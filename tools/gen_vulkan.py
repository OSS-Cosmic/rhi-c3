#!/usr/bin/env python3
# Copyright 2026 Michael Pollind
# SPDX-License-Identifier: GPL-2.0-only
"""Generates the C3 Vulkan bindings (module vk) from the Khronos registry.

Usage: python3 c3/tools/gen_vulkan.py [path/to/vk.xml]

Writes c3/src/vendor/vulkan/{core,enums,structs,procedures}.c3. The output
maps the C API mechanically (`VkX` / `vkX`) to `vk::X`. The
conventions are documented in the header of core.c3 and in c3/README.md.

Only the `vulkan` API is emitted. Skipped: vulkansc-only items, video
extensions, provisional (beta) extensions, disabled extensions and every
platform except xlib, xlib_xrandr, wayland and win32. Anything that references
a skipped type is dropped as well, so the output always compiles.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

DEFAULT_REGISTRY = "/usr/share/vulkan/registry/vk.xml"
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "vendor", "vulkan")

ALLOWED_PLATFORMS = {"xlib", "xlib_xrandr", "wayland", "win32"}

# C basic types from vk_platform.h.
BASIC_TYPES = {
    "void": "void",
    "char": "char",
    "float": "float",
    "double": "double",
    "int8_t": "ichar",
    "uint8_t": "char",
    "int16_t": "short",
    "uint16_t": "ushort",
    "int32_t": "int",
    "uint32_t": "uint",
    "int64_t": "long",
    "uint64_t": "ulong",
    "size_t": "usz",
    "int": "CInt",
}

# Window-system types of the platforms we keep, with the C3 declaration used
# for each. Types that are only ever used through a pointer are opaque
# (`typedef X = void;`).
PLATFORM_TYPES = {
    "Display": ("XlibDisplay", "typedef XlibDisplay = void;", "Xlib Display (opaque, used as XlibDisplay*)"),
    "Window": ("XlibWindow", "alias XlibWindow = CULong;", "Xlib Window (XID)"),
    "VisualID": ("XlibVisualID", "alias XlibVisualID = CULong;", "Xlib VisualID"),
    "RROutput": ("RROutput", "alias RROutput = CULong;", "Xrandr RROutput (XID)"),
    "wl_display": ("WlDisplay", "typedef WlDisplay = void;", "struct wl_display (opaque, used as WlDisplay*)"),
    "wl_surface": ("WlSurface", "typedef WlSurface = void;", "struct wl_surface (opaque, used as WlSurface*)"),
    "HINSTANCE": ("Hinstance", "alias Hinstance = void*;", "HINSTANCE"),
    "HWND": ("Hwnd", "alias Hwnd = void*;", "HWND"),
    "HMONITOR": ("Hmonitor", "alias Hmonitor = void*;", "HMONITOR"),
    "HANDLE": ("Handle", "alias Handle = void*;", "HANDLE"),
    "SECURITY_ATTRIBUTES": ("SecurityAttributes", "typedef SecurityAttributes = void;", "SECURITY_ATTRIBUTES (opaque, used as SecurityAttributes*)"),
    "DWORD": ("Dword", "alias Dword = uint;", "DWORD"),
    "LPCWSTR": ("Lpcwstr", "alias Lpcwstr = ushort*;", "LPCWSTR (UTF-16, null-terminated)"),
}

# C3 keywords that Vulkan uses as field or parameter names get a trailing `_`.
C3_KEYWORDS = {
    "void", "bool", "char", "double", "float", "float16", "int128", "ichar", "int", "iptr", "sz",
    "long", "short", "uint128", "uint", "ulong", "uptr", "ushort", "usz", "float128", "any",
    "fault", "typeid", "assert", "asm", "bitstruct", "break", "case", "catch", "const",
    "continue", "alias", "default", "defer", "typedef", "do", "else", "enum", "extern", "false",
    "for", "foreach", "foreach_r", "fn", "tlocal", "if", "inline", "import", "macro", "module",
    "nextcase", "null", "return", "static", "struct", "switch", "true", "try", "union", "var",
    "while", "attrdef", "constdef", "faultdef", "interface", "lengthof", "bfloat16",
}

EXT_SUFFIXES = ["KHR", "EXT", "AMD", "NV", "NVX", "GOOGLE", "KHX", "ARM", "QCOM", "INTEL",
                "HUAWEI", "VALVE", "LUNARG", "QNX", "MSFT", "SEC", "MESA", "IMG", "FB", "ANDROID",
                "AMDX", "OHOS", "MVK", "NN", "GGP", "FUCHSIA", "BRCM", "NXP", "SAMSUNG"]


def api_ok(elem):
    api = elem.get("api")
    return api is None or "vulkan" in api.split(",")


def strip_api(elem):
    """Removes every child element whose `api` attribute excludes vulkan."""
    for child in list(elem):
        if not api_ok(child):
            elem.remove(child)
        else:
            strip_api(child)


def no_vk(name):
    for p in ("VK_", "Vk", "vk"):
        if name.startswith(p):
            return name[len(p):]
    return name


def to_snake_upper(name):
    s1 = re.sub(r"(.)([A-Z][a-z]+)", r"\1_\2", name)
    return re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", s1).upper()


def lower_first(name):
    return name[0].lower() + name[1:]


def fix_ident(name):
    if name in C3_KEYWORDS:
        return name + "_"
    if name[0].isupper():
        name = lower_first(name)
    return name


def parse_int(text):
    t = text.strip()
    while t.startswith("(") and t.endswith(")"):
        t = t[1:-1].strip()
    t = re.sub(r"(?<=[0-9a-fA-F])[uUlL]+$", "", t)
    if t.startswith("~"):
        return ~parse_int(t[1:])
    return int(t, 0)


class DependsExpr:
    """Evaluates the registry `depends` expressions (`,` = or, `+` = and)."""

    def __init__(self, text):
        self.tokens = re.findall(r"[(),+]|[A-Za-z0-9_:]+", text)
        self.pos = 0

    def evaluate(self, pred):
        return self._or(pred)

    def _peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def _or(self, pred):
        v = self._and(pred)
        while self._peek() == ",":
            self.pos += 1
            v = self._and(pred) or v
        return v

    def _and(self, pred):
        v = self._atom(pred)
        while self._peek() == "+":
            self.pos += 1
            v = self._atom(pred) and v
        return v

    def _atom(self, pred):
        tok = self._peek()
        self.pos += 1
        if tok == "(":
            v = self._or(pred)
            self.pos += 1  # ")"
            return v
        # `VK_EXT_foo::featureName` style dependencies only need the extension.
        return pred(tok.split("::")[0])


class Registry:
    def __init__(self, path):
        self.root = ET.parse(path).getroot()
        strip_api(self.root)
        self.types = {}       # name -> element (first vulkan-compatible definition)
        self.type_order = []
        for t in self.root.find("types"):
            if t.tag != "type":
                continue
            name = t.get("name") or t.findtext("name") or t.findtext("proto/name")
            if name is None or name in self.types:
                continue
            self.types[name] = t
            self.type_order.append(name)
        self.enums_blocks = {e.get("name"): e for e in self.root.findall("enums")}
        self.commands = {}
        self.command_order = []
        for c in self.root.find("commands"):
            name = c.get("name") or c.findtext("proto/name")
            if name in self.commands:
                continue
            self.commands[name] = c
            self.command_order.append(name)
        self.header_version = None
        for t in self.root.find("types"):
            if t.get("category") == "define" and t.findtext("name") == "VK_HEADER_VERSION":
                m = re.search(r"VK_HEADER_VERSION\s+(\d+)", "".join(t.itertext()))
                if m and self.header_version is None:
                    self.header_version = int(m.group(1))

        self.features = [f for f in self.root.findall("feature")
                         if "vulkan" in f.get("api", "").split(",")]
        self.feature_names = {f.get("name") for f in self.features}
        self.all_exts = {e.get("name"): e for e in self.root.findall("extensions/extension")}
        self._ext_ok = {}
        self.extensions = [e for e in self.root.findall("extensions/extension") if self.ext_ok(e.get("name"))]
        self.skipped_extensions = [e.get("name") for e in self.root.findall("extensions/extension")
                                   if "vulkan" in e.get("supported", "").split(",") and not self.ext_ok(e.get("name"))]

    def ext_ok(self, name):
        if name in self.feature_names:
            return True
        if name in self._ext_ok:
            return self._ext_ok[name]
        e = self.all_exts.get(name)
        ok = e is not None
        if ok:
            ok = "vulkan" in e.get("supported", "").split(",")
            ok = ok and e.get("provisional") != "true"
            ok = ok and (e.get("platform") is None or e.get("platform") in ALLOWED_PLATFORMS)
            ok = ok and "video" not in name.lower()
        self._ext_ok[name] = False  # guards against cycles
        if ok and e.get("depends"):
            ok = DependsExpr(e.get("depends")).evaluate(self.ext_ok)
        self._ext_ok[name] = ok
        return ok

    def require_blocks(self):
        """Yields (require element, extension number or None) for everything included."""
        for f in self.features:
            for req in f.findall("require"):
                if req.get("depends") and not DependsExpr(req.get("depends")).evaluate(self.ext_ok):
                    continue
                yield req, None, f
        for e in self.extensions:
            for req in e.findall("require"):
                if req.get("depends") and not DependsExpr(req.get("depends")).evaluate(self.ext_ok):
                    continue
                yield req, int(e.get("number")), e


# ---------------------------------------------------------------------------
# Declarations parsed from <member>/<param>/<proto>

class Decl:
    def __init__(self, elem):
        parts = []
        for node in elem.iter():
            if node.tag == "comment":
                if node.tail and node is not elem:
                    parts.append(node.tail)
                continue
            if node is elem:
                parts.append(node.text or "")
            else:
                parts.append(node.text or "")
                parts.append(node.tail or "")
        text = " ".join("".join(parts).split())
        self.text = text
        self.type = elem.findtext("type")
        self.name = elem.findtext("name")
        m = re.match(r"^(const\s+)?(struct\s+)?(\w+)\s*((?:\*\s*(?:const\s*)?)*)\s*(\w+)\s*((?:\[\s*\w+\s*\]\s*)*)(?::\s*(\d+))?$", text)
        if not m:
            raise ValueError("cannot parse declaration: " + text)
        self.const = bool(m.group(1))
        self.stars = m.group(4).count("*")
        self.dims = re.findall(r"\[\s*(\w+)\s*\]", m.group(6))
        self.bits = int(m.group(7)) if m.group(7) else None


class Gen:
    def __init__(self, reg):
        self.reg = reg
        self.required_types = set()
        self.required_commands = []
        self.enum_values = {}      # enum type -> list of (c name, value or None, alias or None)
        self.constants = []        # (c name, element) of extension constants, in order
        self.ext_constant_names = set()
        self._collect()

    # -- inclusion ----------------------------------------------------------

    def _collect(self):
        reg = self.reg
        seen_cmd = set()
        self.value_seen = set()
        for name, block in reg.enums_blocks.items():
            if block.get("type") in ("enum", "bitmask"):
                vals = self.enum_values.setdefault(name, [])
                for e in block.findall("enum"):
                    vals.append((e.get("name"), self._enum_value(e, None), e.get("alias")))
                    self.value_seen.add(e.get("name"))
        for req, extnumber, owner in reg.require_blocks():
            for t in req.findall("type"):
                self.required_types.add(t.get("name"))
            for c in req.findall("command"):
                if c.get("name") not in seen_cmd:
                    seen_cmd.add(c.get("name"))
                    self.required_commands.append(c.get("name"))
            for e in req.findall("enum"):
                name = e.get("name")
                ext_enum = e.get("extends")
                if ext_enum:
                    if name in self.value_seen:
                        continue
                    self.value_seen.add(name)
                    self.enum_values.setdefault(ext_enum, []).append(
                        (name, self._enum_value(e, extnumber), e.get("alias")))
                elif (e.get("value") is not None or e.get("alias") is not None) and name not in self.ext_constant_names:
                    self.ext_constant_names.add(name)
                    self.constants.append((name, e))

        # Close over referenced types (structs, params, bitmask bits, aliases).
        work = list(self.required_types)
        for c in self.required_commands:
            work.extend(self._command_types(c))
        while work:
            n = work.pop()
            self.required_types.add(n)
            t = reg.types.get(n)
            if t is None:
                continue
            refs = []
            if t.get("alias"):
                refs.append(t.get("alias"))
            cat = t.get("category")
            if cat in ("struct", "union"):
                refs.extend(m.findtext("type") for m in t.findall("member"))
            elif cat == "funcpointer":
                refs.append(t.findtext("proto/type"))
                refs.extend(p.findtext("type") for p in t.findall("param"))
            elif cat == "bitmask":
                for key in ("requires", "bitvalues"):
                    if t.get(key):
                        refs.append(t.get(key))
            for r in refs:
                if r and r not in self.required_types:
                    self.required_types.add(r)
                    work.append(r)

        # Drop everything that references an unavailable type, to a fixed point.
        self.available = set()
        for n in self.required_types:
            if n in BASIC_TYPES or n in PLATFORM_TYPES:
                self.available.add(n)
                continue
            t = reg.types.get(n)
            if t is None or t.get("category") in (None, "include", "define"):
                continue
            if t.get("category") == "basetype" and not n.startswith("Vk"):
                continue  # ANativeWindow, CAMetalLayer, MTL*_id, IOSurfaceRef, ...
            self.available.add(n)
        changed = True
        while changed:
            changed = False
            for n in sorted(self.available):
                t = reg.types.get(n)
                if t is None:
                    continue
                deps = []
                if t.get("alias"):
                    deps.append(t.get("alias"))
                cat = t.get("category")
                if cat in ("struct", "union"):
                    deps.extend(m.findtext("type") for m in t.findall("member"))
                elif cat == "funcpointer":
                    deps.append(t.findtext("proto/type"))
                    deps.extend(p.findtext("type") for p in t.findall("param"))
                if any(d not in self.available for d in deps):
                    self.available.discard(n)
                    changed = True
        self.commands = []
        self.dropped_commands = []
        for c in self.required_commands:
            if all(tn in self.available for tn in self._command_types(c)):
                self.commands.append(c)
            else:
                self.dropped_commands.append(c)
        self.dropped_types = sorted(
            n for n in self.required_types
            if n not in self.available and n in reg.types
            and reg.types[n].get("category") not in ("include", "define"))

    def _command_types(self, name):
        c = self.reg.commands[name]
        if c.get("alias"):
            return [] if c.get("alias") not in self.reg.commands else self._command_types(c.get("alias"))
        out = [c.findtext("proto/type")]
        out.extend(p.findtext("type") for p in c.findall("param"))
        return out

    def _enum_value(self, e, extnumber):
        if e.get("alias"):
            return None
        if e.get("bitpos") is not None:
            return 1 << int(e.get("bitpos"))
        if e.get("offset") is not None:
            num = int(e.get("extnumber") or extnumber)
            v = 1000000000 + (num - 1) * 1000 + int(e.get("offset"))
            return -v if e.get("dir") == "-" else v
        if e.get("value") is not None:
            return parse_int(e.get("value"))
        return None

    # -- naming -------------------------------------------------------------

    def type_name(self, c_name):
        if c_name in BASIC_TYPES:
            return BASIC_TYPES[c_name]
        if c_name in PLATFORM_TYPES:
            return PLATFORM_TYPES[c_name][0]
        if c_name.startswith("PFN_vk"):
            return "Proc" + c_name[len("PFN_vk"):]
        return no_vk(c_name)

    def c3_type(self, decl, as_param=False):
        stars = decl.stars
        if decl.type == "char" and stars >= 1 and decl.const:
            base = "ZString"
            stars -= 1
        else:
            base = self.type_name(decl.type)
        t = base + "*" * stars
        if decl.dims:
            dims = "".join("[%s]" % self.dim(d) for d in reversed(decl.dims))
            t = t + dims
            if as_param:
                t = t + "*"  # C array parameters decay to pointers
        return t

    def dim(self, d):
        if d.isdigit():
            return d
        return no_vk(d)

    # -- enums --------------------------------------------------------------

    def enum_member_names(self, enum_name):
        """Returns [(member name, value)] for a (non-bitmask) enum."""
        base = no_vk(enum_name)
        prefix = to_snake_upper(base)
        suffix = None
        for ext in EXT_SUFFIXES:
            if prefix.endswith("_" + ext):
                suffix = "_" + ext
                prefix = prefix[: -len(suffix)]
                break
        prefix_words = prefix.split("_")
        prefix += "_"
        values = {}
        for n, v, a in self.enum_values.get(enum_name, []):
            values[n] = (v, a)
        out = []
        used = set()
        for n, (v, a) in values.items():
            while v is None and a is not None:
                v, a = values.get(a, (None, None)) if a in values else (None, None)
            if v is None:
                continue
            short = no_vk(n)
            if short.startswith(prefix):
                short = short[len(prefix):]
                if short[0].isdigit():
                    if len(short) > 1 and short[1] == "D":
                        short = short[1] + short[0] + short[2:]  # IMAGE_TYPE_2D -> D2
                    else:
                        short = prefix_words[-1] + "_" + short
            if suffix and short.endswith(suffix) and short != suffix[1:]:
                short = short[: -len(suffix)]
            short = short.upper()
            if short in used:
                continue
            used.add(short)
            out.append((short, v))
        return out

    def bitmask_values(self, enum_name):
        values = {}
        for n, v, a in self.enum_values.get(enum_name, []):
            values[n] = (v, a)
        out = []
        for n, (v, a) in values.items():
            out.append((no_vk(n), v, no_vk(a) if a else None))
        return out

    # -- emitters -----------------------------------------------------------

    def header(self, what):
        return ("// Generated by c3/tools/gen_vulkan.py from the Khronos Vulkan registry (vk.xml,\n"
                "// VK_HEADER_VERSION %d; Apache-2.0 OR MIT). Do not edit: rerun the generator.\n"
                "// %s\n"
                "module vk;\n\n" % (self.reg.header_version, what))

    def ordered(self, categories):
        return [n for n in self.reg.type_order
                if n in self.available and self.reg.types[n].get("category") in categories]

    def emit_core(self):
        reg = self.reg
        out = [
            "// Generated by c3/tools/gen_vulkan.py from the Khronos Vulkan registry (vk.xml,\n",
            "// VK_HEADER_VERSION %d; Apache-2.0 OR MIT). Do not edit: rerun the generator:\n" % reg.header_version,
            "//     python3 c3/tools/gen_vulkan.py [path/to/vk.xml]\n",
            "//\n",
            CONVENTIONS,
            "module vk;\n\n",
        ]
        w = out.append
        w("const uint HEADER_VERSION = %d;\n\n" % reg.header_version)
        w("// Versions. The @-macros fold to constants when given constants.\n")
        w("macro uint @make_api_version(#variant, #major, #minor, #patch) => ((uint)(#variant) << 29) | ((uint)(#major) << 22) | ((uint)(#minor) << 12) | (uint)(#patch);\n")
        w("macro uint @make_version(#major, #minor, #patch) => ((uint)(#major) << 22) | ((uint)(#minor) << 12) | (uint)(#patch);\n")
        w("macro uint @api_version_variant(#version) => (uint)(#version) >> 29;\n")
        w("macro uint @api_version_major(#version) => ((uint)(#version) >> 22) & 0x7F;\n")
        w("macro uint @api_version_minor(#version) => ((uint)(#version) >> 12) & 0x3FF;\n")
        w("macro uint @api_version_patch(#version) => (uint)(#version) & 0xFFF;\n")
        w("macro uint @version_major(#version) => (uint)(#version) >> 22;\n")
        w("macro uint @version_minor(#version) => ((uint)(#version) >> 12) & 0x3FF;\n")
        w("macro uint @version_patch(#version) => (uint)(#version) & 0xFFF;\n\n")
        for minor in range(5):
            w("const uint API_VERSION_1_%d = @make_api_version(0, 1, %d, 0);\n" % (minor, minor))
        w("const uint HEADER_VERSION_COMPLETE = @make_api_version(0, 1, 4, HEADER_VERSION);\n\n")

        w("// Base types\n")
        base_decl = {
            "VkSampleMask": "alias SampleMask = uint;",
            "VkBool32": "alias Bool32 = uint;",
            "VkFlags": "alias Flags = uint;",
            "VkFlags64": "alias Flags64 = ulong;",
            "VkDeviceSize": "alias DeviceSize = ulong;",
            "VkDeviceAddress": "alias DeviceAddress = ulong;",
            "VkRemoteAddressNV": "alias RemoteAddressNV = void*;",
        }
        for n in self.ordered({"basetype"}):
            if n not in base_decl:
                raise ValueError("unhandled basetype " + n)
            w(base_decl[n] + "\n")
        w("\n// Platform types (xlib, xlib_xrandr, wayland, win32)\n")
        for c_name, (name, decl, comment) in PLATFORM_TYPES.items():
            if c_name in self.available:
                w("%s // %s\n" % (decl, comment))

        w("\n// API constants\n")
        for e in reg.enums_blocks["API Constants"].findall("enum"):
            name = no_vk(e.get("name"))
            if e.get("alias"):
                w("const %s = %s;\n" % (name, no_vk(e.get("alias"))))
                continue
            ctype = BASIC_TYPES[e.get("type")]
            if ctype == "float":
                w("const float %s = %s;\n" % (name, e.get("value").rstrip("fF")))
            else:
                v = parse_int(e.get("value"))
                bits = 64 if ctype == "ulong" else 32
                v &= (1 << bits) - 1
                w("const %s %s = %s;\n" % (ctype, name, ("0x%X" % v) if v > 0xFFFF else str(v)))

        w("\n// Handles. Dispatchable handles are distinct pointers (compare with null),\n")
        w("// non-dispatchable handles are distinct 64-bit integers (compare with 0 or NULL_HANDLE).\n")
        w("const NULL_HANDLE = 0;\n\n")
        aliases = []
        for n in self.ordered({"handle"}):
            t = reg.types[n]
            if t.get("alias"):
                aliases.append("alias %s = %s;\n" % (no_vk(n), no_vk(t.get("alias"))))
            elif t.findtext("type") == "VK_DEFINE_HANDLE":
                w("typedef %s @constinit = inline void*;\n" % no_vk(n))
        w("\n")
        for n in self.ordered({"handle"}):
            t = reg.types[n]
            if not t.get("alias") and t.findtext("type") == "VK_DEFINE_NON_DISPATCHABLE_HANDLE":
                w("typedef %s @constinit = ulong;\n" % no_vk(n))
        w("\n")
        out.extend(aliases)

        w("\n// Extension names and spec versions\n")
        const_types = {}
        for c_name, e in self.constants:
            name = no_vk(c_name)
            if e.get("alias"):
                target = e.get("alias")
                if target in const_types:
                    w("const %s %s = %s;\n" % (const_types[target], name, no_vk(target)))
                    const_types[c_name] = const_types[target]
                continue
            value = e.get("value")
            if value.startswith('"'):
                w("const ZString %s = %s;\n" % (name, value))
                const_types[c_name] = "ZString"
            elif re.match(r"^-?(0x)?[0-9A-Fa-f]+U?$", value):
                w("const uint %s = %s;\n" % (name, value.rstrip("U")))
                const_types[c_name] = "uint"
            elif value.startswith("VK_") and value in const_types:
                w("const %s %s = %s;\n" % (const_types[value], name, no_vk(value)))
                const_types[c_name] = const_types[value]
            # Anything else (enum-valued aliases of old names) is covered by the enums.
        return "".join(out)

    def emit_enums(self):
        reg = self.reg
        out = [self.header("Enums (constdef) and bitmask Flags types with their bit constants.")]
        w = out.append
        # FlagBits enum -> Flags type name.
        bits_owner = {}
        for n in self.ordered({"bitmask"}):
            t = reg.types[n]
            for key in ("requires", "bitvalues"):
                if t.get(key):
                    bits_owner.setdefault(t.get(key), n)

        w("// Enums\n")
        for n in self.ordered({"enum"}):
            t = reg.types[n]
            if t.get("alias"):
                continue
            block = reg.enums_blocks.get(n)
            if block is not None and block.get("type") == "bitmask":
                continue
            if n in bits_owner or "FlagBits" in n:
                continue
            members = self.enum_member_names(n)
            w("constdef %s : int\n{\n" % no_vk(n))
            if not members:
                w("\tNONE_ = 0, // no values in the registry\n")
            width = max((len(m) for m, _ in members), default=0)
            for m, v in members:
                w("\t%s = %d,\n" % (m.ljust(width), v))
            w("}\n\n")

        w("// Bitmasks. XFlagBits is an alias of XFlags; bits are module constants.\n")
        for n in self.ordered({"bitmask"}):
            t = reg.types[n]
            if t.get("alias"):
                continue
            base = "ulong" if t.findtext("type") == "VkFlags64" else "uint"
            flags = no_vk(n)
            w("typedef %s @constinit = %s;\n" % (flags, base))
            bits = t.get("requires") or t.get("bitvalues")
            if bits and bits in self.available and bits_owner.get(bits) == n:
                w("alias %s = %s;\n" % (no_vk(bits), flags))
                vals = self.bitmask_values(bits)
                width = max((len(m) for m, _, _ in vals), default=0)
                for m, v, a in vals:
                    if v is None:
                        if a is None:
                            continue
                        w("const %s %s = %s;\n" % (flags, m.ljust(width), a))
                    else:
                        w("const %s %s = 0x%08X;\n" % (flags, m.ljust(width), v) if base == "uint"
                          else "const %s %s = 0x%016X;\n" % (flags, m.ljust(width), v))
            w("\n")

        # FlagBits enums that have no Flags typedef of their own.
        for n in self.ordered({"enum"}):
            t = reg.types[n]
            if t.get("alias") or n in bits_owner:
                continue
            block = reg.enums_blocks.get(n)
            if not ((block is not None and block.get("type") == "bitmask") or "FlagBits" in n):
                continue
            base = "ulong" if block is not None and block.get("bitwidth") == "64" else "uint"
            flags = no_vk(n)
            w("typedef %s @constinit = %s;\n" % (flags, base))
            vals = self.bitmask_values(n)
            for m, v, a in vals:
                if v is None:
                    if a is not None:
                        w("const %s %s = %s;\n" % (flags, m, a))
                else:
                    w("const %s %s = 0x%X;\n" % (flags, m, v))
            w("\n")

        w("// Enum and bitmask aliases\n")
        for n in self.ordered({"enum", "bitmask"}):
            t = reg.types[n]
            if t.get("alias"):
                w("alias %s = %s;\n" % (no_vk(n), no_vk(t.get("alias"))))
        return "".join(out)

    def emit_structs(self):
        reg = self.reg
        out = [self.header("Structs and unions, field-for-field with the C headers (C field names).")]
        w = out.append
        aliases = []
        for n in self.ordered({"struct", "union"}):
            t = reg.types[n]
            if t.get("alias"):
                aliases.append("alias %s = %s;\n" % (no_vk(n), no_vk(t.get("alias"))))
                continue
            w("%s %s\n{\n" % (t.get("category"), no_vk(n)))
            members = [Decl(m) for m in t.findall("member")]
            i = 0
            while i < len(members):
                d = members[i]
                if d.bits is None:
                    w("\t%s %s;\n" % (self.c3_type(d), fix_ident(d.name)))
                    i += 1
                    continue
                # Consecutive C bitfields share 32-bit containers, low bits first.
                group = []
                used = 0
                while i < len(members) and members[i].bits is not None and used + members[i].bits <= 32:
                    group.append((members[i], used))
                    used += members[i].bits
                    i += 1
                w("\tbitstruct : uint\n\t{\n")
                for bd, lo in group:
                    w("\t\t%s %s : %d..%d;\n" % (self.c3_type(bd), fix_ident(bd.name), lo, lo + bd.bits - 1))
                w("\t}\n")
            w("}\n\n")
        w("// Aliases\n")
        out.extend(aliases)
        return "".join(out)

    def fn_type(self, proto_elem, params):
        ret = Decl(proto_elem)
        ps = []
        for p in params:
            d = Decl(p)
            ps.append("%s %s" % (self.c3_type(d, as_param=True), fix_ident(d.name)))
        return "fn %s(%s)" % (self.c3_type(ret), ", ".join(ps))

    def command_group(self, name):
        reg = self.reg
        c = reg.commands[name]
        while c.get("alias"):
            c = reg.commands[c.get("alias")]
        if name == "vkGetInstanceProcAddr":
            return "Loader"
        if name == "vkGetDeviceProcAddr":
            return "Instance"
        params = c.findall("param")
        first = params[0].findtext("type") if params else None
        t = reg.types.get(first) if first else None
        if t is not None and t.get("category") == "handle":
            while t.get("alias"):
                first = t.get("alias")
                t = reg.types[first]
            if t.findtext("type") == "VK_DEFINE_HANDLE":
                return "Instance" if first in ("VkInstance", "VkPhysicalDevice") else "Device"
        return "Loader"

    def emit_procedures(self):
        reg = self.reg
        out = [self.header("Procedure types, global procedure pointers, run-time loaders and DeviceVTable.")]
        w = out.append

        w("// Misc procedure types (PFN_vk* callbacks)\n")
        for n in self.ordered({"funcpointer"}):
            t = reg.types[n]
            w("alias %s = %s;\n" % (self.type_name(n), self.fn_type(t.find("proto"), t.findall("param"))))
        w("\n")

        groups = {"Loader": [], "Instance": [], "Device": []}
        for name in self.commands:
            groups[self.command_group(name)].append(name)
        for g in groups.values():
            g.sort(key=lambda n: no_vk(n))

        for g, names in groups.items():
            w("// %s procedure types\n" % g)
            for name in names:
                c = reg.commands[name]
                if c.get("alias"):
                    w("alias Proc%s = Proc%s;\n" % (no_vk(name), no_vk(c.get("alias"))))
                else:
                    w("alias Proc%s = %s;\n" % (no_vk(name), self.fn_type(c.find("proto"), c.findall("param"))))
            w("\n")

        for g, names in groups.items():
            w("// %s procedures\n" % g)
            width = max(len(no_vk(n)) for n in names) + 4
            for name in names:
                w("%s %s;\n" % (("Proc" + no_vk(name)).ljust(width), lower_first(no_vk(name))))
            w("\n")

        def load(target, getter, arg, names, prefix=""):
            width = max(len(lower_first(no_vk(n))) for n in names)
            for name in names:
                var = lower_first(no_vk(name))
                w('\t%s%s = (Proc%s)%s(%s, "%s");\n' % (prefix, var.ljust(width), no_vk(name), getter, arg, name))

        w("// Device procedure table, for applications with more than one VkDevice\n")
        w("struct DeviceVTable\n{\n")
        width = max(len(no_vk(n)) for n in groups["Device"]) + 4
        for name in groups["Device"]:
            w("\t%s %s;\n" % (("Proc" + no_vk(name)).ljust(width), lower_first(no_vk(name))))
        w("}\n\n")

        w("fn void load_proc_addresses_device_vtable(Device device, DeviceVTable* vtable)\n{\n")
        load("vtable", "getDeviceProcAddr", "device", groups["Device"], prefix="vtable.")
        w("}\n\n")

        w("fn void load_proc_addresses_device(Device device)\n{\n")
        load(None, "getDeviceProcAddr", "device", groups["Device"])
        w("}\n\n")

        w("fn void load_proc_addresses_instance(Instance instance)\n{\n")
        load(None, "getInstanceProcAddr", "instance", groups["Instance"])
        w("\n\t// Device procedures (may call into dispatch)\n")
        load(None, "getInstanceProcAddr", "instance", groups["Device"])
        w("}\n\n")

        w("fn void load_proc_addresses_global(void* vk_get_instance_proc_addr)\n{\n")
        w("\tgetInstanceProcAddr = (ProcGetInstanceProcAddr)vk_get_instance_proc_addr;\n\n")
        load(None, "getInstanceProcAddr", "(Instance)null",
             [n for n in groups["Loader"] if n != "vkGetInstanceProcAddr"])
        w("}\n")
        return "".join(out)


CONVENTIONS = """\
// Conventions (C bindings `vk.X` -> C3 `vk::X`):
//
// - Names drop the Vk/vk/VK_ prefix: `vk::Instance`, `vk::ImageCreateInfo`,
//   `vk::KHR_SWAPCHAIN_EXTENSION_NAME` (ZString), `vk::WHOLE_SIZE`.
// - Handles: dispatchable handles are `typedef Instance @constinit = inline void*;`
//   (distinct, compare with null); non-dispatchable handles are
//   `typedef Image @constinit = ulong;` (distinct, compare with 0 / NULL_HANDLE).
// - Enums are `constdef X : int` with explicit values; members drop the type
//   prefix and the type's vendor suffix: `vk::Format.R8G8B8A8_UNORM`
//   (or just `R8G8B8A8_UNORM` where a Format is expected),
//   `vk::Result.ERROR_OUT_OF_DATE_KHR`, `vk::ColorSpaceKHR.SRGB_NONLINEAR`.
//   Members that would start with a digit become `D2`/`D3` (`ImageType.D2`)
//   or keep the last prefix word; lowercase letters are uppercased
//   (`Format.ASTC_4X4_UNORM_BLOCK`).
// - Bitmasks: `typedef ImageAspectFlags @constinit = uint;` (Flags64-based
//   ones are ulong), `alias ImageAspectFlagBits = ImageAspectFlags;`, and every
//   bit is a module constant with its full C name minus VK_:
//   `vk::IMAGE_ASPECT_COLOR_BIT | vk::IMAGE_ASPECT_DEPTH_BIT`,
//   test with `if (flags & vk::MEMORY_PROPERTY_DEVICE_LOCAL_BIT)`.
// - Base types are plain aliases: DeviceSize/DeviceAddress/Flags64 = ulong,
//   Bool32/SampleMask/Flags = uint.
// - Structs keep the C field names (sType, pNext, ...); C3 keywords get a
//   trailing underscore (`module_`). C3 has no field defaults, so sType must
//   be set by hand. C bitfields become anonymous bitstructs (fields stay
//   directly accessible). `const char*` is ZString, fixed arrays use the API
//   constants (`char[MAX_EXTENSION_NAME_SIZE]`).
// - Procedure types keep the C names: `ProcCreateInstance`,
//   `ProcGetDeviceProcAddr`, `ProcVoidFunction`, `ProcDebugUtilsMessengerCallbackEXT`.
// - C3 variables and fields must start lowercase, so the global procedure
//   pointers and DeviceVTable fields are the command name minus `vk` with the
//   first letter lowercased: `vk.CreateInstance(...)` is
//   `vk::createInstance(...)`, `vtable.CmdDraw` is `vtable.cmdDraw`.
// - Loading: load_proc_addresses_global(vkGetInstanceProcAddr),
//   load_proc_addresses_instance(instance), load_proc_addresses_device(device),
//   load_proc_addresses_device_vtable(device, &vtable). Nothing links libvulkan;
//   volk (vendor/volk) opens the loader library and supplies vkGetInstanceProcAddr.
// - MAKE_API_VERSION/VERSION_MAJOR/... are the macros
//   `vk::@make_api_version(0, 1, 3, 0)`, `vk::@api_version_major(v)`, ...
//   which fold to constants when given constants.
// - Platform types: XlibDisplay (opaque), XlibWindow, XlibVisualID, RROutput,
//   WlDisplay/WlSurface (opaque), Hinstance, Hwnd, Hmonitor, Handle, Dword,
//   Lpcwstr, SecurityAttributes (opaque). Fn types use the default C calling
//   convention, which matches VKAPI_CALL on every 64-bit target and wasm.
"""


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REGISTRY
    reg = Registry(path)
    gen = Gen(reg)
    files = {
        "core.c3": gen.emit_core(),
        "enums.c3": gen.emit_enums(),
        "structs.c3": gen.emit_structs(),
        "procedures.c3": gen.emit_procedures(),
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, text in files.items():
        with open(os.path.join(OUT_DIR, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
    print("vk.xml header %d: %d types, %d commands (%d dropped), %d extensions (%d skipped)" % (
        reg.header_version, len(gen.available), len(gen.commands), len(gen.dropped_commands),
        len(reg.extensions), len(reg.skipped_extensions)))
    if gen.dropped_types:
        print("dropped types: " + ", ".join(gen.dropped_types))
    if gen.dropped_commands:
        print("dropped commands: " + ", ".join(gen.dropped_commands))


if __name__ == "__main__":
    main()

"""Starlark rules that drive c3c (C3 has no native Bazel support).

c3c resolves `$embed` paths and project files relative to the working
directory/source file, so every action first builds a staging tree of symlinks
that mirrors the repo layout (including generated shaders at
`build/examples/<ex>/shaders/`), then runs c3c from inside it.
"""

load("@c3c//:config.bzl", "C3C")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

_COMMON_SRCS = [
    Label("//:c3_src"),
    Label("//:vk_src"),
]

def _lib_name(f):
    n = f.basename
    if ".so" in n:
        n = n.split(".so")[0]
    for suffix in [".pic.a", ".a", ".lo"]:
        if n.endswith(suffix):
            n = n[:-len(suffix)]
            break
    if n.startswith("lib"):
        n = n[3:]
    return n

def _collect_libs(deps):
    statics = {}
    dynamics = {}
    for dep in deps:
        for li in dep[CcInfo].linking_context.linker_inputs.to_list():
            for lib in li.libraries:
                s = lib.pic_static_library or lib.static_library
                if s:
                    statics[_lib_name(s)] = s
                d = lib.dynamic_library
                if d:
                    dynamics[_lib_name(d)] = d
    return statics, dynamics

def _stage_lines(files, shader_files, use_short):
    """Shell lines that symlink `files` into $STAGE, mirroring repo paths."""
    lines = []
    for f in files:
        dest = f.short_path
        src = f.short_path if use_short else f.path
        lines.append('mkdir -p "$STAGE/$(dirname %s)" && cp -L "$EXEC/%s" "$STAGE/%s"' % (dest, src, dest))
    for f in shader_files:
        dest = "build/" + f.short_path
        src = f.short_path if use_short else f.path
        lines.append('mkdir -p "$STAGE/$(dirname %s)" && cp -L "$EXEC/%s" "$STAGE/%s"' % (dest, src, dest))
    return lines

def _lib_lines(statics, dynamics, use_short):
    lines = ['mkdir -p "$STAGE/_libs"']
    for name, f in statics.items():
        lines.append('ln -sf "$EXEC/%s" "$STAGE/_libs/lib%s.a"' % (f.short_path if use_short else f.path, name))
    for name, f in dynamics.items():
        lines.append('ln -sf "$EXEC/%s" "$STAGE/_libs/lib%s.so"' % (f.short_path if use_short else f.path, name))
    return lines

def _link_args(statics, dynamics, linkopts):
    args = ["-L", '"$STAGE/_libs"'] if (statics or dynamics) else []
    for name in sorted(statics.keys()) + sorted(dynamics.keys()):
        args += ["-l", name]
    if dynamics:
        args += ["-z", "-Wl,-rpath,\\$ORIGIN"]
    return args + linkopts

def _defines(defines):
    out = []
    for d in defines:
        out += ["-D", d]
    return out

def _c3_common_attrs():
    return {
        "srcs": attr.label_list(allow_files = True, default = _COMMON_SRCS),
        "extra_srcs": attr.label_list(allow_files = True, doc = "Extra sources (e.g. example main + platform)."),
        "_sdl3_c3l": attr.label(allow_single_file = True, default = Label("@c3c//:sdl3.c3l")),
        "shaders": attr.label_list(allow_files = True, doc = "Generated shader files embedded via $embed; staged at build/<short_path>."),
        "native_deps": attr.label_list(providers = [CcInfo]),
        "target": attr.string(mandatory = True),
        "defines": attr.string_list(),
        "linkopts": attr.string_list(doc = "Extra args passed to c3c verbatim."),
    }

def _gather(ctx):
    files = []
    for t in ctx.attr.srcs + ctx.attr.extra_srcs:
        files += t[DefaultInfo].files.to_list()
    shader_files = []
    for t in ctx.attr.shaders:
        shader_files += t[DefaultInfo].files.to_list()
    statics, dynamics = _collect_libs(ctx.attr.native_deps)
    return files, shader_files, statics, dynamics

def _quote(args):
    return " ".join(["'%s'" % a if (a.startswith("-Wl") or "*" in a) else a for a in args])

def _binary_impl(ctx):
    files, shader_files, statics, dynamics = _gather(ctx)
    is_wasm = ctx.attr.target.startswith("wasm")
    out = ctx.actions.declare_file(ctx.attr.name + (".wasm" if is_wasm else ""))
    dyn_outs = []
    for name, f in dynamics.items():
        dyn_outs.append((f, ctx.actions.declare_file(f.basename)))

    main = ctx.file.main
    compile_args = [
        "compile",
        main.short_path,
    ] + [f.short_path for f in ctx.files.extra_srcs if f.short_path.endswith(".c3") and f != main] + [
        "'src/**'",
        "'vendor/vulkan.c3l/vk/**'",
        "--target",
        ctx.attr.target,
        "--obj-out",
        "obj",
        "--output-dir",
        '"$OUTDIR"',
        "-o",
        ctx.attr.name,
    ] + _defines(ctx.attr.defines)

    script = ctx.actions.declare_file(ctx.attr.name + ".stage.sh")
    lines = [
        "set -euo pipefail",
        "EXEC=$PWD",
        'STAGE="$(mktemp -d)"',
        'trap \'rm -rf "$STAGE"\' EXIT',
        'OUTDIR="$EXEC/%s"' % out.dirname,
    ]
    lines += _stage_lines(files, shader_files, False)
    lines += _lib_lines(statics, dynamics, False)
    lines.append('ln -sf "$EXEC/%s" "$STAGE/sdl3.c3l"' % (ctx.file._sdl3_c3l.short_path if False else ctx.file._sdl3_c3l.path))
    lines.append('cd "$STAGE"')
    lines.append("%s %s %s" % (C3C, " ".join(compile_args), _quote(_link_args(statics, dynamics, ctx.attr.linkopts)).replace("$STAGE", "$STAGE")))
    lines.append('[ -e "$OUTDIR/%s" ] || touch "$OUTDIR/%s"' % (out.basename, out.basename))
    for src, dst in dyn_outs:
        lines.append('cp -L "$EXEC/%s" "$EXEC/%s"' % (src.path, dst.path))
    ctx.actions.write(script, "\n".join(lines) + "\n", is_executable = True)

    inputs = files + [ctx.file._sdl3_c3l] + shader_files + list(statics.values()) + list(dynamics.values())
    ctx.actions.run(
        outputs = [out] + [d for _, d in dyn_outs],
        inputs = inputs,
        executable = "/bin/bash",
        arguments = [script.path],
        tools = [script],
        mnemonic = "C3Compile",
        progress_message = "c3c %s (%s)" % (ctx.attr.name, ctx.attr.target),
        use_default_shell_env = True,
        execution_requirements = {"no-remote": "1", "local": "1"},
    )
    return [DefaultInfo(files = depset([out] + [d for _, d in dyn_outs]), executable = out if not is_wasm else None)]

c3_binary = rule(
    implementation = _binary_impl,
    attrs = dict(_c3_common_attrs(), main = attr.label(allow_single_file = [".c3"], mandatory = True)),
    doc = "Compiles one example/main file against the RHI sources with c3c.",
)

def _check_impl(ctx):
    files, shader_files, statics, dynamics = _gather(ctx)
    stamp = ctx.actions.declare_file(ctx.attr.name + ".ok")
    script = ctx.actions.declare_file(ctx.attr.name + ".stage.sh")
    lines = [
        "set -euo pipefail",
        "EXEC=$PWD",
        'STAGE="$(mktemp -d)"',
        'trap \'rm -rf "$STAGE"\' EXIT',
    ]
    test_files = ctx.files._tests if ctx.attr.run_tests else []
    files = files + test_files
    lines += _stage_lines(files + [ctx.file._project], shader_files, False)
    lines += _lib_lines(statics, dynamics, False)
    lines.append('ln -sf "$EXEC/%s" "$STAGE/sdl3.c3l"' % (ctx.file._sdl3_c3l.short_path if False else ctx.file._sdl3_c3l.path))
    lines.append('cd "$STAGE"')
    verb = "test -C" if ctx.attr.run_tests else "build"
    lines.append("%s %s --target %s --build-dir b --obj-out obj %s" % (C3C, verb, ctx.attr.target, " ".join(_defines(ctx.attr.defines) + _link_args(statics, dynamics, ctx.attr.linkopts))))
    lines.append('touch "$EXEC/%s"' % stamp.path)
    ctx.actions.write(script, "\n".join(lines) + "\n", is_executable = True)
    ctx.actions.run(
        outputs = [stamp],
        inputs = files + [ctx.file._sdl3_c3l, ctx.file._project] + shader_files + list(statics.values()) + list(dynamics.values()),
        executable = "/bin/bash",
        arguments = [script.path],
        tools = [script],
        mnemonic = "C3Check",
        progress_message = "c3c build --target %s" % ctx.attr.target,
        use_default_shell_env = True,
        execution_requirements = {"no-remote": "1", "local": "1"},
    )
    return [DefaultInfo(files = depset([stamp]))]

_check = rule(
    implementation = _check_impl,
    attrs = dict(_c3_common_attrs(), run_tests = attr.bool(doc = "Compile (not run) the test sources: `c3c test -C`."), _tests = attr.label(allow_files = True, default = Label("//:c3_tests")), _project = attr.label(allow_single_file = True, default = Label("//:project.json"))),
)

def c3_check(name, target, defines = [], native_deps = [], **kwargs):
    """Project-mode `c3c build --target <target>` as a pass/fail build."""
    _check(name = name, target = target, defines = defines, native_deps = native_deps, **kwargs)

def _test_impl(ctx):
    files, shader_files, statics, dynamics = _gather(ctx)
    test_files = ctx.files._tests
    script = ctx.actions.declare_file(ctx.attr.name + ".sh")
    lines = [
        "set -euo pipefail",
        "EXEC=$PWD",
        'STAGE_ROOT="$(mktemp -d)"',
        'STAGE="$STAGE_ROOT/stage"',
        'mkdir -p "$STAGE"',
        'trap \'rm -rf "$STAGE_ROOT"\' EXIT',
    ]
    lines += _stage_lines(files + test_files + [ctx.file._project], shader_files, True)
    lines += _lib_lines(statics, dynamics, True)
    lines.append('export LD_LIBRARY_PATH="$STAGE/_libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"')
    project_dir = ctx.file._project.short_path.rsplit("/", 1)[0] if "/" in ctx.file._project.short_path else "."
    lines.append('ln -sf "$EXEC/%s" "$STAGE/%s/sdl3.c3l"' % (ctx.file._sdl3_c3l.short_path, project_dir))
    lines.append('cd "$STAGE/%s"' % project_dir)
    lines.append("%s test --build-dir b --obj-out obj %s" % (C3C, " ".join(_defines(ctx.attr.defines) + _link_args(statics, dynamics, ctx.attr.linkopts))))
    ctx.actions.write(script, "\n".join(lines) + "\n", is_executable = True)
    runfiles = ctx.runfiles(files = files + [ctx.file._sdl3_c3l] + test_files + [ctx.file._project] + shader_files + list(statics.values()) + list(dynamics.values()))
    return [DefaultInfo(executable = script, runfiles = runfiles)]

_test = rule(
    implementation = _test_impl,
    test = True,
    attrs = dict(
        _c3_common_attrs(),
        target = attr.string(default = "linux-x64"),
        _tests = attr.label(allow_files = True, default = Label("//:c3_tests")),
        _project = attr.label(allow_single_file = True, default = Label("//:project.json")),
    ),
)

def c3_test(name, native_deps = [], defines = [], **kwargs):
    """`c3c test` in project mode, run on the host."""
    _test(name = name, native_deps = native_deps, defines = defines, tags = ["local", "no-sandbox"], **kwargs)

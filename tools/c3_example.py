#!/usr/bin/env python3
"""Build one example with c3c from the repository root.

linux-x64 and macos-aarch64 link executables; wasm32 links a .wasm and packages
the browser bundle (glue, index.html) next to it; other targets are compile-only.

usage: c3_example.py <c3c> <example> <target> <outdir> <stamp> [sdl3 link flag ...]
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMGUI_EXAMPLES = {"03_imgui", "04_svt"}
VULKAN_C3 = os.environ.get("VULKAN_C3_DIR") or str(ROOT / "subprojects" / "vulkan_c3")
WEB_DIR = ROOT / "examples" / "platform" / "web"


def package_web(example, outdir):
    for name in ("glue.js", "webgl_glue.js"):
        shutil.copy(WEB_DIR / name, outdir / name)
    html = (WEB_DIR / "index.html").read_text().replace("{{WASM_NAME}}", example)
    (outdir / "index.html").write_text(html)


def main(argv):
    c3c, example, target, outdir, stamp = argv[1], argv[2], argv[3], Path(argv[4]), Path(argv[5])
    sdl3_flags = argv[6:]
    imgui = example in IMGUI_EXAMPLES
    if imgui and not (ROOT / "vendor/imgui_c/lib/libimgui.a").is_file():
        print(
            "ImGui example requires vendor/imgui_c/lib/libimgui.a; initialize "
            "vendor/imgui_c/imgui and build the imgui target first.",
            file=sys.stderr,
        )
        return 1
    outdir.mkdir(parents=True, exist_ok=True)
    cmd = [c3c, "compile", f"examples/{example}/main.c3", "examples/platform/platform.c3", "src/**", f"{VULKAN_C3}/vk/**",
           "--target", target, "-o", str(outdir / example)]
    if imgui:
        cmd += ["-D", "RHI_IMGUI"]
    if target == "linux-x64":
        cmd += ["-D", "RHI_VK"] + sdl3_flags
    elif target == "wasm32":
        cmd += ["-D", "RHI_WGPU", "-D", "RHI_WEBGL"]
    elif target == "macos-aarch64":
        cmd += ["-D", "RHI_MTL", "--libdir", ".", "--lib", "sdl3"]
        if imgui:
            cmd += ["-L", "vendor/imgui_c/lib", "-l", "imgui", "-l", "c++"]
        for framework in (
            "Cocoa", "IOKit", "ForceFeedback", "Carbon", "CoreAudio",
            "AudioToolbox", "AVFoundation", "CoreMedia", "CoreVideo",
            "GameController", "CoreHaptics", "UniformTypeIdentifiers",
            "ApplicationServices",
        ):
            cmd += ["-z", "-framework", "-z", framework]
    if target == "linux-x64":
        cmd += ["-L", "vendor/lib", "-l", "vma", "-l", "stdc++", "-l", "X11-xcb"]
        if imgui:
            cmd += ["-L", "vendor/imgui_c/lib", "-l", "imgui"]
    elif target not in ("wasm32", "macos-aarch64"):
        cmd += ["-C"]
    status = subprocess.run(cmd, cwd=ROOT, check=False).returncode
    if status == 0:
        if target == "wasm32":
            package_web(example, outdir)
        stamp.write_text("")
    return status


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

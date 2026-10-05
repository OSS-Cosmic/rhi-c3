#!/usr/bin/env python3
"""Build and test the C3 port from any working directory.

The C3 project lives beside the Odin project and owns its VMA copy. Keep all
paths anchored at this file so both ``c3/build.py`` and the root compatibility
commands behave identically.
"""

import argparse
import os
import platform
import subprocess
import sys
from pathlib import Path


C3_ROOT = Path(__file__).resolve().parent
REPO_ROOT = C3_ROOT.parent
VMA_SOURCE = C3_ROOT / "vendor" / "vma" / "vma_impl.cpp"
VMA_INCLUDE = C3_ROOT / "vendor" / "vma" / "include"
VMA_OBJECT = C3_ROOT / "build" / "vma_impl.o"
VMA_LIBRARY = C3_ROOT / "vendor" / "vma" / "lib" / "libvma.a"
IMGUI_SOURCE = REPO_ROOT / "vendor" / "imgui" / "imgui_impl.cpp"
IMGUI_INTERNAL_SOURCE = REPO_ROOT / "vendor" / "imgui" / "odin-imgui" / "dcimgui" / "dcimgui_nodefaultargfunctions_internal.cpp"
IMGUI_INCLUDE = REPO_ROOT / "vendor" / "imgui" / "imgui"
IMGUI_BINDINGS_INCLUDE = REPO_ROOT / "vendor" / "imgui" / "odin-imgui" / "dcimgui"
IMGUI_OBJECT = C3_ROOT / "build" / "imgui_impl.o"
IMGUI_INTERNAL_OBJECT = C3_ROOT / "build" / "imgui_internal_impl.o"
IMGUI_LIBRARY = REPO_ROOT / "vendor" / "imgui" / "lib" / "libimgui.a"
C3C = os.environ.get("C3C") or "c3c"
CXX = os.environ.get("CXX") or "c++"
C3_TARGETS = ("linux-x64", "windows-x64", "macos-aarch64", "wasm32")
SDL3_LIBRARY_DIRS = (
    Path("/usr/lib/x86_64-linux-gnu"),
    Path("/usr/lib64"),
    Path("/usr/lib"),
    Path("/usr/local/lib"),
)


def die(message, status=1):
    print(message, file=sys.stderr, flush=True)
    raise SystemExit(status)


def run(*args, cwd=None):
    """Run a child process and return its status, translating launch errors."""
    sys.stdout.flush()
    sys.stderr.flush()
    try:
        return subprocess.run(list(args), cwd=cwd, check=False).returncode
    except OSError as error:
        die(f"error: {args[0]}: {error.strerror}", 127)


def run_checked(*args, cwd=None):
    status = run(*args, cwd=cwd)
    if status:
        # Match the shell convention for a process terminated by a signal.
        raise SystemExit(128 - status if status < 0 else status)


def build_vma():
    """Compile and archive VMA exactly as the root ``vma`` command does."""
    print("== build vendor/vma", flush=True)
    (C3_ROOT / "vendor" / "vma" / "lib").mkdir(parents=True, exist_ok=True)
    (C3_ROOT / "build").mkdir(parents=True, exist_ok=True)
    run_checked(
        CXX,
        "-std=c++17",
        "-O2",
        "-fPIC",
        "-I",
        str(VMA_INCLUDE),
        "-c",
        str(VMA_SOURCE),
        "-o",
        str(VMA_OBJECT),
        cwd=C3_ROOT,
    )
    run_checked("ar", "rcs", str(VMA_LIBRARY), str(VMA_OBJECT), cwd=C3_ROOT)


def ensure_vma():
    if not VMA_LIBRARY.is_file():
        build_vma()


def imgui_submodule_check():
    """Fail with the exact initialization command when ImGui submodules are empty."""
    if not (IMGUI_INCLUDE / "imgui.cpp").is_file():
        die("error: vendor/imgui/imgui is empty; run: git submodule update --init vendor/imgui/imgui")
    if not (IMGUI_BINDINGS_INCLUDE / "dcimgui_nodefaultargfunctions.cpp").is_file():
        die("error: vendor/imgui/odin-imgui is empty; run: git submodule update --init vendor/imgui/odin-imgui")
    if not IMGUI_INTERNAL_SOURCE.is_file():
        die("error: vendor/imgui/odin-imgui is missing its dcimgui internal source; run: git submodule update --init vendor/imgui/odin-imgui")


def build_imgui():
    """Compile the pinned Dear ImGui/dear-bindings C API into libimgui.a."""
    imgui_submodule_check()
    print("== build vendor/imgui", flush=True)
    IMGUI_LIBRARY.parent.mkdir(parents=True, exist_ok=True)
    (C3_ROOT / "build").mkdir(parents=True, exist_ok=True)
    flags = (
        "-std=c++17",
        "-O2",
        "-fPIC",
        "-fno-exceptions",
        "-fno-rtti",
        "-I",
        str(IMGUI_INCLUDE),
        "-I",
        str(IMGUI_BINDINGS_INCLUDE),
    )
    run_checked(CXX, *flags, "-c", str(IMGUI_SOURCE), "-o", str(IMGUI_OBJECT), cwd=REPO_ROOT)
    run_checked(CXX, *flags, "-c", str(IMGUI_INTERNAL_SOURCE), "-o", str(IMGUI_INTERNAL_OBJECT), cwd=REPO_ROOT)
    run_checked("ar", "rcs", str(IMGUI_LIBRARY), str(IMGUI_OBJECT), str(IMGUI_INTERNAL_OBJECT), cwd=REPO_ROOT)


def ensure_imgui():
    if not IMGUI_LIBRARY.is_file():
        build_imgui()


def sdl3_link_flags():
    """Return C3 linker arguments for Linux's runtime-only SDL3 install.

    C3's ``-z`` option forwards the following argument to the native linker.
    This is the equivalent of the root build's ``-extra-linker-flags``
    handling, including its fallback from ``libSDL3.so`` to ``libSDL3.so.0``.
    """
    if platform.system() != "Linux":
        return []

    runtime_library = None
    for directory in SDL3_LIBRARY_DIRS:
        development_library = directory / "libSDL3.so"
        if development_library.exists():
            return []
        if runtime_library is None and (directory / "libSDL3.so.0").exists():
            runtime_library = directory / "libSDL3.so.0"
    if runtime_library is None:
        return []

    link_directory = C3_ROOT / "build" / "lib"
    link_directory.mkdir(parents=True, exist_ok=True)
    link = link_directory / "libSDL3.so"
    if not link.exists():
        if link.is_symlink():
            link.unlink()
        link.symlink_to(runtime_library)
    return ["-z", f"-L{link_directory}", "-z", f"-Wl,-rpath,{runtime_library.parent}"]


def host_test():
    """Build and run every C3 ``@test`` function on the host."""
    ensure_imgui()
    ensure_vma()
    print("== c3 test", flush=True)
    run_checked(C3C, "test", "-z", "-lSDL3", *sdl3_link_flags(), cwd=C3_ROOT)


def check():
    """Cross-build the C3 project and compile its platform-specific tests."""
    for target in C3_TARGETS:
        print(f"== c3 check ({target})", flush=True)
        run_checked(C3C, "build", "--target", target, cwd=C3_ROOT)
    print("== c3 check (headless)", flush=True)
    run_checked(C3C, "build", "-D", "RHI_HEADLESS", cwd=C3_ROOT)
    print("== c3 check tests (macos-aarch64)", flush=True)
    run_checked(C3C, "test", "-C", "--target", "macos-aarch64", cwd=C3_ROOT)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build and test the C3 port.")
    parser.add_argument(
        "command",
        choices=("vma", "imgui", "test", "check"),
        help="vma/imgui: build vendor archives; test: run host tests; check: build/check all C3 targets",
    )
    command = parser.parse_args(argv).command
    if command == "vma":
        build_vma()
    elif command == "imgui":
        build_imgui()
    elif command == "test":
        host_test()
    else:
        check()


if __name__ == "__main__":
    main()

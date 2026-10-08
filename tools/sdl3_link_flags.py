#!/usr/bin/env python3
"""Print C3 linker arguments (one per line) for Linux's runtime-only SDL3 install.

C3's ``-z`` option forwards the following argument to the native linker. When
no ``libSDL3.so`` development symlink exists but ``libSDL3.so.0`` does, create
``<link_dir>/libSDL3.so`` and emit ``-z -L<link_dir> -z -Wl,-rpath,<runtime dir>``.
Prints nothing on non-Linux hosts or when no fallback is needed.

usage: sdl3_link_flags.py <link_dir>
"""

import platform
import sys
from pathlib import Path

SDL3_LIBRARY_DIRS = (
    Path("/usr/lib/x86_64-linux-gnu"),
    Path("/usr/lib64"),
    Path("/usr/lib"),
    Path("/usr/local/lib"),
)


def sdl3_link_flags(link_directory):
    if platform.system() != "Linux":
        return []

    runtime_library = None
    for directory in SDL3_LIBRARY_DIRS:
        if (directory / "libSDL3.so").exists():
            return []
        if runtime_library is None and (directory / "libSDL3.so.0").exists():
            runtime_library = directory / "libSDL3.so.0"
    if runtime_library is None:
        return []

    link_directory.mkdir(parents=True, exist_ok=True)
    link = link_directory / "libSDL3.so"
    if not link.exists():
        if link.is_symlink():
            link.unlink()
        link.symlink_to(runtime_library)
    return ["-z", f"-L{link_directory}", "-z", f"-Wl,-rpath,{runtime_library.parent}"]


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    for flag in sdl3_link_flags(Path(argv[1]).resolve()):
        print(flag)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

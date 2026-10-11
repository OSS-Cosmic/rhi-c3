#!/usr/bin/env python3
"""Stage a built static archive at its in-tree location (vendor/<lib>/lib).

project.json's linker-search-paths point at vendor/<lib>/lib, so a direct
``c3c test`` from the repo root finds the archives Meson built. Meson emits
thin archives (members referenced by relative path), which break when moved,
so the members are re-archived into a regular archive.

usage: stage_lib.py <archive> <dest_dir> <stamp>
"""

import subprocess
import sys
import shutil
from pathlib import Path


def main(argv):
    archive, dest, stamp = (Path(a).resolve() for a in argv[1:4])
    dest.mkdir(parents=True, exist_ok=True)
    target = dest / archive.name
    # Meson emits thin archives on some platforms, where members refer back
    # to the build directory. Apple ar emits regular archives, which can be
    # copied directly and may include platform-specific symbol table entries.
    with archive.open("rb") as built_archive:
        magic = built_archive.read(8)
    if magic != b"!<thin>\n":
        shutil.copy2(archive, target)
        stamp.write_text("")
        return 0
    members = subprocess.run(
        ["ar", "t", str(archive)], check=True, capture_output=True, text=True
    ).stdout.split()
    # Thin-archive members are relative to the build dir (cwd of the build).
    members = [str(Path(m).resolve()) for m in members]
    target.unlink(missing_ok=True)
    subprocess.run(["ar", "rcs", str(target), *members], check=True)
    stamp.write_text("")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

#!/usr/bin/env python3
"""Expose the wrap-built libSDL3_shared.so as <link_dir>/libSDL3.so for `-lSDL3`.

usage: link_sdl3.py <built_lib> <link_dir> <stamp>
"""

import sys
from pathlib import Path


def main(argv):
    built, link_dir, stamp = Path(argv[1]).resolve(), Path(argv[2]), Path(argv[3])
    link_dir.mkdir(parents=True, exist_ok=True)
    link = link_dir / "libSDL3.so"
    if link.is_symlink() or link.exists():
        link.unlink()
    link.symlink_to(built)
    stamp.write_text("")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

#!/usr/bin/env python3
"""Run c3c cross-build / compile checks from the repository root.

usage: c3_check.py <c3c> [leg|group ...]   (no legs = all legs, in order;
groups: vulkan, dx12, metal)
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEGS = {
    "linux-x64": ["build", "--target", "linux-x64"],
    "windows-x64": ["build", "--target", "windows-x64"],
    "macos-aarch64": ["build", "--target", "macos-aarch64"],
    "wasm32": ["build", "--target", "wasm32"],
    "headless": ["build", "-D", "RHI_HEADLESS"],
    "tests-macos": ["test", "-C", "--target", "macos-aarch64"],
}
GROUPS = {
    "vulkan": ["linux-x64"],
    "dx12": ["windows-x64"],
    "metal": ["macos-aarch64", "tests-macos"],
}


def main(argv):
    c3c, legs = argv[1], argv[2:] or list(LEGS)
    legs = [leg for name in legs for leg in GROUPS.get(name, [name])]
    for leg in legs:
        if leg not in LEGS:
            print(f"error: unknown leg {leg}; choose from {', '.join(LEGS)}", file=sys.stderr)
            return 2
        print(f"== c3 check ({leg})", flush=True)
        try:
            status = subprocess.run([c3c, *LEGS[leg]], cwd=ROOT, check=False).returncode
        except OSError as error:
            print(f"error: {c3c}: {error.strerror}", file=sys.stderr)
            return 127
        if status:
            return status
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

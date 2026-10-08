#!/usr/bin/env python3
"""Cross-compile D3D12MemoryAllocator plus its C shim into libd3d12ma.a.

Meson cannot mix the host and a mingw toolchain in one non-cross build, so
meson.build runs this through a custom_target. The archive is written to the
Meson build dir and also staged at vendor/d3d12ma/lib/libd3d12ma.a.

usage: build_d3d12ma.py <cxx> <ar> <source_root> <output.a>
"""

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def main(argv):
    cxx, ar, root, output = argv[1], argv[2], Path(argv[3]), Path(argv[4])
    d3d12ma = root / "vendor" / "d3d12ma"
    sources = (d3d12ma / "D3D12MemAlloc.cpp", d3d12ma / "d3d12ma_c.cpp")
    with tempfile.TemporaryDirectory() as tmp:
        objects = []
        for source in sources:
            obj = Path(tmp) / f"d3d12ma_{source.stem}.o"
            subprocess.run(
                [cxx, "-std=c++17", "-O2",
                 "-I", str(d3d12ma / "include"), "-I", str(d3d12ma),
                 "-c", str(source), "-o", str(obj)],
                check=True,
            )
            objects.append(str(obj))
        output.unlink(missing_ok=True)
        subprocess.run([ar, "rcs", str(output), *objects], check=True)
    stage = d3d12ma / "lib"
    stage.mkdir(parents=True, exist_ok=True)
    shutil.copy2(output, stage / output.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

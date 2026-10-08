#!/usr/bin/env python3
"""Compile one example's shader manifest for one backend with slangc.

Manifest lines are `source entry stage output-name`; `#` lines and blanks are
skipped. A leading `c3/` in the source resolves from the repository root,
anything else is relative to the manifest.

`glsl` compiles to SPIR-V in a temp dir, then runs spirv-cross (WebGL2, GLSL ES 300).

usage: build_shaders.py <slangc> <spirv|metal|wgsl|glsl> <manifest> <outdir> <stamp> [spirv-cross]
"""

import tempfile

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BACKENDS = {
    "spirv": (".spv", []),
    "metal": (".metal", []),
    "wgsl": (".wgsl", ["-DRHI_WGSL=1"]),
    "glsl": (".glsl", []),
}
CROSS_STAGES = {"vertex": "vert", "fragment": "frag"}


def main(argv):
    slangc, backend, manifest, outdir, stamp = argv[1], argv[2], Path(argv[3]), Path(argv[4]), Path(argv[5])
    spirv_cross = argv[6] if len(argv) > 6 else "spirv-cross"
    ext, extra = BACKENDS[backend]
    outdir.mkdir(parents=True, exist_ok=True)
    for line in manifest.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        source, entry, stage, name = line.split()
        src = ROOT / source[3:] if source.startswith("c3/") else manifest.parent / source
        out = outdir / (name + ext)
        if backend == "glsl":
            with tempfile.TemporaryDirectory() as tmp:
                spv = Path(tmp) / (name + ".spv")
                subprocess.run(
                    [slangc, str(src), "-entry", entry, "-stage", stage, "-target", "spirv",
                     "-o", str(spv)],
                    check=True,
                )
                subprocess.run(
                    [spirv_cross, str(spv), "--version", "300", "--es", "--entry", "main",
                     "--stage", CROSS_STAGES[stage], "--output", str(out)],
                    check=True,
                )
            continue
        subprocess.run(
            [slangc, str(src), "-entry", entry, "-stage", stage, "-target", backend,
             *extra, "-o", str(out)],
            check=True,
        )
    stamp.write_text("")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

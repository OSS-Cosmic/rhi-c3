"""Locates host tools (c3c, slangc, spirv-cross) and exposes their paths.

Override with the C3C, SLANGC and SPIRV_CROSS environment variables. Tools are
not downloaded; missing optional tools resolve to the empty string.
"""

def _find(rctx, env_name, binary, extra = []):
    override = rctx.getenv(env_name)
    if override:
        return override
    found = rctx.which(binary)
    if found:
        return str(found)
    for p in extra:
        if rctx.path(p).exists:
            return p
    return ""

def _impl(rctx):
    home = rctx.getenv("HOME") or ""
    c3c = _find(rctx, "C3C", "c3c", [home + "/opt/c3/c3c"])
    slangc = _find(rctx, "SLANGC", "slangc")
    spirv_cross = _find(rctx, "SPIRV_CROSS", "spirv-cross")
    # The project depends on the `sdl3` c3l vendor package (a zip archive).
    if c3c:
        res = rctx.execute([c3c, "vendor-fetch", "sdl3"])
        if res.return_code != 0:
            fail("c3c vendor-fetch sdl3 failed: " + res.stderr)
    rctx.file("BUILD.bazel", "exports_files([\"config.bzl\", \"sdl3.c3l\"])\n")
    rctx.file("config.bzl", "C3C = %r\nSLANGC = %r\nSPIRV_CROSS = %r\n" % (c3c, slangc, spirv_cross))

c3c_repo = repository_rule(
    implementation = _impl,
    environ = ["C3C", "SLANGC", "SPIRV_CROSS", "PATH", "HOME"],
    local = True,
)

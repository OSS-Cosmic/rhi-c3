"""Slang shader compilation (slangc, plus spirv-cross for the GLSL ES path)."""

load("@c3c//:config.bzl", "SLANGC", "SPIRV_CROSS")

_EXT = {"spirv": "spv", "metal": "metal", "wgsl": "wgsl", "glsl": "glsl"}
_CROSS_STAGE = {"vertex": "vert", "fragment": "frag"}

def _slang_impl(ctx):
    fmt = ctx.attr.fmt
    out = ctx.actions.declare_file("shaders/%s.%s" % (ctx.attr.out_name, _EXT[fmt]))
    src = ctx.file.src
    if not SLANGC:
        fail("slangc not found on PATH (set SLANGC)")
    base = [SLANGC, src.path, "-entry", ctx.attr.entry, "-stage", ctx.attr.stage]
    if fmt == "glsl":
        if not SPIRV_CROSS:
            fail("spirv-cross not found on PATH (set SPIRV_CROSS); needed for the WebGL2 GLSL path")
        cmd = "%s -target spirv -o $TMPDIR/s.spv && %s $TMPDIR/s.spv --version 300 --es --entry main --stage %s --output %s" % (
            " ".join(base),
            SPIRV_CROSS,
            _CROSS_STAGE[ctx.attr.stage],
            out.path,
        )
    else:
        extra = " -DRHI_WGSL=1" if fmt == "wgsl" else ""
        cmd = "%s -target %s%s -o %s" % (" ".join(base), fmt, extra, out.path)
    ctx.actions.run_shell(
        outputs = [out],
        inputs = depset([src], transitive = [d[DefaultInfo].files for d in ctx.attr.deps]),
        command = cmd,
        mnemonic = "Slangc",
        progress_message = "slangc %s -> %s" % (src.short_path, fmt),
        use_default_shell_env = True,
        execution_requirements = {"no-remote": "1"},
    )
    return [DefaultInfo(files = depset([out]))]

slang_shader = rule(
    implementation = _slang_impl,
    attrs = {
        "src": attr.label(allow_single_file = [".slang"], mandatory = True),
        "entry": attr.string(mandatory = True),
        "stage": attr.string(mandatory = True, values = ["vertex", "fragment"]),
        "fmt": attr.string(mandatory = True, values = _EXT.keys()),
        "out_name": attr.string(mandatory = True),
        "deps": attr.label_list(allow_files = True),
    },
)

def shader_set(shaders):
    """Declares shaders_{spirv,metal,wgsl,glsl} filegroups for one example.

    Args:
      shaders: list of (src label, entry, stage, output name) tuples, the same
        fields the old shaders.txt manifest carried.
    """
    for fmt in _EXT.keys():
        names = []
        for src, entry, stage, out_name in shaders:
            n = "%s_%s" % (out_name, fmt)
            slang_shader(
                name = n,
                src = src,
                entry = entry,
                stage = stage,
                fmt = fmt,
                out_name = out_name,
                tags = ["manual"],
            )
            names.append(":" + n)
        native.filegroup(name = "shaders_" + fmt, srcs = names, visibility = ["//visibility:public"])

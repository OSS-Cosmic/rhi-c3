"""Per-example build macros: one c3_binary per backend."""

load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("//tools:c3.bzl", "c3_binary")

_MACOS_FRAMEWORKS = [
    "Cocoa", "IOKit", "ForceFeedback", "Carbon", "CoreAudio", "AudioToolbox",
    "AVFoundation", "CoreMedia", "CoreVideo", "GameController", "CoreHaptics",
    "UniformTypeIdentifiers", "ApplicationServices",
]

def rhi_example(name, backends, imgui = False, has_shaders = False):
    """Declares <backend> targets for example `name`.

    Backends: vulkan (linux-x64), dx12 (windows-x64, compile only),
    metal (macos-aarch64; compile only unless built on macOS), web (wasm32).
    Shaders are expected as :shaders_<format> filegroups (see slang.bzl).
    """
    main = "main.c3"
    extra = [main, "//examples/platform:platform.c3"]
    imgui_defs = ["RHI_IMGUI"] if imgui else []
    compile_only = select({
        "@platforms//os:macos": [],
        "//conditions:default": ["-C"],
    })

    if "vulkan" in backends:
        c3_binary(
            name = "vulkan",
            main = main,
            extra_srcs = extra,
            target = "linux-x64",
            defines = ["RHI_VK"] + imgui_defs,
            native_deps = ["//:vma", "@sdl3//:sdl3"] + (["//:imgui"] if imgui else []),
            linkopts = ["-l", "stdc++", "-l", "X11-xcb"],
            shaders = [":shaders_spirv"] if has_shaders else [],
        )
    if "dx12" in backends:
        c3_binary(
            name = "dx12",
            main = main,
            extra_srcs = extra,
            target = "windows-x64",
            # No DXIL shaders yet: examples embed SPIR-V and run on Vulkan
            # unless the D3D12 front paths are selected.
            defines = ["RHI_VK", "RHI_DX12"] + imgui_defs,
            linkopts = ["-C"],
            shaders = [":shaders_spirv"] if has_shaders else [],
        )
    if "metal" in backends:
        c3_binary(
            name = "metal",
            main = main,
            extra_srcs = extra,
            target = "macos-aarch64",
            defines = ["RHI_MTL"] + imgui_defs,
            linkopts = ["--libdir", ".", "--lib", "sdl3"] +
                       (["-l", "c++"] if imgui else []) +
                       [x for fw in _MACOS_FRAMEWORKS for x in ["-z", "-framework", "-z", fw]] +
                       compile_only,
            native_deps = ["//:imgui"] if imgui else [],
            shaders = [":shaders_metal"] if has_shaders else [],
        )
    if "web" in backends:
        c3_binary(
            name = "web",
            main = main,
            extra_srcs = extra,
            target = "wasm32",
            defines = ["RHI_WGPU", "RHI_WEBGL"] + imgui_defs,
            shaders = [":shaders_wgsl", ":shaders_glsl"] if has_shaders else [],
        )

        expand_template(
            name = "web_html",
            template = "//examples/platform:web/index.html",
            out = "web.html",
            substitutions = {"@WASM_NAME@": "web", "@EXAMPLE@": name},
        )
        native.filegroup(
            name = "web_bundle",
            srcs = [":web", ":web_html", "//examples/platform:web/glue.js", "//examples/platform:web/webgl_glue.js"],
        )

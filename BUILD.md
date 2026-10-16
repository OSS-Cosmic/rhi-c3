<!--
Copyright 2026 Michael Pollind
SPDX-License-Identifier: GPL-2.0-only
-->

# Build

Bazel (see `.bazelversion`) drives everything. Run it from the repository root.
`bazel build <target>`; tools (`c3c`, `slangc`, `spirv-cross`) are found on `PATH`
or through `C3C`, `SLANGC`, `SPIRV_CROSS`.

| Target | Builds |
| --- | --- |
| `//examples/<ex>:vulkan` | linux-x64, linked, SPIR-V shaders |
| `//examples/<ex>:dx12` | windows-x64, compile only |
| `//examples/<ex>:metal` | macos-aarch64, MSL shaders; compile only off macOS |
| `//examples/<ex>:web` / `:web_bundle` | wasm32, WGSL + GLSL shaders, packaged bundle |
| `//examples/<ex>:shaders_<fmt>` | shaders for one example (`spirv`, `metal`, `wgsl`, `glsl`) |
| `//:vma`, `//:imgui`, `//:d3d12ma` | C++ archives linked by c3c |
| `//:check_<leg>` | `linux_x64`, `windows_x64`, `macos_aarch64`, `tests_macos` (compiles the tests), `wasm32`, `headless` |
| `//:c3_host` | `c3c test` on the host (`bazel test`) |

Examples: `00_clear` `01_shader` `02_mesh` `03_imgui` `04_svt` `05_texture`.

## Layout

- `tools/c3.bzl` - `c3_binary`, `c3_check`, `c3_test` rules. Each action stages a
  symlink/copy tree mirroring the repo (so `$embed("../../build/examples/<ex>/shaders/..")`
  resolves) and runs `c3c` from there.
- `tools/slang.bzl` - `slang_shader` rule and `shader_set` macro (replaces `shaders.txt`).
- `tools/examples.bzl` - `rhi_example` macro generating the per-backend targets.
- `tools/c3c_repo.bzl` - locates host tools and fetches the `sdl3` c3l vendor package.

## SDL3

SDL3 `release-3.4.2` is downloaded and built from source with CMake
(`third_party/sdl3.BUILD`, needs `cmake`). Linux binaries get `libSDL3.so.0` copied
next to them and an `$ORIGIN` runpath.

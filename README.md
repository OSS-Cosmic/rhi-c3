<!--
Copyright 2026 Michael Pollind
SPDX-License-Identifier: GPL-2.0-only
-->

# rhi (C3)

C3 (0.8) render hardware interface with Vulkan, Metal, D3D12, WebGPU and
WebGL2 backends behind one backend-neutral API (`module rhi`).

| Backend | Feature flag | Target | Status |
| --- | --- | --- | --- |
| Vulkan | `RHI_VK` | Linux, Windows | Working |
| Metal | `RHI_MTL` | macOS arm64 | Working, native macOS needed to run |
| D3D12 | `RHI_DX12` | Windows x64 | In progress. Barriers and mip generation landed, rest still stubbed (`src/rhi/backend_stubs.c3`). Compile-checked only |
| WebGPU / WebGL2 | `RHI_WGPU` / `RHI_WEBGL` | wasm32 | Working with browser glue in `examples/platform/web` |

A backend compiles in only when its feature flag is on, the target OS matches,
and `RHI_HEADLESS` is off. See `HAS_*` consts in `src/rhi/rhi.c3`.

## Layout

```text
src/rhi/        backend-neutral front + per-backend code (vk_*, mtl_*, dx12_*, webgpu, webgl)
src/vendor/     bindings: vma, metal, sdl3, imgui
vendor/vulkan.c3l/ Vulkan.c3 bindings and runtime loader (submodule)
vendor/         native sources: VulkanMemoryAllocator, d3d12ma, imgui_c (+ imgui submodule)
examples/       00_clear .. 05_texture, shared platform harness, slang shaders
test/           c3 @test functions, mirror src/
```

## Prerequisites

Common:

- C3 0.8 (`c3c`, tested with 0.8.4) on `PATH` (or `C3C=/path/to/c3c`; falls back to `~/opt/c3/c3c`).
- Bazel 9 (`bazel`; version pinned in `.bazelversion`), C and C++17 compilers, `cmake` (builds SDL3 from source).
- Vulkan.c3 submodule: `git submodule update --init vendor/vulkan.c3l`
- C3's `sdl3` vendor package is fetched automatically with `c3c vendor-fetch sdl3`; the native SDL3 shared library is built by Bazel.
- Dear ImGui submodule, for `03_imgui` and `04_svt`:
  `git submodule update --init vendor/imgui_c/imgui`
- `slangc` and `spirv-cross` for shaders. Put them on `PATH` or set `SLANGC=` /
  `SPIRV_CROSS=`. `spirv-cross` is only needed for WebGL2 GLSL.

Per backend:

- **Vulkan**: Vulkan loader/driver at runtime. Vulkan.c3 loads the loader at run
  time, so nothing links `libvulkan`.
  Initialize VMA with `git submodule update --init vendor/VulkanMemoryAllocator`.
- **Metal**: macOS arm64, Xcode toolchain. Links `Metal`, `Foundation`,
  `QuartzCore` frameworks and the Objective-C runtime.
- **D3D12**: Windows 10+ with a D3D12 device. Cross-building from Linux needs
  mingw-w64 (`x86_64-w64-mingw32-g++`) for D3D12MA (`//:d3d12ma`, tagged `manual`).

## Build vendor libraries

Bazel builds the C++ archives that c3c links and passes them to every c3 action.

```sh
bazel build //:vma //:imgui      # libvma.a, libimgui.a under bazel-bin/
```

D3D12MemAlloc is opt-in (`manual` tag) and needs a mingw toolchain:

```sh
bazel build //:d3d12ma
```

## Build the library per backend

Library is a static lib. Each `c3c` target below selects the backend via OS.

```sh
c3c build --target linux-x64        # Vulkan
c3c build --target windows-x64      # Vulkan + D3D12
c3c build --target macos-aarch64    # Metal
c3c build --target wasm32           # WebGPU + WebGL2
c3c build -D RHI_HEADLESS           # no windowing/backends
```

Output lands in `build/`. Run all compile checks at once:

```sh
bazel build //:check_linux_x64 //:check_windows_x64 //:check_macos_aarch64 \
            //:check_wasm32 //:check_headless
```

Legs: `check_linux_x64`, `check_windows_x64`, `check_macos_aarch64`, `check_tests_macos`,
`check_wasm32` (the 00_clear web build), `check_headless`. `windows-x64` and
`macos-aarch64` are cross compile checks, they do not run anything.

### Vulkan (Linux / Windows)

```sh
bazel build //examples/01_shader:vulkan      # linked example + SPIR-V shaders (slangc)
bazel build //:check_linux_x64
```
Each example package exposes `:vulkan`, `:dx12`, `:metal` and `:web` targets
(where the example supports that backend) and `:shaders_{spirv,metal,wgsl,glsl}`.
`bazel-bin/examples/<ex>/vulkan` finds its SDL3 beside the binary.

### Metal (macOS)

Build on a Mac for a real run. From another host only the compile check works:

```sh
bazel build //examples/03_imgui:metal    # MSL shaders (slangc); compile only off macOS
bazel build //:check_macos_aarch64       # c3c build, no link or run
```

Metal shaders are MSL text compiled at run time, entry point name kept from the
shader manifest. Binding indices: push constants at vertex buffer 0, vertex
buffers from index 1 (`MTL_VERTEX_BUFFER_BASE`), textures/samplers bound by name.

### D3D12 (Windows)

D3D12 is enabled by the `RHI_DX12` feature in `project.json` and only compiles
on Windows targets.

```sh
bazel build //:d3d12ma                   # D3D12MA archive (mingw cross)
bazel build //examples/00_clear:dx12     # cross-compile an example, compile only
bazel build //:check_windows_x64         # c3c library check
```

Backend is not complete yet. Examples fall back to Vulkan on Windows until the
D3D12 front paths land. No DXIL shader output exists in the example manifest
pipeline yet.

## Tests

```sh
bazel test //:c3_host        # runs c3c test on host
c3c test                     # directly, after vendor packages/libraries are available
```

The `sdl3` vendor package supplies the platform SDL3 archive and linker metadata.

## Examples

Sources in `examples/`. All share the `platform` harness
(`examples/platform/platform.c3`): SDL on native, browser glue on wasm.

| Example | Shows | Backends |
| --- | --- | --- |
| `00_clear` | Swapchain clear, image barriers, quadrant clears | VK, MTL, WebGPU, WebGL2 |
| `01_shader` | Fullscreen triangle, Mandelbrot | VK, MTL, WebGPU, WebGL2 |
| `02_mesh` | Rotating cube, depth, push constants | VK, MTL, WebGPU, WebGL2 |
| `03_imgui` | Dear ImGui demo + `rhi` status | Native only, needs `RHI_IMGUI` |
| `04_svt` | Feedback-driven sparse virtual texturing | Native only, needs `RHI_IMGUI` |
| `05_texture` | Alpha-blended textured quad | WebGPU, WebGL2 |

More detail in [`examples/README.md`](examples/README.md).

### 1. Compile shaders

Each example with a `shaders.txt` lists `source entry stage output-name` per
line. Outputs expected per backend:

| Output | Backend | Command |
| --- | --- | --- |
| `<name>.spv` | Vulkan | `slangc -target spirv` |
| `<name>.metal` | Metal | `slangc -target metal` |
| `<name>.wgsl` | WebGPU | `slangc -target wgsl -DRHI_WGSL=1` |
| `<name>.glsl` | WebGL2 | `slangc -target spirv`, then `spirv-cross --version 300 --es` |

Keep `-DRHI_WGSL=1`: WebGPU has no push constants, so the slang sources swap
them for bound uniforms under that define.

### 2. Build and run natively

Native examples compile the example, the platform harness and `src/`
together. Vendor archives must exist first (see above).

```sh
c3c compile examples/00_clear/main.c3 examples/platform/platform.c3 'src/**' \
    --libdir . --lib sdl3 \
    -L bazel-bin -l vma -l imgui -l stdc++ \
    -o build/examples/00_clear/00_clear

./build/examples/00_clear/00_clear --frames 120
```

Swap the example directory for the others. `03_imgui` and `04_svt` also need
`-D RHI_IMGUI` and the imgui archive. Shaders are read from the example's
`shaders/` output directory next to the binary.

Runtime flags:

- `--frames N` exit after N frames (examples that support it)
- `--video-driver <name>` pick SDL video driver, for example `x11` or `wayland`

On macOS drop `-l stdc++` for `-l c++` if the linker asks, and build for
`macos-aarch64`. On Windows use `--target windows-x64`.

### 3. Build for the browser

```sh
bazel build //examples/00_clear:web_bundle    # also 01_shader, 02_mesh, 05_texture
```

Builds wasm, `.wgsl` (slangc) and `.glsl` (slangc + spirv-cross) shaders and packages
the bundle. Examples with shaders need `slangc` and `spirv-cross`.

Output lands in `bazel-bin/examples/<ex>/` as `web.{wasm,html}`; copy it together with
`examples/platform/web/{glue,webgl_glue}.js` (the `web_bundle` filegroup lists all four).
Direct c3c, without packaging or shaders:

```sh
c3c compile --target wasm32 examples/01_shader/main.c3 examples/platform/platform.c3 'src/**' \
    -o build/examples/01_shader/web/01_shader
```

Serve that dir (it holds `index.html`, `glue.js`,
`webgl_glue.js` from `examples/platform/web/`, the `.wasm`, and the `.wgsl` /
`.glsl` shaders), e.g. `python3 -m http.server -d bazel-bin/examples/01_shader` then open `web.html`. Browser boot is WebGPU first, WebGL2 fallback. A wasm build
that compiles is not proof it runs: the bundle must also pass the import and
lifecycle export checks (`examples/platform/web/bundle_test.mjs`).

## Vulkan bindings

Vulkan types, commands, and runtime loading come from the `vendor/vulkan.c3l` submodule.

## License

GPL-2.0-only.

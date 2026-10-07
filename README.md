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
src/vendor/     bindings: vulkan, vma, metal, sdl3, imgui
vendor/         native sources: vma, d3d12ma, imgui_c (+ imgui submodule)
examples/       00_clear .. 05_texture, shared platform harness, slang shaders
test/           c3 @test functions, mirror src/
tools/          build helpers (meson drives these)
```

## Prerequisites

Common:

- C3 0.8 (`c3c`, tested with 0.8.4) on `PATH`, or set `$C3C`.
- Meson >= 1.1, Python 3, C and C++17 compilers, `ar`.
- volk submodule (Vulkan loader): `git submodule update --init vendor/volk`
- SDL3 dev library (links as `-lSDL3`) for native windows.
- Dear ImGui submodule, for `03_imgui` and `04_svt`:
  `git submodule update --init vendor/imgui_c/imgui`
- `slangc` and `spirv-cross` for shaders. Set `SLANGC` / `SPIRV_CROSS` (or `-Dslangc=` /
  `-Dspirv_cross=`) to use existing binaries. `spirv-cross` is only needed for WebGL2 GLSL.

Per backend:

- **Vulkan**: Vulkan loader/driver at runtime, Vulkan headers to build VMA and volk.
  volk opens the loader at run time, nothing links libvulkan.
- **Metal**: macOS arm64, Xcode toolchain. Links `Metal`, `Foundation`,
  `QuartzCore` frameworks and the Objective-C runtime.
- **D3D12**: Windows 10+ with a D3D12 device. Cross-building from Linux needs
  mingw-w64 (`x86_64-w64-mingw32-g++`) for D3D12MA, or set `D3D12MA_CXX`.

## Build vendor libraries

Meson builds the C++ archives that c3c links. Build dir must not be `build/`
(c3c owns it).

```sh
meson setup build-meson
meson compile -C build-meson     # vendor/vma/lib/libvma.a, vendor/imgui_c/lib/libimgui.a
```

D3D12MemAlloc is opt-in and not built by default:

```sh
meson compile -C build-meson d3d12ma
# custom compiler:
meson setup build-meson --reconfigure -Dd3d12ma_cxx=/path/to/x86_64-w64-mingw32-g++
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
meson compile -C build-meson check                    # every leg
meson compile -C build-meson check-windows-x64        # one leg
```

Legs: `linux-x64`, `windows-x64`, `macos-aarch64`, `wasm32`, `headless`,
`tests-macos`. `windows-x64` and `macos-aarch64` are cross compile checks, they
do not run anything.

### Vulkan (Linux / Windows)

```sh
meson compile -C build-meson vulkan       # linux examples (linked) + SPIR-V shaders (slangc)
meson compile -C build-meson check-vulkan
```
Shader targets are skipped when `slangc` is missing (`$SLANGC` or `-Dslangc=`).
Alias targets: one per backend (`vulkan`, `dx12`, `metal`, `web`), one per example
(`<backend>-<example>`, e.g. `vulkan-01_shader`, `web-05_texture`), and `examples` for
everything.

### Metal (macOS)

Build on a Mac for a real run. From another host only the compile check works:

```sh
meson compile -C build-meson metal        # examples + MSL shaders (slangc), compile only
meson compile -C build-meson check-metal  # c3c build + test compile, no link or run
```

Metal shaders are MSL text compiled at run time, entry point name kept from the
shader manifest. Binding indices: push constants at vertex buffer 0, vertex
buffers from index 1 (`MTL_VERTEX_BUFFER_BASE`), textures/samplers bound by name.

### D3D12 (Windows)

D3D12 is enabled by the `RHI_DX12` feature in `project.json` and only compiles
on Windows targets.

```sh
meson compile -C build-meson d3d12ma      # D3D12MA archive (mingw cross, also built by default)
meson compile -C build-meson dx12         # cross-compile every example, compile only
meson compile -C build-meson check-dx12   # c3c library check
```

Backend is not complete yet. Examples fall back to Vulkan on Windows until the
D3D12 front paths land. No DXIL shader output exists in the example manifest
pipeline yet.

## Tests

```sh
meson test -C build-meson     # runs `c3c test -z -lSDL3` on host
c3c test -z -lSDL3            # directly, after vendor libs are built
```

SDL3 must be linkable. Runtime-only Linux installs may need the `libSDL3.so`
dev symlink; `tools/sdl3_link_flags.py` adds a local shim when it can.

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
    -L vendor/vma/lib -L vendor/imgui_c/lib -l vma -l imgui -l stdc++ -l SDL3 \
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
meson compile -C build-meson web    # 00_clear, 01_shader, 02_mesh, 05_texture
```

Builds wasm, `.wgsl` (slangc) and `.glsl` (slangc + spirv-cross) shaders and packages
the bundle. Shader steps are skipped when `slangc` / `spirv-cross` are missing.

Output lands in `build-meson/web/<name>/`, for example `build-meson/web/01_shader/`.
Direct c3c, without packaging or shaders:

```sh
c3c compile --target wasm32 examples/01_shader/main.c3 examples/platform/platform.c3 'src/**' \
    -o build/examples/01_shader/web/01_shader
```

Serve that dir (it holds `index.html`, `glue.js`,
`webgl_glue.js` from `examples/platform/web/`, the `.wasm`, and the `.wgsl` /
`.glsl` shaders), e.g. `python3 -m http.server -d build-meson/web/01_shader`. Browser boot is WebGPU first, WebGL2 fallback. A wasm build
that compiles is not proof it runs: the bundle must also pass the import and
lifecycle export checks (`examples/platform/web/bundle_test.mjs`).

## Regenerating Vulkan bindings

`src/vendor/vulkan/` is generated and committed.

```sh
python3 tools/gen_vulkan.py [path/to/vk.xml]   # default /usr/share/vulkan/registry/vk.xml
```

Output is deterministic: matching registry leaves `git diff` empty.

## License

GPL-2.0-only.

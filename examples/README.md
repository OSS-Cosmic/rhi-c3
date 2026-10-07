# rhi C3 examples

This directory is the C3-side home for the example shader assets and shader
manifests. C3 builds use only files beneath this directory.

## Examples

| Example | Demonstrates | Shader manifest | Intended backends |
| --- | --- | --- | --- |
| `00_clear` | Swapchain clear and image barriers; four quadrant clears on native backends. | — | Vulkan, Metal, WebGPU, WebGL2 |
| `01_shader` | Fullscreen vertex-id triangle rendering a Mandelbrot set. | `01_shader/shaders.txt` | Vulkan, Metal, WebGPU, WebGL2 |
| `02_mesh` | Rotating indexed cube with a depth attachment and push constants. | `02_mesh/shaders.txt` | Vulkan, Metal, WebGPU, WebGL2 |
| `03_imgui` | Dear ImGui demo window and an `rhi` status window. | — | Native only; requires ImGui integration |
| `04_svt` | Feedback-driven software virtual texturing with an atlas, page table, and ImGui controls. | `04_svt/shaders.txt` | Native only; requires ImGui integration |
| `05_texture` | Alpha-blended textured quad with named texture and sampler bindings. | `05_texture/shaders.txt` | WebGPU/WebGL2 |

The manifests use four whitespace-separated fields per non-comment line:

```text
c3/examples/assets/02_mesh.slang vertexMain vertex 02_mesh.vert
```

Paths beginning with `c3/` are resolved from the repository root and then
normalized beneath `c3`; paths such as `05_texture.slang` are relative to the
manifest. The source, entry-point, stage, and output-name fields are fixed. `00_clear` has no shader source of its own.

## Target and backend matrix

The C3 project advertises `RHI_VK`, `RHI_MTL`, `RHI_WGPU`, and `RHI_WEBGL`. Backend selection is
also gated by the target, so the matrix for `c3-check` is:

| C3 target | Vulkan | Metal | WebGPU | WebGL2 |
| --- | --- | --- | --- | --- |
| `linux-x64` | enabled | unavailable | gated | gated |
| `windows-x64` | enabled | unavailable | gated | gated |
| `macos-aarch64` | unavailable | enabled | gated | gated |
| `wasm32` | unavailable | unavailable | enabled | enabled |

"Gated" means the backend is unavailable for that target. The WebGPU/WebGL2
sources are feature-gated to wasm32, so native examples target Vulkan on Linux
and Windows and Metal on macOS, while `meson compile -C build-meson web` builds the browser backends with
the platform glue and bundle assets included here.

## Prerequisites

- C3 0.8 (`c3c`; the port is tested with 0.8.4).
- SDL3 for native windows. The C3 SDL binding links `SDL3`; on Linux, the
  system development link or the runtime-library symlink created by the root
  build helper must be available.
- VMA for Vulkan allocations. From the repository root,
  `meson compile -C build-meson` creates `vendor/vma/lib/libvma.a`.
- Dear ImGui for `03_imgui` and `04_svt`: initialize the `vendor/imgui_c/imgui`
  submodule (`git submodule update --init vendor/imgui_c/imgui`), then run
  `meson compile -C build-meson`. The examples are native-only and the runner
  enables `RHI_IMGUI` only for these two targets.
- `slangc` and SPIRV-Cross for shader preprocessing; set `SLANGC` / `SPIRV_CROSS`
  to use existing binaries in an offline checkout.

## Build, check, and test commands

Run Meson from the repository root.

```sh
meson compile -C build-meson                # vendor archives (vma, imgui if present)
meson test -C build-meson                   # C3 @test functions on the host
meson compile -C build-meson check          # C3 static library: all targets
meson compile -C build-meson web            # browser bundles: 00, 01, 02, 05
meson compile -C build-meson vulkan         # native Vulkan examples 00-04
c3c build --target linux-x64                # one C3 target directly
c3c test                                    # C3 tests directly
```

Browser examples are built with `RHI_WGPU` and `RHI_WEBGL`. The shared platform
exports the wasm lifecycle and pointer-event callbacks;
the browser bundle supplies WebGPU-first/WebGL2-fallback boot, zero-size canvas
handling, and the ABI/import/export checks of the browser bundle.

## Shader outputs

Each manifest entry is compiled into the C3 example build's shader output
directory. The expected outputs are:

| Output | Consumer | Compiler convention |
| --- | --- | --- |
| `<name>.spv` | Vulkan | `slangc -target spirv`; the Vulkan entry point is `main` |
| `<name>.metal` | Metal | `slangc -target metal`; C3 passes the source to Metal at runtime and keeps the manifest entry name |
| `<name>.wgsl` | WebGPU | `slangc -target wgsl -DRHI_WGSL=1`; WGSL keeps names such as `vertexMain` and `fragmentMain` |
| `<name>.glsl` | WebGL2 | `spirv-cross --version 300 es`; GLSL entry points are `main` |

The `RHI_WGSL=1` define is required. WebGPU has no push constants, and Slang's
unbound WGSL uniform generated from `[[vk::push_constant]]` is rejected by the
browser. The guarded declarations in `02_mesh.slang` and `05_texture.slang`
replace those resources with explicitly bound uniform/texture resources for
the WGSL build. Do not remove that preprocessing convention when adding a
manifest entry.

## Browser status

The WGSL and GLSL forms, browser boot assets, and wasm lifecycle contract are
in place. A successful `c3c build --target wasm32` is still not proof that an
example can run in a browser; the browser bundle must also pass the backend
import and lifecycle export checks.

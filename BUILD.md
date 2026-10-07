<!--
Copyright 2026 Michael Pollind
SPDX-License-Identifier: GPL-2.0-only
-->

# Build

Setup once: `meson setup build-meson`. Then `meson compile -C build-meson <target>`.

| Target | Builds |
| --- | --- |
| `vulkan` | examples 00-04, linux-x64, linked, SPIR-V shaders |
| `dx12` | examples 00-04, windows-x64, compile only |
| `metal` | examples 00-04, macos-aarch64, compile only, MSL shaders |
| `web` | examples 00, 01, 02, 05, wasm32, WGSL + GLSL shaders, packaged bundle |
| `<backend>-<example>` | one example, e.g. `vulkan-01_shader`, `web-05_texture` |
| `examples` | every example, every backend |
| `check` | C3 library, every target |
| `check-<leg>` | one leg: `linux-x64`, `windows-x64`, `macos-aarch64`, `wasm32`, `headless`, `tests-macos` |

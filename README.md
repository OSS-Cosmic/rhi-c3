<!--
Copyright 2026 Michael Pollind
SPDX-License-Identifier: GPL-2.0-only
-->

# rhi (C3 port)

C3 (0.8) port of the Odin `rhi` tree, built side by side with it.

## Layout

- Sources: `c3/src/rhi/<pkg>/*.c3`, declared `module rhi::<pkg>;`
  (e.g. `rhi/alloc/offset_alloc.odin` becomes `c3/src/rhi/alloc/offset_alloc.c3`).
- Tests: `c3/test/rhi/<pkg>/*.c3`, declared in the **same** module as the code
  under test so `@private` helpers stay reachable. Test names drop the Odin
  `test_` prefix.

## Running

The approved C3 driver is `c3/build.py`. It anchors its paths to the C3
directory, so it is independent of the caller's working directory. From the
repository root, run it directly as:

```sh
./c3/build.py vma
./c3/build.py test
./c3/build.py check
```

The same commands can be run from the C3 directory, or invoked by an
automation caller without changing directories:

```sh
cd c3
./build.py vma
./build.py test
./build.py check

# Equivalently, from any caller working directory:
python3 /path/to/rhi-odin/c3/build.py test
```

`vma` writes the static library to `c3/vendor/vma/lib/libvma.a`; `test` builds
it automatically when it is missing. The C3 project links that local library
and `stdc++`. For a direct C3 compiler invocation after the VMA library is
available, run it from `c3/`:

```sh
c3c test -z -lSDL3
```

`check` builds the static library for all supported targets:
`linux-x64`, `windows-x64`, `macos-aarch64`, and `wasm32`. It also performs a
headless compile with `RHI_HEADLESS` and compiles the tests for
`macos-aarch64` without linking or running them. The equivalent individual
checks from `c3/` are:

```sh
c3c build --target linux-x64
c3c build --target windows-x64
c3c build --target macos-aarch64
c3c build --target wasm32
c3c build -D RHI_HEADLESS
c3c test -C --target macos-aarch64
```

### Host prerequisites and limitations

- C3 0.8 (`c3c`; the port is tested with c3c 0.8.4) must be on `PATH`.
- Building VMA needs a C++17 compiler and `ar`: the driver uses `c++` (or
  `$CXX`) and `ar` to compile the vendored `c3/vendor/vma/vma_impl.cpp` and
  writes `c3/vendor/vma/lib/libvma.a`. The system Vulkan development headers,
  including `<vulkan/vulkan.h>`, must also be installed.
- Host test executables need SDL3 available to the linker. The binding links
  the library as `SDL3`; a runtime-only Linux installation may need the
  development symlink or an equivalent library search path. The driver can
  add a local link/rpath shim for the common runtime-only Linux layout, but it
  cannot provide SDL3 itself.
- Native macOS Metal builds need Apple's `Metal.framework`,
  `Foundation.framework`, and `QuartzCore.framework`, plus the Objective-C
  runtime. The Metal binding is macOS arm64-only. The
  `c3c test -C --target macos-aarch64` check compiles the Darwin sources and
  tests without linking or running them, so it can be used from another host;
  it does not replace a native macOS test run. The `wasm32` and headless legs
  are compile checks as well.

## Vendor bindings

Third-party bindings live in `c3/src/vendor/<lib>/`, one module per library,
with tests in `c3/test/vendor/<lib>/`.

VMA (`module vma`, `c3/src/vendor/vma/vma.c3`) is a hand port of the Odin VMA
binding (VMA 3.3.0): `vma::create_allocator`, `create_buffer`,
... bound with `@cname("vmaCreateAllocator")` etc. Flags are C bit masks
(`vma::ALLOCATION_CREATE_MAPPED_BIT`), not Odin's bit_set indices. Struct sizes
are pinned against the C header in `c3/test/vendor/vma/vma_test.c3`.

Vulkan (`module vk`, `c3/src/vendor/vulkan/{core,enums,structs,procedures}.c3`)
is generated from the Khronos registry. The generated Vulkan bindings are
committed source files and must remain in the repository; they are not
regenerated as a build step. Regenerate them with

```sh
python3 c3/tools/gen_vulkan.py [path/to/vk.xml]   # default /usr/share/vulkan/registry/vk.xml
```

The optional argument is an explicit registry path. Use it when
`/usr/share/vulkan/registry/vk.xml` is not present, for example:
`python3 c3/tools/gen_vulkan.py /path/to/Vulkan-Headers/registry/vk.xml`.
When working from `c3/`, the equivalent command is
`python3 tools/gen_vulkan.py /path/to/vk.xml`. The output is deterministic, so
rerunning it with the matching registry must leave `git diff` empty.

It covers the `vulkan` API with the xlib, xlib_xrandr, wayland and win32 platforms.
Video, provisional (beta), disabled and vulkansc-only extensions are skipped,
along with anything that depends on them. Nothing links against libvulkan.
Procedures are loaded at run time, as in Odin's `vendor:vulkan`. The header of
`core.c3` has the full list of conventions. In short:

| Odin `vendor:vulkan` | C3 `vk` |
| --- | --- |
| `vk.Instance`, `vk.Device` (dispatchable) | `typedef Instance @constinit = inline void*;` compare with `null` |
| `vk.Image`, `vk.Buffer` (non-dispatchable) | `typedef Image @constinit = ulong;` compare with `0` / `vk::NULL_HANDLE` |
| `vk.Format.R8G8B8A8_UNORM`, `.R8G8B8A8_UNORM` | `constdef Format : int`: `vk::Format.R8G8B8A8_UNORM`, or `R8G8B8A8_UNORM` where a `Format` is expected |
| `.D2` (`vk.ImageType`), `.ASTC_4x4_UNORM_BLOCK` | `ImageType.D2`, `Format.ASTC_4X4_UNORM_BLOCK` (C3 constants are all caps) |
| `vk.ImageAspectFlags{.COLOR, .DEPTH}` | `vk::IMAGE_ASPECT_COLOR_BIT \| vk::IMAGE_ASPECT_DEPTH_BIT` (`typedef ImageAspectFlags @constinit = uint;`, 64-bit flags use `ulong`) |
| `.DEVICE_LOCAL in flags` (`vk.MemoryPropertyFlag`) | `flags & vk::MEMORY_PROPERTY_DEVICE_LOCAL_BIT` (`MemoryPropertyFlagBits` is an alias of `MemoryPropertyFlags`) |
| `vk.DeviceSize`, `vk.Bool32`, `vk.Flags` | plain aliases of `ulong`, `uint`, `uint` |
| `vk.CreateInstance(...)`, `vtable.CmdDraw(...)` | `vk::createInstance(...)`, `vtable.cmdDraw(...)` (C3 variables and fields must start lowercase) |
| `vk.ProcCreateInstance`, `vk.ProcVoidFunction` | `vk::ProcCreateInstance`, `vk::ProcVoidFunction` (same names) |
| `vk.Device_VTable`, `vk.load_proc_addresses_device_vtable` | `vk::DeviceVTable`, `vk::load_proc_addresses_device_vtable(device, &vtable)` |
| `vk.MAKE_API_VERSION(0, 1, 3, 0)`, `vk.API_VERSION_MAJOR(v)` | `vk::@make_api_version(0, 1, 3, 0)`, `vk::@api_version_major(v)` (constant when the arguments are) |
| `vk.KHR_SWAPCHAIN_EXTENSION_NAME` (cstring) | `vk::KHR_SWAPCHAIN_EXTENSION_NAME` (`ZString`) |
| `vk.XlibDisplay`, `vk.wl_display`, `vk.HWND`, `vk.HINSTANCE` | `vk::XlibDisplay`, `vk::WlDisplay` (opaque, used through pointers), `vk::Hwnd`, `vk::Hinstance` |

Structs keep the C field names (`sType`, `pNext`). A field whose name is a C3
keyword gets a trailing underscore (`module_`). C3 has no default field
values, so `sType` has to be set by hand: `.sType = BUFFER_CREATE_INFO`. C
bitfields become anonymous bitstructs, so their fields are still accessed
directly (`inst.mask`).

## Metal binding-index convention

The Metal backend (`c3/src/rhi/mtl_*.c3`) is ported from rhi-zig, not Odin,
and keeps rhi-zig's binding indices so slangc's `-target metal` output binds
without remapping:

- **Push constants** go to vertex-stage buffer index 0 via `setVertexBytes`.
  slangc emits `[[vk::push_constant]]` as `constant T* [[buffer(0)]]`.
- **Vertex buffers** start at `MTL_VERTEX_BUFFER_BASE = 1`: vertex-buffer slot
  `n` is Metal buffer index `1 + n`, both in the `MTLVertexDescriptor` layouts
  and in `setVertexBuffer:offset:atIndex:`.
- **Textures and samplers** (new; rhi-zig has none on Metal): slangc numbers
  `[[texture(n)]]` / `[[sampler(n)]]` from 0 per stage in declaration order.
  They are bound by name through the pipeline's `texture_bindings`, as on
  WebGPU/WebGL2: `binding` is the texture index, `sampler_binding` the sampler
  index.
- **Shaders** are MSL source text compiled at run time with
  `newLibraryWithSource:options:error:`, and `ShaderStageDesc.entry_point` is
  required. slangc cannot produce `metallib` on Linux; rhi-zig does the same.

## Odin to C3 mapping

| Odin | C3 |
| --- | --- |
| `allocator := context.allocator` | trailing `Allocator allocator = mem`, stored on the struct where Odin does |
| `mem.Allocator_Error` / `or_return` | optional return (`void?`, `T?`), rethrown with `!` |
| `(value, ok: bool)` returns | `T?` with a module fault declared via `excuse` (`POOL_EMPTY`, `NO_SPACE_LEFT`) |
| `[dynamic]T` | `List{T}` (`ordered_remove`/`inject_at` become `remove_at`/`insert_at`) |
| `make([]T, n, allocator)` | `mem::alloc::alloc_array_try(allocator, T, n)!`, freed with `mem::alloc::free` on the same allocator in `deinit` |
| `intrinsics.count_leading/trailing_zeros` | `.clz()` / `.ctz()` |
| `@(private = "file")` | `@private` (module-private; not allowed on methods, so helper methods are public) |
| `Offset_Allocator`, `offset_allocator_allocate(&a, n)` | `OffsetAllocator`, `a.allocate(n)` (types PascalCase, procs become methods) |
| `u32`, `u16`, `u8`, `u64`, `uint` | `uint`, `ushort`, `char`, `ulong`, `usz` |
| `#config(RHI_HEADLESS, false)`, `-define:RHI_HEADLESS=true` | `const bool RHI_HEADLESS = $feat(RHI_HEADLESS);`, `c3c build -D RHI_HEADLESS` |
| `ODIN_ARCH`/`ODIN_OS`, `when` chains | `env::ARCH_TYPE`, `env::WIN32`/`LINUX`/`DARWIN`; `IS_WEB` is wasm32 or wasm64; `$if` or ternary `const` |
| `Error` union (`General_Error`, `Pipeline_Error`, `Allocator_Error`) | one `faultdef` per enum, all sharing C3's fault space; `Error` returns become `T?` |
| `bit_set[E; u8]` | `char` bitmask of `1 << E.X.ordinal` |
| `Maybe(T)` | value plus `bool has_*` flag |
| `for f in Format`, `fmt.tprint(f)` | `foreach (f : Format::values)`, `Format::names[f.ordinal]` |
| `core:container/queue` `Queue(T)` (`push_back`/`pop_front`) | `std::collections::deque` `Deque{T}` (`push`/`pop_first`) |
| `GPU_Ref :: struct($T: typeid)`, `gpu_ref_ref(r)` | generic struct `GpuRef <Type>` used as `GpuRef{T}`, methods `r.ref()` |
| parapoly procs with no receiver (`gpu_ref_create(dev, value, fin)`) | generic free fns `fn ... gpu_ref_create(...) <Type>`, called as `gpu_ref_create{T}(...)` (C3 has no static methods) |
| `transmute(proc(rawptr))typed_proc` | cast to the `fn void(void*)` alias, e.g. `(DerefFn)&GpuRef{T}.deref`; `TimelineDeferral.enqueue_typed` macro does it |
| `Allocator_Error` from `append`/`queue.push_back`/`make` | none: `List`/`Deque` growth panics on OOM, so those procs return `void` |

## Backend gating

Each backend is compiled in only once its C3 port has landed. `rhi.c3` ANDs a
"ported" feature flag into every `HAS_*` const (`RHI_VK`, `RHI_DX12`,
`RHI_MTL`, `RHI_WGPU`, `RHI_WEBGL`) and builds `PLATFORM_API` from those consts,
so `platform_has_api` / `is_target_selected` only report compiled-in backends.
The project enables the browser flags so the C3 web acceptance command can
validate the glue contract; `c3/src/rhi/webgpu.c3` and `webgl.c3` still need
to land before those targets compile. Vulkan is still staged with stubs for
the remaining missing `*_vk` functions and stand-in payload structs in
`vk_pending.c3`, under the backend's positive gate
(`@feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32))`); each later ticket
deletes the stubs it replaces.

Top-level declarations can only be gated with `@feat(...)`, which takes
feature flags (`LINUX`, `WIN32`, `DARWIN`, `WASM`, `-D` flags), never consts
like `HAS_VK`. So Odin's `when !HAS_VK { Buffer_Vk :: struct {} }` stand-ins
live in `backend_stubs.c3`, one `module rhi @feat(!(...));` section per
backend whose gate is the negation of its `HAS_*` const (keep the two in
sync). C3 rejects zero-sized structs: every stand-in and every empty Odin
struct gets a `char _unused;` member. Inside function bodies, `$if HAS_VK:`
is fine, and a disabled branch may call `*_vk` functions that do not exist.

## Front types (backend-neutral dispatch)

| Odin | C3 |
| --- | --- |
| `Image_View`, `Queue_Submit_Desc`, `Buffer_Vk` | `ImageView`, `QueueSubmitDesc`, `BufferVk` |
| enum values `.Color_Attachment` | `COLOR_ATTACHMENT` |
| `fence_init :: proc(device: ^Device, ...)`, `fence_init_vk` | free fn `fence_init(Device* device, ...)`; backends keep the `_vk`/`_dx12`/`_wgpu`/`_webgl` suffix |
| `-> Error`, `-> (T, Error)` | `void?`, `T?`; `return UNSUPPORTED_BACKEND~;` (a value Odin returned beside the error is dropped) |
| `backend: struct #raw_union { vk: X_Vk, ... }` | `union backend { XVk vk; ... }` (`using impl:` becomes an anonymous `union { ... }`) |
| `switch renderer.backend { case .Vk: when HAS_VK { ... } }` | `switch (renderer.backend) { case VK: $if HAS_VK: ... $endif ... }` (a case holding a disabled `$if` does not fall through; a truly empty `case MTL:` does, so give it a `break;`) |
| tagged `union` (`Renderer_Options`, `Window_Handle`) | struct with a tag enum plus an anonymous `union` (`RendererOptions.backend`) |
| `bit_set[Flag; u16]` in the front | `bitstruct X : ushort` with one `bool flag_name : N;` per flag, `N` = the Odin ordinal |
| `Maybe(T)` field `blend` | `T blend; bool has_blend;` |
| `[]^Cmd`, `cstring`, `rawptr`, `int` | `Cmd*[]`, `ZString`, `void*`, `sz` |
| parapoly struct `Command_Ring_Buffer($POOL_COUNT: int, ...)` | value-param generic `struct CommandRingBuffer <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>`, used as `CommandRingBuffer{2, 3, true}` |

Notes:

- Unsigned arithmetic wraps in C3 safe mode (`-O0`, `trap-on-wrap` is off by
  default), so `OffsetAllocator`'s `free_offset -= 1` keeps the C/Odin wrap
  semantics. Shifts by `>=` bit width *do* trap in safe mode, which is why
  `find_lowest_set_bit_after` keeps its explicit `start_bit_index >= 32` guard.
- `small_float_float_to_uint` is named `small_float_to_uint` in C3 because the
  ported `small_float_float_to_uint` test lives in the same module.
- `test::eq` needs matching integer signedness (use `0u` against `uint`) and
  an `equals` method for structs; the tests define `IdRange.equals`.

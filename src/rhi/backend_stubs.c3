// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Stand-in payload structs for backends that are not compiled in. Gathered
// here because C3 can only gate top-level declarations with
// feature flags.
//
// Each section's `@feat` is the negation of that backend's `HAS_*` const in
// rhi.c3; keep the two in sync. A backend ticket defines the real structs
// under the positive gate in its own file. C3 rejects zero-sized structs, so
// every stand-in carries a `_unused` byte.
//
// `Fence`/`Semaphore`'s `Wgpu`/`Webgl` payloads are empty on every target
// (the web arms are implemented inline) and live in fence.c3/semaphore.c3.
//
// Vulkan has landed: its payload structs live in vk_*.c3 (and, until the
// port finishes, as stand-ins in vk_pending.c3), all gated by
// `@feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32))`. On targets where
// that gate is false (macOS, wasm, headless) the `*Vk` union members still
// need a type, so a Vulkan-off section stays here with the negated gate.

// ---- vulkan (compiled out) ----
module rhi @feat(!(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32)));

struct RendererVk { char _unused; }
struct PhysicalAdapterVk { char _unused; }
struct DeviceVk { char _unused; }
struct QueueVk { char _unused; }
struct FenceVk { char _unused; }
struct SemaphoreVk { char _unused; }
struct TimelineVk { char _unused; }
struct PoolVk { char _unused; }
struct CmdVk { char _unused; }
struct CommandRingElementVk { char _unused; }
struct CommandRingBufferVk <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferVk { char _unused; }
struct ImageVk { char _unused; }
struct ImageViewVk { char _unused; }
struct SamplerVk { char _unused; }
struct ShaderVk { char _unused; }
struct PipelineVk { char _unused; }
struct SwapchainVk { char _unused; }
struct ProgramVk { char _unused; }
struct ProgramPipelineSlotVk { char _unused; }
struct ProgramDescriptorSetVk { char _unused; }
struct QueryPoolVk { char _unused; }

// ---- d3d12 ----
module rhi @feat(!(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32));

struct RendererDx12 { char _unused; }
struct PhysicalAdapterDx12 { char _unused; }
struct DeviceDx12 { char _unused; }
struct QueueDx12 { char _unused; }
struct FenceDx12 { char _unused; }
struct TimelineDx12 { char _unused; }
struct PoolDx12 { char _unused; }
struct CmdDx12 { char _unused; }
struct CommandRingElementDx12 { char _unused; }
struct CommandRingBufferDx12 <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferDx12 { char _unused; }
struct ImageDx12 { char _unused; }
struct ImageViewDx12 { char _unused; }
struct SamplerDx12 { char _unused; }
struct ShaderDx12 { char _unused; }
struct PipelineDx12 { char _unused; }
struct QueryPoolDx12 { char _unused; }
struct AccelStructureDx12 { char _unused; }

// ---- metal ----
// DARWIN already implies !WASM.
module rhi @feat(!(RHI_MTL & DARWIN & !RHI_HEADLESS));

struct RendererMtl { char _unused; }
struct PhysicalAdapterMtl { char _unused; }
struct DeviceMtl { char _unused; }
struct QueueMtl { char _unused; }
struct FenceMtl { char _unused; }
struct SemaphoreMtl { char _unused; }
struct TimelineMtl { char _unused; }
struct PoolMtl { char _unused; }
struct CmdMtl { char _unused; }
struct CommandRingElementMtl { char _unused; }
struct CommandRingBufferMtl <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferMtl { char _unused; }
struct ImageMtlState { char _unused; }
struct ImageViewMtlState { char _unused; }
struct SamplerMtl { char _unused; }
struct ShaderMtl { char _unused; }
struct PipelineMtl { char _unused; }
struct SwapchainMtl { char _unused; }

// ---- webgpu ----
module rhi @feat(!(RHI_WGPU & !RHI_HEADLESS & WASM));

struct RendererWgpu { char _unused; }
struct PhysicalAdapterWgpu { char _unused; }
struct DeviceWgpu { char _unused; }
struct QueueWgpu { char _unused; }
struct TimelineWgpu { char _unused; }
struct PoolWgpu { char _unused; }
struct CmdWgpu { char _unused; }
struct CommandRingElementWgpu { char _unused; }
struct CommandRingBufferWgpu <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferWgpu { char _unused; }
struct ImageWgpu { char _unused; }
struct ImageViewWgpu { char _unused; }
struct SamplerWgpu { char _unused; }
struct ShaderWgpu { char _unused; }
struct PipelineWgpu { char _unused; }
struct SwapchainWgpu { char _unused; }

// ---- webgl ----
module rhi @feat(!(RHI_WEBGL & !RHI_HEADLESS & WASM));

struct RendererWebgl { char _unused; }
struct PhysicalAdapterWebgl { char _unused; }
struct DeviceWebgl { char _unused; }
struct QueueWebgl { char _unused; }
struct TimelineWebgl { char _unused; }
struct PoolWebgl { char _unused; }
struct CmdWebgl { char _unused; }
struct CommandRingElementWebgl { char _unused; }
struct CommandRingBufferWebgl <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferWebgl { char _unused; }
struct ImageWebgl { char _unused; }
struct ImageViewWebgl { char _unused; }
struct SamplerWebgl { char _unused; }
struct ShaderWebgl { char _unused; }
struct PipelineWebgl { char _unused; }
struct SwapchainWebgl { char _unused; }

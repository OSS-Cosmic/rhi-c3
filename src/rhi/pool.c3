// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral command pool. Port of rhi-zig's `cmd.zig` `Pool` type.
// Browser pools do not emulate Vulkan queue families: WebGPU and WebGL2 expose
// a single ordered graphics queue.
module rhi;

struct Pool
{
	union backend
	{
		PoolVk vk;
		PoolDx12 dx12;
		PoolWgpu wgpu;
		PoolWebgl webgl;
		PoolMtl mtl;
	}
}

fn Pool? pool_init(Device* device, Queue* queue)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return pool_init_vk(device, queue);
			$endif
		case DX12:
			$if HAS_DX12:
				return pool_init_dx12(device, queue);
			$endif
		case MTL:
			$if HAS_MTL:
				return pool_init_mtl(device, queue);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return pool_init_wgpu(device, queue);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return pool_init_webgl(device, queue);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void? pool_reset(Pool* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return pool_reset_vk(p, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return pool_reset_dx12(p, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return pool_reset_mtl(p, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return pool_reset_wgpu(p, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return pool_reset_webgl(p, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void pool_deinit(Pool* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				pool_deinit_vk(p, device);
			$endif
		case DX12:
			$if HAS_DX12:
				pool_deinit_dx12(p, device);
			$endif
		case MTL:
			$if HAS_MTL:
				pool_deinit_mtl(p, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				pool_deinit_wgpu(p, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				pool_deinit_webgl(p, device);
			$endif
	}
}

// ---- metal ----

// Metal has no command-pool object. PoolMtl is deliberately empty; the
// command ring still keeps the pool lifetime parallel with the other RHI
// backends and owns the command-buffer handles through CmdMtl.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct PoolMtl { char _unused; }

fn Pool? pool_init_mtl(Device* device, Queue* queue)
{
	return { .backend.mtl = { ._unused = 0 } };
}

fn void? pool_reset_mtl(Pool* pool, Device* device)
{
	return;
}

fn void pool_deinit_mtl(Pool* pool, Device* device)
{
}

// ---- dx12 ----

// Direct3D 12 command pool. Wraps one ID3D12CommandAllocator of the queue's
// list type; command lists created from it (CmdDx12) record into this
// allocator and are only reusable after `pool_reset_dx12`, which may run once
// the GPU finished every list recorded from the pool.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct PoolDx12
{
	// Owned.
	d3d12::CommandAllocator* allocator;
	d3d12::CommandListType type;
}

fn Pool? pool_init_dx12(Device* device, Queue* queue)
{
	d3d12::Device* dev = device.backend.dx12.device;
	d3d12::CommandQueue* q = queue.backend.dx12.queue;
	if (!dev || !q) return INITIALIZATION_FAILED~;

	// The allocator must match the list type of the queue it feeds.
	d3d12::CommandQueueDesc queue_desc;
	q.vtbl.get_desc(q, &queue_desc);

	Guid iid = d3d12::IID_COMMAND_ALLOCATOR;
	d3d12::CommandAllocator* allocator;
	dx12_check(dev.vtbl.create_command_allocator(dev, queue_desc.type, &iid, (void**)&allocator))!;
	return { .backend.dx12 = { .allocator = allocator, .type = queue_desc.type } };
}

fn void? pool_reset_dx12(Pool* p, Device* device)
{
	d3d12::CommandAllocator* allocator = p.backend.dx12.allocator;
	if (!allocator) return UNKNOWN~;
	dx12_check(allocator.vtbl.reset(allocator))!;
}

fn void pool_deinit_dx12(Pool* p, Device* device)
{
	PoolDx12* state = &p.backend.dx12;
	if (state.allocator) dxgi::release(state.allocator);
	*state = {};
}

// ---- vulkan ----

// Vulkan command-pool management.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct PoolVk
{
	Queue* queue;
	vk::CommandPool pool;
}

fn Pool? pool_init_vk(Device* device, Queue* queue)
{
	vk::CommandPoolCreateInfo info = {
		.sType = vk::StructureType.COMMAND_POOL_CREATE_INFO,
		.flags = vk::COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		.queueFamilyIndex = queue.backend.vk.family_index,
	};
	vk::CommandPool command_pool;
	vk_check(device.backend.vk.vtable.createCommandPool(device.backend.vk.device, &info, null, &command_pool))!;
	return { .backend.vk = { .queue = queue, .pool = command_pool } };
}

fn void? pool_reset_vk(Pool* pool, Device* device)
{
	return vk_check(device.backend.vk.vtable.resetCommandPool(device.backend.vk.device, pool.backend.vk.pool, 0));
}

fn void pool_deinit_vk(Pool* pool, Device* device)
{
	device.backend.vk.vtable.destroyCommandPool(device.backend.vk.device, pool.backend.vk.pool, null);
}

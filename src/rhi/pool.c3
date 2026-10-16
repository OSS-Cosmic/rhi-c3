// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral command pool. Port of rhi-zig's `cmd.zig` `Pool` type.
// Browser pools do not emulate Vulkan queue families: WebGPU and WebGL2 expose
// a single ordered graphics queue.
module rhi;
import d3d12, dxgi, vk;

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
				{
					vk::CommandPoolCreateInfo info = {
						.sType = vk::StructureType.STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
						.flags = vk::CommandPoolCreateFlagBits.COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
						.queueFamilyIndex = queue.backend.vk.family_index,
					};
					vk::CommandPool command_pool;
					vk_check(vk::vkCreateCommandPool(device.backend.vk.device, &info, null, &command_pool))!;
					return { .backend.vk = { .queue = queue, .pool = command_pool } };
				}
			$endif
		case DX12:
			$if HAS_DX12:
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
			$endif
		case MTL:
			$if HAS_MTL:
				{
					return { .backend.mtl = { ._unused = 0 } };
				}
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					return { .backend.wgpu = {} };
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					if (device == null || queue == null) return INITIALIZATION_FAILED~;
					return {};
				}
			$endif
	}
	unreachable();
}

fn void? pool_reset(Pool* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					return vk_check(vk::vkResetCommandPool(device.backend.vk.device, p.backend.vk.pool, (vk::CommandPoolResetFlags)0));
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					d3d12::CommandAllocator* allocator = p.backend.dx12.allocator;
					if (!allocator) return UNKNOWN~;
					dx12_check(allocator.vtbl.reset(allocator))!;
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					return;
				}
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					return;
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					return;
				}
			$endif
	}
	unreachable();
}

fn void pool_deinit(Pool* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				vk::destroyCommandPool(device.backend.vk.device, p.backend.vk.pool, null);
			$endif
		case DX12:
			$if HAS_DX12:
				PoolDx12* state = &p.backend.dx12;
				if (state.allocator) dxgi::release(state.allocator);
				*state = {};
			$endif
		case MTL:
			$if HAS_MTL:
				// Metal has no command-pool object.
				break;
			$endif
		case WGPU:
			$if HAS_WGPU:
				// WebGPU has no command-pool object.
				break;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				break;
			$endif
	}
}

// ---- metal ----

// Metal has no command-pool object. PoolMtl is deliberately empty; the
// command ring still keeps the pool lifetime parallel with the other RHI
// backends and owns the command-buffer handles through CmdMtl.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct PoolMtl { char _unused; }

// ---- dx12 ----

// Direct3D 12 command pool. Wraps one ID3D12CommandAllocator of the queue's
// list type; command lists created from it (CmdDx12) record into this
// allocator and are only reusable after `pool_reset`, which may run once
// the GPU finished every list recorded from the pool.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct PoolDx12
{
	// Owned.
	d3d12::CommandAllocator* allocator;
	d3d12::CommandListType type;
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

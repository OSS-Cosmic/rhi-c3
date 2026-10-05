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

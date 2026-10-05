// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral binary semaphore. Port of rhi-zig's `semaphore.zig`.
//
// The browser arms are implemented inline: WebGPU and WebGL2 expose a single
// ordered graphics queue, so GPU-GPU ordering between submits is implicit and
// a semaphore has nothing to carry.
module rhi;

struct SemaphoreWgpu { char _unused; }
struct SemaphoreWebgl { char _unused; }

struct Semaphore
{
	union backend
	{
		SemaphoreVk vk;
		SemaphoreWgpu wgpu;
		SemaphoreWebgl webgl;
		SemaphoreMtl mtl;
	}
}

fn Semaphore? semaphore_init(Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return semaphore_init_vk(device);
			$endif
		case DX12:
			// D3D12 has no binary semaphores; GPU-GPU sync uses a `Timeline`
			// (ID3D12Fence) instead.
			return UNSUPPORTED_FEATURE~;
		case MTL:
			$if HAS_MTL:
				return semaphore_init_mtl(device);
			$endif
		case WGPU:
		case WEBGL:
			// Nothing to create; see the file header.
			return {};
	}
	return UNSUPPORTED_BACKEND~;
}

fn void semaphore_deinit(Semaphore* s, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				semaphore_deinit_vk(s, device);
			$endif
		case MTL:
			$if HAS_MTL:
				semaphore_deinit_mtl(s, device);
			$endif
		case DX12:
		case WGPU:
		case WEBGL:
			break;
	}
}

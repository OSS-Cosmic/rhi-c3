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

// ---- metal ----

// Metal has no binary semaphores; GPU-GPU synchronization uses timelines
// (MTLSharedEvent) instead. Keep this separate from the swapchain.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct SemaphoreMtl { char _unused; }

fn Semaphore? semaphore_init_mtl(Device* device)
{
	return UNSUPPORTED_FEATURE~;
}

fn void semaphore_deinit_mtl(Semaphore* s, Device* device)
{
}

// ---- vulkan ----

// Vulkan binary semaphore.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct SemaphoreVk
{
	vk::Semaphore semaphore;
}

fn Semaphore? semaphore_init_vk(Device* device)
{
	vk::SemaphoreCreateInfo create_info = { .sType = SEMAPHORE_CREATE_INFO };
	vk::Semaphore semaphore;
	vk_check(device.backend.vk.vtable.createSemaphore(device.backend.vk.device, &create_info, null, &semaphore))!;
	return { .backend.vk = { .semaphore = semaphore } };
}

fn void semaphore_deinit_vk(Semaphore* s, Device* device)
{
	device.backend.vk.vtable.destroySemaphore(device.backend.vk.device, s.backend.vk.semaphore, null);
	s.backend.vk.semaphore = 0;
}

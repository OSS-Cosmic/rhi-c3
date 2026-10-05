// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU fence: a CPU-waitable one-shot signal. Port of rhi-zig's
// `fence.zig`.
//
// The browser arms are implemented inline: a browser frame cannot block on
// the GPU, WebGPU and WebGL2 expose a single ordered graphics queue, and the
// browser keeps submitted resources alive on its own (GL defers deleting
// objects until the commands referencing them retire). A fence therefore has
// nothing to carry and nothing to wait on.
module rhi;

struct FenceWgpu { char _unused; }
struct FenceWebgl { char _unused; }

struct Fence
{
	union backend
	{
		FenceVk vk;
		FenceWgpu wgpu;
		FenceWebgl webgl;
		FenceDx12 dx12;
		FenceMtl mtl;
	}
}

enum FenceStatus
{
	COMPLETE,
	INCOMPLETE,
}

fn Fence? fence_init(Device* device, bool signaled)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_init_vk(device, signaled);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_init_dx12(device, signaled);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_init_mtl(device, signaled);
			$endif
		case WGPU:
		case WEBGL:
			// Nothing to create; see the file header.
			return {};
	}
	return UNSUPPORTED_BACKEND~;
}

fn void fence_deinit(Fence* f, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				fence_deinit_vk(f, device);
			$endif
		case DX12:
			$if HAS_DX12:
				fence_deinit_dx12(f, device);
			$endif
		case MTL:
			$if HAS_MTL:
				fence_deinit_mtl(f, device);
			$endif
		case WGPU:
		case WEBGL:
			break;
	}
}

fn void? fence_wait(Device* device, Fence*[] fences)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_wait_vk(device, fences);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_wait_dx12(device, fences);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_wait_mtl(device, fences);
			$endif
		case WGPU:
		case WEBGL:
			// Cannot block a browser task; the ordered queue already sequences
			// later submits after earlier ones.
			return;
	}
	return UNSUPPORTED_BACKEND~;
}

fn FenceStatus? fence_status(Fence* f, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_status_vk(f, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_status_dx12(f, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_status_mtl(f, device);
			$endif
		case WGPU:
		case WEBGL:
			// Resources are kept alive by the browser, so a fence is always safe
			// to treat as complete. Use a `Timeline` to observe real progress.
			return COMPLETE;
	}
	return UNSUPPORTED_BACKEND~;
}

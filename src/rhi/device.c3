// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral logical device: resolved queues and a memory allocator.
// Port of the Vulkan arm of rhi-zig's `device.zig`.
module rhi;

struct Device
{
	Queue graphics_queue;
	Queue compute_queue;
	bool has_compute_queue;
	Queue transfer_queue;
	bool has_transfer_queue;
	PhysicalAdapter adapter;
	Allocator allocator;
	union backend
	{
		DeviceVk vk;
		DeviceWgpu wgpu;
		DeviceWebgl webgl;
		DeviceDx12 dx12;
		DeviceMtl mtl;
	}
}

fn Device? device_init(PhysicalAdapter* adapter, Allocator allocator = mem)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return device_init_vk(adapter, allocator);
			$endif
		case DX12:
			$if HAS_DX12:
				return device_init_dx12(adapter, allocator);
			$endif
		case MTL:
			$if HAS_MTL:
				return device_init_mtl(adapter, allocator);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return device_init_wgpu(adapter, allocator);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return device_init_webgl(adapter, allocator);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void device_deinit(Device* d)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				device_deinit_vk(d);
			$endif
		case DX12:
			$if HAS_DX12:
				device_deinit_dx12(d);
			$endif
		case MTL:
			$if HAS_MTL:
				device_deinit_mtl(d);
			$endif
		case WGPU:
			$if HAS_WGPU:
				device_deinit_wgpu(d);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				device_deinit_webgl(d);
			$endif
	}
}

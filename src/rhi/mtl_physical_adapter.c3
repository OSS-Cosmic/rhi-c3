// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal physical adapter. Port of the `.mtl` arm of rhi-zig's
// `physical_adapter.zig`, widened from the single system default device to
// every device MTLCopyAllDevices reports.
//
// Each adapter holds a retain on its MTLDevice. The front has no per-backend
// adapter release (Vulkan physical devices need none), so that reference
// lives as long as the process; `device_init_mtl` takes its own retain and
// `device_deinit_mtl` drops only that one.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::collections::list;
import std::os::macos::objc;
import mtl;

struct PhysicalAdapterMtl
{
	mtl::Device device;
}

fn PhysicalAdapter mtl_adapter_from_device(mtl::Device device)
{
	// Metal reports only a handful of the neutral limits; the rest keep the
	// conservative web defaults rather than claiming more than we can check.
	PhysicalAdapter a = physical_adapter_web_defaults();
	device.retain();
	a.backend.mtl = { .device = device };

	mtl::NSString name = device.name();
	if (name) physical_adapter_set_name(&a, name.utf8().str_view());
	a.luid = device.registry_id();
	a.video_memory_size = device.recommended_max_working_set_size();
	a.adapter_type = device.has_unified_memory() ? INTEGRATED : DISCRETE;
	a.preset_level = HIGH;

	a.buffer_max_size = device.max_buffer_length();
	a.attachment_max_dim = 16384;
	a.texture_1d_max_dim = 16384;
	a.texture_2d_max_dim = 16384;
	// MTLTextureType3D and texture arrays top out at 2048 on every Apple GPU.
	a.texture_3d_max_dim = 2048;
	a.texture_array_layer_max_num = 2048;
	a.color_attachment_max_num = 8;
	a.fragment_shader_output_attachment_max_num = 8;

	mtl::Size threads = device.max_threads_per_threadgroup();
	a.compute_shader_work_group_max_dim = { (uint)threads.width, (uint)threads.height, (uint)threads.depth };
	a.compute_shader_work_group_invocation_max_num = (uint)threads.width;

	a.constant_buffer_offset_alignment = 256;
	a.upload_buffer_texture_row_alignment = 256;
	return a;
}

fn List{PhysicalAdapter}? enumerate_adapters_mtl(Allocator allocator = mem)
{
	List{PhysicalAdapter} adapters;
	adapters.init(allocator, 0);
	objc::@autoreleasepool()
	{
		mtl::NSArray devices = mtl::copy_all_devices();
		if (devices)
		{
			defer devices.release();
			mtl::NSUInteger count = devices.count();
			for (mtl::NSUInteger i = 0; i < count; i++)
			{
				adapters.push(mtl_adapter_from_device(devices.object_at_index(mtl::Device, i)));
			}
		}
		// MTLCopyAllDevices is macOS-only and may come back empty (e.g. in a
		// sandbox); the system default device is the documented fallback.
		if (adapters.len() == 0)
		{
			mtl::Device device = mtl::create_system_default_device();
			if (device)
			{
				adapters.push(mtl_adapter_from_device(device));
				device.release();
			}
		}
	};
	if (adapters.len() == 0)
	{
		adapters.free();
		return INITIALIZATION_FAILED~;
	}
	return adapters;
}

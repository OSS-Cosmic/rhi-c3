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

// ---- metal ----

// Metal logical device. Port of the `.mtl` arms of rhi-zig's `device.zig`
// `init`/`deinit`.
//
// Metal has one device-level MTLCommandQueue type with no queue families:
// the single queue created here is the graphics queue, and there is no
// separate compute or transfer queue.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct DeviceMtl
{
	// Owned: a retain on the adapter's MTLDevice.
	mtl::Device device;
	// Owned; `graphics_queue` borrows it.
	mtl::CommandQueue queue;
}

fn Device? device_init_mtl(PhysicalAdapter* adapter, Allocator allocator = mem)
{
	mtl::Device device = adapter.backend.mtl.device;
	if (!device) return INITIALIZATION_FAILED~;
	mtl::CommandQueue queue = device.new_command_queue();
	if (!queue) return INITIALIZATION_FAILED~;
	mtl::SharedEvent completion_event = device.new_shared_event();
	if (!completion_event)
	{
		queue.release();
		return INITIALIZATION_FAILED~;
	}
	device.retain();
	return {
		.graphics_queue = { .backend.mtl = { .queue = queue, .completion_event = completion_event } },
		.adapter = *adapter,
		.allocator = allocator,
		.backend.mtl = { .device = device, .queue = queue },
	};
}

fn void device_deinit_mtl(Device* d)
{
	QueueMtl* graphics = &d.graphics_queue.backend.mtl;
	if (graphics.completion_event) graphics.completion_event.release();
	*graphics = {};
	DeviceMtl* state = &d.backend.mtl;
	if (state.queue) state.queue.release();
	if (state.device) state.device.release();
	*state = {};
}

// ---- dx12 ----

// Direct3D 12 logical device. Port of the `.dx12` arms of rhi-zig's
// `device.zig` `init`/`deinit`: an ID3D12Device at feature level 12_0+, a
// D3D12MemoryAllocator, and direct / compute / copy command queues that
// back the graphics, compute and transfer queues.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi, d3d12ma;

struct DeviceDx12
{
	// Owned.
	d3d12::Device* device;
	// Owned: a reference on the adapter's IDXGIAdapter1.
	dxgi::Adapter1* adapter;
	// Owned.
	d3d12ma::Allocator allocator;
	// Owned, created lazily by the first ExecuteIndirect draw of each kind.
	d3d12::CommandSignature* draw_signature;
	d3d12::CommandSignature* draw_indexed_signature;
	// DXR support level; NOT_SUPPORTED when the adapter lacks DXR.
	d3d12::RaytracingTier raytracing_tier;
}

// `d3d12ma::Allocator` shadows std's `Allocator` here, so spell std's out.
fn Device? device_init_dx12(PhysicalAdapter* adapter, mem::alloc::Allocator allocator = mem)
{
	dxgi::Adapter1* dxgi_adapter = adapter.backend.dx12.adapter;
	if (!dxgi_adapter) return INITIALIZATION_FAILED~;

	Guid iid = d3d12::IID_DEVICE;
	d3d12::Device* dev;
	if (dxgi::failed(d3d12::create_device(dxgi_adapter, d3d12::FeatureLevel.LEVEL_12_0, &iid, (void**)&dev)) || !dev)
	{
		return INITIALIZATION_FAILED~;
	}

	d3d12ma::AllocatorDesc ma_desc = { .device = dev, .adapter = dxgi_adapter };
	d3d12ma::Allocator ma;
	if (d3d12ma::create_allocator(&ma_desc, &ma) < 0)
	{
		dxgi::release(dev);
		return INITIALIZATION_FAILED~;
	}

	Device result = {
		.adapter = *adapter,
		.allocator = allocator,
	};
	defer catch device_deinit_dx12(&result);

	// The queue fields are filled in as they are created so a failure part
	// way through is cleaned up by `device_deinit_dx12`.
	dxgi::add_ref(dxgi_adapter);
	result.backend.dx12 = { .device = dev, .adapter = dxgi_adapter, .allocator = ma };

	d3d12::FeatureDataOptions5 options5;
	if (!dxgi::failed(dev.vtbl.check_feature_support(dev, d3d12::Feature.D3D12_OPTIONS5, &options5, d3d12::FeatureDataOptions5::size)))
	{
		result.backend.dx12.raytracing_tier = options5.raytracing_tier;
	}

	result.graphics_queue.backend.dx12 = dx12_queue_create(dev, d3d12::CommandListType.DIRECT)!;
	result.compute_queue.backend.dx12 = dx12_queue_create(dev, d3d12::CommandListType.COMPUTE)!;
	result.has_compute_queue = true;
	result.transfer_queue.backend.dx12 = dx12_queue_create(dev, d3d12::CommandListType.COPY)!;
	result.has_transfer_queue = true;
	return result;
}

fn void device_deinit_dx12(Device* d)
{
	dx12_queue_destroy(&d.graphics_queue.backend.dx12);
	dx12_queue_destroy(&d.compute_queue.backend.dx12);
	dx12_queue_destroy(&d.transfer_queue.backend.dx12);
	DeviceDx12* state = &d.backend.dx12;
	if (state.draw_signature) dxgi::release(state.draw_signature);
	if (state.draw_indexed_signature) dxgi::release(state.draw_indexed_signature);
	if (state.allocator) d3d12ma::destroy_allocator(state.allocator);
	if (state.device) dxgi::release(state.device);
	if (state.adapter) dxgi::release(state.adapter);
	*state = {};
}

// ---- vulkan ----

// Vulkan logical device: extension filtering, queue-family selection, feature
// chains, per-device dispatch table and the VMA allocator.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, vma;
import std::collections::list;

struct DeviceVk
{
	bool maintenance_5_feature_enabled;
	bool conservative_raster_tier;
	bool swapchain_mutable_format;
	bool memory_budget;
	// `occlusionQueryPrecise` was reported by the adapter and thus enabled
	// (the feature chain is created from the queried features).
	bool occlusion_query_precise;
	vk::Device device;
	vma::Allocator vma_allocator;
	// Per-device dispatch table, loaded with `vk::load_proc_addresses_device_vtable`
	// rather than the global loader (mirrors rhi-zig's per-device `DeviceWrapper`,
	// `dkb`). Every device-level Vulkan call goes through `vtable.x`.
	vk::DeviceVTable vtable;
}

fn bool device_has_extension(ZString[] names, ZString name) @private
{
	foreach (n : names)
	{
		if (n.str_view() == name.str_view()) return true;
	}
	return false;
}

fn sz device_queue_create_info_find(vk::DeviceQueueCreateInfo[] infos, sz family_idx) @private
{
	foreach (idx, info : infos)
	{
		if ((sz)info.queueFamilyIndex == family_idx) return idx;
	}
	return -1;
}

// `alloc::Allocator`: a bare `Allocator` resolves to `vma::Allocator` here.
fn Device? device_init_vk(PhysicalAdapter* adapter, alloc::Allocator allocator = mem)
{
	vk::PhysicalDevice physical_device = adapter.backend.vk.physical_device;

	uint extension_count;
	vk_check(vk::enumerateDeviceExtensionProperties(physical_device, null, &extension_count, null))!;
	vk::ExtensionProperties[] extension_properties = mem::alloc::alloc_array_try(allocator, vk::ExtensionProperties, extension_count)!;
	defer mem::alloc::free(allocator, extension_properties.ptr);
	vk_check(vk::enumerateDeviceExtensionProperties(physical_device, null, &extension_count, extension_properties.ptr))!;

	List{ZString} enabled_extension_names;
	enabled_extension_names.init(allocator);
	defer enabled_extension_names.free();
	foreach (ext : DEFAULT_DEVICE_EXTENSIONS)
	{
		if (vk_has_extension(extension_properties, ext.str_view())) enabled_extension_names.push(ext);
	}

	uint family_count;
	vk::getPhysicalDeviceQueueFamilyProperties(physical_device, &family_count, null);
	vk::QueueFamilyProperties[] queue_family_props = mem::alloc::alloc_array_try(allocator, vk::QueueFamilyProperties, family_count)!;
	defer mem::alloc::free(allocator, queue_family_props.ptr);
	vk::getPhysicalDeviceQueueFamilyProperties(physical_device, &family_count, queue_family_props.ptr);

	foreach (i, family : queue_family_props)
	{
		log::info("Queue Family %d: 0x%x", i, (uint)family.queueFlags, category: log::CATEGORY_RENDER);
	}

	float[6] priorities = { 1.0, 0.9, 0.8, 0.7, 0.6, 0.5 };
	List{vk::DeviceQueueCreateInfo} device_queue_create_info;
	device_queue_create_info.init(allocator);
	defer device_queue_create_info.free();

	// Optional queues: graphics, compute, transfer.
	Queue[3] rhi_queues;
	bool[3] has_rhi_queue;
	vk::QueueFlags[3] configs = { vk::QUEUE_GRAPHICS_BIT, vk::QUEUE_COMPUTE_BIT, vk::QUEUE_TRANSFER_BIT };

	foreach (config_idx, required_bits : configs)
	{
		uint min_queue_flags = uint::max;
		sz best_family_idx = 0;

		foreach (family_idx, &family : queue_family_props)
		{
			if (config_idx == 0 && (required_bits & family.queueFlags) == required_bits)
			{
				best_family_idx = family_idx;
				break;
			}

			uint existing_count = 0;
			sz idx = device_queue_create_info_find(device_queue_create_info.array_view(), family_idx);
			if (idx != -1) existing_count = device_queue_create_info[idx].queueCount;

			if (family.queueCount == 0) continue;

			uint family_int = (uint)family.queueFlags;
			uint required_int = (uint)required_bits;
			uint matching = family_int & required_int;

			// Family flags are a subset of the required bits and still has a
			// free slot: take it immediately.
			if (matching > 0 && (family_int & ~required_int) == 0 && (family.queueCount - existing_count) > 0)
			{
				best_family_idx = family_idx;
				break;
			}

			// Otherwise prefer the family with the fewest extra flags beyond
			// what is required.
			if (matching > 0 && (family_int - matching) < min_queue_flags)
			{
				best_family_idx = family_idx;
				min_queue_flags = family_int - matching;
			}
		}

		sz entry_idx = device_queue_create_info_find(device_queue_create_info.array_view(), best_family_idx);
		if (entry_idx == -1)
		{
			device_queue_create_info.push({
				.sType = DEVICE_QUEUE_CREATE_INFO,
				.queueFamilyIndex = (uint)best_family_idx,
				.queueCount = 0,
				.pQueuePriorities = &priorities,
			});
			entry_idx = (sz)device_queue_create_info.len() - 1;
		}
		vk::DeviceQueueCreateInfo* entry = &device_queue_create_info[entry_idx];

		// Out of slots in this family: try to reuse an already-resolved queue
		// with the same rule used above.
		if (entry.queueCount >= queue_family_props[best_family_idx].queueCount)
		{
			min_queue_flags = uint::max;
			sz dup_idx = -1;
			uint required_int = (uint)required_bits;
			for (sz i = 0; i < rhi_queues.len; i++)
			{
				if (!has_rhi_queue[i]) continue;
				uint eq_int = (uint)rhi_queues[i].backend.vk.queue_flags;
				uint matching = eq_int & required_int;
				if (matching > 0 && (eq_int & ~required_int) == 0)
				{
					dup_idx = i;
					break;
				}
				if (matching > 0 && (eq_int - matching) < min_queue_flags)
				{
					min_queue_flags = eq_int - matching;
					dup_idx = i;
				}
			}
			if (dup_idx != -1)
			{
				rhi_queues[config_idx] = rhi_queues[dup_idx];
				has_rhi_queue[config_idx] = true;
			}
		}
		else
		{
			rhi_queues[config_idx] = {};
			rhi_queues[config_idx].backend.vk = {
				.queue_flags = queue_family_props[best_family_idx].queueFlags,
				.family_index = (uint)best_family_idx,
				.slot_index = entry.queueCount,
			};
			has_rhi_queue[config_idx] = true;
			entry.queueCount += 1;
		}
	}

	if (!has_rhi_queue[0]) return INITIALIZATION_FAILED~;

	bool has_maintenance_5 = device_has_extension(enabled_extension_names.array_view(), vk::KHR_MAINTENANCE_5_EXTENSION_NAME);

	vk::PhysicalDeviceFeatures2 features = { .sType = PHYSICAL_DEVICE_FEATURES_2 };

	vk::PhysicalDeviceVulkan11Features features11 = { .sType = PHYSICAL_DEVICE_VULKAN_1_1_FEATURES };
	vk_add_next(&features, &features11);

	vk::PhysicalDeviceVulkan12Features features12 = { .sType = PHYSICAL_DEVICE_VULKAN_1_2_FEATURES };
	vk_add_next(&features, &features12);

	vk::PhysicalDeviceVulkan13Features features13 = { .sType = PHYSICAL_DEVICE_VULKAN_1_3_FEATURES };
	if (renderer.vk.api_version >= vk::API_VERSION_1_3) vk_add_next(&features, &features13);

	vk::PhysicalDeviceMaintenance5FeaturesKHR maintenance_5_features = { .sType = PHYSICAL_DEVICE_MAINTENANCE_5_FEATURES_KHR };
	if (has_maintenance_5) vk_add_next(&features, &maintenance_5_features);

	vk::PhysicalDevicePresentIdFeaturesKHR present_id_features = { .sType = PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_PRESENT_ID_EXTENSION_NAME))
	{
		vk_add_next(&features, &present_id_features);
	}

	vk::PhysicalDevicePresentWaitFeaturesKHR present_wait_features = { .sType = PHYSICAL_DEVICE_PRESENT_WAIT_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_PRESENT_WAIT_EXTENSION_NAME))
	{
		vk_add_next(&features, &present_wait_features);
	}

	vk::PhysicalDeviceLineRasterizationFeaturesKHR line_rasterization_features = { .sType = PHYSICAL_DEVICE_LINE_RASTERIZATION_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_LINE_RASTERIZATION_EXTENSION_NAME))
	{
		vk_add_next(&features, &line_rasterization_features);
	}

	vk::PhysicalDeviceAccelerationStructureFeaturesKHR accel_structure_features = { .sType = PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME))
	{
		vk_add_next(&features, &accel_structure_features);
	}

	vk::PhysicalDeviceRayTracingPipelineFeaturesKHR ray_tracing_pipeline_features = { .sType = PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME))
	{
		vk_add_next(&features, &ray_tracing_pipeline_features);
	}

	vk::PhysicalDeviceRayQueryFeaturesKHR ray_query_features = { .sType = PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR };
	if (device_has_extension(enabled_extension_names.array_view(), vk::KHR_RAY_QUERY_EXTENSION_NAME))
	{
		vk_add_next(&features, &ray_query_features);
	}

	vk::getPhysicalDeviceFeatures2(physical_device, &features);

	vk::DeviceCreateInfo device_create_info = {
		.sType = DEVICE_CREATE_INFO,
		.pNext = &features,
		.queueCreateInfoCount = (uint)device_queue_create_info.len(),
		.pQueueCreateInfos = &device_queue_create_info[0],
		.enabledExtensionCount = (uint)enabled_extension_names.len(),
		.ppEnabledExtensionNames = enabled_extension_names.len() ? &enabled_extension_names[0] : null,
	};

	vk::Device vk_device;
	vk_check(vk::createDevice(physical_device, &device_create_info, null, &vk_device))!;

	vk::DeviceVTable vtable;
	vk::load_proc_addresses_device_vtable(vk_device, &vtable);

	for (sz i = 0; i < rhi_queues.len; i++)
	{
		if (!has_rhi_queue[i]) continue;
		QueueVk* q = &rhi_queues[i].backend.vk;
		if (q.queue == null) vtable.getDeviceQueue(vk_device, q.family_index, q.slot_index, &q.queue);
	}

	vma::VulkanFunctions vulkan_functions = {
		.get_physical_device_properties = vk::getPhysicalDeviceProperties,
		.get_instance_proc_addr = vk::getInstanceProcAddr,
		.get_device_proc_addr = vk::getDeviceProcAddr,
		.get_physical_device_memory_properties = vk::getPhysicalDeviceMemoryProperties,
		.allocate_memory = vtable.allocateMemory,
		.free_memory = vtable.freeMemory,
		.map_memory = vtable.mapMemory,
		.unmap_memory = vtable.unmapMemory,
		.flush_mapped_memory_ranges = vtable.flushMappedMemoryRanges,
		.invalidate_mapped_memory_ranges = vtable.invalidateMappedMemoryRanges,
		.bind_buffer_memory = vtable.bindBufferMemory,
		.bind_image_memory = vtable.bindImageMemory,
		.get_buffer_memory_requirements = vtable.getBufferMemoryRequirements,
		.get_image_memory_requirements = vtable.getImageMemoryRequirements,
		.create_buffer = vtable.createBuffer,
		.destroy_buffer = vtable.destroyBuffer,
		.create_image = vtable.createImage,
		.destroy_image = vtable.destroyImage,
		.cmd_copy_buffer = vtable.cmdCopyBuffer,
		.get_buffer_memory_requirements2_khr = vtable.getBufferMemoryRequirements2KHR,
		.get_image_memory_requirements2_khr = vtable.getImageMemoryRequirements2KHR,
		.bind_buffer_memory2_khr = vtable.bindBufferMemory2KHR,
		.bind_image_memory2_khr = vtable.bindImageMemory2KHR,
		.get_physical_device_memory_properties2_khr = vk::getPhysicalDeviceMemoryProperties2KHR,
		.get_device_buffer_memory_requirements = vtable.getDeviceBufferMemoryRequirements,
		.get_device_image_memory_requirements = vtable.getDeviceImageMemoryRequirements,
	};

	vma::AllocatorCreateFlags allocator_flags;
	if (adapter.backend.vk.is_buffer_device_address_supported) allocator_flags |= vma::ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT;
	if (adapter.backend.vk.is_amd_device_coherent_memory_supported) allocator_flags |= vma::ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT;

	vma::AllocatorCreateInfo vma_create_info = {
		.physical_device = physical_device,
		.device = vk_device,
		.instance = renderer.vk.instance,
		.flags = allocator_flags,
		.vulkan_functions = &vulkan_functions,
		.vulkan_api_version = vk::API_VERSION_1_3,
	};

	vma::Allocator vma_allocator;
	if (catch err = vk_check(vma::create_allocator(&vma_create_info, &vma_allocator)))
	{
		vtable.destroyDevice(vk_device, null);
		return err~;
	}

	Device device = {
		.graphics_queue = rhi_queues[0],
		.compute_queue = rhi_queues[1],
		.has_compute_queue = has_rhi_queue[1],
		.transfer_queue = rhi_queues[2],
		.has_transfer_queue = has_rhi_queue[2],
		.adapter = *adapter,
		.allocator = allocator,
	};
	device.backend.vk = {
		.maintenance_5_feature_enabled = has_maintenance_5,
		.conservative_raster_tier = false,
		.swapchain_mutable_format = false,
		.memory_budget = false,
		.occlusion_query_precise = features.features.occlusionQueryPrecise != vk::FALSE,
		.device = vk_device,
		.vma_allocator = vma_allocator,
		.vtable = vtable,
	};
	return device;
}

fn void device_deinit_vk(Device* d)
{
	vma::destroy_allocator(d.backend.vk.vma_allocator);
	d.backend.vk.vtable.destroyDevice(d.backend.vk.device, null);
}

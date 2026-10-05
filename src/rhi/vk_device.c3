// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan logical device: extension filtering, queue-family selection, feature
// chains, per-device dispatch table and the VMA allocator. Port of the
// `---- device ----` section of rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, vma;
import std::collections::list;

struct DeviceVk
{
	bool maintenance_5_feature_enabled;
	bool conservative_raster_tier;
	bool swapchain_mutable_format;
	bool memory_budget;
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

	// Odin's `[3]Maybe(Queue)`: graphics, compute, transfer.
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

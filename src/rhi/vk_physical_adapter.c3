// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan physical adapter enumeration. Port of the `---- physical_adapter ----`
// section of rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;
import std::collections::list;

struct PhysicalAdapterVk
{
	vk::PhysicalDevice physical_device;
	uint api_version;
	bool is_swap_chain_supported;
	bool is_buffer_device_address_supported;
	bool is_amd_device_coherent_memory_supported;
	bool is_present_id_supported;
	bool is_maintenance5_supported;
	bool is_acceleration_structure_supported;
	bool is_ray_tracing_pipeline_supported;
	bool is_ray_query_supported;
	bool is_deferred_host_operations_supported;
}

// One adapter per physical device group (its first device). The returned list
// is owned by the caller and released with `adapters.free()`.
fn List{PhysicalAdapter}? enumerate_adapters_vk(Allocator allocator = mem)
{
	List{PhysicalAdapter} adapters;
	adapters.init(allocator, 0);
	defer catch adapters.free();

	uint count;
	vk_check(vk::enumeratePhysicalDeviceGroups(renderer.vk.instance, &count, null))!;

	vk::PhysicalDeviceGroupProperties[] device_group_properties = mem::alloc::alloc_array_try(allocator, vk::PhysicalDeviceGroupProperties, count)!;
	defer mem::alloc::free(allocator, device_group_properties.ptr);

	foreach (&p : device_group_properties)
	{
		*p = { .sType = PHYSICAL_DEVICE_GROUP_PROPERTIES };
	}

	vk_check(vk::enumeratePhysicalDeviceGroups(renderer.vk.instance, &count, device_group_properties.ptr))!;

	for (uint i = 0; i < count; i++)
	{
		vk::PhysicalDevice physical_device = device_group_properties[i].physicalDevices[0];

		uint ext_count;
		vk_check(vk::enumerateDeviceExtensionProperties(physical_device, null, &ext_count, null))!;

		vk::ExtensionProperties[] extension_properties = mem::alloc::alloc_array_try(allocator, vk::ExtensionProperties, ext_count)!;
		defer mem::alloc::free(allocator, extension_properties.ptr);

		vk_check(vk::enumerateDeviceExtensionProperties(physical_device, null, &ext_count, extension_properties.ptr))!;

		bool has_acceleration_structure = vk_has_extension(extension_properties, vk::KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME.str_view());
		bool has_ray_tracing_pipeline = vk_has_extension(extension_properties, vk::KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME.str_view());
		bool has_ray_query = vk_has_extension(extension_properties, vk::KHR_RAY_QUERY_EXTENSION_NAME.str_view());
		bool has_deferred_host_operations = vk_has_extension(extension_properties, vk::KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME.str_view());

		vk::PhysicalDeviceProperties2 properties = { .sType = PHYSICAL_DEVICE_PROPERTIES_2 };
		vk::PhysicalDeviceVulkan11Properties props11 = { .sType = PHYSICAL_DEVICE_VULKAN_1_1_PROPERTIES };
		vk::PhysicalDeviceVulkan12Properties props12 = { .sType = PHYSICAL_DEVICE_VULKAN_1_2_PROPERTIES };
		vk::PhysicalDeviceVulkan13Properties props13 = { .sType = PHYSICAL_DEVICE_VULKAN_1_3_PROPERTIES };
		vk::PhysicalDeviceIDProperties device_id_properties = { .sType = PHYSICAL_DEVICE_ID_PROPERTIES };
		vk::PhysicalDeviceAccelerationStructurePropertiesKHR accel_structure_properties = { .sType = PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_PROPERTIES_KHR };
		vk::PhysicalDeviceRayTracingPipelinePropertiesKHR ray_tracing_pipeline_properties = { .sType = PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_PROPERTIES_KHR };

		vk_add_next(&properties, &props11);
		vk_add_next(&properties, &props12);
		vk_add_next(&properties, &props13);
		vk_add_next(&properties, &device_id_properties);
		if (has_acceleration_structure) vk_add_next(&properties, &accel_structure_properties);
		if (has_ray_tracing_pipeline) vk_add_next(&properties, &ray_tracing_pipeline_properties);

		vk::PhysicalDeviceFeatures2 features = { .sType = PHYSICAL_DEVICE_FEATURES_2 };
		vk::PhysicalDeviceVulkan11Features features11 = { .sType = PHYSICAL_DEVICE_VULKAN_1_1_FEATURES };
		vk::PhysicalDeviceVulkan12Features features12 = { .sType = PHYSICAL_DEVICE_VULKAN_1_2_FEATURES };
		vk::PhysicalDeviceVulkan13Features features13 = { .sType = PHYSICAL_DEVICE_VULKAN_1_3_FEATURES };
		vk::PhysicalDevicePresentIdFeaturesKHR present_id_features = { .sType = PHYSICAL_DEVICE_PRESENT_ID_FEATURES_KHR };
		vk::PhysicalDeviceAccelerationStructureFeaturesKHR accel_structure_features = { .sType = PHYSICAL_DEVICE_ACCELERATION_STRUCTURE_FEATURES_KHR };
		vk::PhysicalDeviceRayTracingPipelineFeaturesKHR ray_tracing_pipeline_features = { .sType = PHYSICAL_DEVICE_RAY_TRACING_PIPELINE_FEATURES_KHR };
		vk::PhysicalDeviceRayQueryFeaturesKHR ray_query_features = { .sType = PHYSICAL_DEVICE_RAY_QUERY_FEATURES_KHR };

		vk_add_next(&features, &features11);
		vk_add_next(&features, &features12);
		vk_add_next(&features, &features13);

		if (vk_has_extension(extension_properties, vk::KHR_PRESENT_ID_EXTENSION_NAME.str_view()))
		{
			vk_add_next(&features, &present_id_features);
		}
		if (has_acceleration_structure) vk_add_next(&features, &accel_structure_features);
		if (has_ray_tracing_pipeline) vk_add_next(&features, &ray_tracing_pipeline_features);
		if (has_ray_query) vk_add_next(&features, &ray_query_features);

		vk::PhysicalDeviceMemoryProperties memory_properties;
		vk::getPhysicalDeviceMemoryProperties(physical_device, &memory_properties);
		vk::getPhysicalDeviceProperties2(physical_device, &properties);
		vk::getPhysicalDeviceFeatures2(physical_device, &features);

		vk::PhysicalDeviceLimits* limits = &properties.properties.limits;

		PhysicalAdapter physical_adapter = {};

		ulong luid_val;
		for (int j = 0; j < 8; j++)
		{
			luid_val |= (ulong)device_id_properties.deviceLUID[j] << (ulong)(j * 8);
		}
		physical_adapter.luid = luid_val;

		physical_adapter.device_id = properties.properties.deviceID;
		physical_adapter.vendor = vendor_from_id(properties.properties.vendorID);
		physical_adapter.preset_level = gpu_preset_lookup(properties.properties.vendorID, properties.properties.deviceID);

		AdapterType adapter_type_val = OTHER;
		switch (properties.properties.deviceType)
		{
			case vk::PhysicalDeviceType.OTHER:
				adapter_type_val = OTHER;
			case vk::PhysicalDeviceType.INTEGRATED_GPU:
				adapter_type_val = INTEGRATED;
			case vk::PhysicalDeviceType.DISCRETE_GPU:
				adapter_type_val = DISCRETE;
			case vk::PhysicalDeviceType.VIRTUAL_GPU:
				adapter_type_val = VIRTUAL;
			case vk::PhysicalDeviceType.CPU:
				adapter_type_val = CPU;
			default:
				adapter_type_val = OTHER;
		}
		physical_adapter.adapter_type = adapter_type_val;

		physical_adapter.viewport_max_num = limits.maxViewports;
		physical_adapter.viewport_bounds_range = limits.viewportBoundsRange;

		physical_adapter.attachment_max_dim = min(limits.maxFramebufferWidth, limits.maxFramebufferHeight);
		physical_adapter.attachment_layer_max_num = limits.maxFramebufferLayers;
		physical_adapter.color_attachment_max_num = limits.maxColorAttachments;

		physical_adapter.color_sample_max_num = (uint)limits.framebufferColorSampleCounts;
		physical_adapter.depth_sample_max_num = (uint)limits.framebufferDepthSampleCounts;
		physical_adapter.stencil_sample_max_num = (uint)limits.framebufferStencilSampleCounts;
		physical_adapter.zero_attachments_sample_max_num = (uint)limits.framebufferNoAttachmentsSampleCounts;
		physical_adapter.texture_color_sample_max_num = (uint)limits.sampledImageColorSampleCounts;
		physical_adapter.texture_integer_sample_max_num = (uint)limits.sampledImageIntegerSampleCounts;
		physical_adapter.texture_depth_sample_max_num = (uint)limits.sampledImageDepthSampleCounts;
		physical_adapter.texture_stencil_sample_max_num = (uint)limits.sampledImageStencilSampleCounts;
		physical_adapter.storage_texture_sample_max_num = (uint)limits.storageImageSampleCounts;

		physical_adapter.texture_1d_max_dim = (ushort)min(limits.maxImageDimension1D, (uint)ushort::max);
		physical_adapter.texture_2d_max_dim = (ushort)min(limits.maxImageDimension2D, (uint)ushort::max);
		physical_adapter.texture_3d_max_dim = (ushort)min(limits.maxImageDimension3D, (uint)ushort::max);
		physical_adapter.texture_array_layer_max_num = (ushort)min(limits.maxImageArrayLayers, (uint)ushort::max);
		physical_adapter.typed_buffer_max_dim = limits.maxTexelBufferElements;
		physical_adapter.memory_allocation_max_num = limits.maxMemoryAllocationCount;
		physical_adapter.sampler_allocation_max_num = limits.maxSamplerAllocationCount;
		physical_adapter.constant_buffer_max_range = limits.maxUniformBufferRange;
		physical_adapter.storage_buffer_max_range = limits.maxStorageBufferRange;
		physical_adapter.buffer_texture_granularity = (ulong)limits.bufferImageGranularity;
		physical_adapter.buffer_max_size = (ulong)props13.maxBufferSize;

		physical_adapter.upload_buffer_texture_row_alignment = (uint)limits.optimalBufferCopyRowPitchAlignment;
		physical_adapter.upload_buffer_offset_alignment = (uint)limits.optimalBufferCopyOffsetAlignment;
		physical_adapter.buffer_shader_resource_offset_alignment = (uint)max(limits.minTexelBufferOffsetAlignment, limits.minStorageBufferOffsetAlignment);
		physical_adapter.constant_buffer_offset_alignment = (uint)limits.minUniformBufferOffsetAlignment;
		physical_adapter.scratch_buffer_offset_alignment = has_acceleration_structure ? accel_structure_properties.minAccelerationStructureScratchOffsetAlignment : 0;
		physical_adapter.shader_binding_table_alignment = has_ray_tracing_pipeline ? ray_tracing_pipeline_properties.shaderGroupBaseAlignment : 0;

		physical_adapter.pipeline_layout_descriptor_set_max_num = limits.maxBoundDescriptorSets;
		physical_adapter.pipeline_layout_root_constant_max_size = limits.maxPushConstantsSize;

		physical_adapter.per_stage_descriptor_sampler_max_num = limits.maxPerStageDescriptorSamplers;
		physical_adapter.per_stage_descriptor_constant_buffer_max_num = limits.maxPerStageDescriptorUniformBuffers;
		physical_adapter.per_stage_descriptor_storage_buffer_max_num = limits.maxPerStageDescriptorStorageBuffers;
		physical_adapter.per_stage_descriptor_texture_max_num = limits.maxPerStageDescriptorSampledImages;
		physical_adapter.per_stage_descriptor_storage_texture_max_num = limits.maxPerStageDescriptorStorageImages;
		physical_adapter.per_stage_resource_max_num = limits.maxPerStageResources;

		physical_adapter.descriptor_set_sampler_max_num = limits.maxDescriptorSetSamplers;
		physical_adapter.descriptor_set_constant_buffer_max_num = limits.maxDescriptorSetUniformBuffers;
		physical_adapter.descriptor_set_storage_buffer_max_num = limits.maxDescriptorSetStorageBuffers;
		physical_adapter.descriptor_set_texture_max_num = limits.maxDescriptorSetSampledImages;
		physical_adapter.descriptor_set_storage_texture_max_num = limits.maxDescriptorSetStorageImages;

		physical_adapter.vertex_shader_attribute_max_num = limits.maxVertexInputAttributes;
		physical_adapter.vertex_shader_stream_max_num = limits.maxVertexInputBindings;
		physical_adapter.vertex_shader_output_component_max_num = limits.maxVertexOutputComponents;

		physical_adapter.tess_control_shader_generation_max_level = limits.maxTessellationGenerationLevel;
		physical_adapter.tess_control_shader_patch_point_max_num = limits.maxTessellationPatchSize;
		physical_adapter.tess_control_shader_per_vertex_input_component_max_num = limits.maxTessellationControlPerVertexInputComponents;
		physical_adapter.tess_control_shader_per_vertex_output_component_max_num = limits.maxTessellationControlPerVertexOutputComponents;
		physical_adapter.tess_control_shader_per_patch_output_component_max_num = limits.maxTessellationControlPerPatchOutputComponents;
		physical_adapter.tess_control_shader_total_output_component_max_num = limits.maxTessellationControlTotalOutputComponents;
		physical_adapter.tess_evaluation_shader_input_component_max_num = limits.maxTessellationEvaluationInputComponents;
		physical_adapter.tess_evaluation_shader_output_component_max_num = limits.maxTessellationEvaluationOutputComponents;

		physical_adapter.geometry_shader_invocation_max_num = limits.maxGeometryShaderInvocations;
		physical_adapter.geometry_shader_input_component_max_num = limits.maxGeometryInputComponents;
		physical_adapter.geometry_shader_output_component_max_num = limits.maxGeometryOutputComponents;
		physical_adapter.geometry_shader_output_vertex_max_num = limits.maxGeometryOutputVertices;
		physical_adapter.geometry_shader_total_output_component_max_num = limits.maxGeometryTotalOutputComponents;

		physical_adapter.fragment_shader_input_component_max_num = limits.maxFragmentInputComponents;
		physical_adapter.fragment_shader_output_attachment_max_num = limits.maxFragmentOutputAttachments;
		physical_adapter.fragment_shader_dual_source_attachment_max_num = limits.maxFragmentDualSrcAttachments;

		physical_adapter.compute_shader_shared_memory_max_size = limits.maxComputeSharedMemorySize;
		physical_adapter.compute_shader_work_group_max_num = limits.maxComputeWorkGroupCount;
		physical_adapter.compute_shader_work_group_invocation_max_num = limits.maxComputeWorkGroupInvocations;
		physical_adapter.compute_shader_work_group_max_dim = limits.maxComputeWorkGroupSize;

		physical_adapter.ray_tracing_shader_group_identifier_size = has_ray_tracing_pipeline ? ray_tracing_pipeline_properties.shaderGroupHandleSize : 0;
		physical_adapter.ray_tracing_shader_table_max_stride = has_ray_tracing_pipeline ? ray_tracing_pipeline_properties.maxShaderGroupStride : 0;
		physical_adapter.ray_tracing_shader_recursion_max_depth = has_ray_tracing_pipeline ? ray_tracing_pipeline_properties.maxRayRecursionDepth : 0;
		physical_adapter.ray_tracing_geometry_object_max_num = has_acceleration_structure ? (uint)min(accel_structure_properties.maxGeometryCount, (ulong)uint::max) : 0;

		physical_adapter.viewport_precision_bits = limits.viewportSubPixelBits;
		physical_adapter.sub_pixel_precision_bits = limits.subPixelPrecisionBits;
		physical_adapter.sub_texel_precision_bits = limits.subTexelPrecisionBits;
		physical_adapter.mipmap_precision_bits = limits.mipmapPrecisionBits;

		physical_adapter.timestamp_frequency_hz = (ulong)(1e9 / (double)limits.timestampPeriod + 0.5);
		physical_adapter.draw_indirect_max_num = limits.maxDrawIndirectCount;
		physical_adapter.sampler_lod_bias_min = -limits.maxSamplerLodBias;
		physical_adapter.sampler_lod_bias_max = limits.maxSamplerLodBias;
		physical_adapter.sampler_anisotropy_max = limits.maxSamplerAnisotropy;
		physical_adapter.texel_offset_min = limits.minTexelOffset;
		physical_adapter.texel_offset_max = limits.maxTexelOffset;
		physical_adapter.texel_gather_offset_min = limits.minTexelGatherOffset;
		physical_adapter.texel_gather_offset_max = limits.maxTexelGatherOffset;
		physical_adapter.clip_distance_max_num = limits.maxClipDistances;
		physical_adapter.cull_distance_max_num = limits.maxCullDistances;
		physical_adapter.combined_clip_and_cull_distance_max_num = limits.maxCombinedClipAndCullDistances;

		physical_adapter.is_texture_filter_min_max_supported = features12.samplerFilterMinmax != vk::FALSE;
		physical_adapter.is_logic_func_supported = features.features.logicOp != vk::FALSE;
		physical_adapter.is_depth_bounds_test_supported = features.features.depthBounds != vk::FALSE;
		physical_adapter.is_draw_indirect_count_supported = features12.drawIndirectCount != vk::FALSE;
		physical_adapter.is_independent_front_and_back_stencil_reference_and_masks_supported = true;
		physical_adapter.is_copy_queue_timestamp_supported = limits.timestampComputeAndGraphics != vk::FALSE;
		physical_adapter.is_enchanced_barrier_supported = true;
		physical_adapter.is_memory_tier2_supported = true;
		physical_adapter.is_dynamic_depth_bias_supported = true;
		physical_adapter.is_viewport_origin_bottom_left_supported = true;
		physical_adapter.is_region_resolve_supported = true;

		physical_adapter.is_shader_native_i16_supported = features.features.shaderInt16 != vk::FALSE;
		physical_adapter.is_shader_native_f16_supported = features12.shaderFloat16 != vk::FALSE;
		physical_adapter.is_shader_native_i32_supported = true;
		physical_adapter.is_shader_native_f32_supported = true;
		physical_adapter.is_shader_native_i64_supported = features.features.shaderInt64 != vk::FALSE;
		physical_adapter.is_shader_native_f64_supported = features.features.shaderFloat64 != vk::FALSE;
		physical_adapter.is_shader_atomics_i32_supported = true;
		physical_adapter.is_shader_atomics_i64_supported = features12.shaderBufferInt64Atomics != vk::FALSE || features12.shaderSharedInt64Atomics != vk::FALSE;

		physical_adapter.backend.vk = {
			.physical_device = physical_device,
			.api_version = properties.properties.apiVersion,
			.is_present_id_supported = present_id_features.presentId != vk::FALSE,
			.is_swap_chain_supported = vk_has_extension(extension_properties, vk::KHR_SWAPCHAIN_EXTENSION_NAME.str_view()),
			.is_buffer_device_address_supported = properties.properties.apiVersion >= vk::API_VERSION_1_2 || vk_has_extension(extension_properties, vk::KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME.str_view()),
			.is_amd_device_coherent_memory_supported = vk_has_extension(extension_properties, vk::AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME.str_view()),
			.is_maintenance5_supported = vk_has_extension(extension_properties, vk::KHR_MAINTENANCE_5_EXTENSION_NAME.str_view()),
			.is_acceleration_structure_supported = has_acceleration_structure && accel_structure_features.accelerationStructure != vk::FALSE,
			.is_ray_tracing_pipeline_supported = has_ray_tracing_pipeline && ray_tracing_pipeline_features.rayTracingPipeline != vk::FALSE,
			.is_ray_query_supported = has_ray_query && ray_query_features.rayQuery != vk::FALSE,
			.is_deferred_host_operations_supported = has_deferred_host_operations,
		};

		for (uint heap_idx = 0; heap_idx < memory_properties.memoryHeapCount; heap_idx++)
		{
			vk::MemoryHeap heap = memory_properties.memoryHeaps[heap_idx];
			if ((heap.flags & vk::MEMORY_HEAP_DEVICE_LOCAL_BIT) && physical_adapter.adapter_type != INTEGRATED)
			{
				physical_adapter.video_memory_size += (ulong)heap.size;
			}
			else
			{
				physical_adapter.system_memory_size += (ulong)heap.size;
			}
		}

		for (uint type_idx = 0; type_idx < memory_properties.memoryTypeCount; type_idx++)
		{
			vk::MemoryType mem_type = memory_properties.memoryTypes[type_idx];
			if ((mem_type.propertyFlags & vk::MEMORY_PROPERTY_DEVICE_LOCAL_BIT) && !(mem_type.propertyFlags & vk::MEMORY_PROPERTY_HOST_VISIBLE_BIT))
			{
				physical_adapter.device_upload_heap_size += (ulong)memory_properties.memoryHeaps[mem_type.heapIndex].size;
			}
		}

		usz name_len = 0;
		while (name_len < properties.properties.deviceName.len && properties.properties.deviceName[name_len] != 0) name_len++;
		if (name_len > 0) physical_adapter.name[:name_len] = properties.properties.deviceName[:name_len];

		adapters.push(physical_adapter);
	}

	return adapters;
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral adapter description. Port of rhi-zig's `physical_adapter.zig`.
module rhi;
import std::collections::list;

enum Vendor : char
{
	UNKNOWN,
	NVIDIA,
	AMD,
	INTEL,
}

enum AdapterType : char
{
	OTHER,
	CPU,
	VIRTUAL,
	INTEGRATED,
	DISCRETE,
}

struct PhysicalAdapter
{
	union backend
	{
		PhysicalAdapterVk vk;
		PhysicalAdapterWgpu wgpu;
		PhysicalAdapterWebgl webgl;
		PhysicalAdapterDx12 dx12;
		PhysicalAdapterMtl mtl;
	}
	char[256] name;
	ulong luid;
	ulong video_memory_size;
	ulong system_memory_size;
	uint device_id;
	Vendor vendor;
	PresetLevel preset_level;
	AdapterType adapter_type;

	// Viewports
	uint viewport_max_num;
	float[2] viewport_bounds_range;

	// Attachments
	uint attachment_max_dim;
	uint attachment_layer_max_num;
	uint color_attachment_max_num;

	// Multi-sampling
	uint color_sample_max_num;
	uint depth_sample_max_num;
	uint stencil_sample_max_num;
	uint zero_attachments_sample_max_num;
	uint texture_color_sample_max_num;
	uint texture_integer_sample_max_num;
	uint texture_depth_sample_max_num;
	uint texture_stencil_sample_max_num;
	uint storage_texture_sample_max_num;

	// Resource dimensions
	ushort texture_1d_max_dim;
	ushort texture_2d_max_dim;
	ushort texture_3d_max_dim;
	ushort texture_array_layer_max_num;
	uint typed_buffer_max_dim;

	// Memory
	ulong device_upload_heap_size; // ReBAR
	uint memory_allocation_max_num;
	uint sampler_allocation_max_num;
	uint constant_buffer_max_range;
	uint storage_buffer_max_range;
	ulong buffer_texture_granularity;
	ulong buffer_max_size;

	// Memory alignment
	uint upload_buffer_texture_row_alignment;
	uint upload_buffer_offset_alignment;
	uint buffer_shader_resource_offset_alignment;
	uint constant_buffer_offset_alignment;
	uint scratch_buffer_offset_alignment;
	uint shader_binding_table_alignment;

	// Pipeline layout
	uint pipeline_layout_descriptor_set_max_num;
	uint pipeline_layout_root_constant_max_size;
	uint pipeline_layout_root_descriptor_max_num;

	// Descriptor set
	uint descriptor_set_sampler_max_num;
	uint descriptor_set_constant_buffer_max_num;
	uint descriptor_set_storage_buffer_max_num;
	uint descriptor_set_texture_max_num;
	uint descriptor_set_storage_texture_max_num;

	// Shader resources
	uint per_stage_descriptor_sampler_max_num;
	uint per_stage_descriptor_constant_buffer_max_num;
	uint per_stage_descriptor_storage_buffer_max_num;
	uint per_stage_descriptor_texture_max_num;
	uint per_stage_descriptor_storage_texture_max_num;
	uint per_stage_resource_max_num;

	// Vertex shader
	uint vertex_shader_attribute_max_num;
	uint vertex_shader_stream_max_num;
	uint vertex_shader_output_component_max_num;

	// Tessellation shaders
	uint tess_control_shader_generation_max_level;
	uint tess_control_shader_patch_point_max_num;
	uint tess_control_shader_per_vertex_input_component_max_num;
	uint tess_control_shader_per_vertex_output_component_max_num;
	uint tess_control_shader_per_patch_output_component_max_num;
	uint tess_control_shader_total_output_component_max_num;
	uint tess_evaluation_shader_input_component_max_num;
	uint tess_evaluation_shader_output_component_max_num;

	// Geometry shader
	uint geometry_shader_invocation_max_num;
	uint geometry_shader_input_component_max_num;
	uint geometry_shader_output_component_max_num;
	uint geometry_shader_output_vertex_max_num;
	uint geometry_shader_total_output_component_max_num;

	// Fragment shader
	uint fragment_shader_input_component_max_num;
	uint fragment_shader_output_attachment_max_num;
	uint fragment_shader_dual_source_attachment_max_num;

	// Compute shader
	uint compute_shader_shared_memory_max_size;
	uint[3] compute_shader_work_group_max_num;
	uint compute_shader_work_group_invocation_max_num;
	uint[3] compute_shader_work_group_max_dim;

	// Ray tracing
	uint ray_tracing_shader_group_identifier_size;
	uint ray_tracing_shader_table_max_stride;
	uint ray_tracing_shader_recursion_max_depth;
	uint ray_tracing_geometry_object_max_num;

	// Precision bits
	uint viewport_precision_bits;
	uint sub_pixel_precision_bits;
	uint sub_texel_precision_bits;
	uint mipmap_precision_bits;

	// Other
	ulong timestamp_frequency_hz;
	uint draw_indirect_max_num;
	float sampler_lod_bias_min;
	float sampler_lod_bias_max;
	float sampler_anisotropy_max;
	int texel_offset_min;
	uint texel_offset_max;
	int texel_gather_offset_min;
	uint texel_gather_offset_max;
	uint clip_distance_max_num;
	uint cull_distance_max_num;
	uint combined_clip_and_cull_distance_max_num;
	// shading_rate_attachment_tile_size: u8, // commented out
	// shader_model: u8, // commented out

	// Tiers
	// conservative_raster_tier: u8, // commented out
	// sample_locations_tier: u8, // commented out
	// ray_tracing_tier: u8, // commented out
	// shading_rate_tier: u8, // commented out
	// bindless_tier: u8, // commented out

	// Features (bitfields replaced with bool)
	bool is_texture_filter_min_max_supported;
	bool is_logic_func_supported;
	bool is_depth_bounds_test_supported;
	bool is_draw_indirect_count_supported;
	bool is_independent_front_and_back_stencil_reference_and_masks_supported;
	bool is_copy_queue_timestamp_supported;
	bool is_enchanced_barrier_supported;
	bool is_memory_tier2_supported;
	bool is_dynamic_depth_bias_supported;
	bool is_viewport_origin_bottom_left_supported;
	bool is_region_resolve_supported;

	// Shader features
	bool is_shader_native_i16_supported;
	bool is_shader_native_f16_supported;
	bool is_shader_native_i32_supported;
	bool is_shader_native_f32_supported;
	bool is_shader_native_i64_supported;
	bool is_shader_native_f64_supported;
	bool is_shader_atomics_i16_supported;
	bool is_shader_atomics_i32_supported;
	bool is_shader_atomics_i64_supported;

	// Emulated features
	bool is_draw_parameters_emulation_enabled;
}

fn PresetLevel gpu_preset_lookup(uint vendor_id, uint device_id)
{
	foreach (preset : DESKTOP_PRESETS)
	{
		if (preset.vendor_id == vendor_id && preset.model_id == device_id) return preset.preset_level;
	}
	return NONE;
}

fn Vendor vendor_from_id(uint id)
{
	switch (id)
	{
		case 0x10DE:
			return NVIDIA;
		case 0x1002:
			return AMD;
		case 0x8086:
			return INTEL;
	}
	return UNKNOWN;
}

fn sz default_select_adapter(PhysicalAdapter[] adapters)
{
	sz selected_adapter_index = 0;
	foreach (idx, adp : adapters)
	{
		if (adp.adapter_type.ordinal > adapters[selected_adapter_index].adapter_type.ordinal)
		{
			selected_adapter_index = idx;
		}
		if (adp.adapter_type.ordinal < adapters[selected_adapter_index].adapter_type.ordinal) continue;

		if (adp.preset_level.ordinal > adapters[selected_adapter_index].preset_level.ordinal)
		{
			selected_adapter_index = idx;
		}
		if (adp.preset_level.ordinal < adapters[selected_adapter_index].preset_level.ordinal) continue;

		if (adp.video_memory_size > adapters[selected_adapter_index].video_memory_size)
		{
			selected_adapter_index = idx;
		}
	}
	return selected_adapter_index;
}

fn String physical_adapter_name(PhysicalAdapter* a)
{
	sz n = 0;
	while (n < a.name.len && a.name[n] != 0) n++;
	return (String)a.name[:n];
}

// Web backends report only a subset of the native adapter limits. Keep the
// remainder explicitly conservative instead of making browser adapters look
// more capable than they are.
fn PhysicalAdapter physical_adapter_web_defaults()
{
	PhysicalAdapter a = {};
	a.viewport_max_num = 1;
	a.viewport_bounds_range = { -32768, 32767 };
	a.attachment_max_dim = 1;
	a.attachment_layer_max_num = 1;
	a.color_attachment_max_num = 1;
	a.color_sample_max_num = 1;
	a.depth_sample_max_num = 1;
	a.stencil_sample_max_num = 1;
	a.zero_attachments_sample_max_num = 1;
	a.texture_color_sample_max_num = 1;
	a.texture_integer_sample_max_num = 1;
	a.texture_depth_sample_max_num = 1;
	a.texture_stencil_sample_max_num = 1;
	a.storage_texture_sample_max_num = 1;
	a.texture_1d_max_dim = 1;
	a.texture_2d_max_dim = 1;
	a.texture_3d_max_dim = 1;
	a.texture_array_layer_max_num = 1;
	a.constant_buffer_max_range = 16 * 1024;
	a.storage_buffer_max_range = 0;
	a.buffer_max_size = 256 * 1024 * 1024;
	a.upload_buffer_texture_row_alignment = 256;
	a.upload_buffer_offset_alignment = 4;
	a.constant_buffer_offset_alignment = 256;
	a.pipeline_layout_descriptor_set_max_num = 1;
	a.descriptor_set_constant_buffer_max_num = 1;
	a.descriptor_set_texture_max_num = 1;
	a.descriptor_set_sampler_max_num = 1;
	a.per_stage_descriptor_constant_buffer_max_num = 1;
	a.per_stage_descriptor_texture_max_num = 1;
	a.per_stage_descriptor_sampler_max_num = 1;
	a.vertex_shader_attribute_max_num = 1;
	a.vertex_shader_stream_max_num = 1;
	a.vertex_shader_output_component_max_num = 4;
	a.fragment_shader_output_attachment_max_num = 1;
	a.compute_shader_work_group_max_num = { 1, 1, 1 };
	a.compute_shader_work_group_max_dim = { 1, 1, 1 };
	a.compute_shader_work_group_invocation_max_num = 1;
	a.sampler_lod_bias_min = -16;
	a.sampler_lod_bias_max = 16;
	a.sampler_anisotropy_max = 1;
	a.timestamp_frequency_hz = 1;
	a.draw_indirect_max_num = 1;
	return a;
}

fn void physical_adapter_set_name(PhysicalAdapter* a, String name)
{
	a.name = {};
	sz count = min(name.len, a.name.len - 1);
	if (count > 0) a.name[:count] = name[:count];
}

fn List{PhysicalAdapter}? enumerate_adapters(Allocator allocator = mem)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return enumerate_adapters_vk(allocator);
			$endif
		case DX12:
			$if HAS_DX12:
				return enumerate_adapters_dx12(allocator);
			$endif
		case MTL:
			$if HAS_MTL:
				return enumerate_adapters_mtl(allocator);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return enumerate_adapters_wgpu(allocator);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return enumerate_adapters_webgl(allocator);
			$endif
	}
	List{PhysicalAdapter} adapters;
	adapters.init(allocator, 0);
	return adapters;
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan helpers: default device extensions, pNext chaining, aspect and
// format mapping, and `vk::Result` to fault conversion.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

const ZString[*] DEFAULT_DEVICE_EXTENSIONS = {
	vk::KHR_SWAPCHAIN_EXTENSION_NAME,
	vk::KHR_MAINTENANCE_1_EXTENSION_NAME,
	vk::KHR_SHADER_DRAW_PARAMETERS_EXTENSION_NAME,
	vk::EXT_SHADER_SUBGROUP_BALLOT_EXTENSION_NAME,
	vk::EXT_SHADER_SUBGROUP_VOTE_EXTENSION_NAME,
	vk::KHR_DEDICATED_ALLOCATION_EXTENSION_NAME,
	vk::KHR_GET_MEMORY_REQUIREMENTS_2_EXTENSION_NAME,

	vk::KHR_DRAW_INDIRECT_COUNT_EXTENSION_NAME,
	vk::EXT_DEVICE_FAULT_EXTENSION_NAME,
	// Fragment shader interlock extension to be used for ROV type functionality in Vulkan
	vk::EXT_FRAGMENT_SHADER_INTERLOCK_EXTENSION_NAME,

	//************************************************************************/
	// AMD Specific Extensions
	//************************************************************************/
	vk::AMD_DRAW_INDIRECT_COUNT_EXTENSION_NAME,
	vk::AMD_SHADER_BALLOT_EXTENSION_NAME,
	vk::AMD_GCN_SHADER_EXTENSION_NAME,
	vk::AMD_BUFFER_MARKER_EXTENSION_NAME,
	vk::AMD_DEVICE_COHERENT_MEMORY_EXTENSION_NAME,
	//************************************************************************/
	// Multi GPU Extensions
	//************************************************************************/
	vk::KHR_DEVICE_GROUP_EXTENSION_NAME,
	//************************************************************************/
	// Bindless & Non Uniform access Extensions
	//************************************************************************/
	vk::EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME,
	vk::KHR_MAINTENANCE_3_EXTENSION_NAME,
	// Required by raytracing and the new bindless descriptor API if we use it in future
	vk::KHR_BUFFER_DEVICE_ADDRESS_EXTENSION_NAME,
	//************************************************************************/
	// Shader Atomic Int 64 Extension
	//************************************************************************/
	vk::KHR_SHADER_ATOMIC_INT64_EXTENSION_NAME,
	//************************************************************************/
	//************************************************************************/
	vk::KHR_RAY_QUERY_EXTENSION_NAME,
	vk::KHR_RAY_TRACING_PIPELINE_EXTENSION_NAME,
	// Required by VK_KHR_ray_tracing_pipeline
	vk::KHR_SPIRV_1_4_EXTENSION_NAME,
	// Required by VK_KHR_spirv_1_4
	vk::KHR_SHADER_FLOAT_CONTROLS_EXTENSION_NAME,

	vk::KHR_ACCELERATION_STRUCTURE_EXTENSION_NAME,
	// Required by VK_KHR_acceleration_structure
	vk::KHR_DEFERRED_HOST_OPERATIONS_EXTENSION_NAME,
	//************************************************************************/
	// YCbCr format support
	//************************************************************************/
	// Requirement for VK_KHR_sampler_ycbcr_conversion
	vk::KHR_BIND_MEMORY_2_EXTENSION_NAME,
	vk::KHR_SAMPLER_YCBCR_CONVERSION_EXTENSION_NAME,
	vk::KHR_IMAGE_FORMAT_LIST_EXTENSION_NAME,
	vk::EXT_SAMPLE_LOCATIONS_EXTENSION_NAME,
	//************************************************************************/
	// Dynamic rendering
	//************************************************************************/
	vk::KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
	vk::KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME, // Required by VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME
	vk::KHR_CREATE_RENDERPASS_2_EXTENSION_NAME, // Required by VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME
	vk::KHR_MULTIVIEW_EXTENSION_NAME, // Required by VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME
	//************************************************************************/
	// Nsight Aftermath
	//************************************************************************/
	vk::EXT_ASTC_DECODE_MODE_EXTENSION_NAME,
};

fn bool vk_has_extension(vk::ExtensionProperties[] props, String name)
{
	foreach (&p : props)
	{
		if (((ZString)&p.extensionName).str_view() == name) return true;
	}
	return false;
}

// Splices `next`
// into `current`'s pNext chain right after `current`.
<*
 @require @kindof(current) == POINTER && @kindof(next) == POINTER
*>
macro void vk_add_next(current, next)
{
	void* tmp = current.pNext;
	current.pNext = next;
	next.pNext = tmp;
}

fn vk::ImageAspectFlags vk_image_aspect_from_format(Format f)
{
	FormatProperties props = format_get_props(f);
	vk::ImageAspectFlags result;
	if (props.is_stencil) result |= vk::IMAGE_ASPECT_STENCIL_BIT;
	if (props.is_depth) result |= vk::IMAGE_ASPECT_DEPTH_BIT;
	if (result) return result;
	return vk::IMAGE_ASPECT_COLOR_BIT;
}

fn vk::ImageAspectFlags vk_image_aspect_from_vk_format(vk::Format f, bool include_stencil)
{
	switch (f)
	{
		case vk::Format.D16_UNORM:
		case vk::Format.X8_D24_UNORM_PACK32:
		case vk::Format.D32_SFLOAT:
			return vk::IMAGE_ASPECT_DEPTH_BIT;
		case vk::Format.S8_UINT:
			return vk::IMAGE_ASPECT_STENCIL_BIT;
		case vk::Format.D16_UNORM_S8_UINT:
		case vk::Format.D24_UNORM_S8_UINT:
		case vk::Format.D32_SFLOAT_S8_UINT:
			vk::ImageAspectFlags result = vk::IMAGE_ASPECT_DEPTH_BIT;
			if (include_stencil) result |= vk::IMAGE_ASPECT_STENCIL_BIT;
			return result;
		default:
			return vk::IMAGE_ASPECT_COLOR_BIT;
	}
}

fn void? vk_check(vk::Result r)
{
	switch (r)
	{
		case vk::Result.SUCCESS:
			return;
		case vk::Result.ERROR_OUT_OF_DEVICE_MEMORY:
		case vk::Result.ERROR_OUT_OF_HOST_MEMORY:
			return OUT_OF_DEVICE_MEMORY~;
		case vk::Result.ERROR_DEVICE_LOST:
			return DEVICE_LOST~;
		case (vk::Result)-1000000000:
			return SURFACE_LOST~;
		case (vk::Result)-1000001004:
			return OUT_OF_DATE~;
		case vk::Result.TIMEOUT:
			return TIMEOUT~;
		default:
			log::error("Unknown Vulkan result: %d", (int)r);
			return UNKNOWN~;
	}
}

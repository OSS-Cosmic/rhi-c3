// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan helpers: default device extensions, pNext chaining, aspect and
// format mapping, and `vk::Result` to fault conversion.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

const ZString[*] DEFAULT_DEVICE_EXTENSIONS = {
	"VK_KHR_swapchain",
	"VK_KHR_maintenance_1",
	"VK_KHR_shader_draw_parameters",
	"VK_EXT_shader_subgroup_ballot",
	"VK_EXT_shader_subgroup_vote",
	"VK_KHR_dedicated_allocation",
	"VK_KHR_get_memory_requirements_2",

	"VK_KHR_draw_indirect_count",
	"VK_EXT_device_fault",
	// Fragment shader interlock extension to be used for ROV type functionality in Vulkan
	"VK_EXT_fragment_shader_interlock",

	//************************************************************************/
	// AMD Specific Extensions
	//************************************************************************/
	"VK_AMD_draw_indirect_count",
	"VK_AMD_shader_ballot",
	"VK_AMD_gcn_shader",
	"VK_AMD_buffer_marker",
	"VK_AMD_device_coherent_memory",
	//************************************************************************/
	// Multi GPU Extensions
	//************************************************************************/
	"VK_KHR_device_group",
	//************************************************************************/
	// Bindless & Non Uniform access Extensions
	//************************************************************************/
	"VK_EXT_descriptor_indexing",
	"VK_KHR_maintenance_3",
	// Required by raytracing and the new bindless descriptor API if we use it in future
	"VK_KHR_buffer_device_address",
	//************************************************************************/
	// Shader Atomic Int 64 Extension
	//************************************************************************/
	"VK_KHR_shader_atomic_int64",
	//************************************************************************/
	//************************************************************************/
	"VK_KHR_ray_query",
	"VK_KHR_ray_tracing_pipeline",
	// Required by VK_KHR_ray_tracing_pipeline
	"VK_KHR_spirv_1_4",
	// Required by VK_KHR_spirv_1_4
	"VK_KHR_shader_float_controls",

	"VK_KHR_acceleration_structure",
	// Required by VK_KHR_acceleration_structure
	"VK_KHR_deferred_host_operations",
	//************************************************************************/
	// YCbCr format support
	//************************************************************************/
	// Requirement for VK_KHR_sampler_ycbcr_conversion
	"VK_KHR_bind_memory_2",
	"VK_KHR_sampler_ycbcr_conversion",
	"VK_KHR_image_format_list",
	"VK_EXT_sample_locations",
	//************************************************************************/
	// Dynamic rendering
	//************************************************************************/
	"VK_KHR_dynamic_rendering",
	"VK_KHR_depth_stencil_resolve", // Required by VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME
	"VK_KHR_create_renderpass_2", // Required by VK_KHR_DEPTH_STENCIL_RESOLVE_EXTENSION_NAME
	"VK_KHR_multiview", // Required by VK_KHR_CREATE_RENDERPASS_2_EXTENSION_NAME
	//************************************************************************/
	// Nsight Aftermath
	//************************************************************************/
	"VK_EXT_astc_decode_mode",
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
	if (props.is_stencil) result |= vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
	if (props.is_depth) result |= vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT;
	if (result) return result;
	return vk::ImageAspectFlagBits.IMAGE_ASPECT_COLOR_BIT;
}

fn vk::ImageAspectFlags vk_image_aspect_from_vk_format(vk::Format f, bool include_stencil)
{
	switch (f)
	{
		case vk::Format.FORMAT_D16_UNORM:
		case vk::Format.FORMAT_X8_D24_UNORM_PACK32:
		case vk::Format.FORMAT_D32_SFLOAT:
			return vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT;
		case vk::Format.FORMAT_S8_UINT:
			return vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
		case vk::Format.FORMAT_D16_UNORM_S8_UINT:
		case vk::Format.FORMAT_D24_UNORM_S8_UINT:
		case vk::Format.FORMAT_D32_SFLOAT_S8_UINT:
			vk::ImageAspectFlags result = vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT;
			if (include_stencil) result |= vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
			return result;
		default:
			return vk::ImageAspectFlagBits.IMAGE_ASPECT_COLOR_BIT;
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

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

struct VkFormatMapping
{
	Format rhi;
	vk::Format vk;
}

const VkFormatMapping[*] VK_FORMAT_MAPPINGS = {
	{ .rhi = Format.UNKNOWN, .vk = vk::Format.UNDEFINED },
	{ .rhi = Format.D16_UNORM_S8_UINT, .vk = vk::Format.D16_UNORM_S8_UINT },
	{ .rhi = Format.D24_UNORM_S8_UINT, .vk = vk::Format.D24_UNORM_S8_UINT },
	{ .rhi = Format.D32_SFLOAT_S8_UINT, .vk = vk::Format.D32_SFLOAT_S8_UINT },
	{ .rhi = Format.R8_UNORM, .vk = vk::Format.R8_UNORM },
	{ .rhi = Format.R8_SNORM, .vk = vk::Format.R8_SNORM },
	{ .rhi = Format.R8_UINT, .vk = vk::Format.R8_UINT },
	{ .rhi = Format.R8_SINT, .vk = vk::Format.R8_SINT },
	{ .rhi = Format.RG8_UNORM, .vk = vk::Format.R8G8_UNORM },
	{ .rhi = Format.RG8_SNORM, .vk = vk::Format.R8G8_SNORM },
	{ .rhi = Format.RG8_UINT, .vk = vk::Format.R8G8_UINT },
	{ .rhi = Format.RG8_SINT, .vk = vk::Format.R8G8_SINT },
	{ .rhi = Format.BGRA8_UNORM, .vk = vk::Format.B8G8R8A8_UNORM },
	{ .rhi = Format.BGRA8_SRGB, .vk = vk::Format.B8G8R8A8_SRGB },
	{ .rhi = Format.BGR8_UNORM, .vk = vk::Format.B8G8R8_UNORM },
	{ .rhi = Format.RGB8_UNORM, .vk = vk::Format.R8G8B8_UNORM },
	{ .rhi = Format.RGBA8_UNORM, .vk = vk::Format.R8G8B8A8_UNORM },
	{ .rhi = Format.RGBA8_SNORM, .vk = vk::Format.R8G8B8A8_SNORM },
	{ .rhi = Format.RGBA8_UINT, .vk = vk::Format.R8G8B8A8_UINT },
	{ .rhi = Format.RGBA8_SINT, .vk = vk::Format.R8G8B8A8_SINT },
	{ .rhi = Format.RGBA8_SRGB, .vk = vk::Format.R8G8B8A8_SRGB },
	{ .rhi = Format.R16_UNORM, .vk = vk::Format.R16_UNORM },
	{ .rhi = Format.R16_SNORM, .vk = vk::Format.R16_SNORM },
	{ .rhi = Format.R16_UINT, .vk = vk::Format.R16_UINT },
	{ .rhi = Format.R16_SINT, .vk = vk::Format.R16_SINT },
	{ .rhi = Format.R16_SFLOAT, .vk = vk::Format.R16_SFLOAT },
	{ .rhi = Format.RG16_UNORM, .vk = vk::Format.R16G16_UNORM },
	{ .rhi = Format.RG16_SNORM, .vk = vk::Format.R16G16_SNORM },
	{ .rhi = Format.RG16_UINT, .vk = vk::Format.R16G16_UINT },
	{ .rhi = Format.RG16_SINT, .vk = vk::Format.R16G16_SINT },
	{ .rhi = Format.RG16_SFLOAT, .vk = vk::Format.R16G16_SFLOAT },
	{ .rhi = Format.RGBA16_UNORM, .vk = vk::Format.R16G16B16A16_UNORM },
	{ .rhi = Format.RGBA16_SNORM, .vk = vk::Format.R16G16B16A16_SNORM },
	{ .rhi = Format.RGBA16_UINT, .vk = vk::Format.R16G16B16A16_UINT },
	{ .rhi = Format.RGBA16_SINT, .vk = vk::Format.R16G16B16A16_SINT },
	{ .rhi = Format.RGBA16_SFLOAT, .vk = vk::Format.R16G16B16A16_SFLOAT },
	{ .rhi = Format.R32_UINT, .vk = vk::Format.R32_UINT },
	{ .rhi = Format.R32_SINT, .vk = vk::Format.R32_SINT },
	{ .rhi = Format.R32_SFLOAT, .vk = vk::Format.R32_SFLOAT },
	{ .rhi = Format.RG32_UINT, .vk = vk::Format.R32G32_UINT },
	{ .rhi = Format.RG32_SINT, .vk = vk::Format.R32G32_SINT },
	{ .rhi = Format.RG32_SFLOAT, .vk = vk::Format.R32G32_SFLOAT },
	{ .rhi = Format.RGB32_UINT, .vk = vk::Format.R32G32B32_UINT },
	{ .rhi = Format.RGB32_SINT, .vk = vk::Format.R32G32B32_SINT },
	{ .rhi = Format.RGB32_SFLOAT, .vk = vk::Format.R32G32B32_SFLOAT },
	{ .rhi = Format.RGBA32_UINT, .vk = vk::Format.R32G32B32A32_UINT },
	{ .rhi = Format.RGBA32_SINT, .vk = vk::Format.R32G32B32A32_SINT },
	{ .rhi = Format.RGBA32_SFLOAT, .vk = vk::Format.R32G32B32A32_SFLOAT },
	{ .rhi = Format.R10_G10_B10_A2_UNORM, .vk = vk::Format.A2B10G10R10_UNORM_PACK32 },
	{ .rhi = Format.R10_G10_B10_A2_UINT, .vk = vk::Format.A2B10G10R10_UINT_PACK32 },
	{ .rhi = Format.R11_G11_B10_UFLOAT, .vk = vk::Format.B10G11R11_UFLOAT_PACK32 },
	{ .rhi = Format.R9_G9_B9_E5_UNORM, .vk = vk::Format.E5B9G9R9_UFLOAT_PACK32 },
	{ .rhi = Format.R5_G6_B5_UNORM, .vk = vk::Format.R5G6B5_UNORM_PACK16 },
	{ .rhi = Format.R5_G5_B5_A1_UNORM, .vk = vk::Format.A1R5G5B5_UNORM_PACK16 },
	{ .rhi = Format.R4_G4_B4_A4_UNORM, .vk = vk::Format.A4R4G4B4_UNORM_PACK16 },
	{ .rhi = Format.BC1_RGBA_UNORM, .vk = vk::Format.BC1_RGBA_UNORM_BLOCK },
	{ .rhi = Format.BC1_RGBA_SRGB, .vk = vk::Format.BC1_RGBA_SRGB_BLOCK },
	{ .rhi = Format.BC2_RGBA_UNORM, .vk = vk::Format.BC2_UNORM_BLOCK },
	{ .rhi = Format.BC2_RGBA_SRGB, .vk = vk::Format.BC2_SRGB_BLOCK },
	{ .rhi = Format.BC3_RGBA_UNORM, .vk = vk::Format.BC3_UNORM_BLOCK },
	{ .rhi = Format.BC3_RGBA_SRGB, .vk = vk::Format.BC3_SRGB_BLOCK },
	{ .rhi = Format.BC4_R_UNORM, .vk = vk::Format.BC4_UNORM_BLOCK },
	{ .rhi = Format.BC4_R_SNORM, .vk = vk::Format.BC4_SNORM_BLOCK },
	{ .rhi = Format.BC5_RG_UNORM, .vk = vk::Format.BC5_UNORM_BLOCK },
	{ .rhi = Format.BC5_RG_SNORM, .vk = vk::Format.BC5_SNORM_BLOCK },
	{ .rhi = Format.BC6H_RGB_UFLOAT, .vk = vk::Format.BC6H_UFLOAT_BLOCK },
	{ .rhi = Format.BC6H_RGB_SFLOAT, .vk = vk::Format.BC6H_SFLOAT_BLOCK },
	{ .rhi = Format.BC7_RGBA_UNORM, .vk = vk::Format.BC7_UNORM_BLOCK },
	{ .rhi = Format.BC7_RGBA_SRGB, .vk = vk::Format.BC7_SRGB_BLOCK },
	{ .rhi = Format.D16_UNORM, .vk = vk::Format.D16_UNORM },
	{ .rhi = Format.D32_SFLOAT, .vk = vk::Format.D32_SFLOAT },
	{ .rhi = Format.D32_SFLOAT_S8_UINT_X24, .vk = vk::Format.D32_SFLOAT_S8_UINT },
	{ .rhi = Format.R24_UNORM_X8, .vk = vk::Format.D24_UNORM_S8_UINT },
	{ .rhi = Format.X24_R8_UINT, .vk = vk::Format.D24_UNORM_S8_UINT },
	{ .rhi = Format.X32_R8_UINT_X24, .vk = vk::Format.D32_SFLOAT_S8_UINT },
	{ .rhi = Format.R32_SFLOAT_X8_X24, .vk = vk::Format.D32_SFLOAT_S8_UINT },
	{ .rhi = Format.ETC2_R8G8B8_UNORM, .vk = vk::Format.ETC2_R8G8B8_UNORM_BLOCK }, // Canonical for this block type normally
	{ .rhi = Format.ETC1_R8G8B8_OES, .vk = vk::Format.ETC2_R8G8B8_UNORM_BLOCK }, // Alias
	{ .rhi = Format.ETC2_R8G8B8_SRGB, .vk = vk::Format.ETC2_R8G8B8_SRGB_BLOCK },
	{ .rhi = Format.ETC2_R8G8B8A1_UNORM, .vk = vk::Format.ETC2_R8G8B8A1_UNORM_BLOCK },
	{ .rhi = Format.ETC2_R8G8B8A1_SRGB, .vk = vk::Format.ETC2_R8G8B8A1_SRGB_BLOCK },
	{ .rhi = Format.ETC2_R8G8B8A8_UNORM, .vk = vk::Format.ETC2_R8G8B8A8_UNORM_BLOCK },
	{ .rhi = Format.ETC2_R8G8B8A8_SRGB, .vk = vk::Format.ETC2_R8G8B8A8_SRGB_BLOCK },
	{ .rhi = Format.ETC2_EAC_R11_UNORM, .vk = vk::Format.EAC_R11_UNORM_BLOCK },
	{ .rhi = Format.ETC2_EAC_R11_SNORM, .vk = vk::Format.EAC_R11_SNORM_BLOCK },
	{ .rhi = Format.ETC2_EAC_R11G11_UNORM, .vk = vk::Format.EAC_R11G11_UNORM_BLOCK },
	{ .rhi = Format.ETC2_EAC_R11G11_SNORM, .vk = vk::Format.EAC_R11G11_SNORM_BLOCK },
};

fn vk::Format to_vk_format(Format format)
{
	foreach (m : VK_FORMAT_MAPPINGS)
	{
		if (m.rhi == format) return m.vk;
	}
	return vk::Format.UNDEFINED;
}

fn Format from_vk_format(vk::Format format)
{
	foreach (m : VK_FORMAT_MAPPINGS)
	{
		if (m.vk == format) return m.rhi;
	}
	return Format.UNKNOWN;
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
		case vk::Result.ERROR_SURFACE_LOST_KHR:
			return SURFACE_LOST~;
		case vk::Result.ERROR_OUT_OF_DATE_KHR:
			return OUT_OF_DATE~;
		case vk::Result.TIMEOUT:
			return TIMEOUT~;
		default:
			log::error("Unknown Vulkan result: %d", (int)r);
			return UNKNOWN~;
	}
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan image views.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct ImageViewVk
{
	vk::ImageView view;
	bool borrowed;
}

fn vk::ImageAspectFlags image_view_aspect_vk(ImageAspect aspect) @private
{
	switch (aspect)
	{
		case COLOR: return vk::IMAGE_ASPECT_COLOR_BIT;
		case DEPTH: return vk::IMAGE_ASPECT_DEPTH_BIT;
		case STENCIL: return vk::IMAGE_ASPECT_STENCIL_BIT;
		case DEPTH_STENCIL: return vk::IMAGE_ASPECT_DEPTH_BIT | vk::IMAGE_ASPECT_STENCIL_BIT;
	}
}

fn vk::ImageViewType image_view_type_vk(ViewType type) @private
{
	switch (type)
	{
		case SHADER_RESOURCE_1D:
		case SHADER_RESOURCE_STORAGE_1D: return vk::ImageViewType.D1;
		case SHADER_RESOURCE_1D_ARRAY:
		case SHADER_RESOURCE_STORAGE_1D_ARRAY: return vk::ImageViewType.D1_ARRAY;
		case SHADER_RESOURCE_2D:
		case SHADER_RESOURCE_STORAGE_2D:
		case COLOR_ATTACHMENT:
		case DEPTH_STENCIL_ATTACHMENT:
		case DEPTH_READONLY_STENCIL_ATTACHMENT:
		case DEPTH_ATTACHMENT_STENCIL_READONLY:
		case DEPTH_STENCIL_READONLY:
		case SHADING_RATE_ATTACHMENT: return vk::ImageViewType.D2;
		case SHADER_RESOURCE_2D_ARRAY:
		case SHADER_RESOURCE_STORAGE_2D_ARRAY: return vk::ImageViewType.D2_ARRAY;
		case SHADER_RESOURCE_CUBE: return vk::ImageViewType.CUBE;
		case SHADER_RESOURCE_CUBE_ARRAY: return vk::ImageViewType.CUBE_ARRAY;
		case SHADER_RESOURCE_3D:
		case SHADER_RESOURCE_STORAGE_3D: return vk::ImageViewType.D3;
	}
}

fn ImageView? image_view_init_vk(Device* device, Image* image, ViewDesc desc)
{
	if (image == null || image.cookie == 0 || image.backend.vk.image == vk::NULL_HANDLE) return UNSUPPORTED_FEATURE~;
	vk::ImageViewCreateInfo create_info = {
		.sType = vk::StructureType.IMAGE_VIEW_CREATE_INFO,
		.image = image.backend.vk.image,
		.viewType = image_view_type_vk(desc.view_type),
		.format = to_vk_format(desc.format),
		.components = {
			.r = vk::ComponentSwizzle.IDENTITY,
			.g = vk::ComponentSwizzle.IDENTITY,
			.b = vk::ComponentSwizzle.IDENTITY,
			.a = vk::ComponentSwizzle.IDENTITY,
		},
		.subresourceRange = {
			.aspectMask = image_view_aspect_vk(desc.aspect),
			.baseMipLevel = desc.base_mip,
			.levelCount = desc.mip_num,
			.baseArrayLayer = desc.base_layer,
			.layerCount = desc.layer_num,
		},
	};
	vk::ImageView view;
	vk_check(device.backend.vk.vtable.createImageView(device.backend.vk.device, &create_info, null, &view))!;
	return {
		.cookie = next_cookie(),
		.backend.vk = { .view = view, .borrowed = false },
	};
}

fn void image_view_deinit_vk(ImageView* v, Device* device)
{
	if (v.backend.vk.borrowed) return;
	if (v.backend.vk.view != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyImageView(device.backend.vk.device, v.backend.vk.view, null);
	}
	v.backend.vk = {};
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal image views.  A view keeps the parent texture retained so an Image
// may be released only after all of its views have been released.  A full
// range, same-format view aliases the parent; sub-ranges use Metal's native
// texture-view object.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct ImageViewMtlState
{
	mtl::Texture texture;
	mtl::Texture parent;
	bool aliases_parent;
}

fn mtl::TextureType mtl_view_texture_type(ViewType view_type)
{
	switch (view_type)
	{
		case SHADER_RESOURCE_1D: return mtl::TextureType.TYPE_1D;
		case SHADER_RESOURCE_1D_ARRAY: return mtl::TextureType.TYPE_1D_ARRAY;
		case SHADER_RESOURCE_2D: return mtl::TextureType.TYPE_2D;
		case SHADER_RESOURCE_2D_ARRAY: return mtl::TextureType.TYPE_2D_ARRAY;
		case SHADER_RESOURCE_CUBE: return mtl::TextureType.TYPE_CUBE;
		case SHADER_RESOURCE_CUBE_ARRAY: return mtl::TextureType.TYPE_CUBE_ARRAY;
		case SHADER_RESOURCE_3D: return mtl::TextureType.TYPE_3D;
		case SHADER_RESOURCE_STORAGE_1D: return mtl::TextureType.TYPE_1D;
		case SHADER_RESOURCE_STORAGE_1D_ARRAY: return mtl::TextureType.TYPE_1D_ARRAY;
		case SHADER_RESOURCE_STORAGE_2D: return mtl::TextureType.TYPE_2D;
		case SHADER_RESOURCE_STORAGE_2D_ARRAY: return mtl::TextureType.TYPE_2D_ARRAY;
		case SHADER_RESOURCE_STORAGE_3D: return mtl::TextureType.TYPE_3D;
		case COLOR_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_STENCIL_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_READONLY_STENCIL_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_ATTACHMENT_STENCIL_READONLY: return mtl::TextureType.TYPE_2D;
		case DEPTH_STENCIL_READONLY: return mtl::TextureType.TYPE_2D;
		case SHADING_RATE_ATTACHMENT: return mtl::TextureType.TYPE_2D;
	}
}

fn bool mtl_view_full_range(ImageMtlState* image, ViewDesc desc)
{
	return desc.base_mip == 0 && desc.mip_num == image.mip_levels &&
		desc.base_layer == 0 && desc.layer_num == image.array_layers &&
		desc.format == image.format && mtl_view_texture_type(desc.view_type) == image.texture_type;
}

fn ImageView? image_view_init_mtl_impl(Device* device, Image* image, ViewDesc desc)
{
	if (image == null || image.cookie == 0 || !image.backend.mtl.texture ||
		desc.mip_num == 0 || desc.layer_num == 0)
	{
		return UNSUPPORTED_FEATURE~;
	}
	ImageMtlState* parent_state = &image.backend.mtl;
	if (desc.base_mip >= parent_state.mip_levels || desc.mip_num > parent_state.mip_levels - desc.base_mip ||
		desc.base_layer >= parent_state.array_layers || desc.layer_num > parent_state.array_layers - desc.base_layer)
	{
		return UNSUPPORTED_FEATURE~;
	}
	if (parent_state.image_type == D3 && (desc.base_layer != 0 || desc.layer_num != 1))
	{
		return UNSUPPORTED_FEATURE~;
	}
	if (to_mtl_pixel_format(desc.format) == mtl::PixelFormat.INVALID)
	{
		return UNSUPPORTED_FEATURE~;
	}

	mtl::Texture parent = parent_state.texture;
	parent.retain();
	if (mtl_view_full_range(parent_state, desc))
	{
		return {
			.cookie = next_cookie(),
			.backend.mtl = { .texture = parent, .parent = parent, .aliases_parent = true },
		};
	}

	mtl::NSRange levels = { .location = desc.base_mip, .length = desc.mip_num };
	mtl::NSRange slices = { .location = desc.base_layer, .length = desc.layer_num };
	mtl::Texture view = parent.new_texture_view(
		to_mtl_pixel_format(desc.format), mtl_view_texture_type(desc.view_type), levels, slices);
	if (!view)
	{
		parent.release();
		return OUT_OF_DEVICE_MEMORY~;
	}
	return {
		.cookie = next_cookie(),
		.backend.mtl = { .texture = view, .parent = parent, .aliases_parent = false },
	};
}

fn void image_view_deinit_mtl_impl(ImageView* view, Device* device)
{
	if (view.backend.mtl.aliases_parent)
	{
		if (view.backend.mtl.parent) view.backend.mtl.parent.release();
	}
	else
	{
		if (view.backend.mtl.texture) view.backend.mtl.texture.release();
		if (view.backend.mtl.parent) view.backend.mtl.parent.release();
	}
	view.backend.mtl = {};
}

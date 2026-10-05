// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral image view handle. Port of the Vulkan arm of rhi-zig's
// `image_view.zig` `ImageView` type.
module rhi;

enum ViewType : char
{
	SHADER_RESOURCE_1D,
	SHADER_RESOURCE_1D_ARRAY,
	SHADER_RESOURCE_2D,
	SHADER_RESOURCE_2D_ARRAY,
	SHADER_RESOURCE_CUBE,
	SHADER_RESOURCE_CUBE_ARRAY,
	SHADER_RESOURCE_3D,
	SHADER_RESOURCE_STORAGE_1D,
	SHADER_RESOURCE_STORAGE_1D_ARRAY,
	SHADER_RESOURCE_STORAGE_2D,
	SHADER_RESOURCE_STORAGE_2D_ARRAY,
	SHADER_RESOURCE_STORAGE_3D,
	COLOR_ATTACHMENT,
	DEPTH_STENCIL_ATTACHMENT,
	DEPTH_READONLY_STENCIL_ATTACHMENT,
	DEPTH_ATTACHMENT_STENCIL_READONLY,
	DEPTH_STENCIL_READONLY,
	SHADING_RATE_ATTACHMENT,
}

enum ImageAspect : char
{
	COLOR,
	DEPTH,
	STENCIL,
	DEPTH_STENCIL,
}

struct ViewDesc
{
	ViewType view_type;
	Format format;
	ImageAspect aspect;
	uint base_mip;
	uint mip_num;
	uint base_layer;
	uint layer_num;
}

struct ImageView
{
	ulong cookie;
	union backend
	{
		ImageViewVk vk;
		ImageViewDx12 dx12;
		ImageViewWgpu wgpu;
		ImageViewWebgl webgl;
		ImageViewMtlState mtl;
	}
}

fn ImageView? image_view_init(Device* device, Image* image, ViewDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return image_view_init_vk(device, image, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return image_view_init_dx12(device, image, desc);
			$endif
		case MTL:
			$if HAS_MTL:
				return image_view_init_mtl_impl(device, image, desc);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return image_view_init_wgpu(device, image, desc);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return image_view_init_webgl(device, image, desc);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void image_view_deinit(ImageView* v, Device* device)
{
	if (v == null || v.cookie == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				image_view_deinit_vk(v, device);
			$endif
		case DX12:
			$if HAS_DX12:
				image_view_deinit_dx12(v, device);
			$endif
		case MTL:
			$if HAS_MTL:
				image_view_deinit_mtl_impl(v, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				image_view_deinit_wgpu(v, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				image_view_deinit_webgl(v, device);
			$endif
	}
	// All backends share this guard, making deinit idempotent at the RHI layer.
	v.cookie = 0;
}

fn bool image_view_is_empty(ImageView* v)
{
	return v.cookie == 0;
}

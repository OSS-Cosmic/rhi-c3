// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral image handle. Port of the Vulkan arm of rhi-zig's
// `image.zig` `Image` type.
module rhi;

enum ImageType : char
{
	D1,
	D2,
	D3,
}

enum ImageTiling : char
{
	OPTIMAL,
	LINEAR,
}

enum ImageSampleCount : char
{
	S1,
	S2,
	S4,
	S8,
	S16,
	S32,
	S64,
}

enum ImageUsageFlag : char
{
	TRANSFER_SRC,
	TRANSFER_DST,
	SAMPLED,
	STORAGE,
	COLOR_ATTACHMENT,
	DEPTH_STENCIL_ATTACHMENT,
	SHADING_RATE,
	TRANSIENT_ATTACHMENT,
	INPUT_ATTACHMENT,
}

bitstruct ImageUsage : ushort
{
	bool transfer_src : 0;
	bool transfer_dst : 1;
	bool sampled : 2;
	bool storage : 3;
	bool color_attachment : 4;
	bool depth_stencil_attachment : 5;
	bool shading_rate : 6;
	bool transient_attachment : 7;
	bool input_attachment : 8;
}

enum ImageCreateFlag : char
{
	CUBE_COMPATIBLE,
	BLOCK_TEXEL_VIEW_COMPATIBLE,
}

bitstruct ImageCreateFlags : char
{
	bool cube_compatible : 0;
	bool block_texel_view_compatible : 1;
}

enum ImageMemoryUsage : char
{
	AUTO,
	PREFER_DEVICE,
	PREFER_HOST,
}

struct ImageDesc
{
	ImageType image_type;
	Format format;
	uint width;
	uint height;
	uint depth;
	uint mip_levels;
	uint array_layers;
	ImageSampleCount samples;
	ImageTiling tiling;
	ImageUsage usage;
	ImageCreateFlags flags;
	ImageMemoryUsage memory_usage;
}

struct ImageExtent
{
	uint width;
	uint height;
	uint depth;
}

struct ImageOrigin
{
	uint x;
	uint y;
	uint z;
}

// A row pitch of zero means tightly packed.  rows_per_image is likewise
// inferred from extent.height when zero.  The pointer is borrowed for the
// duration of the call; browser queue writes copy it synchronously.
struct ImageUploadOptions
{
	char[] data;
	ImageExtent extent;
	uint mip_level;
	uint base_array_layer;
	uint layer_count;
	ImageOrigin origin;
	uint bytes_per_row;
	uint rows_per_image;
}

struct Image
{
	ulong cookie;
	union backend
	{
		ImageVk vk;
		ImageDx12 dx12;
		ImageWgpu wgpu;
		ImageWebgl webgl;
		ImageMtlState mtl;
	}
}

fn Image? image_init(Device* device, ImageDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return image_init_vk(device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return image_init_dx12(device, desc);
			$endif
		case MTL:
			$if HAS_MTL:
				return image_init_mtl_impl(device, desc);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return image_init_wgpu(device, desc);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return image_init_webgl(device, desc);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void image_deinit(Image* img, Device* device)
{
	if (img == null || img.cookie == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				image_deinit_vk(img, device);
			$endif
		case DX12:
			$if HAS_DX12:
				image_deinit_dx12(img, device);
			$endif
		case MTL:
			$if HAS_MTL:
				image_deinit_mtl_impl(img, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				image_deinit_wgpu(img, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				image_deinit_webgl(img, device);
			$endif
	}
	// All backends share this guard, making deinit idempotent at the RHI layer.
	img.cookie = 0;
}

fn void? image_upload(Image* image, Device* device, ImageUploadOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return image_upload_vk(image, device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				return image_upload_mtl_impl(image, device, options);
			$endif
		case DX12:
			return UNSUPPORTED_BACKEND~;
		case WGPU:
			$if HAS_WGPU:
				return image_upload_wgpu(image, device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return image_upload_webgl(image, device, options);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn bool image_is_empty(Image* img)
{
	return img.cookie == 0;
}

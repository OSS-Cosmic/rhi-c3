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

// ---- metal ----

// Metal image creation and the load-time upload path. The public entry
// points use an `_impl` suffix to keep backend-specific names distinct from
// the front-end dispatch functions.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import mtl;

struct ImageMtlState
{
	// Owned by the Image.
	mtl::Texture texture;
	mtl::TextureType texture_type;
	Format format;
	ImageType image_type;
	uint width;
	uint height;
	uint depth;
	uint mip_levels;
	uint array_layers;
}

fn uint mtl_sample_count(ImageSampleCount samples)
{
	switch (samples)
	{
		case S1: return 1;
		case S2: return 2;
		case S4: return 4;
		case S8: return 8;
		case S16: return 16;
		case S32: return 32;
		case S64: return 64;
	}
}

fn ImageMtlState? mtl_image_create_state(Device* device, ImageDesc desc)
{
	if (desc.width == 0 || desc.height == 0 || desc.depth == 0 ||
		desc.mip_levels == 0 || desc.array_layers == 0)
	{
		return UNSUPPORTED_FEATURE~;
	}

	mtl::PixelFormat pixel_format = to_mtl_pixel_format(desc.format);
	if (pixel_format == mtl::PixelFormat.INVALID) return UNSUPPORTED_FEATURE~;
	FormatProperties format_props = format_get_props(desc.format);

	uint array_length = desc.array_layers;
	mtl::TextureType texture_type;
	switch (desc.image_type)
	{
		case D1:
			if (desc.height != 1 || desc.depth != 1 || desc.samples != S1) return UNSUPPORTED_FEATURE~;
			texture_type = desc.array_layers > 1 ? mtl::TextureType.TYPE_1D_ARRAY : mtl::TextureType.TYPE_1D;
		case D2:
			if (desc.depth != 1) return UNSUPPORTED_FEATURE~;
			if (desc.flags.cube_compatible)
			{
				if (desc.samples != S1 || desc.array_layers < 6 || desc.array_layers % 6 != 0)
				{
					return UNSUPPORTED_FEATURE~;
				}
				array_length = desc.array_layers / 6;
				texture_type = array_length > 1 ? mtl::TextureType.TYPE_CUBE_ARRAY : mtl::TextureType.TYPE_CUBE;
			}
			else if (desc.samples != S1)
			{
				if (desc.mip_levels != 1) return UNSUPPORTED_FEATURE~;
				texture_type = desc.array_layers > 1 ? mtl::TextureType.TYPE_2D_MULTISAMPLE_ARRAY : mtl::TextureType.TYPE_2D_MULTISAMPLE;
			}
			else
			{
				texture_type = desc.array_layers > 1 ? mtl::TextureType.TYPE_2D_ARRAY : mtl::TextureType.TYPE_2D;
			}
		case D3:
			if (desc.array_layers != 1 || desc.samples != S1) return UNSUPPORTED_FEATURE~;
			texture_type = mtl::TextureType.TYPE_3D;
	}

	mtl::TextureDescriptor descriptor = mtl::new_texture_descriptor();
	if (!descriptor) return OUT_OF_DEVICE_MEMORY~;
	defer descriptor.release();
	descriptor.set_texture_type(texture_type);
	descriptor.set_pixel_format(pixel_format);
	descriptor.set_width(desc.width);
	descriptor.set_height(desc.height);
	descriptor.set_depth(desc.image_type == D3 ? desc.depth : 1);
	descriptor.set_array_length(array_length);
	descriptor.set_mipmap_level_count(desc.mip_levels);
	descriptor.set_sample_count(mtl_sample_count(desc.samples));

	mtl::TextureUsage usage = mtl::TEXTURE_USAGE_UNKNOWN;
	if (desc.flags.block_texel_view_compatible)
	{
		usage |= mtl::TEXTURE_USAGE_PIXEL_FORMAT_VIEW;
	}
	if (desc.usage.sampled || desc.usage.input_attachment || desc.usage.shading_rate)
	{
		usage |= mtl::TEXTURE_USAGE_SHADER_READ;
	}
	if (desc.usage.storage) usage |= mtl::TEXTURE_USAGE_SHADER_WRITE;
	if (desc.usage.color_attachment || desc.usage.depth_stencil_attachment)
	{
		usage |= mtl::TEXTURE_USAGE_RENDER_TARGET;
	}
	descriptor.set_usage(usage);

	// Metal has no public linear/optimal tiling choice.  Its texture
	// descriptor owns the layout, so both RHI tilings use the same descriptor.
	// Transient attachments are the one exception: memoryless is the faithful
	// Metal equivalent, and cannot be combined with host uploads.
	mtl::StorageMode storage_mode;
	if (desc.usage.transient_attachment)
	{
		if (desc.memory_usage == PREFER_HOST || desc.usage.transfer_src || desc.usage.transfer_dst)
		{
			return UNSUPPORTED_FEATURE~;
		}
		storage_mode = mtl::StorageMode.MEMORYLESS;
	}
	else
	{
		// Depth/stencil textures are render-target resources in Metal and must
		// remain private even when the generic descriptor requests host memory.
		storage_mode = !format_props.is_depth && desc.memory_usage == PREFER_HOST ?
			mtl::StorageMode.SHARED : mtl::StorageMode.PRIVATE;
	}
	descriptor.set_storage_mode(storage_mode);

	mtl::Texture texture = device.backend.mtl.device.new_texture(descriptor);
	if (!texture) return OUT_OF_DEVICE_MEMORY~;
	return {
		.texture = texture,
		.texture_type = texture_type,
		.format = desc.format,
		.image_type = desc.image_type,
		.width = desc.width,
		.height = desc.height,
		.depth = desc.depth,
		.mip_levels = desc.mip_levels,
		.array_layers = desc.array_layers,
	};
}

fn Image? image_init_mtl_impl(Device* device, ImageDesc desc)
{
	ImageMtlState state = mtl_image_create_state(device, desc)!!;
	return {
		.cookie = next_cookie(),
		.backend.mtl = state,
	};
}

fn void image_deinit_mtl_impl(Image* image, Device* device)
{
	if (image.backend.mtl.texture) image.backend.mtl.texture.release();
	image.backend.mtl = {};
}

fn uint mtl_upload_block_count(uint value, uint block)
{
	return (value + block - 1) / block;
}

fn void? image_upload_mtl_impl(Image* image, Device* device, ImageUploadOptions options)
{
	if (image == null || image.cookie == 0 || !image.backend.mtl.texture)
	{
		return UNSUPPORTED_FEATURE~;
	}
	if (options.data.len == 0) return;
	if (options.extent.width == 0 || options.extent.height == 0 || options.extent.depth == 0 ||
		options.layer_count == 0 || options.mip_level >= image.backend.mtl.mip_levels)
	{
		return UNSUPPORTED_FEATURE~;
	}

	ImageMtlState* state = &image.backend.mtl;
	uint mip_width = state.width >> options.mip_level;
	uint mip_height = state.height >> options.mip_level;
	uint mip_depth = state.depth >> options.mip_level;
	if (mip_width == 0) mip_width = 1;
	if (mip_height == 0) mip_height = 1;
	if (mip_depth == 0) mip_depth = 1;
	if (options.origin.x > mip_width || options.extent.width > mip_width - options.origin.x ||
		options.origin.y > mip_height || options.extent.height > mip_height - options.origin.y ||
		options.origin.z > mip_depth || options.extent.depth > mip_depth - options.origin.z)
	{
		return UNSUPPORTED_FEATURE~;
	}

	if (state.image_type == D3)
	{
		if (options.base_array_layer != 0 || options.layer_count != 1 || options.origin.z + options.extent.depth > mip_depth)
		{
			return UNSUPPORTED_FEATURE~;
		}
	}
	else
	{
		if (options.origin.z != 0 || options.extent.depth != 1 ||
			options.base_array_layer > state.array_layers ||
			options.layer_count > state.array_layers - options.base_array_layer)
		{
			return UNSUPPORTED_FEATURE~;
		}
	}
	if (state.image_type == D1 && (options.origin.y != 0 || options.extent.height != 1))
	{
		return UNSUPPORTED_FEATURE~;
	}

	FormatProperties props = format_get_props(state.format);
	if (props.stride == 0 || props.block_width == 0 || props.block_height == 0)
	{
		return UNSUPPORTED_FEATURE~;
	}
	uint blocks_x = mtl_upload_block_count(options.extent.width, props.block_width);
	uint rows = mtl_upload_block_count(options.extent.height, props.block_height);
	uint tight_row_bytes = blocks_x * props.stride;
	uint bytes_per_row = options.bytes_per_row == 0 ? tight_row_bytes : options.bytes_per_row;
	uint rows_per_image = options.rows_per_image == 0 ? rows : options.rows_per_image;
	if (bytes_per_row < tight_row_bytes || rows_per_image < rows)
	{
		return UNSUPPORTED_FEATURE~;
	}
	uint bytes_per_image = bytes_per_row * rows_per_image;
	uint depth_slices = state.image_type == D3 ? options.extent.depth : 1;
	ulong required = (ulong)(options.layer_count - 1) * bytes_per_image +
		(ulong)(depth_slices - 1) * bytes_per_image +
		(ulong)(rows - 1) * bytes_per_row + tight_row_bytes;
	if (required > (ulong)options.data.len) return UNSUPPORTED_FEATURE~;

	objc::@autoreleasepool()
	{
		// newBufferWithBytes copies the borrowed upload before this function
		// returns, and the command buffer is waited before the staging buffer is
		// released.  This makes image_upload a genuinely one-shot operation for
		// private and shared textures alike.
		mtl::Buffer staging = device.backend.mtl.device.new_buffer_with_bytes(
			(void*)options.data.ptr, (mtl::NSUInteger)options.data.len,
			mtl::RESOURCE_STORAGE_MODE_SHARED);
		if (!staging) return OUT_OF_DEVICE_MEMORY~;
		defer staging.release();
		mtl::CommandBuffer command_buffer = device.backend.mtl.queue.command_buffer();
		if (!command_buffer) return INITIALIZATION_FAILED~;
		mtl::BlitCommandEncoder encoder = command_buffer.blit_command_encoder();
		if (!encoder) return INITIALIZATION_FAILED~;

		if (state.image_type == D3)
		{
			encoder.copy_buffer_to_texture(
				staging, 0, bytes_per_row, bytes_per_image,
				{ .width = options.extent.width, .height = options.extent.height, .depth = options.extent.depth },
				state.texture, 0, options.mip_level,
				{ .x = options.origin.x, .y = options.origin.y, .z = options.origin.z });
		}
		else
		{
			for (uint layer = 0; layer < options.layer_count; layer++)
			{
				encoder.copy_buffer_to_texture(
					staging, (mtl::NSUInteger)layer * bytes_per_image, bytes_per_row, bytes_per_image,
					{ .width = options.extent.width, .height = options.extent.height, .depth = 1 },
					state.texture, (mtl::NSUInteger)(options.base_array_layer + layer), options.mip_level,
					{ .x = options.origin.x, .y = options.origin.y, .z = 0 });
			}
		}
		encoder.end_encoding();
		command_buffer.commit();
		command_buffer.wait_until_completed();
	};
}

// ---- dx12 ----

// Direct3D 12 images. Port of the `.dx12` arms of rhi-zig's `image.zig`: a
// committed texture resource created through D3D12MemoryAllocator. The
// resource is created in the COMMON state; barriers move it from there.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi, d3d12ma;

struct ImageDx12
{
	// Owned: the allocation releases the resource it holds.
	d3d12ma::Allocation allocation;
	// Borrowed from `allocation`; views and barriers reference it.
	d3d12::Resource* resource;
	// The format the image was created with (the resource itself may be typeless).
	Format format;
	ImageType image_type;
	uint width;
	uint height;
	uint depth;
	uint mip_levels;
	uint array_layers;
	uint sample_count;
}

fn uint dx12_sample_count(ImageSampleCount samples)
{
	switch (samples)
	{
		case S1: return 1;
		case S2: return 2;
		case S4: return 4;
		case S8: return 8;
		case S16: return 16;
		case S32: return 32;
		case S64: return 64;
	}
}

fn Image? image_init_dx12(Device* device, ImageDesc desc)
{
	if (desc.width == 0 || desc.height == 0 || desc.depth == 0 ||
		desc.mip_levels == 0 || desc.array_layers == 0 ||
		desc.mip_levels > 0xFFFF || desc.array_layers > 0xFFFF || desc.depth > 0xFFFF)
	{
		return UNSUPPORTED_FEATURE~;
	}

	dxgi::Format dxgi_format = format_to_dxgi(desc.format);
	if (dxgi_format == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	FormatProperties props = format_get_props(desc.format);

	d3d12::ResourceDimension dimension;
	ushort depth_or_array_size = (ushort)desc.array_layers;
	switch (desc.image_type)
	{
		case D1:
			if (desc.height != 1 || desc.depth != 1 || desc.samples != S1) return UNSUPPORTED_FEATURE~;
			dimension = d3d12::ResourceDimension.TEXTURE1D;
		case D2:
			if (desc.depth != 1) return UNSUPPORTED_FEATURE~;
			if (desc.flags.cube_compatible && (desc.samples != S1 || desc.array_layers < 6 || desc.array_layers % 6 != 0))
			{
				return UNSUPPORTED_FEATURE~;
			}
			dimension = d3d12::ResourceDimension.TEXTURE2D;
		case D3:
			if (desc.array_layers != 1 || desc.samples != S1) return UNSUPPORTED_FEATURE~;
			dimension = d3d12::ResourceDimension.TEXTURE3D;
			depth_or_array_size = (ushort)desc.depth;
	}

	// Depth formats are created typeless so the same resource can back both a
	// depth-stencil view and a shader-resource view.
	if (props.is_depth) dxgi_format = format_to_dxgi_typeless(desc.format);

	d3d12::ResourceFlags flags = d3d12::RESOURCE_FLAG_NONE;
	if (desc.usage.color_attachment) flags |= d3d12::RESOURCE_FLAG_ALLOW_RENDER_TARGET;
	if (desc.usage.depth_stencil_attachment)
	{
		flags |= d3d12::RESOURCE_FLAG_ALLOW_DEPTH_STENCIL;
		if (!desc.usage.sampled && !desc.usage.input_attachment)
		{
			flags |= d3d12::RESOURCE_FLAG_DENY_SHADER_RESOURCE;
		}
	}
	if (desc.usage.storage) flags |= d3d12::RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;

	d3d12::ResourceDesc resource_desc = {
		.dimension = dimension,
		.alignment = 0,
		.width = desc.width,
		.height = desc.height,
		.depth_or_array_size = depth_or_array_size,
		.mip_levels = (ushort)desc.mip_levels,
		.format = dxgi_format,
		.sample_desc = { .count = dx12_sample_count(desc.samples), .quality = 0 },
		.layout = d3d12::TextureLayout.UNKNOWN,
		.flags = flags,
	};

	// Textures always live in device-local memory; D3D12 has no useful
	// host-visible texture heap, so PREFER_HOST is treated as AUTO.
	d3d12ma::AllocationDesc alloc_desc = { .heap_type = (int)d3d12::HeapType.DEFAULT };
	d3d12ma::Allocation allocation;
	d3d12::Resource* resource;
	int hr = d3d12ma::create_resource(
		device.backend.dx12.allocator, &alloc_desc, &resource_desc,
		(uint)d3d12::RESOURCE_STATE_COMMON, null, &allocation, (void**)&resource);
	if (dxgi::failed(hr) || !allocation) return OUT_OF_DEVICE_MEMORY~;
	// The allocation owns the resource; drop the extra reference handed back.
	if (resource) dxgi::release(resource);

	return {
		.cookie = next_cookie(),
		.backend.dx12 = {
			.allocation = allocation,
			.resource = (d3d12::Resource*)d3d12ma::allocation_get_resource(allocation),
			.format = desc.format,
			.image_type = desc.image_type,
			.width = desc.width,
			.height = desc.height,
			.depth = desc.depth,
			.mip_levels = desc.mip_levels,
			.array_layers = desc.array_layers,
			.sample_count = dx12_sample_count(desc.samples),
		},
	};
}

fn void image_deinit_dx12(Image* img, Device* device)
{
	if (img.backend.dx12.allocation) d3d12ma::free_allocation(img.backend.dx12.allocation);
	img.backend.dx12 = {};
}

// ---- vulkan ----

// Vulkan images and synchronous upload path. The upload intentionally uses
// raw command-pool/buffer calls until the reusable pool/cmd front is ported.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, vma;

struct ImageVk
{
	vk::Image image;
	vma::Allocation allocation;
	vk::Format format;
	bool borrowed;
}

fn vk::ImageUsageFlags image_usage_flags_vk(ImageUsage usage) @private
{
	vk::ImageUsageFlags flags;
	if (usage.transfer_src) flags |= vk::IMAGE_USAGE_TRANSFER_SRC_BIT;
	if (usage.transfer_dst) flags |= vk::IMAGE_USAGE_TRANSFER_DST_BIT;
	if (usage.sampled) flags |= vk::IMAGE_USAGE_SAMPLED_BIT;
	if (usage.storage) flags |= vk::IMAGE_USAGE_STORAGE_BIT;
	if (usage.color_attachment) flags |= vk::IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
	if (usage.depth_stencil_attachment) flags |= vk::IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
	if (usage.shading_rate) flags |= vk::IMAGE_USAGE_FRAGMENT_SHADING_RATE_ATTACHMENT_BIT_KHR;
	if (usage.transient_attachment) flags |= vk::IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT;
	if (usage.input_attachment) flags |= vk::IMAGE_USAGE_INPUT_ATTACHMENT_BIT;
	return flags;
}

fn vk::ImageType image_type_vk(ImageType type) @private
{
	switch (type)
	{
		case D1: return vk::ImageType.D1;
		case D2: return vk::ImageType.D2;
		case D3: return vk::ImageType.D3;
	}
}

fn vk::SampleCountFlagBits image_samples_vk(ImageSampleCount samples) @private
{
	switch (samples)
	{
		case S1: return vk::SAMPLE_COUNT_1_BIT;
		case S2: return vk::SAMPLE_COUNT_2_BIT;
		case S4: return vk::SAMPLE_COUNT_4_BIT;
		case S8: return vk::SAMPLE_COUNT_8_BIT;
		case S16: return vk::SAMPLE_COUNT_16_BIT;
		case S32: return vk::SAMPLE_COUNT_32_BIT;
		case S64: return vk::SAMPLE_COUNT_64_BIT;
	}
}

fn vma::MemoryUsage image_memory_usage_vk(ImageMemoryUsage usage) @private
{
	switch (usage)
	{
		case AUTO: return vma::MemoryUsage.AUTO;
		case PREFER_DEVICE: return vma::MemoryUsage.AUTO_PREFER_DEVICE;
		case PREFER_HOST: return vma::MemoryUsage.AUTO_PREFER_HOST;
	}
}

fn Image? image_init_vk(Device* device, ImageDesc desc)
{
	if (desc.width == 0 || desc.height == 0 || desc.depth == 0 || desc.mip_levels == 0 || desc.array_layers == 0) {
		return UNSUPPORTED_FEATURE~;
	}
	vk::ImageCreateFlags create_flags;
	if (desc.flags.cube_compatible) create_flags |= vk::IMAGE_CREATE_CUBE_COMPATIBLE_BIT;
	if (desc.flags.block_texel_view_compatible) create_flags |= vk::IMAGE_CREATE_BLOCK_TEXEL_VIEW_COMPATIBLE_BIT;
	vk::ImageCreateInfo create_info = {
		.sType = vk::StructureType.IMAGE_CREATE_INFO,
		.flags = create_flags,
		.imageType = image_type_vk(desc.image_type),
		.format = to_vk_format(desc.format),
		.extent = { .width = desc.width, .height = desc.height, .depth = desc.depth },
		.mipLevels = desc.mip_levels,
		.arrayLayers = desc.array_layers,
		.samples = image_samples_vk(desc.samples),
		.tiling = desc.tiling == OPTIMAL ? vk::ImageTiling.OPTIMAL : vk::ImageTiling.LINEAR,
		.usage = image_usage_flags_vk(desc.usage),
		.sharingMode = vk::SharingMode.EXCLUSIVE,
		.initialLayout = vk::ImageLayout.UNDEFINED,
	};
	vma::AllocationCreateInfo allocation_info = { .usage = image_memory_usage_vk(desc.memory_usage) };
	vk::Image image;
	vma::Allocation allocation;
	vma::AllocationInfo vma_info;
	vk_check(vma::create_image(device.backend.vk.vma_allocator, &create_info, &allocation_info, &image, &allocation, &vma_info))!;
	return {
		.cookie = next_cookie(),
		.backend.vk = { .image = image, .allocation = allocation, .format = create_info.format, .borrowed = false },
	};
}

fn void image_deinit_vk(Image* img, Device* device)
{
	if (img.backend.vk.borrowed) return;
	if (img.backend.vk.allocation != null) {
		vma::destroy_image(device.backend.vk.vma_allocator, img.backend.vk.image, img.backend.vk.allocation);
	} else if (img.backend.vk.image != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyImage(device.backend.vk.device, img.backend.vk.image, null);
	}
	img.backend.vk = {};
}

fn void? vk_upload_barrier(Device* device, vk::CommandBuffer cmd, vk::Image image, vk::ImageLayout old_layout, vk::ImageLayout new_layout, uint mip_level, uint base_layer, uint layer_count) @private
{
	vk::ImageMemoryBarrier2 barrier = {
		.sType = vk::StructureType.IMAGE_MEMORY_BARRIER_2,
		.srcStageMask = old_layout == vk::ImageLayout.UNDEFINED ? vk::PIPELINE_STAGE_2_TOP_OF_PIPE_BIT : vk::PIPELINE_STAGE_2_COPY_BIT,
		.srcAccessMask = old_layout == vk::ImageLayout.UNDEFINED ? vk::ACCESS_2_NONE : vk::ACCESS_2_TRANSFER_WRITE_BIT,
		.dstStageMask = new_layout == vk::ImageLayout.TRANSFER_DST_OPTIMAL ? vk::PIPELINE_STAGE_2_COPY_BIT : vk::PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT,
		.dstAccessMask = new_layout == vk::ImageLayout.TRANSFER_DST_OPTIMAL ? vk::ACCESS_2_TRANSFER_WRITE_BIT : vk::ACCESS_2_SHADER_READ_BIT,
		.oldLayout = old_layout,
		.newLayout = new_layout,
		.srcQueueFamilyIndex = uint::max,
		.dstQueueFamilyIndex = uint::max,
		.image = image,
		.subresourceRange = {
			.aspectMask = vk::IMAGE_ASPECT_COLOR_BIT,
			.baseMipLevel = mip_level,
			.levelCount = 1,
			.baseArrayLayer = base_layer,
			.layerCount = layer_count,
		},
	};
	vk::DependencyInfo dependency = {
		.sType = vk::StructureType.DEPENDENCY_INFO,
		.imageMemoryBarrierCount = 1,
		.pImageMemoryBarriers = &barrier,
	};
	device.backend.vk.vtable.cmdPipelineBarrier2(cmd, &dependency);
}

fn void? image_upload_vk(Image* image, Device* device, ImageUploadOptions options)
{
	if (options.data.len == 0) return;
	if (image == null || image.cookie == 0) return UNSUPPORTED_FEATURE~;
	ImageVk* vk_image = &image.backend.vk;
	if (options.extent.width == 0 || options.extent.height == 0 || options.extent.depth == 0) {
		return UNSUPPORTED_FEATURE~;
	}
	uint layer_count = options.layer_count == 0 ? 1 : options.layer_count;
	if (options.mip_level >= 65536 || options.base_array_layer >= 65536 || layer_count > 65535 ||
		(ulong)options.base_array_layer + (ulong)layer_count > 65535) {
		return UNSUPPORTED_FEATURE~;
	}
	if (options.origin.x > uint::max / 2 || options.origin.y > uint::max / 2 || options.origin.z > uint::max / 2) {
		return UNSUPPORTED_FEATURE~;
	}

	FormatProperties props = format_get_props(from_vk_format(vk_image.format));
	if (props.stride == 0 || props.is_compressed || props.block_width != 1 || props.block_height != 1 || props.is_depth || props.is_stencil) {
		return UNSUPPORTED_FEATURE~;
	}
	ulong stride = props.stride;
	ulong tight_row = (ulong)options.extent.width * stride;
	ulong bytes_per_row = options.bytes_per_row == 0 ? tight_row : options.bytes_per_row;
	ulong rows_per_image = options.rows_per_image == 0 ? options.extent.height : options.rows_per_image;
	if (bytes_per_row < tight_row || bytes_per_row % stride != 0 || bytes_per_row / stride > uint::max ||
		rows_per_image < options.extent.height || rows_per_image > uint::max) {
		return UNSUPPORTED_FEATURE~;
	}
	ulong slices = (ulong)options.extent.depth * layer_count;
	ulong required = bytes_per_row * (rows_per_image * (slices - 1) + ((ulong)options.extent.height - 1)) + tight_row;
	if (required > options.data.len) return UNSUPPORTED_FEATURE~;

	Buffer staging = buffer_init_general(device, {
		.size = options.data.len,
		.persistent_map = true,
		.sequential_access = true,
		.usage = { .transfer_src = true },
		.buffer_usage = PREFER_HOST,
	})!!;
	defer buffer_deinit(&staging, device);
	if (staging.mapped_region.len < options.data.len) return UNSUPPORTED_FEATURE~;
	buffer_write(&staging, device, 0, options.data);
	buffer_flush(&staging, device);

	vk::CommandPool pool;
	vk::CommandPoolCreateInfo pool_info = { .sType = vk::StructureType.COMMAND_POOL_CREATE_INFO, .flags = vk::COMMAND_POOL_CREATE_TRANSIENT_BIT, .queueFamilyIndex = device.graphics_queue.backend.vk.family_index };
	vk_check(device.backend.vk.vtable.createCommandPool(device.backend.vk.device, &pool_info, null, &pool))!;
	defer device.backend.vk.vtable.destroyCommandPool(device.backend.vk.device, pool, null);
	vk::CommandBuffer cmd;
	vk::CommandBufferAllocateInfo alloc_info = {
		.sType = vk::StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = pool,
		.level = vk::CommandBufferLevel.PRIMARY,
		.commandBufferCount = 1,
	};
	vk_check(device.backend.vk.vtable.allocateCommandBuffers(device.backend.vk.device, &alloc_info, &cmd))!;
	defer device.backend.vk.vtable.freeCommandBuffers(device.backend.vk.device, pool, 1, &cmd);
	vk::CommandBufferBeginInfo begin_info = { .sType = vk::StructureType.COMMAND_BUFFER_BEGIN_INFO, .flags = vk::COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT };
	vk_check(device.backend.vk.vtable.beginCommandBuffer(cmd, &begin_info))!;
	vk_upload_barrier(device, cmd, vk_image.image, vk::ImageLayout.UNDEFINED, vk::ImageLayout.TRANSFER_DST_OPTIMAL, options.mip_level, options.base_array_layer, layer_count)!;
	vk::BufferImageCopy copy = {
		.bufferRowLength = (uint)(bytes_per_row / stride),
		.bufferImageHeight = (uint)rows_per_image,
		.imageSubresource = {
			.aspectMask = vk::IMAGE_ASPECT_COLOR_BIT,
			.mipLevel = options.mip_level,
			.baseArrayLayer = options.base_array_layer,
			.layerCount = layer_count,
		},
		.imageOffset = { .x = (int)options.origin.x, .y = (int)options.origin.y, .z = (int)options.origin.z },
		.imageExtent = { .width = options.extent.width, .height = options.extent.height, .depth = options.extent.depth },
	};
	device.backend.vk.vtable.cmdCopyBufferToImage(cmd, staging.backend.vk.buffer, vk_image.image, vk::ImageLayout.TRANSFER_DST_OPTIMAL, 1, &copy);
	vk_upload_barrier(device, cmd, vk_image.image, vk::ImageLayout.TRANSFER_DST_OPTIMAL, vk::ImageLayout.SHADER_READ_ONLY_OPTIMAL, options.mip_level, options.base_array_layer, layer_count)!;
	vk_check(device.backend.vk.vtable.endCommandBuffer(cmd))!;
	vk::CommandBufferSubmitInfo cmd_submit = { .sType = vk::StructureType.COMMAND_BUFFER_SUBMIT_INFO, .commandBuffer = cmd };
	vk::SubmitInfo2 submit = { .sType = vk::StructureType.SUBMIT_INFO_2, .commandBufferInfoCount = 1, .pCommandBufferInfos = &cmd_submit };
	vk_check(device.backend.vk.vtable.queueSubmit2(device.graphics_queue.backend.vk.queue, 1, &submit, 0))!;
	vk_check(device.backend.vk.vtable.queueWaitIdle(device.graphics_queue.backend.vk.queue))!;
}

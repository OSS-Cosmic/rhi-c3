// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

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

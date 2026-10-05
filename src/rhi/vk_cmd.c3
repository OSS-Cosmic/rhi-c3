// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan command recording. Port of the command section of rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct CmdVk
{
	vk::CommandBuffer cmd;
}

fn Cmd? cmd_init_vk(Device* device, Pool* pool)
{
	vk::CommandBufferAllocateInfo info = {
		.sType = vk::StructureType.COMMAND_BUFFER_ALLOCATE_INFO,
		.commandPool = pool.backend.vk.pool,
		.level = vk::CommandBufferLevel.PRIMARY,
		.commandBufferCount = 1,
	};
	vk::CommandBuffer command_buffer;
	vk_check(device.backend.vk.vtable.allocateCommandBuffers(device.backend.vk.device, &info, &command_buffer))!;
	return { .backend.vk = { .cmd = command_buffer } };
}

fn void cmd_deinit_vk(Cmd* cmd, Device* device, Pool* pool)
{
	device.backend.vk.vtable.freeCommandBuffers(device.backend.vk.device, pool.backend.vk.pool, 1, &cmd.backend.vk.cmd);
	cmd.backend.vk = {};
}

fn void? cmd_begin_vk(Cmd* cmd, Device* device)
{
	vk::CommandBufferBeginInfo info = {
		.sType = vk::StructureType.COMMAND_BUFFER_BEGIN_INFO,
		.flags = vk::COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
	};
	return vk_check(device.backend.vk.vtable.beginCommandBuffer(cmd.backend.vk.cmd, &info));
}

fn void? cmd_end_vk(Cmd* cmd, Device* device)
{
	return vk_check(device.backend.vk.vtable.endCommandBuffer(cmd.backend.vk.cmd));
}

fn void cmd_set_viewport_vk(Cmd* cmd, Device* device, Viewport viewport)
{
	(void)device;
	vk::Viewport vk_viewport = {
		.x = viewport.x,
		.y = viewport.y,
		.width = viewport.width,
		.height = viewport.height,
		.minDepth = viewport.min_depth,
		.maxDepth = viewport.max_depth,
	};
	device.backend.vk.vtable.cmdSetViewport(cmd.backend.vk.cmd, 0, 1, &vk_viewport);
}

fn void cmd_set_scissor_vk(Cmd* cmd, Device* device, Rect rect)
{
	(void)device;
	vk::Rect2D scissor = {
		.offset = { .x = rect.x, .y = rect.y },
		.extent = { .width = rect.width, .height = rect.height },
	};
	device.backend.vk.vtable.cmdSetScissor(cmd.backend.vk.cmd, 0, 1, &scissor);
}

fn void cmd_draw_vk(Cmd* cmd, Device* device, uint vertex_count, uint instance_count, uint first_vertex, uint first_instance)
{
	(void)device;
	device.backend.vk.vtable.cmdDraw(cmd.backend.vk.cmd, vertex_count, instance_count, first_vertex, first_instance);
}

fn void cmd_draw_indexed_vk(Cmd* cmd, Device* device, uint index_count, uint instance_count, uint first_index, int vertex_offset, uint first_instance)
{
	(void)device;
	device.backend.vk.vtable.cmdDrawIndexed(cmd.backend.vk.cmd, index_count, instance_count, first_index, vertex_offset, first_instance);
}

fn void cmd_draw_indirect_vk(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	(void)device;
	device.backend.vk.vtable.cmdDrawIndirect(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, draw_count, stride);
}

fn void cmd_draw_indexed_indirect_vk(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	(void)device;
	device.backend.vk.vtable.cmdDrawIndexedIndirect(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, draw_count, stride);
}

fn void cmd_draw_indirect_count_vk(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	(void)device;
	device.backend.vk.vtable.cmdDrawIndirectCount(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, count_buffer.backend.vk.buffer, count_offset, max_draw_count, stride);
}

fn void cmd_draw_indexed_indirect_count_vk(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	(void)device;
	device.backend.vk.vtable.cmdDrawIndexedIndirectCount(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, count_buffer.backend.vk.buffer, count_offset, max_draw_count, stride);
}

fn void cmd_bind_pipeline_vk(Cmd* cmd, Device* device, Pipeline* pipeline)
{
	(void)device;
	device.backend.vk.vtable.cmdBindPipeline(cmd.backend.vk.cmd, vk::PipelineBindPoint.GRAPHICS, pipeline.backend.vk.pipeline);
}

fn void cmd_set_push_constants_vk(Cmd* cmd, Device* device, Pipeline* pipeline, char[] bytes)
{
	(void)device;
	device.backend.vk.vtable.cmdPushConstants(cmd.backend.vk.cmd, pipeline.backend.vk.layout, vk::SHADER_STAGE_VERTEX_BIT, 0, (uint)bytes.len, bytes.ptr);
}

fn void cmd_clear_attachment_regions_vk(Cmd* cmd, Device* device, CmdClearRegion[] regions)
{
	(void)device;
	foreach (region : regions)
	{
		vk::ClearAttachment attachment = {
			.aspectMask = vk::IMAGE_ASPECT_COLOR_BIT,
			.colorAttachment = 0,
			.clearValue = { .color = { .float32 = region.color } },
		};
		vk::ClearRect rect = {
			.rect = {
				.offset = { .x = region.rect.x, .y = region.rect.y },
				.extent = { .width = region.rect.width, .height = region.rect.height },
			},
			.baseArrayLayer = 0,
			.layerCount = 1,
		};
		device.backend.vk.vtable.cmdClearAttachments(cmd.backend.vk.cmd, 1, &attachment, 1, &rect);
	}
}

fn vk::AttachmentLoadOp vk_load_op(LoadOp op) @private
{
	switch (op)
	{
		case LOAD: return vk::AttachmentLoadOp.LOAD;
		case CLEAR: return vk::AttachmentLoadOp.CLEAR;
		case DONT_CARE: return vk::AttachmentLoadOp.DONT_CARE;
	}
}

fn vk::AttachmentStoreOp vk_store_op(StoreOp op) @private
{
	switch (op)
	{
		case STORE: return vk::AttachmentStoreOp.STORE;
		case DONT_CARE: return vk::AttachmentStoreOp.DONT_CARE;
	}
}

fn void cmd_begin_rendering_vk(Cmd* cmd, Device* device, CmdBeginRenderingOptions options)
{
	(void)device;
	assert(options.color_attachments.len <= 8);
	vk::RenderingAttachmentInfo[8] colors;
	foreach (i, color : options.color_attachments)
	{
		colors[i] = {
			.sType = vk::StructureType.RENDERING_ATTACHMENT_INFO,
			.imageView = color.view.backend.vk.view,
			.imageLayout = vk::ImageLayout.COLOR_ATTACHMENT_OPTIMAL,
			.loadOp = vk_load_op(color.load_op),
			.storeOp = vk_store_op(color.store_op),
			.clearValue = { .color = { .float32 = color.clear_color } },
		};
	}
	vk::RenderingAttachmentInfo depth;
	vk::RenderingAttachmentInfo stencil;
	vk::RenderingInfo info = {
		.sType = vk::StructureType.RENDERING_INFO,
		.renderArea = {
			.offset = { .x = options.render_area.x, .y = options.render_area.y },
			.extent = { .width = options.render_area.width, .height = options.render_area.height },
		},
		.layerCount = 1,
		.colorAttachmentCount = (uint)options.color_attachments.len,
		.pColorAttachments = &colors[0],
	};
	if (options.has_depth_attachment)
	{
		CmdDepthAttachment d = options.depth_attachment;
		depth = {
			.sType = vk::StructureType.RENDERING_ATTACHMENT_INFO,
			.imageView = d.view.backend.vk.view,
			.imageLayout = d.read_only ? vk::ImageLayout.DEPTH_READ_ONLY_OPTIMAL : vk::ImageLayout.DEPTH_ATTACHMENT_OPTIMAL,
			.loadOp = vk_load_op(d.load_op),
			.storeOp = vk_store_op(d.store_op),
			.clearValue = { .depthStencil = { .depth = d.clear_depth, .stencil = 0 } },
		};
		info.pDepthAttachment = &depth;
		if (d.has_stencil)
		{
			stencil = {
				.sType = vk::StructureType.RENDERING_ATTACHMENT_INFO,
				.imageView = d.view.backend.vk.view,
				.imageLayout = vk::ImageLayout.STENCIL_ATTACHMENT_OPTIMAL,
				.loadOp = vk_load_op(d.stencil_load_op),
				.storeOp = vk_store_op(d.stencil_store_op),
				.clearValue = { .depthStencil = { .depth = d.clear_depth, .stencil = d.clear_stencil } },
			};
			info.pStencilAttachment = &stencil;
		}
	}
	device.backend.vk.vtable.cmdBeginRendering(cmd.backend.vk.cmd, &info);
}

fn void cmd_end_rendering_vk(Cmd* cmd, Device* device)
{
	(void)device;
	device.backend.vk.vtable.cmdEndRendering(cmd.backend.vk.cmd);
}

fn void cmd_bind_vertex_buffers_vk(Cmd* cmd, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets)
{
	(void)device;
	assert(buffers.len <= 32);
	assert(offsets.ptr == null || offsets.len == buffers.len);
	if (buffers.len == 0) return;
	vk::Buffer[32] vk_buffers;
	vk::DeviceSize[32] vk_offsets;
	foreach (i, buffer : buffers)
	{
		if (buffer != null) vk_buffers[i] = buffer.backend.vk.buffer;
		if (offsets.ptr != null) vk_offsets[i] = offsets[i];
	}
	uint start = 0;
	while (start < buffers.len)
	{
		while (start < buffers.len && buffers[start] == null) start++;
		if (start == buffers.len) break;
		uint end = start + 1;
		while (end < buffers.len && buffers[end] != null) end++;
		device.backend.vk.vtable.cmdBindVertexBuffers(cmd.backend.vk.cmd, first_binding + start, end - start, &vk_buffers[start], &vk_offsets[start]);
		start = end;
	}
}

fn void cmd_bind_index_buffer_vk(Cmd* cmd, Device* device, Buffer* buffer, IndexType index_type, ulong offset)
{
	(void)device;
	vk::IndexType vk_index_type = index_type == UINT16 ? vk::IndexType.UINT16 : vk::IndexType.UINT32;
	device.backend.vk.vtable.cmdBindIndexBuffer(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, vk_index_type);
}

fn void cmd_copy_buffer_vk(Cmd* cmd, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size)
{
	(void)device;
	vk::BufferCopy region = { .srcOffset = src_offset, .dstOffset = dst_offset, .size = size };
	device.backend.vk.vtable.cmdCopyBuffer(cmd.backend.vk.cmd, src.backend.vk.buffer, dst.backend.vk.buffer, 1, &region);
}

fn void cmd_copy_image_vk(Cmd* cmd, Device* device, Image* src, Image* dst, ImageCopyDesc desc)
{
	(void)device;
	vk::ImageAspectFlags src_aspect = vk_image_aspect_from_vk_format(src.backend.vk.format, true);
	vk::ImageAspectFlags dst_aspect = vk_image_aspect_from_vk_format(dst.backend.vk.format, true);
	vk::ImageCopy region = {
		.srcSubresource = { .aspectMask = src_aspect, .mipLevel = desc.src_mip_level, .baseArrayLayer = desc.src_array_layer, .layerCount = 1 },
		.srcOffset = { .x = desc.src_x, .y = desc.src_y, .z = desc.src_z },
		.dstSubresource = { .aspectMask = dst_aspect, .mipLevel = desc.dst_mip_level, .baseArrayLayer = desc.dst_array_layer, .layerCount = 1 },
		.dstOffset = { .x = desc.dst_x, .y = desc.dst_y, .z = desc.dst_z },
		.extent = { .width = desc.width, .height = desc.height, .depth = desc.depth },
	};
	device.backend.vk.vtable.cmdCopyImage(cmd.backend.vk.cmd, src.backend.vk.image, vk::ImageLayout.TRANSFER_SRC_OPTIMAL, dst.backend.vk.image, vk::ImageLayout.TRANSFER_DST_OPTIMAL, 1, &region);
}

const ResourceState VK_GENERAL_LAYOUT_STATES = {
	.general = true,
	.storage_read = true,
	.storage_write = true,
	.clear_storage = true,
};
const ResourceState VK_SHADER_ACCESS_STATES = {
	.general = true,
	.shader_resource = true,
	.storage_read = true,
	.storage_write = true,
	.constant_buffer = true,
};
const ResourceState VK_ACCEL_STATES = {
	.accel_read = true,
	.accel_write = true,
	.accel_build_input = true,
};
const ResourceState VK_ATTACHMENT_LAYOUT_STATES = {
	.render_target = true,
	.render_target_read = true,
};
const ResourceState VK_RESOURCE_STATE_NONE = (ResourceState)0;
const BarrierStages VK_BARRIER_STAGES_NONE = (BarrierStages)0;

fn vk::ImageLayout vk_resource_state_to_image_layout(ResourceState state) @private
{
	if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.UNDEFINED;
	if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.GENERAL;
	if ((state & VK_ATTACHMENT_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.COLOR_ATTACHMENT_OPTIMAL;
	if (state.depth_write) return vk::ImageLayout.DEPTH_ATTACHMENT_OPTIMAL;
	if (state.depth_read) return vk::ImageLayout.DEPTH_READ_ONLY_OPTIMAL;
	if (state.shader_resource) return vk::ImageLayout.SHADER_READ_ONLY_OPTIMAL;
	if (state.copy_src) return vk::ImageLayout.TRANSFER_SRC_OPTIMAL;
	if (state.copy_dst) return vk::ImageLayout.TRANSFER_DST_OPTIMAL;
	if (state.present) return vk::ImageLayout.PRESENT_SRC_KHR;
	return vk::ImageLayout.UNDEFINED;
}

fn vk::ImageLayout vk_resource_state_to_image_layout_aspect(ResourceState state, BarrierAspect aspect) @private
{
	if (aspect == STENCIL)
	{
		if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.UNDEFINED;
		if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.GENERAL;
		if (state.depth_write) return vk::ImageLayout.STENCIL_ATTACHMENT_OPTIMAL;
		if (state.depth_read) return vk::ImageLayout.STENCIL_READ_ONLY_OPTIMAL;
	}
	if (aspect == DEPTH_STENCIL)
	{
		if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.UNDEFINED;
		if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.GENERAL;
		if (state.depth_write) return vk::ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
		if (state.depth_read) return vk::ImageLayout.DEPTH_STENCIL_READ_ONLY_OPTIMAL;
	}
	return vk_resource_state_to_image_layout(state);
}

fn vk::AccessFlags2 vk_resource_state_to_access(ResourceState state) @private
{
	vk::AccessFlags2 access;
	if (state.general) access |= vk::ACCESS_2_SHADER_READ_BIT | vk::ACCESS_2_SHADER_WRITE_BIT;
	if (state.render_target) access |= vk::ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
	if (state.render_target_read) access |= vk::ACCESS_2_COLOR_ATTACHMENT_READ_BIT | vk::ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
	if (state.depth_write) access |= vk::ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT | vk::ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
	if (state.depth_read) access |= vk::ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
	if (state.shader_resource) access |= vk::ACCESS_2_SHADER_SAMPLED_READ_BIT | vk::ACCESS_2_SHADER_READ_BIT;
	if (state.storage_read) access |= vk::ACCESS_2_SHADER_STORAGE_READ_BIT;
	if (state.storage_write) access |= vk::ACCESS_2_SHADER_STORAGE_WRITE_BIT;
	if (state.copy_src) access |= vk::ACCESS_2_TRANSFER_READ_BIT;
	if (state.copy_dst) access |= vk::ACCESS_2_TRANSFER_WRITE_BIT;
	if (state.indirect_argument) access |= vk::ACCESS_2_INDIRECT_COMMAND_READ_BIT;
	if (state.vertex_buffer) access |= vk::ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT;
	if (state.index_buffer) access |= vk::ACCESS_2_INDEX_READ_BIT;
	if (state.constant_buffer) access |= vk::ACCESS_2_UNIFORM_READ_BIT;
	if (state.accel_read || state.accel_build_input) access |= vk::ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR;
	if (state.accel_write) access |= vk::ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
	if (state.clear_storage) access |= vk::ACCESS_2_TRANSFER_WRITE_BIT;
	if (state.host_read) access |= vk::ACCESS_2_HOST_READ_BIT;
	return access;
}

fn bool vk_barrier_state_supported(ResourceState state, BarrierCapabilities caps) @private
{
	return (state & VK_ACCEL_STATES) == VK_RESOURCE_STATE_NONE || caps.acceleration_structure_enabled;
}

struct VkStageMaskResult
{
	vk::PipelineStageFlags2 mask;
	bool ok;
}

fn VkStageMaskResult vk_stage_mask_from_state(ResourceState state, BarrierCapabilities caps) @private
{
	if (!vk_barrier_state_supported(state, caps)) return {};
	VkStageMaskResult result = { .ok = true };
	if ((state & VK_SHADER_ACCESS_STATES) != VK_RESOURCE_STATE_NONE)
	{
		result.mask |= vk::PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
		result.mask |= vk::PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
		result.mask |= vk::PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
		if (caps.ray_tracing_pipeline_enabled) result.mask |= vk::PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
	}
	if (state.render_target || state.render_target_read) result.mask |= vk::PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (state.depth_write || state.depth_read) result.mask |= vk::PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | vk::PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
	if (state.copy_src || state.copy_dst) result.mask |= vk::PIPELINE_STAGE_2_COPY_BIT | vk::PIPELINE_STAGE_2_BLIT_BIT | vk::PIPELINE_STAGE_2_CLEAR_BIT;
	if (state.indirect_argument) result.mask |= vk::PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (state.vertex_buffer || state.index_buffer) result.mask |= vk::PIPELINE_STAGE_2_VERTEX_INPUT_BIT;
	if ((state & VK_ACCEL_STATES) != VK_RESOURCE_STATE_NONE) result.mask |= vk::PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	if (state.clear_storage) result.mask |= vk::PIPELINE_STAGE_2_CLEAR_BIT;
	if (state.host_read) result.mask |= vk::PIPELINE_STAGE_2_HOST_BIT;
	return result;
}

fn VkStageMaskResult vk_stage_bits_to_vk(BarrierStages stages, ResourceState fallback, BarrierCapabilities caps) @private
{
	if (!vk_barrier_state_supported(fallback, caps)) return {};
	if (stages == VK_BARRIER_STAGES_NONE) return vk_stage_mask_from_state(fallback, caps);
	VkStageMaskResult result = { .ok = true };
	if (fallback.render_target || fallback.render_target_read) result.mask |= vk::PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (fallback.depth_write || fallback.depth_read) result.mask |= vk::PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | vk::PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
	if ((fallback.copy_src || fallback.copy_dst) && (stages.copy || stages.blit || stages.clear)) {
		// The explicit transfer hint supplies the fixed-function transfer stage.
	} else if (fallback.copy_src || fallback.copy_dst) {
		result.mask |= vk::PIPELINE_STAGE_2_COPY_BIT | vk::PIPELINE_STAGE_2_BLIT_BIT | vk::PIPELINE_STAGE_2_CLEAR_BIT;
	}
	if (fallback.clear_storage) result.mask |= vk::PIPELINE_STAGE_2_CLEAR_BIT;
	if (fallback.indirect_argument) result.mask |= vk::PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (fallback.vertex_buffer || fallback.index_buffer) result.mask |= vk::PIPELINE_STAGE_2_VERTEX_INPUT_BIT;
	if (fallback.host_read) result.mask |= vk::PIPELINE_STAGE_2_HOST_BIT;
	if (stages.vertex) result.mask |= vk::PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
	if (stages.fragment) result.mask |= vk::PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
	if (stages.compute) result.mask |= vk::PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
	if (stages.ray_tracing)
	{
		BarrierStages non_ray = stages;
		non_ray.ray_tracing = false;
		bool raster_shader_stage = non_ray.vertex || non_ray.fragment || non_ray.compute;
		if (!caps.ray_tracing_pipeline_enabled && (non_ray == VK_BARRIER_STAGES_NONE || (!raster_shader_stage && (fallback & VK_SHADER_ACCESS_STATES) != VK_RESOURCE_STATE_NONE))) return {};
		if (caps.ray_tracing_pipeline_enabled) result.mask |= vk::PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
	}
	if (stages.draw_indirect) result.mask |= vk::PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (stages.copy) result.mask |= vk::PIPELINE_STAGE_2_COPY_BIT;
	if (stages.blit) result.mask |= vk::PIPELINE_STAGE_2_BLIT_BIT;
	if (stages.clear) result.mask |= vk::PIPELINE_STAGE_2_CLEAR_BIT;
	if (stages.accel_build)
	{
		if (!caps.acceleration_structure_enabled) return {};
		result.mask |= vk::PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	}
	if (stages.color_attachment) result.mask |= vk::PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (stages.host) result.mask |= vk::PIPELINE_STAGE_2_HOST_BIT;
	if (fallback.accel_write) result.mask |= vk::PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	return result;
}

fn vk::ImageAspectFlags vk_barrier_aspect(BarrierAspect aspect) @private
{
	switch (aspect)
	{
		case COLOR: return vk::IMAGE_ASPECT_COLOR_BIT;
		case DEPTH: return vk::IMAGE_ASPECT_DEPTH_BIT;
		case STENCIL: return vk::IMAGE_ASPECT_STENCIL_BIT;
		case DEPTH_STENCIL: return vk::IMAGE_ASPECT_DEPTH_BIT | vk::IMAGE_ASPECT_STENCIL_BIT;
	}
}

fn void cmd_resource_barrier_vk(Cmd* cmd, Device* device, MemoryBarrier[] memory, BufferBarrier[] buffers, ImageBarrier[] images)
{
	VkStageMaskResult source;
	VkStageMaskResult destination;
	vk::MemoryBarrier2[] vk_memory = mem::temp_array(vk::MemoryBarrier2, memory.len);
	vk::BufferMemoryBarrier2[] vk_buffers = mem::temp_array(vk::BufferMemoryBarrier2, buffers.len);
	vk::ImageMemoryBarrier2[] vk_images = mem::temp_array(vk::ImageMemoryBarrier2, images.len);
	uint memory_count;
	uint buffer_count;
	uint image_count;
	foreach (barrier : memory)
	{
		source = vk_stage_bits_to_vk(barrier.before_stages, barrier.before, cmd.barrier_capabilities);
		destination = vk_stage_bits_to_vk(barrier.after_stages, barrier.after, cmd.barrier_capabilities);
		if (!source.ok || !destination.ok) { log::error("rhi: unsupported memory barrier; skipped"); continue; }
		vk_memory[memory_count] = { .sType = vk::StructureType.MEMORY_BARRIER_2, .srcStageMask = source.mask, .srcAccessMask = vk_resource_state_to_access(barrier.before), .dstStageMask = destination.mask, .dstAccessMask = vk_resource_state_to_access(barrier.after) };
		memory_count++;
	}
	foreach (barrier : buffers)
	{
		source = vk_stage_bits_to_vk(barrier.before_stages, barrier.before, cmd.barrier_capabilities);
		destination = vk_stage_bits_to_vk(barrier.after_stages, barrier.after, cmd.barrier_capabilities);
		if (!source.ok || !destination.ok) { log::error("rhi: unsupported buffer barrier; skipped"); continue; }
		vk_buffers[buffer_count] = {
			.sType = vk::StructureType.BUFFER_MEMORY_BARRIER_2,
			.srcStageMask = source.mask,
			.srcAccessMask = vk_resource_state_to_access(barrier.before),
			.dstStageMask = destination.mask,
			.dstAccessMask = vk_resource_state_to_access(barrier.after),
			.srcQueueFamilyIndex = vk::QUEUE_FAMILY_IGNORED,
			.dstQueueFamilyIndex = vk::QUEUE_FAMILY_IGNORED,
			.buffer = barrier.buffer.backend.vk.buffer,
			.offset = barrier.offset,
			.size = barrier.size == 0 ? vk::WHOLE_SIZE : barrier.size,
		};
		buffer_count++;
	}
	foreach (barrier : images)
	{
		source = vk_stage_bits_to_vk(barrier.before_stages, barrier.before, cmd.barrier_capabilities);
		destination = vk_stage_bits_to_vk(barrier.after_stages, barrier.after, cmd.barrier_capabilities);
		if (!source.ok || !destination.ok) { log::error("rhi: unsupported image barrier; skipped"); continue; }
		vk_images[image_count] = {
			.sType = vk::StructureType.IMAGE_MEMORY_BARRIER_2,
			.srcStageMask = source.mask,
			.srcAccessMask = vk_resource_state_to_access(barrier.before),
			.dstStageMask = destination.mask,
			.dstAccessMask = vk_resource_state_to_access(barrier.after),
			.oldLayout = vk_resource_state_to_image_layout_aspect(barrier.before, barrier.aspect),
			.newLayout = vk_resource_state_to_image_layout_aspect(barrier.after, barrier.aspect),
			.srcQueueFamilyIndex = vk::QUEUE_FAMILY_IGNORED,
			.dstQueueFamilyIndex = vk::QUEUE_FAMILY_IGNORED,
			.image = barrier.image.backend.vk.image,
			.subresourceRange = {
				.aspectMask = vk_barrier_aspect(barrier.aspect),
				.baseMipLevel = barrier.base_mip,
				.levelCount = barrier.mip_count == 0 ? vk::REMAINING_MIP_LEVELS : barrier.mip_count,
				.baseArrayLayer = barrier.base_layer,
				.layerCount = barrier.layer_count == 0 ? vk::REMAINING_ARRAY_LAYERS : barrier.layer_count,
			},
		};
		image_count++;
	}
	if (memory_count + buffer_count + image_count == 0) return;
	vk::DependencyInfo dependency = {
		.sType = vk::StructureType.DEPENDENCY_INFO,
		.memoryBarrierCount = memory_count,
		.pMemoryBarriers = vk_memory.ptr,
		.bufferMemoryBarrierCount = buffer_count,
		.pBufferMemoryBarriers = vk_buffers.ptr,
		.imageMemoryBarrierCount = image_count,
		.pImageMemoryBarriers = vk_images.ptr,
	};
	device.backend.vk.vtable.cmdPipelineBarrier2(cmd.backend.vk.cmd, &dependency);
}

fn void cmd_copy_buffer_to_texture_vk(Cmd* cmd, Device* device, CmdCopyBufferToTextureOptions options)
{
	(void)device;
	vk::BufferImageCopy region = {
		.bufferOffset = options.buffer_offset,
		.bufferRowLength = options.buffer_row_length,
		.bufferImageHeight = options.buffer_image_height,
		.imageSubresource = { .aspectMask = vk_barrier_aspect(options.aspect), .mipLevel = options.mip_level, .baseArrayLayer = options.base_array_layer, .layerCount = options.layer_count },
		.imageOffset = { .x = options.x, .y = options.y, .z = options.z },
		.imageExtent = { .width = options.width, .height = options.height, .depth = options.depth },
	};
	device.backend.vk.vtable.cmdCopyBufferToImage(cmd.backend.vk.cmd, options.src.backend.vk.buffer, options.dst.backend.vk.image, vk::ImageLayout.TRANSFER_DST_OPTIMAL, 1, &region);
}

fn void cmd_copy_texture_to_buffer_vk(Cmd* cmd, Device* device, CmdCopyTextureToBufferOptions options)
{
	(void)device;
	vk::BufferImageCopy region = {
		.bufferOffset = options.buffer_offset,
		.bufferRowLength = options.buffer_row_length,
		.bufferImageHeight = options.buffer_image_height,
		.imageSubresource = { .aspectMask = vk_barrier_aspect(options.aspect), .mipLevel = options.mip_level, .baseArrayLayer = options.base_array_layer, .layerCount = options.layer_count },
		.imageOffset = { .x = options.x, .y = options.y, .z = options.z },
		.imageExtent = { .width = options.width, .height = options.height, .depth = options.depth },
	};
	device.backend.vk.vtable.cmdCopyImageToBuffer(cmd.backend.vk.cmd, options.src.backend.vk.image, vk::ImageLayout.TRANSFER_SRC_OPTIMAL, options.dst.backend.vk.buffer, 1, &region);
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal command recording. Metal command buffers are retained while they are
// owned by a Cmd and committed by queue_submit_mtl; encoders are ended before
// a command buffer is submitted or reused.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import mtl;

const uint MTL_DRAW_PRIMITIVE_STRIDE = 16;
const uint MTL_DRAW_INDEXED_STRIDE = 20;

struct CmdMtl
{
	mtl::CommandQueue queue;
	mtl::CommandBuffer command_buffer;
	mtl::RenderCommandEncoder render_encoder;
	mtl::BlitCommandEncoder blit_encoder;
	mtl::Buffer index_buffer;
	mtl::IndexType index_type;
	ulong index_offset;
	mtl::PrimitiveType primitive_type;
	bool render_active;
	bool blit_active;
}

fn void mtl_finish_render(CmdMtl* state)
{
	if (!state.render_encoder) return;
	state.render_encoder.end_encoding();
	state.render_encoder = null;
	state.render_active = false;
}

fn void mtl_finish_blit(CmdMtl* state)
{
	if (!state.blit_encoder) return;
	state.blit_encoder.end_encoding();
	state.blit_encoder = null;
	state.blit_active = false;
}

fn bool mtl_require_render(CmdMtl* state)
{
	if (state.render_encoder) return true;
	log::error("Metal: graphics command requires an active render pass");
	return false;
}

fn bool mtl_begin_blit(CmdMtl* state)
{
	if (state.render_encoder)
	{
		log::error("Metal: copy command rejected inside a render pass");
		return false;
	}
	if (state.blit_encoder) return true;
	if (!state.command_buffer)
	{
		log::error("Metal: copy command has no command buffer");
		return false;
	}
	state.blit_encoder = state.command_buffer.blit_command_encoder();
	if (!state.blit_encoder)
	{
		log::error("Metal: failed to create blit encoder");
		return false;
	}
	state.blit_active = true;
	return true;
}

fn mtl::LoadAction mtl_load_action(LoadOp op)
{
	switch (op)
	{
		case LOAD: return mtl::LoadAction.LOAD;
		case CLEAR: return mtl::LoadAction.CLEAR;
		case DONT_CARE: return mtl::LoadAction.DONT_CARE;
	}
}

fn mtl::StoreAction mtl_store_action(StoreOp op)
{
	switch (op)
	{
		case STORE: return mtl::StoreAction.STORE;
		case DONT_CARE: return mtl::StoreAction.DONT_CARE;
	}
}

fn mtl::RenderStages mtl_render_stages(BarrierStages stages)
{
	mtl::RenderStages result = {};
	if (stages.vertex) result |= mtl::RENDER_STAGE_VERTEX;
	if (stages.fragment) result |= mtl::RENDER_STAGE_FRAGMENT;
	// Metal's graphics encoder has no compute/copy stage. Treat non-graphics
	// producer/consumer names as the whole graphics encoder scope.
	if (stages.compute || stages.ray_tracing || stages.draw_indirect || stages.copy ||
		stages.blit || stages.clear || stages.accel_build || stages.color_attachment || stages.host)
	{
		result |= mtl::RENDER_STAGE_VERTEX | mtl::RENDER_STAGE_FRAGMENT;
	}
	if (!stages.vertex && !stages.fragment && !stages.compute && !stages.ray_tracing &&
		!stages.draw_indirect && !stages.copy && !stages.blit && !stages.clear &&
		!stages.accel_build && !stages.color_attachment && !stages.host)
	{
		result = mtl::RENDER_STAGE_VERTEX | mtl::RENDER_STAGE_FRAGMENT;
	}
	return result;
}

fn void mtl_copy_layout(Format format, uint width, uint height, uint bytes_per_row, uint bytes_per_image, uint row_length, uint image_height, uint* out_row, uint* out_image)
{
	FormatProperties props = format_get_props(format);
	uint blocks_x = (width + props.block_width - 1) / props.block_width;
	uint rows = (height + props.block_height - 1) / props.block_height;
	uint tight_row = blocks_x * props.stride;
	uint row = bytes_per_row;
	if (row == 0 && row_length != 0) row = ((row_length + props.block_width - 1) / props.block_width) * props.stride;
	if (row == 0) row = tight_row;
	uint image = bytes_per_image;
	if (image == 0)
	{
		uint image_rows = image_height != 0 ? (image_height + props.block_height - 1) / props.block_height : rows;
		image = row * image_rows;
	}
	*out_row = row;
	*out_image = image;
}

fn Cmd? cmd_init_mtl(Device* device, Pool* pool)
{
	return { .backend.mtl = { .queue = device.backend.mtl.queue } };
}

fn void cmd_deinit_mtl(Cmd* c, Device* device, Pool* pool)
{
	CmdMtl* state = &c.backend.mtl;
	mtl_finish_render(state);
	mtl_finish_blit(state);
	if (state.command_buffer) state.command_buffer.release();
	*state = {};
}

fn void? cmd_begin_mtl(Cmd* c, Device* device)
{
	CmdMtl* state = &c.backend.mtl;
	mtl_finish_render(state);
	mtl_finish_blit(state);
	if (state.command_buffer) state.command_buffer.release();
	state.command_buffer = state.queue.command_buffer();
	if (!state.command_buffer) return INITIALIZATION_FAILED~;
	state.command_buffer.retain();
	state.index_buffer = null;
	state.index_offset = 0;
	state.render_active = false;
	state.blit_active = false;
	return;
}

fn void? cmd_end_mtl(Cmd* c, Device* device)
{
	CmdMtl* state = &c.backend.mtl;
	mtl_finish_render(state);
	mtl_finish_blit(state);
	return;
}

fn void cmd_set_viewport_mtl(Cmd* c, Device* device, Viewport vp)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state)) return;
	state.render_encoder.set_viewport({
		.origin_x = vp.x, .origin_y = vp.y, .width = vp.width, .height = vp.height,
		.znear = vp.min_depth, .zfar = vp.max_depth,
	});
}

fn void cmd_set_scissor_mtl(Cmd* c, Device* device, Rect rect)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state)) return;
	if (rect.x < 0 || rect.y < 0)
	{
		log::error("Metal: negative scissor coordinates are unsupported");
		return;
	}
	state.render_encoder.set_scissor_rect({ .x = (mtl::NSUInteger)rect.x, .y = (mtl::NSUInteger)rect.y, .width = rect.width, .height = rect.height });
}

fn void cmd_draw_mtl(Cmd* c, Device* device, uint vertex_count, uint instance_count, uint first_vertex, uint first_instance)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state)) return;
	state.render_encoder.draw_primitives_instanced(state.primitive_type, first_vertex, vertex_count, instance_count, first_instance);
}

fn void cmd_draw_indexed_mtl(Cmd* c, Device* device, uint index_count, uint instance_count, uint first_index, int vertex_offset, uint first_instance)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state) || !state.index_buffer)
	{
		if (!state.index_buffer) log::error("Metal: indexed draw has no index buffer");
		return;
	}
	uint index_size = state.index_type == mtl::IndexType.UINT16 ? 2 : 4;
	ulong byte_offset = state.index_offset + (ulong)first_index * index_size;
	state.render_encoder.draw_indexed_primitives_instanced(state.primitive_type, index_count, state.index_type, state.index_buffer, byte_offset, instance_count, vertex_offset, first_instance);
}

fn void cmd_draw_indirect_mtl(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state) || buffer == null || !buffer.backend.mtl.buffer) return;
	uint draw_stride = stride == 0 ? MTL_DRAW_PRIMITIVE_STRIDE : stride;
	for (uint i = 0; i < draw_count; i++)
	{
		state.render_encoder.draw_primitives_indirect(state.primitive_type, buffer.backend.mtl.buffer, offset + (ulong)i * draw_stride);
	}
}

fn void cmd_draw_indexed_indirect_mtl(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state) || !state.index_buffer || buffer == null || !buffer.backend.mtl.buffer)
	{
		if (!state.index_buffer) log::error("Metal: indexed indirect draw has no index buffer");
		return;
	}
	uint draw_stride = stride == 0 ? MTL_DRAW_INDEXED_STRIDE : stride;
	for (uint i = 0; i < draw_count; i++)
	{
		state.render_encoder.draw_indexed_primitives_indirect(state.primitive_type, state.index_type, state.index_buffer, state.index_offset, buffer.backend.mtl.buffer, offset + (ulong)i * draw_stride);
	}
}

fn void cmd_draw_indirect_count_mtl(Cmd* c, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	log::error("Metal: indirect-count draw is unsupported; draw dropped");
}

fn void cmd_bind_pipeline_mtl(Cmd* c, Device* device, Pipeline* pipeline)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state) || pipeline == null || !pipeline.backend.mtl.state) return;
	PipelineMtl* p = &pipeline.backend.mtl;
	state.primitive_type = p.primitive_type;
	state.render_encoder.set_render_pipeline_state(p.state);
	state.render_encoder.set_depth_stencil_state(p.depth_stencil);
	state.render_encoder.set_cull_mode(p.cull_mode);
	state.render_encoder.set_front_facing_winding(p.winding);
}

fn void cmd_set_push_constants_mtl(Cmd* c, Device* device, Pipeline* pipeline, char[] bytes)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state) || bytes.len == 0) return;
	if (pipeline != null && pipeline.backend.mtl.push_constant_size != 0 && bytes.len > pipeline.backend.mtl.push_constant_size)
	{
		log::error("Metal: push constant data exceeds pipeline limit");
		return;
	}
	state.render_encoder.set_vertex_bytes((void*)bytes.ptr, (mtl::NSUInteger)bytes.len, 0);
	state.render_encoder.set_fragment_bytes((void*)bytes.ptr, (mtl::NSUInteger)bytes.len, 0);
}

fn void cmd_clear_attachment_regions_mtl(Cmd* c, Device* device, CmdClearRegion[] regions)
{
	if (regions.len != 0) log::error("Metal: partial attachment clears are unsupported; clears dropped");
}

fn void cmd_begin_rendering_mtl(Cmd* c, Device* device, CmdBeginRenderingOptions options)
{
	CmdMtl* state = &c.backend.mtl;
	if (!state.command_buffer) { log::error("Metal: render pass has no command buffer"); return; }
	if (state.render_encoder)
	{
		log::error("Metal: render pass already active");
		return;
	}
	mtl_finish_blit(state);
	objc::@autoreleasepool()
	{
		mtl::RenderPassDescriptor desc = mtl::render_pass_descriptor();
		if (!desc) { log::error("Metal: failed to create render pass descriptor"); return; }
		mtl::RenderPassColorAttachmentDescriptorArray colors = desc.color_attachments();
		foreach (i, attachment : options.color_attachments)
		{
			if (!attachment.view.backend.mtl.texture) continue;
			mtl::RenderPassColorAttachmentDescriptor color = colors.object((mtl::NSUInteger)i);
			color.set_texture(attachment.view.backend.mtl.texture);
			color.set_load_action(mtl_load_action(attachment.load_op));
			color.set_store_action(mtl_store_action(attachment.store_op));
			if (attachment.load_op == CLEAR)
			{
				color.set_clear_color({ .red = attachment.clear_color[0], .green = attachment.clear_color[1], .blue = attachment.clear_color[2], .alpha = attachment.clear_color[3] });
			}
		}
		if (options.has_depth_attachment && options.depth_attachment.view.backend.mtl.texture)
		{
			CmdDepthAttachment depth = options.depth_attachment;
			mtl::RenderPassDepthAttachmentDescriptor depth_desc = desc.depth_attachment();
			depth_desc.set_texture(depth.view.backend.mtl.texture);
			depth_desc.set_load_action(mtl_load_action(depth.load_op));
			depth_desc.set_store_action(mtl_store_action(depth.store_op));
			if (depth.load_op == CLEAR) depth_desc.set_clear_depth(depth.clear_depth);
			if (depth.has_stencil)
			{
				mtl::RenderPassStencilAttachmentDescriptor stencil = desc.stencil_attachment();
				stencil.set_texture(depth.view.backend.mtl.texture);
				stencil.set_load_action(mtl_load_action(depth.stencil_load_op));
				stencil.set_store_action(mtl_store_action(depth.stencil_store_op));
				if (depth.stencil_load_op == CLEAR) stencil.set_clear_stencil(depth.clear_stencil);
			}
		}
		state.render_encoder = state.command_buffer.render_command_encoder(desc);
		if (!state.render_encoder)
		{
			log::error("Metal: failed to create render encoder");
			return;
		}
		state.render_active = true;
	};
}

fn void cmd_end_rendering_mtl(Cmd* c, Device* device)
{
	mtl_finish_render(&c.backend.mtl);
}

fn void cmd_bind_vertex_buffers_mtl(Cmd* c, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets)
{
	CmdMtl* state = &c.backend.mtl;
	if (!mtl_require_render(state)) return;
	foreach (i, buffer : buffers)
	{
		if (buffer == null || !buffer.backend.mtl.buffer) continue;
		ulong offset = offsets.len == 0 ? 0 : offsets[i];
		state.render_encoder.set_vertex_buffer(buffer.backend.mtl.buffer, offset, (mtl::NSUInteger)(MTL_VERTEX_BUFFER_BASE + first_binding + (uint)i));
	}
}

fn void cmd_bind_index_buffer_mtl(Cmd* c, Device* device, Buffer* buffer, IndexType index_type, ulong offset)
{
	CmdMtl* state = &c.backend.mtl;
	state.index_buffer = buffer == null ? null : buffer.backend.mtl.buffer;
	state.index_type = index_type == IndexType.UINT16 ? mtl::IndexType.UINT16 : mtl::IndexType.UINT32;
	state.index_offset = offset;
}

// Render-pass load/store handles non-storage transitions; only storage barriers
// in an open render encoder issue a Metal memory barrier.
fn void cmd_resource_barrier_mtl(Cmd* c, Device* device, MemoryBarrier[] memory, BufferBarrier[] buffers, ImageBarrier[] images)
{
	CmdMtl* state = &c.backend.mtl;
	if (!state.render_encoder) return;
	if (memory.len == 0 && buffers.len == 0 && images.len == 0) return;
	bool storage = false;
	foreach (barrier : memory)
	{
		if (barrier.before.storage_read || barrier.before.storage_write || barrier.after.storage_read || barrier.after.storage_write) { storage = true; break; }
	}
	if (!storage) foreach (barrier : buffers)
	{
		if (barrier.before.storage_read || barrier.before.storage_write || barrier.after.storage_read || barrier.after.storage_write) { storage = true; break; }
	}
	if (!storage) foreach (barrier : images)
	{
		if (barrier.before.storage_read || barrier.before.storage_write || barrier.after.storage_read || barrier.after.storage_write) { storage = true; break; }
	}
	if (!storage) return;
	mtl::BarrierScope scope = {};
	if (memory.len != 0 || buffers.len != 0) scope |= mtl::BARRIER_SCOPE_BUFFERS;
	if (memory.len != 0 || images.len != 0) scope |= mtl::BARRIER_SCOPE_TEXTURES;
	if (images.len != 0)
	{
		foreach (barrier : images)
		{
			if (barrier.before.render_target || barrier.after.render_target || barrier.before.depth_write || barrier.after.depth_write)
			{
				scope |= mtl::BARRIER_SCOPE_RENDER_TARGETS;
				break;
			}
		}
	}
	BarrierStages before = {};
	BarrierStages after = {};
	foreach (barrier : memory) { before |= barrier.before_stages; after |= barrier.after_stages; }
	foreach (barrier : buffers) { before |= barrier.before_stages; after |= barrier.after_stages; }
	foreach (barrier : images) { before |= barrier.before_stages; after |= barrier.after_stages; }
	state.render_encoder.memory_barrier(scope, mtl_render_stages(after), mtl_render_stages(before));
}

fn void cmd_copy_buffer_to_texture_mtl(Cmd* c, Device* device, CmdCopyBufferToTextureOptions options)
{
	CmdMtl* state = &c.backend.mtl;
	if (options.src == null || options.dst == null || !options.src.backend.mtl.buffer || !options.dst.backend.mtl.texture || options.width == 0 || options.height == 0 || options.depth == 0 || options.layer_count == 0 || options.x < 0 || options.y < 0 || options.z < 0 || !mtl_begin_blit(state)) return;
	uint row = 0;
	uint image = 0;
	mtl_copy_layout(options.dst.backend.mtl.format, options.width, options.height, options.bytes_per_row, options.bytes_per_image, options.buffer_row_length, options.buffer_image_height, &row, &image);
	if (options.dst.backend.mtl.image_type == D3)
	{
		state.blit_encoder.copy_buffer_to_texture(options.src.backend.mtl.buffer, options.buffer_offset, row, image, { .width = options.width, .height = options.height, .depth = options.depth }, options.dst.backend.mtl.texture, 0, options.mip_level, { .x = (mtl::NSUInteger)options.x, .y = (mtl::NSUInteger)options.y, .z = (mtl::NSUInteger)options.z });
	}
	else
	{
		for (uint layer = 0; layer < options.layer_count; layer++)
		{
			state.blit_encoder.copy_buffer_to_texture(options.src.backend.mtl.buffer, options.buffer_offset + (ulong)layer * image, row, image, { .width = options.width, .height = options.height, .depth = 1 }, options.dst.backend.mtl.texture, (mtl::NSUInteger)(options.base_array_layer + layer), options.mip_level, { .x = (mtl::NSUInteger)options.x, .y = (mtl::NSUInteger)options.y, .z = 0 });
		}
	}
}

fn void cmd_copy_texture_to_buffer_mtl(Cmd* c, Device* device, CmdCopyTextureToBufferOptions options)
{
	CmdMtl* state = &c.backend.mtl;
	if (options.src == null || options.dst == null || !options.src.backend.mtl.texture || !options.dst.backend.mtl.buffer || options.width == 0 || options.height == 0 || options.depth == 0 || options.layer_count == 0 || options.x < 0 || options.y < 0 || options.z < 0 || !mtl_begin_blit(state)) return;
	uint row = 0;
	uint image = 0;
	mtl_copy_layout(options.src.backend.mtl.format, options.width, options.height, options.bytes_per_row, options.bytes_per_image, options.buffer_row_length, options.buffer_image_height, &row, &image);
	if (options.src.backend.mtl.image_type == D3)
	{
		state.blit_encoder.copy_texture_to_buffer(options.src.backend.mtl.texture, 0, options.mip_level, { .x = (mtl::NSUInteger)options.x, .y = (mtl::NSUInteger)options.y, .z = (mtl::NSUInteger)options.z }, { .width = options.width, .height = options.height, .depth = options.depth }, options.dst.backend.mtl.buffer, options.buffer_offset, row, image);
	}
	else
	{
		for (uint layer = 0; layer < options.layer_count; layer++)
		{
			state.blit_encoder.copy_texture_to_buffer(options.src.backend.mtl.texture, (mtl::NSUInteger)(options.base_array_layer + layer), options.mip_level, { .x = (mtl::NSUInteger)options.x, .y = (mtl::NSUInteger)options.y, .z = 0 }, { .width = options.width, .height = options.height, .depth = 1 }, options.dst.backend.mtl.buffer, options.buffer_offset + (ulong)layer * image, row, image);
		}
	}
}

fn void cmd_copy_buffer_mtl(Cmd* c, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size)
{
	CmdMtl* state = &c.backend.mtl;
	if (src == null || dst == null || !src.backend.mtl.buffer || !dst.backend.mtl.buffer || size == 0 || !mtl_begin_blit(state)) return;
	state.blit_encoder.copy_buffer_to_buffer(src.backend.mtl.buffer, src_offset, dst.backend.mtl.buffer, dst_offset, size);
}

fn void cmd_copy_image_mtl(Cmd* c, Device* device, Image* src, Image* dst, ImageCopyDesc desc)
{
	CmdMtl* state = &c.backend.mtl;
	if (src == null || dst == null || !src.backend.mtl.texture || !dst.backend.mtl.texture || desc.width == 0 || desc.height == 0 || desc.depth == 0 || desc.src_x < 0 || desc.src_y < 0 || desc.src_z < 0 || desc.dst_x < 0 || desc.dst_y < 0 || desc.dst_z < 0 || !mtl_begin_blit(state)) return;
	state.blit_encoder.copy_texture_to_texture(src.backend.mtl.texture, desc.src_array_layer, desc.src_mip_level, { .x = (mtl::NSUInteger)desc.src_x, .y = (mtl::NSUInteger)desc.src_y, .z = (mtl::NSUInteger)desc.src_z }, { .width = desc.width, .height = desc.height, .depth = desc.depth }, dst.backend.mtl.texture, desc.dst_array_layer, desc.dst_mip_level, { .x = (mtl::NSUInteger)desc.dst_x, .y = (mtl::NSUInteger)desc.dst_y, .z = (mtl::NSUInteger)desc.dst_z });
}

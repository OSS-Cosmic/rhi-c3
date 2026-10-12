// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral command buffer. Port of rhi-zig's `cmd.zig`: recording
// (`cmd_init`/`cmd_begin`/`cmd_end`, state, draws, barriers, copies) is
// dispatched to the Vulkan, Metal, WebGPU and WebGL2 backends. The command pool and
// ring types (`Pool`, `CommandRingElement`, `CommandRingBuffer`) live in
// pool.c3 and cmd_ring.c3.
module rhi;
import d3d12, dxgi, mtl, vk;
import std::math::geometry;
import std::os::macos::objc;

struct Cmd
{
	union backend
	{
		CmdVk vk;
		CmdDx12 dx12;
		CmdMtl mtl;
		CmdWgpu wgpu;
		CmdWebgl webgl;
	}
	// Filled at `cmd_init`; every barrier recorded on this command buffer
	// translates against it.
	BarrierCapabilities barrier_capabilities;
}

// `min_depth`/`max_depth` have no meaningful zero-value default (Vulkan wants
// 0/1 respectively); the caller must set both explicitly.
//
// RI uses Vulkan-style signed-height viewports. Shared draws use exactly one
// form, {0, target_height, target_width, -target_height}: width positive,
// height negative for the Y-flipped/top-left mapping, so y is the far edge.
// Shaders pair with it by emitting ndc = float2(2,-2)*uv + float2(-1,1).
// Vulkan and Metal pass the values through unchanged; D3D12 interprets them.
//
// A positive height is Vulkan's native bottom-to-top mapping and has no D3D12
// equivalent (RSSetViewports takes a positive extent and always maps NDC y=+1
// to the top), so it renders vertically flipped there. `origin_bottom_left`
// requests that form explicitly and D3D12 rejects it rather than silently
// reorienting -- keep it false for shared draws.
struct Viewport
{
	float x;
	float y;
	float width;
	float height;
	float min_depth;
	float max_depth;
	bool origin_bottom_left;
}

struct CmdClearRegion
{
	float[4] color;
	std::math::geometry::Rect rect;
}

fn Cmd? cmd_init(Device* device, Pool* pool)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				vk::CommandBufferAllocateInfo info = {
					.sType = vk::StructureType.STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
					.commandPool = pool.backend.vk.pool,
					.level = vk::CommandBufferLevel.COMMAND_BUFFER_LEVEL_PRIMARY,
					.commandBufferCount = 1,
				};
				vk::CommandBuffer command_buffer;
				vk_check(vk::vkAllocateCommandBuffers(device.backend.vk.device, &info, &command_buffer))!;
				Cmd c = { .backend.vk = { .cmd = command_buffer } };
				// The Vulkan device does not track ray-tracing pipeline or
				// acceleration-structure features yet, so both stay off and
				// ray-tracing stages drop out of derived barrier masks, as HPL2
				// does on a device without RT.
				c.barrier_capabilities = {};
				return c;
			$endif
		case DX12:
			$if HAS_DX12:
				{
					d3d12::Device* dev = device.backend.dx12.device;
					d3d12::CommandAllocator* allocator = pool.backend.dx12.allocator;
					if (!dev || !allocator) return INITIALIZATION_FAILED~;

					Guid iid = d3d12::IID_GRAPHICS_COMMAND_LIST;
					d3d12::GraphicsCommandList* list;
					dx12_check(dev.vtbl.create_command_list(dev, 0, pool.backend.dx12.type, allocator, null, &iid, (void**)&list))!;
					// CreateCommandList returns the list open; close it so the first
					// `cmd_begin_dx12` can Reset it like every later one.
					if (dxgi::failed(list.vtbl.close(list)))
					{
						dxgi::release(list);
						return INITIALIZATION_FAILED~;
					}
					return { .backend.dx12 = { .list = list, .allocator = allocator } };
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					return { .backend.mtl = { .queue = device.backend.mtl.queue } };
				}
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					if (device == null || device.backend.wgpu.device == 0) return INITIALIZATION_FAILED~;
					return { .backend.wgpu = { .device = device.backend.wgpu.device } };
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					if (device == null || pool == null) return INITIALIZATION_FAILED~;
					WebglCommand[] commands = alloc::alloc_array_try(device.allocator, WebglCommand, WEBGL_MAX_COMMANDS)!;
					commands[..] = {};
					return { .barrier_capabilities = {}, .backend.webgl = { .commands = commands } };
				}
			$endif
	}
	unreachable();
}

fn void cmd_deinit(Cmd* c, Device* device, Pool* pool)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					vk::freeCommandBuffers(device.backend.vk.device, pool.backend.vk.pool, 1, &cmd.backend.vk.cmd);
					cmd.backend.vk = {};
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					(void)pool;
					CmdDx12* state = &cmd.backend.dx12;
					if (state.list) dxgi::release(state.list);
					*state = {};
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					mtl_finish_render(state);
					mtl_finish_blit(state);
					if (state.command_buffer) state.command_buffer.release();
					*state = {};
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					CmdWgpu* s = &c.backend.wgpu;
					if (s.pass != 0) { wgpu_render_pass_end(s.pass); s.pass = 0; }
					wgpu_release_if(&s.command_buffer);
					wgpu_release_if(&s.encoder);
					wgpu_release_if(&s.texture_bind_group);
					s.pipeline = 0;
					s.push_constant_group = 0;
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					if (c == null) return;
					if (c.backend.webgl.commands.ptr != null) alloc::free(device.allocator, c.backend.webgl.commands.ptr);
					c.backend.webgl = {};
				}
			$endif
	}
}

fn void? cmd_begin(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					vk::CommandBufferBeginInfo info = {
						.sType = vk::StructureType.STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
						.flags = vk::CommandBufferUsageFlagBits.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
					};
					return vk_check(vk::vkBeginCommandBuffer(cmd.backend.vk.cmd, &info));
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					CmdDx12* state = &cmd.backend.dx12;
					if (!state.list || !state.allocator) return UNKNOWN~;
					dx12_check(state.list.vtbl.reset(state.list, state.allocator, null))!;
					state.rtv_count = 0;
					state.has_dsv = false;
					state.vertex_stride = 0;
				}
			$endif
		case MTL:
			$if HAS_MTL:
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
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					CmdWgpu* s = &c.backend.wgpu;
					if (s.encoder != 0) return UNKNOWN~;
					s.encoder = wgpu_device_create_command_encoder(s.device);
					if (s.encoder == 0) return OUT_OF_DEVICE_MEMORY~;
					return;
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 if (c == null) return INITIALIZATION_FAILED~; c.backend.webgl.command_count = 0; return;
				}
			$endif
	}
	unreachable();
}

fn void? cmd_end(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					return vk_check(vk::vkEndCommandBuffer(cmd.backend.vk.cmd));
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					CmdDx12* state = &cmd.backend.dx12;
					if (!state.list) return UNKNOWN~;
					dx12_check(state.list.vtbl.close(state.list))!;
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					mtl_finish_render(state);
					mtl_finish_blit(state);
					return;
				}
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					CmdWgpu* s = &c.backend.wgpu;
					if (s.pass != 0) { wgpu_render_pass_end(s.pass); s.pass = 0; }
					if (s.encoder == 0) return UNKNOWN~;
					wgpu_release_if(&s.command_buffer);
					s.command_buffer = wgpu_command_encoder_finish(s.encoder);
					wgpu_release_if(&s.encoder);
					if (s.command_buffer == 0) return UNKNOWN~;
					return;
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 if (c == null) return INITIALIZATION_FAILED~; return;
				}
			$endif
	}
	unreachable();
}

fn void cmd_set_viewport(Cmd* c, Device* device, Viewport vp)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					Viewport viewport = vp;
					(void)device;
					vk::Viewport vk_viewport = {
						.x = viewport.x,
						.y = viewport.y,
						.width = viewport.width,
						.height = viewport.height,
						.minDepth = viewport.min_depth,
						.maxDepth = viewport.max_depth,
					};
					vk::cmdSetViewport(cmd.backend.vk.cmd, 0, 1, &vk_viewport);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					Viewport viewport = vp;
					(void)device;
					assert(!viewport.origin_bottom_left, "D3D12 does not support bottom-left origin viewports");
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					float y = viewport.y;
					float height = viewport.height;
					if (height < 0)
					{
						y += height;
						height = -height;
					}
					d3d12::Viewport vp = {
						.top_left_x = viewport.x,
						.top_left_y = y,
						.width = viewport.width,
						.height = height,
						.min_depth = viewport.min_depth,
						.max_depth = viewport.max_depth,
					};
					list.vtbl.rs_set_viewports(list, 1, &vp);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					state.render_encoder.set_viewport({
						.origin_x = vp.x, .origin_y = vp.y, .width = vp.width, .height = vp.height,
						.znear = vp.min_depth, .zfar = vp.max_depth,
					});
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c.backend.wgpu.pass != 0, "viewport requires an active render pass");
					wgpu_render_pass_set_viewport(c.backend.wgpu.pass, vp.x, vp.y, vp.width, vp.height, vp.min_depth, vp.max_depth);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, VIEWPORT); if (x != null) x.viewport = vp;
				}
			$endif
	}
}

fn void cmd_set_scissor(Cmd* c, Device* device, std::math::geometry::Rect rect)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::Rect2D scissor = {
						.offset = { .x = (int)rect.x, .y = (int)rect.y },
						.extent = { .width = (uint)rect.width, .height = (uint)rect.height },
					};
					vk::cmdSetScissor(cmd.backend.vk.cmd, 0, 1, &scissor);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					d3d12::Rect scissor = dx12_rect(rect);
					list.vtbl.rs_set_scissor_rects(list, 1, &scissor);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					assert(rect.x >= 0 && rect.y >= 0, "scissor coordinates must be nonnegative");
					state.render_encoder.set_scissor_rect({ .x = (mtl::NSUInteger)rect.x, .y = (mtl::NSUInteger)rect.y, .width = (mtl::NSUInteger)rect.width, .height = (mtl::NSUInteger)rect.height });
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c.backend.wgpu.pass != 0, "scissor requires an active render pass");
					assert(rect.x >= 0 && rect.y >= 0, "scissor coordinates must be nonnegative");
					wgpu_render_pass_set_scissor_rect(c.backend.wgpu.pass, (uint)rect.x, (uint)rect.y, (uint)rect.width, (uint)rect.height);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, SCISSOR); if (x != null) x.rect = rect;
				}
			$endif
	}
}

fn void cmd_draw(Cmd* c, Device* device, uint vertex_count, uint instance_count = 1, uint first_vertex = 0, uint first_instance = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdDraw(cmd.backend.vk.cmd, vertex_count, instance_count, first_vertex, first_instance);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					list.vtbl.draw_instanced(list, vertex_count, instance_count, first_vertex, first_instance);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					state.render_encoder.draw_primitives_instanced(state.primitive_type, first_vertex, vertex_count, instance_count, first_instance);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c.backend.wgpu.pass != 0, "draw requires an active render pass");
					wgpu_render_pass_draw(c.backend.wgpu.pass, vertex_count, instance_count, first_vertex, first_instance);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, DRAW); if (x != null) { x.count = vertex_count; x.instance_count = instance_count; x.first = first_vertex; }
				}
			$endif
	}
}

fn void cmd_draw_indexed(Cmd* c, Device* device, uint index_count, uint instance_count = 1, uint first_index = 0, int vertex_offset = 0, uint first_instance = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdDrawIndexed(cmd.backend.vk.cmd, index_count, instance_count, first_index, vertex_offset, first_instance);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					list.vtbl.draw_indexed_instanced(list, index_count, instance_count, first_index, vertex_offset, first_instance);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					assert(state.index_buffer, "indexed draw requires an index buffer");
					uint index_size = state.index_type == mtl::IndexType.UINT16 ? 2 : 4;
					ulong byte_offset = state.index_offset + (ulong)first_index * index_size;
					state.render_encoder.draw_indexed_primitives_instanced(state.primitive_type, index_count, state.index_type, state.index_buffer, byte_offset, instance_count, vertex_offset, first_instance);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c.backend.wgpu.pass != 0, "indexed draw requires an active render pass");
					wgpu_render_pass_draw_indexed(c.backend.wgpu.pass, index_count, instance_count, first_index, vertex_offset, first_instance);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, DRAW_INDEXED); if (x != null) { x.count = index_count; x.instance_count = instance_count; x.first = first_index; x.vertex_offset = vertex_offset; }
				}
			$endif
	}
}

// `draw_count` records of `Draw_Indirect_Command` layout (vertex_count,
// instance_count, first_vertex, first_instance: u32), `stride` bytes apart,
// starting at `offset`. The buffer must be in `.Indirect_Argument` state.
fn void cmd_draw_indirect(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdDrawIndirect(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, draw_count, stride);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					assert(buffer != null && buffer.backend.dx12.resource, "indirect draw requires an initialized argument buffer");
					if (draw_count == 0) return;
					d3d12::CommandSignature* signature = dx12_draw_signature(device, false);
					assert(signature, "failed to create D3D12 draw command signature");
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					uint natural = DX12_DRAW_ARGS_STRIDE;
					if (stride == 0 || stride == natural)
					{
						list.vtbl.execute_indirect(list, signature, draw_count, buffer.backend.dx12.resource, offset, null, 0);
						return;
					}
					for (uint i = 0; i < draw_count; i++)
					{
						list.vtbl.execute_indirect(list, signature, 1, buffer.backend.dx12.resource, offset + (ulong)i * stride, null, 0);
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					assert(buffer != null && buffer.backend.mtl.buffer, "indirect draw requires a valid argument buffer");
					uint draw_stride = stride == 0 ? MTL_DRAW_PRIMITIVE_STRIDE : stride;
					for (uint i = 0; i < draw_count; i++)
					{
						state.render_encoder.draw_primitives_indirect(state.primitive_type, buffer.backend.mtl.buffer, offset + (ulong)i * draw_stride);
					}
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: indirect draws are not in the scalar bridge");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Buffer* b = buffer;
				}
			$endif
	}
}

// Indexed form of `cmd_draw_indirect`: records are (index_count,
// instance_count, first_index: u32, vertex_offset: i32, first_instance: u32).
fn void cmd_draw_indexed_indirect(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdDrawIndexedIndirect(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, draw_count, stride);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					assert(buffer != null && buffer.backend.dx12.resource, "indirect draw requires an initialized argument buffer");
					if (draw_count == 0) return;
					d3d12::CommandSignature* signature = dx12_draw_signature(device, true);
					assert(signature, "failed to create D3D12 draw command signature");
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					uint natural = DX12_DRAW_INDEXED_ARGS_STRIDE;
					if (stride == 0 || stride == natural)
					{
						list.vtbl.execute_indirect(list, signature, draw_count, buffer.backend.dx12.resource, offset, null, 0);
						return;
					}
					for (uint i = 0; i < draw_count; i++)
					{
						list.vtbl.execute_indirect(list, signature, 1, buffer.backend.dx12.resource, offset + (ulong)i * stride, null, 0);
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					assert(state.index_buffer && buffer != null && buffer.backend.mtl.buffer, "indexed indirect draw requires an index buffer and valid argument buffer");
					uint draw_stride = stride == 0 ? MTL_DRAW_INDEXED_STRIDE : stride;
					for (uint i = 0; i < draw_count; i++)
					{
						state.render_encoder.draw_indexed_primitives_indirect(state.primitive_type, state.index_type, state.index_buffer, state.index_offset, buffer.backend.mtl.buffer, offset + (ulong)i * draw_stride);
					}
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: indexed indirect draws are not in the scalar bridge");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Buffer* b = buffer;
				}
			$endif
	}
}

// Like `cmd_draw_indirect`, but the draw count is the u32 at `count_offset` in
// `count_buffer`, clamped to `max_draw_count`. Requires
// `Physical_Adapter.is_draw_indirect_count_supported`.
fn void cmd_draw_indirect_count(Cmd* c, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdDrawIndirectCount(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, count_buffer.backend.vk.buffer, count_offset, max_draw_count, stride);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					assert(buffer != null && count_buffer != null, "indirect-count draw requires argument and count buffers");
					assert(buffer.backend.dx12.resource && count_buffer.backend.dx12.resource, "indirect-count draw requires initialized buffers");
					assert(max_draw_count > 0, "indirect-count draw maximum must be nonzero");
					assert(stride == 0 || stride == DX12_DRAW_ARGS_STRIDE, "D3D12 indirect-count draw requires tightly packed arguments");
					d3d12::CommandSignature* signature = dx12_draw_signature(device, false);
					if (!signature) return;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					list.vtbl.execute_indirect(list, signature, max_draw_count, buffer.backend.dx12.resource, offset, count_buffer.backend.dx12.resource, count_offset);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					// Metal does not support indirect-count draws.
					unreachable();
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: indirect-count draws are not in the scalar bridge");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Buffer* b = buffer;
				}
			$endif
	}
}

fn void cmd_bind_pipeline(Cmd* c, Device* device, Pipeline* pipeline)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdBindPipeline(cmd.backend.vk.cmd, vk::PipelineBindPoint.PIPELINE_BIND_POINT_GRAPHICS, pipeline.backend.vk.pipeline);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(pipeline != null && pipeline.backend.dx12.state, "pipeline must be initialized before binding");
					CmdDx12* state = &cmd.backend.dx12;
					PipelineDx12* p = &pipeline.backend.dx12;
					d3d12::GraphicsCommandList* list = state.list;
					list.vtbl.set_pipeline_state(list, p.state);
					list.vtbl.set_graphics_root_signature(list, p.root_signature);
					list.vtbl.ia_set_primitive_topology(list, p.topology);
					state.vertex_stride = p.vertex_stride;
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					assert(pipeline != null && pipeline.backend.mtl.state, "pipeline must be initialized before binding");
					PipelineMtl* p = &pipeline.backend.mtl;
					state.primitive_type = p.primitive_type;
					state.render_encoder.set_render_pipeline_state(p.state);
					state.render_encoder.set_depth_stencil_state(p.depth_stencil);
					state.render_encoder.set_cull_mode(p.cull_mode);
					state.render_encoder.set_front_facing_winding(p.winding);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					c.backend.wgpu.pipeline = pipeline == null ? 0 : pipeline.backend.wgpu.pipeline;
					c.backend.wgpu.push_constant_group = pipeline == null ? 0 : pipeline.backend.wgpu.push_constant_group;
					if (c.backend.wgpu.pass != 0 && c.backend.wgpu.pipeline != 0)
					{
						wgpu_render_pass_set_pipeline(c.backend.wgpu.pass, c.backend.wgpu.pipeline);
						if (c.backend.wgpu.push_constant_group != 0) wgpu_render_pass_set_bind_group(c.backend.wgpu.pass, 0, c.backend.wgpu.push_constant_group);
					}
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Pipeline* p = pipeline;
					 WebglCommand* x = webgl_push(c, PIPELINE); if (x != null) x.pipeline = p;
				}
			$endif
	}
}

fn void cmd_set_push_constants(Cmd* c, Device* device, Pipeline* pipeline, char[] bytes)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdPushConstants(cmd.backend.vk.cmd, pipeline.backend.vk.layout, vk::ShaderStageFlagBits.SHADER_STAGE_VERTEX_BIT, 0, (uint)bytes.len, bytes.ptr);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(pipeline != null, "push constants require a pipeline");
					if (bytes.len == 0) return;
					PipelineDx12* p = &pipeline.backend.dx12;
					assert(p.push_constant_param != uint::max, "pipeline has no push constant range");
					assert(bytes.len <= p.push_constant_size, "push constant data exceeds the pipeline limit");
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					// Root constants are whole 32-bit values; zero-pad a ragged tail.
					uint count = ((uint)bytes.len + 3) / 4;
					uint[] values = mem::talloc_array(uint, count);
					mem::clear(values.ptr, (usz)count * 4);
					mem::copy(values.ptr, bytes.ptr, bytes.len);
					list.vtbl.set_graphics_root_32bit_constants(list, p.push_constant_param, count, values.ptr, 0);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					if (bytes.len == 0) return;
					assert(pipeline != null, "push constants require a pipeline");
					assert(pipeline.backend.mtl.push_constant_size == 0 || bytes.len <= pipeline.backend.mtl.push_constant_size, "push constant data exceeds the pipeline limit");
					state.render_encoder.set_vertex_bytes((void*)bytes.ptr, (mtl::NSUInteger)bytes.len, 0);
					state.render_encoder.set_fragment_bytes((void*)bytes.ptr, (mtl::NSUInteger)bytes.len, 0);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(pipeline != null, "push constants require a pipeline");
					if (bytes.len == 0) return;
					assert(pipeline.backend.wgpu.push_constant_buffer != 0, "pipeline has no push constant buffer");
					uint size = (uint)min(bytes.len, (sz)pipeline.backend.wgpu.push_constant_size);
					if (size > 0) wgpu_queue_write_buffer(device.backend.wgpu.queue, pipeline.backend.wgpu.push_constant_buffer, 0, bytes.ptr, size);
					if (c.backend.wgpu.pass != 0 && pipeline.backend.wgpu.push_constant_group != 0) wgpu_render_pass_set_bind_group(c.backend.wgpu.pass, 0, pipeline.backend.wgpu.push_constant_group);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Pipeline* p = pipeline;
					WebglCommand* x = webgl_push(c, PUSH_CONSTANTS); if (x == null) return;
					x.pipeline = p; x.push_len = (uint)min(bytes.len, (sz)x.push_data.len); x.push_data[:x.push_len] = bytes[:x.push_len];
				}
			$endif
	}
}

// `regions` are partial attachment clears. Metal cannot encode these and
// drops them; render-pass load-op clears remain available there.
fn void cmd_clear_attachment_regions(Cmd* c, Device* device, CmdClearRegion[] regions)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					foreach (region : regions)
					{
						vk::ClearAttachment attachment = {
							.aspectMask = vk::ImageAspectFlagBits.IMAGE_ASPECT_COLOR_BIT,
							.colorAttachment = 0,
							.clearValue = { .color = { .float32 = region.color } },
						};
						vk::ClearRect rect = {
							.rect = {
								.offset = { .x = (int)region.rect.x, .y = (int)region.rect.y },
								.extent = { .width = (uint)region.rect.width, .height = (uint)region.rect.height },
							},
							.baseArrayLayer = 0,
							.layerCount = 1,
						};
						vk::cmdClearAttachments(cmd.backend.vk.cmd, 1, &attachment, 1, &rect);
					}
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					CmdDx12* state = &cmd.backend.dx12;
					assert(regions.len == 0 || state.rtv_count != 0, "attachment clears require active render targets");
					d3d12::GraphicsCommandList* list = state.list;
					// Like Vulkan, only color attachment 0 is cleared.
					foreach (region : regions)
					{
						float[4] color = region.color;
						d3d12::Rect rect = dx12_rect(region.rect);
						list.vtbl.clear_render_target_view(list, state.rtvs[0], &color, 1, &rect);
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					assert(regions.len == 0, "Metal does not support partial attachment clears");
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					// A WebGPU loadOp=clear clears the whole attachment.  Never translate a
					// region clear into it: that would silently erase pixels outside the region.
					if (regions.len > 0) abort("WebGPU: partial attachment clears are unsupported");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					WebglCommand* x = webgl_push(c, CLEAR_REGIONS); if (x == null) return; x.attachment_count = (uint)min(regions.len, (sz)8); foreach (i, region : regions[:x.attachment_count]) { x.attachments[i].clear_color = region.color; x.attachments[i].rect = region.rect; x.attachments[i].load_op = CLEAR; x.attachments[i].framebuffer = 0; x.attachments[i].texture = 0; }
				}
			$endif
	}
}

// Bind named descriptors against the slots the pipeline declared in
// `texture_bindings`. All slots go at once: WebGPU builds a bind group from a
// whole pipeline-owned layout, and a WebGL2 texture unit is global state.
// Metal writes the resolved texture and sampler objects directly at the
// pipeline-declared fragment indices. Vulkan/DX12 remain unsupported here.
// Call after `cmd_bind_pipeline`.
fn void? cmd_bind_descriptors(Cmd* c, Device* device, Pipeline* pipeline, DescriptorBinding[] bindings)
{
	switch (renderer.backend)
	{
		case VK:
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
					assert(c != null && pipeline != null, "descriptor binding requires a command buffer and pipeline");
				CmdMtl* state = &c.backend.mtl;
				assert(state.render_encoder, "descriptor binding requires an active render pass");
				PipelineMtl* metal_pipeline = &pipeline.backend.mtl;
				ResolvedDescriptorSlot[MAX_TEXTURE_BINDINGS] resolved = resolve_descriptor_slots(
					metal_pipeline.texture_slots[:metal_pipeline.texture_slot_count], bindings)!;
				for (uint i = 0; i < metal_pipeline.texture_slot_count; i++)
				{
					TextureSlot slot = metal_pipeline.texture_slots[i];
					if (resolved[i].has_texture)
					{
						state.render_encoder.set_fragment_texture(
							(mtl::Texture)resolved[i].texture.handle, (mtl::NSUInteger)slot.binding);
					}
					if (resolved[i].has_sampler)
					{
						state.render_encoder.set_fragment_sampler_state(
							(mtl::SamplerState)resolved[i].sampler.handle, (mtl::NSUInteger)slot.sampler_binding);
					}
				}
				return;
			$else
				break;
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c != null && pipeline != null && c.backend.wgpu.pass != 0, "descriptor binding requires a command buffer, pipeline, and active render pass");
					PipelineWgpu* p = &pipeline.backend.wgpu;
					DescriptorBinding[MAX_TEXTURE_BINDINGS] texture_bindings;
					uint texture_binding_count = 0;
					foreach (b : bindings)
					{
						if (b.descriptor.type == SAMPLED_IMAGE || b.descriptor.type == SAMPLER)
						{
							if (texture_binding_count >= texture_bindings.len) return TOO_MANY_TEXTURE_BINDINGS~;
							texture_bindings[texture_binding_count++] = b;
						}
						else if (!descriptor_is_empty(b.descriptor)) return DESCRIPTOR_TYPE_MISMATCH~;
					}
					ResolvedDescriptorSlot[MAX_TEXTURE_BINDINGS] resolved = resolve_descriptor_slots(p.texture_slots[:p.texture_slot_count], texture_bindings[:texture_binding_count])!;
					if (p.texture_slot_count == 0) return;
					uint[32] entries;
					uint count = 0;
					for (uint i = 0; i < p.texture_slot_count; i++)
					{
						TextureSlot slot = p.texture_slots[i];
						if (!resolved[i].has_texture) return DESCRIPTOR_MISSING~;
						entries[count] = slot.binding; entries[count + 1] = (uint)resolved[i].texture.handle; count += 2;
						if (resolved[i].has_sampler)
						{
							if (!slot.has_sampler_binding) return SAMPLER_REQUIRED~;
							entries[count] = slot.sampler_binding; entries[count + 1] = (uint)resolved[i].sampler.handle; count += 2;
						}
					}
					uint group = wgpu_device_create_bind_group_textures(device.backend.wgpu.device, p.texture_layout, &entries[0], count);
					if (group == 0) return INITIALIZATION_FAILED~;
					wgpu_render_pass_set_bind_group(c.backend.wgpu.pass, 1, group);
					wgpu_release_if(&c.backend.wgpu.texture_bind_group);
					c.backend.wgpu.texture_bind_group = group;
					return;
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Pipeline* p = pipeline;
					WebglCommand* x = webgl_push(c, DESCRIPTORS); if (x == null) return INITIALIZATION_FAILED~; x.pipeline = p; x.descriptor_count = (uint)min(bindings.len, (sz)MAX_TEXTURE_BINDINGS); x.descriptors[:x.descriptor_count] = bindings[:x.descriptor_count]; return;
				}
			$endif
	}
	unreachable();
}

// One pipeline texture slot's matched descriptors, indexed alongside the pipeline's slots.
struct ResolvedDescriptorSlot
{
	Descriptor texture;
	bool has_texture;
	Descriptor sampler;
	bool has_sampler;
}

// Match each binding to the slot whose declared name it carries. Order-free:
// bindings may be listed in any order.
fn ResolvedDescriptorSlot[MAX_TEXTURE_BINDINGS]? resolve_descriptor_slots(TextureSlot[] slots, DescriptorBinding[] bindings)
{
	ResolvedDescriptorSlot[MAX_TEXTURE_BINDINGS] out;
	foreach (b : bindings)
	{
		// An empty descriptor names an uncreated resource; skip it.
		if (descriptor_is_empty(b.descriptor)) continue;
		bool matched = false;
		// Every slot is checked, not just the first hit: one sampler shared
		// by two textures is named by both their slots.
		foreach (i, slot : slots)
		{
			if (slot.name_hash == b.handle.hash)
			{
				if (b.descriptor.type != SAMPLED_IMAGE) return DESCRIPTOR_TYPE_MISMATCH~;
				out[i].texture = b.descriptor;
				out[i].has_texture = true;
				matched = true;
			}
			if (slot.has_sampler_name_hash && slot.sampler_name_hash == b.handle.hash)
			{
				if (b.descriptor.type != SAMPLER) return DESCRIPTOR_TYPE_MISMATCH~;
				out[i].sampler = b.descriptor;
				out[i].has_sampler = true;
				matched = true;
			}
		}
		if (!matched) return BINDING_NOT_FOUND~;
	}
	return out;
}

enum LoadOp : char
{
	LOAD,
	CLEAR,
	DONT_CARE,
}

enum StoreOp : char
{
	STORE,
	DONT_CARE,
}

struct CmdColorAttachment
{
	ImageView view;
	LoadOp load_op;
	StoreOp store_op;
	float[4] clear_color;
}

struct CmdDepthAttachment
{
	ImageView view;
	LoadOp load_op;
	StoreOp store_op;
	float clear_depth;
	// Bind as DEPTH_READ_ONLY_OPTIMAL (depth-tested but not written) instead
	// of DEPTH_STENCIL_ATTACHMENT_OPTIMAL.
	bool read_only;
	// When the view's format carries a stencil aspect, set `has_stencil` to
	// also bind it as a stencil attachment with its own load/store (a pass may
	// load depth but clear stencil); `clear_stencil` supplies the clear. With
	// `has_stencil`, the depth aspect binds as DEPTH_ATTACHMENT_OPTIMAL and the
	// stencil aspect as STENCIL_ATTACHMENT_OPTIMAL.
	bool has_stencil;
	LoadOp stencil_load_op;
	StoreOp stencil_store_op;
	uint clear_stencil;
}

struct CmdBeginRenderingOptions
{
	CmdColorAttachment[] color_attachments;
	std::math::geometry::Rect render_area;
	CmdDepthAttachment depth_attachment;
	bool has_depth_attachment;
}

fn void cmd_begin_rendering(Cmd* c, Device* device, CmdBeginRenderingOptions options) @inline
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					assert(options.color_attachments.len <= 8, "Metal supports at most eight color attachments");
					vk::RenderingAttachmentInfo[8] colors;
					foreach (i, color : options.color_attachments)
					{
						colors[i] = {
							.sType = vk::StructureType.STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
							.imageView = color.view.backend.vk.view,
							.imageLayout = vk::ImageLayout.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
							.loadOp = vk_load_op(color.load_op),
							.storeOp = vk_store_op(color.store_op),
							.clearValue = { .color = { .float32 = color.clear_color } },
						};
					}
					vk::RenderingAttachmentInfo depth;
					vk::RenderingAttachmentInfo stencil;
					vk::RenderingInfo info = {
						.sType = vk::StructureType.STRUCTURE_TYPE_RENDERING_INFO,
						.renderArea = {
							.offset = { .x = (int)options.render_area.x, .y = (int)options.render_area.y },
							.extent = { .width = (uint)options.render_area.width, .height = (uint)options.render_area.height },
						},
						.layerCount = 1,
						.colorAttachmentCount = (uint)options.color_attachments.len,
						.pColorAttachments = &colors[0],
					};
					if (options.has_depth_attachment)
					{
						CmdDepthAttachment d = options.depth_attachment;
						depth = {
							.sType = vk::StructureType.STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
							.imageView = d.view.backend.vk.view,
							.imageLayout = d.read_only ? vk::ImageLayout.IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL : vk::ImageLayout.IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL,
							.loadOp = vk_load_op(d.load_op),
							.storeOp = vk_store_op(d.store_op),
							.clearValue = { .depthStencil = { .depth = d.clear_depth, .stencil = 0 } },
						};
						info.pDepthAttachment = &depth;
						if (d.has_stencil)
						{
							stencil = {
								.sType = vk::StructureType.STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO,
								.imageView = d.view.backend.vk.view,
								.imageLayout = vk::ImageLayout.IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL,
								.loadOp = vk_load_op(d.stencil_load_op),
								.storeOp = vk_store_op(d.stencil_store_op),
								.clearValue = { .depthStencil = { .depth = d.clear_depth, .stencil = d.clear_stencil } },
							};
							info.pStencilAttachment = &stencil;
						}
					}
					vk::cmdBeginRendering(cmd.backend.vk.cmd, &info);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(options.color_attachments.len <= DX12_MAX_RENDER_TARGETS, "render pass exceeds the D3D12 render target limit");
					CmdDx12* state = &cmd.backend.dx12;
					d3d12::GraphicsCommandList* list = state.list;

					state.rtv_count = (uint)options.color_attachments.len;
					foreach (i, color : options.color_attachments)
					{
						state.rtvs[i] = color.view.backend.dx12.cpu;
					}
					state.has_dsv = options.has_depth_attachment;
					if (state.has_dsv) state.dsv = options.depth_attachment.view.backend.dx12.cpu;
					list.vtbl.om_set_render_targets(list, state.rtv_count, state.rtv_count > 0 ? &state.rtvs[0] : null, 0, state.has_dsv ? &state.dsv : null);

					// Vulkan clears only inside the render area.
					d3d12::Rect area = dx12_rect(options.render_area);
					bool has_area = options.render_area.width != 0 && options.render_area.height != 0;
					foreach (i, color : options.color_attachments)
					{
						if (color.load_op != LoadOp.CLEAR) continue;
						float[4] clear_color = color.clear_color;
						list.vtbl.clear_render_target_view(list, state.rtvs[i], &clear_color, has_area ? 1 : 0, has_area ? &area : null);
					}
					if (state.has_dsv)
					{
						CmdDepthAttachment depth = options.depth_attachment;
						d3d12::ClearFlags flags = 0;
						if (depth.load_op == LoadOp.CLEAR && !depth.read_only) flags |= d3d12::CLEAR_FLAG_DEPTH;
						if (depth.has_stencil && depth.stencil_load_op == LoadOp.CLEAR) flags |= d3d12::CLEAR_FLAG_STENCIL;
						if (flags != 0)
						{
							list.vtbl.clear_depth_stencil_view(list, state.dsv, flags, depth.clear_depth, (char)depth.clear_stencil, has_area ? 1 : 0, has_area ? &area : null);
						}
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.command_buffer, "rendering requires an active command buffer");
					assert(!state.render_encoder, "rendering cannot begin while another render pass is active");
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
						state.render_encoder.retain();
						state.render_active = true;
					};
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					CmdWgpu* s = &c.backend.wgpu;
					assert(s.encoder != 0, "rendering requires an active command encoder");
					assert(options.color_attachments.len == 1, "WebGPU requires exactly one color attachment");
					if (s.pass != 0) { wgpu_render_pass_end(s.pass); s.pass = 0; }
					CmdColorAttachment color = options.color_attachments[0];
					uint depth_view = options.has_depth_attachment ? options.depth_attachment.view.backend.wgpu.view : 0;
					uint color_load = color.load_op == LOAD ? 0 : 1;
					uint color_store = color.store_op == STORE ? 0 : 1;
					uint depth_load = options.has_depth_attachment && options.depth_attachment.load_op == LOAD ? 0 : 1;
					uint depth_store = options.has_depth_attachment && options.depth_attachment.store_op == STORE ? 0 : 1;
					s.pass = wgpu_command_encoder_begin_render_pass(s.encoder, color.view.backend.wgpu.view, color_load, color_store, color.clear_color[0], color.clear_color[1], color.clear_color[2], color.clear_color[3], depth_view, depth_load, depth_store, options.has_depth_attachment ? options.depth_attachment.clear_depth : 1);
					if (s.pass != 0 && options.render_area.x >= 0 && options.render_area.y >= 0) wgpu_render_pass_set_scissor_rect(s.pass, (uint)options.render_area.x, (uint)options.render_area.y, (uint)options.render_area.width, (uint)options.render_area.height);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					WebglCommand* x = webgl_push(c, BEGIN_RENDERING); if (x == null) return; x.rect = options.render_area; x.width = (uint)options.render_area.width; x.height = (uint)options.render_area.height; x.attachment_count = (uint)min(options.color_attachments.len, (sz)8); foreach (i, a : options.color_attachments[:x.attachment_count]) { x.attachments[i].texture = a.view.backend.webgl.texture; x.attachments[i].framebuffer = a.view.backend.webgl.framebuffer; x.attachments[i].load_op = a.load_op; x.attachments[i].clear_color = a.clear_color; } if (x.attachment_count > 0) x.framebuffer = x.attachments[0].framebuffer; c.backend.webgl.pass_open = true;
					if (options.has_depth_attachment)
					{
						x.has_depth = true;
						x.clear_depth = options.depth_attachment.load_op == CLEAR;
						x.depth = options.depth_attachment.clear_depth;
						if (x.framebuffer == 0) x.framebuffer = options.depth_attachment.view.backend.webgl.framebuffer;
						gl_framebuffer_texture_2d(x.framebuffer, GL_DEPTH_ATTACHMENT, options.depth_attachment.view.backend.webgl.texture);
					}
				}
			$endif
	}
}

fn void cmd_end_rendering(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::cmdEndRendering(cmd.backend.vk.cmd);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					CmdDx12* state = &cmd.backend.dx12;
					state.rtv_count = 0;
					state.has_dsv = false;
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					mtl_finish_render(&c.backend.mtl);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					if (c.backend.wgpu.pass != 0) { wgpu_render_pass_end(c.backend.wgpu.pass); c.backend.wgpu.pass = 0; }
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, END_RENDERING); if (x != null) c.backend.webgl.pass_open = false;
				}
			$endif
	}
}

enum IndexType : char
{
	UINT16,
	UINT32,
}

fn void cmd_bind_vertex_buffer(Cmd* c, Device* device, Buffer* buffer, uint slot)
{
	Buffer*[1] buffers = { buffer };
	cmd_bind_vertex_buffers(c, device, slot, buffers[..]);
}

// Bind `buffers[i]` to binding `first_binding + i` at `offsets[i]`. A nil
// buffer entry binds nothing to its slot; nil `offsets` means all zero,
// otherwise it must be as long as `buffers`.
fn void cmd_bind_vertex_buffers(Cmd* c, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets = {}) @inline
{
	assert(offsets.ptr == null || offsets.len == buffers.len, "vertex buffer offsets must match the buffer count");
	if (buffers.len == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					assert(buffers.len <= 32, "Vulkan supports at most 32 vertex buffers in one call");
					assert(offsets.ptr == null || offsets.len == buffers.len, "vertex buffer offsets must match the buffer count");
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
						vk::cmdBindVertexBuffers(cmd.backend.vk.cmd, first_binding + start, end - start, &vk_buffers[start], &vk_offsets[start]);
						start = end;
					}
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(offsets.ptr == null || offsets.len == buffers.len, "vertex buffer offsets must match the buffer count");
					CmdDx12* state = &cmd.backend.dx12;
					d3d12::GraphicsCommandList* list = state.list;
					foreach (i, buffer : buffers)
					{
						if (buffer == null || !buffer.backend.dx12.resource) continue;
						ulong offset = offsets.ptr == null ? 0 : offsets[i];
						BufferDx12* b = &buffer.backend.dx12;
						if (offset > b.size) continue;
						d3d12::VertexBufferView view = {
							.buffer_location = b.gpu_address + offset,
							.size_in_bytes = (uint)(b.size - offset),
							.stride_in_bytes = state.vertex_stride,
						};
						list.vtbl.ia_set_vertex_buffers(list, first_binding + (uint)i, 1, &view);
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(state.render_encoder, "graphics command requires an active render pass");
					foreach (i, buffer : buffers)
					{
						if (buffer == null || !buffer.backend.mtl.buffer) continue;
						ulong offset = offsets.len == 0 ? 0 : offsets[i];
						state.render_encoder.set_vertex_buffer(buffer.backend.mtl.buffer, offset, (mtl::NSUInteger)(MTL_VERTEX_BUFFER_BASE + first_binding + (uint)i));
					}
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					assert(c.backend.wgpu.pass != 0, "vertex buffer binding requires an active render pass");
					foreach (i, b : buffers) if (b != null && b.cookie != 0) wgpu_render_pass_set_vertex_buffer(c.backend.wgpu.pass, first_binding + (uint)i, b.backend.wgpu.buffer, offsets.len == 0 ? 0 : (uint)offsets[i]);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					WebglCommand* x = webgl_push(c, VERTEX_BUFFERS); if (x == null) return; x.first_binding = first_binding; x.buffer_count = (uint)min(buffers.len, (sz)8); foreach (i, b : buffers[:x.buffer_count]) { x.buffers[i] = b; x.offsets[i] = offsets.len == buffers.len ? offsets[i] : 0; }
				}
			$endif
	}
}

fn void cmd_bind_index_buffer(Cmd* c, Device* device, Buffer* buffer, IndexType index_type, ulong offset = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::IndexType vk_index_type = index_type == UINT16 ? vk::IndexType.INDEX_TYPE_UINT16 : vk::IndexType.INDEX_TYPE_UINT32;
					vk::cmdBindIndexBuffer(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, vk_index_type);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(buffer != null && buffer.backend.dx12.resource, "index buffer must be initialized before binding");
					BufferDx12* b = &buffer.backend.dx12;
					assert(offset <= b.size, "index buffer offset exceeds the buffer size");
					d3d12::IndexBufferView view = {
						.buffer_location = b.gpu_address + offset,
						.size_in_bytes = (uint)(b.size - offset),
						.format = index_type == IndexType.UINT16 ? dxgi::Format.R16_UINT : dxgi::Format.R32_UINT,
					};
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					list.vtbl.ia_set_index_buffer(list, &view);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					state.index_buffer = buffer == null ? null : buffer.backend.mtl.buffer;
					state.index_type = index_type == IndexType.UINT16 ? mtl::IndexType.UINT16 : mtl::IndexType.UINT32;
					state.index_offset = offset;
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					if (c.backend.wgpu.pass != 0 && buffer != null) { c.backend.wgpu.index_format = index_type == UINT16 ? 0 : 1; wgpu_render_pass_set_index_buffer(c.backend.wgpu.pass, buffer.backend.wgpu.buffer, c.backend.wgpu.index_format, (uint)offset); }
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					Buffer* b = buffer;
					 WebglCommand* x = webgl_push(c, INDEX_BUFFER); if (x != null) { x.buffer = b; x.index_type = index_type; x.offset = offset; }
				}
			$endif
	}
}

// Port of HPL2's `RIResourceState` (RIBarrier.h). The empty set is UNDEFINED:
// the previous contents are discarded.
enum ResourceStateFlag : char
{
	GENERAL,
	RENDER_TARGET,
	RENDER_TARGET_READ,
	DEPTH_WRITE,
	DEPTH_READ,
	SHADER_RESOURCE,
	STORAGE_READ,
	STORAGE_WRITE,
	COPY_SRC,
	COPY_DST,
	PRESENT,
	INDIRECT_ARGUMENT,
	VERTEX_BUFFER,
	INDEX_BUFFER,
	CONSTANT_BUFFER,
	ACCEL_READ,
	ACCEL_WRITE,
	CLEAR_STORAGE,
	// A read of an acceleration structure build's input buffers. Vulkan maps
	// it like `Accel_Read`; D3D12 needs it kept separate.
	ACCEL_BUILD_INPUT,
	HOST_READ,
}

bitstruct ResourceState : uint
{
	bool general : 0;
	bool render_target : 1;
	bool render_target_read : 2;
	bool depth_write : 3;
	bool depth_read : 4;
	bool shader_resource : 5;
	bool storage_read : 6;
	bool storage_write : 7;
	bool copy_src : 8;
	bool copy_dst : 9;
	bool present : 10;
	bool indirect_argument : 11;
	bool vertex_buffer : 12;
	bool index_buffer : 13;
	bool constant_buffer : 14;
	bool accel_read : 15;
	bool accel_write : 16;
	bool clear_storage : 17;
	// A read of an acceleration structure build's input buffers. Vulkan maps
	// it like `Accel_Read`; D3D12 needs it kept separate.
	bool accel_build_input : 18;
	bool host_read : 19;
}

const ResourceState RESOURCE_STATE_UNORDERED_ACCESS = { .storage_read = true, .storage_write = true };

enum BarrierStage : char
{
	VERTEX,
	FRAGMENT,
	COMPUTE,
	RAY_TRACING,
	DRAW_INDIRECT,
	COPY,
	BLIT,
	CLEAR,
	ACCEL_BUILD,
	COLOR_ATTACHMENT,
	HOST,
}

// An empty set means "derive the stages from the resource state".
bitstruct BarrierStages : ushort
{
	bool vertex : 0;
	bool fragment : 1;
	bool compute : 2;
	bool ray_tracing : 3;
	bool draw_indirect : 4;
	bool copy : 5;
	bool blit : 6;
	bool clear : 7;
	bool accel_build : 8;
	bool color_attachment : 9;
	bool host : 10;
}

const BarrierStages BARRIER_STAGES_ALL_GRAPHICS = { .vertex = true, .fragment = true };
const BarrierStages BARRIER_STAGES_ALL_SHADER = { .vertex = true, .fragment = true, .compute = true, .ray_tracing = true };

// Device features that gate which stages a barrier may name. Copied onto the
// `Cmd` at `cmd_init` so every barrier in one recording translates against the
// same feature set, as HPL2's `RICmd::barrierCapabilities` does.
struct BarrierCapabilities
{
	bool ray_tracing_pipeline_enabled;
	bool acceleration_structure_enabled;
}

enum BarrierAspect : char
{
	COLOR,
	DEPTH,
	STENCIL,
	DEPTH_STENCIL,
}

struct MemoryBarrier
{
	ResourceState before;
	ResourceState after;
	BarrierStages before_stages;
	BarrierStages after_stages;
}

// `size == 0` covers the whole buffer from `offset`.
struct BufferBarrier
{
	Buffer* buffer;
	ResourceState before;
	ResourceState after;
	BarrierStages before_stages;
	BarrierStages after_stages;
	ulong offset;
	ulong size;
}

struct ImageBarrier
{
	Image* image;
	ResourceState before;
	ResourceState after;
	BarrierStages before_stages;
	BarrierStages after_stages;
	BarrierAspect aspect;
	ushort base_mip;
	ushort mip_count;
	ushort base_layer;
	ushort layer_count;
}

fn void cmd_resource_barrier(Cmd* c, Device* device, MemoryBarrier[] memory = {}, BufferBarrier[] buffers = {}, ImageBarrier[] images = {})
{
	if (memory.len == 0 && buffers.len == 0 && images.len == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
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
						assert(source.ok && destination.ok, "memory barrier uses unsupported access states");
						vk_memory[memory_count] = { .sType = vk::StructureType.STRUCTURE_TYPE_MEMORY_BARRIER_2, .srcStageMask = source.mask, .srcAccessMask = vk_resource_state_to_access(barrier.before), .dstStageMask = destination.mask, .dstAccessMask = vk_resource_state_to_access(barrier.after) };
						memory_count++;
					}
					foreach (barrier : buffers)
					{
						source = vk_stage_bits_to_vk(barrier.before_stages, barrier.before, cmd.barrier_capabilities);
						destination = vk_stage_bits_to_vk(barrier.after_stages, barrier.after, cmd.barrier_capabilities);
						assert(source.ok && destination.ok, "buffer barrier uses unsupported access states");
						vk_buffers[buffer_count] = {
							.sType = vk::StructureType.STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2,
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
						assert(source.ok && destination.ok, "image barrier uses unsupported access states");
						vk_images[image_count] = {
							.sType = vk::StructureType.STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2,
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
						.sType = vk::StructureType.STRUCTURE_TYPE_DEPENDENCY_INFO,
						.memoryBarrierCount = memory_count,
						.pMemoryBarriers = vk_memory.ptr,
						.bufferMemoryBarrierCount = buffer_count,
						.pBufferMemoryBarriers = vk_buffers.ptr,
						.imageMemoryBarrierCount = image_count,
						.pImageMemoryBarriers = vk_images.ptr,
					};
					vk::cmdPipelineBarrier2(cmd.backend.vk.cmd, &dependency);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					d3d12::ResourceBarrier[] barriers = mem::talloc_array(d3d12::ResourceBarrier, memory.len + buffers.len + images.len);
					uint count = 0;
					foreach (m : memory)
					{
						d3d12::ResourceStates before = dx12_resource_states(m.before, m.before_stages);
						d3d12::ResourceStates after = dx12_resource_states(m.after, m.after_stages);
						if (dx12_barrier_kind(before, after) != Dx12BarrierKind.UAV) continue;
						d3d12::ResourceBarrier b = {};
						b.type = d3d12::ResourceBarrierType.UAV;
						b.flags = d3d12::RESOURCE_BARRIER_FLAG_NONE;
						b.uav.resource = null;
						barriers[count++] = b;
					}
					foreach (b : buffers)
					{
						if (b.buffer == null || !b.buffer.backend.dx12.resource) continue;
						if (b.buffer.backend.dx12.heap_type != d3d12::HeapType.DEFAULT) continue;
						d3d12::ResourceStates before = dx12_resource_states(b.before, b.before_stages);
						d3d12::ResourceStates after = dx12_resource_states(b.after, b.after_stages);
						count += dx12_emit_barrier(&barriers[count], b.buffer.backend.dx12.resource, d3d12::RESOURCE_BARRIER_ALL_SUBRESOURCES, before, after);
					}
					// Partially-covered images expand to one barrier per subresource, so they
					// are flushed on their own below.
					foreach (b : images)
					{
						if (b.image == null || !b.image.backend.dx12.resource) continue;
						ImageDx12* image = &b.image.backend.dx12;
						if (!dx12_image_barrier_whole(image, b)) continue;
						d3d12::ResourceStates before = dx12_resource_states(b.before, b.before_stages);
						d3d12::ResourceStates after = dx12_resource_states(b.after, b.after_stages);
						count += dx12_emit_barrier(&barriers[count], image.resource, d3d12::RESOURCE_BARRIER_ALL_SUBRESOURCES, before, after);
					}
					if (count > 0) list.vtbl.resource_barrier(list, count, barriers.ptr);

					foreach (b : images)
					{
						if (b.image == null || !b.image.backend.dx12.resource) continue;
						ImageDx12* image = &b.image.backend.dx12;
						if (dx12_image_barrier_whole(image, b)) continue;
						d3d12::ResourceStates before = dx12_resource_states(b.before, b.before_stages);
						d3d12::ResourceStates after = dx12_resource_states(b.after, b.after_stages);
						uint mips = b.mip_count == 0 ? image.mip_levels - b.base_mip : b.mip_count;
						uint layers = b.layer_count == 0 ? image.array_layers - b.base_layer : b.layer_count;
						bool stencil = format_get_props(image.format).is_stencil;
						uint planes;
						switch (b.aspect)
						{
							case STENCIL: planes = 0b10;
							case DEPTH_STENCIL: planes = stencil ? 0b11 : 0b01;
							default: planes = 0b01;
						}
						d3d12::ResourceBarrier[] subresources = mem::talloc_array(d3d12::ResourceBarrier, (usz)mips * layers * 2);
						uint n = 0;
						for (uint plane = 0; plane < 2; plane++)
						{
							if ((planes & (1u << plane)) == 0) continue;
							for (uint layer = b.base_layer; layer < b.base_layer + layers; layer++)
							{
								for (uint mip = b.base_mip; mip < b.base_mip + mips; mip++)
								{
									uint index = mip + (layer + plane * image.array_layers) * image.mip_levels;
									n += dx12_emit_barrier(&subresources[n], image.resource, index, before, after);
								}
							}
						}
						if (n > 0) list.vtbl.resource_barrier(list, n, subresources.ptr);
					}
				}
			$endif
		case MTL:
			$if HAS_MTL:
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
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
				}
			$endif
	}
}

fn void cmd_image_barrier(Cmd* c, Device* device, ImageBarrier barrier)
{
	ImageBarrier[1] b = { barrier };
	cmd_resource_barrier(c, device, images: b[..]);
}

fn void cmd_buffer_barrier(Cmd* c, Device* device, BufferBarrier barrier)
{
	BufferBarrier[1] b = { barrier };
	cmd_resource_barrier(c, device, buffers: b[..]);
}

fn void cmd_memory_barrier(Cmd* c, Device* device, MemoryBarrier barrier)
{
	MemoryBarrier[1] b = { barrier };
	cmd_resource_barrier(c, device, memory: b[..]);
}

// Vulkan reads the texel counts (`buffer_row_length`/`buffer_image_height`);
// D3D12 reads the byte pitches (`bytes_per_row`/`bytes_per_image`) and copies
// with a PLACED_FOOTPRINT source, so on D3D12 `bytes_per_row` must be a
// multiple of 256 and `buffer_offset` a multiple of 512.
struct CmdCopyBufferToTextureOptions
{
	Buffer* src;
	Image* dst;
	ulong buffer_offset;
	uint buffer_row_length; // texels (Vulkan VkBufferImageCopy)
	uint buffer_image_height; // texels (Vulkan VkBufferImageCopy)
	uint bytes_per_row; // bytes (D3D12 row pitch)
	uint bytes_per_image; // bytes (D3D12 slice pitch)
	uint mip_level;
	uint base_array_layer;
	uint layer_count;
	BarrierAspect aspect;
	int x;
	int y;
	int z;
	uint width;
	uint height;
	uint depth;
}

fn void cmd_copy_buffer_to_texture(Cmd* c, Device* device, CmdCopyBufferToTextureOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::BufferImageCopy region = {
						.bufferOffset = options.buffer_offset,
						.bufferRowLength = options.buffer_row_length,
						.bufferImageHeight = options.buffer_image_height,
						.imageSubresource = { .aspectMask = vk_barrier_aspect(options.aspect), .mipLevel = options.mip_level, .baseArrayLayer = options.base_array_layer, .layerCount = options.layer_count },
						.imageOffset = { .x = options.x, .y = options.y, .z = options.z },
						.imageExtent = { .width = options.width, .height = options.height, .depth = options.depth },
					};
					vk::cmdCopyBufferToImage(cmd.backend.vk.cmd, options.src.backend.vk.buffer, options.dst.backend.vk.image, vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					dx12_copy_buffer_image(
						cmd, options.src, options.dst, true,
						options.buffer_offset, options.bytes_per_row, options.bytes_per_image,
						options.mip_level, options.base_array_layer, options.layer_count, options.aspect,
						options.x, options.y, options.z, options.width, options.height, options.depth);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(options.src != null && options.dst != null, "buffer-to-image copy requires source and destination resources");
					assert(options.src.backend.mtl.buffer && options.dst.backend.mtl.texture, "buffer-to-image copy requires a buffer and texture");
					assert(options.width > 0 && options.height > 0 && options.depth > 0 && options.layer_count > 0, "buffer-to-image copy extent and layer count must be nonzero");
					assert(options.x >= 0 && options.y >= 0 && options.z >= 0, "buffer-to-image copy origin must be nonnegative");
					if (!mtl_begin_blit(state)) return;
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
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: buffer-to-texture copies are unsupported; use image_upload");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					WebglCommand* x = webgl_push(c, COPY_BUFFER_TEXTURE); if (x != null) { x.src = options.src; x.image = options.dst; x.offset = options.buffer_offset; x.rect = { .x = (float)options.x, .y = (float)options.y, .width = (float)options.width, .height = (float)options.height }; }
				}
			$endif
	}
}

// Reverse of `cmd_copy_buffer_to_texture`. `src` must be in `.Copy_Src` and
// `dst` in `.Copy_Dst`; the caller owns the surrounding barriers. D3D12
// copies into a PLACED_FOOTPRINT destination, so on D3D12 `bytes_per_row`
// must be a multiple of 256 and `buffer_offset` a multiple of 512.
struct CmdCopyTextureToBufferOptions
{
	Image* src;
	Buffer* dst;
	ulong buffer_offset;
	uint buffer_row_length; // texels (Vulkan VkBufferImageCopy)
	uint buffer_image_height; // texels (Vulkan VkBufferImageCopy)
	uint bytes_per_row; // bytes (D3D12 row pitch)
	uint bytes_per_image; // bytes (D3D12 slice pitch)
	uint mip_level;
	uint base_array_layer;
	uint layer_count;
	BarrierAspect aspect;
	int x;
	int y;
	int z;
	uint width;
	uint height;
	uint depth;
}

fn void cmd_copy_texture_to_buffer(Cmd* c, Device* device, CmdCopyTextureToBufferOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::BufferImageCopy region = {
						.bufferOffset = options.buffer_offset,
						.bufferRowLength = options.buffer_row_length,
						.bufferImageHeight = options.buffer_image_height,
						.imageSubresource = { .aspectMask = vk_barrier_aspect(options.aspect), .mipLevel = options.mip_level, .baseArrayLayer = options.base_array_layer, .layerCount = options.layer_count },
						.imageOffset = { .x = options.x, .y = options.y, .z = options.z },
						.imageExtent = { .width = options.width, .height = options.height, .depth = options.depth },
					};
					vk::cmdCopyImageToBuffer(cmd.backend.vk.cmd, options.src.backend.vk.image, vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, options.dst.backend.vk.buffer, 1, &region);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					dx12_copy_buffer_image(
						cmd, options.dst, options.src, false,
						options.buffer_offset, options.bytes_per_row, options.bytes_per_image,
						options.mip_level, options.base_array_layer, options.layer_count, options.aspect,
						options.x, options.y, options.z, options.width, options.height, options.depth);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(options.src != null && options.dst != null, "image-to-buffer copy requires source and destination resources");
					assert(options.src.backend.mtl.texture && options.dst.backend.mtl.buffer, "image-to-buffer copy requires a texture and buffer");
					assert(options.width > 0 && options.height > 0 && options.depth > 0 && options.layer_count > 0, "image-to-buffer copy extent and layer count must be nonzero");
					assert(options.x >= 0 && options.y >= 0 && options.z >= 0, "image-to-buffer copy origin must be nonnegative");
					if (!mtl_begin_blit(state)) return;
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
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: texture-to-buffer copies are unsupported by the bridge");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
				}
			$endif
	}
}

// Copy `size` bytes from `src` at `src_offset` to `dst` at `dst_offset`. The
// caller owns the surrounding barriers (`.Copy_Src` / `.Copy_Dst`).
fn void cmd_copy_buffer(Cmd* c, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size)
{
	if (size == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::BufferCopy region = { .srcOffset = src_offset, .dstOffset = dst_offset, .size = size };
					vk::cmdCopyBuffer(cmd.backend.vk.cmd, src.backend.vk.buffer, dst.backend.vk.buffer, 1, &region);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(src != null && dst != null, "buffer copy requires source and destination buffers");
					assert(src.backend.dx12.resource && dst.backend.dx12.resource, "buffer copy resources must be initialized");
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
					list.vtbl.copy_buffer_region(list, dst.backend.dx12.resource, dst_offset, src.backend.dx12.resource, src_offset, size);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(src != null && dst != null, "buffer copy requires source and destination buffers");
					assert(src.backend.mtl.buffer && dst.backend.mtl.buffer, "buffer copy resources must be initialized");
					if (size == 0) return;
					if (!mtl_begin_blit(state)) return;
					state.blit_encoder.copy_buffer_to_buffer(src.backend.mtl.buffer, src_offset, dst.backend.mtl.buffer, dst_offset, size);
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					if (c.backend.wgpu.encoder != 0 && src != null && dst != null && size <= 0xFFFFFFFF) wgpu_command_encoder_copy_buffer_to_buffer(c.backend.wgpu.encoder, src.backend.wgpu.buffer, (uint)src_offset, dst.backend.wgpu.buffer, (uint)dst_offset, (uint)size);
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, COPY_BUFFER); if (x != null) { x.src = src; x.dst = dst; x.src_offset = src_offset; x.dst_offset = dst_offset; x.size = size; }
				}
			$endif
	}
}

// Port of HPL2's `RIImageCopyDesc`: one 1:1 region (no scaling).
//
// NOTE the field order: the source subresource comes FIRST and the extent
// LAST. A positional `{width, height, 1}` therefore fills src_mip_level,
// src_array_layer and src_x instead, leaving the extent zeroed -- set the
// fields by name. There are no field defaults, so `depth == 0` is read as 1 and
// a 2D copy may leave it unset.
struct ImageCopyDesc
{
	uint src_mip_level;
	uint src_array_layer;
	int src_x;
	int src_y;
	int src_z;
	uint dst_mip_level;
	uint dst_array_layer;
	int dst_x;
	int dst_y;
	int dst_z;
	uint width;
	uint height;
	uint depth;
}

// Image-to-image copy of a single region. `src` must be in `.Copy_Src` and
// `dst` in `.Copy_Dst`; the caller owns the surrounding barriers.
fn void cmd_copy_image(Cmd* c, Device* device, Image* src, Image* dst, ImageCopyDesc desc)
{
	ImageCopyDesc d = desc;
	if (d.depth == 0) d.depth = 1;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
					Cmd* cmd = c;
					(void)device;
					vk::ImageAspectFlags src_aspect = vk_image_aspect_from_vk_format(src.backend.vk.format, true);
					vk::ImageAspectFlags dst_aspect = vk_image_aspect_from_vk_format(dst.backend.vk.format, true);
					vk::ImageCopy region = {
						.srcSubresource = { .aspectMask = src_aspect, .mipLevel = d.src_mip_level, .baseArrayLayer = d.src_array_layer, .layerCount = 1 },
						.srcOffset = { .x = d.src_x, .y = d.src_y, .z = d.src_z },
						.dstSubresource = { .aspectMask = dst_aspect, .mipLevel = d.dst_mip_level, .baseArrayLayer = d.dst_array_layer, .layerCount = 1 },
						.dstOffset = { .x = d.dst_x, .y = d.dst_y, .z = d.dst_z },
						.extent = { .width = d.width, .height = d.height, .depth = d.depth },
					};
					vk::cmdCopyImage(cmd.backend.vk.cmd, src.backend.vk.image, vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst.backend.vk.image, vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					Cmd* cmd = c;
					(void)device;
					assert(src != null && dst != null, "image copy requires source and destination images");
					assert(src.backend.dx12.resource && dst.backend.dx12.resource, "image copy resources must be initialized");
					ImageDx12* s = &src.backend.dx12;
					ImageDx12* d = &dst.backend.dx12;
					d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;

					d3d12::TextureCopyLocation src_loc = {};
					src_loc.resource = s.resource;
					src_loc.type = d3d12::TextureCopyType.SUBRESOURCE_INDEX;
					src_loc.subresource_index = dx12_copy_subresource(s, d.src_mip_level, d.src_array_layer, BarrierAspect.COLOR);
					d3d12::TextureCopyLocation dst_loc = {};
					dst_loc.resource = d.resource;
					dst_loc.type = d3d12::TextureCopyType.SUBRESOURCE_INDEX;
					dst_loc.subresource_index = dx12_copy_subresource(d, d.dst_mip_level, d.dst_array_layer, BarrierAspect.COLOR);

					// A copy of the whole source subresource passes no box (required for
					// depth-stencil and multisampled resources).
					uint mip_width = s.width >> d.src_mip_level;
					uint mip_height = s.height >> d.src_mip_level;
					uint mip_depth = s.depth >> d.src_mip_level;
					if (mip_width == 0) mip_width = 1;
					if (mip_height == 0) mip_height = 1;
					if (mip_depth == 0) mip_depth = 1;
					bool whole = d.src_x == 0 && d.src_y == 0 && d.src_z == 0
						&& d.width == mip_width && d.height == mip_height && d.depth == mip_depth;
					d3d12::ResourceBox box = {
						.left = (uint)d.src_x, .top = (uint)d.src_y, .front = (uint)d.src_z,
						.right = (uint)d.src_x + d.width, .bottom = (uint)d.src_y + d.height, .back = (uint)d.src_z + d.depth,
					};
					list.vtbl.copy_texture_region(list, &dst_loc, (uint)d.dst_x, (uint)d.dst_y, (uint)d.dst_z, &src_loc, whole ? null : &box);
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					CmdMtl* state = &c.backend.mtl;
					assert(src != null && dst != null, "image copy requires source and destination images");
					assert(src.backend.mtl.texture && dst.backend.mtl.texture, "image copy resources must be initialized");
					assert(d.width > 0 && d.height > 0 && d.depth > 0, "image copy extent must be nonzero");
					assert(d.src_x >= 0 && d.src_y >= 0 && d.src_z >= 0 && d.dst_x >= 0 && d.dst_y >= 0 && d.dst_z >= 0, "image copy origins must be nonnegative");
					if (!mtl_begin_blit(state)) return;
					state.blit_encoder.copy_texture_to_texture(src.backend.mtl.texture, d.src_array_layer, d.src_mip_level, { .x = (mtl::NSUInteger)d.src_x, .y = (mtl::NSUInteger)d.src_y, .z = (mtl::NSUInteger)d.src_z }, { .width = d.width, .height = d.height, .depth = d.depth }, dst.backend.mtl.texture, d.dst_array_layer, d.dst_mip_level, { .x = (mtl::NSUInteger)d.dst_x, .y = (mtl::NSUInteger)d.dst_y, .z = (mtl::NSUInteger)d.dst_z });
				}
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				{
					 wgpu_log_text("WebGPU: image copies are unsupported by the bridge");
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					 WebglCommand* x = webgl_push(c, COPY_IMAGE); if (x != null) { x.image = src; x.image_dst = dst; x.image_copy = desc; }
				}
			$endif
	}
}

// ---- metal ----

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
	state.render_encoder.release();
	state.render_encoder = null;
	state.render_active = false;
}

fn void mtl_finish_blit(CmdMtl* state)
{
	if (!state.blit_encoder) return;
	state.blit_encoder.end_encoding();
	state.blit_encoder.release();
	state.blit_encoder = null;
	state.blit_active = false;
}

fn bool mtl_begin_blit(CmdMtl* state)
{
	assert(state != null, "copy command requires a command buffer");
	assert(!state.render_encoder, "copy commands cannot be recorded inside a render pass");
	if (state.blit_encoder) return true;
	assert(state.command_buffer, "copy command requires an active command buffer");
	state.blit_encoder = state.command_buffer.blit_command_encoder();
	if (!state.blit_encoder)
	{
		log::error("Metal: failed to create blit encoder");
		return false;
	}
	state.blit_encoder.retain();
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


















// Render-pass load/store handles non-storage transitions; only storage barriers
// in an open render encoder issue a Metal memory barrier.





// ---- dx12 ----

// Direct3D 12 command recording. Port of the `.dx12` arm of rhi-zig's
// `cmd.zig`. One CmdDx12 owns one ID3D12GraphicsCommandList created from the
// pool's allocator; `cmd_begin_dx12` reopens it against that allocator, which
// is only legal once the GPU finished every list recorded from the pool.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

const uint DX12_MAX_RENDER_TARGETS = 8;
// Argument record sizes of the two ExecuteIndirect command signatures.
const uint DX12_DRAW_ARGS_STRIDE = 16;
const uint DX12_DRAW_INDEXED_ARGS_STRIDE = 20;

struct CmdDx12
{
	// Owned. Created closed; `cmd_begin_dx12` opens it, `cmd_end_dx12` closes
	// it again so queue submission always sees an executable list.
	d3d12::GraphicsCommandList* list;
	// Borrowed from PoolDx12.
	d3d12::CommandAllocator* allocator;
	// Targets bound by `cmd_begin_rendering_dx12`, kept for partial clears.
	d3d12::CpuDescriptorHandle[DX12_MAX_RENDER_TARGETS] rtvs;
	uint rtv_count;
	d3d12::CpuDescriptorHandle dsv;
	bool has_dsv;
	// Vertex buffer stride of the pipeline bound last.
	uint vertex_stride;
}





// RI viewports are Vulkan-style signed-height (see `Viewport`). D3D12 takes a
// positive extent anchored at the top-left, so the flipped form
// {y = far edge, height < 0} becomes {y = y + height, height = -height}.

fn d3d12::Rect dx12_rect(std::math::geometry::Rect rect) @local
{
	return {
		.left = (int)rect.x,
		.top = (int)rect.y,
		.right = (int)(rect.x + rect.width),
		.bottom = (int)(rect.y + rect.height),
	};
}




// The signature for one draw argument layout, created on first use and owned
// by the device. Null when creation fails.
fn d3d12::CommandSignature* dx12_draw_signature(Device* device, bool indexed) @local
{
	DeviceDx12* state = &device.backend.dx12;
	d3d12::CommandSignature** slot = indexed ? &state.draw_indexed_signature : &state.draw_signature;
	if (*slot) return *slot;

	d3d12::IndirectArgumentDesc argument = {};
	argument.type = indexed ? d3d12::IndirectArgumentType.DRAW_INDEXED : d3d12::IndirectArgumentType.DRAW;
	d3d12::CommandSignatureDesc desc = {
		.byte_stride = indexed ? DX12_DRAW_INDEXED_ARGS_STRIDE : DX12_DRAW_ARGS_STRIDE,
		.num_argument_descs = 1,
		.argument_descs = &argument,
		.node_mask = 0,
	};
	d3d12::Device* dev = state.device;
	Guid iid = d3d12::IID_COMMAND_SIGNATURE;
	d3d12::CommandSignature* signature;
	if (dxgi::failed(dev.vtbl.create_command_signature(dev, &desc, null, &iid, (void**)&signature)) || !signature)
	{
		log::error("D3D12: failed to create draw command signature");
		return null;
	}
	*slot = signature;
	return signature;
}

// `count_buffer` is the ExecuteIndirect count buffer; it takes a uint32 at
// `count_offset` and runs min(count, max_draw_count) draws.





// Store ops need no work: D3D12 render targets are always written back.



// Append the barrier `before` -> `after` on `resource` (one subresource, or
// ALL_SUBRESOURCES) to `out`; nothing when the states need no ordering.
fn uint dx12_emit_barrier(d3d12::ResourceBarrier* out, d3d12::Resource* resource, uint subresource, d3d12::ResourceStates before, d3d12::ResourceStates after) @local
{
	switch (dx12_barrier_kind(before, after))
	{
		case NONE:
			return 0;
		case UAV:
			*out = {};
			out.type = d3d12::ResourceBarrierType.UAV;
			out.flags = d3d12::RESOURCE_BARRIER_FLAG_NONE;
			out.uav.resource = resource;
		case TRANSITION:
			*out = {};
			out.type = d3d12::ResourceBarrierType.TRANSITION;
			out.flags = d3d12::RESOURCE_BARRIER_FLAG_NONE;
			out.transition.resource = resource;
			out.transition.subresource = subresource;
			out.transition.state_before = before;
			out.transition.state_after = after;
	}
	return 1;
}

// True when the barrier covers every subresource of the image.
fn bool dx12_image_barrier_whole(ImageDx12* image, ImageBarrier barrier) @local
{
	if (barrier.base_mip != 0 || barrier.base_layer != 0) return false;
	if (barrier.mip_count != 0 && barrier.mip_count < image.mip_levels) return false;
	if (barrier.layer_count != 0 && barrier.layer_count < image.array_layers) return false;
	bool all_planes = format_get_props(image.format).is_stencil ? barrier.aspect == BarrierAspect.DEPTH_STENCIL : barrier.aspect != BarrierAspect.STENCIL;
	return all_planes || !format_get_props(image.format).is_depth;
}

// Memory barriers carry no resource: they become a UAV barrier on every
// resource when the translated state stays UAV/acceleration structure.
// Buffer barriers skip UPLOAD/READBACK heap buffers, whose state is fixed.
// Image barriers name the whole resource unless the range narrows it.

// Format used by a PLACED_FOOTPRINT: depth planes are copied as their
// shader-readable single-plane equivalents.
fn dxgi::Format dx12_copy_format(Format format, BarrierAspect aspect) @local
{
	if (!format_get_props(format).is_depth) return format_to_dxgi(format);
	if (aspect == BarrierAspect.STENCIL)
	{
		ViewDesc stencil_view = { .format = format, .aspect = STENCIL };
		return dx12_view_srv_format(stencil_view);
	}
	return format_to_dxgi_srv(format);
}

fn uint dx12_copy_subresource(ImageDx12* image, uint mip, uint layer, BarrierAspect aspect) @local
{
	uint plane = aspect == BarrierAspect.STENCIL ? 1 : 0;
	return mip + (layer + plane * image.array_layers) * image.mip_levels;
}

// One PLACED_FOOTPRINT copy per array layer between a buffer and an image
// subresource. `bytes_per_row` must be 256-aligned and `buffer_offset`
// 512-aligned (D3D12 requirements; see the option structs).
fn void dx12_copy_buffer_image(
	Cmd* cmd, Buffer* buffer, Image* img, bool to_texture,
	ulong buffer_offset, uint bytes_per_row, uint bytes_per_image,
	uint mip_level, uint base_layer, uint layer_count, BarrierAspect aspect,
	int x, int y, int z, uint width, uint height, uint depth) @local
{
	assert(buffer != null && img != null, "buffer-image copy requires a buffer and image");
	assert(buffer.backend.dx12.resource && img.backend.dx12.resource, "buffer-image copy resources must be initialized");
	assert(width > 0 && height > 0 && depth > 0, "buffer-image copy extent must be nonzero");
	assert(bytes_per_row % d3d12::TEXTURE_DATA_PITCH_ALIGNMENT == 0 && buffer_offset % d3d12::TEXTURE_DATA_PLACEMENT_ALIGNMENT == 0,
		"D3D12 buffer-image copies require 256-byte row pitch and 512-byte offset alignment");
	ImageDx12* image = &img.backend.dx12;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	if (layer_count == 0) layer_count = 1;
	if (bytes_per_image == 0) bytes_per_image = bytes_per_row * height;
	dxgi::Format format = dx12_copy_format(image.format, aspect);

	for (uint layer = 0; layer < layer_count; layer++)
	{
		d3d12::TextureCopyLocation texture = {};
		texture.resource = image.resource;
		texture.type = d3d12::TextureCopyType.SUBRESOURCE_INDEX;
		texture.subresource_index = dx12_copy_subresource(image, mip_level, base_layer + layer, aspect);

		d3d12::TextureCopyLocation placed = {};
		placed.resource = buffer.backend.dx12.resource;
		placed.type = d3d12::TextureCopyType.PLACED_FOOTPRINT;
		placed.placed_footprint.offset = buffer_offset + (ulong)layer * bytes_per_image;
		placed.placed_footprint.footprint = {
			.format = format,
			.width = width,
			.height = height,
			.depth = depth,
			.row_pitch = bytes_per_row,
		};

		if (to_texture)
		{
			d3d12::ResourceBox box = { .left = 0, .top = 0, .front = 0, .right = width, .bottom = height, .back = depth };
			list.vtbl.copy_texture_region(list, &texture, (uint)x, (uint)y, (uint)z, &placed, &box);
		}
		else
		{
			d3d12::ResourceBox box = {
				.left = (uint)x, .top = (uint)y, .front = (uint)z,
				.right = (uint)x + width, .bottom = (uint)y + height, .back = (uint)z + depth,
			};
			list.vtbl.copy_texture_region(list, &placed, 0, 0, 0, &texture, &box);
		}
	}
}





// ---- vulkan ----

// Vulkan command recording. Vulkan command section.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct CmdVk
{
	vk::CommandBuffer cmd;
}











fn void cmd_draw_indexed_indirect_count_vk(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	(void)device;
	vk::cmdDrawIndexedIndirectCount(cmd.backend.vk.cmd, buffer.backend.vk.buffer, offset, count_buffer.backend.vk.buffer, count_offset, max_draw_count, stride);
}




fn vk::AttachmentLoadOp vk_load_op(LoadOp op) @private
{
	switch (op)
	{
		case LOAD: return vk::AttachmentLoadOp.ATTACHMENT_LOAD_OP_LOAD;
		case CLEAR: return vk::AttachmentLoadOp.ATTACHMENT_LOAD_OP_CLEAR;
		case DONT_CARE: return vk::AttachmentLoadOp.ATTACHMENT_LOAD_OP_DONT_CARE;
	}
}

fn vk::AttachmentStoreOp vk_store_op(StoreOp op) @private
{
	switch (op)
	{
		case STORE: return vk::AttachmentStoreOp.ATTACHMENT_STORE_OP_STORE;
		case DONT_CARE: return vk::AttachmentStoreOp.ATTACHMENT_STORE_OP_DONT_CARE;
	}
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
	if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_UNDEFINED;
	if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_GENERAL;
	if ((state & VK_ATTACHMENT_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
	if (state.depth_write) return vk::ImageLayout.IMAGE_LAYOUT_DEPTH_ATTACHMENT_OPTIMAL;
	if (state.depth_read) return vk::ImageLayout.IMAGE_LAYOUT_DEPTH_READ_ONLY_OPTIMAL;
	if (state.shader_resource) return vk::ImageLayout.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
	if (state.copy_src) return vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
	if (state.copy_dst) return vk::ImageLayout.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
	if (state.present) return (vk::ImageLayout)1000001002;
	return vk::ImageLayout.IMAGE_LAYOUT_UNDEFINED;
}

fn vk::ImageLayout vk_resource_state_to_image_layout_aspect(ResourceState state, BarrierAspect aspect) @private
{
	if (aspect == STENCIL)
	{
		if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_UNDEFINED;
		if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_GENERAL;
		if (state.depth_write) return vk::ImageLayout.IMAGE_LAYOUT_STENCIL_ATTACHMENT_OPTIMAL;
		if (state.depth_read) return vk::ImageLayout.IMAGE_LAYOUT_STENCIL_READ_ONLY_OPTIMAL;
	}
	if (aspect == DEPTH_STENCIL)
	{
		if (state == VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_UNDEFINED;
		if ((state & VK_GENERAL_LAYOUT_STATES) != VK_RESOURCE_STATE_NONE) return vk::ImageLayout.IMAGE_LAYOUT_GENERAL;
		if (state.depth_write) return vk::ImageLayout.IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
		if (state.depth_read) return vk::ImageLayout.IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL;
	}
	return vk_resource_state_to_image_layout(state);
}

fn vk::AccessFlags2 vk_resource_state_to_access(ResourceState state) @private
{
	vk::AccessFlags2 access;
	if (state.general) access |= vk::AccessFlagBits2.ACCESS_2_SHADER_READ_BIT | vk::AccessFlagBits2.ACCESS_2_SHADER_WRITE_BIT;
	if (state.render_target) access |= vk::AccessFlagBits2.ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
	if (state.render_target_read) access |= vk::AccessFlagBits2.ACCESS_2_COLOR_ATTACHMENT_READ_BIT | vk::AccessFlagBits2.ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT;
	if (state.depth_write) access |= vk::AccessFlagBits2.ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT | vk::AccessFlagBits2.ACCESS_2_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;
	if (state.depth_read) access |= vk::AccessFlagBits2.ACCESS_2_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
	if (state.shader_resource) access |= vk::AccessFlagBits2.ACCESS_2_SHADER_SAMPLED_READ_BIT | vk::AccessFlagBits2.ACCESS_2_SHADER_READ_BIT;
	if (state.storage_read) access |= vk::AccessFlagBits2.ACCESS_2_SHADER_STORAGE_READ_BIT;
	if (state.storage_write) access |= vk::AccessFlagBits2.ACCESS_2_SHADER_STORAGE_WRITE_BIT;
	if (state.copy_src) access |= vk::AccessFlagBits2.ACCESS_2_TRANSFER_READ_BIT;
	if (state.copy_dst) access |= vk::AccessFlagBits2.ACCESS_2_TRANSFER_WRITE_BIT;
	if (state.indirect_argument) access |= vk::AccessFlagBits2.ACCESS_2_INDIRECT_COMMAND_READ_BIT;
	if (state.vertex_buffer) access |= vk::AccessFlagBits2.ACCESS_2_VERTEX_ATTRIBUTE_READ_BIT;
	if (state.index_buffer) access |= vk::AccessFlagBits2.ACCESS_2_INDEX_READ_BIT;
	if (state.constant_buffer) access |= vk::AccessFlagBits2.ACCESS_2_UNIFORM_READ_BIT;
	if (state.accel_read || state.accel_build_input) access |= vk::AccessFlagBits2.ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR;
	if (state.accel_write) access |= vk::AccessFlagBits2.ACCESS_2_ACCELERATION_STRUCTURE_WRITE_BIT_KHR;
	if (state.clear_storage) access |= vk::AccessFlagBits2.ACCESS_2_TRANSFER_WRITE_BIT;
	if (state.host_read) access |= vk::AccessFlagBits2.ACCESS_2_HOST_READ_BIT;
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
		result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
		result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
		result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
		if (caps.ray_tracing_pipeline_enabled) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
	}
	if (state.render_target || state.render_target_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (state.depth_write || state.depth_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
	if (state.copy_src || state.copy_dst) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COPY_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_BLIT_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_CLEAR_BIT;
	if (state.indirect_argument) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (state.vertex_buffer || state.index_buffer) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_VERTEX_INPUT_BIT;
	if ((state & VK_ACCEL_STATES) != VK_RESOURCE_STATE_NONE) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	if (state.clear_storage) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_CLEAR_BIT;
	if (state.host_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_HOST_BIT;
	return result;
}

fn VkStageMaskResult vk_stage_bits_to_vk(BarrierStages stages, ResourceState fallback, BarrierCapabilities caps) @private
{
	if (!vk_barrier_state_supported(fallback, caps)) return {};
	if (stages == VK_BARRIER_STAGES_NONE) return vk_stage_mask_from_state(fallback, caps);
	VkStageMaskResult result = { .ok = true };
	if (fallback.render_target || fallback.render_target_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (fallback.depth_write || fallback.depth_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_EARLY_FRAGMENT_TESTS_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_LATE_FRAGMENT_TESTS_BIT;
	if ((fallback.copy_src || fallback.copy_dst) && (stages.copy || stages.blit || stages.clear)) {
		// The explicit transfer hint supplies the fixed-function transfer stage.
	} else if (fallback.copy_src || fallback.copy_dst) {
		result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COPY_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_BLIT_BIT | vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_CLEAR_BIT;
	}
	if (fallback.clear_storage) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_CLEAR_BIT;
	if (fallback.indirect_argument) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (fallback.vertex_buffer || fallback.index_buffer) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_VERTEX_INPUT_BIT;
	if (fallback.host_read) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_HOST_BIT;
	if (stages.vertex) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
	if (stages.fragment) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
	if (stages.compute) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
	if (stages.ray_tracing)
	{
		BarrierStages non_ray = stages;
		non_ray.ray_tracing = false;
		bool raster_shader_stage = non_ray.vertex || non_ray.fragment || non_ray.compute;
		if (!caps.ray_tracing_pipeline_enabled && (non_ray == VK_BARRIER_STAGES_NONE || (!raster_shader_stage && (fallback & VK_SHADER_ACCESS_STATES) != VK_RESOURCE_STATE_NONE))) return {};
		if (caps.ray_tracing_pipeline_enabled) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
	}
	if (stages.draw_indirect) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (stages.copy) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COPY_BIT;
	if (stages.blit) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_BLIT_BIT;
	if (stages.clear) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_CLEAR_BIT;
	if (stages.accel_build)
	{
		if (!caps.acceleration_structure_enabled) return {};
		result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	}
	if (stages.color_attachment) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (stages.host) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_HOST_BIT;
	if (fallback.accel_write) result.mask |= vk::PipelineStageFlagBits2.PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	return result;
}

fn vk::ImageAspectFlags vk_barrier_aspect(BarrierAspect aspect) @private
{
	switch (aspect)
	{
		case COLOR: return vk::ImageAspectFlagBits.IMAGE_ASPECT_COLOR_BIT;
		case DEPTH: return vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT;
		case STENCIL: return vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
		case DEPTH_STENCIL: return vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT | vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
	}
}

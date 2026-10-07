// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral command buffer. Port of rhi-zig's `cmd.zig`: recording
// (`cmd_init`/`cmd_begin`/`cmd_end`, state, draws, barriers, copies) is
// dispatched to the Vulkan, Metal, WebGPU and WebGL2 backends. The command pool and
// ring types (`Pool`, `CommandRingElement`, `CommandRingBuffer`) live in
// pool.c3 and cmd_ring.c3.
module rhi;
import mtl;

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

struct Rect
{
	int x;
	int y;
	uint width;
	uint height;
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
	Rect rect;
}

fn Cmd? cmd_init(Device* device, Pool* pool)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				Cmd c = cmd_init_vk(device, pool)!;
				// The Vulkan device does not track ray-tracing pipeline or
				// acceleration-structure features yet, so both stay off and
				// ray-tracing stages drop out of derived barrier masks, as HPL2
				// does on a device without RT.
				c.barrier_capabilities = {};
				return c;
			$endif
		case DX12:
			$if HAS_DX12:
				return cmd_init_dx12(device, pool);
			$endif
		case MTL:
			$if HAS_MTL:
				return cmd_init_mtl(device, pool);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return cmd_init_wgpu(device, pool);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return cmd_init_webgl(device, pool);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void cmd_deinit(Cmd* c, Device* device, Pool* pool)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_deinit_vk(c, device, pool);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_deinit_dx12(c, device, pool);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_deinit_mtl(c, device, pool);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_deinit_wgpu(c, device, pool);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_deinit_webgl(c, device, pool);
			$endif
	}
}

fn void? cmd_begin(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return cmd_begin_vk(c, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return cmd_begin_dx12(c, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return cmd_begin_mtl(c, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return cmd_begin_wgpu(c, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return cmd_begin_webgl(c, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void? cmd_end(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return cmd_end_vk(c, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return cmd_end_dx12(c, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return cmd_end_mtl(c, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return cmd_end_wgpu(c, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return cmd_end_webgl(c, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void cmd_set_viewport(Cmd* c, Device* device, Viewport vp)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_set_viewport_vk(c, device, vp);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_set_viewport_dx12(c, device, vp);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_set_viewport_mtl(c, device, vp);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_set_viewport_wgpu(c, device, vp);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_set_viewport_webgl(c, device, vp);
			$endif
	}
}

fn void cmd_set_scissor(Cmd* c, Device* device, Rect rect)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_set_scissor_vk(c, device, rect);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_set_scissor_dx12(c, device, rect);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_set_scissor_mtl(c, device, rect);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_set_scissor_wgpu(c, device, rect);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_set_scissor_webgl(c, device, rect);
			$endif
	}
}

fn void cmd_draw(Cmd* c, Device* device, uint vertex_count, uint instance_count = 1, uint first_vertex = 0, uint first_instance = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_draw_vk(c, device, vertex_count, instance_count, first_vertex, first_instance);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_draw_dx12(c, device, vertex_count, instance_count, first_vertex, first_instance);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_draw_mtl(c, device, vertex_count, instance_count, first_vertex, first_instance);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_draw_wgpu(c, device, vertex_count, instance_count, first_vertex, first_instance);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_draw_webgl(c, device, vertex_count, instance_count, first_vertex, first_instance);
			$endif
	}
}

fn void cmd_draw_indexed(Cmd* c, Device* device, uint index_count, uint instance_count = 1, uint first_index = 0, int vertex_offset = 0, uint first_instance = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_draw_indexed_vk(c, device, index_count, instance_count, first_index, vertex_offset, first_instance);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_draw_indexed_dx12(c, device, index_count, instance_count, first_index, vertex_offset, first_instance);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_draw_indexed_mtl(c, device, index_count, instance_count, first_index, vertex_offset, first_instance);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_draw_indexed_wgpu(c, device, index_count, instance_count, first_index, vertex_offset, first_instance);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_draw_indexed_webgl(c, device, index_count, instance_count, first_index, vertex_offset, first_instance);
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
				cmd_draw_indirect_vk(c, device, buffer, offset, draw_count, stride);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_draw_indirect_dx12(c, device, buffer, offset, draw_count, stride);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_draw_indirect_mtl(c, device, buffer, offset, draw_count, stride);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_draw_indirect_wgpu(c, device, buffer, offset, draw_count, stride);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_draw_indirect_webgl(c, device, buffer, offset, draw_count, stride);
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
				cmd_draw_indexed_indirect_vk(c, device, buffer, offset, draw_count, stride);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_draw_indexed_indirect_dx12(c, device, buffer, offset, draw_count, stride);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_draw_indexed_indirect_mtl(c, device, buffer, offset, draw_count, stride);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_draw_indexed_indirect_wgpu(c, device, buffer, offset, draw_count, stride);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_draw_indexed_indirect_webgl(c, device, buffer, offset, draw_count, stride);
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
				cmd_draw_indirect_count_vk(c, device, buffer, offset, count_buffer, count_offset, max_draw_count, stride);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_draw_indirect_count_dx12(c, device, buffer, offset, count_buffer, count_offset, max_draw_count, stride);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_draw_indirect_count_mtl(c, device, buffer, offset, count_buffer, count_offset, max_draw_count, stride);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_draw_indirect_count_wgpu(c, device, buffer, offset, count_buffer, count_offset, max_draw_count, stride);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_draw_indirect_count_webgl(c, device, buffer, offset, count_buffer, count_offset, max_draw_count, stride);
			$endif
	}
}

fn void cmd_bind_pipeline(Cmd* c, Device* device, Pipeline* pipeline)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_bind_pipeline_vk(c, device, pipeline);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_bind_pipeline_dx12(c, device, pipeline);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_bind_pipeline_mtl(c, device, pipeline);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_bind_pipeline_wgpu(c, device, pipeline);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_bind_pipeline_webgl(c, device, pipeline);
			$endif
	}
}

fn void cmd_set_push_constants(Cmd* c, Device* device, Pipeline* pipeline, char[] bytes)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_set_push_constants_vk(c, device, pipeline, bytes);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_set_push_constants_dx12(c, device, pipeline, bytes);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_set_push_constants_mtl(c, device, pipeline, bytes);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_set_push_constants_wgpu(c, device, pipeline, bytes);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_set_push_constants_webgl(c, device, pipeline, bytes);
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
				cmd_clear_attachment_regions_vk(c, device, regions);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_clear_attachment_regions_dx12(c, device, regions);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_clear_attachment_regions_mtl(c, device, regions);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_clear_attachment_regions_wgpu(c, device, regions);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_clear_attachment_regions_webgl(c, device, regions);
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
				if (c == null || pipeline == null) return;
				CmdMtl* state = &c.backend.mtl;
				if (!state.render_encoder)
				{
					log::error("Metal: descriptor binding requires an active render pass");
					return;
				}
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
				return cmd_bind_descriptors_wgpu(c, device, pipeline, bindings);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return cmd_bind_descriptors_webgl(c, device, pipeline, bindings);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
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
	Rect render_area;
	CmdDepthAttachment depth_attachment;
	bool has_depth_attachment;
}

fn void cmd_begin_rendering(Cmd* c, Device* device, CmdBeginRenderingOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_begin_rendering_vk(c, device, options);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_begin_rendering_dx12(c, device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_begin_rendering_mtl(c, device, options);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_begin_rendering_wgpu(c, device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_begin_rendering_webgl(c, device, options);
			$endif
	}
}

fn void cmd_end_rendering(Cmd* c, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_end_rendering_vk(c, device);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_end_rendering_dx12(c, device);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_end_rendering_mtl(c, device);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_end_rendering_wgpu(c, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_end_rendering_webgl(c, device);
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
fn void cmd_bind_vertex_buffers(Cmd* c, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets = {})
{
	assert(offsets.ptr == null || offsets.len == buffers.len);
	if (buffers.len == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_bind_vertex_buffers_vk(c, device, first_binding, buffers, offsets);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_bind_vertex_buffers_dx12(c, device, first_binding, buffers, offsets);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_bind_vertex_buffers_mtl(c, device, first_binding, buffers, offsets);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_bind_vertex_buffers_wgpu(c, device, first_binding, buffers, offsets);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_bind_vertex_buffers_webgl(c, device, first_binding, buffers, offsets);
			$endif
	}
}

fn void cmd_bind_index_buffer(Cmd* c, Device* device, Buffer* buffer, IndexType index_type, ulong offset = 0)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_bind_index_buffer_vk(c, device, buffer, index_type, offset);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_bind_index_buffer_dx12(c, device, buffer, index_type, offset);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_bind_index_buffer_mtl(c, device, buffer, index_type, offset);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_bind_index_buffer_wgpu(c, device, buffer, index_type, offset);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_bind_index_buffer_webgl(c, device, buffer, index_type, offset);
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
				cmd_resource_barrier_vk(c, device, memory, buffers, images);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_resource_barrier_dx12(c, device, memory, buffers, images);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_resource_barrier_mtl(c, device, memory, buffers, images);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_resource_barrier_wgpu(c, device, memory, buffers, images);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_resource_barrier_webgl(c, device, memory, buffers, images);
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
				cmd_copy_buffer_to_texture_vk(c, device, options);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_copy_buffer_to_texture_dx12(c, device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_copy_buffer_to_texture_mtl(c, device, options);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_copy_buffer_to_texture_wgpu(c, device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_copy_buffer_to_texture_webgl(c, device, options);
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
				cmd_copy_texture_to_buffer_vk(c, device, options);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_copy_texture_to_buffer_dx12(c, device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_copy_texture_to_buffer_mtl(c, device, options);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_copy_texture_to_buffer_wgpu(c, device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_copy_texture_to_buffer_webgl(c, device, options);
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
				cmd_copy_buffer_vk(c, device, src, src_offset, dst, dst_offset, size);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_copy_buffer_dx12(c, device, src, src_offset, dst, dst_offset, size);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_copy_buffer_mtl(c, device, src, src_offset, dst, dst_offset, size);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_copy_buffer_wgpu(c, device, src, src_offset, dst, dst_offset, size);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_copy_buffer_webgl(c, device, src, src_offset, dst, dst_offset, size);
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
				cmd_copy_image_vk(c, device, src, dst, d);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_copy_image_dx12(c, device, src, dst, d);
			$endif
		case MTL:
			$if HAS_MTL:
				cmd_copy_image_mtl(c, device, src, dst, d);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				cmd_copy_image_wgpu(c, device, src, dst, d);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				cmd_copy_image_webgl(c, device, src, dst, d);
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

fn Cmd? cmd_init_dx12(Device* device, Pool* pool)
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

fn void cmd_deinit_dx12(Cmd* cmd, Device* device, Pool* pool)
{
	(void)device;
	(void)pool;
	CmdDx12* state = &cmd.backend.dx12;
	if (state.list) dxgi::release(state.list);
	*state = {};
}

fn void? cmd_begin_dx12(Cmd* cmd, Device* device)
{
	(void)device;
	CmdDx12* state = &cmd.backend.dx12;
	if (!state.list || !state.allocator) return UNKNOWN~;
	dx12_check(state.list.vtbl.reset(state.list, state.allocator, null))!;
	state.rtv_count = 0;
	state.has_dsv = false;
	state.vertex_stride = 0;
}

fn void? cmd_end_dx12(Cmd* cmd, Device* device)
{
	(void)device;
	CmdDx12* state = &cmd.backend.dx12;
	if (!state.list) return UNKNOWN~;
	dx12_check(state.list.vtbl.close(state.list))!;
}

// RI viewports are Vulkan-style signed-height (see `Viewport`). D3D12 takes a
// positive extent anchored at the top-left, so the flipped form
// {y = far edge, height < 0} becomes {y = y + height, height = -height}.
fn void cmd_set_viewport_dx12(Cmd* cmd, Device* device, Viewport viewport)
{
	(void)device;
	if (viewport.origin_bottom_left)
	{
		log::error("D3D12: bottom-left origin viewports are not supported");
		return;
	}
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

fn d3d12::Rect dx12_rect(Rect rect) @local
{
	return {
		.left = rect.x,
		.top = rect.y,
		.right = rect.x + (int)rect.width,
		.bottom = rect.y + (int)rect.height,
	};
}

fn void cmd_set_scissor_dx12(Cmd* cmd, Device* device, Rect rect)
{
	(void)device;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	d3d12::Rect scissor = dx12_rect(rect);
	list.vtbl.rs_set_scissor_rects(list, 1, &scissor);
}

fn void cmd_draw_dx12(Cmd* cmd, Device* device, uint vertex_count, uint instance_count, uint first_vertex, uint first_instance)
{
	(void)device;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	list.vtbl.draw_instanced(list, vertex_count, instance_count, first_vertex, first_instance);
}

fn void cmd_draw_indexed_dx12(Cmd* cmd, Device* device, uint index_count, uint instance_count, uint first_index, int vertex_offset, uint first_instance)
{
	(void)device;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	list.vtbl.draw_indexed_instanced(list, index_count, instance_count, first_index, vertex_offset, first_instance);
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

// ExecuteIndirect walks the argument buffer at the signature's fixed stride; a
// caller stride that differs is honoured by issuing one draw at a time.
fn void dx12_draw_indirect(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride, bool indexed) @local
{
	if (buffer == null || !buffer.backend.dx12.resource || draw_count == 0) return;
	d3d12::CommandSignature* signature = dx12_draw_signature(device, indexed);
	if (!signature) return;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	uint natural = indexed ? DX12_DRAW_INDEXED_ARGS_STRIDE : DX12_DRAW_ARGS_STRIDE;
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

fn void cmd_draw_indirect_dx12(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	dx12_draw_indirect(cmd, device, buffer, offset, draw_count, stride, false);
}

fn void cmd_draw_indexed_indirect_dx12(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride)
{
	dx12_draw_indirect(cmd, device, buffer, offset, draw_count, stride, true);
}

// `count_buffer` is the ExecuteIndirect count buffer; it takes a uint32 at
// `count_offset` and runs min(count, max_draw_count) draws.
fn void cmd_draw_indirect_count_dx12(Cmd* cmd, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride)
{
	if (buffer == null || count_buffer == null || !buffer.backend.dx12.resource || !count_buffer.backend.dx12.resource || max_draw_count == 0) return;
	if (stride != 0 && stride != DX12_DRAW_ARGS_STRIDE)
	{
		log::error("D3D12: indirect-count draw requires tightly packed draw arguments; draw dropped");
		return;
	}
	d3d12::CommandSignature* signature = dx12_draw_signature(device, false);
	if (!signature) return;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	list.vtbl.execute_indirect(list, signature, max_draw_count, buffer.backend.dx12.resource, offset, count_buffer.backend.dx12.resource, count_offset);
}

fn void cmd_bind_pipeline_dx12(Cmd* cmd, Device* device, Pipeline* pipeline)
{
	(void)device;
	if (pipeline == null || !pipeline.backend.dx12.state) return;
	CmdDx12* state = &cmd.backend.dx12;
	PipelineDx12* p = &pipeline.backend.dx12;
	d3d12::GraphicsCommandList* list = state.list;
	list.vtbl.set_pipeline_state(list, p.state);
	list.vtbl.set_graphics_root_signature(list, p.root_signature);
	list.vtbl.ia_set_primitive_topology(list, p.topology);
	state.vertex_stride = p.vertex_stride;
}

fn void cmd_set_push_constants_dx12(Cmd* cmd, Device* device, Pipeline* pipeline, char[] bytes)
{
	(void)device;
	if (pipeline == null || bytes.len == 0) return;
	PipelineDx12* p = &pipeline.backend.dx12;
	if (p.push_constant_param == uint::max) return;
	if (bytes.len > p.push_constant_size)
	{
		log::error("D3D12: push constant data exceeds pipeline limit");
		return;
	}
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	// Root constants are whole 32-bit values; zero-pad a ragged tail.
	uint count = ((uint)bytes.len + 3) / 4;
	uint[] values = mem::talloc_array(uint, count);
	mem::clear(values.ptr, (usz)count * 4);
	mem::copy(values.ptr, bytes.ptr, bytes.len);
	list.vtbl.set_graphics_root_32bit_constants(list, p.push_constant_param, count, values.ptr, 0);
}

fn void cmd_clear_attachment_regions_dx12(Cmd* cmd, Device* device, CmdClearRegion[] regions)
{
	(void)device;
	CmdDx12* state = &cmd.backend.dx12;
	if (state.rtv_count == 0) return;
	d3d12::GraphicsCommandList* list = state.list;
	// Like Vulkan, only color attachment 0 is cleared.
	foreach (region : regions)
	{
		float[4] color = region.color;
		d3d12::Rect rect = dx12_rect(region.rect);
		list.vtbl.clear_render_target_view(list, state.rtvs[0], &color, 1, &rect);
	}
}

fn void cmd_begin_rendering_dx12(Cmd* cmd, Device* device, CmdBeginRenderingOptions options)
{
	(void)device;
	assert(options.color_attachments.len <= DX12_MAX_RENDER_TARGETS);
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

// Store ops need no work: D3D12 render targets are always written back.
fn void cmd_end_rendering_dx12(Cmd* cmd, Device* device)
{
	(void)device;
	CmdDx12* state = &cmd.backend.dx12;
	state.rtv_count = 0;
	state.has_dsv = false;
}

fn void cmd_bind_vertex_buffers_dx12(Cmd* cmd, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets)
{
	(void)device;
	assert(offsets.ptr == null || offsets.len == buffers.len);
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

fn void cmd_bind_index_buffer_dx12(Cmd* cmd, Device* device, Buffer* buffer, IndexType index_type, ulong offset)
{
	(void)device;
	if (buffer == null || !buffer.backend.dx12.resource) return;
	BufferDx12* b = &buffer.backend.dx12;
	if (offset > b.size) return;
	d3d12::IndexBufferView view = {
		.buffer_location = b.gpu_address + offset,
		.size_in_bytes = (uint)(b.size - offset),
		.format = index_type == IndexType.UINT16 ? dxgi::Format.R16_UINT : dxgi::Format.R32_UINT,
	};
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	list.vtbl.ia_set_index_buffer(list, &view);
}

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

// Plane 0 is depth (or color), plane 1 the stencil of a depth-stencil format.
fn uint dx12_barrier_plane_mask(Format format, BarrierAspect aspect) @local
{
	bool stencil = format_get_props(format).is_stencil;
	switch (aspect)
	{
		case STENCIL: return 0b10;
		case DEPTH_STENCIL: return stencil ? 0b11 : 0b01;
		default: return 0b01;
	}
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
fn void cmd_resource_barrier_dx12(Cmd* cmd, Device* device, MemoryBarrier[] memory, BufferBarrier[] buffers, ImageBarrier[] images)
{
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
		uint planes = dx12_barrier_plane_mask(image.format, b.aspect);
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
	if (buffer == null || img == null || !buffer.backend.dx12.resource || !img.backend.dx12.resource) return;
	if (width == 0 || height == 0 || depth == 0) return;
	if (bytes_per_row % d3d12::TEXTURE_DATA_PITCH_ALIGNMENT != 0 || buffer_offset % d3d12::TEXTURE_DATA_PLACEMENT_ALIGNMENT != 0)
	{
		log::error("D3D12: buffer/texture copy needs 256-byte row pitch and 512-byte offset alignment; copy dropped");
		return;
	}
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

fn void cmd_copy_buffer_to_texture_dx12(Cmd* cmd, Device* device, CmdCopyBufferToTextureOptions options)
{
	(void)device;
	dx12_copy_buffer_image(
		cmd, options.src, options.dst, true,
		options.buffer_offset, options.bytes_per_row, options.bytes_per_image,
		options.mip_level, options.base_array_layer, options.layer_count, options.aspect,
		options.x, options.y, options.z, options.width, options.height, options.depth);
}

fn void cmd_copy_texture_to_buffer_dx12(Cmd* cmd, Device* device, CmdCopyTextureToBufferOptions options)
{
	(void)device;
	dx12_copy_buffer_image(
		cmd, options.dst, options.src, false,
		options.buffer_offset, options.bytes_per_row, options.bytes_per_image,
		options.mip_level, options.base_array_layer, options.layer_count, options.aspect,
		options.x, options.y, options.z, options.width, options.height, options.depth);
}

fn void cmd_copy_buffer_dx12(Cmd* cmd, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size)
{
	(void)device;
	if (src == null || dst == null || !src.backend.dx12.resource || !dst.backend.dx12.resource) return;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	list.vtbl.copy_buffer_region(list, dst.backend.dx12.resource, dst_offset, src.backend.dx12.resource, src_offset, size);
}

fn void cmd_copy_image_dx12(Cmd* cmd, Device* device, Image* src, Image* dst, ImageCopyDesc desc)
{
	(void)device;
	if (src == null || dst == null || !src.backend.dx12.resource || !dst.backend.dx12.resource) return;
	ImageDx12* s = &src.backend.dx12;
	ImageDx12* d = &dst.backend.dx12;
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;

	d3d12::TextureCopyLocation src_loc = {};
	src_loc.resource = s.resource;
	src_loc.type = d3d12::TextureCopyType.SUBRESOURCE_INDEX;
	src_loc.subresource_index = dx12_copy_subresource(s, desc.src_mip_level, desc.src_array_layer, BarrierAspect.COLOR);
	d3d12::TextureCopyLocation dst_loc = {};
	dst_loc.resource = d.resource;
	dst_loc.type = d3d12::TextureCopyType.SUBRESOURCE_INDEX;
	dst_loc.subresource_index = dx12_copy_subresource(d, desc.dst_mip_level, desc.dst_array_layer, BarrierAspect.COLOR);

	// A copy of the whole source subresource passes no box (required for
	// depth-stencil and multisampled resources).
	uint mip_width = s.width >> desc.src_mip_level;
	uint mip_height = s.height >> desc.src_mip_level;
	uint mip_depth = s.depth >> desc.src_mip_level;
	if (mip_width == 0) mip_width = 1;
	if (mip_height == 0) mip_height = 1;
	if (mip_depth == 0) mip_depth = 1;
	bool whole = desc.src_x == 0 && desc.src_y == 0 && desc.src_z == 0
		&& desc.width == mip_width && desc.height == mip_height && desc.depth == mip_depth;
	d3d12::ResourceBox box = {
		.left = (uint)desc.src_x, .top = (uint)desc.src_y, .front = (uint)desc.src_z,
		.right = (uint)desc.src_x + desc.width, .bottom = (uint)desc.src_y + desc.height, .back = (uint)desc.src_z + desc.depth,
	};
	list.vtbl.copy_texture_region(list, &dst_loc, (uint)desc.dst_x, (uint)desc.dst_y, (uint)desc.dst_z, &src_loc, whole ? null : &box);
}

// ---- vulkan ----

// Vulkan command recording. Vulkan command section.
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

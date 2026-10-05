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
// fields by name. Odin has no field defaults, so `depth == 0` is read as 1 and
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

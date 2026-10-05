// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// WebGPU backend.  The browser half is deliberately a scalar ABI: WebGPU
// objects are indices into the handle table in glue.js, and strings/arrays
// cross wasm as (pointer, length) pairs.  Keep the import names and enum
// ordinals in lockstep with src/webgpu.zig and src/webgpu/enums.zig.
module rhi @feat(RHI_WGPU & !RHI_HEADLESS & WASM);
import std::collections::list;

// ---- glue ABI -------------------------------------------------------------

extern fn uint wgpu_adapter_get() @wasm("wgpu", "wgpu_adapter_get");
extern fn uint wgpu_device_get() @wasm("wgpu", "wgpu_device_get");
extern fn uint wgpu_device_get_queue(uint device) @wasm("wgpu", "wgpu_device_get_queue");
extern fn uint wgpu_adapter_name(uint adapter, char* ptr, uint len) @wasm("wgpu", "wgpu_adapter_name");
extern fn uint wgpu_adapter_vendor_id(uint adapter) @wasm("wgpu", "wgpu_adapter_vendor_id");
extern fn uint wgpu_adapter_device_id(uint adapter) @wasm("wgpu", "wgpu_adapter_device_id");
extern fn uint wgpu_adapter_type(uint adapter) @wasm("wgpu", "wgpu_adapter_type");
extern fn uint wgpu_adapter_limit(uint adapter, char* ptr, uint len) @wasm("wgpu", "wgpu_adapter_limit");
extern fn void wgpu_release(uint handle) @wasm("wgpu", "wgpu_release");

extern fn uint wgpu_surface_create(char* ptr, uint len) @wasm("wgpu", "wgpu_surface_create");
extern fn uint wgpu_surface_preferred_format() @wasm("wgpu", "wgpu_surface_preferred_format");
extern fn void wgpu_surface_configure(uint surface, uint device, uint format, uint width, uint height) @wasm("wgpu", "wgpu_surface_configure");
extern fn uint wgpu_surface_get_current_texture(uint surface) @wasm("wgpu", "wgpu_surface_get_current_texture");

extern fn uint wgpu_device_create_texture(uint device, uint format, uint width, uint height, uint depth_or_layers, uint mip_levels, uint samples, uint dimension, uint usage) @wasm("wgpu", "wgpu_device_create_texture");
extern fn void wgpu_queue_write_texture(uint queue, uint texture, uint mip, uint x, uint y, uint z, uint width, uint height, uint depth, char* ptr, uint len, uint bytes_per_row, uint rows_per_image) @wasm("wgpu", "wgpu_queue_write_texture");
extern fn uint wgpu_texture_create_view(uint texture, uint format, uint dimension, uint aspect, uint base_mip, uint mip_count, uint base_layer, uint layer_count) @wasm("wgpu", "wgpu_texture_create_view");

extern fn uint wgpu_device_create_buffer(uint device, uint size, uint usage) @wasm("wgpu", "wgpu_device_create_buffer");
extern fn void wgpu_queue_write_buffer(uint queue, uint buffer, uint offset, char* ptr, uint len) @wasm("wgpu", "wgpu_queue_write_buffer");
extern fn uint wgpu_device_create_shader_module(uint device, char* ptr, uint len) @wasm("wgpu", "wgpu_device_create_shader_module");
extern fn uint wgpu_device_create_render_pipeline(uint device, uint vs, char* vs_entry, uint vs_len, uint fs, char* fs_entry, uint fs_len, uint color_format, uint depth_format, uint topology, uint cull, uint front, uint depth_write, uint depth_compare, uint stride, uint* attrs, uint attrs_len, uint blend_enable, uint src_color, uint dst_color, uint color_op, uint src_alpha, uint dst_alpha, uint alpha_op, uint write_mask) @wasm("wgpu", "wgpu_device_create_render_pipeline");
extern fn uint wgpu_device_create_sampler(uint device, uint mag, uint min, uint mip, uint address_u, uint address_v, uint address_w, float lod_min, float lod_max, uint anisotropy) @wasm("wgpu", "wgpu_device_create_sampler");
extern fn uint wgpu_device_create_bind_group_textures(uint device, uint layout, uint* entries, uint entries_len) @wasm("wgpu", "wgpu_device_create_bind_group_textures");
extern fn uint wgpu_render_pipeline_get_bind_group_layout(uint pipeline, uint index) @wasm("wgpu", "wgpu_render_pipeline_get_bind_group_layout");
extern fn uint wgpu_device_create_bind_group_uniform(uint device, uint layout, uint buffer, uint offset, uint size) @wasm("wgpu", "wgpu_device_create_bind_group_uniform");

extern fn uint wgpu_device_create_command_encoder(uint device) @wasm("wgpu", "wgpu_device_create_command_encoder");
extern fn uint wgpu_command_encoder_begin_render_pass(uint encoder, uint color_view, uint color_load, uint color_store, float clear_r, float clear_g, float clear_b, float clear_a, uint depth_view, uint depth_load, uint depth_store, float clear_depth) @wasm("wgpu", "wgpu_command_encoder_begin_render_pass");
extern fn void wgpu_command_encoder_copy_buffer_to_buffer(uint encoder, uint src, uint src_offset, uint dst, uint dst_offset, uint size) @wasm("wgpu", "wgpu_command_encoder_copy_buffer_to_buffer");
extern fn uint wgpu_command_encoder_finish(uint encoder) @wasm("wgpu", "wgpu_command_encoder_finish");
extern fn void wgpu_render_pass_set_viewport(uint pass, float x, float y, float width, float height, float min_depth, float max_depth) @wasm("wgpu", "wgpu_render_pass_set_viewport");
extern fn void wgpu_render_pass_set_scissor_rect(uint pass, uint x, uint y, uint width, uint height) @wasm("wgpu", "wgpu_render_pass_set_scissor_rect");
extern fn void wgpu_render_pass_set_pipeline(uint pass, uint pipeline) @wasm("wgpu", "wgpu_render_pass_set_pipeline");
extern fn void wgpu_render_pass_set_bind_group(uint pass, uint index, uint bind_group) @wasm("wgpu", "wgpu_render_pass_set_bind_group");
extern fn void wgpu_render_pass_set_vertex_buffer(uint pass, uint slot, uint buffer, uint offset) @wasm("wgpu", "wgpu_render_pass_set_vertex_buffer");
extern fn void wgpu_render_pass_set_index_buffer(uint pass, uint buffer, uint format, uint offset) @wasm("wgpu", "wgpu_render_pass_set_index_buffer");
extern fn void wgpu_render_pass_draw(uint pass, uint vertices, uint instances, uint first_vertex, uint first_instance) @wasm("wgpu", "wgpu_render_pass_draw");
extern fn void wgpu_render_pass_draw_indexed(uint pass, uint indices, uint instances, uint first_index, int base_vertex, uint first_instance) @wasm("wgpu", "wgpu_render_pass_draw_indexed");
extern fn void wgpu_render_pass_end(uint pass) @wasm("wgpu", "wgpu_render_pass_end");
extern fn void wgpu_queue_submit(uint queue, uint* commands, uint count) @wasm("wgpu", "wgpu_queue_submit");
extern fn void wgpu_queue_on_submitted_work_done(uint queue, uint* out_value, uint lo, uint hi) @wasm("wgpu", "wgpu_queue_on_submitted_work_done");
extern fn void wgpu_log(uint level, char* ptr, uint len) @wasm("wgpu", "wgpu_log");

const WGPU_BUFFER_MAP_READ = 0x001;
const WGPU_BUFFER_MAP_WRITE = 0x002;
const WGPU_BUFFER_COPY_SRC = 0x004;
const WGPU_BUFFER_COPY_DST = 0x008;
const WGPU_BUFFER_INDEX = 0x010;
const WGPU_BUFFER_VERTEX = 0x020;
const WGPU_BUFFER_UNIFORM = 0x040;
const WGPU_BUFFER_STORAGE = 0x080;
const WGPU_BUFFER_INDIRECT = 0x100;
const WGPU_TEXTURE_COPY_SRC = 0x01;
const WGPU_TEXTURE_COPY_DST = 0x02;
const WGPU_TEXTURE_BINDING = 0x04;
const WGPU_TEXTURE_STORAGE = 0x08;
const WGPU_TEXTURE_RENDER = 0x10;

fn void wgpu_release_if(uint* handle)
{
	if (*handle != 0) wgpu_release(*handle);
	*handle = 0;
}

fn void wgpu_log_text(String message)
{
	if (message.len > 0) wgpu_log(1, message.ptr, (uint)message.len);
}

// ---- payloads -------------------------------------------------------------

struct RendererWgpu { uint adapter; }
struct PhysicalAdapterWgpu { uint adapter; }
struct DeviceWgpu { uint device; uint queue; }
struct QueueWgpu { uint queue; }
struct TimelineWgpu { uint[2] completed_value; }
struct PoolWgpu { char _unused; }
struct CmdWgpu
{
	uint device;
	uint encoder;
	uint pass;
	uint command_buffer;
	uint pipeline;
	uint index_format;
	uint texture_bind_group;
	uint push_constant_group;
}
struct CommandRingElementWgpu { char _unused; }
struct CommandRingBufferWgpu <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { char _unused; }
struct BufferWgpu { uint buffer; ulong size; uint usage; }
struct ImageWgpu
{
	uint texture;
	Format format;
	ImageType image_type;
	uint width, height, depth, mip_levels, array_layers;
}
struct ImageViewWgpu { uint view; }
struct SamplerWgpu { uint sampler; }
struct ShaderWgpu
{
	uint vertex_module;
	uint fragment_module;
	String vertex_entry;
	String fragment_entry;
	ShaderStages stages;
}
struct PipelineWgpu
{
	uint pipeline;
	uint texture_layout;
	uint uniform_layout;
	uint push_constant_buffer;
	uint push_constant_group;
	TextureSlot[MAX_TEXTURE_BINDINGS] texture_slots;
	uint texture_slot_count;
	uint push_constant_size;
}
struct SwapchainWgpu
{
	uint surface;
	uint current_texture;
	uint current_view;
	WgpuTextureFormat format;
	Format color_format;
}

// ---- renderer / adapter / device / queue ---------------------------------

fn void? renderer_init_wgpu(RendererWgpuOptions opts, Allocator allocator = mem)
{
	uint adapter = wgpu_adapter_get();
	if (adapter == 0) return INITIALIZATION_FAILED~;
	renderer = { .backend = WGPU, .wgpu = { .adapter = adapter } };
}

fn void renderer_deinit_wgpu()
{
	wgpu_release_if(&renderer.wgpu.adapter);
	renderer = {};
}

fn List{PhysicalAdapter}? enumerate_adapters_wgpu(Allocator allocator = mem)
{
	List{PhysicalAdapter} adapters;
	adapters.init(allocator, 0);
	uint adapter = renderer.wgpu.adapter;
	if (adapter == 0) return INITIALIZATION_FAILED~;
	PhysicalAdapter a = physical_adapter_web_defaults();
	a.backend.wgpu = { .adapter = adapter };
	char[256] name;
	uint name_len = wgpu_adapter_name(adapter, &name[0], (uint)name.len);
	if (name_len > name.len) name_len = (uint)name.len;
	physical_adapter_set_name(&a, (String)name[:name_len]);
	a.device_id = wgpu_adapter_device_id(adapter);
	a.vendor = vendor_from_id(wgpu_adapter_vendor_id(adapter));
	switch (wgpu_adapter_type(adapter))
	{
		case 0: a.adapter_type = DISCRETE;
		case 1: a.adapter_type = INTEGRATED;
		case 2: a.adapter_type = CPU;
		default: a.adapter_type = OTHER;
	}
	a.preset_level = HIGH;
	// These are the limits used by the WebGPU bridge.  Unknown limits return 0.
	a.buffer_max_size = wgpu_limit(adapter, "maxBufferSize", 0xFFFFFFFF);
	a.texture_1d_max_dim = (ushort)wgpu_limit(adapter, "maxTextureDimension1D", 8192);
	a.texture_2d_max_dim = (ushort)wgpu_limit(adapter, "maxTextureDimension2D", 8192);
	a.texture_3d_max_dim = (ushort)wgpu_limit(adapter, "maxTextureDimension3D", 2048);
	a.texture_array_layer_max_num = (ushort)wgpu_limit(adapter, "maxTextureArrayLayers", 256);
	a.vertex_shader_attribute_max_num = wgpu_limit(adapter, "maxVertexAttributes", 16);
	a.vertex_shader_stream_max_num = wgpu_limit(adapter, "maxVertexBuffers", 8);
	a.color_attachment_max_num = wgpu_limit(adapter, "maxColorAttachments", 8);
	a.fragment_shader_output_attachment_max_num = a.color_attachment_max_num;
	a.constant_buffer_offset_alignment = wgpu_limit(adapter, "minUniformBufferOffsetAlignment", 256);
	a.sampler_anisotropy_max = 16;
	a.is_shader_native_f32_supported = true;
	a.is_draw_indirect_count_supported = false;
	adapters.push(a);
	return adapters;
}

fn uint wgpu_limit(uint adapter, String key, uint fallback)
{
	uint value = wgpu_adapter_limit(adapter, key.ptr, (uint)key.len);
	return value == 0 ? fallback : value;
}

fn Device? device_init_wgpu(PhysicalAdapter* adapter, Allocator allocator = mem)
{
	if (adapter == null || adapter.backend.wgpu.adapter == 0) return INITIALIZATION_FAILED~;
	uint device = wgpu_device_get();
	uint queue = wgpu_device_get_queue(device);
	if (device == 0 || queue == 0) return INITIALIZATION_FAILED~;
	return {
		.graphics_queue = { .backend.wgpu = { .queue = queue } },
		.adapter = *adapter,
		.allocator = allocator,
		.backend.wgpu = { .device = device, .queue = queue },
	};
}

fn void device_deinit_wgpu(Device* d)
{
	if (d == null) return;
	wgpu_release_if(&d.backend.wgpu.queue);
	wgpu_release_if(&d.backend.wgpu.device);
	d.graphics_queue.backend.wgpu = {};
	d = null;
}

fn void? queue_wait_idle_wgpu(Queue* q, Device* device)
{
	if (q == null || q.backend.wgpu.queue == 0) return UNKNOWN~;
	return;
}

fn void? queue_submit_wgpu(Queue* q, Device* device, QueueSubmitDesc desc)
{
	if (q == null || q.backend.wgpu.queue == 0) return UNKNOWN~;
	if (desc.binary_waits.len != 0 || desc.binary_signals.len != 0) return UNSUPPORTED_FEATURE~;
	if (desc.waits.len != 0) return UNSUPPORTED_FEATURE~;
	if (desc.cmds.len == 0) return;
	uint[64] handles;
	if (desc.cmds.len > handles.len) return UNSUPPORTED_FEATURE~;
	foreach (i, c : desc.cmds)
	{
		if (c == null || c.backend.wgpu.command_buffer == 0) return UNKNOWN~;
		handles[i] = c.backend.wgpu.command_buffer;
	}
	wgpu_queue_submit(q.backend.wgpu.queue, &handles[0], (uint)desc.cmds.len);
	foreach (op : desc.signals)
	{
		if (op.timeline == null) continue;
		uint lo = (uint)op.value;
		uint hi = (uint)(op.value >> 32);
		wgpu_queue_on_submitted_work_done(q.backend.wgpu.queue, &op.timeline.backend.wgpu.completed_value[0], lo, hi);
	}
	if (desc.completion != null) command_ring_element_wait_wgpu(desc.completion, device)!;
	return;
}

// ---- pool / command ring --------------------------------------------------

fn Pool? pool_init_wgpu(Device* device, Queue* queue) { return { .backend.wgpu = {} }; }
fn void? pool_reset_wgpu(Pool* p, Device* device) { return; }
fn void pool_deinit_wgpu(Pool* p, Device* device) {}

fn void? command_ring_element_wait_wgpu(CommandRingElement* e, Device* device) { return; }

fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init_wgpu(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} result = { .pool_index = (sz)POOL_COUNT };
	for (sz p = 0; p < (sz)POOL_COUNT; p++)
	{
		result.pools[p] = pool_init_wgpu(device, queue)!;
		for (sz c = 0; c < (sz)CMD_PER_POOL; c++) result.cmds[p][c] = cmd_init_wgpu(device, &result.pools[p])!;
	}
	return result;
}

fn void command_ring_buffer_deinit_wgpu(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	for (sz p = 0; p < (sz)POOL_COUNT; p++)
	{
		for (sz c = 0; c < (sz)CMD_PER_POOL; c++) cmd_deinit(&r.cmds[p][c], device, &r.pools[p]);
		pool_deinit_wgpu(&r.pools[p], device);
	}
	*r = {};
}

fn CommandRingElement command_ring_buffer_get_wgpu(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	assert(r.pool_index < (sz)POOL_COUNT, "WebGPU: command ring must be advanced before get");
	assert(num_cmds > 0 && num_cmds <= (sz)CMD_PER_POOL - r.cmd_index, "WebGPU: command ring range exhausted");
	CommandRingElement result = { .cmds = r.cmds[r.pool_index][r.cmd_index .. r.cmd_index + num_cmds], .pool = &r.pools[r.pool_index] };
	r.cmd_index += num_cmds;
	return result;
}

// ---- timelines ------------------------------------------------------------

fn Timeline? timeline_init_wgpu(Device* device) { return { .backend.wgpu = {} }; }
fn void timeline_deinit_wgpu(Timeline* t, Device* device) { t.backend.wgpu = {}; }
fn ulong? timeline_completed_wgpu(Timeline* t, Device* device)
{
	return (ulong)t.backend.wgpu.completed_value[0] | ((ulong)t.backend.wgpu.completed_value[1] << 32);
}
fn void? timeline_wait_wgpu(Timeline* t, Device* device, ulong value) { return UNSUPPORTED_FEATURE~; }

// ---- buffers --------------------------------------------------------------

fn uint wgpu_buffer_usage(BufferUsage u, bool mapped)
{
	uint usage = 0;
	if (u.transfer_src) usage |= WGPU_BUFFER_COPY_SRC;
	if (u.transfer_dst || mapped) usage |= WGPU_BUFFER_COPY_DST;
	if (u.vertex_buffer) usage |= WGPU_BUFFER_VERTEX;
	if (u.index_buffer) usage |= WGPU_BUFFER_INDEX;
	if (u.constant_buffer) usage |= WGPU_BUFFER_UNIFORM;
	if (u.shader_resource_storage) usage |= WGPU_BUFFER_STORAGE;
	if (u.indirect) usage |= WGPU_BUFFER_INDIRECT;
	return usage;
}

fn Buffer? buffer_init_general_wgpu(Device* device, BufferDesc desc)
{
	uint size = web_buffer_size(desc.size, device.adapter.buffer_max_size)!!;
	uint usage = wgpu_buffer_usage(desc.usage, desc.persistent_map);
	if (usage == 0) usage = WGPU_BUFFER_COPY_DST;
	uint buffer = wgpu_device_create_buffer(device.backend.wgpu.device, size, usage);
	if (buffer == 0) return OUT_OF_DEVICE_MEMORY~;
	char[] mapped;
	if (desc.persistent_map)
	{
		mapped = alloc::malloc(device.allocator, desc.size)[:desc.size];
		if (mapped.ptr == null) { wgpu_release(buffer); return OUT_OF_DEVICE_MEMORY~; }
	}
	return { .cookie = next_cookie(), .mapped_region = mapped, .backend.wgpu = { .buffer = buffer, .size = (ulong)desc.size, .usage = usage } };
}

fn void buffer_deinit_wgpu(Buffer* b, Device* device)
{
	wgpu_release_if(&b.backend.wgpu.buffer);
	if (b.mapped_region.ptr != null) alloc::free(device.allocator, b.mapped_region.ptr);
	b.backend.wgpu = {};
}

fn void buffer_write_wgpu(Buffer* b, Device* device, sz offset, char[] bytes)
{
	if (offset < 0 || offset > (sz)b.backend.wgpu.size || (sz)bytes.len > (sz)b.backend.wgpu.size - offset) return;
	if (b.mapped_region.ptr == null && (offset % 4 != 0 || bytes.len % 4 != 0)) return;
	if (b.mapped_region.ptr != null)
	{
		if (offset >= 0 && offset <= b.mapped_region.len && bytes.len <= b.mapped_region.len - offset) b.mapped_region[offset : bytes.len] = bytes[..];
		return;
	}
	wgpu_queue_write_buffer(device.backend.wgpu.queue, b.backend.wgpu.buffer, (uint)offset, bytes.ptr, (uint)bytes.len);
}

fn void buffer_flush_wgpu(Buffer* b, Device* device)
{
	if (b.mapped_region.len == 0) return;
	wgpu_queue_write_buffer(device.backend.wgpu.queue, b.backend.wgpu.buffer, 0, b.mapped_region.ptr, (uint)b.mapped_region.len);
}

// ---- sampler / shader -----------------------------------------------------

fn uint wgpu_filter(SamplerFilter f) { return f == LINEAR ? 1 : 0; }
fn uint wgpu_mipmap(SamplerMipmap f) { return f == LINEAR ? 1 : 0; }
fn uint wgpu_address(SamplerAddress a)
{
	switch (a) { case CLAMP_TO_EDGE: return 0; case REPEAT: return 1; case MIRROR: return 2; case CLAMP_TO_BORDER: return 0; }
}
fn uint wgpu_compare(SamplerCompare c) { return (uint)c.ordinal; }

fn Sampler? sampler_init_wgpu(Device* device, SamplerDesc desc)
{
	if (desc.address_u == CLAMP_TO_BORDER || desc.address_v == CLAMP_TO_BORDER || desc.address_w == CLAMP_TO_BORDER || desc.mip_lod_bias != 0 || desc.compare_func != NEVER) return UNSUPPORTED_FEATURE~;
	float lod_min = desc.set_lod_range ? desc.min_lod : 0;
	float lod_max = desc.set_lod_range ? desc.max_lod : 32;
	if (lod_max < lod_min) return UNSUPPORTED_FEATURE~;
	uint anisotropy = desc.max_anisotropy < 1 ? 1 : (uint)desc.max_anisotropy;
	uint sampler = wgpu_device_create_sampler(device.backend.wgpu.device, wgpu_filter(desc.mag_filter), wgpu_filter(desc.min_filter), wgpu_mipmap(desc.mip_map_mode), wgpu_address(desc.address_u), wgpu_address(desc.address_v), wgpu_address(desc.address_w), lod_min, lod_max, anisotropy);
	if (sampler == 0) return OUT_OF_DEVICE_MEMORY~;
	return { .cookie = next_cookie(), .backend.wgpu = { .sampler = sampler } };
}

fn void sampler_deinit_wgpu(Sampler* s, Device* device) { wgpu_release_if(&s.backend.wgpu.sampler); }

fn Shader? shader_init_graphics_wgpu(Device* device, ShaderGraphicsOptions options)
{
	if (!options.has_vertex_stage || !options.has_fragment_stage || options.has_geometry_stage || options.has_hull_stage || options.has_domain_stage || options.has_comp_stage) return UNSUPPORTED_FEATURE~;
	uint vertex = wgpu_device_create_shader_module(device.backend.wgpu.device, options.vertex_stage.data.ptr, (uint)options.vertex_stage.data.len);
	uint fragment = wgpu_device_create_shader_module(device.backend.wgpu.device, options.fragment_stage.data.ptr, (uint)options.fragment_stage.data.len);
	if (vertex == 0 || fragment == 0) { wgpu_release(vertex); wgpu_release(fragment); return INITIALIZATION_FAILED~; }
	return { .cookie = next_cookie(), .backend.wgpu = { .vertex_module = vertex, .fragment_module = fragment, .vertex_entry = options.vertex_stage.entry_point, .fragment_entry = options.fragment_stage.entry_point, .stages = { .vertex = true, .pixel = true } } };
}

fn void shader_deinit_wgpu(Shader* s, Device* device)
{
	wgpu_release_if(&s.backend.wgpu.vertex_module);
	wgpu_release_if(&s.backend.wgpu.fragment_module);
	s.backend.wgpu = {};
}
fn ShaderStages shader_stages_wgpu(Shader* s) { return s.backend.wgpu.stages; }

// ---- images / views -------------------------------------------------------

fn uint wgpu_sample_count(ImageSampleCount samples)
{
	switch (samples) { case S1: return 1; case S2: return 2; case S4: return 4; case S8: return 8; case S16: return 16; case S32: return 32; case S64: return 64; }
}

fn uint wgpu_image_usage(ImageUsage usage)
{
	uint result = 0;
	if (usage.transfer_src) result |= WGPU_TEXTURE_COPY_SRC;
	if (usage.transfer_dst) result |= WGPU_TEXTURE_COPY_DST;
	if (usage.sampled || usage.input_attachment) result |= WGPU_TEXTURE_BINDING;
	if (usage.storage) result |= WGPU_TEXTURE_STORAGE;
	if (usage.color_attachment || usage.depth_stencil_attachment) result |= WGPU_TEXTURE_RENDER;
	return result;
}

fn Image? image_init_wgpu(Device* device, ImageDesc desc)
{
	if (desc.width == 0 || desc.height == 0 || desc.depth == 0 || desc.mip_levels == 0 || desc.array_layers == 0) return UNSUPPORTED_FEATURE~;
	WgpuTextureFormat format = wgpu_format(desc.format)!!;
	uint dimension = desc.image_type == D1 ? 0 : desc.image_type == D2 ? 1 : 2;
	uint depth_or_layers = desc.image_type == D3 ? desc.depth : desc.array_layers;
	if (desc.image_type == D1 && (desc.height != 1 || desc.depth != 1)) return UNSUPPORTED_FEATURE~;
	if (desc.image_type == D3 && desc.array_layers != 1) return UNSUPPORTED_FEATURE~;
	uint texture = wgpu_device_create_texture(device.backend.wgpu.device, (uint)format, desc.width, desc.height, depth_or_layers, desc.mip_levels, wgpu_sample_count(desc.samples), dimension, wgpu_image_usage(desc.usage));
	if (texture == 0) return OUT_OF_DEVICE_MEMORY~;
	return { .cookie = next_cookie(), .backend.wgpu = { .texture = texture, .format = desc.format, .image_type = desc.image_type, .width = desc.width, .height = desc.height, .depth = desc.depth, .mip_levels = desc.mip_levels, .array_layers = desc.array_layers } };
}

fn void image_deinit_wgpu(Image* image, Device* device) { wgpu_release_if(&image.backend.wgpu.texture); image.backend.wgpu = {}; }

fn void? image_upload_wgpu(Image* image, Device* device, ImageUploadOptions options)
{
	if (image == null || image.cookie == 0 || image.backend.wgpu.texture == 0 || options.data.len == 0) return;
	ImageWgpu* state = &image.backend.wgpu;
	if (options.mip_level >= state.mip_levels || options.layer_count == 0 || options.extent.width == 0 || options.extent.height == 0 || options.extent.depth == 0) return UNSUPPORTED_FEATURE~;
	uint mip_width = state.width >> options.mip_level; if (mip_width == 0) mip_width = 1;
	uint mip_height = state.height >> options.mip_level; if (mip_height == 0) mip_height = 1;
	uint mip_depth = state.depth >> options.mip_level; if (mip_depth == 0) mip_depth = 1;
	if (options.origin.x > mip_width || options.extent.width > mip_width - options.origin.x || options.origin.y > mip_height || options.extent.height > mip_height - options.origin.y) return UNSUPPORTED_FEATURE~;
	uint depth = options.extent.depth;
	uint z = options.origin.z;
	if (state.image_type == D3)
	{
		if (options.base_array_layer != 0 || options.layer_count != 1 || z > mip_depth || depth > mip_depth - z) return UNSUPPORTED_FEATURE~;
	}
	else
	{
		if (options.origin.z != 0 || options.extent.depth != 1 || options.base_array_layer > state.array_layers || options.layer_count > state.array_layers - options.base_array_layer) return UNSUPPORTED_FEATURE~;
		z = options.base_array_layer;
		depth = options.layer_count;
	}
	uint row = options.bytes_per_row;
	if (row == 0) row = (uint)options.data.len / options.extent.height;
	uint rows = options.rows_per_image == 0 ? options.extent.height : options.rows_per_image;
	wgpu_queue_write_texture(device.backend.wgpu.queue, state.texture, options.mip_level, options.origin.x, options.origin.y, z, options.extent.width, options.extent.height, depth, options.data.ptr, (uint)options.data.len, row, rows);
	return;
}

fn ImageView? image_view_init_wgpu(Device* device, Image* image, ViewDesc desc)
{
	if (image == null || image.cookie == 0) return INITIALIZATION_FAILED~;
	ImageWgpu* state = &image.backend.wgpu;
	if (desc.base_mip >= state.mip_levels || desc.mip_num == 0 || desc.mip_num > state.mip_levels - desc.base_mip || desc.base_layer >= state.array_layers || desc.layer_num == 0 || desc.layer_num > state.array_layers - desc.base_layer) return UNSUPPORTED_FEATURE~;
	uint dimension;
	switch (desc.view_type)
	{
		case SHADER_RESOURCE_1D: dimension = 0;
		case SHADER_RESOURCE_STORAGE_1D: dimension = 0;
		case SHADER_RESOURCE_2D: dimension = 1;
		case SHADER_RESOURCE_STORAGE_2D: dimension = 1;
		case COLOR_ATTACHMENT: dimension = 1;
		case DEPTH_STENCIL_ATTACHMENT: dimension = 1;
		case DEPTH_READONLY_STENCIL_ATTACHMENT: dimension = 1;
		case DEPTH_ATTACHMENT_STENCIL_READONLY: dimension = 1;
		case DEPTH_STENCIL_READONLY: dimension = 1;
		case SHADER_RESOURCE_2D_ARRAY: dimension = 2;
		case SHADER_RESOURCE_STORAGE_2D_ARRAY: dimension = 2;
		case SHADER_RESOURCE_CUBE: dimension = 3;
		case SHADER_RESOURCE_CUBE_ARRAY: dimension = 4;
		case SHADER_RESOURCE_3D: dimension = 5;
		case SHADER_RESOURCE_STORAGE_3D: dimension = 5;
		default: return UNSUPPORTED_FEATURE~;
	}
	uint aspect = desc.aspect == COLOR || desc.aspect == DEPTH_STENCIL ? 0 : desc.aspect == STENCIL ? 1 : 2;
	WgpuTextureFormat format = wgpu_format(desc.format)!!;
	uint view = wgpu_texture_create_view(state.texture, (uint)format, dimension, aspect, desc.base_mip, desc.mip_num, desc.base_layer, desc.layer_num);
	if (view == 0) return OUT_OF_DEVICE_MEMORY~;
	return { .cookie = next_cookie(), .backend.wgpu = { .view = view } };
}

fn void image_view_deinit_wgpu(ImageView* v, Device* device) { wgpu_release_if(&v.backend.wgpu.view); v.backend.wgpu = {}; }

// ---- pipelines ------------------------------------------------------------

fn uint wgpu_blend_factor(BlendFactor f)
{
	switch (f)
	{
		case ZERO: return 0; case ONE: return 1; case SRC_COLOR: return 2; case ONE_MINUS_SRC_COLOR: return 3;
		case SRC_ALPHA: return 4; case ONE_MINUS_SRC_ALPHA: return 5; case DST_COLOR: return 6; case ONE_MINUS_DST_COLOR: return 7;
		case DST_ALPHA: return 8; case ONE_MINUS_DST_ALPHA: return 9; case SRC_ALPHA_SATURATE: return 10;
		case CONSTANT_COLOR: return 11; case CONSTANT_ALPHA: return 11; case ONE_MINUS_CONSTANT_COLOR: return 12; case ONE_MINUS_CONSTANT_ALPHA: return 12;
	}
}
fn uint wgpu_blend_op(BlendOp op) { return (uint)op.ordinal; }
fn uint wgpu_compare_op(CompareOp op) { return (uint)op.ordinal; }
fn uint wgpu_topology(PrimitiveTopology t)
{
	switch (t) { case POINT_LIST: return 0; case LINE_LIST: return 1; case LINE_STRIP: return 2; case TRIANGLE_LIST: return 3; case TRIANGLE_STRIP: return 4; }
}
fn uint wgpu_cull(CullMode c) { return (uint)c.ordinal; }
fn uint wgpu_front(FrontFace f) { return f == CLOCKWISE ? 1 : 0; }

fn Pipeline? pipeline_init_graphics_wgpu(Device* device, PipelineGraphicsOptions options)
{
	if (options.shader == null || options.shader.cookie == 0 || !options.has_vertex_layout || options.colors.len != 1) return MULTIPLE_RENDER_TARGETS_UNSUPPORTED~;
	if (options.vertex_layout.attributes.len > 16) return TOO_MANY_VERTEX_ATTRIBUTES~;
	ShaderWgpu* shader = &options.shader.backend.wgpu;
	WgpuTextureFormat color = wgpu_format(options.colors[0].format)!!;
	WgpuTextureFormat depth = (WgpuTextureFormat)(WgpuTextureFormat::len - 1);
	if (options.has_depth) depth = wgpu_format(options.depth.format)!!;
	uint[48] attrs;
	if (options.vertex_layout.attributes.len * 3 > attrs.len) return TOO_MANY_VERTEX_ATTRIBUTES~;
	foreach (i, a : options.vertex_layout.attributes)
	{
		attrs[i * 3] = a.location;
		attrs[i * 3 + 1] = (uint)a.format.ordinal;
		attrs[i * 3 + 2] = a.offset;
	}
	BlendState blend = options.colors[0].blend;
	uint mask = (blend.write_mask.r ? 1 : 0) | (blend.write_mask.g ? 2 : 0) | (blend.write_mask.b ? 4 : 0) | (blend.write_mask.a ? 8 : 0);
	uint pipeline = wgpu_device_create_render_pipeline(device.backend.wgpu.device, shader.vertex_module, shader.vertex_entry.ptr, (uint)shader.vertex_entry.len, shader.fragment_module, shader.fragment_entry.ptr, (uint)shader.fragment_entry.len, (uint)color, (uint)depth, wgpu_topology(options.raster.topology), wgpu_cull(options.raster.cull_mode), wgpu_front(options.raster.front_face), options.has_depth && options.depth.write ? 1 : 0, options.has_depth ? wgpu_compare_op(options.depth.compare) : 0, options.vertex_layout.stride, &attrs[0], (uint)(options.vertex_layout.attributes.len * 3), options.colors[0].has_blend ? 1 : 0, wgpu_blend_factor(blend.src_color), wgpu_blend_factor(blend.dst_color), wgpu_blend_op(blend.color_op), wgpu_blend_factor(blend.src_alpha), wgpu_blend_factor(blend.dst_alpha), wgpu_blend_op(blend.alpha_op), mask);
	if (pipeline == 0) return SHADER_COMPILATION_FAILED~;
	TextureSlot[MAX_TEXTURE_BINDINGS] slots;
	uint slot_count = resolve_texture_slots(options.texture_bindings, &slots)!;
	uint texture_layout = wgpu_render_pipeline_get_bind_group_layout(pipeline, 1);
	uint uniform_layout = wgpu_render_pipeline_get_bind_group_layout(pipeline, 0);
	uint push_constant_buffer = 0;
	uint push_constant_group = 0;
	uint push_constant_size = options.push_constant_size;
	if (push_constant_size > 0)
	{
		push_constant_size = (push_constant_size + 15) & ~(uint)15;
		push_constant_buffer = wgpu_device_create_buffer(device.backend.wgpu.device, push_constant_size, WGPU_BUFFER_COPY_DST | WGPU_BUFFER_UNIFORM);
		if (push_constant_buffer == 0)
		{
			wgpu_release_if(&uniform_layout); wgpu_release_if(&texture_layout); wgpu_release(pipeline);
			return OUT_OF_DEVICE_MEMORY~;
		}
		push_constant_group = wgpu_device_create_bind_group_uniform(device.backend.wgpu.device, uniform_layout, push_constant_buffer, 0, push_constant_size);
		if (push_constant_group == 0)
		{
			wgpu_release_if(&push_constant_buffer); wgpu_release_if(&uniform_layout); wgpu_release_if(&texture_layout); wgpu_release(pipeline);
			return INITIALIZATION_FAILED~;
		}
	}
	return { .cookie = next_cookie(), .backend.wgpu = { .pipeline = pipeline, .texture_layout = texture_layout, .uniform_layout = uniform_layout, .push_constant_buffer = push_constant_buffer, .push_constant_group = push_constant_group, .texture_slots = slots, .texture_slot_count = slot_count, .push_constant_size = push_constant_size } };
}

fn void pipeline_deinit_wgpu(Pipeline* p, Device* device)
{
	wgpu_release_if(&p.backend.wgpu.push_constant_group);
	wgpu_release_if(&p.backend.wgpu.push_constant_buffer);
	wgpu_release_if(&p.backend.wgpu.pipeline);
	wgpu_release_if(&p.backend.wgpu.texture_layout);
	wgpu_release_if(&p.backend.wgpu.uniform_layout);
	p.backend.wgpu = {};
}

// ---- command encoding -----------------------------------------------------

fn Cmd? cmd_init_wgpu(Device* device, Pool* pool)
{
	if (device == null || device.backend.wgpu.device == 0) return INITIALIZATION_FAILED~;
	return { .backend.wgpu = { .device = device.backend.wgpu.device } };
}

fn void cmd_deinit_wgpu(Cmd* c, Device* device, Pool* pool)
{
	CmdWgpu* s = &c.backend.wgpu;
	if (s.pass != 0) { wgpu_render_pass_end(s.pass); s.pass = 0; }
	wgpu_release_if(&s.command_buffer);
	wgpu_release_if(&s.encoder);
	wgpu_release_if(&s.texture_bind_group);
	s.pipeline = 0;
	s.push_constant_group = 0;
}

fn void? cmd_begin_wgpu(Cmd* c, Device* device)
{
	CmdWgpu* s = &c.backend.wgpu;
	if (s.encoder != 0) return UNKNOWN~;
	s.encoder = wgpu_device_create_command_encoder(s.device);
	if (s.encoder == 0) return OUT_OF_DEVICE_MEMORY~;
	return;
}

fn void? cmd_end_wgpu(Cmd* c, Device* device)
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

fn void cmd_set_viewport_wgpu(Cmd* c, Device* device, Viewport vp)
{
	if (c.backend.wgpu.pass != 0) wgpu_render_pass_set_viewport(c.backend.wgpu.pass, vp.x, vp.y, vp.width, vp.height, vp.min_depth, vp.max_depth);
}
fn void cmd_set_scissor_wgpu(Cmd* c, Device* device, Rect rect)
{
	if (c.backend.wgpu.pass != 0 && rect.x >= 0 && rect.y >= 0) wgpu_render_pass_set_scissor_rect(c.backend.wgpu.pass, (uint)rect.x, (uint)rect.y, rect.width, rect.height);
}
fn void cmd_draw_wgpu(Cmd* c, Device* device, uint vertex_count, uint instance_count, uint first_vertex, uint first_instance)
{
	if (c.backend.wgpu.pass != 0) wgpu_render_pass_draw(c.backend.wgpu.pass, vertex_count, instance_count, first_vertex, first_instance);
}
fn void cmd_draw_indexed_wgpu(Cmd* c, Device* device, uint index_count, uint instance_count, uint first_index, int vertex_offset, uint first_instance)
{
	if (c.backend.wgpu.pass != 0) wgpu_render_pass_draw_indexed(c.backend.wgpu.pass, index_count, instance_count, first_index, vertex_offset, first_instance);
}
fn void cmd_draw_indirect_wgpu(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride) { wgpu_log_text("WebGPU: indirect draws are not in the scalar bridge"); }
fn void cmd_draw_indexed_indirect_wgpu(Cmd* c, Device* device, Buffer* buffer, ulong offset, uint draw_count, uint stride) { wgpu_log_text("WebGPU: indexed indirect draws are not in the scalar bridge"); }
fn void cmd_draw_indirect_count_wgpu(Cmd* c, Device* device, Buffer* buffer, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride) { wgpu_log_text("WebGPU: indirect-count draws are not in the scalar bridge"); }

fn void cmd_bind_pipeline_wgpu(Cmd* c, Device* device, Pipeline* pipeline)
{
	c.backend.wgpu.pipeline = pipeline == null ? 0 : pipeline.backend.wgpu.pipeline;
	c.backend.wgpu.push_constant_group = pipeline == null ? 0 : pipeline.backend.wgpu.push_constant_group;
	if (c.backend.wgpu.pass != 0 && c.backend.wgpu.pipeline != 0)
	{
		wgpu_render_pass_set_pipeline(c.backend.wgpu.pass, c.backend.wgpu.pipeline);
		if (c.backend.wgpu.push_constant_group != 0) wgpu_render_pass_set_bind_group(c.backend.wgpu.pass, 0, c.backend.wgpu.push_constant_group);
	}
}
fn void cmd_set_push_constants_wgpu(Cmd* c, Device* device, Pipeline* pipeline, char[] bytes)
{
	if (pipeline == null || bytes.len == 0 || pipeline.backend.wgpu.push_constant_buffer == 0) return;
	uint size = (uint)min(bytes.len, (sz)pipeline.backend.wgpu.push_constant_size);
	if (size > 0) wgpu_queue_write_buffer(device.backend.wgpu.queue, pipeline.backend.wgpu.push_constant_buffer, 0, bytes.ptr, size);
	if (c.backend.wgpu.pass != 0 && pipeline.backend.wgpu.push_constant_group != 0) wgpu_render_pass_set_bind_group(c.backend.wgpu.pass, 0, pipeline.backend.wgpu.push_constant_group);
}
fn void cmd_clear_attachment_regions_wgpu(Cmd* c, Device* device, CmdClearRegion[] regions)
{
	// A WebGPU loadOp=clear clears the whole attachment.  Never translate a
	// region clear into it: that would silently erase pixels outside the region.
	if (regions.len > 0) abort("WebGPU: partial attachment clears are unsupported");
}

fn void? cmd_bind_descriptors_wgpu(Cmd* c, Device* device, Pipeline* pipeline, DescriptorBinding[] bindings)
{
	if (c == null || pipeline == null || c.backend.wgpu.pass == 0) return UNKNOWN~;
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

fn void cmd_begin_rendering_wgpu(Cmd* c, Device* device, CmdBeginRenderingOptions options)
{
	CmdWgpu* s = &c.backend.wgpu;
	if (s.encoder == 0 || options.color_attachments.len != 1) { wgpu_log_text("WebGPU: one color attachment is required"); return; }
	if (s.pass != 0) { wgpu_render_pass_end(s.pass); s.pass = 0; }
	CmdColorAttachment color = options.color_attachments[0];
	uint depth_view = options.has_depth_attachment ? options.depth_attachment.view.backend.wgpu.view : 0;
	uint color_load = color.load_op == LOAD ? 0 : 1;
	uint color_store = color.store_op == STORE ? 0 : 1;
	uint depth_load = options.has_depth_attachment && options.depth_attachment.load_op == LOAD ? 0 : 1;
	uint depth_store = options.has_depth_attachment && options.depth_attachment.store_op == STORE ? 0 : 1;
	s.pass = wgpu_command_encoder_begin_render_pass(s.encoder, color.view.backend.wgpu.view, color_load, color_store, color.clear_color[0], color.clear_color[1], color.clear_color[2], color.clear_color[3], depth_view, depth_load, depth_store, options.has_depth_attachment ? options.depth_attachment.clear_depth : 1);
	if (s.pass != 0 && options.render_area.x >= 0 && options.render_area.y >= 0) wgpu_render_pass_set_scissor_rect(s.pass, (uint)options.render_area.x, (uint)options.render_area.y, options.render_area.width, options.render_area.height);
}
fn void cmd_end_rendering_wgpu(Cmd* c, Device* device)
{
	if (c.backend.wgpu.pass != 0) { wgpu_render_pass_end(c.backend.wgpu.pass); c.backend.wgpu.pass = 0; }
}
fn void cmd_bind_vertex_buffers_wgpu(Cmd* c, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets = {})
{
	if (c.backend.wgpu.pass == 0) return;
	foreach (i, b : buffers) if (b != null && b.cookie != 0) wgpu_render_pass_set_vertex_buffer(c.backend.wgpu.pass, first_binding + (uint)i, b.backend.wgpu.buffer, offsets.len == 0 ? 0 : (uint)offsets[i]);
}
fn void cmd_bind_index_buffer_wgpu(Cmd* c, Device* device, Buffer* buffer, IndexType index_type, ulong offset = 0)
{
	if (c.backend.wgpu.pass != 0 && buffer != null) { c.backend.wgpu.index_format = index_type == UINT16 ? 0 : 1; wgpu_render_pass_set_index_buffer(c.backend.wgpu.pass, buffer.backend.wgpu.buffer, c.backend.wgpu.index_format, (uint)offset); }
}
fn void cmd_resource_barrier_wgpu(Cmd* c, Device* device, MemoryBarrier[] memory = {}, BufferBarrier[] buffers = {}, ImageBarrier[] images = {}) {}
fn void cmd_copy_buffer_to_texture_wgpu(Cmd* c, Device* device, CmdCopyBufferToTextureOptions options) { wgpu_log_text("WebGPU: buffer-to-texture copies are unsupported; use image_upload"); }
fn void cmd_copy_texture_to_buffer_wgpu(Cmd* c, Device* device, CmdCopyTextureToBufferOptions options) { wgpu_log_text("WebGPU: texture-to-buffer copies are unsupported by the bridge"); }
fn void cmd_copy_buffer_wgpu(Cmd* c, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size)
{
	if (c.backend.wgpu.encoder != 0 && src != null && dst != null && size <= 0xFFFFFFFF) wgpu_command_encoder_copy_buffer_to_buffer(c.backend.wgpu.encoder, src.backend.wgpu.buffer, (uint)src_offset, dst.backend.wgpu.buffer, (uint)dst_offset, (uint)size);
}
fn void cmd_copy_image_wgpu(Cmd* c, Device* device, Image* src, Image* dst, ImageCopyDesc desc) { wgpu_log_text("WebGPU: image copies are unsupported by the bridge"); }

// ---- canvas swapchain -----------------------------------------------------

fn Swapchain? swapchain_init_wgpu(Device* device, SwapchainDesc desc, Allocator allocator = mem)
{
	if (device == null || desc.queue == null || desc.width == 0 || desc.height == 0) return INITIALIZATION_FAILED~;
	uint surface = 0;
	SwapchainSurfaceFormat preferred;
	if (desc.source.kind == WINDOW)
	{
		if (desc.source.window.kind != CANVAS) return INITIALIZATION_FAILED~;
		String selector = swapchain_canvas_selector(desc.source.window.canvas);
		surface = wgpu_surface_create(selector.ptr, (uint)selector.len);
		if (surface == 0) return SURFACE_LOST~;
		uint raw = wgpu_surface_preferred_format();
		preferred = swapchain_wgpu_surface_format(raw);
	}
	else if (desc.source.kind == SWAPCHAIN)
	{
		Swapchain* old = desc.source.swapchain;
		if (old == null || old.backend.wgpu.surface == 0) return SURFACE_LOST~;
		surface = old.backend.wgpu.surface;
		preferred = { .gpu = old.backend.wgpu.format, .format = old.backend.wgpu.color_format };
		old.backend.wgpu.surface = 0;
		wgpu_release_if(&old.backend.wgpu.current_texture);
		wgpu_release_if(&old.backend.wgpu.current_view);
	}
	else
	{
		return INITIALIZATION_FAILED~;
	}
	wgpu_surface_configure(surface, device.backend.wgpu.device, (uint)preferred.gpu, desc.width, desc.height);
	return { .allocator = allocator, .present_queue = desc.queue, .image_count = 1, .width = desc.width, .height = desc.height, .backend.wgpu = { .surface = surface, .format = preferred.gpu, .color_format = preferred.format } };
}

fn void swapchain_deinit_wgpu(Swapchain* s, Device* device)
{
	wgpu_release_if(&s.backend.wgpu.current_view);
	wgpu_release_if(&s.backend.wgpu.current_texture);
	wgpu_release_if(&s.backend.wgpu.surface);
	s.backend.wgpu = {};
}

fn void? swapchain_recreate_wgpu(Swapchain* s, Device* device, ushort width, ushort height)
{
	if (width == 0 || height == 0 || s.backend.wgpu.surface == 0) return INITIALIZATION_FAILED~;
	wgpu_surface_configure(s.backend.wgpu.surface, device.backend.wgpu.device, (uint)s.backend.wgpu.format, width, height);
	s.width = width; s.height = height;
	return;
}

fn SwapchainStatus? swapchain_acquire_next_image_wgpu(Swapchain* s, Device* device, uint* out_index)
{
	wgpu_release_if(&s.backend.wgpu.current_view);
	wgpu_release_if(&s.backend.wgpu.current_texture);
	uint texture = wgpu_surface_get_current_texture(s.backend.wgpu.surface);
	if (texture == 0) return OUT_OF_DATE~;
	uint view = wgpu_texture_create_view(texture, (uint)s.backend.wgpu.format, 1, 0, 0, 1, 0, 1);
	if (view == 0) { wgpu_release(texture); return OUT_OF_DATE~; }
	s.backend.wgpu.current_texture = texture;
	s.backend.wgpu.current_view = view;
	if (out_index != null) *out_index = 0;
	return OK;
}

fn Image swapchain_image_wgpu(Swapchain* s, uint index)
{
	if (index != 0 || s.backend.wgpu.current_texture == 0) return {};
	return { .cookie = s.backend.wgpu.current_texture, .backend.wgpu = { .texture = s.backend.wgpu.current_texture, .format = s.backend.wgpu.color_format, .image_type = D2, .width = s.width, .height = s.height, .depth = 1, .mip_levels = 1, .array_layers = 1 } };
}
fn ImageView swapchain_image_view_wgpu(Swapchain* s, uint index)
{
	if (index != 0 || s.backend.wgpu.current_view == 0) return {};
	return { .cookie = s.backend.wgpu.current_view, .backend.wgpu = { .view = s.backend.wgpu.current_view } };
}

fn SwapchainStatus? swapchain_frame_submit_wgpu(Swapchain* s, Device* device, Queue* queue, SwapchainFrameSubmit submit)
{
	if (submit.image_index != 0 || queue == null) return OUT_OF_DATE~;
	foreach (c : submit.cmds) if (c != null && c.backend.wgpu.command_buffer == 0) return UNKNOWN~;
	if (submit.cmds.len > 0)
	{
		uint[64] commands;
		if (submit.cmds.len > commands.len) return UNSUPPORTED_FEATURE~;
		foreach (i, c : submit.cmds) commands[i] = c.backend.wgpu.command_buffer;
		wgpu_queue_submit(queue.backend.wgpu.queue, &commands[0], (uint)submit.cmds.len);
	}
	if (submit.timeline != null)
	{
		ulong value = submit.signal_value != 0 ? submit.signal_value : timeline_next(submit.timeline);
		submit.timeline.signal_value = value;
		uint lo = (uint)value; uint hi = (uint)(value >> 32);
		wgpu_queue_on_submitted_work_done(queue.backend.wgpu.queue, &submit.timeline.backend.wgpu.completed_value[0], lo, hi);
	}
	return OK;
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// WebGL2 backend.  The browser bridge deliberately exposes a small, integer
// handle based ABI: GL objects stay in JavaScript and this file records the
// RHI commands in wasm memory, replaying them only when the ordered queue is
// submitted.  Rendering is always performed into an offscreen colour FBO;
// the bridge blits that FBO to the canvas at frame submit.
module rhi @feat(RHI_WEBGL & !RHI_HEADLESS & WASM);
import std::collections::list;

alias GlHandle = uint;

// ---- javascript ABI -----------------------------------------------------

extern fn uint gl_available() @wasm("webgl", "gl_available");
extern fn uint gl_renderer_name(char* ptr, uint len) @wasm("webgl", "gl_renderer_name");
extern fn int gl_get_parameter_int(uint pname) @wasm("webgl", "gl_get_parameter_int");

extern fn GlHandle gl_create_buffer(uint target, uint size, uint usage) @wasm("webgl", "gl_create_buffer");
extern fn void gl_delete_buffer(GlHandle buffer) @wasm("webgl", "gl_delete_buffer");
extern fn void gl_buffer_sub_data(uint target, GlHandle buffer, uint offset, char* ptr, uint len) @wasm("webgl", "gl_buffer_sub_data");
extern fn void gl_copy_buffer_sub_data(uint src_target, GlHandle src, uint src_offset, uint dst_target, GlHandle dst, uint dst_offset, uint size) @wasm("webgl", "gl_copy_buffer_sub_data");

extern fn GlHandle gl_create_texture_2d(uint internal_format, uint width, uint height, uint levels) @wasm("webgl", "gl_create_texture_2d");
extern fn void gl_delete_texture(GlHandle texture) @wasm("webgl", "gl_delete_texture");
extern fn void gl_tex_sub_image_2d(GlHandle texture, uint level, int x, int y, uint width, uint height, uint format, uint type, char* ptr, uint len) @wasm("webgl", "gl_tex_sub_image_2d");
extern fn void gl_tex_sub_image_2d_from_buffer(GlHandle texture, uint level, int x, int y, uint width, uint height, uint format, uint type, GlHandle buffer, uint offset, uint row_length) @wasm("webgl", "gl_tex_sub_image_2d_from_buffer");
extern fn GlHandle gl_create_sampler(uint min_filter, uint mag_filter, uint wrap_s, uint wrap_t, uint wrap_r) @wasm("webgl", "gl_create_sampler");
extern fn void gl_delete_sampler(GlHandle sampler) @wasm("webgl", "gl_delete_sampler");
extern fn void gl_bind_texture_unit(uint unit, GlHandle texture, GlHandle sampler) @wasm("webgl", "gl_bind_texture_unit");
extern fn int gl_set_sampler_unit(GlHandle program, char* ptr, uint len, uint unit) @wasm("webgl", "gl_set_sampler_unit");

extern fn GlHandle gl_create_framebuffer() @wasm("webgl", "gl_create_framebuffer");
extern fn void gl_delete_framebuffer(GlHandle framebuffer) @wasm("webgl", "gl_delete_framebuffer");
extern fn void gl_framebuffer_texture_2d(GlHandle framebuffer, uint attachment, GlHandle texture) @wasm("webgl", "gl_framebuffer_texture_2d");
extern fn uint gl_check_framebuffer_status(GlHandle framebuffer) @wasm("webgl", "gl_check_framebuffer_status");
extern fn void gl_bind_framebuffer(GlHandle framebuffer) @wasm("webgl", "gl_bind_framebuffer");
extern fn void gl_blit_to_canvas(GlHandle framebuffer, uint width, uint height) @wasm("webgl", "gl_blit_to_canvas");

extern fn GlHandle gl_create_program(char* vs_ptr, uint vs_len, char* fs_ptr, uint fs_len, char* err_ptr, uint err_len) @wasm("webgl", "gl_create_program");
extern fn void gl_delete_program(GlHandle program) @wasm("webgl", "gl_delete_program");
extern fn void gl_use_program(GlHandle program) @wasm("webgl", "gl_use_program");
extern fn int gl_uniform_location(GlHandle program, char* ptr, uint len) @wasm("webgl", "gl_uniform_location");
extern fn void gl_uniform_raw(int location, uint type, char* ptr, uint len) @wasm("webgl", "gl_uniform_raw");

extern fn GlHandle gl_create_vertex_array() @wasm("webgl", "gl_create_vertex_array");
extern fn void gl_delete_vertex_array(GlHandle vao) @wasm("webgl", "gl_delete_vertex_array");
extern fn void gl_bind_vertex_array(GlHandle vao) @wasm("webgl", "gl_bind_vertex_array");
extern fn void gl_vertex_attrib_pointer(GlHandle vao, GlHandle buffer, uint location, uint components, uint stride, uint offset) @wasm("webgl", "gl_vertex_attrib_pointer");
extern fn void gl_vao_set_element_buffer(GlHandle vao, GlHandle buffer) @wasm("webgl", "gl_vao_set_element_buffer");

extern fn void gl_viewport(int x, int y, int width, int height, float min_depth, float max_depth) @wasm("webgl", "gl_viewport");
extern fn void gl_scissor(int x, int y, uint width, uint height) @wasm("webgl", "gl_scissor");
extern fn void gl_set_enabled(uint cap, bool enabled) @wasm("webgl", "gl_set_enabled");
extern fn void gl_depth_func(uint func) @wasm("webgl", "gl_depth_func");
extern fn void gl_depth_mask(bool enabled) @wasm("webgl", "gl_depth_mask");
extern fn void gl_cull_face(uint mode) @wasm("webgl", "gl_cull_face");
extern fn void gl_front_face(uint mode) @wasm("webgl", "gl_front_face");
extern fn void gl_color_mask(bool r, bool g, bool b, bool a) @wasm("webgl", "gl_color_mask");
extern fn void gl_blend_func_separate(uint src_rgb, uint dst_rgb, uint src_alpha, uint dst_alpha) @wasm("webgl", "gl_blend_func_separate");
extern fn void gl_blend_equation_separate(uint rgb, uint alpha) @wasm("webgl", "gl_blend_equation_separate");
extern fn void gl_clear_color(float r, float g, float b, float a) @wasm("webgl", "gl_clear_color");
extern fn void gl_clear_depth(float depth) @wasm("webgl", "gl_clear_depth");
extern fn void gl_clear_stencil(uint stencil) @wasm("webgl", "gl_clear_stencil");
extern fn void gl_draw_arrays(uint mode, uint first, uint count, uint instances) @wasm("webgl", "gl_draw_arrays");
extern fn void gl_draw_elements(uint mode, uint count, uint type, uint offset, uint instances) @wasm("webgl", "gl_draw_elements");
extern fn void gl_finish() @wasm("webgl", "gl_finish");
extern fn GlHandle gl_fence_sync() @wasm("webgl", "gl_fence_sync");
extern fn bool gl_client_wait_sync(GlHandle sync) @wasm("webgl", "gl_client_wait_sync");
extern fn void gl_delete_sync(GlHandle sync) @wasm("webgl", "gl_delete_sync");

// ---- GL constants and small conversions --------------------------------

const uint GL_ARRAY_BUFFER = 0x8892;
const uint GL_ELEMENT_ARRAY_BUFFER = 0x8893;
const uint GL_COPY_READ_BUFFER = 0x8F36;
const uint GL_COPY_WRITE_BUFFER = 0x8F37;
const uint GL_PIXEL_UNPACK_BUFFER = 0x88EC;
const uint GL_STATIC_DRAW = 0x88E4;
const uint GL_DYNAMIC_DRAW = 0x88E8;
const uint GL_STREAM_DRAW = 0x88E0;
const uint GL_FRAMEBUFFER = 0x8D40;
const uint GL_COLOR_ATTACHMENT0 = 0x8CE0;
const uint GL_DEPTH_ATTACHMENT = 0x8D00;
const uint GL_DEPTH_STENCIL_ATTACHMENT = 0x821A;
const uint GL_RGBA = 0x1908;
const uint GL_RGBA_INTEGER = 0x8D99;
const uint GL_RED = 0x1903;
const uint GL_RG = 0x8227;
const uint GL_DEPTH_COMPONENT = 0x1902;
const uint GL_UNSIGNED_BYTE = 0x1401;
const uint GL_BYTE = 0x1400;
const uint GL_UNSIGNED_SHORT = 0x1403;
const uint GL_SHORT = 0x1402;
const uint GL_UNSIGNED_INT = 0x1405;
const uint GL_INT = 0x1404;
const uint GL_FLOAT = 0x1406;
const uint GL_HALF_FLOAT = 0x140B;
const uint GL_RGBA8 = 0x8058;
const uint GL_SRGB8_ALPHA8 = 0x8C43;
const uint GL_RGBA16F = 0x881A;
const uint GL_RGBA32F = 0x8814;
const uint GL_RGBA8UI = 0x8D7C;
const uint GL_RGBA8I = 0x8D8E;
const uint GL_RGBA16UI = 0x8D76;
const uint GL_RGBA16I = 0x8D88;
const uint GL_RGBA32UI = 0x8D70;
const uint GL_RGBA32I = 0x8D82;
const uint GL_R8 = 0x8229;
const uint GL_RG8 = 0x822B;
const uint GL_R16F = 0x822D;
const uint GL_RG16F = 0x822F;
const uint GL_R32F = 0x822E;
const uint GL_RG32F = 0x8230;
const uint GL_DEPTH_COMPONENT16 = 0x81A5;
const uint GL_DEPTH_COMPONENT24 = 0x81A6;
const uint GL_DEPTH_COMPONENT32F = 0x8CAC;
const uint GL_DEPTH24_STENCIL8 = 0x88F0;
const uint GL_DEPTH32F_STENCIL8 = 0x8CAD;
const uint GL_TEXTURE_MIN_FILTER = 0x2801;
const uint GL_NEAREST = 0x2600;
const uint GL_LINEAR = 0x2601;
const uint GL_CLAMP_TO_EDGE = 0x812F;
const uint GL_REPEAT = 0x2901;
const uint GL_MIRRORED_REPEAT = 0x8370;
const uint GL_LESS = 0x0201;
const uint GL_EQUAL = 0x0202;
const uint GL_LEQUAL = 0x0203;
const uint GL_GREATER = 0x0204;
const uint GL_NOTEQUAL = 0x0205;
const uint GL_GEQUAL = 0x0206;
const uint GL_ALWAYS = 0x0207;
const uint GL_NEVER = 0x0200;
const uint GL_DEPTH_TEST = 0x0B71;
const uint GL_CULL_FACE = 0x0B44;
const uint GL_BLEND = 0x0BE2;
const uint GL_SCISSOR_TEST = 0x0C11;
const uint GL_FRONT = 0x0404;
const uint GL_BACK = 0x0405;
const uint GL_CW = 0x0900;
const uint GL_CCW = 0x0901;
const uint GL_TRIANGLES = 0x0004;
const uint GL_TRIANGLE_STRIP = 0x0005;
const uint GL_LINES = 0x0001;
const uint GL_LINE_STRIP = 0x0003;
const uint GL_POINTS = 0x0000;
const uint GL_FUNC_ADD = 0x8006;
const uint GL_FUNC_SUBTRACT = 0x800A;
const uint GL_FUNC_REVERSE_SUBTRACT = 0x800B;
const uint GL_ZERO = 0;
const uint GL_ONE = 1;
const uint GL_SRC_COLOR = 0x0300;
const uint GL_ONE_MINUS_SRC_COLOR = 0x0301;
const uint GL_DST_COLOR = 0x0306;
const uint GL_ONE_MINUS_DST_COLOR = 0x0307;
const uint GL_SRC_ALPHA = 0x0302;
const uint GL_ONE_MINUS_SRC_ALPHA = 0x0303;
const uint GL_DST_ALPHA = 0x0304;
const uint GL_ONE_MINUS_DST_ALPHA = 0x0305;
const uint GL_CONSTANT_COLOR = 0x8001;
const uint GL_ONE_MINUS_CONSTANT_COLOR = 0x8002;
const uint GL_CONSTANT_ALPHA = 0x8003;
const uint GL_ONE_MINUS_CONSTANT_ALPHA = 0x8004;
const uint GL_SRC_ALPHA_SATURATE = 0x0308;

struct WebglFormat { uint internal_format; uint format; uint type; bool valid; bool depth; }

fn WebglFormat webgl_format(Format f)
{
	WebglFormat out = { .internal_format = GL_RGBA8, .format = GL_RGBA, .type = GL_UNSIGNED_BYTE, .valid = true };
	switch (f)
	{
		case RGBA8_SRGB: out.internal_format = GL_SRGB8_ALPHA8;
		case RGBA16_SFLOAT: out.internal_format = GL_RGBA16F; out.type = GL_HALF_FLOAT;
		case RGBA32_SFLOAT: out.internal_format = GL_RGBA32F; out.type = GL_FLOAT;
		case RGBA8_UINT: out.internal_format = GL_RGBA8UI; out.format = GL_RGBA_INTEGER;
		case RGBA8_SINT: out.internal_format = GL_RGBA8I; out.format = GL_RGBA_INTEGER; out.type = GL_BYTE;
		case RGBA16_UINT: out.internal_format = GL_RGBA16UI; out.format = GL_RGBA_INTEGER; out.type = GL_UNSIGNED_SHORT;
		case RGBA16_SINT: out.internal_format = GL_RGBA16I; out.format = GL_RGBA_INTEGER; out.type = GL_SHORT;
		case RGBA32_UINT: out.internal_format = GL_RGBA32UI; out.format = GL_RGBA_INTEGER; out.type = GL_UNSIGNED_INT;
		case RGBA32_SINT: out.internal_format = GL_RGBA32I; out.format = GL_RGBA_INTEGER; out.type = GL_INT;
		case R8_UNORM: out.internal_format = GL_R8; out.format = GL_RED;
		case RG8_UNORM: out.internal_format = GL_RG8; out.format = GL_RG;
		case R16_SFLOAT: out.internal_format = GL_R16F; out.format = GL_RED; out.type = GL_HALF_FLOAT;
		case RG16_SFLOAT: out.internal_format = GL_RG16F; out.format = GL_RG; out.type = GL_HALF_FLOAT;
		case R32_SFLOAT: out.internal_format = GL_R32F; out.format = GL_RED; out.type = GL_FLOAT;
		case RG32_SFLOAT: out.internal_format = GL_RG32F; out.format = GL_RG; out.type = GL_FLOAT;
		case D16_UNORM: out.internal_format = GL_DEPTH_COMPONENT16; out.format = GL_DEPTH_COMPONENT; out.type = GL_UNSIGNED_SHORT; out.depth = true;
		case D24_UNORM_S8_UINT: out.internal_format = GL_DEPTH24_STENCIL8; out.format = GL_DEPTH_COMPONENT; out.type = GL_UNSIGNED_INT; out.depth = true;
		case D32_SFLOAT: out.internal_format = GL_DEPTH_COMPONENT32F; out.format = GL_DEPTH_COMPONENT; out.type = GL_FLOAT; out.depth = true;
		case D32_SFLOAT_S8_UINT: out.internal_format = GL_DEPTH32F_STENCIL8; out.format = GL_DEPTH_COMPONENT; out.type = GL_FLOAT; out.depth = true;
		case UNKNOWN: out.valid = false;
		default: out.valid = false;
	}
	return out;
}

fn uint webgl_buffer_target(BufferUsage usage)
{
	if (usage.index_buffer) return GL_ELEMENT_ARRAY_BUFFER;
	if (usage.vertex_buffer) return GL_ARRAY_BUFFER;
	if (usage.transfer_src || usage.transfer_dst) return GL_COPY_WRITE_BUFFER;
	return GL_ARRAY_BUFFER;
}

fn uint webgl_buffer_usage(BufferDesc desc)
{
	if (desc.sequential_access) return GL_STREAM_DRAW;
	if (desc.persistent_map) return GL_DYNAMIC_DRAW;
	return GL_STATIC_DRAW;
}

fn uint webgl_compare(CompareOp op)
{
	switch (op) { case NEVER: return GL_NEVER; case LESS: return GL_LESS; case EQUAL: return GL_EQUAL; case LESS_EQUAL: return GL_LEQUAL; case GREATER: return GL_GREATER; case NOT_EQUAL: return GL_NOTEQUAL; case GREATER_EQUAL: return GL_GEQUAL; case ALWAYS: return GL_ALWAYS; }
}

fn uint webgl_blend_factor(BlendFactor f)
{
	switch (f) { case ZERO: return GL_ZERO; case ONE: return GL_ONE; case SRC_COLOR: return GL_SRC_COLOR; case ONE_MINUS_SRC_COLOR: return GL_ONE_MINUS_SRC_COLOR; case DST_COLOR: return GL_DST_COLOR; case ONE_MINUS_DST_COLOR: return GL_ONE_MINUS_DST_COLOR; case SRC_ALPHA: return GL_SRC_ALPHA; case ONE_MINUS_SRC_ALPHA: return GL_ONE_MINUS_SRC_ALPHA; case DST_ALPHA: return GL_DST_ALPHA; case ONE_MINUS_DST_ALPHA: return GL_ONE_MINUS_DST_ALPHA; case CONSTANT_COLOR: return GL_CONSTANT_COLOR; case ONE_MINUS_CONSTANT_COLOR: return GL_ONE_MINUS_CONSTANT_COLOR; case CONSTANT_ALPHA: return GL_CONSTANT_ALPHA; case ONE_MINUS_CONSTANT_ALPHA: return GL_ONE_MINUS_CONSTANT_ALPHA; case SRC_ALPHA_SATURATE: return GL_SRC_ALPHA_SATURATE; }
}

fn uint webgl_blend_op(BlendOp op)
{
	switch (op) { case ADD: return GL_FUNC_ADD; case SUBTRACT: return GL_FUNC_SUBTRACT; case REVERSE_SUBTRACT: return GL_FUNC_REVERSE_SUBTRACT; case MIN: return 0x8007; case MAX: return 0x8008; }
}

fn uint webgl_topology(PrimitiveTopology topology)
{
	switch (topology) { case TRIANGLE_LIST: return GL_TRIANGLES; case TRIANGLE_STRIP: return GL_TRIANGLE_STRIP; case LINE_LIST: return GL_LINES; case LINE_STRIP: return GL_LINE_STRIP; case POINT_LIST: return GL_POINTS; }
}

fn uint webgl_components(VertexFormat format)
{
	switch (format) { case FLOAT: return 1; case FLOAT2: return 2; case FLOAT3: return 3; case FLOAT4: return 4; }
}

fn uint webgl_wrap(SamplerAddress address)
{
	switch (address) { case MIRROR: return GL_MIRRORED_REPEAT; case REPEAT: return GL_REPEAT; case CLAMP_TO_EDGE: return GL_CLAMP_TO_EDGE; case CLAMP_TO_BORDER: return GL_CLAMP_TO_EDGE; }
}

// ---- backend payloads ---------------------------------------------------

struct RendererWebgl { bool available; }
struct PhysicalAdapterWebgl { bool available; }
struct DeviceWebgl { bool alive; }
struct QueueWebgl { bool alive; }
struct TimelineWebgl { ulong completed; }
struct PoolWebgl { bool alive; }
struct BufferWebgl { GlHandle buffer; uint target; uint size; }
struct ImageWebgl { GlHandle texture; uint width, height; WebglFormat format; }
struct ImageViewWebgl { GlHandle texture; GlHandle framebuffer; uint width, height; }
struct SamplerWebgl { GlHandle sampler; }
struct ShaderWebgl { GlHandle program; }

struct WebglAttachment
{
	GlHandle texture;
	GlHandle framebuffer;
	LoadOp load_op;
	Rect rect;
	float[4] clear_color;
}

enum WebglOp : char
{
	BEGIN_RENDERING, END_RENDERING, VIEWPORT, SCISSOR, PIPELINE, PUSH_CONSTANTS,
	DESCRIPTORS, VERTEX_BUFFERS, INDEX_BUFFER, DRAW, DRAW_INDEXED, CLEAR_REGIONS,
	COPY_BUFFER, COPY_BUFFER_TEXTURE, COPY_TEXTURE_BUFFER, COPY_IMAGE,
}

struct WebglCommand
{
	WebglOp op;
	Viewport viewport;
	Rect rect;
	Pipeline* pipeline;
	Buffer* buffer;
	Buffer* src;
	Buffer* dst;
	Image* image;
	Image* image_dst;
	ImageCopyDesc image_copy;
	IndexType index_type;
	ulong offset;
	ulong src_offset;
	ulong dst_offset;
	ulong size;
	uint count;
	uint instance_count;
	uint first;
	int vertex_offset;
	uint first_binding;
	Buffer*[8] buffers;
	ulong[8] offsets;
	uint buffer_count;
	DescriptorBinding[MAX_TEXTURE_BINDINGS] descriptors;
	uint descriptor_count;
	char[256] push_data;
	uint push_len;
	WebglAttachment[8] attachments;
	uint attachment_count;
	GlHandle framebuffer;
	uint width, height;
	bool has_depth;
	bool clear_depth;
	float depth;
}

const uint WEBGL_MAX_COMMANDS = 32;

struct CmdWebgl
{
	WebglCommand[] commands;
	uint command_count;
	bool pass_open;
	Pipeline* current_pipeline;
	GlHandle fence;
}

struct CommandRingElementWebgl { GlHandle fence; }
struct CommandRingBufferWebgl <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE> { bool alive; }
struct PipelineWebgl
{
	GlHandle program;
	GlHandle vao;
	TextureSlot[MAX_TEXTURE_BINDINGS] texture_slots;
	uint texture_slot_count;
	uint push_constant_size;
	VertexLayout vertex_layout;
	bool has_vertex_layout;
	RasterState raster;
	DepthState depth;
	bool has_depth;
	BlendState blend;
	bool blend_enabled;
}
struct SwapchainWebgl
{
	Format format;
	uint width, height;
	GlHandle color_texture;
	GlHandle framebuffer;
}

// ---- renderer, adapter, device, queue and lifetime ---------------------

fn void? renderer_init_webgl(RendererWebglOptions opts, Allocator allocator = mem)
{
	if (gl_available() == 0) return UNSUPPORTED_BACKEND~;
	renderer.backend = WEBGL;
	renderer.webgl = { .available = true };
	return;
}

fn void renderer_deinit_webgl()
{
	renderer.webgl.available = false;
}

fn List{PhysicalAdapter}? enumerate_adapters_webgl(Allocator allocator = mem)
{
	if (gl_available() == 0) return UNSUPPORTED_BACKEND~;
	List{PhysicalAdapter} adapters;
	adapters.init(allocator, 1);
	PhysicalAdapter a = physical_adapter_web_defaults();
	a.backend.webgl.available = true;
	char[256] name;
	uint n = gl_renderer_name(&name[0], 256);
	physical_adapter_set_name(&a, (String)name[:n]);
	a.adapter_type = OTHER;
	adapters.push(a);
	return adapters;
}

fn Device? device_init_webgl(PhysicalAdapter* adapter, Allocator allocator = mem)
{
	if (adapter == null || !adapter.backend.webgl.available) return INITIALIZATION_FAILED~;
	Device d = {};
	d.adapter = *adapter;
	d.allocator = allocator;
	d.graphics_queue.backend.webgl.alive = true;
	d.compute_queue = d.graphics_queue;
	d.transfer_queue = d.graphics_queue;
	d.has_compute_queue = true;
	d.has_transfer_queue = true;
	d.backend.webgl.alive = true;
	return d;
}

fn void device_deinit_webgl(Device* d)
{
	if (d == null) return;
	d.backend.webgl.alive = false;
}

fn void? queue_wait_idle_webgl(Queue* q, Device* device)
{
	if (q == null || !q.backend.webgl.alive) return INITIALIZATION_FAILED~;
	gl_finish();
	return;
}

fn Pool? pool_init_webgl(Device* device, Queue* queue)
{
	if (device == null || queue == null) return INITIALIZATION_FAILED~;
	Pool p = {};
	p.backend.webgl.alive = true;
	return p;
}

fn void? pool_reset_webgl(Pool* p, Device* device)
{
	if (p == null || !p.backend.webgl.alive) return INITIALIZATION_FAILED~;
	return;
}

fn void pool_deinit_webgl(Pool* p, Device* device)
{
	if (p != null) p.backend.webgl.alive = false;
}

fn Timeline? timeline_init_webgl(Device* device)
{
	if (device == null) return INITIALIZATION_FAILED~;
	Timeline t = {};
	t.backend.webgl.completed = 0;
	return t;
}

fn void timeline_deinit_webgl(Timeline* t, Device* device) {}

fn ulong? timeline_completed_webgl(Timeline* t, Device* device)
{
	if (t == null) return INITIALIZATION_FAILED~;
	return t.backend.webgl.completed;
}

fn void? queue_submit_webgl(Queue* q, Device* device, QueueSubmitDesc desc)
{
	if (q == null || device == null) return INITIALIZATION_FAILED~;
	foreach (cmd : desc.cmds)
	{
		if (cmd == null) continue;
		webgl_replay_cmd(cmd, device);
	}
	if (desc.completion != null)
	{
		if (desc.completion.backend.webgl.fence != 0) gl_delete_sync(desc.completion.backend.webgl.fence);
		desc.completion.backend.webgl.fence = gl_fence_sync();
	}
	foreach (signal : desc.signals)
	{
		if (signal.timeline != null && signal.value > signal.timeline.signal_value) signal.timeline.signal_value = signal.value;
	}
	return;
}

// ---- resource creation --------------------------------------------------

fn Buffer? buffer_init_general_webgl(Device* device, BufferDesc desc)
{
	uint size = web_buffer_size(desc.size, 256 * 1024 * 1024)!!;
	Buffer b = {};
	uint target = webgl_buffer_target(desc.usage);
	b.backend.webgl.buffer = gl_create_buffer(target, size, webgl_buffer_usage(desc));
	b.backend.webgl.size = size;
	b.backend.webgl.target = target;
	if (b.backend.webgl.buffer == 0) return OUT_OF_DEVICE_MEMORY~;
	b.cookie = b.backend.webgl.buffer;
	return b;
}

fn void buffer_deinit_webgl(Buffer* b, Device* device)
{
	if (b != null && b.backend.webgl.buffer != 0) gl_delete_buffer(b.backend.webgl.buffer);
	if (b != null) b.backend.webgl.buffer = 0;
}

fn void buffer_write_webgl(Buffer* b, Device* device, sz offset, char[] bytes)
{
	if (b == null || b.backend.webgl.buffer == 0) return;
	web_buffer_write_range(offset, bytes.len, (sz)b.backend.webgl.size, 1)!!;
	gl_buffer_sub_data(b.backend.webgl.target, b.backend.webgl.buffer, (uint)offset, bytes.ptr, (uint)bytes.len);
}

fn void buffer_flush_webgl(Buffer* b, Device* device) {}

fn Image? image_init_webgl(Device* device, ImageDesc desc)
{
	if (desc.image_type != D2 || desc.width == 0 || desc.height == 0 || desc.mip_levels == 0) return UNSUPPORTED_FEATURE~;
	WebglFormat f = webgl_format(desc.format);
	if (!f.valid) return UNSUPPORTED_FEATURE~;
	Image image = {};
	image.backend.webgl.texture = gl_create_texture_2d(f.internal_format, desc.width, desc.height, desc.mip_levels);
	image.backend.webgl.width = desc.width;
	image.backend.webgl.height = desc.height;
	image.backend.webgl.format = f;
	if (image.backend.webgl.texture == 0) return OUT_OF_DEVICE_MEMORY~;
	image.cookie = image.backend.webgl.texture;
	return image;
}

fn void image_deinit_webgl(Image* image, Device* device)
{
	if (image != null && image.backend.webgl.texture != 0) gl_delete_texture(image.backend.webgl.texture);
	if (image != null) image.backend.webgl.texture = 0;
}

fn void? image_upload_webgl(Image* image, Device* device, ImageUploadOptions options)
{
	if (image == null || image.backend.webgl.texture == 0) return INITIALIZATION_FAILED~;
	if (options.data.len == 0) return;
	WebglFormat f = image.backend.webgl.format;
	gl_tex_sub_image_2d(image.backend.webgl.texture, options.mip_level, (int)options.origin.x, (int)options.origin.y, options.extent.width, options.extent.height, f.format, f.type, options.data.ptr, (uint)options.data.len);
	return;
}

fn ImageView? image_view_init_webgl(Device* device, Image* image, ViewDesc desc)
{
	if (image == null || image.backend.webgl.texture == 0) return INITIALIZATION_FAILED~;
	ImageView v = {};
	v.backend.webgl.texture = image.backend.webgl.texture;
	v.backend.webgl.width = image.backend.webgl.width;
	v.backend.webgl.height = image.backend.webgl.height;
	if (desc.view_type == COLOR_ATTACHMENT || desc.view_type == DEPTH_STENCIL_ATTACHMENT)
	{
		v.backend.webgl.framebuffer = gl_create_framebuffer();
		uint attachment = desc.view_type == COLOR_ATTACHMENT ? GL_COLOR_ATTACHMENT0 : GL_DEPTH_STENCIL_ATTACHMENT;
		gl_framebuffer_texture_2d(v.backend.webgl.framebuffer, attachment, v.backend.webgl.texture);
		if (gl_check_framebuffer_status(v.backend.webgl.framebuffer) != 0x8CD5) return INITIALIZATION_FAILED~;
	}
	v.cookie = image.cookie ^ ((ulong)desc.base_mip << 32) ^ desc.base_layer + 1;
	return v;
}

fn void image_view_deinit_webgl(ImageView* v, Device* device)
{
	if (v != null && v.backend.webgl.framebuffer != 0) gl_delete_framebuffer(v.backend.webgl.framebuffer);
	if (v != null) v.backend.webgl.framebuffer = 0;
}

fn Sampler? sampler_init_webgl(Device* device, SamplerDesc desc)
{
	if (desc.address_u == CLAMP_TO_BORDER || desc.address_v == CLAMP_TO_BORDER || desc.address_w == CLAMP_TO_BORDER) return UNSUPPORTED_FEATURE~;
	uint min_filter = desc.min_filter == LINEAR ? GL_LINEAR : GL_NEAREST;
	if (desc.mip_map_mode == LINEAR) min_filter = desc.min_filter == LINEAR ? 0x2703 : 0x2701;
	uint mag_filter = desc.mag_filter == LINEAR ? GL_LINEAR : GL_NEAREST;
	Sampler s = {};
	s.backend.webgl.sampler = gl_create_sampler(min_filter, mag_filter, webgl_wrap(desc.address_u), webgl_wrap(desc.address_v), webgl_wrap(desc.address_w));
	if (s.backend.webgl.sampler == 0) return OUT_OF_DEVICE_MEMORY~;
	s.cookie = s.backend.webgl.sampler;
	return s;
}

fn void sampler_deinit_webgl(Sampler* s, Device* device)
{
	if (s != null && s.backend.webgl.sampler != 0) gl_delete_sampler(s.backend.webgl.sampler);
	if (s != null) s.backend.webgl.sampler = 0;
}

fn Shader? shader_init_graphics_webgl(Device* device, ShaderGraphicsOptions options)
{
	if (!options.has_vertex_stage || !options.has_fragment_stage) return MISSING_SHADER_STAGE~;
	char[2048] error;
	GlHandle program = gl_create_program(options.vertex_stage.data.ptr, (uint)options.vertex_stage.data.len, options.fragment_stage.data.ptr, (uint)options.fragment_stage.data.len, &error[0], 2048);
	if (program == 0) return SHADER_COMPILATION_FAILED~;
	Shader s = {};
	s.backend.webgl.program = program;
	s.cookie = program;
	return s;
}

fn ShaderStages shader_stages_webgl(Shader* s)
{
	return SHADER_STAGES_GRAPHICS;
}

fn void shader_deinit_webgl(Shader* s, Device* device)
{
	if (s != null && s.backend.webgl.program != 0) gl_delete_program(s.backend.webgl.program);
	if (s != null) s.backend.webgl.program = 0;
}

fn Pipeline? pipeline_init_graphics_webgl(Device* device, PipelineGraphicsOptions options)
{
	if (options.shader == null || options.shader.backend.webgl.program == 0) return INITIALIZATION_FAILED~;
	if (options.colors.len > 1) return MULTIPLE_RENDER_TARGETS_UNSUPPORTED~;
	TextureSlot[MAX_TEXTURE_BINDINGS] slots;
	uint slot_count = resolve_texture_slots(options.texture_bindings, &slots)!;
	Pipeline p = {};
	p.backend.webgl.program = options.shader.backend.webgl.program;
	p.backend.webgl.vao = gl_create_vertex_array();
	p.backend.webgl.texture_slots = slots;
	p.backend.webgl.texture_slot_count = slot_count;
	p.backend.webgl.push_constant_size = options.push_constant_size;
	p.backend.webgl.has_vertex_layout = options.has_vertex_layout;
	p.backend.webgl.vertex_layout = options.vertex_layout;
	p.backend.webgl.raster = options.raster;
	p.backend.webgl.depth = options.depth;
	p.backend.webgl.has_depth = options.has_depth;
	if (options.colors.len > 0)
	{
		p.backend.webgl.blend = options.colors[0].blend;
		p.backend.webgl.blend_enabled = options.colors[0].has_blend;
	}
	if (!p.backend.webgl.blend_enabled) p.backend.webgl.blend.write_mask = WRITE_MASK_ALL;
	foreach (binding : options.texture_bindings)
	{
		if (gl_set_sampler_unit(p.backend.webgl.program, binding.name.ptr, (uint)binding.name.len, binding.binding) != 0) return TEXTURE_BINDING_NOT_FOUND~;
	}
	p.cookie = p.backend.webgl.program;
	return p;
}

fn void pipeline_deinit_webgl(Pipeline* p, Device* device)
{
	if (p == null) return;
	if (p.backend.webgl.vao != 0) gl_delete_vertex_array(p.backend.webgl.vao);
	p.backend.webgl.vao = 0;
}

// ---- command recording and replay --------------------------------------

fn WebglCommand* webgl_push(Cmd* c, WebglOp op)
{
	if (c == null || c.backend.webgl.command_count >= WEBGL_MAX_COMMANDS) return null;
	WebglCommand* out = &c.backend.webgl.commands[c.backend.webgl.command_count];
	*out = {};
	out.op = op;
	c.backend.webgl.command_count += 1;
	return out;
}

fn Cmd? cmd_init_webgl(Device* device, Pool* pool)
{
	if (device == null || pool == null) return INITIALIZATION_FAILED~;
	WebglCommand[] commands = alloc::alloc_array_try(device.allocator, WebglCommand, WEBGL_MAX_COMMANDS)!;
	commands[..] = {};
	return { .barrier_capabilities = {}, .backend.webgl = { .commands = commands } };
}

fn void cmd_deinit_webgl(Cmd* c, Device* device, Pool* pool)
{
	if (c == null) return;
	if (c.backend.webgl.commands.ptr != null) alloc::free(device.allocator, c.backend.webgl.commands.ptr);
	c.backend.webgl = {};
}
fn void? cmd_begin_webgl(Cmd* c, Device* device) { if (c == null) return INITIALIZATION_FAILED~; c.backend.webgl.command_count = 0; return; }
fn void? cmd_end_webgl(Cmd* c, Device* device) { if (c == null) return INITIALIZATION_FAILED~; return; }
fn void cmd_set_viewport_webgl(Cmd* c, Device* device, Viewport vp) { WebglCommand* x = webgl_push(c, VIEWPORT); if (x != null) x.viewport = vp; }
fn void cmd_set_scissor_webgl(Cmd* c, Device* device, Rect rect) { WebglCommand* x = webgl_push(c, SCISSOR); if (x != null) x.rect = rect; }
fn void cmd_bind_pipeline_webgl(Cmd* c, Device* device, Pipeline* p) { WebglCommand* x = webgl_push(c, PIPELINE); if (x != null) x.pipeline = p; }
fn void cmd_set_push_constants_webgl(Cmd* c, Device* device, Pipeline* p, char[] bytes)
{
	WebglCommand* x = webgl_push(c, PUSH_CONSTANTS); if (x == null) return;
	x.pipeline = p; x.push_len = (uint)min(bytes.len, (sz)x.push_data.len); x.push_data[:x.push_len] = bytes[:x.push_len];
}
fn void cmd_draw_webgl(Cmd* c, Device* device, uint vertex_count, uint instance_count, uint first_vertex, uint first_instance) { WebglCommand* x = webgl_push(c, DRAW); if (x != null) { x.count = vertex_count; x.instance_count = instance_count; x.first = first_vertex; } }
fn void cmd_draw_indexed_webgl(Cmd* c, Device* device, uint index_count, uint instance_count, uint first_index, int vertex_offset, uint first_instance) { WebglCommand* x = webgl_push(c, DRAW_INDEXED); if (x != null) { x.count = index_count; x.instance_count = instance_count; x.first = first_index; x.vertex_offset = vertex_offset; } }
fn void cmd_draw_indirect_webgl(Cmd* c, Device* device, Buffer* b, ulong offset, uint draw_count, uint stride) {}
fn void cmd_draw_indexed_indirect_webgl(Cmd* c, Device* device, Buffer* b, ulong offset, uint draw_count, uint stride) {}
fn void cmd_draw_indirect_count_webgl(Cmd* c, Device* device, Buffer* b, ulong offset, Buffer* count_buffer, ulong count_offset, uint max_draw_count, uint stride) {}
fn void cmd_clear_attachment_regions_webgl(Cmd* c, Device* device, CmdClearRegion[] regions)
{
	WebglCommand* x = webgl_push(c, CLEAR_REGIONS); if (x == null) return; x.attachment_count = (uint)min(regions.len, (sz)8); foreach (i, region : regions[:x.attachment_count]) { x.attachments[i].clear_color = region.color; x.attachments[i].rect = region.rect; x.attachments[i].load_op = CLEAR; x.attachments[i].framebuffer = 0; x.attachments[i].texture = 0; }
}
fn void? cmd_bind_descriptors_webgl(Cmd* c, Device* device, Pipeline* p, DescriptorBinding[] bindings)
{
	WebglCommand* x = webgl_push(c, DESCRIPTORS); if (x == null) return INITIALIZATION_FAILED~; x.pipeline = p; x.descriptor_count = (uint)min(bindings.len, (sz)MAX_TEXTURE_BINDINGS); x.descriptors[:x.descriptor_count] = bindings[:x.descriptor_count]; return;
}
fn void cmd_begin_rendering_webgl(Cmd* c, Device* device, CmdBeginRenderingOptions options)
{
	WebglCommand* x = webgl_push(c, BEGIN_RENDERING); if (x == null) return; x.rect = options.render_area; x.width = options.render_area.width; x.height = options.render_area.height; x.attachment_count = (uint)min(options.color_attachments.len, (sz)8); foreach (i, a : options.color_attachments[:x.attachment_count]) { x.attachments[i].texture = a.view.backend.webgl.texture; x.attachments[i].framebuffer = a.view.backend.webgl.framebuffer; x.attachments[i].load_op = a.load_op; x.attachments[i].clear_color = a.clear_color; } if (x.attachment_count > 0) x.framebuffer = x.attachments[0].framebuffer; c.backend.webgl.pass_open = true;
	if (options.has_depth_attachment)
	{
		x.has_depth = true;
		x.clear_depth = options.depth_attachment.load_op == CLEAR;
		x.depth = options.depth_attachment.clear_depth;
		if (x.framebuffer == 0) x.framebuffer = options.depth_attachment.view.backend.webgl.framebuffer;
		gl_framebuffer_texture_2d(x.framebuffer, GL_DEPTH_ATTACHMENT, options.depth_attachment.view.backend.webgl.texture);
	}
}
fn void cmd_end_rendering_webgl(Cmd* c, Device* device) { WebglCommand* x = webgl_push(c, END_RENDERING); if (x != null) c.backend.webgl.pass_open = false; }
fn void cmd_bind_vertex_buffers_webgl(Cmd* c, Device* device, uint first_binding, Buffer*[] buffers, ulong[] offsets = {})
{
	WebglCommand* x = webgl_push(c, VERTEX_BUFFERS); if (x == null) return; x.first_binding = first_binding; x.buffer_count = (uint)min(buffers.len, (sz)8); foreach (i, b : buffers[:x.buffer_count]) { x.buffers[i] = b; x.offsets[i] = offsets.len == buffers.len ? offsets[i] : 0; }
}
fn void cmd_bind_index_buffer_webgl(Cmd* c, Device* device, Buffer* b, IndexType index_type, ulong offset = 0) { WebglCommand* x = webgl_push(c, INDEX_BUFFER); if (x != null) { x.buffer = b; x.index_type = index_type; x.offset = offset; } }
fn void cmd_resource_barrier_webgl(Cmd* c, Device* device, MemoryBarrier[] memory, BufferBarrier[] buffers, ImageBarrier[] images) {}
fn void cmd_copy_buffer_webgl(Cmd* c, Device* device, Buffer* src, ulong src_offset, Buffer* dst, ulong dst_offset, ulong size) { WebglCommand* x = webgl_push(c, COPY_BUFFER); if (x != null) { x.src = src; x.dst = dst; x.src_offset = src_offset; x.dst_offset = dst_offset; x.size = size; } }
fn void cmd_copy_buffer_to_texture_webgl(Cmd* c, Device* device, CmdCopyBufferToTextureOptions options) { WebglCommand* x = webgl_push(c, COPY_BUFFER_TEXTURE); if (x != null) { x.src = options.src; x.image = options.dst; x.offset = options.buffer_offset; x.rect = { .x = options.x, .y = options.y, .width = options.width, .height = options.height }; } }
fn void cmd_copy_texture_to_buffer_webgl(Cmd* c, Device* device, CmdCopyTextureToBufferOptions options) {}
fn void cmd_copy_image_webgl(Cmd* c, Device* device, Image* src, Image* dst, ImageCopyDesc desc) { WebglCommand* x = webgl_push(c, COPY_IMAGE); if (x != null) { x.image = src; x.image_dst = dst; x.image_copy = desc; } }

fn void webgl_apply_pipeline(PipelineWebgl* p)
{
	gl_use_program(p.program);
	gl_bind_vertex_array(p.vao);
	gl_set_enabled(GL_DEPTH_TEST, p.has_depth);
	if (p.has_depth) { gl_depth_func(webgl_compare(p.depth.compare)); gl_depth_mask(p.depth.write); }
	gl_set_enabled(GL_CULL_FACE, p.raster.cull_mode != NONE);
	if (p.raster.cull_mode != NONE) gl_cull_face(p.raster.cull_mode == FRONT ? GL_FRONT : GL_BACK);
	gl_front_face(p.raster.front_face == CLOCKWISE ? GL_CW : GL_CCW);
	// GL blend state is global, so set it on every pipeline. The front contract
	// supplies BLEND_STATE_STRAIGHT_ALPHA for ordinary translucent targets.
	gl_set_enabled(GL_BLEND, p.blend_enabled);
	if (p.blend_enabled)
	{
		gl_blend_func_separate(webgl_blend_factor(p.blend.src_color), webgl_blend_factor(p.blend.dst_color), webgl_blend_factor(p.blend.src_alpha), webgl_blend_factor(p.blend.dst_alpha));
		gl_blend_equation_separate(webgl_blend_op(p.blend.color_op), webgl_blend_op(p.blend.alpha_op));
	}
	gl_color_mask(p.blend.write_mask.r, p.blend.write_mask.g, p.blend.write_mask.b, p.blend.write_mask.a);
}

fn void webgl_replay_cmd(Cmd* c, Device* device)
{
	int target_height = 0;
	foreach (cmd : c.backend.webgl.commands[:c.backend.webgl.command_count])
	{
		switch (cmd.op)
		{
			case BEGIN_RENDERING:
				target_height = (int)cmd.height;
				gl_bind_framebuffer(cmd.framebuffer);
				gl_set_enabled(GL_SCISSOR_TEST, false);
				gl_color_mask(true, true, true, true);
				if (cmd.attachment_count > 0 && cmd.attachments[0].load_op == CLEAR) { float[4] v = cmd.attachments[0].clear_color; gl_clear_color(v[0], v[1], v[2], v[3]); }
				if (cmd.has_depth && cmd.clear_depth) { gl_depth_mask(true); gl_clear_depth(cmd.depth); }
			case END_RENDERING:
				gl_set_enabled(GL_SCISSOR_TEST, false);
				break;
			case VIEWPORT:
				Viewport v = cmd.viewport; int h = (int)v.height; int y = target_height - (int)v.y - (h < 0 ? -h : h); if (h < 0) h = -h; gl_viewport((int)v.x, y, (int)v.width, h, v.min_depth, v.max_depth);
			case SCISSOR:
				gl_set_enabled(GL_SCISSOR_TEST, true); gl_scissor(cmd.rect.x, target_height - cmd.rect.y - (int)cmd.rect.height, cmd.rect.width, cmd.rect.height);
			case PIPELINE:
				if (cmd.pipeline != null) { c.backend.webgl.current_pipeline = cmd.pipeline; webgl_apply_pipeline(&cmd.pipeline.backend.webgl); }
			case PUSH_CONSTANTS:
				if (cmd.pipeline != null && cmd.push_len > 0) { char[] name = "push_constants"; int location = gl_uniform_location(cmd.pipeline.backend.webgl.program, name.ptr, (uint)name.len); gl_uniform_raw(location, 0x8B50, &cmd.push_data[0], cmd.push_len); }
			case DESCRIPTORS:
				if (cmd.pipeline != null) foreach (b : cmd.descriptors[:cmd.descriptor_count]) foreach (i, slot : cmd.pipeline.backend.webgl.texture_slots[:cmd.pipeline.backend.webgl.texture_slot_count]) { if (slot.name_hash == b.handle.hash && b.descriptor.type == SAMPLED_IMAGE) gl_bind_texture_unit(slot.binding, (GlHandle)b.descriptor.handle, 0); if (slot.has_sampler_name_hash && slot.sampler_name_hash == b.handle.hash && b.descriptor.type == SAMPLER) gl_bind_texture_unit(slot.binding, 0, (GlHandle)b.descriptor.handle); }
			case VERTEX_BUFFERS:
				if (c.backend.webgl.current_pipeline != null) foreach (i, b : cmd.buffers[:cmd.buffer_count]) if (b != null) foreach (a : c.backend.webgl.current_pipeline.backend.webgl.vertex_layout.attributes) gl_vertex_attrib_pointer(c.backend.webgl.current_pipeline.backend.webgl.vao, b.backend.webgl.buffer, a.location, webgl_components(a.format), c.backend.webgl.current_pipeline.backend.webgl.vertex_layout.stride, (uint)cmd.offsets[i] + a.offset);
			case INDEX_BUFFER:
				if (c.backend.webgl.current_pipeline != null && cmd.buffer != null) gl_vao_set_element_buffer(c.backend.webgl.current_pipeline.backend.webgl.vao, cmd.buffer.backend.webgl.buffer);
			case DRAW:
				if (c.backend.webgl.current_pipeline != null) gl_draw_arrays(webgl_topology(c.backend.webgl.current_pipeline.backend.webgl.raster.topology), cmd.first, cmd.count, cmd.instance_count);
			case DRAW_INDEXED:
				if (c.backend.webgl.current_pipeline != null) gl_draw_elements(webgl_topology(c.backend.webgl.current_pipeline.backend.webgl.raster.topology), cmd.count, cmd.index_type == UINT16 ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT, (uint)cmd.offset, cmd.instance_count);
			case CLEAR_REGIONS:
				foreach (a : cmd.attachments[:cmd.attachment_count]) { gl_scissor(a.rect.x, target_height - a.rect.y - (int)a.rect.height, a.rect.width, a.rect.height); gl_clear_color(a.clear_color[0], a.clear_color[1], a.clear_color[2], a.clear_color[3]); }
			case COPY_BUFFER:
				if (cmd.src != null && cmd.dst != null) gl_copy_buffer_sub_data(cmd.src.backend.webgl.target, cmd.src.backend.webgl.buffer, (uint)cmd.src_offset, cmd.dst.backend.webgl.target, cmd.dst.backend.webgl.buffer, (uint)cmd.dst_offset, (uint)cmd.size);
			case COPY_BUFFER_TEXTURE:
				if (cmd.src != null && cmd.image != null) gl_tex_sub_image_2d_from_buffer(cmd.image.backend.webgl.texture, 0, cmd.rect.x, cmd.rect.y, cmd.rect.width, cmd.rect.height, cmd.image.backend.webgl.format.format, cmd.image.backend.webgl.format.type, cmd.src.backend.webgl.buffer, (uint)cmd.offset, 0);
			case COPY_TEXTURE_BUFFER:
				// Texture readback is not exposed by the browser bridge yet.
				break;
			case COPY_IMAGE:
				// WebGL2 has no texture-to-texture copy helper in the bridge. The
				// common path uploads through a staging buffer instead.
				break;
		}
	}
}

// ---- command ring and swapchain ----------------------------------------

fn void? command_ring_element_wait_webgl(CommandRingElement* e, Device* device)
{
	if (e == null) return INITIALIZATION_FAILED~;
	if (e.backend.webgl.fence != 0 && !gl_client_wait_sync(e.backend.webgl.fence)) return TIMEOUT~;
	if (e.backend.webgl.fence != 0) { gl_delete_sync(e.backend.webgl.fence); e.backend.webgl.fence = 0; }
	return;
}

fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init_webgl(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} r = { .pool_index = (sz)POOL_COUNT };
	r.backend.webgl.alive = true;
	for (sz i = 0; i < (sz)POOL_COUNT; i++)
	{
		r.pools[i] = pool_init_webgl(device, queue)!;
		for (sz j = 0; j < (sz)CMD_PER_POOL; j++) r.cmds[i][j] = cmd_init_webgl(device, &r.pools[i])!;
	}
	return r;
}

fn void command_ring_buffer_deinit_webgl(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	if (r == null) return;
	for (sz i = 0; i < (sz)POOL_COUNT; i++)
	{
		for (sz j = 0; j < (sz)CMD_PER_POOL; j++) cmd_deinit_webgl(&r.cmds[i][j], device, &r.pools[i]);
		pool_deinit_webgl(&r.pools[i], device);
	}
	r.backend.webgl.alive = false;
}

fn CommandRingElement command_ring_buffer_get_webgl(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingElement e = {};
	if (r == null || r.pool_index >= (sz)POOL_COUNT || num_cmds == 0 || num_cmds > (sz)CMD_PER_POOL - r.cmd_index) return e;
	e.pool = &r.pools[r.pool_index];
	e.cmds = r.cmds[r.pool_index][r.cmd_index .. r.cmd_index + num_cmds];
	e.backend.webgl = {};
	r.cmd_index += num_cmds;
	return e;
}

fn Swapchain? swapchain_init_webgl(Device* device, SwapchainDesc desc, Allocator allocator = mem)
{
	swapchain_validate_desc(desc)!;
	if (desc.source.kind != WINDOW || desc.source.window.kind != CANVAS) return UNSUPPORTED_FEATURE~;
	Swapchain s = {};
	s.width = desc.width; s.height = desc.height; s.image_count = 1; s.present_queue = desc.queue; s.allocator = allocator;
	s.backend.webgl.format = RGBA8_UNORM; s.backend.webgl.width = desc.width; s.backend.webgl.height = desc.height;
	s.backend.webgl.color_texture = gl_create_texture_2d(GL_RGBA8, desc.width, desc.height, 1);
	s.backend.webgl.framebuffer = gl_create_framebuffer();
	gl_framebuffer_texture_2d(s.backend.webgl.framebuffer, GL_COLOR_ATTACHMENT0, s.backend.webgl.color_texture);
	if (gl_check_framebuffer_status(s.backend.webgl.framebuffer) != 0x8CD5) return INITIALIZATION_FAILED~;
	return s;
}

fn void swapchain_deinit_webgl(Swapchain* s, Device* device)
{
	if (s == null) return;
	if (s.backend.webgl.framebuffer != 0) gl_delete_framebuffer(s.backend.webgl.framebuffer);
	if (s.backend.webgl.color_texture != 0) gl_delete_texture(s.backend.webgl.color_texture);
	s.backend.webgl.framebuffer = 0; s.backend.webgl.color_texture = 0;
}

fn void? swapchain_recreate_webgl(Swapchain* s, Device* device, ushort width, ushort height)
{
	if (s == null || width == 0 || height == 0) return INITIALIZATION_FAILED~;
	if (s.backend.webgl.framebuffer != 0) gl_delete_framebuffer(s.backend.webgl.framebuffer);
	if (s.backend.webgl.color_texture != 0) gl_delete_texture(s.backend.webgl.color_texture);
	s.backend.webgl.color_texture = gl_create_texture_2d(GL_RGBA8, width, height, 1);
	s.backend.webgl.framebuffer = gl_create_framebuffer();
	gl_framebuffer_texture_2d(s.backend.webgl.framebuffer, GL_COLOR_ATTACHMENT0, s.backend.webgl.color_texture);
	s.width = width; s.height = height; s.backend.webgl.width = width; s.backend.webgl.height = height;
	return;
}

fn SwapchainStatus? swapchain_acquire_next_image_webgl(Swapchain* s, Device* device, uint* out_index) { if (s == null || s.image_count == 0) return OUT_OF_DATE~; if (out_index != null) *out_index = 0; return OK; }
fn Image swapchain_image_webgl(Swapchain* s, uint index) { if (s == null || index != 0) return {}; Image i = {}; i.cookie = s.backend.webgl.color_texture; i.backend.webgl.texture = s.backend.webgl.color_texture; i.backend.webgl.width = s.width; i.backend.webgl.height = s.height; i.backend.webgl.format = webgl_format(RGBA8_UNORM); return i; }
fn ImageView swapchain_image_view_webgl(Swapchain* s, uint index) { if (s == null || index != 0) return {}; ImageView v = {}; v.cookie = s.backend.webgl.color_texture; v.backend.webgl.texture = s.backend.webgl.color_texture; v.backend.webgl.framebuffer = s.backend.webgl.framebuffer; v.backend.webgl.width = s.width; v.backend.webgl.height = s.height; return v; }
fn SwapchainStatus? swapchain_frame_submit_webgl(Swapchain* s, Device* device, Queue* queue, SwapchainFrameSubmit submit)
{
	if (s == null || submit.image_index != 0) return OUT_OF_DATE~;
	queue_submit_webgl(queue, device, { .cmds = submit.cmds, .signals = {} })!;
	gl_blit_to_canvas(s.backend.webgl.framebuffer, s.width, s.height);
	if (submit.timeline != null) submit.timeline.backend.webgl.completed = submit.signal_value != 0 ? submit.signal_value : submit.timeline.signal_value;
	if (submit.completion != null) submit.completion.backend.webgl.fence = gl_fence_sync();
	return OK;
}

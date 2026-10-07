// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan ImGui renderer. This file is deliberately behind RHI_IMGUI: the
// vendor/imgui_c shim is an optional application dependency and must not make
// the regular RHI (or its other backends) require libimgui.
module rhi @feat(RHI_IMGUI & RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import std::core::mem;
import rhi::alloc;

const uint IMGUI_FRAMES_IN_FLIGHT = 3;
const uint IMGUI_INIT_VERTEX_CAPACITY = 64 * 1024;
const uint IMGUI_INIT_INDEX_CAPACITY = 128 * 1024;
const ulong IMGUI_PIPELINE_KEY = 0x1697_D00D_1697_D00D;
const uint IMGUI_DRAW_VERT_STRIDE = 20;
const uint IMGUI_DRAW_IDX_STRIDE = 2;
const uint IMGUI_BACKEND_FLAGS_RENDERER_HAS_VTX_OFFSET = 1 << 3;

// SPIR-V blobs are generated from examples/assets/imgui.slang (slangc -target
// spirv, per examples/03_imgui/shaders.txt), or copy them from
// build/examples/03_imgui/shaders after `./build.py shaders/examples build`.
const char[*] IMGUI_VERT_SPV @align(4) = $embed("shaders/imgui.vert.spv");
const char[*] IMGUI_FRAG_SPV @align(4) = $embed("shaders/imgui.frag.spv");

// The C API exposes ImGui's public structs directly. Keep only the fields the
// renderer reads, with padding that preserves the vendor/imgui_c/imgui 1.93.0 WIP ABI. The offsets
// are checked by test/vendor/imgui/imgui_test.c3.
struct ImguiVec2 { float x; float y; }
struct ImguiVec4 { float x; float y; float z; float w; }

struct ImguiIO
{

uint config_flags;

uint backend_flags;

ImguiVec2 display_size;

ImguiVec2 display_framebuffer_scale;

float delta_time;

float ini_saving_rate;

void* ini_filename;

void* log_filename;

void* user_data;

void* fonts;

char[120] _to_capture_flags;

bool want_capture_mouse;

bool want_capture_keyboard;
}

struct ImguiVectorDrawCmd
{

int size;

int capacity;

void* data;
}

struct ImguiVectorDrawIdx
{

int size;

int capacity;

ushort* data;
}

struct ImguiVectorDrawVert
{

int size;

int capacity;

void* data;
}

struct ImguiDrawVert
{

ImguiVec2 pos;

ImguiVec2 uv;

uint col;
}

struct ImguiDrawCmd
{

ImguiVec4 clip_rect;

char[16] tex_ref;

uint vtx_offset;

uint idx_offset;

uint elem_count;

void* user_callback;

void* user_callback_data;

int user_callback_data_size;

int user_callback_data_offset;
}

struct ImguiDrawList
{

ImguiVectorDrawCmd cmd_buffer;

ImguiVectorDrawIdx idx_buffer;

ImguiVectorDrawVert vtx_buffer;

char[176] _rest;
}

struct ImguiVectorDrawListPtr
{

int size;

int capacity;

ImguiDrawList** data;
}

struct ImguiDrawData
{

bool valid;

int frame_count;

int total_idx_count;

int total_vtx_count;

ImguiVectorDrawListPtr cmd_lists;

ImguiVec2 display_pos;

ImguiVec2 display_size;

ImguiVec2 framebuffer_scale;

// OwnerViewport and Textures in ImGui's DrawData ABI.
char[16] _rest;

int cmd_lists_count;
}

// The names and signatures match the vendor/imgui_c shim (dear_bindings-style
// C names). No renderer stub is supplied when RHI_IMGUI is absent.
extern fn void* imgui_create_context(void* shared_font_atlas) @cname("ImGui_CreateContext");
extern fn void imgui_destroy_context(void* ctx) @cname("ImGui_DestroyContext");
extern fn void imgui_set_current_context(void* ctx) @cname("ImGui_SetCurrentContext");
extern fn ImguiIO* imgui_get_io() @cname("ImGui_GetIO");
extern fn void imgui_new_frame() @cname("ImGui_NewFrame");
extern fn void imgui_render() @cname("ImGui_Render");
extern fn ImguiDrawData* imgui_get_draw_data() @cname("ImGui_GetDrawData");
extern fn void imgui_style_colors_dark(void* dst) @cname("ImGui_StyleColorsDark");

extern fn void imgui_io_add_key_event(ImguiIO* io, int key, bool down) @cname("ImGuiIO_AddKeyEvent");
extern fn void imgui_io_add_mouse_pos_event(ImguiIO* io, float x, float y) @cname("ImGuiIO_AddMousePosEvent");
extern fn void imgui_io_add_mouse_button_event(ImguiIO* io, int button, bool down) @cname("ImGuiIO_AddMouseButtonEvent");
extern fn void imgui_io_add_mouse_wheel_event(ImguiIO* io, float x, float y) @cname("ImGuiIO_AddMouseWheelEvent");
extern fn void imgui_io_add_focus_event(ImguiIO* io, bool focused) @cname("ImGuiIO_AddFocusEvent");
extern fn void imgui_io_add_input_character(ImguiIO* io, uint c) @cname("ImGuiIO_AddInputCharacter");

extern fn void imgui_font_atlas_get_tex_data_rgba32(void* atlas, char** pixels, int* width, int* height, int* bytes_per_pixel) @cname("ImFontAtlas_GetTexDataAsRGBA32");
extern fn void imgui_font_atlas_set_tex_id(void* atlas, ulong id) @cname("ImFontAtlas_SetTexID");

struct ImguiPushConstants
{

float[2] scale;

float[2] translate;
}

struct ImguiLayer
{

void* ctx;

Program program;

Image font_image;

ImageView font_view;

Sampler sampler;

Descriptor tex_descriptor;

Descriptor sampler_descriptor;

Buffer vertex_buffer;

Buffer index_buffer;

alloc::SegmentAlloc vertex_alloc;

alloc::SegmentAlloc index_alloc;

Format color_format;

ulong frame_index;
}

fn void imgui_layer_cleanup(ImguiLayer* layer, Device* device)
{

if (layer == null) return;

if (device != null)
{
	if (layer.index_buffer.cookie) buffer_deinit(&layer.index_buffer, device);

	if (layer.vertex_buffer.cookie) buffer_deinit(&layer.vertex_buffer, device);

	if (layer.program.shader_bins[0].data.len || layer.program.shader_bins[1].data.len) program_deinit(&layer.program, device);

	if (layer.sampler.cookie) sampler_deinit(&layer.sampler, device);

	if (layer.font_view.cookie) image_view_deinit(&layer.font_view, device);

	if (layer.font_image.cookie) image_deinit(&layer.font_image, device);
}

if (layer.ctx) imgui_destroy_context(layer.ctx);

*layer = {};
}

fn ImguiLayer? imgui_layer_init(Device* device, Format color_format)
{

if (device == null || renderer.backend != VK) return UNSUPPORTED_BACKEND~;

ImguiLayer layer = { .color_format = color_format };

defer catch imgui_layer_cleanup(&layer, device);

layer.ctx = imgui_create_context(null);

if (layer.ctx == null) return INITIALIZATION_FAILED~;

imgui_set_current_context(layer.ctx);

imgui_style_colors_dark(null);

ImguiIO* io = imgui_get_io();

if (io == null || io.fonts == null) return INITIALIZATION_FAILED~;

io.backend_flags |= IMGUI_BACKEND_FLAGS_RENDERER_HAS_VTX_OFFSET;

char* pixels;

int width;

int height;

int bytes_per_pixel;

imgui_font_atlas_get_tex_data_rgba32(io.fonts, &pixels, &width, &height, &bytes_per_pixel);

if (pixels == null || width <= 0 || height <= 0 || bytes_per_pixel != 4) return INITIALIZATION_FAILED~;

if ((ulong)width > ulong::max / ((ulong)height * 4)) return OUT_OF_DEVICE_MEMORY~;

layer.font_image = image_init(device, {

.image_type = D2,

.format = RGBA8_UNORM,

.width = (uint)width,

.height = (uint)height,

.depth = 1,

.mip_levels = 1,

.array_layers = 1,

.samples = S1,

.tiling = OPTIMAL,

.usage = { .transfer_dst = true, .sampled = true },

.memory_usage = PREFER_DEVICE,

})!;

layer.font_view = image_view_init(device, &layer.font_image, {

.view_type = SHADER_RESOURCE_2D,

.format = RGBA8_UNORM,

.aspect = COLOR,

.mip_num = 1,

.layer_num = 1,

})!;

char[] font_pixels = pixels[:(usz)((ulong)width * (ulong)height * 4)];

image_upload(&layer.font_image, device, {

.data = font_pixels,

.extent = { .width = (uint)width, .height = (uint)height, .depth = 1 },

.layer_count = 1,

})!;

// The value is only a non-zero legacy texture id; the renderer binds the
// actual atlas descriptors by name below.
imgui_font_atlas_set_tex_id(io.fonts, 1);

layer.sampler = sampler_init(device, {

.min_filter = LINEAR,

.mag_filter = LINEAR,

.mip_map_mode = LINEAR,

.address_u = CLAMP_TO_EDGE,

.address_v = CLAMP_TO_EDGE,

.address_w = CLAMP_TO_EDGE,

.set_lod_range = true,

.max_lod = 0,

.max_anisotropy = 1,

.compare_func = NEVER,

})!;

ProgramModuleStage[2] modules = {

{ .stage = VERTEX, .data = IMGUI_VERT_SPV[..], .entry_point = "main" },

{ .stage = FRAGMENT, .data = IMGUI_FRAG_SPV[..], .entry_point = "main" },

};

ProgramLayoutBinding[2] bindings = {

{ .name = "uTexture", .set = 0, .binding = 0, .descriptor_type = SAMPLED_IMAGE, .count = 1, .stages = { .fragment = true } },

{ .name = "uSampler", .set = 0, .binding = 1, .descriptor_type = SAMPLER, .count = 1, .stages = { .fragment = true } },

};

layer.program = program_init(device, modules[..], {

.bindings = bindings[..],

.push_constant = { .stages = { .vertex = true }, .size = 16 },

.has_push_constant = true,

})!;

layer.vertex_buffer = imgui_scratch_buffer_init(device, (usz)IMGUI_INIT_VERTEX_CAPACITY * IMGUI_DRAW_VERT_STRIDE, { .vertex_buffer = true })!;

layer.index_buffer = imgui_scratch_buffer_init(device, (usz)IMGUI_INIT_INDEX_CAPACITY * IMGUI_DRAW_IDX_STRIDE, { .index_buffer = true })!;

layer.tex_descriptor = descriptor_sampled_image(&layer.font_view);

layer.sampler_descriptor = descriptor_sampler(&layer.sampler);

layer.vertex_alloc = alloc::segment_alloc_init({ .max_elements = IMGUI_INIT_VERTEX_CAPACITY, .element_stride = IMGUI_DRAW_VERT_STRIDE, .num_segments = IMGUI_FRAMES_IN_FLIGHT });

layer.index_alloc = alloc::segment_alloc_init({ .max_elements = IMGUI_INIT_INDEX_CAPACITY, .element_stride = IMGUI_DRAW_IDX_STRIDE, .num_segments = IMGUI_FRAMES_IN_FLIGHT });

return layer;
}

fn Buffer? imgui_scratch_buffer_init(Device* device, usz size, BufferUsage usage)
{

return buffer_init_general(device, {

.size = (sz)size,

.persistent_map = true,

.sequential_access = true,

.usage = usage,

.buffer_usage = PREFER_HOST,

});
}

fn void imgui_layer_deinit(ImguiLayer* layer, Device* device)
{

if (layer == null) return;

if (device != null) (void)queue_wait_idle(&device.graphics_queue, device);

imgui_layer_cleanup(layer, device);
}

fn SegmentReq? imgui_alloc_scratch(ImguiLayer* layer, Device* device, alloc::SegmentAlloc* segment, Buffer* buffer, ulong frame_index, uint stride, uint count, BufferUsage usage)
{

if (device == null || segment == null || buffer == null || count == 0 || stride == 0)
{
	return OUT_OF_DEVICE_MEMORY~;
}
if (stride > ushort::max) return OUT_OF_DEVICE_MEMORY~;
if (segment.element_stride != (ushort)stride) return INITIALIZATION_FAILED~;

SegmentReq? request = segment.alloc(frame_index, (usz)count);

if (catch err = request)
{

(void)err;

queue_wait_idle(&device.graphics_queue, device)!;

uint new_max = segment.max_elements > 0 ? segment.max_elements : 1;

while (new_max < count)
{
	if (new_max > uint::max / 2) return OUT_OF_DEVICE_MEMORY~;
	new_max *= 2;
}

if (new_max > uint::max / 2) return OUT_OF_DEVICE_MEMORY~;
new_max *= 2;

Buffer grown = imgui_scratch_buffer_init(device, (usz)new_max * stride, usage)!;

buffer_deinit(buffer, device);

*buffer = grown;

*segment = alloc::segment_alloc_init({ .max_elements = new_max, .element_stride = (ushort)stride, .num_segments = IMGUI_FRAMES_IN_FLIGHT });

request = segment.alloc(frame_index, (usz)count);

}

return request;
}

fn void imgui_layer_new_frame(ImguiLayer* layer, float display_width, float display_height, float dt)
{

if (layer == null || layer.ctx == null) return;

imgui_set_current_context(layer.ctx);

ImguiIO* io = imgui_get_io();

if (io == null) return;

io.display_size = { .x = display_width, .y = display_height };

io.display_framebuffer_scale = { .x = 1, .y = 1 };

io.delta_time = dt > 0 ? dt : 1.0 / 60.0;

imgui_new_frame();
}

fn void? imgui_layer_render(ImguiLayer* layer, Device* device, Cmd* cmd)
{

if (layer == null || device == null || cmd == null || layer.ctx == null) return;

imgui_set_current_context(layer.ctx);

imgui_render();

ImguiDrawData* draw_data = imgui_get_draw_data();

ulong render_frame = layer.frame_index;
layer.frame_index++;

if (draw_data == null || draw_data.total_vtx_count <= 0 || draw_data.total_idx_count <= 0) return;

if (draw_data.cmd_lists.size <= 0 || draw_data.cmd_lists.data == null ||
	draw_data.cmd_lists_count != draw_data.cmd_lists.size)
{
	return INITIALIZATION_FAILED~;
}

float fb_width = draw_data.display_size.x * draw_data.framebuffer_scale.x;

float fb_height = draw_data.display_size.y * draw_data.framebuffer_scale.y;

if (fb_width <= 0 || fb_height <= 0) return;

SegmentReq vtx_request = imgui_alloc_scratch(layer, device, &layer.vertex_alloc, &layer.vertex_buffer, render_frame, IMGUI_DRAW_VERT_STRIDE, (uint)draw_data.total_vtx_count, { .vertex_buffer = true })!;

SegmentReq idx_request = imgui_alloc_scratch(layer, device, &layer.index_alloc, &layer.index_buffer, render_frame, IMGUI_DRAW_IDX_STRIDE, (uint)draw_data.total_idx_count, { .index_buffer = true })!;

if (layer.vertex_buffer.mapped_region.ptr == null || layer.index_buffer.mapped_region.ptr == null)
{
	return BUFFER_NOT_MAPPED~;
}

sz vertex_byte_offset = (sz)vtx_request.element_offset * IMGUI_DRAW_VERT_STRIDE;

sz index_byte_offset = (sz)idx_request.element_offset * IMGUI_DRAW_IDX_STRIDE;

usz copied_vtx = 0;
usz copied_idx = 0;

for (int i = 0; i < draw_data.cmd_lists.size; i++)
{

ImguiDrawList* list = draw_data.cmd_lists.data[i];

if (list == null || list.vtx_buffer.size < 0 || list.idx_buffer.size < 0)
{
	return INITIALIZATION_FAILED~;
}
if (list.vtx_buffer.size > list.vtx_buffer.capacity || list.idx_buffer.size > list.idx_buffer.capacity)
{
	return INITIALIZATION_FAILED~;
}
if ((list.vtx_buffer.size > 0 && list.vtx_buffer.data == null) ||
	(list.idx_buffer.size > 0 && list.idx_buffer.data == null))
{
	return INITIALIZATION_FAILED~;
}

sz vertex_bytes = (sz)list.vtx_buffer.size * IMGUI_DRAW_VERT_STRIDE;

sz index_bytes = (sz)list.idx_buffer.size * IMGUI_DRAW_IDX_STRIDE;

mem::copy((void*)(layer.vertex_buffer.mapped_region.ptr + vertex_byte_offset), list.vtx_buffer.data, vertex_bytes);

mem::copy((void*)(layer.index_buffer.mapped_region.ptr + index_byte_offset), list.idx_buffer.data, index_bytes);

vertex_byte_offset += vertex_bytes;

index_byte_offset += index_bytes;

copied_vtx += (usz)list.vtx_buffer.size;

copied_idx += (usz)list.idx_buffer.size;
}

if (copied_vtx != (usz)draw_data.total_vtx_count || copied_idx != (usz)draw_data.total_idx_count)
{
	return INITIALIZATION_FAILED~;
}

buffer_flush(&layer.vertex_buffer, device);

buffer_flush(&layer.index_buffer, device);

ProgramColorAttachment[1] colors = {{

.format = layer.color_format,

.blend = BLEND_STATE_STRAIGHT_ALPHA,

.has_blend = true,

}};

ProgramVertexStream[1] streams = {{ .binding = 0, .stride = IMGUI_DRAW_VERT_STRIDE }};

ProgramVertexAttribute[3] attributes = {

{ .location = 0, .binding = 0, .format = RG32_SFLOAT, .offset = 0 },

{ .location = 1, .binding = 0, .format = RG32_SFLOAT, .offset = 8 },

{ .location = 2, .binding = 0, .format = RGBA8_UNORM, .offset = 16 },

};

program_bind_pipeline(&layer.program, device, cmd, IMGUI_PIPELINE_KEY, {

.topology = TRIANGLE_LIST,

.cull_mode = NONE,

.front_face = CLOCKWISE,

.depth_compare = ALWAYS,

.colors = colors[..],

.vertex_streams = streams[..],

.vertex_attributes = attributes[..],

})!;

float inv_width = 2.0f / draw_data.display_size.x;

float inv_height = 2.0f / draw_data.display_size.y;

ImguiPushConstants push_constants = {

.scale = { inv_width, inv_height },

.translate = { -1.0f - draw_data.display_pos.x * inv_width, -1.0f - draw_data.display_pos.y * inv_height },

};

program_push_constants(&layer.program, device, cmd, ((char*)&push_constants)[:16], 0);

cmd_set_viewport(cmd, device, { .width = fb_width, .height = fb_height, .min_depth = 0, .max_depth = 1 });

cmd_bind_vertex_buffer(cmd, device, &layer.vertex_buffer, 0);

cmd_bind_index_buffer(cmd, device, &layer.index_buffer, UINT16);

DescriptorBinding[2] descriptors = {

descriptor_binding("uTexture", layer.tex_descriptor, 0),

descriptor_binding("uSampler", layer.sampler_descriptor, 0),

};

program_bind_descriptors(&layer.program, device, cmd, (uint)render_frame, descriptors[..], GRAPHICS)!;

uint global_vertex = vtx_request.element_offset;

uint global_index = idx_request.element_offset;

for (int i = 0; i < draw_data.cmd_lists.size; i++)
{

ImguiDrawList* list = draw_data.cmd_lists.data[i];

if (list == null || list.cmd_buffer.size < 0 ||
	(list.cmd_buffer.size > 0 && list.cmd_buffer.data == null))
{
	return INITIALIZATION_FAILED~;
}
if (list.cmd_buffer.size > list.cmd_buffer.capacity)
{
	return INITIALIZATION_FAILED~;
}

ImguiDrawCmd* commands = (ImguiDrawCmd*)list.cmd_buffer.data;

for (int j = 0; j < list.cmd_buffer.size; j++)
{

ImguiDrawCmd* draw_cmd = &commands[j];

if (draw_cmd.user_callback != null) continue;

if (draw_cmd.idx_offset > (uint)list.idx_buffer.size ||
	draw_cmd.elem_count > (uint)list.idx_buffer.size - draw_cmd.idx_offset ||
	draw_cmd.vtx_offset > (uint)list.vtx_buffer.size)
{
	return INITIALIZATION_FAILED~;
}
if (draw_cmd.elem_count == 0) continue;

float min_x = (draw_cmd.clip_rect.x - draw_data.display_pos.x) * draw_data.framebuffer_scale.x;

float min_y = (draw_cmd.clip_rect.y - draw_data.display_pos.y) * draw_data.framebuffer_scale.y;

float max_x = (draw_cmd.clip_rect.z - draw_data.display_pos.x) * draw_data.framebuffer_scale.x;

float max_y = (draw_cmd.clip_rect.w - draw_data.display_pos.y) * draw_data.framebuffer_scale.y;

if (min_x < 0) min_x = 0;

if (min_y < 0) min_y = 0;

if (max_x > fb_width) max_x = fb_width;

if (max_y > fb_height) max_y = fb_height;

if (max_x <= min_x || max_y <= min_y) continue;

cmd_set_scissor(cmd, device, { .x = (int)min_x, .y = (int)min_y, .width = (uint)(max_x - min_x), .height = (uint)(max_y - min_y) });

cmd_draw_indexed(cmd, device, draw_cmd.elem_count, 1, global_index + draw_cmd.idx_offset, (int)(global_vertex + draw_cmd.vtx_offset), 0);

}

global_vertex += (uint)list.vtx_buffer.size;

global_index += (uint)list.idx_buffer.size;

}
}

fn void imgui_layer_add_mouse_pos_event(ImguiLayer* layer, float x, float y)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_mouse_pos_event(io, x, y);
}

fn void imgui_layer_add_mouse_button_event(ImguiLayer* layer, int button, bool down)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_mouse_button_event(io, button, down);
}

fn void imgui_layer_add_mouse_wheel_event(ImguiLayer* layer, float x, float y)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_mouse_wheel_event(io, x, y);
}

fn void imgui_layer_add_key_event(ImguiLayer* layer, int key, bool down)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_key_event(io, key, down);
}

fn void imgui_layer_add_focus_event(ImguiLayer* layer, bool focused)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_focus_event(io, focused);
}

fn void imgui_layer_add_input_character(ImguiLayer* layer, uint character)
{

if (ImguiIO* io = imgui_layer_io(layer)) imgui_io_add_input_character(io, character);
}

fn ImguiIO* imgui_layer_io(ImguiLayer* layer)
{

if (layer == null || layer.ctx == null) return null;

imgui_set_current_context(layer.ctx);

return imgui_get_io();
}

fn bool imgui_layer_want_capture_mouse(ImguiLayer* layer)
{

ImguiIO* io = imgui_layer_io(layer);

return io != null && io.want_capture_mouse;
}

fn bool imgui_layer_want_capture_keyboard(ImguiLayer* layer)
{

ImguiIO* io = imgui_layer_io(layer);

return io != null && io.want_capture_keyboard;
}

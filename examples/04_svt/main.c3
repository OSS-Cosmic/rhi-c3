// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// 04_svt: software virtual texturing.
//
// This example is intentionally Vulkan-only.  It is the first C3 example that
// uses rhi::Program directly: descriptor bindings are declared and resolved by
// name for the feedback and composite pipelines.  ImGui rendering is supplied
// by the existing RHI_IMGUI layer and widget calls use the vendor/imgui_c shim ABI.
module example_04_svt @feat(RHI_VK & RHI_IMGUI & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import std::collections::list;
import std::math;
import imgui;
import platform;
import rhi;
import sdl3;

// The compact C3 ImGui binding intentionally exposes only the calls shared by
// the demos; keep this layout primitive local so the demo does not widen the
// vendor ABI surface.
extern fn void imgui_separator() @cname("ImGui_Separator");

const uint VIRTUAL_SIZE = 8192;
const uint TILE_SIZE = 128;
const uint BORDER = 1;
const uint PAGE_SIZE = TILE_SIZE + 2 * BORDER;
const uint PAGE_TABLE_SIZE = VIRTUAL_SIZE / TILE_SIZE;
const uint MIP_COUNT = 7;
const uint ATLAS_COUNT = 24;
const uint ATLAS_PX = ATLAS_COUNT * PAGE_SIZE;
const uint NUM_SLOTS = ATLAS_COUNT * ATLAS_COUNT;
const uint UPLOADS_PER_FRAME = 12;
const uint FB_RING = 3;
const uint PT_TOTAL_TEXELS = 4096 + 1024 + 256 + 64 + 16 + 4 + 1;
const uint PT_BYTES = PT_TOTAL_TEXELS * 4;
const uint TILE_BYTES = PAGE_SIZE * PAGE_SIZE * 4;
const uint NONE = 0xffffffff;
const float PI = 3.14159265358979323846;

const char[*] SVT_VERTEX_SPV @align(4) = $embed("../../build/examples/04_svt/shaders/04_svt.vert.spv");
const char[*] SVT_COMPOSITE_SPV @align(4) = $embed("../../build/examples/04_svt/shaders/04_svt_composite.frag.spv");
const char[*] SVT_FEEDBACK_SPV @align(4) = $embed("../../build/examples/04_svt/shaders/04_svt_feedback.frag.spv");

struct Vertex
{
	float[3] position;
	float[2] uv;
}

struct PushConsts
{
	float[16] mvp;
	float page_table_size;
	float virtual_texture_size;
	float mip_count;
	float mip_bias;
	float atlas_count;
	float border_scale;
	float border_offset;
	float _pad;
}

const Vertex[4] PLANE_VERTS = {
	{ .position = { -25, 0, -25 }, .uv = { 0, 0 } },
	{ .position = {  25, 0, -25 }, .uv = { 1, 0 } },
	{ .position = { -25, 0,  25 }, .uv = { 0, 1 } },
	{ .position = {  25, 0,  25 }, .uv = { 1, 1 } },
};
const ushort[6] PLANE_INDEX = { 0, 1, 2, 2, 1, 3 };

struct Page
{
	uint mip;
	uint x;
	uint y;
}

struct PageIndexer
{
	uint[MIP_COUNT] sizes;
	uint[MIP_COUNT] offsets;
	uint total;
}

fn PageIndexer page_indexer_init()
{
	PageIndexer result;
	uint total = 0;
	for (uint mip = 0; mip < MIP_COUNT; mip++)
	{
		uint size = PAGE_TABLE_SIZE >> mip;
		result.sizes[mip] = size;
		result.offsets[mip] = total;
		total += size * size;
	}
	result.total = total;
	return result;
}

fn uint page_index(PageIndexer* indexer, uint mip, uint x, uint y)
{
	return indexer.offsets[mip] + y * indexer.sizes[mip] + x;
}

fn Page page_decode(PageIndexer* indexer, uint index)
{
	uint mip = 0;
	while (mip + 1 < MIP_COUNT && index >= indexer.offsets[mip + 1]) mip++;
	uint local = index - indexer.offsets[mip];
	uint size = indexer.sizes[mip];
	return { .mip = mip, .x = local % size, .y = local / size };
}

// A direct page-index table avoids a hash allocation in the hot path.  It is
// the same page -> slot cache as a map, with the LRU metadata kept in
// the atlas-slot arrays.  Coarse pages are pinned to guarantee fallbacks.
struct PageCache
{
	uint[PT_TOTAL_TEXELS] page_slot;
	uint[NUM_SLOTS] slot_page;
	ulong[NUM_SLOTS] last_used;
	bool[NUM_SLOTS] pinned;
	uint used;
	ulong clock;
}

fn void page_cache_init(PageCache* cache)
{
	for (uint i = 0; i < PT_TOTAL_TEXELS; i++) cache.page_slot[i] = NONE;
	for (uint i = 0; i < NUM_SLOTS; i++)
	{
		cache.slot_page[i] = NONE;
		cache.last_used[i] = 0;
		cache.pinned[i] = false;
	}
	cache.used = 0;
	cache.clock = 0;
}

fn void page_cache_deinit(PageCache* cache) { *cache = {}; }

fn uint page_cache_request(PageCache* cache, uint page, bool pin, bool* loaded)
{
	cache.clock++;
	uint existing = cache.page_slot[page];
	if (existing != NONE)
	{
		cache.last_used[existing] = cache.clock;
		if (pin) cache.pinned[existing] = true;
		*loaded = false;
		return existing;
	}

	uint slot;
	if (cache.used < NUM_SLOTS)
	{
		slot = cache.used++;
	}
	else
	{
		slot = NONE;
		ulong oldest = 0xffffffffffffffff;
		for (uint i = 0; i < NUM_SLOTS; i++)
		{
			if (cache.pinned[i]) continue;
			if (cache.last_used[i] < oldest) { oldest = cache.last_used[i]; slot = i; }
		}
		// The pinned coarse set occupies 21 slots, leaving plenty of LRU space.
		if (slot == NONE) { *loaded = false; return NONE; }
		uint old_page = cache.slot_page[slot];
		if (old_page != NONE) cache.page_slot[old_page] = NONE;
	}
	cache.slot_page[slot] = page;
	cache.page_slot[page] = slot;
	cache.last_used[slot] = cache.clock;
	cache.pinned[slot] = pin;
	*loaded = true;
	return slot;
}

struct Upload
{
	uint slot;
	Page page;
}

fn void procedural_tile(Page page, char[] bytes)
{
	uint r0 = (page.x * 41 + page.mip * 60 + 40) & 255;
	uint g0 = (page.y * 47 + page.mip * 20 + 40) & 255;
	uint b0 = (page.mip * 35 + 90) & 255;
	for (uint y = 0; y < PAGE_SIZE; y++)
	{
		for (uint x = 0; x < PAGE_SIZE; x++)
		{
			uint scale = (((x / 16) + (y / 16)) & 1) == 0 ? 255 : 150;
			uint at = (y * PAGE_SIZE + x) * 4;
			bytes[at + 0] = (char)(r0 * scale / 255);
			bytes[at + 1] = (char)(g0 * scale / 255);
			bytes[at + 2] = (char)(b0 * scale / 255);
			bytes[at + 3] = (char)255;
		}
	}
}

// Small column-major matrix helpers.  Keeping them local makes the example
// independent of a matrix package and preserves the shader ABI exactly.
fn void mat4_identity(float[16]* m)
{
	*m = {};
	(*m)[0] = 1; (*m)[5] = 1; (*m)[10] = 1; (*m)[15] = 1;
}

fn void mat4_mul(float[16]* out, float[16] a, float[16] b)
{
	float[16] result = {};
	for (uint col = 0; col < 4; col++)
	{
		for (uint row = 0; row < 4; row++)
		{
			result[col * 4 + row] = a[0 * 4 + row] * b[col * 4 + 0] + a[1 * 4 + row] * b[col * 4 + 1] + a[2 * 4 + row] * b[col * 4 + 2] + a[3 * 4 + row] * b[col * 4 + 3];
		}
	}
	*out = result;
}

fn void mat4_look_at(float[16]* out, float[3] eye, float[3] target)
{
	float[3] f = { target[0] - eye[0], target[1] - eye[1], target[2] - eye[2] };
	float fl = math::sqrt(f[0] * f[0] + f[1] * f[1] + f[2] * f[2]);
	for (uint i = 0; i < 3; i++) f[i] /= fl;
	float[3] up = { 0, 1, 0 };
	float[3] s = { f[1] * up[2] - f[2] * up[1], f[2] * up[0] - f[0] * up[2], f[0] * up[1] - f[1] * up[0] };
	float sl = math::sqrt(s[0] * s[0] + s[1] * s[1] + s[2] * s[2]);
	for (uint i = 0; i < 3; i++) s[i] /= sl;
	float[3] u = { s[1] * f[2] - s[2] * f[1], s[2] * f[0] - s[0] * f[2], s[0] * f[1] - s[1] * f[0] };
	mat4_identity(out);
	(*out)[0] = s[0]; (*out)[4] = s[1]; (*out)[8] = s[2];
	(*out)[1] = u[0]; (*out)[5] = u[1]; (*out)[9] = u[2];
	(*out)[2] = -f[0]; (*out)[6] = -f[1]; (*out)[10] = -f[2];
	(*out)[12] = -(s[0] * eye[0] + s[1] * eye[1] + s[2] * eye[2]);
	(*out)[13] = -(u[0] * eye[0] + u[1] * eye[1] + u[2] * eye[2]);
	(*out)[14] = f[0] * eye[0] + f[1] * eye[1] + f[2] * eye[2];
}

fn void mat4_perspective(float[16]* out, float fov, float aspect, float near, float far)
{
	float t = (float)(1.0 / math::tan(fov * 0.5));
	*out = {};
	(*out)[0] = t / aspect;
	(*out)[5] = t;
	(*out)[10] = far / (near - far);
	(*out)[11] = -1;
	(*out)[14] = (far * near) / (near - far);
}

enum Stage : char
{
	NONE, RENDERER, DEVICE, SWAPCHAIN, COMMAND_RING, TIMELINE, IMGUI,
	RESOURCES, FEEDBACK_PROGRAM, COMPOSITE_PROGRAM,
}

struct SvtState
{
	platform::Window window;
	Stage stage;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FB_RING, 1, true} ring;
	rhi::Timeline timeline;
	rhi::ImguiLayer imgui;
	rhi::Program feedback_program;
	rhi::Program composite_program;
	rhi::Image atlas_image;
	rhi::ImageView atlas_view;
	rhi::Image page_table_image;
	rhi::ImageView page_table_view;
	rhi::Sampler nearest_sampler;
	rhi::Sampler linear_sampler;
	rhi::Buffer quad_vb;
	rhi::Buffer quad_ib;
	rhi::Buffer[FB_RING] feedback_ring;
	rhi::Buffer[FB_RING] staging_ring;
	PageIndexer indexer;
	PageCache cache;
	char[PT_BYTES] page_table_cpu;
	uint frame;
	ulong uploads_total;
	bool resources_initialized;
	ulong last_ticks;
	bool fly_mode;
	float[3] camera_position;
	float camera_yaw;
	float camera_pitch;
	float move_speed;
	float mip_bias;
	float frame_dt;
	bool[512] keys;
	uint requested_min_mip;
	uint requested_max_mip;
	bool force_rebuild;
	int frame_limit;
	int presented;
}

SvtState state;

fn int parse_frame_count(String text)
{
	if (text.len == 0) return -1;
	int result = 0;
	for (sz i = 0; i < text.len; i++)
	{
		if (text[i] < '0' || text[i] > '9') return -1;
		result = result * 10 + text[i] - '0';
	}
	return result;
}

fn void parse_args(String[] args)
{
	state.frame_limit = 0;
	for (sz i = 0; i < args.len; i++)
	{
		if (args[i] != "--frames") continue;
		if (i + 1 >= args.len) { state.frame_limit = -1; continue; }
		state.frame_limit = parse_frame_count(args[i + 1]);
		i++;
	}
}

fn ushort dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn void request_page(uint page, bool pin, Upload[UPLOADS_PER_FRAME]* uploads, uint* count)
{
	bool resident = state.cache.page_slot[page] != NONE;
	if (!resident && *count >= UPLOADS_PER_FRAME) return;
	bool loaded;
	uint slot = page_cache_request(&state.cache, page, pin, &loaded);
	if (loaded && slot != NONE)
	{
		(*uploads)[*count] = { .slot = slot, .page = page_decode(&state.indexer, page) };
		(*count)++;
	}
}

fn void rebuild_page_table()
{
	for (uint i = 0; i < PT_BYTES; i++) state.page_table_cpu[i] = 0;
	for (uint level = 0; level < MIP_COUNT; level++)
	{
		uint size = state.indexer.sizes[level];
		uint base = state.indexer.offsets[level];
		for (uint y = 0; y < size; y++) for (uint x = 0; x < size; x++)
		{
			uint mip = level;
			uint px = x;
			uint py = y;
			uint slot = NONE;
			uint resident_mip = 0;
			while (mip < MIP_COUNT)
			{
				uint candidate = state.cache.page_slot[page_index(&state.indexer, mip, px, py)];
				if (candidate != NONE) { slot = candidate; resident_mip = mip; break; }
				mip++;
				px >>= 1;
				py >>= 1;
			}
			uint at = (base + y * size + x) * 4;
			if (slot != NONE)
			{
				state.page_table_cpu[at + 0] = (char)(slot % ATLAS_COUNT);
				state.page_table_cpu[at + 1] = (char)(slot / ATLAS_COUNT);
				state.page_table_cpu[at + 2] = (char)resident_mip;
				state.page_table_cpu[at + 3] = (char)255;
			}
		}
	}
}

fn void? init_programs() @private
{
	char[] vertex = SVT_VERTEX_SPV[..];
	char[] composite = SVT_COMPOSITE_SPV[..];
	char[] feedback = SVT_FEEDBACK_SPV[..];
	rhi::ProgramModuleStage[2] feedback_modules = {
		{ .stage = rhi::ProgramStage.VERTEX, .data = vertex, .entry_point = "main" },
		{ .stage = rhi::ProgramStage.FRAGMENT, .data = feedback, .entry_point = "main" },
	};
	rhi::ProgramModuleStage[2] composite_modules = {
		{ .stage = rhi::ProgramStage.VERTEX, .data = vertex, .entry_point = "main" },
		{ .stage = rhi::ProgramStage.FRAGMENT, .data = composite, .entry_point = "main" },
	};
	rhi::ProgramStageFlags graphics = { .vertex = true, .fragment = true };
	rhi::ProgramLayoutBinding[1] feedback_bindings = {
		{ .name = "feedback_buffer", .set = 0, .binding = 0, .descriptor_type = rhi::DescriptorType.STORAGE_BUFFER, .count = 1, .stages = { .fragment = true } },
	};
	rhi::ProgramLayoutBinding[4] composite_bindings = {
		{ .name = "s_page_table", .set = 0, .binding = 1, .descriptor_type = rhi::DescriptorType.SAMPLED_IMAGE, .count = 1, .stages = { .fragment = true } },
		{ .name = "s_atlas", .set = 0, .binding = 2, .descriptor_type = rhi::DescriptorType.SAMPLED_IMAGE, .count = 1, .stages = { .fragment = true } },
		{ .name = "page_sampler", .set = 0, .binding = 3, .descriptor_type = rhi::DescriptorType.SAMPLER, .count = 1, .stages = { .fragment = true } },
		{ .name = "atlas_sampler", .set = 0, .binding = 4, .descriptor_type = rhi::DescriptorType.SAMPLER, .count = 1, .stages = { .fragment = true } },
	};
	rhi::ProgramPushConstantRange push = { .stages = graphics, .size = PushConsts::size };
	state.feedback_program = rhi::program_init(&state.device, feedback_modules[..], { .bindings = feedback_bindings[..], .push_constant = push, .has_push_constant = true })!;
	state.stage = FEEDBACK_PROGRAM;
	state.composite_program = rhi::program_init(&state.device, composite_modules[..], { .bindings = composite_bindings[..], .push_constant = push, .has_push_constant = true })!;
	state.stage = COMPOSITE_PROGRAM;
}

fn void? init_resources() @private
{
	state.indexer = page_indexer_init();
	page_cache_init(&state.cache);
	state.atlas_image = rhi::image_init(&state.device, {
		.image_type = rhi::ImageType.D2, .format = rhi::Format.RGBA8_UNORM,
		.width = ATLAS_PX, .height = ATLAS_PX, .depth = 1, .mip_levels = 1,
		.array_layers = 1, .samples = rhi::ImageSampleCount.S1, .tiling = rhi::ImageTiling.OPTIMAL,
		.usage = { .sampled = true, .transfer_dst = true }, .memory_usage = rhi::ImageMemoryUsage.PREFER_DEVICE,
	})!;
	state.atlas_view = rhi::image_view_init(&state.device, &state.atlas_image, {
		.view_type = rhi::ViewType.SHADER_RESOURCE_2D, .format = rhi::Format.RGBA8_UNORM,
		.aspect = rhi::ImageAspect.COLOR, .mip_num = 1, .layer_num = 1,
	})!;
	state.page_table_image = rhi::image_init(&state.device, {
		.image_type = rhi::ImageType.D2, .format = rhi::Format.RGBA8_UNORM,
		.width = PAGE_TABLE_SIZE, .height = PAGE_TABLE_SIZE, .depth = 1, .mip_levels = MIP_COUNT,
		.array_layers = 1, .samples = rhi::ImageSampleCount.S1, .tiling = rhi::ImageTiling.OPTIMAL,
		.usage = { .sampled = true, .transfer_dst = true }, .memory_usage = rhi::ImageMemoryUsage.PREFER_DEVICE,
	})!;
	state.page_table_view = rhi::image_view_init(&state.device, &state.page_table_image, {
		.view_type = rhi::ViewType.SHADER_RESOURCE_2D, .format = rhi::Format.RGBA8_UNORM,
		.aspect = rhi::ImageAspect.COLOR, .mip_num = MIP_COUNT, .layer_num = 1,
	})!;
	state.nearest_sampler = rhi::sampler_init(&state.device, {
		.min_filter = rhi::SamplerFilter.NEAREST, .mag_filter = rhi::SamplerFilter.NEAREST,
		.mip_map_mode = rhi::SamplerMipmap.NEAREST, .address_u = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.address_v = rhi::SamplerAddress.CLAMP_TO_EDGE, .address_w = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.max_anisotropy = 1, .compare_func = rhi::SamplerCompare.NEVER,
	})!;
	state.linear_sampler = rhi::sampler_init(&state.device, {
		.min_filter = rhi::SamplerFilter.LINEAR, .mag_filter = rhi::SamplerFilter.LINEAR,
		.mip_map_mode = rhi::SamplerMipmap.NEAREST, .address_u = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.address_v = rhi::SamplerAddress.CLAMP_TO_EDGE, .address_w = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.max_anisotropy = 1, .compare_func = rhi::SamplerCompare.NEVER,
	})!;
	char[] vertices = ((char*)&PLANE_VERTS[0])[:@sizeof(PLANE_VERTS)];
	char[] indices = ((char*)&PLANE_INDEX[0])[:@sizeof(PLANE_INDEX)];
	state.quad_vb = rhi::buffer_init_general(&state.device, { .size = vertices.len, .persistent_map = true, .usage = { .vertex_buffer = true }, .buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST })!;
	state.quad_ib = rhi::buffer_init_general(&state.device, { .size = indices.len, .persistent_map = true, .usage = { .index_buffer = true }, .buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST })!;
	rhi::buffer_write(&state.quad_vb, &state.device, 0, vertices);
	rhi::buffer_write(&state.quad_ib, &state.device, 0, indices);
	rhi::buffer_flush(&state.quad_vb, &state.device);
	rhi::buffer_flush(&state.quad_ib, &state.device);
	for (uint i = 0; i < FB_RING; i++)
	{
		state.feedback_ring[i] = rhi::buffer_init_general(&state.device, { .size = PT_BYTES, .stride = 4, .persistent_map = true, .usage = { .shader_resource_storage = true }, .buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST })!;
		state.staging_ring[i] = rhi::buffer_init_general(&state.device, { .size = UPLOADS_PER_FRAME * TILE_BYTES + PT_BYTES, .persistent_map = true, .sequential_access = true, .usage = { .transfer_src = true }, .buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST })!;
	}
	state.stage = RESOURCES;
}

fn void svt_draw_imgui()
{
	// ImGui statistics and controls: the ticket's C3 binding supplies these
	// calls.  Keeping all statistics here lives in one place.
	bool visible = imgui::begin("04-svt virtual texturing", null, 0);
	if (visible)
	{
	imgui::text("%.1f FPS", (double)(1.0 / max(state.frame_dt, 0.0001)));
	imgui_separator();
	imgui::text("Software virtual texturing");
	if (imgui::checkbox("Fly camera (Esc to release)", &state.fly_mode))
	{
		(void)sdl3::set_window_relative_mouse_mode(state.window.handle, state.fly_mode);
	}
	imgui::text("WASD move, Q/E down/up, mouse look");
	imgui::slider_float("Move speed", &state.move_speed, 2, 80, "%.1f", 0);
	imgui::slider_float("Mip bias", &state.mip_bias, -2, 3, "%.2f", 0);
	imgui_separator();
	imgui::text("Resident tiles: %d / %d", (int)state.cache.used, (int)NUM_SLOTS);
	imgui::text("Tiles streamed: %d", (int)state.uploads_total);
	imgui::text("Requested mip: %d .. %d", (int)state.requested_min_mip, (int)state.requested_max_mip);
	}
	imgui::end();
}

fn void make_push_constants(float[16] view_projection, PushConsts* pc)
{
	*pc = {};
	pc.mvp = view_projection;
	pc.page_table_size = PAGE_TABLE_SIZE;
	pc.virtual_texture_size = VIRTUAL_SIZE;
	pc.mip_count = MIP_COUNT;
	pc.mip_bias = state.mip_bias;
	pc.atlas_count = ATLAS_COUNT;
	pc.border_scale = (float)TILE_SIZE / PAGE_SIZE;
	pc.border_offset = (float)BORDER / PAGE_SIZE;
}

fn void record_copy_uploads(rhi::Cmd* cmd, uint slot, Upload[UPLOADS_PER_FRAME] uploads, uint upload_count)
{
	char[] staging = state.staging_ring[slot].mapped_region;
	for (uint i = 0; i < upload_count; i++)
	{
		procedural_tile(uploads[i].page, staging[i * TILE_BYTES : TILE_BYTES]);
		uint x = uploads[i].slot % ATLAS_COUNT;
		uint y = uploads[i].slot / ATLAS_COUNT;
		rhi::cmd_copy_buffer_to_texture(cmd, &state.device, {
			.src = &state.staging_ring[slot], .dst = &state.atlas_image, .buffer_offset = (ulong)(i * TILE_BYTES),
			.mip_level = 0, .layer_count = 1, .aspect = rhi::BarrierAspect.COLOR,
			.x = (int)(x * PAGE_SIZE), .y = (int)(y * PAGE_SIZE), .width = PAGE_SIZE, .height = PAGE_SIZE, .depth = 1,
		});
	}
	rebuild_page_table();
	uint table_offset = UPLOADS_PER_FRAME * TILE_BYTES;
	for (uint i = 0; i < PT_BYTES; i++) staging[table_offset + i] = state.page_table_cpu[i];
	rhi::buffer_flush(&state.staging_ring[slot], &state.device);
	for (uint mip = 0; mip < MIP_COUNT; mip++)
	{
		uint size = PAGE_TABLE_SIZE >> mip;
		rhi::cmd_copy_buffer_to_texture(cmd, &state.device, {
			.src = &state.staging_ring[slot], .dst = &state.page_table_image,
			.buffer_offset = (ulong)(table_offset + state.indexer.offsets[mip] * 4),
			.mip_level = mip, .layer_count = 1, .aspect = rhi::BarrierAspect.COLOR,
			.width = size, .height = size, .depth = 1,
		});
	}
}

fn void? svt_init(platform::Window window)
{
	state.window = window;
	if (catch err = rhi::renderer_init({ .backend = rhi::Backend.VK, .vk = { .app_name = "04_svt" } })) return err~;
	state.stage = RENDERER;
	list::List{rhi::PhysicalAdapter}? adapters = rhi::enumerate_adapters();
	if (catch err = adapters) return err~;
	defer adapters.free();
	if (adapters.len() == 0) return rhi::INITIALIZATION_FAILED~;
	state.device = rhi::device_init(&adapters[rhi::default_select_adapter(adapters.array_view())])!;
	state.stage = DEVICE;
	platform::PixelSize size = platform::window_size_in_pixels(window);
	state.swapchain = rhi::swapchain_init(&state.device, {
		.width = dimension(size.width, 1024), .height = dimension(size.height, 640),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT, .request_image_count = (char)FB_RING,
		.vsync = true, .queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(window) },
	})!;
	state.stage = SWAPCHAIN;
	state.ring = rhi::command_ring_buffer_init{FB_RING, 1, true}(&state.device, &state.device.graphics_queue)!;
	state.stage = COMMAND_RING;
	state.timeline = rhi::timeline_init(&state.device)!;
	state.stage = TIMELINE;
	state.imgui = rhi::imgui_layer_init(&state.device, rhi::swapchain_color_format(&state.swapchain))!;
	state.stage = IMGUI;
	state.camera_position = { 0, 10, 16 };
	state.camera_pitch = -0.5;
	state.move_speed = 20;
	init_resources()!;
	init_programs()!;
}

fn platform::AppResult svt_app_init(platform::Window window)
{
	state = {};
	parse_args(platform::program_args());
	if (state.frame_limit < 0)
	{
		log::error("[04_svt] --frames requires a non-negative integer");
		return platform::AppResult.FAILURE;
	}
	if (catch err = svt_init(window))
	{
		log::error("[04_svt] initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn void clear_feedback(uint slot)
{
	for (uint i = 0; i < state.indexer.total * 4; i++) state.feedback_ring[slot].mapped_region[i] = 0;
	rhi::buffer_flush(&state.feedback_ring[slot], &state.device);
}

fn void read_feedback(uint slot, Upload[UPLOADS_PER_FRAME]* uploads, uint* upload_count, uint* request_count)
{
	uint* flags = (uint*)state.feedback_ring[slot].mapped_region.ptr;
	uint min_mip = MIP_COUNT - 1;
	uint max_mip = 0;
	*request_count = 0;
	for (uint mip = 4; mip < MIP_COUNT; mip++)
	{
		uint size = state.indexer.sizes[mip];
		for (uint y = 0; y < size; y++) for (uint x = 0; x < size; x++) request_page(page_index(&state.indexer, mip, x, y), true, uploads, upload_count);
	}
	if (state.resources_initialized)
	{
		for (uint i = 0; i < state.indexer.total; i++)
		{
			if (flags[i] == 0) continue;
			(*request_count)++;
			uint mip = page_decode(&state.indexer, i).mip;
			if (mip < min_mip) min_mip = mip;
			if (mip > max_mip) max_mip = mip;
			request_page(i, false, uploads, upload_count);
		}
	}
	state.requested_min_mip = *request_count == 0 ? 0 : min_mip;
	state.requested_max_mip = max_mip;
}

fn void camera_matrix(float aspect, float dt, float[16]* out)
{
	float[3] target = { 0, 0, 0 };
	float[3] eye;
	if (state.fly_mode)
	{
		float cy = (float)math::cos(state.camera_yaw);
		float sy = (float)math::sin(state.camera_yaw);
		float cp = (float)math::cos(state.camera_pitch);
		float sp = (float)math::sin(state.camera_pitch);
		float[3] forward = { sy * cp, sp, -cy * cp };
		float[3] right = { forward[2], 0, -forward[0] };
		float rl = math::sqrt(right[0] * right[0] + right[2] * right[2]);
		if (rl > 0) { right[0] /= rl; right[2] /= rl; }
		float[3] velocity = {};
			if (state.keys[sdl3::SDL_SCANCODE_W]) for (uint i = 0; i < 3; i++) velocity[i] += forward[i];
			if (state.keys[sdl3::SDL_SCANCODE_S]) for (uint i = 0; i < 3; i++) velocity[i] -= forward[i];
			if (state.keys[sdl3::SDL_SCANCODE_D]) for (uint i = 0; i < 3; i++) velocity[i] += right[i];
			if (state.keys[sdl3::SDL_SCANCODE_A]) for (uint i = 0; i < 3; i++) velocity[i] -= right[i];
			if (state.keys[sdl3::SDL_SCANCODE_E]) velocity[1] += 1;
			if (state.keys[sdl3::SDL_SCANCODE_Q]) velocity[1] -= 1;
		for (uint i = 0; i < 3; i++) state.camera_position[i] += velocity[i] * state.move_speed * dt;
		eye = state.camera_position;
		for (uint i = 0; i < 3; i++) target[i] = eye[i] + forward[i];
	}
	else
	{
		float t = (float)platform::ticks_ms() / 1000;
		float sweep = (float)(0.5 - 0.5 * math::cos(t * 0.5));
		float distance = 6 + sweep * 34;
		float height = 4 + sweep * 20;
		eye = { (float)math::cos(t * 0.25) * distance, height, (float)math::sin(t * 0.25) * distance };
	}
	float[16] view;
	float[16] projection;
	float[16] depth = {};
	mat4_look_at(&view, eye, { 0, 0, 0 });
	mat4_perspective(&projection, 55 * PI / 180, aspect, 0.1, 300);
	depth[0] = 1; depth[5] = 1; depth[10] = 0.5; depth[11] = 0.5; depth[15] = 1;
	float[16] proj_zero_one;
	mat4_mul(&proj_zero_one, depth, projection);
	mat4_mul(out, proj_zero_one, view);
}

fn void? svt_frame()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	ushort width = dimension(size.width, 1);
	ushort height = dimension(size.height, 1);
	if (width == 0 || height == 0) return;
	if (state.force_rebuild || state.swapchain.width != width || state.swapchain.height != height)
	{
		rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)!;
		rhi::swapchain_recreate(&state.swapchain, &state.device, width, height)!;
		state.force_rebuild = false;
	}
	uint image_index;
	rhi::SwapchainStatus acquired = rhi::swapchain_acquire_next_image(&state.swapchain, &state.device, &image_index)!;
	if (acquired == rhi::SwapchainStatus.OUT_OF_DATE) { state.force_rebuild = true; return; }
	state.ring.advance();
	rhi::CommandRingElement element = rhi::command_ring_buffer_get{FB_RING, 1, true}(&state.ring, &state.device, 1);
	rhi::command_ring_element_wait(&element, &state.device)!;
	uint slot = (uint)state.ring.pool_index;
	Upload[UPLOADS_PER_FRAME] uploads = {};
	uint upload_count = 0;
	uint request_count = 0;
	read_feedback(slot, &uploads, &upload_count, &request_count);
	state.uploads_total += upload_count;
	if (state.frame % 60 == 0)
	{
		log::info("[04_svt] frame %d: resident=%d/%d tiles_streamed=%d feedback_pages=%d requested_mip=[%d..%d]",
			(int)state.frame, (int)state.cache.used, (int)NUM_SLOTS, (int)state.uploads_total,
			(int)request_count, (int)state.requested_min_mip, (int)state.requested_max_mip);
	}
	clear_feedback(slot);
	rhi::pool_reset(element.pool, &state.device)!;
	rhi::Cmd* cmd = &element.cmds[0];
	rhi::cmd_begin(cmd, &state.device)!;
	rhi::ResourceState before = state.resources_initialized ? (rhi::ResourceState){ .shader_resource = true } : {};
	rhi::ImageBarrier[2] upload_barriers = {
		{ .image = &state.atlas_image, .before = before, .after = { .copy_dst = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = 1, .layer_count = 1 },
		{ .image = &state.page_table_image, .before = before, .after = { .copy_dst = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = MIP_COUNT, .layer_count = 1 },
	};
	rhi::cmd_resource_barrier(cmd, &state.device, images: upload_barriers[..]);
	record_copy_uploads(cmd, slot, uploads, upload_count);
	rhi::ImageBarrier[2] sampled_barriers = {
		{ .image = &state.atlas_image, .before = { .copy_dst = true }, .after = { .shader_resource = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = 1, .layer_count = 1 },
		{ .image = &state.page_table_image, .before = { .copy_dst = true }, .after = { .shader_resource = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = MIP_COUNT, .layer_count = 1 },
	};
	rhi::cmd_resource_barrier(cmd, &state.device, images: sampled_barriers[..]);
	state.resources_initialized = true;
	ulong now = platform::ticks_ms();
	state.frame_dt = state.last_ticks == 0 ? (float)(1.0 / 60) : (float)(now - state.last_ticks) / 1000;
	state.last_ticks = now;
	float[16] mvp;
	camera_matrix((float)width / height, state.frame_dt, &mvp);
	PushConsts pc;
	make_push_constants(mvp, &pc);
	rhi::ProgramVertexStream[1] streams = { { .binding = 0, .stride = Vertex::size, .per_instance = false } };
	rhi::ProgramVertexAttribute[2] attributes = {
		{ .location = 0, .binding = 0, .format = rhi::Format.RGB32_SFLOAT, .offset = 0 },
		{ .location = 1, .binding = 0, .format = rhi::Format.RG32_SFLOAT, .offset = 12 },
	};
	rhi::Viewport viewport = { .width = width, .height = height, .max_depth = 1 };
	rhi::Rect scissor = { .width = width, .height = height };
	rhi::cmd_begin_rendering(cmd, &state.device, { .render_area = { .width = width, .height = height } });
	rhi::cmd_set_viewport(cmd, &state.device, viewport);
	rhi::cmd_set_scissor(cmd, &state.device, scissor);
	rhi::program_bind_pipeline(&state.feedback_program, &state.device, cmd, 1, { .topology = rhi::PrimitiveTopology.TRIANGLE_LIST, .cull_mode = rhi::CullMode.NONE, .front_face = rhi::FrontFace.CLOCKWISE, .depth_compare = rhi::CompareOp.ALWAYS, .vertex_streams = streams[..], .vertex_attributes = attributes[..] })!;
	rhi::program_push_constants(&state.feedback_program, &state.device, cmd, ((char*)&pc)[:PushConsts::size], 0);
	rhi::program_bind_descriptors(&state.feedback_program, &state.device, cmd, state.frame, (rhi::DescriptorBinding[1]){ rhi::descriptor_binding("feedback_buffer", rhi::descriptor_storage_buffer(&state.feedback_ring[slot], 0, PT_BYTES), 0) }[..], rhi::ProgramBindPoint.GRAPHICS)!;
	rhi::cmd_bind_vertex_buffer(cmd, &state.device, &state.quad_vb, 0);
	rhi::cmd_bind_index_buffer(cmd, &state.device, &state.quad_ib, rhi::IndexType.UINT16);
	rhi::cmd_draw_indexed(cmd, &state.device, PLANE_INDEX.len);
	rhi::cmd_end_rendering(cmd, &state.device);
	rhi::cmd_buffer_barrier(cmd, &state.device, { .buffer = &state.feedback_ring[slot], .before = { .storage_write = true }, .after = { .host_read = true }, .before_stages = { .fragment = true }, .after_stages = { .host = true } });
	rhi::Image image = rhi::swapchain_image(&state.swapchain, image_index);
	rhi::ImageView view = rhi::swapchain_image_view(&state.swapchain, image_index);
	rhi::cmd_image_barrier(cmd, &state.device, { .image = &image, .after = { .render_target = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = 1, .layer_count = 1 });
	rhi::imgui_layer_new_frame(&state.imgui, width, height, state.frame_dt);
	svt_draw_imgui();
	rhi::cmd_begin_rendering(cmd, &state.device, { .color_attachments = { { .view = view, .load_op = rhi::LoadOp.CLEAR, .store_op = rhi::StoreOp.STORE, .clear_color = { 0, 0, 0.05, 1 } } }, .render_area = { .width = width, .height = height } });
	rhi::cmd_set_viewport(cmd, &state.device, viewport);
	rhi::cmd_set_scissor(cmd, &state.device, scissor);
	rhi::program_bind_pipeline(&state.composite_program, &state.device, cmd, 2 | ((ulong)rhi::swapchain_color_format(&state.swapchain) << 8), { .topology = rhi::PrimitiveTopology.TRIANGLE_LIST, .cull_mode = rhi::CullMode.NONE, .front_face = rhi::FrontFace.CLOCKWISE, .depth_compare = rhi::CompareOp.ALWAYS, .colors = { { .format = rhi::swapchain_color_format(&state.swapchain) } }, .vertex_streams = streams[..], .vertex_attributes = attributes[..] })!;
	rhi::program_push_constants(&state.composite_program, &state.device, cmd, ((char*)&pc)[:PushConsts::size], 0);
	rhi::DescriptorBinding[4] descriptors = {
		rhi::descriptor_binding("s_page_table", rhi::descriptor_sampled_image(&state.page_table_view), 0),
		rhi::descriptor_binding("s_atlas", rhi::descriptor_sampled_image(&state.atlas_view), 0),
		rhi::descriptor_binding("page_sampler", rhi::descriptor_sampler(&state.nearest_sampler), 0),
		rhi::descriptor_binding("atlas_sampler", rhi::descriptor_sampler(&state.linear_sampler), 0),
	};
	rhi::program_bind_descriptors(&state.composite_program, &state.device, cmd, state.frame, descriptors[..], rhi::ProgramBindPoint.GRAPHICS)!;
	rhi::cmd_bind_vertex_buffer(cmd, &state.device, &state.quad_vb, 0);
	rhi::cmd_bind_index_buffer(cmd, &state.device, &state.quad_ib, rhi::IndexType.UINT16);
	rhi::cmd_draw_indexed(cmd, &state.device, PLANE_INDEX.len);
	rhi::imgui_layer_render(&state.imgui, &state.device, cmd)!;
	rhi::cmd_end_rendering(cmd, &state.device);
	rhi::cmd_image_barrier(cmd, &state.device, { .image = &image, .before = { .render_target = true }, .after = { .present = true }, .aspect = rhi::BarrierAspect.COLOR, .mip_count = 1, .layer_count = 1 });
	rhi::cmd_end(cmd, &state.device)!;
	rhi::Cmd*[1] commands = { cmd };
	rhi::SwapchainStatus presented = rhi::swapchain_frame_submit(&state.swapchain, &state.device, &state.device.graphics_queue, { .image_index = image_index, .cmds = commands[..], .timeline = &state.timeline, .signal_value = 0, .completion = &element })!;
	if (presented == rhi::SwapchainStatus.OUT_OF_DATE || presented == rhi::SwapchainStatus.SUBOPTIMAL) state.force_rebuild = true;
	state.frame++;
	state.presented++;
}

fn platform::AppResult svt_app_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch err = svt_frame())
	{
		log::error("[04_svt] frame failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit > 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn platform::AppResult svt_event(platform::Event* event)
{
	uint type = event.common.type;
	if (type == sdl3::SDL_EVENT_MOUSE_MOTION)
	{
		sdl3::MouseMotionEvent* motion = (sdl3::MouseMotionEvent*)event;
		rhi::imgui_layer_add_mouse_pos_event(&state.imgui, motion.x, motion.y);
		if (state.fly_mode)
		{
			state.camera_yaw += motion.xrel * 0.0025;
			state.camera_pitch = (float)max(-1.5, min(1.5, (double)state.camera_pitch - motion.yrel * 0.0025));
		}
	}
	else if (type == sdl3::SDL_EVENT_MOUSE_WHEEL)
	{
		sdl3::MouseWheelEvent* wheel = (sdl3::MouseWheelEvent*)event;
		rhi::imgui_layer_add_mouse_wheel_event(&state.imgui, wheel.x, wheel.y);
	}
	else if (type == sdl3::SDL_EVENT_MOUSE_BUTTON_DOWN || type == sdl3::SDL_EVENT_MOUSE_BUTTON_UP)
	{
		sdl3::MouseButtonEvent* button = (sdl3::MouseButtonEvent*)event;
		int mapped = button.button == sdl3::SDL_BUTTON_LEFT ? 0 : button.button == sdl3::SDL_BUTTON_RIGHT ? 1 : button.button == sdl3::SDL_BUTTON_MIDDLE ? 2 : -1;
		if (mapped >= 0) rhi::imgui_layer_add_mouse_button_event(&state.imgui, mapped, type == sdl3::SDL_EVENT_MOUSE_BUTTON_DOWN);
	}
	else if (type == sdl3::SDL_EVENT_KEY_DOWN || type == sdl3::SDL_EVENT_KEY_UP)
	{
		sdl3::KeyboardEvent* key = (sdl3::KeyboardEvent*)event;
		if (key.scancode < state.keys.len) state.keys[key.scancode] = type == sdl3::SDL_EVENT_KEY_DOWN;
		if (type == sdl3::SDL_EVENT_KEY_DOWN && key.scancode == sdl3::SDL_SCANCODE_ESCAPE && state.fly_mode)
		{
			state.fly_mode = false;
			(void)sdl3::set_window_relative_mouse_mode(state.window.handle, false);
		}
	}
	return platform::AppResult.CONTINUE;
}

// Resource initialization is intentionally one stage because the RHI returns
// each handle independently. Keep cleanup handle-based as well, so a failed
// image view, sampler, or ring allocation cannot leak the resources created
// earlier in init_resources().
fn void svt_deinit_resources()
{
	for (uint i = 0; i < FB_RING; i++)
	{
		if (state.staging_ring[i].cookie) rhi::buffer_deinit(&state.staging_ring[i], &state.device);
		if (state.feedback_ring[i].cookie) rhi::buffer_deinit(&state.feedback_ring[i], &state.device);
	}
	if (state.quad_ib.cookie) rhi::buffer_deinit(&state.quad_ib, &state.device);
	if (state.quad_vb.cookie) rhi::buffer_deinit(&state.quad_vb, &state.device);
	if (state.linear_sampler.cookie) rhi::sampler_deinit(&state.linear_sampler, &state.device);
	if (state.nearest_sampler.cookie) rhi::sampler_deinit(&state.nearest_sampler, &state.device);
	if (state.page_table_view.cookie) rhi::image_view_deinit(&state.page_table_view, &state.device);
	if (state.page_table_image.cookie) rhi::image_deinit(&state.page_table_image, &state.device);
	if (state.atlas_view.cookie) rhi::image_view_deinit(&state.atlas_view, &state.device);
	if (state.atlas_image.cookie) rhi::image_deinit(&state.atlas_image, &state.device);
}

fn void svt_app_quit(platform::AppResult result)
{
	(void)result;
	if (state.stage >= Stage.DEVICE) (void)rhi::queue_wait_idle(&state.device.graphics_queue, &state.device);
	if (state.stage >= Stage.COMPOSITE_PROGRAM) rhi::program_deinit(&state.composite_program, &state.device);
	if (state.stage >= Stage.FEEDBACK_PROGRAM) rhi::program_deinit(&state.feedback_program, &state.device);
	if (state.stage >= Stage.IMGUI) svt_deinit_resources();
	if (state.stage >= Stage.IMGUI) { page_cache_deinit(&state.cache); rhi::imgui_layer_deinit(&state.imgui, &state.device); }
	if (state.stage >= Stage.TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= Stage.COMMAND_RING) rhi::command_ring_buffer_deinit{FB_RING, 1, true}(&state.ring, &state.device);
	if (state.stage >= Stage.SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= Stage.DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= Stage.RENDERER) rhi::renderer_deinit();
	int limit = state.frame_limit;
	state = {};
	state.frame_limit = limit;
}

fn platform::App svt_app()
{
	return { .title = "04_svt", .width = 1024, .height = 640, .init = &svt_app_init, .frame = &svt_app_frame, .event = &svt_event, .quit = &svt_app_quit };
}

fn void main(String[] args)
{
	platform::run(svt_app(), args);
}

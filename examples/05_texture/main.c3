// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// A checkerboard texture and alpha-blended quad.  Uses the shared native
// platform::App lifecycle.
module texture_example;

import std::collections::list;
import platform;
import rhi;

const int FRAMES_IN_FLIGHT = 3;
const uint TEX_SIZE = 8;
const rhi::Format TEX_FORMAT = rhi::Format.RGBA8_UNORM;

// The example runner/shader tooling compiles the manifest into these files before checking or building
// the example.  Vulkan consumes SPIR-V and Metal consumes generated MSL; do
// not embed the checked-in shader source files here.
const char[*] TEXTURE_VERTEX_SPV @align(4) = $embed("../../build/examples/05_texture/shaders/05_texture.vert.spv");
const char[*] TEXTURE_FRAGMENT_SPV @align(4) = $embed("../../build/examples/05_texture/shaders/05_texture.frag.spv");
const char[*] TEXTURE_VERTEX_MSL = $embed("../../build/examples/05_texture/shaders/05_texture.vert.metal");
const char[*] TEXTURE_FRAGMENT_MSL = $embed("../../build/examples/05_texture/shaders/05_texture.frag.metal");
const char[*] TEXTURE_VERTEX_WGSL = $embed("../../build/examples/05_texture/shaders/05_texture.vert.wgsl");
const char[*] TEXTURE_FRAGMENT_WGSL = $embed("../../build/examples/05_texture/shaders/05_texture.frag.wgsl");
const char[*] TEXTURE_VERTEX_GLSL = $embed("../../build/examples/05_texture/shaders/05_texture.vert.glsl");
const char[*] TEXTURE_FRAGMENT_GLSL = $embed("../../build/examples/05_texture/shaders/05_texture.frag.glsl");

struct TextureVertex
{
	float[2] position;
	float[2] uv;
}

const TextureVertex[6] QUAD = {
	{ .position = { -0.6, -0.6 }, .uv = { 0, 1 } },
	{ .position = {  0.6, -0.6 }, .uv = { 1, 1 } },
	{ .position = {  0.6,  0.6 }, .uv = { 1, 0 } },
	{ .position = { -0.6, -0.6 }, .uv = { 0, 1 } },
	{ .position = {  0.6,  0.6 }, .uv = { 1, 0 } },
	{ .position = { -0.6,  0.6 }, .uv = { 0, 0 } },
};

enum TextureStage : char
{
	NONE,
	RENDERER,
	DEVICE,
	SWAPCHAIN,
	COMMAND_RING,
	TIMELINE,
	VERTEX_BUFFER,
	IMAGE,
	VIEW,
	SAMPLER,
	SHADER,
	PIPELINE,
}

struct TextureState
{
	platform::Window window;
	TextureStage stage;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true} ring;
	rhi::Timeline timeline;
	rhi::Buffer vertex_buffer;
	rhi::Image image;
	rhi::ImageView view;
	rhi::Sampler sampler;
	rhi::Shader shader;
	rhi::Pipeline pipeline;
	rhi::Format pipeline_format;
	ulong[FRAMES_IN_FLIGHT] slot_values;
	bool poll_timeline;
	bool force_rebuild;
	int frame_limit;
	int presented;
}

TextureState state;

fn void texture_app_parse_args(String[] args)
{
	for (sz i = 0; i < args.len; i += 1)
	{
		if (args[i] != "--frames") continue;
		if (i + 1 >= args.len)
		{
			state.frame_limit = -1;
			continue;
		}
		i += 1;
		state.frame_limit = texture_parse_frame_count(args[i]);
	}
}

fn int texture_parse_frame_count(String text)
{
	if (text.len == 0) return -1;
	int result = 0;
	for (sz i = 0; i < text.len; i += 1)
	{
		char c = text[i];
		if (c < '0' || c > '9') return -1;
		result = result * 10 + (c - '0');
	}
	return result;
}

fn ushort texture_dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn platform::AppResult texture_app_init(platform::Window window)
{
	state = {};
	state.window = window;
	texture_app_parse_args(platform::program_args());
	if (state.frame_limit < 0)
	{
		log::error("[05_texture] --frames requires a non-negative integer");
		return platform::AppResult.FAILURE;
	}
	if (catch err = texture_init(window))
	{
		log::error("[05_texture] initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn void? texture_init(platform::Window window)
{
	if (catch err = platform::renderer_init()) return err~;
	state.stage = RENDERER;

	List{rhi::PhysicalAdapter}? adapters = rhi::enumerate_adapters();
	if (catch err = adapters) return err~;
	defer adapters.free();
	if (adapters.len() == 0) return rhi::INITIALIZATION_FAILED~;

	rhi::Device? device = rhi::device_init(&adapters[rhi::default_select_adapter(adapters.array_view())]);
	if (catch err = device) return err~;
	state.device = device;
	state.stage = DEVICE;

	platform::PixelSize size = platform::window_size_in_pixels(window);
	rhi::Swapchain? swapchain = rhi::swapchain_init(&state.device, {
		.width = texture_dimension(size.width, 640),
		.height = texture_dimension(size.height, 480),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT,
		.request_image_count = (char)FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(window) },
	});
	if (catch err = swapchain) return err~;
	state.swapchain = swapchain;
	state.stage = SWAPCHAIN;

	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true}? ring = rhi::command_ring_buffer_init{FRAMES_IN_FLIGHT, 1, true}(
		&state.device, &state.device.graphics_queue
	);
	if (catch err = ring) return err~;
	state.ring = ring;
	state.stage = COMMAND_RING;

	rhi::Timeline? timeline = rhi::timeline_init(&state.device);
	if (catch err = timeline) return err~;
	state.timeline = timeline;
	state.stage = TIMELINE;

	char[] vertex_bytes = ((char*)&QUAD[0])[:@sizeof(QUAD)];
	rhi::Buffer? vertex_buffer = rhi::buffer_init_general(&state.device, {
		.size = vertex_bytes.len,
		.persistent_map = true,
		.usage = { .vertex_buffer = true },
		.buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST,
	});
	if (catch err = vertex_buffer) return err~;
	state.vertex_buffer = vertex_buffer;
	rhi::buffer_write(&state.vertex_buffer, &state.device, 0, vertex_bytes);
	rhi::buffer_flush(&state.vertex_buffer, &state.device);
	state.stage = VERTEX_BUFFER;

	rhi::Image? image = rhi::image_init(&state.device, {
		.image_type = rhi::ImageType.D2,
		.format = TEX_FORMAT,
		.width = TEX_SIZE,
		.height = TEX_SIZE,
		.depth = 1,
		.mip_levels = 1,
		.array_layers = 1,
		.samples = rhi::ImageSampleCount.S1,
		.tiling = rhi::ImageTiling.OPTIMAL,
		.usage = { .sampled = true, .transfer_dst = true },
		.memory_usage = rhi::ImageMemoryUsage.PREFER_DEVICE,
	});
	if (catch err = image) return err~;
	state.image = image;
	state.stage = IMAGE;

	char[256] pixels;
	texture_fill_checkerboard(&pixels);
	if (catch err = rhi::image_upload(&state.image, &state.device, {
		.data = pixels[..],
		.extent = { .width = TEX_SIZE, .height = TEX_SIZE, .depth = 1 },
		.mip_level = 0,
		.base_array_layer = 0,
		.layer_count = 1,
		.origin = { .x = 0, .y = 0, .z = 0 },
		.bytes_per_row = 0,
		.rows_per_image = 0,
	})) return err~;

	rhi::ImageView? view = rhi::image_view_init(&state.device, &state.image, {
		.view_type = rhi::ViewType.SHADER_RESOURCE_2D,
		.format = TEX_FORMAT,
		.aspect = rhi::ImageAspect.COLOR,
		.base_mip = 0,
		.mip_num = 1,
		.base_layer = 0,
		.layer_num = 1,
	});
	if (catch err = view) return err~;
	state.view = view;
	state.stage = VIEW;

	rhi::Sampler? sampler = rhi::sampler_init(&state.device, {
		.min_filter = rhi::SamplerFilter.NEAREST,
		.mag_filter = rhi::SamplerFilter.NEAREST,
		.mip_map_mode = rhi::SamplerMipmap.NEAREST,
		.address_u = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.address_v = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.address_w = rhi::SamplerAddress.CLAMP_TO_EDGE,
		.max_anisotropy = 1,
		.compare_func = rhi::SamplerCompare.NEVER,
	});
	if (catch err = sampler) return err~;
	state.sampler = sampler;
	state.stage = SAMPLER;

	rhi::Shader? shader = rhi::shader_init_graphics(&state.device, texture_shader_stages());
	if (catch err = shader) return err~;
	state.shader = shader;
	state.stage = SHADER;

	state.pipeline_format = rhi::swapchain_color_format(&state.swapchain);
	if (catch err = texture_pipeline_init(state.pipeline_format)) return err~;
	state.stage = PIPELINE;
	state.poll_timeline = rhi::IS_WEB;
	state.slot_values = {};
	state.force_rebuild = false;
	state.presented = 0;
}

fn void texture_fill_checkerboard(char[256]* pixels)
{
	for (uint y = 0; y < TEX_SIZE; y += 1)
	{
		for (uint x = 0; x < TEX_SIZE; x += 1)
		{
			uint offset = (y * TEX_SIZE + x) * 4;
			bool red = ((x + y) % 2) == 0;
			(*pixels)[offset + 0] = red ? 220 : 255;
			(*pixels)[offset + 1] = red ? 40 : 255;
			(*pixels)[offset + 2] = red ? 40 : 255;
			(*pixels)[offset + 3] = red ? 255 : 128;
		}
	}
}

fn rhi::ShaderGraphicsOptions texture_shader_stages()
{
	char[] vertex_data;
	char[] fragment_data;
	String vertex_entry;
	String fragment_entry;
	switch (rhi::renderer.backend)
	{
		case rhi::Backend.MTL:
			vertex_data = TEXTURE_VERTEX_MSL[..];
			fragment_data = TEXTURE_FRAGMENT_MSL[..];
			vertex_entry = "vertexMain";
			fragment_entry = "fragmentMain";
		case rhi::Backend.VK:
			vertex_data = TEXTURE_VERTEX_SPV[..];
			fragment_data = TEXTURE_FRAGMENT_SPV[..];
			vertex_entry = "main";
			fragment_entry = "main";
		case rhi::Backend.WGPU:
			vertex_data = TEXTURE_VERTEX_WGSL[..];
			fragment_data = TEXTURE_FRAGMENT_WGSL[..];
			vertex_entry = "vertexMain";
			fragment_entry = "fragmentMain";
		case rhi::Backend.WEBGL:
			vertex_data = TEXTURE_VERTEX_GLSL[..];
			fragment_data = TEXTURE_FRAGMENT_GLSL[..];
			vertex_entry = "main";
			fragment_entry = "main";
		default:
			vertex_data = TEXTURE_VERTEX_SPV[..];
			fragment_data = TEXTURE_FRAGMENT_SPV[..];
			vertex_entry = "main";
			fragment_entry = "main";
	}
	return {
		.vertex_stage = { .data = vertex_data, .entry_point = vertex_entry },
		.has_vertex_stage = true,
		.fragment_stage = { .data = fragment_data, .entry_point = fragment_entry },
		.has_fragment_stage = true,
	};
}

fn void? texture_pipeline_init(rhi::Format format)
{
	rhi::Pipeline? pipeline = rhi::pipeline_init_graphics(&state.device, {
		.shader = &state.shader,
		.colors = { { .format = format, .blend = rhi::BLEND_STATE_STRAIGHT_ALPHA } },
		.has_vertex_layout = true,
		.vertex_layout = {
			.stride = TextureVertex::size,
			.attributes = {
				{ .location = 0, .format = rhi::VertexFormat.FLOAT2, .offset = 0 },
				{ .location = 1, .format = rhi::VertexFormat.FLOAT2, .offset = 2 * float::size },
			},
		},
		.texture_bindings = {{
			.name = "tex",
			.binding = 0,
			.sampler_name = "smp",
			.has_sampler_name = true,
			.sampler_binding = 1,
			.has_sampler_binding = true,
		}},
	});
	if (catch err = pipeline) return err~;
	state.pipeline = pipeline;
}

fn platform::AppResult texture_app_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch err = texture_frame())
	{
		log::error("[05_texture] frame submission failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit > 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn void? texture_frame()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	if (size.width == 0 || size.height == 0) return;
	ushort requested_width = texture_dimension(size.width, 1);
	ushort requested_height = texture_dimension(size.height, 1);
	if (state.force_rebuild || state.swapchain.width != requested_width || state.swapchain.height != requested_height)
	{
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)) return err~;
		if (catch err = rhi::swapchain_recreate(&state.swapchain, &state.device, requested_width, requested_height)) return err~;
		state.force_rebuild = false;
		rhi::Format format = rhi::swapchain_color_format(&state.swapchain);
		if (format != state.pipeline_format)
		{
			rhi::pipeline_deinit(&state.pipeline, &state.device);
			state.stage = SHADER;
			if (catch err = texture_pipeline_init(format)) return err~;
			state.pipeline_format = format;
			state.stage = PIPELINE;
		}
	}

	if (state.poll_timeline)
	{
		ulong? completed_value = rhi::timeline_completed(&state.timeline, &state.device);
		if (catch err = completed_value) return err~;
		ulong completed = completed_value;
		sz next_slot = (state.ring.pool_index + 1) % FRAMES_IN_FLIGHT;
		if (state.slot_values[next_slot] > completed) return;
	}

	uint image_index;
	rhi::SwapchainStatus? acquired = rhi::swapchain_acquire_next_image(&state.swapchain, &state.device, &image_index);
	if (catch err = acquired) return err~;
	if (acquired == rhi::SwapchainStatus.OUT_OF_DATE)
	{
		state.force_rebuild = true;
		return;
	}

	state.ring.advance();
	rhi::CommandRingElement element = rhi::command_ring_buffer_get{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device, 1);
	if (catch err = rhi::command_ring_element_wait(&element, &state.device)) return err~;
	if (catch err = rhi::pool_reset(element.pool, &state.device)) return err~;
	rhi::Cmd* cmd = &element.cmds[0];
	if (catch err = rhi::cmd_begin(cmd, &state.device)) return err~;

	rhi::Image image = rhi::swapchain_image(&state.swapchain, image_index);
	rhi::ImageView view = rhi::swapchain_image_view(&state.swapchain, image_index);
	uint width = state.swapchain.width;
	uint height = state.swapchain.height;
	rhi::cmd_image_barrier(cmd, &state.device, {
		.image = &image,
		.after = { .render_target = true },
		.aspect = rhi::BarrierAspect.COLOR,
		.mip_count = 1,
		.layer_count = 1,
	});
	rhi::cmd_begin_rendering(cmd, &state.device, {
		.color_attachments = {{
			.view = view,
			.load_op = rhi::LoadOp.CLEAR,
			.store_op = rhi::StoreOp.STORE,
			.clear_color = { 0.05, 0.35, 0.15, 1 },
		}},
		.render_area = { .width = width, .height = height },
	});
	rhi::cmd_set_viewport(cmd, &state.device, { .width = (float)width, .height = (float)height, .min_depth = 0, .max_depth = 1 });
	rhi::cmd_set_scissor(cmd, &state.device, { .width = width, .height = height });
	rhi::cmd_bind_pipeline(cmd, &state.device, &state.pipeline);
	if (catch err = rhi::cmd_bind_descriptors(cmd, &state.device, &state.pipeline, {
		rhi::descriptor_binding("tex", rhi::descriptor_sampled_image(&state.view), 0),
		rhi::descriptor_binding("smp", rhi::descriptor_sampler(&state.sampler), 0),
	})) return err~;
	rhi::cmd_bind_vertex_buffer(cmd, &state.device, &state.vertex_buffer, 0);
	rhi::cmd_draw(cmd, &state.device, QUAD.len);
	rhi::cmd_end_rendering(cmd, &state.device);
	rhi::cmd_image_barrier(cmd, &state.device, {
		.image = &image,
		.before = { .render_target = true },
		.after = { .present = true },
		.aspect = rhi::BarrierAspect.COLOR,
		.mip_count = 1,
		.layer_count = 1,
	});
	if (catch err = rhi::cmd_end(cmd, &state.device)) return err~;

	rhi::Cmd*[1] cmds = { cmd };
	rhi::SwapchainStatus? submitted = rhi::swapchain_frame_submit(&state.swapchain, &state.device, &state.device.graphics_queue, {
		.image_index = image_index,
		.cmds = cmds[..],
		.timeline = &state.timeline,
		.signal_value = 0,
		.completion = &element,
	});
	if (catch err = submitted) return err~;
	state.slot_values[state.ring.pool_index] = rhi::timeline_pending(&state.timeline);
	if (submitted == rhi::SwapchainStatus.OUT_OF_DATE || submitted == rhi::SwapchainStatus.SUBOPTIMAL) state.force_rebuild = true;
	state.presented += 1;
}

fn platform::AppResult texture_event(platform::Event* event)
{
	(void)event;
	return platform::AppResult.CONTINUE;
}

fn void texture_app_quit(platform::AppResult result)
{
	(void)result;
	if (state.stage >= DEVICE)
	{
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device))
		{
			log::error("[05_texture] queue idle failed during shutdown");
		}
	}
	if (state.stage >= PIPELINE) rhi::pipeline_deinit(&state.pipeline, &state.device);
	if (state.stage >= SHADER) rhi::shader_deinit(&state.shader, &state.device);
	if (state.stage >= SAMPLER) rhi::sampler_deinit(&state.sampler, &state.device);
	if (state.stage >= VIEW) rhi::image_view_deinit(&state.view, &state.device);
	if (state.stage >= IMAGE) rhi::image_deinit(&state.image, &state.device);
	if (state.stage >= VERTEX_BUFFER) rhi::buffer_deinit(&state.vertex_buffer, &state.device);
	if (state.stage >= TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= COMMAND_RING) rhi::command_ring_buffer_deinit{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device);
	if (state.stage >= SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= RENDERER) rhi::renderer_deinit();
	int frame_limit = state.frame_limit;
	state = {};
	state.frame_limit = frame_limit;
}

fn platform::App texture_app()
{
	return {
		.title = "05_texture",
		.width = 640,
		.height = 480,
		.init = &texture_app_init,
		.frame = &texture_app_frame,
		.event = &texture_event,
		.quit = &texture_app_quit,
	};
}

fn void main(String[] args)
{
	platform::run(texture_app(), args);
}

fn void texture_web_start(String[] args) @feat(WASM) @export("_start")
{
	platform::run(texture_app(), args);
}

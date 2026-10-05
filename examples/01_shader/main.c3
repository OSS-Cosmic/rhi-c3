// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// A fullscreen triangle whose vertex positions come from SV_VertexID.  This
// is the C3 rendering half of examples/01_shader/main.odin.  The shared
// platform::App lifecycle owns the window and event loop.
//
// The shader manifest is compiled by build.py before this source is checked.
// Vulkan consumes SPIR-V with the generated "main" entry point; Metal
// consumes the generated MSL source and the original vertexMain/fragmentMain
// entry points.  The command recording below does not branch on the backend.
module example_01_shader;

import std::collections::list;
import platform;
import rhi;

const int FRAMES_IN_FLIGHT = 3;

// Keep the SPIR-V blobs aligned: Vulkan consumes their bytes as uint words.
const char[*] FULLSCREEN_VERT_SPV @align(4) = $embed("../../build/examples/01_shader/shaders/fullscreen.vert.spv");
const char[*] MANDELBROT_FRAG_SPV @align(4) = $embed("../../build/examples/01_shader/shaders/mandelbrot.frag.spv");

const char[*] FULLSCREEN_VERT_MSL = $embed("../../build/examples/01_shader/shaders/fullscreen.vert.metal");
const char[*] MANDELBROT_FRAG_MSL = $embed("../../build/examples/01_shader/shaders/mandelbrot.frag.metal");
const char[*] FULLSCREEN_VERT_WGSL = $embed("../../build/examples/01_shader/shaders/fullscreen.vert.wgsl");
const char[*] MANDELBROT_FRAG_WGSL = $embed("../../build/examples/01_shader/shaders/mandelbrot.frag.wgsl");
const char[*] FULLSCREEN_VERT_GLSL = $embed("../../build/examples/01_shader/shaders/fullscreen.vert.glsl");
const char[*] MANDELBROT_FRAG_GLSL = $embed("../../build/examples/01_shader/shaders/mandelbrot.frag.glsl");

enum ShaderStage : char
{
	NONE,
	RENDERER,
	DEVICE,
	SWAPCHAIN,
	COMMAND_RING,
	TIMELINE,
	SHADER,
	PIPELINE,
}

struct ShaderState
{
	platform::Window window;
	ShaderStage stage;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true} ring;
	rhi::Timeline timeline;
	rhi::Shader shader;
	rhi::Pipeline pipeline;
	rhi::Format pipeline_format;
	ulong[FRAMES_IN_FLIGHT] slot_values;
	bool poll_timeline;
	bool force_rebuild;
	int frame_limit;
	int presented;
}

ShaderState state;

fn void shader_app_parse_args(String[] args)
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
		state.frame_limit = shader_parse_frame_count(args[i]);
	}
}

fn int shader_parse_frame_count(String text)
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

fn ushort shader_dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn platform::AppResult shader_app_init(platform::Window window)
{
	state = {};
	state.window = window;
	shader_app_parse_args(platform::program_args());
	if (state.frame_limit < 0) return platform::AppResult.FAILURE;
	if (catch err = shader_init(window))
	{
		log::error("[01_shader] initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn void? shader_init(platform::Window window)
{
	platform::PixelSize size = platform::window_size_in_pixels(window);
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

	rhi::SwapchainDesc swapchain_desc = {
		.width = shader_dimension(size.width, 640),
		.height = shader_dimension(size.height, 480),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT,
		.request_image_count = (char)FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(window) },
	};
	rhi::Swapchain? swapchain = rhi::swapchain_init(&state.device, swapchain_desc);
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

	rhi::ShaderGraphicsOptions stages = shader_stages();
	rhi::Shader? shader = rhi::shader_init_graphics(&state.device, stages);
	if (catch err = shader) return err~;
	state.shader = shader;
	state.stage = SHADER;

	state.pipeline_format = rhi::swapchain_color_format(&state.swapchain);
	if (catch err = shader_pipeline_init(state.pipeline_format)) return err~;
	state.stage = PIPELINE;
	state.poll_timeline = rhi::IS_WEB;
	state.slot_values = {};
	state.force_rebuild = false;
	state.presented = 0;
}

fn rhi::ShaderGraphicsOptions shader_stages()
{
	if (rhi::renderer.backend == rhi::Backend.MTL)
	{
		return {
			.vertex_stage = { .data = FULLSCREEN_VERT_MSL[..], .entry_point = "vertexMain" },
			.has_vertex_stage = true,
			.fragment_stage = { .data = MANDELBROT_FRAG_MSL[..], .entry_point = "fragmentMain" },
			.has_fragment_stage = true,
		};
	}
	if (rhi::renderer.backend == rhi::Backend.WGPU)
	{
		return {
			.vertex_stage = { .data = FULLSCREEN_VERT_WGSL[..], .entry_point = "vertexMain" },
			.has_vertex_stage = true,
			.fragment_stage = { .data = MANDELBROT_FRAG_WGSL[..], .entry_point = "fragmentMain" },
			.has_fragment_stage = true,
		};
	}
	if (rhi::renderer.backend == rhi::Backend.WEBGL)
	{
		return {
			.vertex_stage = { .data = FULLSCREEN_VERT_GLSL[..], .entry_point = "main" },
			.has_vertex_stage = true,
			.fragment_stage = { .data = MANDELBROT_FRAG_GLSL[..], .entry_point = "main" },
			.has_fragment_stage = true,
		};
	}

	// The native non-Metal target is Vulkan.  Slang renames both SPIR-V entry
	// points to main, which is the entry name required by the Vulkan backend.
	return {
		.vertex_stage = { .data = FULLSCREEN_VERT_SPV[..], .entry_point = "main" },
		.has_vertex_stage = true,
		.fragment_stage = { .data = MANDELBROT_FRAG_SPV[..], .entry_point = "main" },
		.has_fragment_stage = true,
	};
}

fn void? shader_pipeline_init(rhi::Format format)
{
	rhi::Pipeline? pipeline = rhi::pipeline_init_graphics(&state.device, {
		.shader = &state.shader,
		.colors = { { .format = format } },
		// No vertex layout: the vertex shader derives the fullscreen triangle
		// from the vertex id, and the fragment shader only consumes its UV.
	});
	if (catch err = pipeline) return err~;
	state.pipeline = pipeline;
}

fn platform::AppResult shader_app_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch err = shader_frame())
	{
		log::error("[01_shader] frame submission failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit > 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn void? shader_frame()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	if (size.width == 0 || size.height == 0) return;
	ushort requested_width = shader_dimension(size.width, 1);
	ushort requested_height = shader_dimension(size.height, 1);
	if (state.force_rebuild || state.swapchain.width != requested_width || state.swapchain.height != requested_height)
	{
		// Vulkan destroys the old swapchain during recreation.  Waiting here
		// also makes replacing a format-dependent pipeline safe.  Metal's
		// recreation path accepts the same backend-neutral sequence.
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)) return err~;
		if (catch err = rhi::swapchain_recreate(&state.swapchain, &state.device, requested_width, requested_height)) return err~;
		state.force_rebuild = false;

		rhi::Format format = rhi::swapchain_color_format(&state.swapchain);
		if (format != state.pipeline_format)
		{
			rhi::pipeline_deinit(&state.pipeline, &state.device);
			state.stage = SHADER;
			if (catch err = shader_pipeline_init(format)) return err~;
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
	rhi::SwapchainStatus acquired_status = acquired;
	if (acquired_status == rhi::SwapchainStatus.OUT_OF_DATE)
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
			.clear_color = { 0, 0, 0, 1 },
		}},
		.render_area = { .width = width, .height = height },
	});
	rhi::cmd_set_viewport(cmd, &state.device, { .width = (float)width, .height = (float)height, .min_depth = 0, .max_depth = 1 });
	rhi::cmd_set_scissor(cmd, &state.device, { .width = width, .height = height });
	rhi::cmd_bind_pipeline(cmd, &state.device, &state.pipeline);
	rhi::cmd_draw(cmd, &state.device, 3);
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
	rhi::SwapchainStatus submitted_status = submitted;
	if (acquired_status == rhi::SwapchainStatus.SUBOPTIMAL
		|| submitted_status == rhi::SwapchainStatus.OUT_OF_DATE
		|| submitted_status == rhi::SwapchainStatus.SUBOPTIMAL)
	{
		state.force_rebuild = true;
	}
	state.presented += 1;
}

fn void shader_app_quit(platform::AppResult result)
{
	(void)result;
	if (state.stage >= DEVICE)
	{
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device))
		{
			log::error("[01_shader] queue idle failed during shutdown");
		}
	}
	if (state.stage >= PIPELINE) rhi::pipeline_deinit(&state.pipeline, &state.device);
	if (state.stage >= SHADER) rhi::shader_deinit(&state.shader, &state.device);
	if (state.stage >= TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= COMMAND_RING) rhi::command_ring_buffer_deinit{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device);
	if (state.stage >= SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= RENDERER) rhi::renderer_deinit();
	int frame_limit = state.frame_limit;
	state = {};
	state.frame_limit = frame_limit;
}

fn platform::App shader_app()
{
	return {
		.title = "01_shader",
		.width = 640,
		.height = 480,
		.init = &shader_app_init,
		.frame = &shader_app_frame,
		.quit = &shader_app_quit,
	};
}

fn void main(String[] args)
{
	platform::run(shader_app(), args);
}

fn void shader_web_start(String[] args) @feat(WASM) @export("_start")
{
	platform::run(shader_app(), args);
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// A rotating, indexed cube. Uses the shared platform::App lifecycle.
//
// The rendering path itself only uses rhi's backend-neutral API. In
// particular, vertex slot 0 is intentional: the Metal backend adds
// MTL_VERTEX_BUFFER_BASE (1) internally to both its descriptor and binding.
// Do not compensate for that convention in this example.
module mesh_example;
import std::collections::list;
import platform;
import rhi;

const int FRAMES_IN_FLIGHT = 3;
const rhi::Format DEPTH_FORMAT = rhi::Format.D32_SFLOAT;

// The C3 shader manifest builds these blobs before the example is checked or
// run. Vulkan consumes SPIR-V and Metal consumes generated MSL.
const char[*] MESH_VERTEX_SPV @align(4) = $embed("../../build/examples/02_mesh/shaders/02_mesh.vert.spv");
const char[*] MESH_FRAGMENT_SPV @align(4) = $embed("../../build/examples/02_mesh/shaders/02_mesh.frag.spv");
const char[*] MESH_VERTEX_MSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.vert.metal");
const char[*] MESH_FRAGMENT_MSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.frag.metal");
const char[*] MESH_VERTEX_WGSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.vert.wgsl");
const char[*] MESH_FRAGMENT_WGSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.frag.wgsl");
const char[*] MESH_VERTEX_GLSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.vert.glsl");
const char[*] MESH_FRAGMENT_GLSL = $embed("../../build/examples/02_mesh/shaders/02_mesh.frag.glsl");

struct PushConsts
{
	float time;
	float aspect;
	float y_sign;
}

// The cube's 24 float3 positions and 36 uint16 indices are kept byte-for-byte
// stable.
const ushort[36] CUBE_INDEX = {
	0, 1, 2, 2, 1, 3,
	4, 6, 5, 5, 6, 7,
	4, 5, 0, 0, 5, 1,
	2, 3, 6, 6, 3, 7,
	4, 0, 6, 6, 0, 2,
	1, 5, 3, 3, 5, 7,
};

const float[24] CUBE_MESH = {
	-0.5, -0.5, -0.5,
	 0.5, -0.5, -0.5,
	-0.5,  0.5, -0.5,
	 0.5,  0.5, -0.5,
	-0.5, -0.5,  0.5,
	 0.5, -0.5,  0.5,
	-0.5,  0.5,  0.5,
	 0.5,  0.5,  0.5,
};

enum MeshStage : char
{
	NONE,
	RENDERER,
	DEVICE,
	SWAPCHAIN,
	COMMAND_RING,
	TIMELINE,
	INDEX_BUFFER,
	BUFFERS,
	DEPTH,
	SHADER,
	PIPELINE,
}

struct MeshState
{
	platform::Window window;
	MeshStage stage;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true} ring;
	rhi::Timeline timeline;
	rhi::Buffer index_buffer;
	rhi::Buffer vertex_buffer;
	rhi::Image depth_image;
	rhi::ImageView depth_view;
	rhi::Shader shader;
	rhi::Pipeline pipeline;
	rhi::Format pipeline_format;
	ulong[FRAMES_IN_FLIGHT] slot_values;
	bool poll_timeline;
	bool force_rebuild;
	int frame_limit;
	int presented;
}

MeshState state;

// Parse the command-line arguments forwarded by platform::run. The last
// --frames wins; zero means run forever and a
// negative value makes mesh_app_init fail.
fn void mesh_app_parse_args(String[] args)
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
		state.frame_limit = mesh_parse_frame_count(args[i]);
	}
}

fn int mesh_parse_frame_count(String text)
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

fn ushort mesh_dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn platform::AppResult mesh_app_init(platform::Window window)
{
	state = {};
	state.window = window;
	mesh_app_parse_args(platform::program_args());
	if (state.frame_limit < 0) return platform::AppResult.FAILURE;
	if (catch err = mesh_init(window))
	{
		log::error("[02_mesh] initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn void? mesh_init(platform::Window window)
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

	rhi::Swapchain? swapchain = rhi::swapchain_init(&state.device, {
		.width = mesh_dimension(size.width, 640),
		.height = mesh_dimension(size.height, 480),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT,
		.request_image_count = (char)FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(window) },
	});
	if (catch err = swapchain) return err~;
	state.swapchain = swapchain;
	state.stage = SWAPCHAIN;

	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true}? ring = rhi::command_ring_buffer_init{FRAMES_IN_FLIGHT, 1, true}(&state.device, &state.device.graphics_queue);
	if (catch err = ring) return err~;
	state.ring = ring;
	state.stage = COMMAND_RING;

	rhi::Timeline? timeline = rhi::timeline_init(&state.device);
	if (catch err = timeline) return err~;
	state.timeline = timeline;
	state.stage = TIMELINE;

	char[] index_bytes = ((char*)&CUBE_INDEX[0])[:@sizeof(CUBE_INDEX)];
	rhi::Buffer? index_buffer = rhi::buffer_init_general(&state.device, {
		.size = index_bytes.len,
		.persistent_map = true,
		.usage = { .index_buffer = true },
		.buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST,
	});
	if (catch err = index_buffer) return err~;
	state.index_buffer = index_buffer;
	state.stage = INDEX_BUFFER;
	rhi::buffer_write(&state.index_buffer, &state.device, 0, index_bytes);
	rhi::buffer_flush(&state.index_buffer, &state.device);

	char[] vertex_bytes = ((char*)&CUBE_MESH[0])[:@sizeof(CUBE_MESH)];
	rhi::Buffer? vertex_buffer = rhi::buffer_init_general(&state.device, {
		.size = vertex_bytes.len,
		.persistent_map = true,
		.usage = { .vertex_buffer = true },
		.buffer_usage = rhi::BufferMemoryUsage.PREFER_HOST,
	});
	if (catch err = vertex_buffer) return err~;
	state.vertex_buffer = vertex_buffer;
	state.stage = BUFFERS;
	rhi::buffer_write(&state.vertex_buffer, &state.device, 0, vertex_bytes);
	rhi::buffer_flush(&state.vertex_buffer, &state.device);

	if (catch err = mesh_depth_init(state.swapchain.width, state.swapchain.height)) return err~;
	state.stage = DEPTH;

	rhi::ShaderGraphicsOptions stages = mesh_shader_stages();
	rhi::Shader? shader = rhi::shader_init_graphics(&state.device, stages);
	if (catch err = shader) return err~;
	state.shader = shader;
	state.stage = SHADER;

	state.pipeline_format = rhi::swapchain_color_format(&state.swapchain);
	if (catch err = mesh_pipeline_init(state.pipeline_format)) return err~;
	state.stage = PIPELINE;
	state.poll_timeline = rhi::IS_WEB;
	state.slot_values = {};
	state.force_rebuild = false;
	state.presented = 0;
}

fn void? mesh_depth_init(ushort width, ushort height)
{
	rhi::Image? image = rhi::image_init(&state.device, {
		.image_type = rhi::ImageType.D2,
		.format = DEPTH_FORMAT,
		.width = width,
		.height = height,
		.depth = 1,
		.mip_levels = 1,
		.array_layers = 1,
		.samples = rhi::ImageSampleCount.S1,
		.tiling = rhi::ImageTiling.OPTIMAL,
		.usage = { .depth_stencil_attachment = true },
		.memory_usage = rhi::ImageMemoryUsage.PREFER_DEVICE,
	});
	if (catch err = image) return err~;
	state.depth_image = image;

	rhi::ImageView? view = rhi::image_view_init(&state.device, &state.depth_image, {
		.view_type = rhi::ViewType.DEPTH_STENCIL_ATTACHMENT,
		.format = DEPTH_FORMAT,
		.aspect = rhi::ImageAspect.DEPTH,
		.mip_num = 1,
		.layer_num = 1,
	});
	if (catch err = view)
	{
		rhi::image_deinit(&state.depth_image, &state.device);
		state.depth_image = {};
		return err~;
	}
	state.depth_view = view;
}

fn void mesh_depth_deinit()
{
	rhi::image_view_deinit(&state.depth_view, &state.device);
	rhi::image_deinit(&state.depth_image, &state.device);
	state.depth_view = {};
	state.depth_image = {};
}

fn rhi::ShaderGraphicsOptions mesh_shader_stages()
{
	char[] vertex_data;
	char[] fragment_data;
	String vertex_entry;
	String fragment_entry;
	switch (rhi::renderer.backend)
	{
		case rhi::Backend.VK:
			vertex_data = MESH_VERTEX_SPV[..];
			fragment_data = MESH_FRAGMENT_SPV[..];
			vertex_entry = "main";
			fragment_entry = "main";
	case rhi::Backend.MTL:
			vertex_data = MESH_VERTEX_MSL[..];
			fragment_data = MESH_FRAGMENT_MSL[..];
			vertex_entry = "vertexMain";
			fragment_entry = "fragmentMain";
		case rhi::Backend.WGPU:
			vertex_data = MESH_VERTEX_WGSL[..];
			fragment_data = MESH_FRAGMENT_WGSL[..];
			vertex_entry = "vertexMain";
			fragment_entry = "fragmentMain";
		case rhi::Backend.WEBGL:
			vertex_data = MESH_VERTEX_GLSL[..];
			fragment_data = MESH_FRAGMENT_GLSL[..];
			vertex_entry = "main";
			fragment_entry = "main";
		default:
			// mesh_renderer_options only selects backends with embedded outputs.
			vertex_data = MESH_VERTEX_SPV[..];
			fragment_data = MESH_FRAGMENT_SPV[..];
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

fn void? mesh_pipeline_init(rhi::Format format)
{
	rhi::Pipeline? pipeline = rhi::pipeline_init_graphics(&state.device, {
		.shader = &state.shader,
		.colors = { { .format = format } },
		.has_depth = true,
		.depth = { .format = DEPTH_FORMAT, .write = true, .compare = rhi::CompareOp.LESS },
		.has_vertex_layout = true,
		.vertex_layout = {
			.stride = 3 * float::size,
			.attributes = { { .location = 0, .format = rhi::VertexFormat.FLOAT3, .offset = 0 } },
		},
		.push_constant_size = PushConsts::size,
	});
	if (catch err = pipeline) return err~;
	state.pipeline = pipeline;
}

fn platform::AppResult mesh_app_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch err = mesh_frame())
	{
		log::error("[02_mesh] frame submission failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit > 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn void? mesh_frame()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	if (size.width == 0 || size.height == 0) return;
	ushort requested_width = mesh_dimension(size.width, 1);
	ushort requested_height = mesh_dimension(size.height, 1);
	if (state.force_rebuild || state.swapchain.width != requested_width || state.swapchain.height != requested_height)
	{
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)) return err~;
		if (catch err = rhi::swapchain_recreate(&state.swapchain, &state.device, requested_width, requested_height)) return err~;
		state.force_rebuild = false;
		state.stage = BUFFERS;
		mesh_depth_deinit();
		if (catch err = mesh_depth_init(state.swapchain.width, state.swapchain.height)) return err~;
		state.stage = DEPTH;

		rhi::Format format = rhi::swapchain_color_format(&state.swapchain);
		if (format != state.pipeline_format)
		{
			rhi::pipeline_deinit(&state.pipeline, &state.device);
			state.stage = SHADER;
			if (catch err = mesh_pipeline_init(format)) return err~;
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
	rhi::cmd_image_barrier(cmd, &state.device, {
		.image = &state.depth_image,
		.after = { .depth_write = true },
		.aspect = rhi::BarrierAspect.DEPTH,
		.mip_count = 1,
		.layer_count = 1,
	});
	rhi::cmd_begin_rendering(cmd, &state.device, {
		.color_attachments = { { .view = view, .load_op = rhi::LoadOp.CLEAR, .store_op = rhi::StoreOp.STORE, .clear_color = { 0, 0, 0, 1 } } },
		.render_area = { .width = width, .height = height },
		.depth_attachment = { .view = state.depth_view, .load_op = rhi::LoadOp.CLEAR, .store_op = rhi::StoreOp.STORE, .clear_depth = 1 },
		.has_depth_attachment = true,
	});
	rhi::cmd_set_viewport(cmd, &state.device, { .width = (float)width, .height = (float)height, .min_depth = 0, .max_depth = 1 });
	rhi::cmd_set_scissor(cmd, &state.device, { .width = width, .height = height });
	rhi::cmd_bind_pipeline(cmd, &state.device, &state.pipeline);
	// Slot 0 is the RHI slot; Metal maps it to native vertex buffer index 1.
	rhi::cmd_bind_vertex_buffer(cmd, &state.device, &state.vertex_buffer, 0);
	rhi::cmd_bind_index_buffer(cmd, &state.device, &state.index_buffer, rhi::IndexType.UINT16);
	PushConsts push = { .time = (float)platform::ticks_ms() / 1000.0, .aspect = (float)width / (float)height, .y_sign = -1 };
	rhi::cmd_set_push_constants(cmd, &state.device, &state.pipeline, ((char*)&push)[:PushConsts::size]);
	rhi::cmd_draw_indexed(cmd, &state.device, CUBE_INDEX.len);
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

fn void mesh_app_quit(platform::AppResult result)
{
	(void)result;
	if (state.stage >= DEVICE)
	{
		if (catch err = rhi::queue_wait_idle(&state.device.graphics_queue, &state.device))
		{
			log::error("[02_mesh] queue idle failed during shutdown");
		}
	}
	if (state.stage >= PIPELINE) rhi::pipeline_deinit(&state.pipeline, &state.device);
	if (state.stage >= SHADER) rhi::shader_deinit(&state.shader, &state.device);
	if (state.stage >= DEPTH) mesh_depth_deinit();
	if (state.stage >= BUFFERS) rhi::buffer_deinit(&state.vertex_buffer, &state.device);
	if (state.stage >= INDEX_BUFFER) rhi::buffer_deinit(&state.index_buffer, &state.device);
	if (state.stage >= TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= COMMAND_RING) rhi::command_ring_buffer_deinit{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device);
	if (state.stage >= SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= RENDERER) rhi::renderer_deinit();
	int frame_limit = state.frame_limit;
	state = {};
	state.frame_limit = frame_limit;
}

fn platform::App mesh_app()
{
	return {
		.title = "02_mesh",
		.width = 640,
		.height = 480,
		.init = &mesh_app_init,
		.frame = &mesh_app_frame,
		.quit = &mesh_app_quit,
	};
}

fn void main(String[] args)
{
	platform::run(mesh_app(), args);
}

fn void mesh_web_start(String[] args) @feat(WASM) @export("_start")
{
	platform::run(mesh_app(), args);
}

// 00_clear: the C3 counterpart of examples/00_clear/main.odin.
//
// The shared platform::App lifecycle owns the native and web entry points.
module example_00_clear;

import platform;
import rhi;
import std::collections::list;

const uint FRAMES_IN_FLIGHT = 3;

enum ClearStage
{
	NONE,
	RENDERER,
	DEVICE,
	SWAPCHAIN,
	COMMAND_RING,
	TIMELINE,
}

struct ClearState
{
	platform::Window window;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true} ring;
	rhi::Timeline timeline;
	ulong[FRAMES_IN_FLIGHT] slot_values;
	ClearStage stage;
	bool force_rebuild;
	bool invalid_args;
	uint frame_limit;
	uint presented;
}

ClearState state;

fn void clear_parse_args(String[] args)
{
	state.frame_limit = 0;
	state.invalid_args = false;
	for (sz i = 0; i < args.len; i++)
	{
		if (args[i] != "--frames") continue;
		if (i + 1 >= args.len)
		{
			state.invalid_args = true;
			return;
		}

		uint? parsed = args[i + 1].to_uint();
		if (catch parsed)
		{
			state.invalid_args = true;
			return;
		}
		state.frame_limit = parsed;
		i++;
	}
}

fn ushort clear_dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn void? clear_init_renderer()
{
	return platform::renderer_init();
}

fn void? clear_init_rhi()
{
	if (catch err = clear_init_renderer()) return err~;
	state.stage = ClearStage.RENDERER;

	List{rhi::PhysicalAdapter}? adapters = rhi::enumerate_adapters();
	if (catch err = adapters) return err~;
	defer adapters.free();
	if (adapters.len() == 0) return rhi::INITIALIZATION_FAILED~;
	rhi::Device? device = rhi::device_init(&adapters[rhi::default_select_adapter(adapters.array_view())]);
	if (catch err = device) return err~;
	state.device = device;
	state.stage = ClearStage.DEVICE;

	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	rhi::SwapchainDesc desc = {
		.width = clear_dimension(size.width, 640),
		.height = clear_dimension(size.height, 480),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT,
		.request_image_count = (char)FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(state.window) },
	};
	state.swapchain = rhi::swapchain_init(&state.device, desc)!;
	state.stage = ClearStage.SWAPCHAIN;

	state.ring = rhi::command_ring_buffer_init{FRAMES_IN_FLIGHT, 1, true}(
		&state.device, &state.device.graphics_queue
	)!;
	state.stage = ClearStage.COMMAND_RING;
	state.timeline = rhi::timeline_init(&state.device)!;
	state.stage = ClearStage.TIMELINE;
	state.force_rebuild = false;
	state.presented = 0;
}

fn platform::AppResult clear_init(platform::Window window)
{
	state = {};
	state.window = window;
	clear_parse_args(platform::program_args());
	if (state.invalid_args)
	{
		log::error("[00_clear] --frames requires a non-negative integer");
		return platform::AppResult.FAILURE;
	}

	if (catch clear_init_rhi())
	{
		log::error("[00_clear] RHI initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn platform::AppResult clear_event(platform::Event* event)
{
	(void)event;
	return platform::AppResult.CONTINUE;
}

fn void? clear_frame_impl()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	if (size.width == 0 || size.height == 0) return;
	ushort width = clear_dimension(size.width, 1);
	ushort height = clear_dimension(size.height, 1);

	if (state.force_rebuild || width != state.swapchain.width || height != state.swapchain.height)
	{
		rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)!;
		rhi::swapchain_recreate(&state.swapchain, &state.device, width, height)!;
		state.force_rebuild = false;
	}

	// Web builds do not wait on fences for the browser-owned event loop.  Keep
	// one timeline value per ring slot, matching the Odin demo's throttling.
	if (rhi::IS_WEB)
	{
		ulong completed = rhi::timeline_completed(&state.timeline, &state.device)!;
		sz next_slot = (state.ring.pool_index + 1) % (sz)FRAMES_IN_FLIGHT;
		if (state.slot_values[next_slot] > completed) return;
	}

	uint image_index;
	rhi::SwapchainStatus? acquired = rhi::swapchain_acquire_next_image(
		&state.swapchain, &state.device, &image_index
	);
	if (catch err = acquired)
	{
		log::error("[00_clear] acquire failed");
		return err~;
	}
	if (acquired == rhi::SwapchainStatus.OUT_OF_DATE)
	{
		state.force_rebuild = true;
		return;
	}

	state.ring.advance();
	rhi::CommandRingElement element = rhi::command_ring_buffer_get{FRAMES_IN_FLIGHT, 1, true}(
		&state.ring, &state.device, 1
	);
	rhi::command_ring_element_wait(&element, &state.device)!;
	rhi::pool_reset(element.pool, &state.device)!;

	rhi::Cmd* cmd = &element.cmds[0];
	rhi::cmd_begin(cmd, &state.device)!;
	rhi::Image image = rhi::swapchain_image(&state.swapchain, image_index);
	rhi::ImageView view = rhi::swapchain_image_view(&state.swapchain, image_index);

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
			.clear_color = { 0.1, 0.2, 0.4, 1.0 },
		}},
		.render_area = { .width = width, .height = height },
	});

	if (rhi::renderer.backend != rhi::Backend.WGPU)
	{
		rhi::CmdClearRegion[4] regions = {
			{ .color = { 0.0, 0.0, 0.0, 1.0 }, .rect = { .x = 0, .y = 0, .width = width / 2, .height = height / 2 } },
			{ .color = { 1.0, 0.0, 0.0, 1.0 }, .rect = { .x = (int)(width / 2), .y = 0, .width = width - width / 2, .height = height / 2 } },
			{ .color = { 0.0, 1.0, 0.0, 1.0 }, .rect = { .x = 0, .y = (int)(height / 2), .width = width / 2, .height = height - height / 2 } },
			{ .color = { 0.0, 0.0, 1.0, 1.0 }, .rect = { .x = (int)(width / 2), .y = (int)(height / 2), .width = width - width / 2, .height = height - height / 2 } },
		};
		rhi::cmd_clear_attachment_regions(cmd, &state.device, regions[..]);
	}

	rhi::cmd_end_rendering(cmd, &state.device);
	rhi::cmd_image_barrier(cmd, &state.device, {
		.image = &image,
		.before = { .render_target = true },
		.after = { .present = true },
		.aspect = rhi::BarrierAspect.COLOR,
		.mip_count = 1,
		.layer_count = 1,
	});
	rhi::cmd_end(cmd, &state.device)!;

	rhi::Cmd*[1] cmds = { cmd };
	rhi::SwapchainStatus presented = rhi::swapchain_frame_submit(&state.swapchain, &state.device, &state.device.graphics_queue, {
		.image_index = image_index,
		.cmds = cmds[..],
		.timeline = &state.timeline,
		.signal_value = 0,
		.completion = &element,
	})!;
	state.slot_values[state.ring.pool_index] = rhi::timeline_pending(&state.timeline);
	if (acquired == rhi::SwapchainStatus.SUBOPTIMAL || presented == rhi::SwapchainStatus.OUT_OF_DATE || presented == rhi::SwapchainStatus.SUBOPTIMAL)
	{
		state.force_rebuild = true;
	}
	state.presented++;
	return;
}

fn platform::AppResult clear_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch clear_frame_impl())
	{
		log::error("[00_clear] frame submission failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn void clear_quit(platform::AppResult result)
{
	(void)result;
	if (!rhi::IS_WEB && state.stage >= ClearStage.DEVICE)
	{
		if (catch rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)) {}
	}
	if (state.stage >= ClearStage.TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= ClearStage.COMMAND_RING) rhi::command_ring_buffer_deinit{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device);
	if (state.stage >= ClearStage.SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= ClearStage.DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= ClearStage.RENDERER) rhi::renderer_deinit();
	state = {};
}

fn platform::App clear_app()
{
	return {
		.title = "00_clear",
		.width = 640,
		.height = 480,
		.init = &clear_init,
		.frame = &clear_frame,
		.event = &clear_event,
		.quit = &clear_quit,
	};
}

fn void main(String[] args)
{
	platform::run(clear_app(), args);
}

fn void clear_web_start(String[] args) @feat(WASM) @export("_start")
{
	platform::run(clear_app(), args);
}

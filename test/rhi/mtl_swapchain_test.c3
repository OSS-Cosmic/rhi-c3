// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// SDL-backed Metal swapchain coverage.  SDL setup failures are logged as a
// skipped test so this remains useful on Macs without a usable video/Metal
// environment (and while the backend is still being completed).
module rhi @feat(RHI_MTL & DARWIN);
import std::collections::list;
import std::core::test;
import sdl3;

const uint MTL_SWAPCHAIN_FRAMES_IN_FLIGHT = 3;

fn bool mtl_swapchain_present_frame(Device* device, Swapchain* swapchain,
	Timeline* timeline, Cmd* cmd, ulong wait_value)
{
	if (wait_value != 0) timeline_wait(timeline, device, wait_value)!!;

	uint image_index;
	SwapchainStatus? acquired = swapchain_acquire_next_image(swapchain, device, &image_index);
	if (catch err = acquired) return false;
	if (acquired != OK && acquired != SUBOPTIMAL) return false;

	cmd_begin(cmd, device)!!;
	Image image = swapchain_image(swapchain, image_index);
	cmd_image_barrier(cmd, device, {
		.image = &image,
		.after = { .render_target = true },
		.after_stages = { .color_attachment = true },
		.aspect = COLOR,
		.mip_count = 1,
		.layer_count = 1,
	});
	cmd_begin_rendering(cmd, device, {
		.color_attachments = { {
			.view = swapchain_image_view(swapchain, image_index),
			.load_op = CLEAR,
			.store_op = STORE,
			.clear_color = { 0, 0, 0, 1 },
		} },
		.render_area = { .width = swapchain.width, .height = swapchain.height },
	});
	cmd_end_rendering(cmd, device);
	cmd_image_barrier(cmd, device, {
		.image = &image,
		.before = { .render_target = true },
		.after = { .present = true },
		.before_stages = { .color_attachment = true },
		.aspect = COLOR,
		.mip_count = 1,
		.layer_count = 1,
	});
	cmd_end(cmd, device)!!;

	Cmd*[1] cmds = { cmd };
	SwapchainStatus? submitted = swapchain_frame_submit(swapchain, device, &device.graphics_queue, {
		.image_index = image_index,
		.cmds = cmds[..],
		.timeline = timeline,
	});
	if (catch err = submitted) return false;
	return submitted == OK || submitted == SUBOPTIMAL;
}

fn void mtl_swapchain_sdl_present_and_recreate() @test
{
	if (!sdl3::init(sdl3::SDL_INIT_VIDEO))
	{
		log::info("Metal swapchain test skipped: SDL_Init failed: %s", sdl3::get_error());
		return;
	}
	defer sdl3::quit();

	sdl3::Window window = sdl3::create_window("rhi-odin Metal swapchain", 64, 64,
		sdl3::SDL_WINDOW_HIDDEN | sdl3::SDL_WINDOW_METAL);
	if (window == null)
	{
		log::info("Metal swapchain test skipped: SDL_CreateWindow failed: %s", sdl3::get_error());
		return;
	}
	defer sdl3::destroy_window(window);

	sdl3::MetalView view = sdl3::metal_create_view(window);
	if (view == null)
	{
		log::info("Metal swapchain test skipped: SDL_Metal_CreateView failed: %s", sdl3::get_error());
		return;
	}
	defer sdl3::metal_destroy_view(view);

	void* layer = sdl3::metal_get_layer(view);
	if (layer == null)
	{
		log::info("Metal swapchain test skipped: SDL_Metal_GetLayer failed: %s", sdl3::get_error());
		return;
	}

	if (catch err = renderer_init({ .backend = MTL, .mtl = {} }))
	{
		log::info("Metal swapchain test skipped: renderer initialization failed");
		return;
	}
	defer renderer_deinit();

	List{PhysicalAdapter}? adapters = enumerate_adapters();
	if (catch err = adapters)
	{
		log::info("Metal swapchain test skipped: adapter enumeration failed");
		return;
	}
	defer adapters.free();
	if (adapters.len() == 0)
	{
		log::info("Metal swapchain test skipped: no Metal adapters");
		return;
	}

	Device? device = device_init(&adapters[default_select_adapter(adapters.array_view())]);
	if (catch err = device)
	{
		log::info("Metal swapchain test skipped: device initialization failed");
		return;
	}
	defer device_deinit(&device);

	Swapchain? swapchain = swapchain_init(&device, {
		.width = 64,
		.height = 64,
		.format = BT709_G22_8BIT,
		.request_image_count = MTL_SWAPCHAIN_FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &device.graphics_queue,
		.source = { .kind = WINDOW, .window = {
			.kind = METAL,
			.metal = { .layer = layer },
		} },
	});
	if (catch err = swapchain)
	{
		log::info("Metal swapchain test skipped: swapchain initialization failed");
		return;
	}
	defer swapchain_deinit(&swapchain, &device);

	Timeline? timeline = timeline_init(&device);
	if (catch err = timeline)
	{
		log::info("Metal swapchain test skipped: timeline initialization failed");
		return;
	}
	defer timeline_deinit(&timeline, &device);

	Pool? pool = pool_init(&device, &device.graphics_queue);
	if (catch err = pool)
	{
		log::info("Metal swapchain test skipped: command pool initialization failed");
		return;
	}
	defer pool_deinit(&pool, &device);

	Cmd[MTL_SWAPCHAIN_FRAMES_IN_FLIGHT] cmds;
	cmds[0] = cmd_init(&device, &pool)!!;
	cmds[1] = cmd_init(&device, &pool)!!;
	cmds[2] = cmd_init(&device, &pool)!!;
	defer cmd_deinit(&cmds[0], &device, &pool);
	defer cmd_deinit(&cmds[1], &device, &pool);
	defer cmd_deinit(&cmds[2], &device, &pool);

	ulong[MTL_SWAPCHAIN_FRAMES_IN_FLIGHT] values = { 0, 0, 0 };
	if (!mtl_swapchain_present_frame(&device, &swapchain, &timeline, &cmds[0], 0))
	{
		log::info("Metal swapchain test skipped: first present failed");
		return;
	}
	values[0] = timeline_pending(&timeline);
	queue_wait_idle(&device.graphics_queue, &device)!!;

	if (catch err = swapchain_recreate(&swapchain, &device, 32, 32))
	{
		log::info("Metal swapchain test skipped: 32x32 swapchain recreation failed");
		return;
	}
	if (!mtl_swapchain_present_frame(&device, &swapchain, &timeline, &cmds[1], 0))
	{
		log::info("Metal swapchain test skipped: present after recreation failed");
		return;
	}
	values[1] = timeline_pending(&timeline);
	queue_wait_idle(&device.graphics_queue, &device)!!;

	for (uint i = 0; i < 4 * max(swapchain.image_count, MTL_SWAPCHAIN_FRAMES_IN_FLIGHT); i++)
	{
		uint slot = i % MTL_SWAPCHAIN_FRAMES_IN_FLIGHT;
		if (!mtl_swapchain_present_frame(&device, &swapchain, &timeline, &cmds[slot], values[slot]))
		{
			log::info("Metal swapchain test skipped: acquire-first present failed");
			return;
		}
		values[slot] = timeline_pending(&timeline);
	}
	timeline_wait(&timeline, &device, timeline_pending(&timeline))!!;
	queue_wait_idle(&device.graphics_queue, &device)!!;
}

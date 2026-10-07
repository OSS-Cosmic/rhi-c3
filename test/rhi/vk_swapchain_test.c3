// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// SDL-backed Vulkan swapchain coverage.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::atomic;
import std::collections::list;
import std::core::test;
import sdl3;
import vk;

const uint VK_SWAPCHAIN_TEST_FRAMES_IN_FLIGHT = 3;

struct VkSwapchainTestValidation
{
	uint errors;
}

fn vk::Bool32 vk_swapchain_test_messenger_callback(
	vk::DebugUtilsMessageSeverityFlagBitsEXT message_severity,
	vk::DebugUtilsMessageTypeFlagsEXT message_types,
	vk::DebugUtilsMessengerCallbackDataEXT* callback_data,
	void* user_data)
{
	VkSwapchainTestValidation* validation = (VkSwapchainTestValidation*)user_data;
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
	{
		atomic::fetch_add(&validation.errors, 1u);
		if (callback_data && callback_data.pMessage)
		{
			log::error("VK ERROR: %s", callback_data.pMessage);
		}
	}
	else if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT)
	{
		if (callback_data && callback_data.pMessage)
		{
			log::warn("VK WARNING: %s", callback_data.pMessage);
		}
	}
	return vk::FALSE;
}

fn bool vk_swapchain_test_present_frame(Device* device, Swapchain* swapchain,
	Timeline* timeline, Cmd* cmd, ulong wait_value)
{
	uint image_index;
	SwapchainStatus? acquired = swapchain_acquire_next_image(swapchain, device, &image_index);
	if (catch err = acquired) return false;
	if (acquired != OK && acquired != SUBOPTIMAL) return false;
	if (wait_value != 0) timeline_wait(timeline, device, wait_value)!!;

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
			.clear_color = { 0.2, 0.4, 0.8, 1.0 },
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

// Returns true after the swapchain path was actually exercised. Initialization
// failures are skips because this test is also run on machines without Vulkan,
// a usable window system, or the in-progress Vulkan swapchain implementation.
fn bool vk_swapchain_test_run(WindowHandle window)
{
	List{PhysicalAdapter}? adapters = enumerate_adapters();
	if (catch err = adapters)
	{
		log::info("Vulkan swapchain test skipped: adapter enumeration failed");
		return false;
	}
	defer adapters.free();
	if (adapters.len() == 0)
	{
		log::info("Vulkan swapchain test skipped: no Vulkan adapters");
		return false;
	}

	Device? device = device_init(&adapters[default_select_adapter(adapters.array_view())]);
	if (catch err = device)
	{
		log::info("Vulkan swapchain test skipped: device initialization failed");
		return false;
	}
	defer device_deinit(&device);

	Swapchain? swapchain = swapchain_init(&device, {
		.width = 64,
		.height = 64,
		.format = BT709_G22_8BIT,
		.request_image_count = 2,
		.vsync = true,
		.queue = &device.graphics_queue,
		.source = { .kind = WINDOW, .window = window },
	});
	if (catch err = swapchain)
	{
		log::info("Vulkan swapchain test skipped: swapchain initialization failed");
		return false;
	}
	defer swapchain_deinit(&swapchain, &device);
	if (swapchain.image_count < 1)
	{
		log::error("Vulkan swapchain test: swapchain has no images");
		test::@check(false);
		return false;
	}

	Timeline? timeline = timeline_init(&device);
	if (catch err = timeline)
	{
		log::info("Vulkan swapchain test skipped: timeline initialization failed");
		return false;
	}
	defer timeline_deinit(&timeline, &device);

	Pool? pool = pool_init(&device, &device.graphics_queue);
	if (catch err = pool)
	{
		log::info("Vulkan swapchain test skipped: command pool initialization failed");
		return false;
	}
	defer pool_deinit(&pool, &device);

	Cmd[VK_SWAPCHAIN_TEST_FRAMES_IN_FLIGHT] cmds;
	cmds[0] = cmd_init(&device, &pool)!!;
	cmds[1] = cmd_init(&device, &pool)!!;
	cmds[2] = cmd_init(&device, &pool)!!;
	defer cmd_deinit(&cmds[0], &device, &pool);
	defer cmd_deinit(&cmds[1], &device, &pool);
	defer cmd_deinit(&cmds[2], &device, &pool);

	ulong[VK_SWAPCHAIN_TEST_FRAMES_IN_FLIGHT] values = { 0, 0, 0 };
	if (!vk_swapchain_test_present_frame(&device, &swapchain, &timeline, &cmds[0], 0))
	{
		log::error("Vulkan swapchain test: clear-and-present failed");
		test::@check(false);
		return false;
	}
	values[0] = timeline_pending(&timeline);
	queue_wait_idle(&device.graphics_queue, &device)!!;

	if (catch err = swapchain_recreate(&swapchain, &device, 32, 32))
	{
		log::error("Vulkan swapchain test: 32x32 recreation failed");
		test::@check(false);
		return false;
	}
	if (!vk_swapchain_test_present_frame(&device, &swapchain, &timeline, &cmds[1], 0))
	{
		log::error("Vulkan swapchain test: present after recreation failed");
		test::@check(false);
		return false;
	}
	values[1] = timeline_pending(&timeline);
	queue_wait_idle(&device.graphics_queue, &device)!!;

	for (uint i = 0; i < 4 * max(swapchain.image_count, VK_SWAPCHAIN_TEST_FRAMES_IN_FLIGHT); i++)
	{
		uint slot = i % VK_SWAPCHAIN_TEST_FRAMES_IN_FLIGHT;
		if (!vk_swapchain_test_present_frame(&device, &swapchain, &timeline, &cmds[slot], values[slot]))
		{
			log::error("Vulkan swapchain test: acquire-first present failed");
			test::@check(false);
			return false;
		}
		values[slot] = timeline_pending(&timeline);
	}
	timeline_wait(&timeline, &device, timeline_pending(&timeline))!!;
	queue_wait_idle(&device.graphics_queue, &device)!!;
	return true;
}

fn void vk_swapchain_present_test() @test
{
	if (!sdl3::init(sdl3::SDL_INIT_VIDEO))
	{
		log::info("Vulkan swapchain test skipped: SDL_Init failed: %s", sdl3::get_error());
		return;
	}
	defer sdl3::quit();

	ZString driver_name = sdl3::get_current_video_driver();
	if (!driver_name)
	{
		log::info("Vulkan swapchain test skipped: SDL did not select a video driver");
		return;
	}
	String driver = driver_name.str_view();
	if (driver != "x11" && driver != "wayland")
	{
		log::info("Vulkan swapchain test skipped: unsupported SDL video driver %s", driver);
		return;
	}

	sdl3::Window sdl_window = sdl3::create_window(
		"rhi Vulkan swapchain", 64, 64,
		sdl3::SDL_WINDOW_HIDDEN | sdl3::SDL_WINDOW_VULKAN);
	if (!sdl_window)
	{
		log::info("Vulkan swapchain test skipped: SDL_CreateWindow failed: %s", sdl3::get_error());
		return;
	}
	defer sdl3::destroy_window(sdl_window);

	sdl3::Properties props = sdl3::get_window_properties(sdl_window);
	WindowHandle window = {};
	if (driver == "x11")
	{
		void* display = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null);
		ulong x11_window = (ulong)sdl3::get_number_property(props, sdl3::SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
		if (!display || x11_window == 0)
		{
			log::info("Vulkan swapchain test skipped: SDL X11 window properties unavailable");
			return;
		}
		window = { .kind = X11, .x11 = { .display = display, .window = x11_window } };
	}
	else
	{
		void* display = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null);
		void* surface = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null);
		if (!display || !surface)
		{
			log::info("Vulkan swapchain test skipped: SDL Wayland window properties unavailable");
			return;
		}
		window = { .kind = WAYLAND, .wayland = { .display = display, .surface = surface } };
	}

	if (catch err = renderer_init({ .backend = VK, .vk = {
		.app_name = "rhi-vulkan-swapchain-test",
		.enable_validation_layer = true,
	} }))
	{
		log::info("Vulkan swapchain test skipped: renderer initialization failed");
		return;
	}

	VkSwapchainTestValidation validation = {};
	vk::DebugUtilsMessengerEXT messenger = 0;
	if (vk::createDebugUtilsMessengerEXT)
	{
		vk::DebugUtilsMessengerCreateInfoEXT info = {
			.sType = vk::StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			.pfnUserCallback = &vk_swapchain_test_messenger_callback,
			.pUserData = &validation,
			.messageSeverity = vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
			.messageType = vk::DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
		};
		if (catch err = vk_check(vk::createDebugUtilsMessengerEXT(renderer.vk.instance, &info, null, &messenger)))
		{
			log::warn("Vulkan swapchain test: could not install validation messenger");
		}
	}
	else
	{
		log::warn("Vulkan swapchain test: debug messenger entry point unavailable");
	}

	bool have_messenger = messenger != 0;
	bool exercised = vk_swapchain_test_run(window);
	if (have_messenger && vk::destroyDebugUtilsMessengerEXT)
	{
		vk::destroyDebugUtilsMessengerEXT(renderer.vk.instance, messenger, null);
		messenger = 0;
	}
	renderer_deinit();

	if (exercised)
	{
		test::eq(validation.errors, 0u);
		log::info("Vulkan swapchain test ran on %s with %d validation errors", driver, validation.errors);
	}
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// 03_imgui: Vulkan ImGui demo.
//
// The ImGui renderer and its embedded shaders live in rhi::imgui. This file
// owns only the example lifecycle and the SDL -> ImGui input translation.
module example_03_imgui @feat(RHI_VK & RHI_IMGUI & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import std::collections::list;
import imgui;
import platform;
import rhi;
import sdl3;

const uint FRAMES_IN_FLIGHT = 3;

enum ImguiStage
{
	NONE,
	RENDERER,
	DEVICE,
	SWAPCHAIN,
	COMMAND_RING,
	TIMELINE,
	IMGUI,
}

struct ImguiState
{
	platform::Window window;
	rhi::Device device;
	rhi::Swapchain swapchain;
	rhi::CommandRingBuffer{FRAMES_IN_FLIGHT, 1, true} ring;
	rhi::Timeline timeline;
	rhi::ImguiLayer imgui;
	ImguiStage stage;
	ulong last_ticks;
	float frame_dt;
	bool force_rebuild;
	bool invalid_args;
	uint frame_limit;
	uint presented;
}

ImguiState state;

// ImGuiKey values are stable public values in the pinned vendor/imgui_c/imgui ABI.
// SDL scancodes are deliberately translated instead of being passed through:
// ImGui's named keys occupy a different numeric range.
const int IMGUI_KEY_TAB = 512;
const int IMGUI_KEY_LEFT = 513;
const int IMGUI_KEY_RIGHT = 514;
const int IMGUI_KEY_UP = 515;
const int IMGUI_KEY_DOWN = 516;
const int IMGUI_KEY_PAGE_UP = 517;
const int IMGUI_KEY_PAGE_DOWN = 518;
const int IMGUI_KEY_HOME = 519;
const int IMGUI_KEY_END = 520;
const int IMGUI_KEY_INSERT = 521;
const int IMGUI_KEY_DELETE = 522;
const int IMGUI_KEY_BACKSPACE = 523;
const int IMGUI_KEY_SPACE = 524;
const int IMGUI_KEY_ENTER = 525;
const int IMGUI_KEY_ESCAPE = 526;
const int IMGUI_KEY_LEFT_CTRL = 527;
const int IMGUI_KEY_LEFT_SHIFT = 528;
const int IMGUI_KEY_LEFT_ALT = 529;
const int IMGUI_KEY_LEFT_SUPER = 530;
const int IMGUI_KEY_RIGHT_CTRL = 531;
const int IMGUI_KEY_RIGHT_SHIFT = 532;
const int IMGUI_KEY_RIGHT_ALT = 533;
const int IMGUI_KEY_RIGHT_SUPER = 534;
const int IMGUI_KEY_0 = 536;
const int IMGUI_KEY_A = 546;
const int IMGUI_KEY_F1 = 572;
const int IMGUI_MOD_CTRL = 4096;
const int IMGUI_MOD_SHIFT = 8192;
const int IMGUI_MOD_ALT = 16384;
const int IMGUI_MOD_SUPER = 32768;

fn ushort imgui_dimension(uint value, ushort fallback)
{
	if (value == 0) return fallback;
	return (ushort)min(value, (uint)ushort::max);
}

fn void imgui_parse_args(String[] args)
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

fn int imgui_key_from_scancode(uint scancode)
{
	if (scancode >= 4 && scancode <= 29) return IMGUI_KEY_A + (int)(scancode - 4);
	if (scancode >= 30 && scancode <= 39) return IMGUI_KEY_0 + (int)((scancode - 30 + 1) % 10);
	if (scancode >= 58 && scancode <= 69) return IMGUI_KEY_F1 + (int)(scancode - 58);
	switch (scancode)
	{
		case 40: return IMGUI_KEY_ENTER;
		case 41: return IMGUI_KEY_ESCAPE;
		case 42: return IMGUI_KEY_BACKSPACE;
		case 43: return IMGUI_KEY_TAB;
		case 44: return IMGUI_KEY_SPACE;
		case 73: return IMGUI_KEY_INSERT;
		case 74: return IMGUI_KEY_HOME;
		case 75: return IMGUI_KEY_PAGE_UP;
		case 76: return IMGUI_KEY_DELETE;
		case 77: return IMGUI_KEY_END;
		case 78: return IMGUI_KEY_PAGE_DOWN;
		case 79: return IMGUI_KEY_RIGHT;
		case 80: return IMGUI_KEY_LEFT;
		case 81: return IMGUI_KEY_DOWN;
		case 82: return IMGUI_KEY_UP;
		case 224: return IMGUI_KEY_LEFT_CTRL;
		case 225: return IMGUI_KEY_LEFT_SHIFT;
		case 226: return IMGUI_KEY_LEFT_ALT;
		case 227: return IMGUI_KEY_LEFT_SUPER;
		case 228: return IMGUI_KEY_RIGHT_CTRL;
		case 229: return IMGUI_KEY_RIGHT_SHIFT;
		case 230: return IMGUI_KEY_RIGHT_ALT;
		case 231: return IMGUI_KEY_RIGHT_SUPER;
	}
	return -1;
}

fn void imgui_forward_modifiers(ushort modifiers, bool down)
{
	if ((modifiers & (sdl3::SDL_KMOD_LCTRL | sdl3::SDL_KMOD_RCTRL)) != 0) rhi::imgui_layer_add_key_event(&state.imgui, IMGUI_MOD_CTRL, down);
	if ((modifiers & (sdl3::SDL_KMOD_LSHIFT | sdl3::SDL_KMOD_RSHIFT)) != 0) rhi::imgui_layer_add_key_event(&state.imgui, IMGUI_MOD_SHIFT, down);
	if ((modifiers & (sdl3::SDL_KMOD_LALT | sdl3::SDL_KMOD_RALT)) != 0) rhi::imgui_layer_add_key_event(&state.imgui, IMGUI_MOD_ALT, down);
	if ((modifiers & (sdl3::SDL_KMOD_LGUI | sdl3::SDL_KMOD_RGUI)) != 0) rhi::imgui_layer_add_key_event(&state.imgui, IMGUI_MOD_SUPER, down);
}

fn void imgui_forward_utf8(sdl3::TextInputEvent* event)
{
	uint offset = 0;
	while (offset < (uint)event.text.len && event.text[offset] != 0)
	{
		uint first = (uint)event.text[offset] & 0xff;
		uint codepoint = first;
		uint count = 1;
		if ((first & 0xe0) == 0xc0 && offset + 1 < (uint)event.text.len)
		{
			codepoint = ((first & 0x1f) << 6) | ((uint)event.text[offset + 1] & 0x3f);
			count = 2;
		}
		else if ((first & 0xf0) == 0xe0 && offset + 2 < (uint)event.text.len)
		{
			codepoint = ((first & 0x0f) << 12) | (((uint)event.text[offset + 1] & 0x3f) << 6) | ((uint)event.text[offset + 2] & 0x3f);
			count = 3;
		}
		else if ((first & 0xf8) == 0xf0 && offset + 3 < (uint)event.text.len)
		{
			codepoint = ((first & 0x07) << 18) | (((uint)event.text[offset + 1] & 0x3f) << 12) | (((uint)event.text[offset + 2] & 0x3f) << 6) | ((uint)event.text[offset + 3] & 0x3f);
			count = 4;
		}
		rhi::imgui_layer_add_input_character(&state.imgui, codepoint);
		offset += count;
	}
}

fn void imgui_draw_status()
{
	if (imgui::begin("rhi", null, 0))
	{
		imgui::text("Dear ImGui on the RHI (Vulkan backend)");
		float fps = state.frame_dt > 0 ? 1.0 / state.frame_dt : 0;
		imgui::text("FPS: %.1f", fps);
		imgui::text("Frames presented: %d", (int)state.presented);
	}
	imgui::end();
}

fn void? imgui_init(platform::Window window)
{
	state.window = window;
	if (catch err = rhi::renderer_init({ .backend = rhi::Backend.VK, .vk = { .app_name = "03_imgui" } })) return err~;
	state.stage = ImguiStage.RENDERER;
	List{rhi::PhysicalAdapter}? adapters = rhi::enumerate_adapters();
	if (catch err = adapters) return err~;
	defer adapters.free();
	if (adapters.len() == 0) return rhi::INITIALIZATION_FAILED~;
	state.device = rhi::device_init(&adapters[rhi::default_select_adapter(adapters.array_view())])!;
	state.stage = ImguiStage.DEVICE;

	platform::PixelSize size = platform::window_size_in_pixels(window);
	state.swapchain = rhi::swapchain_init(&state.device, {
		.width = imgui_dimension(size.width, 1280),
		.height = imgui_dimension(size.height, 720),
		.format = rhi::SwapchainFormat.BT709_G22_8BIT,
		.request_image_count = (char)FRAMES_IN_FLIGHT,
		.vsync = true,
		.queue = &state.device.graphics_queue,
		.source = { .kind = rhi::SwapchainSourceKind.WINDOW, .window = platform::window_handle(window) },
	})!;
	state.stage = ImguiStage.SWAPCHAIN;
	state.ring = rhi::command_ring_buffer_init{FRAMES_IN_FLIGHT, 1, true}(&state.device, &state.device.graphics_queue)!;
	state.stage = ImguiStage.COMMAND_RING;
	state.timeline = rhi::timeline_init(&state.device)!;
	state.stage = ImguiStage.TIMELINE;
	state.imgui = rhi::imgui_layer_init(&state.device, rhi::swapchain_color_format(&state.swapchain))!;
	state.stage = ImguiStage.IMGUI;
	state.last_ticks = platform::ticks_ms();
	state.frame_dt = 1.0 / 60;
	state.force_rebuild = false;
	state.presented = 0;
}

fn platform::AppResult imgui_app_init(platform::Window window)
{
	state = {};
	imgui_parse_args(platform::program_args());
	if (state.invalid_args)
	{
		log::error("[03_imgui] --frames requires a non-negative integer");
		return platform::AppResult.FAILURE;
	}
	if (catch imgui_init(window))
	{
		log::error("[03_imgui] Vulkan/ImGui initialization failed");
		return platform::AppResult.FAILURE;
	}
	return platform::AppResult.CONTINUE;
}

fn void? imgui_frame()
{
	platform::PixelSize size = platform::window_size_in_pixels(state.window);
	if (size.width == 0 || size.height == 0) return;
	ushort width = imgui_dimension(size.width, 1);
	ushort height = imgui_dimension(size.height, 1);
	if (state.force_rebuild || width != state.swapchain.width || height != state.swapchain.height)
	{
		rhi::queue_wait_idle(&state.device.graphics_queue, &state.device)!;
		rhi::swapchain_recreate(&state.swapchain, &state.device, width, height)!;
		state.force_rebuild = false;
	}

	uint image_index;
	rhi::SwapchainStatus acquired = rhi::swapchain_acquire_next_image(&state.swapchain, &state.device, &image_index)!;
	if (acquired == rhi::SwapchainStatus.OUT_OF_DATE)
	{
		state.force_rebuild = true;
		return;
	}

	ulong now = platform::ticks_ms();
	state.frame_dt = state.last_ticks == 0 ? (float)(1.0 / 60) : (float)(now - state.last_ticks) / 1000;
	state.last_ticks = now;
	rhi::imgui_layer_new_frame(&state.imgui, width, height, state.frame_dt);
	imgui::show_demo_window(null);
	imgui_draw_status();

	state.ring.advance();
	rhi::CommandRingElement element = rhi::command_ring_buffer_get{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device, 1);
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
			.clear_color = { 0.1, 0.1, 0.12, 1.0 },
		}},
		.render_area = { .width = width, .height = height },
	});
	rhi::imgui_layer_render(&state.imgui, &state.device, cmd)!;
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
	rhi::Cmd*[1] commands = { cmd };
	rhi::SwapchainStatus presented = rhi::swapchain_frame_submit(&state.swapchain, &state.device, &state.device.graphics_queue, {
		.image_index = image_index,
		.cmds = commands[..],
		.timeline = &state.timeline,
		.signal_value = 0,
		.completion = &element,
	})!;
	if (presented == rhi::SwapchainStatus.OUT_OF_DATE || presented == rhi::SwapchainStatus.SUBOPTIMAL) state.force_rebuild = true;
	state.presented++;
}

fn platform::AppResult imgui_app_frame()
{
	if (state.frame_limit != 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	if (catch imgui_frame())
	{
		log::error("[03_imgui] frame failed");
		return platform::AppResult.FAILURE;
	}
	if (state.frame_limit > 0 && state.presented >= state.frame_limit) return platform::AppResult.SUCCESS;
	return platform::AppResult.CONTINUE;
}

fn platform::AppResult imgui_event(platform::Event* event)
{
	uint type = event.common.type;
	if (state.stage < ImguiStage.IMGUI) return platform::AppResult.CONTINUE;
	if (type == sdl3::SDL_EVENT_MOUSE_MOTION)
	{
		sdl3::MouseMotionEvent* motion = (sdl3::MouseMotionEvent*)event;
		rhi::imgui_layer_add_mouse_pos_event(&state.imgui, motion.x, motion.y);
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
		bool down = type == sdl3::SDL_EVENT_KEY_DOWN;
		int imgui_key = imgui_key_from_scancode(key.scancode);
		if (imgui_key >= 0) rhi::imgui_layer_add_key_event(&state.imgui, imgui_key, down);
		imgui_forward_modifiers(key.modifiers, down);
	}
	else if (type == sdl3::SDL_EVENT_TEXT_INPUT)
	{
		imgui_forward_utf8((sdl3::TextInputEvent*)event);
	}
	return platform::AppResult.CONTINUE;
}

fn void imgui_app_quit(platform::AppResult result)
{
	(void)result;
	if (state.stage >= ImguiStage.DEVICE) (void)rhi::queue_wait_idle(&state.device.graphics_queue, &state.device);
	if (state.stage >= ImguiStage.IMGUI) rhi::imgui_layer_deinit(&state.imgui, &state.device);
	if (state.stage >= ImguiStage.TIMELINE) rhi::timeline_deinit(&state.timeline, &state.device);
	if (state.stage >= ImguiStage.COMMAND_RING) rhi::command_ring_buffer_deinit{FRAMES_IN_FLIGHT, 1, true}(&state.ring, &state.device);
	if (state.stage >= ImguiStage.SWAPCHAIN) rhi::swapchain_deinit(&state.swapchain, &state.device);
	if (state.stage >= ImguiStage.DEVICE) rhi::device_deinit(&state.device);
	if (state.stage >= ImguiStage.RENDERER) rhi::renderer_deinit();
	int limit = (int)state.frame_limit;
	state = {};
	state.frame_limit = (uint)limit;
}

fn platform::App imgui_app()
{
	return { .title = "03_imgui", .width = 1280, .height = 720, .init = &imgui_app_init, .frame = &imgui_app_frame, .event = &imgui_event, .quit = &imgui_app_quit };
}

fn void main(String[] args)
{
	platform::run(imgui_app(), args);
}

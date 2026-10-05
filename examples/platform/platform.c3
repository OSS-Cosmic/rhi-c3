// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Small shared application harness for examples.  Native examples use SDL's
// non-blocking event queue; web examples are driven by rhi_web_frame from the
// browser's requestAnimationFrame loop.
module platform;
import rhi;

enum AppResult : char
{
	CONTINUE,
	SUCCESS,
	FAILURE,
}

struct PixelSize
{
	uint width;
	uint height;
}

alias AppInit = fn AppResult(Window window);
alias AppFrame = fn AppResult();
alias AppEvent = fn AppResult(Event* event);
alias AppQuit = fn void(AppResult result);

// The callbacks are deliberately plain function pointers so an example can
// stop after a fixed number of frames without knowing whether it is running
// against SDL or the browser host.
struct App
{
	String title;
	uint width;
	uint height;
	AppInit init;
	AppFrame frame;
	AppEvent event;
	AppQuit quit;
}

module platform @feat(!WASM & (LINUX | WIN32 | DARWIN));
import rhi;
import sdl3;

struct Window
{
	sdl3::Window handle;
	sdl3::MetalView metal_view;
}

alias Event = sdl3::Event;

String[] active_args;

fn String[] program_args() => active_args;

fn PixelSize window_size_in_pixels(Window window)
{
	int width;
	int height;
	if (!window.handle || !sdl3::get_window_size_in_pixels(window.handle, &width, &height)) return {};
	return { .width = (uint)width, .height = (uint)height };
}

fn ulong perf_counter() => sdl3::get_performance_counter();
fn ulong perf_frequency() => sdl3::get_performance_frequency();
fn ulong ticks_ms() => sdl3::get_ticks();

fn void apply_video_driver_arg(String[] args)
{
	for (sz i = 0; i < args.len; i++)
	{
		String value = {};
		if (args[i] == "--video-driver" && i + 1 < args.len)
		{
			value = args[i + 1];
			i++;
		}
		else if (args[i].starts_with("--video-driver="))
		{
			value = args[i][15..];
		}
		if (value.len > 0)
		{
			sdl3::set_hint_with_priority(sdl3::SDL_HINT_VIDEO_DRIVER,
				value.zstr_tcopy(), sdl3::SDL_HINT_OVERRIDE);
			return;
		}
	}
}

fn rhi::WindowHandle window_handle(Window window)
{
	rhi::WindowHandle result = {};
	if (!window.handle) return result;

	$if env::DARWIN:
		if (!window.metal_view) return result;
		result.kind = rhi::WindowHandleKind.METAL;
		result.metal = { .layer = sdl3::metal_get_layer(window.metal_view) };
		return result;
	$endif

	sdl3::Properties props = sdl3::get_window_properties(window.handle);
	$if env::WIN32:
		result.kind = rhi::WindowHandleKind.WIN32;
		result.win32 = {
			.hinstance = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER, null),
			.hwnd = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WIN32_HWND_POINTER, null),
		};
		return result;
	$endif

	$if env::LINUX:
		ZString driver = sdl3::get_current_video_driver();
		if (driver == "x11")
		{
			result.kind = rhi::WindowHandleKind.X11;
			result.x11 = {
				.display = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_X11_DISPLAY_POINTER, null),
				.window = (ulong)sdl3::get_number_property(props, sdl3::SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0),
			};
		}
		else if (driver == "wayland")
		{
			result.kind = rhi::WindowHandleKind.WAYLAND;
			result.wayland = {
				.display = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, null),
				.surface = sdl3::get_pointer_property(props, sdl3::SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, null),
			};
		}
	$endif
	return result;
}

fn void? renderer_init()
{
	if (rhi::platform_has_api(rhi::Backend.MTL))
	{
		return rhi::renderer_init({ .backend = rhi::Backend.MTL, .mtl = {} });
	}
	if (rhi::platform_has_api(rhi::Backend.VK))
	{
		return rhi::renderer_init({
			.backend = rhi::Backend.VK,
			.vk = { .app_name = "c3-example", .enable_validation_layer = true },
		});
	}
	return rhi::UNSUPPORTED_BACKEND~;
}

fn AppResult run(App app, String[] args)
{
	active_args = args.len > 1 ? args[1..] : {};
	apply_video_driver_arg(active_args);
	if (!sdl3::init(sdl3::SDL_INIT_VIDEO))
	{
		active_args = {};
		return FAILURE;
	}
	defer sdl3::quit();

	sdl3::WindowFlags flags = sdl3::SDL_WINDOW_RESIZABLE;
	$if env::DARWIN:
		flags |= sdl3::SDL_WINDOW_METAL;
	$else
		flags |= sdl3::SDL_WINDOW_VULKAN;
	$endif

	// SDL_PollEvent is intentionally used instead of SDL_WaitEvent or a
	// blocking pump.  This keeps the frame callback live during interactive
	// resize, including Wayland's configure loop.
	sdl3::Window native_window = sdl3::create_window(app.title.zstr_tcopy(), (int)app.width, (int)app.height, flags);
	if (!native_window)
	{
		active_args = {};
		return FAILURE;
	}
	defer sdl3::destroy_window(native_window);

	Window window = { .handle = native_window };
	$if env::DARWIN:
		window.metal_view = sdl3::metal_create_view(native_window);
		if (!window.metal_view)
		{
			active_args = {};
			return FAILURE;
		}
		defer sdl3::metal_destroy_view(window.metal_view);
	$endif

	AppResult result = CONTINUE;
	if (app.init) result = app.init(window);
	while (result == CONTINUE)
	{
		sdl3::Event event = {};
		while (sdl3::poll_event(&event))
		{
			uint type = event.common.type;
			if (type == sdl3::SDL_EVENT_QUIT || type == sdl3::SDL_EVENT_WINDOW_CLOSE_REQUESTED)
			{
				result = SUCCESS;
				break;
			}

			// Resize and pixel-size events are passed through unchanged.  The
			// callback can query window_size_in_pixels(window) for the current
			// drawable size after either event.
			if (app.event)
			{
				AppResult event_result = app.event(&event);
				if (event_result != CONTINUE) result = event_result;
			}
			if (result != CONTINUE) break;
		}
		if (result != CONTINUE) break;
		if (!app.frame)
		{
			result = FAILURE;
			break;
		}
		result = app.frame();
	}

	if (app.quit) app.quit(result);
	active_args = {};
	return result;
}

module platform @feat(WASM);
import rhi;
import std::core::mem;

struct Window
{
	String selector;
}

// Browser input is queued by the host between animation frames. Keeping the
// queue in the platform layer means example callbacks are never re-entrant
// with the frame callback and native/web event signatures stay identical.
struct Event
{
	uint type;
	float x;
	float y;
	uint button;
}

struct WebState
{
	App app;
	Window window;
	PixelSize size;
	double time_ms;
	bool registered;
	bool live;
	Event[64] events;
	uint event_count;
}

WebState web_state;
String[] web_args;
char[4096] web_selector_storage;

fn String[] program_args() => web_args;
fn ulong perf_counter() => (ulong)web_state.time_ms;
fn ulong perf_frequency() => 1000;
fn ulong ticks_ms() => (ulong)web_state.time_ms;
fn PixelSize window_size_in_pixels(Window window) => web_state.size;

fn rhi::WindowHandle window_handle(Window window)
{
	return { .kind = rhi::WindowHandleKind.CANVAS, .canvas = { .selector = window.selector } };
}

fn void? renderer_init()
{
	// The JS boot layer probes WebGPU first and leaves the WebGPU handles null
	// when it falls back to WebGL2. Let the backend report that unavailable
	// adapter, then retry with the context that the host actually created.
	if (rhi::platform_has_api(rhi::Backend.WGPU))
	{
		if (catch err = rhi::renderer_init({ .backend = rhi::Backend.WGPU, .wgpu = {} }))
		{
			if (rhi::platform_has_api(rhi::Backend.WEBGL))
			{
				return rhi::renderer_init({ .backend = rhi::Backend.WEBGL, .webgl = {} });
			}
			return err~;
		}
		return;
	}
	if (rhi::platform_has_api(rhi::Backend.WEBGL))
	{
		return rhi::renderer_init({ .backend = rhi::Backend.WEBGL, .webgl = {} });
	}
	return rhi::UNSUPPORTED_BACKEND~;
}

fn AppResult run(App app, String[] args)
{
	// The browser has no process arguments.  The glue calls rhi_web_init after
	// _start returns, so run only registers the callbacks here.
	web_args = {};
	web_state = {
		.app = app,
		.size = {},
		.registered = true,
		.live = false,
		.event_count = 0,
	};
	return CONTINUE;
}

// Minimal browser glue.  The host schedules rhi_web_frame from
// requestAnimationFrame and owns the selector memory passed to init.
char[4096] web_alloc_buffer;

fn int rhi_glue_abi_version() @export("rhi_glue_abi_version") => rhi::GLUE_ABI_VERSION;

fn char* rhi_web_alloc(uint size) @export("rhi_web_alloc")
{
	return size <= web_alloc_buffer.len ? &web_alloc_buffer[0] : null;
}

fn int rhi_web_init(char* selector, uint selector_len) @export("rhi_web_init")
{
	if (!web_state.registered || web_state.live || selector == null || selector_len > web_selector_storage.len) return 1;
	mem::copy(&web_selector_storage[0], selector, (sz)selector_len);
	web_state.window.selector = (String)web_selector_storage[:selector_len];
	if (web_state.app.init)
	{
		AppResult result = web_state.app.init(web_state.window);
		if (result != CONTINUE)
		{
			if (web_state.app.quit) web_state.app.quit(result);
			return 1;
		}
	}
	web_state.live = true;
	return 0;
}

// Called by glue.js from pointer listeners. Events are drained at the start
// of the next frame, so a browser event cannot interrupt command recording.
fn void rhi_web_pointer_event(uint type, float x, float y, uint button) @export("rhi_web_pointer_event")
{
	if (!web_state.live) return;
	Event event = { .type = type, .x = x, .y = y, .button = button };
	if (type == 0 && web_state.event_count > 0
		&& web_state.events[web_state.event_count - 1].type == 0)
	{
		web_state.events[web_state.event_count - 1] = event;
		return;
	}
	if (web_state.event_count == web_state.events.len)
	{
		mem::copy(&web_state.events[0], &web_state.events[1], (sz)(web_state.events.len - 1) * Event::size);
		web_state.event_count--;
	}
	web_state.events[web_state.event_count++] = event;
}

fn int rhi_web_frame(uint width, uint height, double time_ms) @export("rhi_web_frame")
{
	if (!web_state.live) return -1;
	web_state.size = { .width = width, .height = height };
	web_state.time_ms = time_ms;
	uint pending = web_state.event_count;
	web_state.event_count = 0;
	for (uint i = 0; i < pending; i++)
	{
		if (web_state.app.event)
		{
			AppResult event_result = web_state.app.event(&web_state.events[i]);
			if (event_result != CONTINUE)
			{
				web_state.live = false;
				if (web_state.app.quit) web_state.app.quit(event_result);
				return event_result == SUCCESS ? 1 : -1;
			}
		}
	}
	if (!web_state.app.frame)
	{
		web_state.live = false;
		return -1;
	}
	AppResult result = web_state.app.frame();
	if (result == CONTINUE) return 0;
	web_state.live = false;
	if (web_state.app.quit) web_state.app.quit(result);
	return result == SUCCESS ? 1 : -1;
}

fn void rhi_web_deinit() @export("rhi_web_deinit")
{
	if (web_state.live)
	{
		web_state.live = false;
		if (web_state.app.quit) web_state.app.quit(SUCCESS);
	}
	web_state.event_count = 0;
	web_args = {};
}

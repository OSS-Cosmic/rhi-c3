// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// This binding is intentionally minimal. The examples and platform support
// will grow it as they need more of SDL3.
// Public names intentionally stay SDL-shaped (`sdl3::init`,
// `sdl3::create_window`, and so on) as that surface grows.
module sdl3 @feat(DARWIN | LINUX | WIN32) @link(env::DARWIN | env::LINUX | env::WIN32, "SDL3");

typedef Window @constinit = inline void*;
typedef Properties @constinit = uint;
typedef InitFlags @constinit = uint;
typedef WindowFlags @constinit = ulong;
typedef MetalView @constinit = inline void*;
typedef HintPriority @constinit = int;

// SDL_Event is a 128-byte tagged union. Keeping the padding member preserves
// the ABI when SDL writes the complete union into the caller's storage; the
// input payload views below are used by the desktop examples.
struct CommonEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
}

struct WindowEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	int data1;
	int data2;
}

// Input payloads used by the desktop examples. These layouts mirror SDL3's
// public SDL_Event members and are intentionally limited to the events the
// examples consume; the rest of SDL's event surface remains opaque here.
struct MouseMotionEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	uint mouse_id;
	float x;
	float y;
	float xrel;
	float yrel;
}

struct MouseButtonEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	uint mouse_id;
	char button;
	bool down;
	char clicks;
	char padding;
	float x;
	float y;
}

struct MouseWheelEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	uint mouse_id;
	float x;
	float y;
	uint direction;
	float mouse_x;
	float mouse_y;
}

struct KeyboardEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	uint keyboard_id;
	uint scancode;
	uint key;
	ushort modifiers;
	bool down;
	bool repeat;
}

struct TextInputEvent
{
	uint type;
	uint reserved;
	ulong timestamp;
	uint window_id;
	char[32] text;
}

union Event
{
	CommonEvent common;
	WindowEvent window;
	char[128] padding;
}

const InitFlags SDL_INIT_VIDEO = 0x00000020;
const WindowFlags SDL_WINDOW_HIDDEN = 0x0000000000000008;
const WindowFlags SDL_WINDOW_RESIZABLE = 0x0000000000000020;
const WindowFlags SDL_WINDOW_VULKAN = 0x0000000010000000;
const WindowFlags SDL_WINDOW_METAL = 0x0000000020000000;

const uint SDL_EVENT_QUIT = 0x00000100;
const uint SDL_EVENT_WINDOW_RESIZED = 0x00000206;
const uint SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED = 0x00000207;
const uint SDL_EVENT_WINDOW_CLOSE_REQUESTED = 0x0000020D;
const uint SDL_EVENT_KEY_DOWN = 0x00000300;
const uint SDL_EVENT_KEY_UP = 0x00000301;
const uint SDL_EVENT_TEXT_INPUT = 0x00000303;
const uint SDL_EVENT_MOUSE_MOTION = 0x00000400;
const uint SDL_EVENT_MOUSE_BUTTON_DOWN = 0x00000401;
const uint SDL_EVENT_MOUSE_BUTTON_UP = 0x00000402;
const uint SDL_EVENT_MOUSE_WHEEL = 0x00000403;

const char SDL_BUTTON_LEFT = 1;
const char SDL_BUTTON_MIDDLE = 2;
const char SDL_BUTTON_RIGHT = 3;

const ushort SDL_KMOD_LSHIFT = 0x0001;
const ushort SDL_KMOD_RSHIFT = 0x0002;
const ushort SDL_KMOD_LCTRL = 0x0040;
const ushort SDL_KMOD_RCTRL = 0x0080;
const ushort SDL_KMOD_LALT = 0x0100;
const ushort SDL_KMOD_RALT = 0x0200;
const ushort SDL_KMOD_LGUI = 0x0400;
const ushort SDL_KMOD_RGUI = 0x0800;

const uint SDL_SCANCODE_A = 4;
const uint SDL_SCANCODE_D = 7;
const uint SDL_SCANCODE_E = 8;
const uint SDL_SCANCODE_Q = 20;
const uint SDL_SCANCODE_S = 22;
const uint SDL_SCANCODE_W = 26;
const uint SDL_SCANCODE_ESCAPE = 41;

const HintPriority SDL_HINT_OVERRIDE = 2;
const ZString SDL_HINT_VIDEO_DRIVER = "SDL_VIDEO_DRIVER";

extern fn bool init(InitFlags flags) @cname("SDL_Init");
extern fn void quit() @cname("SDL_Quit");
extern fn Window create_window(ZString title, int width, int height, WindowFlags flags) @cname("SDL_CreateWindow");
extern fn void destroy_window(Window window) @cname("SDL_DestroyWindow");
extern fn bool poll_event(Event* event) @cname("SDL_PollEvent");
extern fn bool set_window_relative_mouse_mode(Window window, bool enabled) @cname("SDL_SetWindowRelativeMouseMode");
extern fn bool get_window_size_in_pixels(Window window, int* width, int* height) @cname("SDL_GetWindowSizeInPixels");
extern fn ulong get_performance_counter() @cname("SDL_GetPerformanceCounter");
extern fn ulong get_performance_frequency() @cname("SDL_GetPerformanceFrequency");
extern fn ulong get_ticks() @cname("SDL_GetTicks");
extern fn bool set_hint_with_priority(ZString name, ZString value, HintPriority priority) @cname("SDL_SetHintWithPriority");
extern fn ZString get_error() @cname("SDL_GetError");
extern fn ZString get_current_video_driver() @cname("SDL_GetCurrentVideoDriver");
extern fn Properties get_window_properties(Window window) @cname("SDL_GetWindowProperties");
extern fn void* get_pointer_property(Properties props, ZString name, void* default_value) @cname("SDL_GetPointerProperty");
extern fn long get_number_property(Properties props, ZString name, long default_value) @cname("SDL_GetNumberProperty");

const ZString SDL_PROP_WINDOW_X11_DISPLAY_POINTER = "SDL.window.x11.display";
const ZString SDL_PROP_WINDOW_X11_WINDOW_NUMBER = "SDL.window.x11.window";
const ZString SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER = "SDL.window.wayland.display";
const ZString SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER = "SDL.window.wayland.surface";
const ZString SDL_PROP_WINDOW_WIN32_INSTANCE_POINTER = "SDL.window.win32.instance";
const ZString SDL_PROP_WINDOW_WIN32_HWND_POINTER = "SDL.window.win32.hwnd";

extern fn MetalView metal_create_view(Window window) @cname("SDL_Metal_CreateView");
extern fn void* metal_get_layer(MetalView view) @cname("SDL_Metal_GetLayer");
extern fn void metal_destroy_view(MetalView view) @cname("SDL_Metal_DestroyView");

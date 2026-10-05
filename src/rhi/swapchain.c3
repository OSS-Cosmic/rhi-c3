// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral swapchain. Port of rhi-zig's `swapchain.zig`: the Vulkan
// swapchain, the WebGPU canvas context and the WebGL2 offscreen target blitted
// onto the canvas. DX12 remains unported; its backend stubs report the
// unsupported status for now.
//
// The web has no image ring and no explicit present: there is one image
// (index 0), and the browser composites the canvas when the frame callback
// returns. `swapchain_image` / `swapchain_image_view` hand out borrowed
// wrappers; callers must never deinit them.
//
// The `SwapchainVk` / `SwapchainWgpu` / `SwapchainWebgl` stand-ins for
// backends that are not compiled in live in backend_stubs.c3.
module rhi;

enum SwapchainFormat : char
{
	BT709_G10_16BIT,
	BT709_G22_8BIT,
	BT709_G22_10BIT,
	BT2020_G2084_10BIT,
}

// A CSS selector naming the `<canvas>` to render into, e.g. `"#canvas"`; an
// empty selector means `"#canvas"`. The string only has to outlive
// `swapchain_init`.
struct WindowCanvas
{
	String selector;
}

// An Xlib window: `display` is the `Display*`, `window` the X11 `Window`.
struct WindowX11
{
	void* display;
	ulong window;
}

// A Wayland `wl_display*` and `wl_surface*`.
struct WindowWayland
{
	void* display;
	void* surface;
}

// A Win32 window. A nil `hinstance` means the current module's.
struct WindowWin32
{
	void* hinstance;
	void* hwnd;
}

// A CAMetalLayer (or another layer accepted by the Metal backend).
struct WindowMetal
{
	void* layer;
}

// Tag of `WindowHandle`. `NONE` is Odin's nil union.
enum WindowHandleKind : char
{
	NONE,
	CANVAS,
	X11,
	WAYLAND,
	WIN32,
	METAL,
}

// Where a fresh surface comes from. Every variant exists on every target, but
// only the platform's own are accepted: X11/Wayland on Linux and Win32 on
// Windows (Vulkan), a Metal layer on macOS (Metal), and the canvas on the web.
// Any foreign variant fails init with `INITIALIZATION_FAILED`.
//
// Odin's tagged `union { Window_Canvas, Window_X11, Window_Wayland,
// Window_Win32, Window_Metal }`: `kind` says which member of the anonymous
// union is live.
struct WindowHandle
{
	WindowHandleKind kind;
	union
	{
		WindowCanvas canvas;
		WindowX11 x11;
		WindowWayland wayland;
		WindowWin32 win32;
		WindowMetal metal;
	}
}

// Tag of `SwapchainSource`. `NONE` is Odin's nil union.
enum SwapchainSourceKind : char
{
	NONE,
	WINDOW,
	SWAPCHAIN,
}

// Where the swapchain's surface comes from:
//  - Window_Handle : first create — init makes a fresh surface the new
//                    swapchain owns.
//  - ^Swapchain    : recreate from an old swapchain — its surface is carried
//                    over (ownership moves to the new swapchain), so the old
//                    one's deinit leaves it alone.
//
// Odin's tagged `union { Window_Handle, ^Swapchain }`: `kind` says which
// member of the anonymous union is live (`WINDOW` -> `window`, `SWAPCHAIN` ->
// `swapchain`).
struct SwapchainSource
{
	SwapchainSourceKind kind;
	union
	{
		WindowHandle window;
		Swapchain* swapchain;
	}
}

struct SwapchainDesc
{
	ushort width, height;
	// Colour space / bit depth request. The web ignores it: WebGPU takes the
	// browser's preferred canvas format and WebGL2 always renders RGBA8.
	SwapchainFormat format;
	// Clamped to the surface's limits. Ignored on the web, which always has
	// exactly one image.
	char request_image_count;
	// true: FIFO. false: MAILBOX, then IMMEDIATE, falling back to FIFO.
	// Ignored on the web: the browser paces frames to the display.
	bool vsync;
	// Queue used to present; stored on the swapchain as `present_queue`.
	Queue* queue;
	SwapchainSource source;
}

// Result of acquire/submit. `OUT_OF_DATE` means the swapchain must be
// recreated before the next acquire; `SUBOPTIMAL` still presented this frame
// but should be recreated soon.
enum SwapchainStatus : char
{
	OK,
	OUT_OF_DATE,
	SUBOPTIMAL,
}

struct Swapchain
{
	Allocator allocator;
	Queue* present_queue;
	// Number of images the caller may index. Always 1 on the web.
	uint image_count;
	ushort width, height;
	union backend
	{
		SwapchainVk vk;
		SwapchainMtl mtl;
		SwapchainWgpu wgpu;
		SwapchainWebgl webgl;
	}
}

// `cmds` must already be ended (`cmd_end`), as for `queue_submit`.
//
// `timeline`, when set, is signalled once this frame's work retires. A
// `signal_value` of 0 reserves the next value with `timeline_next`, matching
// rhi-zig's `frame_submit`; a non-zero value is used as is, for callers that
// reserved it themselves.
//
// `completion`, when set, is the ring element whose fence this submit resets
// and signals (see `QueueSubmitDesc.completion`), so a later
// `command_ring_element_wait` covers this frame. The web ignores it.
struct SwapchainFrameSubmit
{
	uint image_index;
	Cmd*[] cmds;
	Timeline* timeline;
	ulong signal_value;
	CommandRingElement* completion;
}

fn Swapchain? swapchain_init(Device* device, SwapchainDesc desc, Allocator allocator = mem)
{
	swapchain_validate_desc(desc)!;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_init_vk(device, desc, allocator);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_init_mtl(device, desc, allocator);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_init_wgpu(device, desc, allocator);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_init_webgl(device, desc, allocator);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void swapchain_deinit(Swapchain* s, Device* device)
{
	if (s == null) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				swapchain_deinit_vk(s, device);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				swapchain_deinit_mtl(s, device);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				swapchain_deinit_wgpu(s, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				swapchain_deinit_webgl(s, device);
			$endif
	}
	s.image_count = 0;
}

// Resize in place. On the web this never needs a new swapchain: WebGPU
// reconfigures the same canvas context and WebGL2 rebuilds its offscreen
// target. Vulkan builds a new swapchain on the same surface and destroys the
// old one, so the caller must first make sure no queued work still uses the
// old images or semaphores (e.g. `queue_wait_idle`). On failure `s` is left
// as it was, though Vulkan may have retired its swapchain: acquire then
// reports `OUT_OF_DATE` and the caller retries the recreate.
fn void? swapchain_recreate(Swapchain* s, Device* device, ushort width, ushort height)
{
	if (width == 0 || height == 0) return INITIALIZATION_FAILED~;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_recreate_vk(s, device, width, height);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_recreate_mtl(s, device, width, height);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_recreate_wgpu(s, device, width, height);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_recreate_webgl(s, device, width, height);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

// Acquire the next image. On `OK`/`SUBOPTIMAL` the image index is written
// to `out_index`; on `OUT_OF_DATE` nothing is written and the caller must
// recreate.
//
// Odin returns `.Out_Of_Date` alongside `.Unsupported_Backend`; a C3 optional
// carries only the fault.
fn SwapchainStatus? swapchain_acquire_next_image(Swapchain* s, Device* device, uint* out_index)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_acquire_next_image_vk(s, device, out_index);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_acquire_next_image_mtl(s, device, out_index);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_acquire_next_image_wgpu(s, device, out_index);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_acquire_next_image_webgl(s, device, out_index);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

// Borrowed: the swapchain owns what this wraps; never `image_deinit` it.
// On WebGPU it is only valid between acquire and submit of one frame.
fn Image swapchain_image(Swapchain* s, uint index)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_image_vk(s, index);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_image_mtl(s, index);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_image_wgpu(s, index);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_image_webgl(s, index);
			$endif
	}
	return {};
}

// Borrowed: the swapchain owns what this wraps; never `image_view_deinit`
// it. On WebGPU it is only valid between acquire and submit of one frame.
fn ImageView swapchain_image_view(Swapchain* s, uint index)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_image_view_vk(s, index);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_image_view_mtl(s, index);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_image_view_wgpu(s, index);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_image_view_webgl(s, index);
			$endif
	}
	return {};
}

// The format of the images this swapchain hands out: what a pipeline
// rendering to the swapchain declares as its colour target.
fn Format swapchain_color_format(Swapchain* s)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return from_vk_format(s.backend.vk.format);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return from_mtl_pixel_format(s.backend.mtl.pixel_format);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return s.backend.wgpu.color_format;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return s.backend.webgl.format;
			$endif
	}
	return Format.UNKNOWN;
}

// Submit the frame's command buffers and hand the image to the display.
//
// Odin returns `.Out_Of_Date` alongside `.Unsupported_Backend`; a C3 optional
// carries only the fault.
fn SwapchainStatus? swapchain_frame_submit(Swapchain* s, Device* device, Queue* queue, SwapchainFrameSubmit submit)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return swapchain_frame_submit_vk(s, device, queue, submit);
			$endif
		case DX12:
			break;
		case MTL:
			$if HAS_MTL:
				return swapchain_frame_submit_mtl(s, device, queue, submit);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return swapchain_frame_submit_wgpu(s, device, queue, submit);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return swapchain_frame_submit_webgl(s, device, queue, submit);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

// Backend-neutral helpers shared by the web backends. Ungated so native
// tests cover them.

fn void? swapchain_validate_desc(SwapchainDesc desc)
{
	if (desc.width == 0 || desc.height == 0 || desc.queue == null || desc.source.kind == NONE)
	{
		return INITIALIZATION_FAILED~;
	}
	if (desc.source.kind == SWAPCHAIN && desc.source.swapchain == null)
	{
		return INITIALIZATION_FAILED~;
	}
}

fn String swapchain_canvas_selector(WindowCanvas c)
{
	return c.selector.len > 0 ? c.selector : "#canvas";
}

// The value `swapchain_frame_submit` signals `timeline` with; see
// `SwapchainFrameSubmit`. 0 when there is no timeline.
fn ulong swapchain_frame_signal_value(SwapchainFrameSubmit submit)
{
	if (submit.timeline == null) return 0;
	if (submit.signal_value != 0) return submit.signal_value;
	return timeline_next(submit.timeline);
}

// Moved here from Odin's webgpu.odin (`Wgpu_Texture_Format`) so the ungated
// `swapchain_wgpu_surface_format` compiles without the WebGPU backend.
// WebGPU's enum values are indices into the string tables consumed by the JS
// bridge. Keep these explicit: their numeric values (the ordinals, in this
// order) are part of the ABI.
enum WgpuTextureFormat : uint
{
	R8_UNORM, R8_SNORM, R8_UINT, R8_SINT,
	R16_UINT, R16_SINT, R16_FLOAT, RG8_UNORM, RG8_SNORM, RG8_UINT, RG8_SINT,
	R32_UINT, R32_SINT, R32_FLOAT, RG16_UINT, RG16_SINT, RG16_FLOAT,
	RGBA8_UNORM, RGBA8_UNORM_SRGB, RGBA8_SNORM, RGBA8_UINT, RGBA8_SINT,
	BGRA8_UNORM, BGRA8_UNORM_SRGB, RGB9_E5_UFLOAT, RGB10_A2_UINT,
	RGB10_A2_UNORM, RG11B10_UFLOAT, RG32_UINT, RG32_SINT, RG32_FLOAT,
	RGBA16_UINT, RGBA16_SINT, RGBA16_FLOAT, RGBA32_UINT, RGBA32_SINT,
	RGBA32_FLOAT, DEPTH16_UNORM, DEPTH24_PLUS, DEPTH24_PLUS_STENCIL8,
	DEPTH32_FLOAT, DEPTH32_FLOAT_STENCIL8, BC1_RGBA_UNORM, BC1_RGBA_UNORM_SRGB,
	BC2_RGBA_UNORM, BC2_RGBA_UNORM_SRGB, BC3_RGBA_UNORM, BC3_RGBA_UNORM_SRGB,
	BC4_R_UNORM, BC4_R_SNORM, BC5_RG_UNORM, BC5_RG_SNORM, BC6H_RGB_UFLOAT,
	BC6H_RGB_FLOAT, BC7_RGBA_UNORM, BC7_RGBA_UNORM_SRGB, ETC2_RGB8_UNORM,
	ETC2_RGB8_UNORM_SRGB, ETC2_RGB8A1_UNORM, ETC2_RGB8A1_UNORM_SRGB,
	ETC2_RGBA8_UNORM, ETC2_RGBA8_UNORM_SRGB, EAC_R11_UNORM, EAC_R11_SNORM,
	EAC_RG11_UNORM, EAC_RG11_SNORM,
}

// `WgpuFormatPair`, `WGPU_FORMATS`, `wgpu_format` and `wgpu_format_rhi` also
// come from Odin's webgpu.odin: the front needs them
// (`swapchain_wgpu_surface_format`) and they have no backend dependency.
struct WgpuFormatPair
{
	Format rhi;
	WgpuTextureFormat gpu;
}

const WgpuFormatPair[*] WGPU_FORMATS = {
	{ R8_UNORM, R8_UNORM }, { R8_SNORM, R8_SNORM }, { R8_UINT, R8_UINT }, { R8_SINT, R8_SINT },
	{ RG8_UNORM, RG8_UNORM }, { RG8_SNORM, RG8_SNORM }, { RG8_UINT, RG8_UINT }, { RG8_SINT, RG8_SINT },
	{ BGRA8_UNORM, BGRA8_UNORM }, { BGRA8_SRGB, BGRA8_UNORM_SRGB }, { RGBA8_UNORM, RGBA8_UNORM },
	{ RGBA8_SNORM, RGBA8_SNORM }, { RGBA8_UINT, RGBA8_UINT }, { RGBA8_SINT, RGBA8_SINT }, { RGBA8_SRGB, RGBA8_UNORM_SRGB },
	{ R16_UINT, R16_UINT }, { R16_SINT, R16_SINT }, { R16_SFLOAT, R16_FLOAT }, { RG16_UINT, RG16_UINT }, { RG16_SINT, RG16_SINT }, { RG16_SFLOAT, RG16_FLOAT },
	{ RGBA16_UINT, RGBA16_UINT }, { RGBA16_SINT, RGBA16_SINT }, { RGBA16_SFLOAT, RGBA16_FLOAT },
	{ R32_UINT, R32_UINT }, { R32_SINT, R32_SINT }, { R32_SFLOAT, R32_FLOAT }, { RG32_UINT, RG32_UINT }, { RG32_SINT, RG32_SINT }, { RG32_SFLOAT, RG32_FLOAT },
	{ RGBA32_UINT, RGBA32_UINT }, { RGBA32_SINT, RGBA32_SINT }, { RGBA32_SFLOAT, RGBA32_FLOAT },
	{ R10_G10_B10_A2_UNORM, RGB10_A2_UNORM }, { R10_G10_B10_A2_UINT, RGB10_A2_UINT }, { R11_G11_B10_UFLOAT, RG11B10_UFLOAT }, { R9_G9_B9_E5_UNORM, RGB9_E5_UFLOAT },
	{ D16_UNORM, DEPTH16_UNORM }, { D32_SFLOAT, DEPTH32_FLOAT }, { D24_UNORM_S8_UINT, DEPTH24_PLUS_STENCIL8 }, { D32_SFLOAT_S8_UINT, DEPTH32_FLOAT_STENCIL8 },
	{ BC1_RGBA_UNORM, BC1_RGBA_UNORM }, { BC1_RGBA_SRGB, BC1_RGBA_UNORM_SRGB }, { BC2_RGBA_UNORM, BC2_RGBA_UNORM }, { BC2_RGBA_SRGB, BC2_RGBA_UNORM_SRGB },
	{ BC3_RGBA_UNORM, BC3_RGBA_UNORM }, { BC3_RGBA_SRGB, BC3_RGBA_UNORM_SRGB }, { BC4_R_UNORM, BC4_R_UNORM }, { BC4_R_SNORM, BC4_R_SNORM },
	{ BC5_RG_UNORM, BC5_RG_UNORM }, { BC5_RG_SNORM, BC5_RG_SNORM }, { BC6H_RGB_UFLOAT, BC6H_RGB_UFLOAT }, { BC6H_RGB_SFLOAT, BC6H_RGB_FLOAT }, { BC7_RGBA_UNORM, BC7_RGBA_UNORM }, { BC7_RGBA_SRGB, BC7_RGBA_UNORM_SRGB },
	{ ETC2_R8G8B8_UNORM, ETC2_RGB8_UNORM }, { ETC2_R8G8B8_SRGB, ETC2_RGB8_UNORM_SRGB }, { ETC2_R8G8B8A1_UNORM, ETC2_RGB8A1_UNORM }, { ETC2_R8G8B8A1_SRGB, ETC2_RGB8A1_UNORM_SRGB },
	{ ETC2_R8G8B8A8_UNORM, ETC2_RGBA8_UNORM }, { ETC2_R8G8B8A8_SRGB, ETC2_RGBA8_UNORM_SRGB }, { ETC2_EAC_R11_UNORM, EAC_R11_UNORM }, { ETC2_EAC_R11_SNORM, EAC_R11_SNORM }, { ETC2_EAC_R11G11_UNORM, EAC_RG11_UNORM }, { ETC2_EAC_R11G11_SNORM, EAC_RG11_SNORM },
};

fn WgpuTextureFormat? wgpu_format(Format f)
{
	foreach (p : WGPU_FORMATS) if (p.rhi == f) return p.gpu;
	return UNSUPPORTED_FEATURE~;
}

fn Format? wgpu_format_rhi(WgpuTextureFormat f)
{
	foreach (p : WGPU_FORMATS) if (p.gpu == f) return p.rhi;
	return UNSUPPORTED_FEATURE~;
}

// Odin's `(Wgpu_Texture_Format, Format)` result of
// `swapchain_wgpu_surface_format`.
struct SwapchainSurfaceFormat
{
	WgpuTextureFormat gpu;
	Format format;
}

// Maps the glue's preferred canvas format (a `WgpuTextureFormat` index) to
// what the swapchain uses. A value outside the RHI format table falls back to
// BGRA8, which every current browser reports anyway.
fn SwapchainSurfaceFormat swapchain_wgpu_surface_format(uint raw)
{
	if (raw < WgpuTextureFormat::len)
	{
		WgpuTextureFormat gpu = WgpuTextureFormat::from_ordinal(raw);
		if (try f = wgpu_format_rhi(gpu)) return { gpu, f };
	}
	return { WgpuTextureFormat.BGRA8_UNORM, Format.BGRA8_UNORM };
}

// The description of a swapchain colour image, carried by the borrowed
// `Image` so views and validation see its real shape.
fn ImageDesc swapchain_image_desc(Format format, ushort width, ushort height)
{
	return {
		.image_type = D2,
		.format = format,
		.width = (uint)width,
		.height = (uint)height,
		.depth = 1,
		.mip_levels = 1,
		.array_layers = 1,
		.samples = S1,
		.tiling = OPTIMAL,
		.usage = { .color_attachment = true, .transfer_src = true },
	};
}

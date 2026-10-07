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

// Tag of `WindowHandle`. `NONE` is the empty case.
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
// Tagged union of Canvas, X11, Wayland, Win32 and Metal handles: `kind` says which member of the anonymous
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

// Tag of `SwapchainSource`. `NONE` is the empty case.
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
// Tagged union of a window handle or a swapchain: `kind` says which
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
// A C3 optional carries only the fault, so `.Out_Of_Date` is not returned
// alongside `.Unsupported_Backend`.
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
// A C3 optional carries only the fault, so `.Out_Of_Date` is not returned
// alongside `.Unsupported_Backend`.
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

// Lives here (not in the WebGPU backend) so the ungated
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
// live here: the front needs them
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

// The `(WgpuTextureFormat, Format)` result of
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

// ---- metal ----

// Metal swapchain. A CAMetalLayer supplies one drawable at a time; its
// texture is exposed through borrowed Image/ImageView wrappers for the frame
// between acquire and submit.
//
// `image_count` is always 1: callers only index the drawable acquired for the
// current frame, just as with the web swapchain, while CAMetalLayer manages
// its own drawable pool internally.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import mtl;

struct SwapchainMtl
{
	// Owned by the swapchain. On recreate from another swapchain this handle is
	// moved from the old payload rather than retained twice.
	mtl::CAMetalLayer layer;
	mtl::PixelFormat pixel_format;
	Format format;
	// Retained while the frame is acquired; released after presentation or
	// during deinit if the frame was not submitted.
	mtl::CAMetalDrawable current_drawable;
}

fn Swapchain? swapchain_init_mtl(Device* device, SwapchainDesc desc, Allocator allocator = mem)
{
	if (device == null || !device.backend.mtl.device || desc.queue == null ||
		desc.width == 0 || desc.height == 0)
	{
		return INITIALIZATION_FAILED~;
	}

	mtl::CAMetalLayer layer = null;
	bool move_layer = false;
	if (desc.source.kind == WINDOW)
	{
		if (desc.source.window.kind != METAL || !desc.source.window.metal.layer)
		{
			return INITIALIZATION_FAILED~;
		}
		layer = (mtl::CAMetalLayer)desc.source.window.metal.layer;
		layer.retain();
	}
	else if (desc.source.kind == SWAPCHAIN)
	{
		Swapchain* old = desc.source.swapchain;
		if (old == null || !old.backend.mtl.layer) return INITIALIZATION_FAILED~;
		layer = old.backend.mtl.layer;
		move_layer = true;
	}
	else
	{
		return INITIALIZATION_FAILED~;
	}

	Swapchain result;
	objc::@autoreleasepool()
	{
		// CAMetalLayer is configured to the one format supported by the
		// rhi-zig Metal arm. Other requests use the same BGRA8 fallback.
		mtl::PixelFormat pixel_format = mtl::PixelFormat.BGRA8UNORM;
		Format format = Format.BGRA8_UNORM;
		layer.set_device(device.backend.mtl.device);
		layer.set_pixel_format(pixel_format);
		layer.set_drawable_size({ .width = (double)desc.width, .height = (double)desc.height });

		uint drawable_count = desc.request_image_count > 0 ? (uint)desc.request_image_count : 0;
		if (drawable_count < 2) drawable_count = 2;
		if (drawable_count > 3) drawable_count = 3;
		layer.set_maximum_drawable_count((mtl::NSUInteger)drawable_count);
		layer.set_display_sync_enabled(desc.vsync);

		result = {
			.allocator = allocator,
			.present_queue = desc.queue,
			.image_count = 1,
			.width = desc.width,
			.height = desc.height,
			.backend.mtl = {
				.layer = layer,
				.pixel_format = pixel_format,
				.format = format,
				.current_drawable = null,
			},
		};
	};

	if (move_layer)
	{
		Swapchain* old = desc.source.swapchain;
		if (old.backend.mtl.current_drawable)
		{
			old.backend.mtl.current_drawable.release();
			old.backend.mtl.current_drawable = null;
		}
		old.backend.mtl.layer = null;
	}
	return result;
}

fn void swapchain_deinit_mtl(Swapchain* s, Device* device)
{
	if (s == null) return;
	if (s.backend.mtl.current_drawable)
	{
		s.backend.mtl.current_drawable.release();
		s.backend.mtl.current_drawable = null;
	}
	if (s.backend.mtl.layer)
	{
		s.backend.mtl.layer.release();
		s.backend.mtl.layer = null;
	}
	s.backend.mtl = {};
}

fn void? swapchain_recreate_mtl(Swapchain* s, Device* device, ushort width, ushort height)
{
	if (s == null || !s.backend.mtl.layer || width == 0 || height == 0)
	{
		return INITIALIZATION_FAILED~;
	}
	if (s.backend.mtl.current_drawable)
	{
		s.backend.mtl.current_drawable.release();
		s.backend.mtl.current_drawable = null;
	}
	objc::@autoreleasepool()
	{
		s.backend.mtl.layer.set_drawable_size({ .width = (double)width, .height = (double)height });
	};
	s.width = width;
	s.height = height;
	return;
}

fn SwapchainStatus? swapchain_acquire_next_image_mtl(Swapchain* s, Device* device, uint* out_index)
{
	if (s == null || out_index == null || !s.backend.mtl.layer) return INITIALIZATION_FAILED~;
	objc::@autoreleasepool()
	{
		if (s.backend.mtl.current_drawable)
		{
			s.backend.mtl.current_drawable.release();
			s.backend.mtl.current_drawable = null;
		}
		mtl::CAMetalDrawable drawable = s.backend.mtl.layer.next_drawable();
		if (!drawable) return OUT_OF_DATE~;
		drawable.retain();
		s.backend.mtl.current_drawable = drawable;
	};
	*out_index = 0;
	return OK;
}

fn Image swapchain_image_mtl(Swapchain* s, uint index)
{
	if (s == null || index != 0 || !s.backend.mtl.current_drawable) return {};
	mtl::Texture texture = s.backend.mtl.current_drawable.texture();
	if (!texture) return {};
	return {
		.cookie = next_cookie(),
		.backend.mtl = {
			// Borrowed from the drawable; image_deinit must not be called on
			// this wrapper (see swapchain_image's front-end contract).
			.texture = texture,
			.texture_type = mtl::TextureType.TYPE_2D,
			.format = s.backend.mtl.format,
			.image_type = D2,
			.width = s.width,
			.height = s.height,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
		},
	};
}

fn ImageView swapchain_image_view_mtl(Swapchain* s, uint index)
{
	if (s == null || index != 0 || !s.backend.mtl.current_drawable) return {};
	mtl::Texture texture = s.backend.mtl.current_drawable.texture();
	if (!texture) return {};
	return {
		.cookie = next_cookie(),
		.backend.mtl = {
			// Both handles are borrowed from the current drawable.
			.texture = texture,
			.parent = null,
			.aliases_parent = false,
		},
	};
}

fn SwapchainStatus? swapchain_frame_submit_mtl(Swapchain* s, Device* device, Queue* queue, SwapchainFrameSubmit submit)
{
	if (s == null || device == null || queue == null || submit.image_index != 0)
	{
		return INITIALIZATION_FAILED~;
	}
	mtl::CAMetalDrawable drawable = s.backend.mtl.current_drawable;
	if (!drawable) return OUT_OF_DATE~;

	TimelineOp[1] signal_ops = {};
	TimelineOp[] signals = {};
	if (submit.timeline)
	{
		signal_ops[0] = { .timeline = submit.timeline, .value = swapchain_frame_signal_value(submit) };
		signals = &signal_ops;
	}
	QueueSubmitDesc queue_submit = {
		.cmds = submit.cmds,
		.signals = signals,
		.completion = submit.completion,
	};
	queue_submit_mtl_present(queue, device, queue_submit, drawable)!;

	// queue_submit_mtl_present has committed the command buffers after
	// encoding presentDrawable, so the swapchain can drop its ownership now.
	drawable.release();
	s.backend.mtl.current_drawable = null;
	return OK;
}

// ---- vulkan ----

// Vulkan swapchain. Vulkan swapchain section.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

const uint MAX_SWAPCHAIN_IMAGES = 8;

// Semaphores deviate from rhi-zig on purpose. Acquire semaphores rotate per
// acquire (`acquire_idx`), since which image comes back is unknown until the
// acquire returns. frame_submit records what retires the submit that waited
// on the semaphore, and acquire waits on it before signalling the semaphore
// again, so reuse is safe whatever order the caller waits its own frame
// fences in and whatever the image count. With a timeline it is the
// (timeline, value) the frame signals. Without one it is the semaphore's
// fence: attached to the frame submit itself when `completion` has no fence,
// else signalled by an empty submit queued right after (a submit takes one
// fence). The semaphore the present waits on is per IMAGE and owned by the
// swapchain (`present_semaphores[image_index]`): a present only releases its
// semaphore once that image is acquired again. rhi-zig signals the ring
// element's semaphore instead, which validation flags as reused while still
// in flight whenever images are presented out of order.
struct SwapchainVk
{
	vk::SurfaceKHR surface;
	vk::SwapchainKHR swapchain;
	vk::Format format;
	vk::ColorSpaceKHR colorspace;
	vk::PresentModeKHR present_mode;
	// The requested count is reused by recreate so the image count does not
	// drift with what the driver handed back.
	uint request_count;
	vk::Image[MAX_SWAPCHAIN_IMAGES] images;
	// Identities of the borrowed Images; the views carry their own cookies.
	ulong[MAX_SWAPCHAIN_IMAGES] image_cookies;
	ImageView[MAX_SWAPCHAIN_IMAGES] views;
	Semaphore[MAX_SWAPCHAIN_IMAGES] acquire_semaphores;
	Semaphore[MAX_SWAPCHAIN_IMAGES] present_semaphores;
	// Per acquire semaphore: signals once the last submit that waited on it
	// has retired, when that submit had no timeline. Created unsignalled.
	vk::Fence[MAX_SWAPCHAIN_IMAGES] acquire_fences;
	// Per acquire semaphore, when the last submit that waited on it signalled
	// a timeline: reuse waits for acquire_wait_value on it. Only read while
	// pending; assumes the caller's timeline outlives its frames.
	Timeline*[MAX_SWAPCHAIN_IMAGES] acquire_wait_timeline;
	ulong[MAX_SWAPCHAIN_IMAGES] acquire_wait_value;
	// Set when semaphore i's last submit was recorded and not yet waited on:
	// on acquire_wait_timeline[i] if set, else on acquire_fences[i].
	bool[MAX_SWAPCHAIN_IMAGES] acquire_pending;
	// Which acquire semaphore signalled each image's latest acquire, so
	// frame_submit waits on the right one.
	uint[MAX_SWAPCHAIN_IMAGES] image_acquire_idx;
	uint acquire_idx;
}

// Only referenced on Windows when a WindowWin32 omits its module handle.
extern fn vk::Hinstance vk_get_module_handle_w(vk::Lpcwstr module_name)
	@cname("GetModuleHandleW") @feat(WIN32);

fn uint swapchain_priority_bt709_g10_16bit(vk::SurfaceFormatKHR f) @private
{
	return (uint)(f.format == vk::Format.R16G16B16A16_SFLOAT) |
		(uint)(f.colorSpace == vk::ColorSpaceKHR.EXTENDED_SRGB_LINEAR_EXT) << 1;
}

fn uint swapchain_priority_bt709_g22_8bit(vk::SurfaceFormatKHR f) @private
{
	return (uint)(f.format == vk::Format.R8G8B8A8_UNORM || f.format == vk::Format.B8G8R8A8_UNORM) |
		(uint)(f.colorSpace == vk::ColorSpaceKHR.SRGB_NONLINEAR) << 1;
}

fn uint swapchain_priority_bt709_g22_10bit(vk::SurfaceFormatKHR f) @private
{
	return (uint)(f.format == vk::Format.A2B10G10R10_UNORM_PACK32) |
		(uint)(f.colorSpace == vk::ColorSpaceKHR.SRGB_NONLINEAR) << 1;
}

fn uint swapchain_priority_bt2020_g2084_10bit(vk::SurfaceFormatKHR f) @private
{
	return (uint)(f.format == vk::Format.A2B10G10R10_UNORM_PACK32) |
		(uint)(f.colorSpace == vk::ColorSpaceKHR.HDR10_ST2084_EXT) << 1;
}

fn uint swapchain_format_priority(SwapchainFormat want, vk::SurfaceFormatKHR format) @private
{
	switch (want)
	{
		case BT709_G10_16BIT: return swapchain_priority_bt709_g10_16bit(format);
		case BT709_G22_8BIT: return swapchain_priority_bt709_g22_8bit(format);
		case BT709_G22_10BIT: return swapchain_priority_bt709_g22_10bit(format);
		case BT2020_G2084_10BIT: return swapchain_priority_bt2020_g2084_10bit(format);
	}
}

fn vk::SurfaceKHR? swapchain_create_surface_vk(WindowHandle handle) @private
{
	vk::SurfaceKHR surface;
	vk::Result result = vk::Result.ERROR_INITIALIZATION_FAILED;
	switch (handle.kind)
	{
		case X11:
			$if env::LINUX:
				if (!handle.x11.display || !vk::createXlibSurfaceKHR) return INITIALIZATION_FAILED~;
				vk::XlibSurfaceCreateInfoKHR info = {
					.sType = vk::StructureType.XLIB_SURFACE_CREATE_INFO_KHR,
					.dpy = (vk::XlibDisplay*)handle.x11.display,
					.window = (vk::XlibWindow)handle.x11.window,
				};
				result = vk::createXlibSurfaceKHR(renderer.vk.instance, &info, null, &surface);
			$else
				return INITIALIZATION_FAILED~;
			$endif
		case WAYLAND:
			$if env::LINUX:
				if (!handle.wayland.display || !handle.wayland.surface || !vk::createWaylandSurfaceKHR) return INITIALIZATION_FAILED~;
				vk::WaylandSurfaceCreateInfoKHR info = {
					.sType = vk::StructureType.WAYLAND_SURFACE_CREATE_INFO_KHR,
					.display = (vk::WlDisplay*)handle.wayland.display,
					.surface = (vk::WlSurface*)handle.wayland.surface,
				};
				result = vk::createWaylandSurfaceKHR(renderer.vk.instance, &info, null, &surface);
			$else
				return INITIALIZATION_FAILED~;
			$endif
		case WIN32:
			$if env::WIN32:
				if (!handle.win32.hwnd || !vk::createWin32SurfaceKHR) return INITIALIZATION_FAILED~;
				vk::Hinstance hinstance = (vk::Hinstance)handle.win32.hinstance;
				if (!hinstance) hinstance = vk_get_module_handle_w(null);
				vk::Win32SurfaceCreateInfoKHR info = {
					.sType = vk::StructureType.WIN32_SURFACE_CREATE_INFO_KHR,
					.hinstance = hinstance,
					.hwnd = (vk::Hwnd)handle.win32.hwnd,
				};
				result = vk::createWin32SurfaceKHR(renderer.vk.instance, &info, null, &surface);
			$else
				return INITIALIZATION_FAILED~;
			$endif
		case CANVAS:
			return INITIALIZATION_FAILED~;
		case METAL:
			return INITIALIZATION_FAILED~;
		case NONE:
			return INITIALIZATION_FAILED~;
	}
	if (result != vk::Result.SUCCESS) vk_check(result)!;
	return surface;
}

fn vk::SurfaceFormatKHR? swapchain_select_format_vk(vk::PhysicalDevice physical, vk::SurfaceKHR surface, SwapchainFormat want) @private
{
	uint count;
	vk_check(vk::getPhysicalDeviceSurfaceFormatsKHR(physical, surface, &count, null))!;
	if (count == 0) return INITIALIZATION_FAILED~;
	vk::SurfaceFormatKHR[] formats = mem::temp_array(vk::SurfaceFormatKHR, count);
	vk_check(vk::getPhysicalDeviceSurfaceFormatsKHR(physical, surface, &count, formats.ptr))!;
	vk::SurfaceFormatKHR best = formats[0];
	for (uint i = 1; i < count; i++)
	{
		if (swapchain_format_priority(want, formats[i]) > swapchain_format_priority(want, best)) best = formats[i];
	}
	return best;
}

fn vk::PresentModeKHR? swapchain_select_present_mode_vk(vk::PhysicalDevice physical, vk::SurfaceKHR surface, bool vsync) @private
{
	if (vsync) return vk::PresentModeKHR.FIFO;
	uint count;
	vk_check(vk::getPhysicalDeviceSurfacePresentModesKHR(physical, surface, &count, null))!;
	vk::PresentModeKHR[] modes = mem::temp_array(vk::PresentModeKHR, count);
	vk_check(vk::getPhysicalDeviceSurfacePresentModesKHR(physical, surface, &count, modes.ptr))!;
	vk::PresentModeKHR[2] preferred = { vk::PresentModeKHR.MAILBOX, vk::PresentModeKHR.IMMEDIATE };
	foreach (mode : preferred)
	{
		foreach (available : modes)
		{
			if (available == mode) return mode;
		}
	}
	return vk::PresentModeKHR.FIFO;
}

// Destroys whatever v holds; zero handles are skipped, so this also unwinds
// a partially built swapchain. The surface is only destroyed when requested;
// a swapchain that hands it to a successor has it nulled first.
fn void swapchain_release_vk(SwapchainVk* v, Device* device, bool destroy_surface) @private
{
	for (uint i = 0; i < MAX_SWAPCHAIN_IMAGES; i++)
	{
		if (v.acquire_semaphores[i].backend.vk.semaphore != 0) semaphore_deinit_vk(&v.acquire_semaphores[i], device);
		if (v.present_semaphores[i].backend.vk.semaphore != 0) semaphore_deinit_vk(&v.present_semaphores[i], device);
		if (v.acquire_fences[i] != 0) device.backend.vk.vtable.destroyFence(device.backend.vk.device, v.acquire_fences[i], null);
		v.acquire_fences[i] = 0;
		v.acquire_wait_timeline[i] = null;
		v.acquire_wait_value[i] = 0;
		v.acquire_pending[i] = false;
		if (v.views[i].backend.vk.view != 0) image_view_deinit_vk(&v.views[i], device);
		v.views[i] = {};
		v.images[i] = 0;
		v.image_cookies[i] = 0;
	}
	if (v.swapchain != 0)
	{
		device.backend.vk.vtable.destroySwapchainKHR(device.backend.vk.device, v.swapchain, null);
		v.swapchain = 0;
	}
	if (destroy_surface && v.surface != 0) vk::destroySurfaceKHR(renderer.vk.instance, v.surface, null);
	v.surface = 0;
}

fn Swapchain? swapchain_init_vk(Device* device, SwapchainDesc desc, Allocator allocator = mem)
{
	if (device == null || desc.queue == null || desc.width == 0 || desc.height == 0) return INITIALIZATION_FAILED~;
	vk::PhysicalDevice physical = device.adapter.backend.vk.physical_device;
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;

	SwapchainVk v = {};
	bool owns_surface = false;
	Swapchain* old = null;
	switch (desc.source.kind)
	{
		case WINDOW:
			v.surface = swapchain_create_surface_vk(desc.source.window)!;
			owns_surface = true;
		case SWAPCHAIN:
			old = desc.source.swapchain;
			if (old == null) return SURFACE_LOST~;
			v.surface = old.backend.vk.surface;
		case NONE:
			return SURFACE_LOST~;
	}
	if (v.surface == 0) return SURFACE_LOST~;
	defer catch swapchain_release_vk(&v, device, owns_surface);

	vk::Bool32 supported;
	vk_check(vk::getPhysicalDeviceSurfaceSupportKHR(physical, desc.queue.backend.vk.family_index, v.surface, &supported))!;
	if (!supported) return INITIALIZATION_FAILED~;

	if (old != null)
	{
		v.format = old.backend.vk.format;
		v.colorspace = old.backend.vk.colorspace;
		v.present_mode = old.backend.vk.present_mode;
	}
	else
	{
		vk::SurfaceFormatKHR surface_format = swapchain_select_format_vk(physical, v.surface, desc.format)!;
		v.format = surface_format.format;
		v.colorspace = surface_format.colorSpace;
		v.present_mode = swapchain_select_present_mode_vk(physical, v.surface, desc.vsync)!;
	}

	vk::SurfaceCapabilitiesKHR caps;
	vk_check(vk::getPhysicalDeviceSurfaceCapabilitiesKHR(physical, v.surface, &caps))!;
	vk::Extent2D extent = caps.currentExtent;
	if (extent.width == uint::max)
	{
		extent.width = min(max((uint)desc.width, caps.minImageExtent.width), caps.maxImageExtent.width);
		extent.height = min(max((uint)desc.height, caps.minImageExtent.height), caps.maxImageExtent.height);
	}
	extent.width = min(extent.width, (uint)ushort::max);
	extent.height = min(extent.height, (uint)ushort::max);
	if (extent.width == 0 || extent.height == 0) return OUT_OF_DATE~;

	v.request_count = (uint)desc.request_image_count;
	uint image_count = max(v.request_count, caps.minImageCount);
	if (caps.maxImageCount > 0) image_count = min(image_count, caps.maxImageCount);
	image_count = min(image_count, MAX_SWAPCHAIN_IMAGES);
	if (image_count < caps.minImageCount) return INITIALIZATION_FAILED~;

	vk::CompositeAlphaFlagsKHR composite_alpha = vk::COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	if ((caps.supportedCompositeAlpha & composite_alpha) == 0)
	{
		vk::CompositeAlphaFlagsKHR[4] alpha_flags = {
			vk::COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
			vk::COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
			vk::COMPOSITE_ALPHA_INHERIT_BIT_KHR,
			vk::COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
		};
		foreach (flag : alpha_flags)
		{
			if ((caps.supportedCompositeAlpha & flag) != 0)
			{
				composite_alpha = flag;
				break;
			}
		}
	}

	vk::SwapchainCreateInfoKHR create_info = {
		.sType = vk::StructureType.SWAPCHAIN_CREATE_INFO_KHR,
		.surface = v.surface,
		.minImageCount = image_count,
		.imageFormat = v.format,
		.imageColorSpace = v.colorspace,
		.imageExtent = extent,
		.imageArrayLayers = 1,
		.imageUsage = vk::IMAGE_USAGE_COLOR_ATTACHMENT_BIT | vk::IMAGE_USAGE_TRANSFER_SRC_BIT,
		.imageSharingMode = vk::SharingMode.EXCLUSIVE,
		.preTransform = caps.currentTransform,
		.compositeAlpha = composite_alpha,
		.presentMode = v.present_mode,
		.clipped = vk::TRUE,
		.oldSwapchain = old != null ? old.backend.vk.swapchain : 0,
	};
	vk_check(vtable.createSwapchainKHR(device.backend.vk.device, &create_info, null, &v.swapchain))!;

	uint count;
	vk_check(vtable.getSwapchainImagesKHR(device.backend.vk.device, v.swapchain, &count, null))!;
	if (count == 0 || count > MAX_SWAPCHAIN_IMAGES) return INITIALIZATION_FAILED~;
	vk_check(vtable.getSwapchainImagesKHR(device.backend.vk.device, v.swapchain, &count, &v.images[0]))!;
	for (uint i = 0; i < count; i++)
	{
		v.image_cookies[i] = next_cookie();
		Image image = {
			.cookie = v.image_cookies[i],
			.backend.vk = { .image = v.images[i], .format = v.format, .borrowed = true },
		};
		v.views[i] = image_view_init_vk(device, &image, {
			.view_type = COLOR_ATTACHMENT,
			.format = from_vk_format(v.format),
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!;
		v.acquire_semaphores[i] = semaphore_init_vk(device)!;
		v.present_semaphores[i] = semaphore_init_vk(device)!;
		vk::FenceCreateInfo fence_info = { .sType = vk::StructureType.FENCE_CREATE_INFO };
		vk_check(vtable.createFence(device.backend.vk.device, &fence_info, null, &v.acquire_fences[i]))!;
	}

	if (old != null) old.backend.vk.surface = 0;
	return {
		.allocator = allocator,
		.present_queue = desc.queue,
		.image_count = count,
		.width = (ushort)extent.width,
		.height = (ushort)extent.height,
		.backend.vk = v,
	};
}

fn void swapchain_deinit_vk(Swapchain* s, Device* device)
{
	if (s == null) return;
	swapchain_release_vk(&s.backend.vk, device, true);
}

fn void? swapchain_recreate_vk(Swapchain* s, Device* device, ushort width, ushort height)
{
	if (s == null) return INITIALIZATION_FAILED~;
	Swapchain? next = swapchain_init_vk(device, {
		.width = width,
		.height = height,
		.request_image_count = (char)min(s.backend.vk.request_count, (uint)char::max),
		.queue = s.present_queue,
		.source = { .kind = SWAPCHAIN, .swapchain = s },
	}, s.allocator);
	Swapchain replacement = next!;
	swapchain_deinit_vk(s, device);
	*s = replacement;
}

fn SwapchainStatus? swapchain_acquire_next_image_vk(Swapchain* s, Device* device, uint* out_index)
{
	if (s == null || device == null || out_index == null || s.image_count == 0) return INITIALIZATION_FAILED~;
	SwapchainVk* v = &s.backend.vk;
	v.acquire_idx = (v.acquire_idx + 1) % s.image_count;
	uint acquire_idx = v.acquire_idx;
	if (v.acquire_pending[acquire_idx])
	{
		if (v.acquire_wait_timeline[acquire_idx])
		{
			timeline_wait_vk(v.acquire_wait_timeline[acquire_idx], device, v.acquire_wait_value[acquire_idx])!;
		}
		else
		{
			vk::Fence fence = v.acquire_fences[acquire_idx];
			vk_check(device.backend.vk.vtable.waitForFences(device.backend.vk.device, 1, &fence, vk::TRUE, ulong::max))!;
			vk_check(device.backend.vk.vtable.resetFences(device.backend.vk.device, 1, &fence))!;
		}
		v.acquire_wait_timeline[acquire_idx] = null;
		v.acquire_wait_value[acquire_idx] = 0;
		v.acquire_pending[acquire_idx] = false;
	}

	uint index;
	vk::Result result = device.backend.vk.vtable.acquireNextImageKHR(
		device.backend.vk.device, v.swapchain, ulong::max,
		v.acquire_semaphores[acquire_idx].backend.vk.semaphore, 0, &index);
	switch (result)
	{
		case vk::Result.SUCCESS:
			v.image_acquire_idx[index] = acquire_idx;
			*out_index = index;
			return OK;
		case vk::Result.SUBOPTIMAL_KHR:
			v.image_acquire_idx[index] = acquire_idx;
			*out_index = index;
			return SUBOPTIMAL;
		case vk::Result.ERROR_OUT_OF_DATE_KHR:
			return OUT_OF_DATE;
	}
	vk_check(result)!;
	return OUT_OF_DATE;
}

fn Image swapchain_image_vk(Swapchain* s, uint index)
{
	assert(s != null && index < s.image_count);
	SwapchainVk* v = &s.backend.vk;
	return {
		.cookie = v.image_cookies[index],
		.backend.vk = { .image = v.images[index], .format = v.format, .borrowed = true },
	};
}

fn ImageView swapchain_image_view_vk(Swapchain* s, uint index)
{
	assert(s != null && index < s.image_count);
	ImageView view = s.backend.vk.views[index];
	return {
		.cookie = view.cookie,
		.backend.vk = { .view = view.backend.vk.view, .borrowed = true },
	};
}

fn SwapchainStatus? swapchain_frame_submit_vk(Swapchain* s, Device* device, Queue* queue, SwapchainFrameSubmit submit)
{
	if (s == null || device == null || queue == null || submit.image_index >= s.image_count) return INITIALIZATION_FAILED~;
	SwapchainVk* v = &s.backend.vk;
	uint acquire_idx = v.image_acquire_idx[submit.image_index];
	Semaphore* acquire = &v.acquire_semaphores[acquire_idx];
	Semaphore* present = &v.present_semaphores[submit.image_index];

	Semaphore*[1] waits = { acquire };
	BarrierStages[1] wait_stages = { { .color_attachment = true } };
	Semaphore*[1] binary_signals = { present };
	TimelineOp[1] signal_ops = { { .timeline = submit.timeline, .value = swapchain_frame_signal_value(submit) } };
	TimelineOp[] signals = {};
	if (submit.timeline) signals = signal_ops[..];
	bool has_completion_fence = submit.completion != null && submit.completion.backend.vk.fence != 0;
	vk::Fence fallback_fence = !submit.timeline && !has_completion_fence ? v.acquire_fences[acquire_idx] : 0;
	queue_submit_vk(queue, device, {
		.cmds = submit.cmds,
		.signals = signals,
		.binary_waits = waits[..],
		.binary_wait_stages = wait_stages[..],
		.binary_signals = binary_signals[..],
		.completion = submit.completion,
	}, fallback_fence)!;
	if (submit.timeline)
	{
		v.acquire_wait_timeline[acquire_idx] = submit.timeline;
		v.acquire_wait_value[acquire_idx] = signal_ops[0].value;
	}
	else if (has_completion_fence)
	{
		vk_check(device.backend.vk.vtable.queueSubmit2(queue.backend.vk.queue, 0, null, v.acquire_fences[acquire_idx]))!;
	}
	v.acquire_pending[acquire_idx] = true;

	vk::Semaphore present_semaphore = present.backend.vk.semaphore;
	uint image_index = submit.image_index;
	vk::PresentInfoKHR present_info = {
		.sType = vk::StructureType.PRESENT_INFO_KHR,
		.waitSemaphoreCount = 1,
		.pWaitSemaphores = &present_semaphore,
		.swapchainCount = 1,
		.pSwapchains = &v.swapchain,
		.pImageIndices = &image_index,
	};
	vk::Result result = device.backend.vk.vtable.queuePresentKHR(s.present_queue.backend.vk.queue, &present_info);
	switch (result)
	{
		case vk::Result.SUCCESS: return OK;
		case vk::Result.SUBOPTIMAL_KHR: return SUBOPTIMAL;
		case vk::Result.ERROR_OUT_OF_DATE_KHR: return OUT_OF_DATE;
	}
	vk_check(result)!;
	return OK;
}

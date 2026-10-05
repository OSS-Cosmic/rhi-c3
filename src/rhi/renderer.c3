// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Global renderer: loads a backend and owns its instance-level handles. Port
// of rhi-zig's `renderer.zig`.
//
// This is also the first backend code in the port, so it sets the convention
// every later backend ticket follows:
//   - The front file (this one) holds backend-neutral types and dispatches on
//     `renderer.backend`. The per-backend payload lives in an anonymous
//     `union` field, mirroring Zig's untagged `backend: union`, with one
//     member per backend (vk, dx12, mtl, wgpu, webgl).
//   - Each backend has one source file (`vulkan.c3`, `d3d12.c3`, `mtl_*.c3`,
//     `webgpu.c3`, `webgl.c3`, and `web.c3` for code the two web
//     backends share). Inside, each front-door area gets a section banner
//     (e.g. `// ---- renderer ----`), and every section is gated so it also
//     compiles out under `-D RHI_HEADLESS`.
//   - backend_stubs.c3 declares empty stand-ins for backends that are not
//     compiled on the current target so the union remains portable.
//   - Dispatch: `switch (renderer.backend) { case VK: $if HAS_VK: return
//     renderer_init_vk(...); $endif ... }`, falling through to
//     `UNSUPPORTED_BACKEND`.
//   - Errors use the faults from `rhi.c3`.
module rhi;

struct Renderer
{
	Backend backend;
	union
	{
		RendererVk vk;
		RendererWgpu wgpu;
		RendererWebgl webgl;
		RendererDx12 dx12;
		RendererMtl mtl;
	}
}

// The single global renderer instance. There is only ever one renderer per
// application, so it is a global singleton rather than a value threaded
// through the API. Populated by `renderer_init`; referenced elsewhere as
// `rhi::renderer`.
Renderer renderer;

struct RendererVkOptions
{
	ZString app_name;
	bool enable_validation_layer;
}

struct RendererWgpuOptions { char _unused; }
struct RendererWebglOptions { char _unused; }
struct RendererMtlOptions { char _unused; }

enum D3d12ValidationLevel : char
{
	NONE,
	STANDARD,
	GPU_BASED,
}

// Device Removed Extended Data. `DEFAULT` enables DRED only alongside the
// debug layer; `OFF` / `ON` force it.
enum D3d12DredMode : char
{
	DEFAULT,
	OFF,
	ON,
}

struct RendererDx12Options
{
	ZString app_name;
	D3d12ValidationLevel validation;
	D3d12DredMode dred;
}

// Odin's `Renderer_Options` tagged union. `backend` is the tag: it selects
// which member of the anonymous union is live (`VK` -> `vk`, `WGPU` -> `wgpu`,
// `WEBGL` -> `webgl`, `DX12` -> `dx12`, `MTL` -> `mtl`). `renderer_init`
// rejects a backend that is not compiled in with `UNSUPPORTED_BACKEND`.
struct RendererOptions
{
	Backend backend;
	union
	{
		RendererVkOptions vk;
		RendererWgpuOptions wgpu;
		RendererWebglOptions webgl;
		RendererDx12Options dx12;
		RendererMtlOptions mtl;
	}
}

fn void? renderer_init(RendererOptions opts, Allocator allocator = mem)
{
	switch (opts.backend)
	{
		case VK:
			$if HAS_VK:
				return renderer_init_vk(opts.vk, allocator);
			$endif
		case DX12:
			$if HAS_DX12:
				return renderer_init_dx12(opts.dx12, allocator);
			$endif
		case MTL:
			$if HAS_MTL:
				return renderer_init_mtl(opts.mtl, allocator);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return renderer_init_wgpu(opts.wgpu, allocator);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return renderer_init_webgl(opts.webgl, allocator);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void renderer_deinit()
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				renderer_deinit_vk();
			$endif
		case DX12:
			$if HAS_DX12:
				renderer_deinit_dx12();
			$endif
		case MTL:
			$if HAS_MTL:
				renderer_deinit_mtl();
			$endif
		case WGPU:
			$if HAS_WGPU:
				renderer_deinit_wgpu();
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				renderer_deinit_webgl();
			$endif
	}
}

fn String renderer_api_string()
{
	switch (renderer.backend)
	{
		case VK:
			return "Vulkan";
		case DX12:
			return "DirectX 12";
		case MTL:
			return "Metal";
		case WGPU:
			return "WebGPU";
		case WEBGL:
			return "WebGL2";
	}
}

fn bool is_target_selected(Backend api)
{
	return platform_has_api(api) && renderer.backend == api;
}

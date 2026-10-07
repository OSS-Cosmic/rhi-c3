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

// Renderer options tagged union. `backend` is the tag: it selects
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

// ---- metal ----

// Metal renderer. Port of the `.mtl` arm of rhi-zig's `renderer.zig`
// `Renderer.init`.
//
// Metal has no instance object: an `MTLDevice` is created per adapter by
// `device_init`, so the renderer only records that Metal is the selected
// backend.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct RendererMtl
{
	char _unused;
}

fn void? renderer_init_mtl(RendererMtlOptions opts, Allocator allocator = mem)
{
	renderer = {
		.backend = MTL,
		.mtl = {},
	};
}

fn void renderer_deinit_mtl()
{
}

// ---- dx12 ----

// Direct3D 12 renderer. Port of the `.dx12` arm of rhi-zig's `renderer.zig`
// `Renderer.init`: enables the D3D12 debug layer when validation is requested
// and creates the DXGI factory that adapter enumeration and device creation
// hang off.
//
// d3d12.dll / dxgi.dll are linked directly (see vendor/d3d12/procedures.c3),
// so there is no library handle to manage.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct RendererDx12
{
	// Owned. IDXGIFactory6 when the OS has it, else IDXGIFactory2 (same vtable
	// layout; `has_factory6` says whether enum_adapter_by_gpu_preference is
	// callable).
	dxgi::Factory6* factory;
	bool has_factory6;
	// Owned; null unless validation was requested and the debug layer exists.
	d3d12::Debug* debug;
}

// Maps an HRESULT onto the front's fault space. S_OK and friends pass.
fn void? dx12_check(dxgi::HResult hr)
{
	if (dxgi::succeeded(hr)) return;
	switch (hr)
	{
		case dxgi::DXGI_ERROR_DEVICE_REMOVED:
		case dxgi::DXGI_ERROR_DEVICE_HUNG:
		case dxgi::DXGI_ERROR_DEVICE_RESET:
			return DEVICE_LOST~;
		case dxgi::E_OUTOFMEMORY:
			return OUT_OF_DEVICE_MEMORY~;
		default:
			return UNKNOWN~;
	}
}

fn void? renderer_init_dx12(RendererDx12Options opts, Allocator allocator = mem)
{
	// TODO: GPU_BASED validation needs ID3D12Debug1::SetEnableGPUBasedValidation
	// and DRED needs ID3D12DeviceRemovedExtendedDataSettings; neither is bound
	// in vendor/d3d12 yet, so GPU_BASED behaves like STANDARD and `opts.dred`
	// is ignored.
	d3d12::Debug* debug;
	uint factory_flags = 0;
	if (opts.validation != D3d12ValidationLevel.NONE)
	{
		Guid iid = d3d12::IID_DEBUG;
		if (dxgi::succeeded(d3d12::get_debug_interface(&iid, (void**)&debug)) && debug)
		{
			debug.vtbl.enable_debug_layer(debug);
			factory_flags |= dxgi::CREATE_FACTORY_DEBUG;
		}
		else
		{
			debug = null;
			log::warn("D3D12 debug layer requested but not available");
		}
	}

	dxgi::Factory6* factory;
	bool has_factory6 = true;
	Guid iid6 = dxgi::IID_DXGI_FACTORY6;
	if (dxgi::failed(d3d12::create_dxgi_factory2(factory_flags, &iid6, (void**)&factory)))
	{
		has_factory6 = false;
		Guid iid2 = dxgi::IID_DXGI_FACTORY2;
		if (dxgi::failed(d3d12::create_dxgi_factory2(factory_flags, &iid2, (void**)&factory)) || !factory)
		{
			if (debug) dxgi::release(debug);
			return INITIALIZATION_FAILED~;
		}
	}

	renderer = {
		.backend = DX12,
		.dx12 = {
			.factory = factory,
			.has_factory6 = has_factory6,
			.debug = debug,
		},
	};
}

fn void renderer_deinit_dx12()
{
	RendererDx12* state = &renderer.dx12;
	if (state.factory) dxgi::release(state.factory);
	if (state.debug) dxgi::release(state.debug);
	*state = {};
}

// ---- vulkan ----

// Vulkan renderer: loads the Vulkan loader library at run time (through volk),
// creates the instance and (with validation) a debug messenger.
//
// Logging uses std::core::log. The per-layer/per-extension
// listing and `VK INFO` messages go to `CATEGORY_RENDER`, which only reports
// ERROR and above by default, so they stay quiet unless that category's
// priority is lowered; `VK ERROR`/`VK WARNING` use the default category.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, volk, std::atomic;
import std::collections::list;

struct RendererVk
{
	uint api_version;
	vk::Instance instance;
	vk::DebugUtilsMessengerEXT debug_messenger;
}

fn void? renderer_init_vk(RendererVkOptions opt, Allocator allocator = mem)
{
	if (volk::initialize() != vk::Result.SUCCESS)
	{
		log::error("Failed to load the Vulkan loader library");
		return INITIALIZATION_FAILED~;
	}
	defer catch volk::finalize();

	vk::load_proc_addresses_global(volk::get_instance_proc_addr());

	vk::ApplicationInfo app_info = {
		.sType = APPLICATION_INFO,
		.pApplicationName = opt.app_name,
		.applicationVersion = vk::@make_api_version(0, 0, 0, 1),
		.engineVersion = vk::@make_api_version(0, 0, 0, 1),
		.apiVersion = vk::API_VERSION_1_3,
	};

	vk::ValidationFeatureEnableEXT[1] enabled_validation_features = { DEBUG_PRINTF };
	vk::ValidationFeaturesEXT validation_features = {
		.sType = VALIDATION_FEATURES_EXT,
		.enabledValidationFeatureCount = enabled_validation_features.len,
		.pEnabledValidationFeatures = &enabled_validation_features,
	};

	List{ZString} enabled_layer_names;
	enabled_layer_names.init(allocator);
	defer enabled_layer_names.free();
	List{ZString} enabled_extension_names;
	enabled_extension_names.init(allocator);
	defer enabled_extension_names.free();

	// The enabled names point into these, so they must outlive createInstance.
	vk::LayerProperties[] layers;
	defer mem::alloc::free(allocator, layers.ptr);
	vk::ExtensionProperties[] exts;
	defer mem::alloc::free(allocator, exts.ptr);

	{
		uint layer_count;
		vk::enumerateInstanceLayerProperties(&layer_count, null);
		layers = mem::alloc::alloc_array_try(allocator, vk::LayerProperties, layer_count)!;
		vk::enumerateInstanceLayerProperties(&layer_count, layers.ptr);

		foreach (&layer : layers)
		{
			ZString name = (ZString)&layer.layerName;
			bool use_layer = opt.enable_validation_layer && name.str_view() == "VK_LAYER_KHRONOS_validation";
			log::info("Instance Layer: %s(%d): %s", name, layer.specVersion, use_layer ? "ENABLED" : "DISABLED", category: log::CATEGORY_RENDER);
			if (use_layer) enabled_layer_names.push(name);
		}
	}

	{
		uint ext_count;
		vk::enumerateInstanceExtensionProperties(null, &ext_count, null);
		exts = mem::alloc::alloc_array_try(allocator, vk::ExtensionProperties, ext_count)!;
		vk::enumerateInstanceExtensionProperties(null, &ext_count, exts.ptr);

		foreach (&ext : exts)
		{
			ZString name = (ZString)&ext.extensionName;
			String s = name.str_view();
			bool use_ext = false;
			$if env::WIN32:
				use_ext |= s == vk::KHR_WIN32_SURFACE_EXTENSION_NAME.str_view();
			$else
				use_ext |= s == vk::KHR_XLIB_SURFACE_EXTENSION_NAME.str_view() || s == vk::KHR_WAYLAND_SURFACE_EXTENSION_NAME.str_view();
			$endif
			use_ext |= s == vk::KHR_SURFACE_EXTENSION_NAME.str_view();
			use_ext |= s == vk::EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME.str_view();
			use_ext |= s == vk::EXT_DEBUG_UTILS_EXTENSION_NAME.str_view();

			log::info("Instance Extension: %s(%d): %s", name, ext.specVersion, use_ext ? "ENABLED" : "DISABLED", category: log::CATEGORY_RENDER);
			if (use_ext) enabled_extension_names.push(name);
		}
	}

	vk::InstanceCreateInfo create_info = {
		.sType = INSTANCE_CREATE_INFO,
		.pApplicationInfo = &app_info,
		.ppEnabledLayerNames = enabled_layer_names.len() ? &enabled_layer_names[0] : null,
		.enabledLayerCount = (uint)enabled_layer_names.len(),
		.ppEnabledExtensionNames = enabled_extension_names.len() ? &enabled_extension_names[0] : null,
		.enabledExtensionCount = (uint)enabled_extension_names.len(),
	};

	if (opt.enable_validation_layer) vk_add_next(&create_info, &validation_features);

	vk::Instance instance;
	vk_check(vk::createInstance(&create_info, null, &instance))!;

	vk::load_proc_addresses_instance(instance);

	vk::DebugUtilsMessengerEXT debug_messenger;
	if (opt.enable_validation_layer && vk::createDebugUtilsMessengerEXT)
	{
		vk::DebugUtilsMessengerCreateInfoEXT debug_create_info = {
			.sType = DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			.pfnUserCallback = &vk_debug_messenger_callback,
			.messageSeverity = vk::DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT
				| vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
				| vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
			.messageType = vk::DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
				| vk::DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
				| vk::DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
		};
		if (catch err = vk_check(vk::createDebugUtilsMessengerEXT(instance, &debug_create_info, null, &debug_messenger)))
		{
			vk::destroyInstance(instance, null);
			return err~;
		}
	}

	renderer = {
		.backend = VK,
		.vk = {
			.api_version = app_info.apiVersion,
			.instance = instance,
			.debug_messenger = debug_messenger,
		},
	};
}

fn void renderer_deinit_vk()
{
	RendererVk* vk_renderer = &renderer.vk;
	if (vk_renderer.debug_messenger != 0 && vk::destroyDebugUtilsMessengerEXT)
	{
		vk::destroyDebugUtilsMessengerEXT(vk_renderer.instance, vk_renderer.debug_messenger, null);
	}
	if (vk_renderer.instance != null) vk::destroyInstance(vk_renderer.instance, null);
	volk::finalize();
	*vk_renderer = {};
}

// Number of validation errors reported through vk_debug_messenger_callback
// The test runner hides stdout of passing tests, so tests with
// validation enabled read this before and after to catch `VK ERROR`s.
uint vk_validation_error_count;

// Port of `VKDebugMessengerUtility`. Called from driver threads; C3 needs no
// saved context for logging.
fn vk::Bool32 vk_debug_messenger_callback(
	vk::DebugUtilsMessageSeverityFlagBitsEXT message_severity,
	vk::DebugUtilsMessageTypeFlagsEXT message_types,
	vk::DebugUtilsMessengerCallbackDataEXT* callback_data,
	void* user_data) @private
{
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
	{
		atomic::fetch_add(&vk_validation_error_count, 1u);
		log::error("VK ERROR: %s", callback_data.pMessage);
	}
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT)
	{
		log::warn("VK WARNING: %s", callback_data.pMessage);
	}
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT)
	{
		log::info("VK INFO: %s", callback_data.pMessage, category: log::CATEGORY_RENDER);
	}
	return vk::FALSE;
}

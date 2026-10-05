// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan renderer: loads the Vulkan loader library at run time, creates the
// instance and (with validation) a debug messenger. Port of the
// `---- renderer ----` section of rhi/vulkan.odin.
//
// std has no cross-platform dynamic-library wrapper, so the loader is opened
// with libc's dlopen/dlsym/dlclose on Linux and std::os::win32's
// LoadLibraryA/GetProcAddress/FreeLibrary on Windows.
//
// Logging uses std::core::log. Odin's per-layer/per-extension `log.infof`
// listing and `VK INFO` messages go to `CATEGORY_RENDER`, which only reports
// ERROR and above by default, so they stay quiet unless that category's
// priority is lowered; `VK ERROR`/`VK WARNING` use the default category.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, libc, std::os::win32, std::atomic;
import std::collections::list;

struct RendererVk
{
	uint api_version;
	vk::Instance instance;
	vk::DebugUtilsMessengerEXT debug_messenger;
	// dlopen handle on Linux, HMODULE on Windows.
	void* library;
}

fn void vk_unload_library(void* library) @private
{
	if (!library) return;
	$if env::WIN32:
		win32::freeLibrary((win32::Win32_HMODULE)library);
	$else
		libc::dlclose(library);
	$endif
}

// Returns vkGetInstanceProcAddr and stores the library handle in `library`.
fn void*? vk_load_get_instance_proc_addr(void** library) @private
{
	$if env::WIN32:
		win32::Win32_HMODULE lib = win32::loadLibraryA("vulkan-1.dll");
		if (!lib)
		{
			log::error("Failed to load vulkan-1.dll");
			return INITIALIZATION_FAILED~;
		}
		void* addr = (void*)win32::getProcAddress(lib, "vkGetInstanceProcAddr");
		if (!addr)
		{
			win32::freeLibrary(lib);
			return INITIALIZATION_FAILED~;
		}
		*library = (void*)lib;
		return addr;
	$else
		ZString[2] names = { "libvulkan.so.1", "libvulkan.so" };
		foreach (name : names)
		{
			log::info("Trying to load Vulkan library: %s", name, category: log::CATEGORY_RENDER);
			void* lib = libc::dlopen(name, libc::RTLD_NOW | libc::RTLD_LOCAL);
			if (!lib) continue;
			void* addr = libc::dlsym(lib, "vkGetInstanceProcAddr");
			if (!addr)
			{
				libc::dlclose(lib);
				continue;
			}
			*library = lib;
			return addr;
		}
		return INITIALIZATION_FAILED~;
	$endif
}

fn void? renderer_init_vk(RendererVkOptions opt, Allocator allocator = mem)
{
	void* library;
	void* proc_addr = vk_load_get_instance_proc_addr(&library)!;
	defer catch vk_unload_library(library);

	vk::load_proc_addresses_global(proc_addr);

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
			.library = library,
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
	vk_unload_library(vk_renderer.library);
	*vk_renderer = {};
}

// Number of validation errors reported through vk_debug_messenger_callback
// (not in Odin). The test runner hides stdout of passing tests, so tests with
// validation enabled read this before and after to catch `VK ERROR`s.
uint vk_validation_error_count;

// Port of `VKDebugMessengerUtility`. Called from driver threads; C3 needs no
// saved context for logging, so Odin's `vk_debug_logger` is dropped.
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

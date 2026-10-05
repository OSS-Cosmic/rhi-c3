// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan swapchain. Port of the swapchain section of rhi/vulkan.odin.
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

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

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

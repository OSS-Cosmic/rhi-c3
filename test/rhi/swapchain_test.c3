// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

// Test names that would clash with the procs under test (same module) get a
// descriptive suffix.

fn void swapchain_validate_desc_rejects_invalid() @test
{
	Queue queue;
	SwapchainDesc desc = {
		.width = 640,
		.height = 480,
		.queue = &queue,
		.source = { .kind = WINDOW, .window = { .kind = CANVAS } },
	};
	test::@check(@ok(swapchain_validate_desc(desc)));

	SwapchainDesc zero = desc;
	zero.width = 0;
	test::@check(@catch(swapchain_validate_desc(zero)) == INITIALIZATION_FAILED);

	SwapchainDesc no_queue = desc;
	no_queue.queue = null;
	test::@check(@catch(swapchain_validate_desc(no_queue)) == INITIALIZATION_FAILED);

	SwapchainDesc no_source = desc;
	no_source.source = {};
	test::@check(@catch(swapchain_validate_desc(no_source)) == INITIALIZATION_FAILED);

	SwapchainDesc nil_old = desc;
	nil_old.source = { .kind = SWAPCHAIN, .swapchain = null };
	test::@check(@catch(swapchain_validate_desc(nil_old)) == INITIALIZATION_FAILED);
}

fn void swapchain_canvas_selector_default() @test
{
	test::eq(swapchain_canvas_selector({}), "#canvas");
	test::eq(swapchain_canvas_selector({ .selector = "#view" }), "#view");
}

fn void swapchain_frame_signal_value_reserves() @test
{
	test::eq(swapchain_frame_signal_value({}), 0ul);

	Timeline timeline = { .signal_value = 4 };
	test::eq(swapchain_frame_signal_value({ .timeline = &timeline }), 5ul);
	test::eq(timeline_pending(&timeline), 5ul);

	// A caller-reserved value is used as is and does not advance the counter.
	test::eq(swapchain_frame_signal_value({ .timeline = &timeline, .signal_value = 9 }), 9ul);
	test::eq(timeline_pending(&timeline), 5ul);
}

fn void swapchain_wgpu_surface_format_maps() @test
{
	SwapchainSurfaceFormat s = swapchain_wgpu_surface_format((uint)WgpuTextureFormat.BGRA8_UNORM.ordinal);
	test::@check(s.gpu == WgpuTextureFormat.BGRA8_UNORM);
	test::@check(s.format == Format.BGRA8_UNORM);

	s = swapchain_wgpu_surface_format((uint)WgpuTextureFormat.RGBA8_UNORM.ordinal);
	test::@check(s.gpu == WgpuTextureFormat.RGBA8_UNORM);
	test::@check(s.format == Format.RGBA8_UNORM);

	// Out of range falls back to BGRA8.
	s = swapchain_wgpu_surface_format(0xFFFF);
	test::@check(s.gpu == WgpuTextureFormat.BGRA8_UNORM);
	test::@check(s.format == Format.BGRA8_UNORM);
}

// test_swapchain_image_desc_is_valid_color_target is not ported here: it
// needs `gl_image_validate` / `wgpu_image_create_params` from the web
// backends, so the web port adds it.

fn void swapchain_unsupported_backend_natively() @test
{
	// No web backend is compiled natively, so every web arm falls through.
	Backend saved = renderer.backend;
	defer renderer.backend = saved;
	renderer.backend = WEBGL;
	Queue queue;
	SwapchainDesc desc = {
		.width = 1,
		.height = 1,
		.queue = &queue,
		.source = { .kind = WINDOW, .window = { .kind = CANVAS } },
	};
	test::@check(@catch(swapchain_init(null, desc)) == UNSUPPORTED_BACKEND);
}

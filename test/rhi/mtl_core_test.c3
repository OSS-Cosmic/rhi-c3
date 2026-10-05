// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal core tests: renderer, adapter enumeration, device, queue, timeline
// and fence. They need a Metal device and so only run on a Mac; elsewhere
// they are compiled out.
//
// Tests run one after another on the main thread (see vk_core_test.c3), so
// the global `renderer` needs no lock.
module rhi @feat(RHI_MTL & DARWIN);
import std::core::test;

fn void mtl_renderer_init_selects_metal() @test
{
	renderer_init({ .backend = MTL, .mtl = {} })!!;
	test::eq(renderer_api_string(), "Metal");
	test::@check(is_target_selected(MTL));
	renderer_deinit();
}

module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::core::test;
import std::collections::list;

// Initializes the Metal renderer and a device on the default adapter, runs
// `@body` with it, then tears both down.
macro @with_mtl_device(;@body(Device* device))
{
	renderer_init({ .backend = MTL, .mtl = {} })!!;
	defer renderer_deinit();
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	Device device = device_init(&adapters[default_select_adapter(adapters.array_view())])!!;
	defer device_deinit(&device);
	@body(&device);
}

fn void mtl_enumerate_adapters_names_each() @test
{
	renderer_init({ .backend = MTL, .mtl = {} })!!;
	defer renderer_deinit();
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	test::@check(adapters.len() >= 1);
	foreach (&a : adapters)
	{
		test::@check(physical_adapter_name(a).len > 0);
		test::@check(a.backend.mtl.device != null);
	}
}

fn void mtl_device_init_deinit() @test
{
	@with_mtl_device(; Device* device)
	{
		test::@check(device.backend.mtl.device != null);
		test::@check(device.backend.mtl.queue != null);
		test::@check(device.graphics_queue.backend.mtl.queue == device.backend.mtl.queue);
		test::@check(!device.has_compute_queue);
		test::@check(!device.has_transfer_queue);
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void mtl_timeline_submit_empty_and_wait() @test
{
	@with_mtl_device(; Device* device)
	{
		Timeline timeline = timeline_init(device)!!;
		defer timeline_deinit(&timeline, device);
		test::@check(timeline_completed(&timeline, device)!! == 0);

		ulong value = timeline_next(&timeline);
		queue_submit(&device.graphics_queue, device, { .signals = { { .timeline = &timeline, .value = value } } })!!;
		timeline_wait(&timeline, device, value)!!;
		test::@check(timeline_completed(&timeline, device)!! >= value);
	};
}

fn void mtl_timeline_two_submit_chain() @test
{
	@with_mtl_device(; Device* device)
	{
		Timeline timeline = timeline_init(device)!!;
		defer timeline_deinit(&timeline, device);

		ulong first = timeline_next(&timeline);
		queue_submit(&device.graphics_queue, device, { .signals = { { .timeline = &timeline, .value = first } } })!!;
		ulong second = timeline_next(&timeline);
		queue_submit(&device.graphics_queue, device, {
			.waits = { { .timeline = &timeline, .value = first } },
			.signals = { { .timeline = &timeline, .value = second } },
		})!!;
		timeline_wait(&timeline, device, second)!!;
		test::@check(timeline_completed(&timeline, device)!! == second);
	};
}

fn void mtl_submit_stamps_completion() @test
{
	@with_mtl_device(; Device* device)
	{
		CommandRingElement element;
		queue_submit(&device.graphics_queue, device, { .completion = &element })!!;
		test::@check(element.backend.mtl.event != null);
		test::@check(element.backend.mtl.value > 0);
		queue_wait_idle(&device.graphics_queue, device)!!;
		test::@check(element.backend.mtl.event.signaled_value() >= element.backend.mtl.value);
	};
}

fn void mtl_fence_signaled_and_unsignaled() @test
{
	@with_mtl_device(; Device* device)
	{
		Fence signaled = fence_init(device, true)!!;
		defer fence_deinit(&signaled, device);
		Fence unsignaled = fence_init(device, false)!!;
		defer fence_deinit(&unsignaled, device);

		test::@check(fence_status(&signaled, device)!! == COMPLETE);
		test::@check(fence_status(&unsignaled, device)!! == INCOMPLETE);
		fence_wait(device, { &signaled })!!;
	};
}

fn void mtl_semaphore_unsupported() @test
{
	@with_mtl_device(; Device* device)
	{
		if (catch err = semaphore_init(device))
		{
			test::@check(err == UNSUPPORTED_FEATURE);
		}
		else
		{
			test::@check(false, "semaphore_init should be unsupported on Metal");
		}
	};
}

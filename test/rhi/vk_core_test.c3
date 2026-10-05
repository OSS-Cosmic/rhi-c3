// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan renderer and format-mapping tests. Port of the `---- renderer ----`
// section of rhi/vulkan_test.odin.
//
// Odin guards the global `renderer` with `gpu_test_lock` because its test
// runner runs tests on several threads. C3's runner (std::core::runtime_test
// `run_tests`) runs every @test one after another in a plain `foreach` on the
// main thread, so no lock is needed.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::core::test;
import std::collections::list;
import vk;

fn void renderer_init_deinit() @test
{
	RendererOptions opts = { .backend = VK, .vk = { .app_name = "rhi-test" } };
	renderer_init(opts)!!;
	test::eq(renderer_api_string(), "Vulkan");
	test::@check(is_target_selected(VK));
	renderer_deinit();
}

fn void format_mapping_round_trips() @test
{
	test::@check(to_vk_format(Format.UNKNOWN) == vk::Format.UNDEFINED);

	foreach (row : VK_FORMAT_MAPPINGS)
	{
		// Count how many rows share this vk value
		int duplicate_count = 0;
		foreach (other : VK_FORMAT_MAPPINGS)
		{
			if (other.vk == row.vk) duplicate_count++;
		}

		// Only test round-trip for non-aliased values
		if (duplicate_count == 1)
		{
			test::eq(from_vk_format(to_vk_format(row.rhi)), row.rhi);
		}
	}
}

// ---- sync (was vulkan_sync_test.odin) ----
// Validation is enabled here (Odin's tests leave it off) so a validation
// error during the test fails it through `vk_validation_error_count`. Without
// the Khronos layer installed the renderer simply comes up without it.

fn void timeline_fence_semaphore_vk() @test
{
	RendererOptions opts = { .backend = VK, .vk = { .app_name = "rhi-test", .enable_validation_layer = true } };
	renderer_init(opts)!!;
	uint validation_errors = vk_validation_error_count;

	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	test::@check(adapters.len() >= 1);

	sz selected = default_select_adapter(adapters.array_view());

	Device dev = device_init(&adapters[selected])!!;

	// Timeline tests
	Timeline tl = timeline_init(&dev)!!;

	test::eq(timeline_completed(&tl, &dev)!!, 0ul);
	test::eq(timeline_next(&tl), 1ul);
	test::eq(timeline_pending(&tl), 1ul);
	timeline_wait(&tl, &dev, 0)!!;

	timeline_deinit(&tl, &dev);

	// Fence signaled tests
	Fence fence_sig = fence_init(&dev, true)!!;
	test::@check(fence_status(&fence_sig, &dev)!! == FenceStatus.COMPLETE);

	Fence*[1] fences = { &fence_sig };
	fence_wait(&dev, &fences)!!;

	fence_deinit(&fence_sig, &dev);

	// Fence unsignaled tests
	Fence fence_unsig = fence_init(&dev, false)!!;
	test::@check(fence_status(&fence_unsig, &dev)!! == FenceStatus.INCOMPLETE);

	fence_deinit(&fence_unsig, &dev);

	// Semaphore tests
	Semaphore sem = semaphore_init(&dev)!!;
	semaphore_deinit(&sem, &dev);

	device_deinit(&dev);
	adapters.free();
	test::eq(vk_validation_error_count, validation_errors);
	renderer_deinit();
}

// Odin records an empty `cmd_begin`/`cmd_end` command buffer per submit; the
// cmd port has not landed, so both submits carry zero command buffers. The
// timeline wait/signal chain is the same.
fn void queue_submit_timeline_chain_vk() @test
{
	RendererOptions opts = { .backend = VK, .vk = { .app_name = "rhi-test", .enable_validation_layer = true } };
	renderer_init(opts)!!;
	uint validation_errors = vk_validation_error_count;

	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	test::@check(adapters.len() >= 1);

	sz selected = default_select_adapter(adapters.array_view());

	Device dev = device_init(&adapters[selected])!!;

	Timeline tl = timeline_init(&dev)!!;

	ulong v1 = timeline_next(&tl);
	TimelineOp[1] signals_a = { { .timeline = &tl, .value = v1, .stages = { .compute = true } } };
	queue_submit(&dev.graphics_queue, &dev, { .signals = &signals_a })!!;

	ulong v2 = timeline_next(&tl);
	TimelineOp[1] waits_b = { { .timeline = &tl, .value = v1, .stages = { .compute = true } } };
	TimelineOp[1] signals_b = { { .timeline = &tl, .value = v2 } };
	queue_submit(&dev.graphics_queue, &dev, { .waits = &waits_b, .signals = &signals_b })!!;

	timeline_wait(&tl, &dev, v2)!!;

	test::@check(timeline_completed(&tl, &dev)!! >= v2);

	queue_wait_idle(&dev.graphics_queue, &dev)!!;

	timeline_deinit(&tl, &dev);
	device_deinit(&dev);
	adapters.free();
	test::eq(vk_validation_error_count, validation_errors);
	renderer_deinit();
}

// ---- device (was vulkan_device_test.odin) ----
// Validation is enabled here too (Odin leaves it off), so vkCreateDevice and
// the feature chains are checked through `vk_validation_error_count`.

fn void device_init_deinit_vk() @test
{
	RendererOptions opts = { .backend = VK, .vk = { .app_name = "rhi-test", .enable_validation_layer = true } };
	renderer_init(opts)!!;
	uint validation_errors = vk_validation_error_count;

	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	test::@check(adapters.len() >= 1);

	sz selected = default_select_adapter(adapters.array_view());
	String adapter_name = physical_adapter_name(&adapters[selected]);

	Device dev = device_init(&adapters[selected])!!;
	test::@check(dev.graphics_queue.backend.vk.queue != null);

	queue_wait_idle(&dev.graphics_queue, &dev)!!;

	int compute_family = dev.has_compute_queue ? (int)dev.compute_queue.backend.vk.family_index : -1;
	int transfer_family = dev.has_transfer_queue ? (int)dev.transfer_queue.backend.vk.family_index : -1;
	log::info("device on adapter \"%s\": graphics family=%d compute family=%d transfer family=%d",
		adapter_name, dev.graphics_queue.backend.vk.family_index, compute_family, transfer_family);

	if (adapter_name.contains("RADV")) test::@check(dev.has_compute_queue);

	device_deinit(&dev);
	adapters.free();
	test::eq(vk_validation_error_count, validation_errors);
	renderer_deinit();
}

// ---- physical_adapter (was vulkan_physical_adapter_test.odin) ----
// Odin's `test_enumerate_adapters_vk`; without the prefix it would clash with
// enumerate_adapters_vk itself, which lives in the same module.

fn void enumerate_adapters_vk_test() @test
{
	RendererOptions opts = { .backend = VK, .vk = { .app_name = "rhi-test", .enable_validation_layer = true } };
	renderer_init(opts)!!;
	uint validation_errors = vk_validation_error_count;

	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	test::@check(adapters.len() >= 1);

	for (sz i = 0; i < adapters.len(); i++)
	{
		test::@check(physical_adapter_name(&adapters[i]).len > 0);
		test::@check(adapters[i].backend.vk.physical_device != null);
		log::info("adapter %d: %s type=%s", i, physical_adapter_name(&adapters[i]), adapters[i].adapter_type);
	}

	sz selected = default_select_adapter(adapters.array_view());
	test::@check(selected >= 0 && selected < adapters.len());

	adapters.free();
	test::eq(vk_validation_error_count, validation_errors);
	renderer_deinit();
}

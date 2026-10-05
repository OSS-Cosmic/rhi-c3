// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan command tests ported from rhi/vulkan_test.odin.  The command
// back-end is intentionally not hidden behind a feature probe here: these
// tests are the probe, and pending command implementations fail with the
// backend's normal UNSUPPORTED_FEATURE result until their ticket lands.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::core::test;
import std::collections::list;
import vk;

const char[*] VK_CMD_FULLSCREEN_VERT_SPV @align(4) = $embed("../../../rhi/testdata/fullscreen.vert.spv");
const char[*] VK_CMD_MANDELBROT_FRAG_SPV @align(4) = $embed("../../../rhi/testdata/mandelbrot.frag.spv");

macro @with_vk_cmd_device(;@body(Device* device))
{
	renderer_init({ .backend = VK, .vk = { .app_name = "rhi-command-test" } })!!;
	defer renderer_deinit();
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	test::@check(adapters.len() >= 1);
	Device device = device_init(&adapters[default_select_adapter(adapters.array_view())])!!;
	defer device_deinit(&device);
	@body(&device);
}

// Keep the Odin assertions on the production Vulkan conversion helpers.  They
// are private implementation helpers, but tests share the rhi module and can
// exercise them without changing the public API.

fn void vk_barrier_undefined_layout() @test
{
	test::eq(vk_resource_state_to_image_layout({}), vk::ImageLayout.UNDEFINED);
	test::eq(vk_resource_state_to_image_layout_aspect({}, STENCIL), vk::ImageLayout.UNDEFINED);
}

fn void vk_barrier_storage_mixed_is_general() @test
{
	ResourceState state = { .storage_read = true, .shader_resource = true };
	test::eq(vk_resource_state_to_image_layout(state), vk::ImageLayout.GENERAL);
}

fn void vk_barrier_stencil_aspect_layout() @test
{
	test::eq(vk_resource_state_to_image_layout_aspect({ .depth_write = true }, STENCIL), vk::ImageLayout.STENCIL_ATTACHMENT_OPTIMAL);
	test::eq(vk_resource_state_to_image_layout_aspect({ .depth_read = true }, STENCIL), vk::ImageLayout.STENCIL_READ_ONLY_OPTIMAL);
	test::eq(vk_resource_state_to_image_layout_aspect({ .depth_write = true }, DEPTH_STENCIL), vk::ImageLayout.DEPTH_STENCIL_ATTACHMENT_OPTIMAL);
	test::eq(vk_resource_state_to_image_layout_aspect({ .depth_write = true }, DEPTH), vk::ImageLayout.DEPTH_ATTACHMENT_OPTIMAL);
}

fn void vk_barrier_hint_keeps_attachment_stage() @test
{
	VkStageMaskResult stages = vk_stage_bits_to_vk({ .fragment = true }, { .render_target = true }, {});
	test::@check(stages.ok);
	test::@check((stages.mask & vk::PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT) != 0);
	test::@check((stages.mask & vk::PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT) != 0);
}

fn void vk_barrier_ray_tracing_hint_without_caps_invalid() @test
{
	VkStageMaskResult stages = vk_stage_bits_to_vk({ .ray_tracing = true }, {}, {});
	test::@check(!stages.ok);
	stages = vk_stage_bits_to_vk({ .ray_tracing = true }, {}, { .ray_tracing_pipeline_enabled = true });
	test::@check(stages.ok);
	test::@check((stages.mask & vk::PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR) != 0);
}

fn void vk_barrier_accel_build_input_access() @test
{
	test::@check((vk_resource_state_to_access({ .accel_build_input = true }) & vk::ACCESS_2_ACCELERATION_STRUCTURE_READ_BIT_KHR) != 0);
}

fn void vk_barrier_derived_stages_gate_ray_tracing() @test
{
	VkStageMaskResult stages = vk_stage_mask_from_state({ .shader_resource = true }, {});
	test::@check(stages.ok);
	test::@check((stages.mask & vk::PIPELINE_STAGE_2_COMPUTE_SHADER_BIT) != 0);
	test::@check((stages.mask & vk::PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR) == 0);
	stages = vk_stage_mask_from_state({ .accel_read = true }, {});
	test::@check(!stages.ok);
}

fn void queue_submit_vk_test() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		vk::CommandPool pool;
		vk::CommandPoolCreateInfo pool_info = { .sType = vk::StructureType.COMMAND_POOL_CREATE_INFO, .queueFamilyIndex = device.graphics_queue.backend.vk.family_index };
		vk_check(device.backend.vk.vtable.createCommandPool(device.backend.vk.device, &pool_info, null, &pool))!!;
		defer device.backend.vk.vtable.destroyCommandPool(device.backend.vk.device, pool, null);
		vk::CommandBuffer cmd_buffer;
		vk::CommandBufferAllocateInfo alloc_info = { .sType = vk::StructureType.COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = pool, .level = vk::CommandBufferLevel.PRIMARY, .commandBufferCount = 1 };
		vk_check(device.backend.vk.vtable.allocateCommandBuffers(device.backend.vk.device, &alloc_info, &cmd_buffer))!!;
		defer device.backend.vk.vtable.freeCommandBuffers(device.backend.vk.device, pool, 1, &cmd_buffer);
		vk::CommandBufferBeginInfo begin_info = { .sType = vk::StructureType.COMMAND_BUFFER_BEGIN_INFO };
		vk_check(device.backend.vk.vtable.beginCommandBuffer(cmd_buffer, &begin_info))!!;
		vk_check(device.backend.vk.vtable.endCommandBuffer(cmd_buffer))!!;
		Cmd cmd = { .backend.vk = { .cmd = cmd_buffer } };
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void cmd_pool_record_submit_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		Buffer buffer = buffer_init_general(device, { .size = 256, .usage = { .transfer_dst = true, .vertex_buffer = true }, .buffer_usage = PREFER_DEVICE })!!;
		defer buffer_deinit(&buffer, device);
		cmd_begin(&cmd, device)!!;
		cmd_buffer_barrier(&cmd, device, { .buffer = &buffer, .before = { .copy_dst = true }, .after = { .vertex_buffer = true }, .size = 256 });
		cmd_memory_barrier(&cmd, device, { .before = { .copy_dst = true }, .after = { .shader_resource = true } });
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		pool_reset(&pool, device)!!;
		cmd_begin(&cmd, device)!!;
		cmd_end(&cmd, device)!!;
		cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void command_ring_buffer_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		CommandRingBuffer{2, 1, true} ring = command_ring_buffer_init{2, 1, true}(device, &device.graphics_queue)!!;
		defer command_ring_buffer_deinit{2, 1, true}(&ring, device);
		CommandRingElement element = command_ring_buffer_get{2, 1, true}(&ring, device, 1);
		command_ring_element_wait(&element, device)!!;
		if (element.cmds.len == 1)
		{
			pool_reset(element.pool, device)!!;
			cmd_begin(&element.cmds[0], device)!!;
			cmd_end(&element.cmds[0], device)!!;
			Cmd*[1] cmds = { &element.cmds[0] };
			queue_submit(&device.graphics_queue, device, { .cmds = cmds[..], .completion = &element })!!;
			command_ring_element_wait(&element, device)!!;
		}
		ring.advance();
		element = command_ring_buffer_get{2, 1, true}(&ring, device, 1);
		test::@check(element.cmds.len == 1);
	};
}

fn Shader? vk_cmd_shader(Device* device)
{
	return shader_init_graphics(device, {
		.vertex_stage = { .data = VK_CMD_FULLSCREEN_VERT_SPV[..], .entry_point = "main" },
		.has_vertex_stage = true,
		.fragment_stage = { .data = VK_CMD_MANDELBROT_FRAG_SPV[..], .entry_point = "main" },
		.has_fragment_stage = true,
	});
}

fn Pipeline? vk_cmd_pipeline(Device* device, Shader* shader, uint push_constant_size = 0)
{
	return pipeline_init_graphics(device, {
		.shader = shader,
		.colors = { { .format = RGBA8_UNORM } },
		.push_constant_size = push_constant_size,
	});
}

fn void cmd_bind_pipeline_push_constants_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Shader shader = shader_init_graphics(device, { .vertex_stage = { .data = VK_CMD_FULLSCREEN_VERT_SPV[..], .entry_point = "main" }, .has_vertex_stage = true, .fragment_stage = { .data = VK_CMD_MANDELBROT_FRAG_SPV[..], .entry_point = "main" }, .has_fragment_stage = true })!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = vk_cmd_pipeline(device, &shader, 16)!!;
		defer pipeline_deinit(&pipeline, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_bind_pipeline(&cmd, device, &pipeline);
		char[16] constants = {};
		cmd_set_push_constants(&cmd, device, &pipeline, constants[..]);
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void cmd_copy_buffer_vk_test() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Buffer src = buffer_init_general(device, { .size = 256, .persistent_map = true, .sequential_access = true, .usage = { .transfer_src = true }, .buffer_usage = PREFER_HOST })!!;
		defer buffer_deinit(&src, device);
		Buffer dst = buffer_init_general(device, { .size = 256, .persistent_map = true, .usage = { .transfer_dst = true }, .buffer_usage = READBACK })!!;
		defer buffer_deinit(&dst, device);
		for (sz i = 0; i < 128; i++) src.mapped_region[i] = (char)(i ^ 0x5a);
		buffer_flush(&src, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_copy_buffer(&cmd, device, &src, 0, &dst, 64, 128);
		cmd_buffer_barrier(&cmd, device, { .buffer = &dst, .before = { .copy_dst = true }, .after = { .host_read = true }, .offset = 64, .size = 128 });
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		for (sz i = 0; i < 128; i++) test::eq(dst.mapped_region[64 + i], (char)(i ^ 0x5a));
	};
}

fn void cmd_draw_indirect_vk_test() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Image image = image_init(device, { .image_type = D2, .format = RGBA8_UNORM, .width = 64, .height = 64, .depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1, .tiling = OPTIMAL, .usage = { .color_attachment = true }, .memory_usage = PREFER_DEVICE })!!;
		defer image_deinit(&image, device);
		ImageView view = image_view_init(device, &image, { .view_type = COLOR_ATTACHMENT, .format = RGBA8_UNORM, .aspect = COLOR, .mip_num = 1, .layer_num = 1 })!!;
		defer image_view_deinit(&view, device);
		Shader shader = vk_cmd_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = vk_cmd_pipeline(device, &shader)!!;
		defer pipeline_deinit(&pipeline, device);
		Buffer args = buffer_init_general(device, { .size = 32, .persistent_map = true, .usage = { .transfer_dst = true, .indirect = true }, .buffer_usage = PREFER_HOST })!!;
		defer buffer_deinit(&args, device);
		char[32] draw_records = { 3, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
		buffer_write(&args, device, 0, draw_records[..]);
		buffer_flush(&args, device);
		Buffer vertex_buffer = buffer_init_general(device, { .size = 64, .usage = { .vertex_buffer = true }, .buffer_usage = PREFER_DEVICE })!!;
		defer buffer_deinit(&vertex_buffer, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, { .image = &image, .after = { .render_target = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
		cmd_buffer_barrier(&cmd, device, { .buffer = &args, .after = { .indirect_argument = true }, .size = 32 });
		cmd_begin_rendering(&cmd, device, { .color_attachments = { { .view = view, .load_op = CLEAR, .store_op = STORE, .clear_color = { 0, 0, 0, 1 } } }, .render_area = { .width = 64, .height = 64 } });
		cmd_bind_pipeline(&cmd, device, &pipeline);
		cmd_set_viewport(&cmd, device, { .width = 64, .height = -64, .min_depth = 0, .max_depth = 1 });
		cmd_set_scissor(&cmd, device, { .width = 64, .height = 64 });
		Buffer*[4] vertex_buffers = { &vertex_buffer, null, &vertex_buffer, &vertex_buffer };
		ulong[4] vertex_offsets = { 0, 0, 16, 32 };
		cmd_bind_vertex_buffers(&cmd, device, 0, vertex_buffers[..], vertex_offsets[..]);
		cmd_draw_indirect(&cmd, device, &args, 0, 2, 16);
		cmd_end_rendering(&cmd, device);
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void cmd_clear_depth_stencil_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Image image = image_init(device, { .image_type = D2, .format = D32_SFLOAT_S8_UINT, .width = 64, .height = 64, .depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1, .tiling = OPTIMAL, .usage = { .depth_stencil_attachment = true }, .memory_usage = PREFER_DEVICE })!!;
		defer image_deinit(&image, device);
		ImageView view = image_view_init(device, &image, { .view_type = DEPTH_STENCIL_ATTACHMENT, .format = D32_SFLOAT_S8_UINT, .aspect = DEPTH_STENCIL, .mip_num = 1, .layer_num = 1 })!!;
		defer image_view_deinit(&view, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, { .image = &image, .after = { .depth_write = true }, .aspect = DEPTH, .mip_count = 1, .layer_count = 1 });
		cmd_image_barrier(&cmd, device, { .image = &image, .after = { .depth_write = true }, .aspect = STENCIL, .mip_count = 1, .layer_count = 1 });
		cmd_begin_rendering(&cmd, device, { .render_area = { .width = 64, .height = 64 }, .depth_attachment = { .view = view, .load_op = CLEAR, .store_op = STORE, .clear_depth = 1, .has_stencil = true, .stencil_load_op = CLEAR, .stencil_store_op = STORE, .clear_stencil = 0x80 }, .has_depth_attachment = true });
		cmd_end_rendering(&cmd, device);
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void cmd_clear_render_target_readback_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Image image = image_init(device, { .image_type = D2, .format = RGBA8_UNORM, .width = 64, .height = 64, .depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1, .tiling = OPTIMAL, .usage = { .color_attachment = true, .transfer_src = true }, .memory_usage = PREFER_DEVICE })!!;
		defer image_deinit(&image, device);
		ImageView view = image_view_init(device, &image, { .view_type = COLOR_ATTACHMENT, .format = RGBA8_UNORM, .aspect = COLOR, .mip_num = 1, .layer_num = 1 })!!;
		defer image_view_deinit(&view, device);
		Buffer readback = buffer_init_general(device, { .size = 256 * 64, .usage = { .transfer_dst = true }, .buffer_usage = READBACK })!!;
		defer buffer_deinit(&readback, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, { .image = &image, .after = { .render_target = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
		cmd_begin_rendering(&cmd, device, { .color_attachments = { { .view = view, .load_op = CLEAR, .store_op = STORE, .clear_color = { 0.2, 0.6, 1, 1 } } }, .render_area = { .width = 64, .height = 64 } });
		cmd_end_rendering(&cmd, device);
		cmd_image_barrier(&cmd, device, { .image = &image, .before = { .render_target = true }, .after = { .copy_src = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
		cmd_copy_texture_to_buffer(&cmd, device, { .src = &image, .dst = &readback, .buffer_offset = 0, .bytes_per_row = 256, .width = 64, .height = 64, .depth = 1, .aspect = COLOR, .layer_count = 1 });
		cmd_buffer_barrier(&cmd, device, { .buffer = &readback, .before = { .copy_dst = true }, .after = { .host_read = true }, .size = 256 * 64 });
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		for (uint y = 0; y < 64; y++)
		{
			for (uint x = 0; x < 64; x++)
			{
				test::eq(readback.mapped_region[y * 256 + x * 4 + 0], (char)51);
				test::eq(readback.mapped_region[y * 256 + x * 4 + 1], (char)153);
				test::eq(readback.mapped_region[y * 256 + x * 4 + 2], (char)255);
				test::eq(readback.mapped_region[y * 256 + x * 4 + 3], (char)255);
			}
		}
	};
}

fn void cmd_begin_end_rendering_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		Image image = image_init(device, { .image_type = D2, .format = RGBA8_UNORM, .width = 64, .height = 64, .depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1, .tiling = OPTIMAL, .usage = { .color_attachment = true }, .memory_usage = PREFER_DEVICE })!!;
		defer image_deinit(&image, device);
		ImageView view = image_view_init(device, &image, { .view_type = COLOR_ATTACHMENT, .format = RGBA8_UNORM, .aspect = COLOR, .mip_num = 1, .layer_num = 1 })!!;
		defer image_view_deinit(&view, device);
		Shader shader = vk_cmd_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = vk_cmd_pipeline(device, &shader)!!;
		defer pipeline_deinit(&pipeline, device);
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, { .image = &image, .after = { .render_target = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
		cmd_begin_rendering(&cmd, device, { .color_attachments = { { .view = view, .load_op = CLEAR, .store_op = STORE, .clear_color = { 0, 0, 0, 1 } } }, .render_area = { .width = 64, .height = 64 } });
		cmd_bind_pipeline(&cmd, device, &pipeline);
		cmd_set_viewport(&cmd, device, { .width = 64, .height = -64, .min_depth = 0, .max_depth = 1 });
		cmd_set_scissor(&cmd, device, { .width = 64, .height = 64 });
		cmd_draw(&cmd, device, 3);
		cmd_end_rendering(&cmd, device);
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void queue_submit_ring_completion_vk() @test
{
	@with_vk_cmd_device(; Device* device)
	{
		CommandRingBuffer{2, 1, true} ring = command_ring_buffer_init{2, 1, true}(device, &device.graphics_queue)!!;
		defer command_ring_buffer_deinit{2, 1, true}(&ring, device);
		for (uint i = 0; i < 4; i++)
		{
			ring.advance();
			CommandRingElement element = command_ring_buffer_get{2, 1, true}(&ring, device, 1);
			if (element.cmds.len == 0) continue;
			command_ring_element_wait(&element, device)!!;
			pool_reset(element.pool, device)!!;
			Cmd* cmd = &element.cmds[0];
			cmd_begin(cmd, device)!!;
			cmd_end(cmd, device)!!;
			Cmd*[1] cmds = { cmd };
			queue_submit(&device.graphics_queue, device, { .cmds = cmds[..], .completion = &element })!!;
			command_ring_element_wait(&element, device)!!;
		}
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

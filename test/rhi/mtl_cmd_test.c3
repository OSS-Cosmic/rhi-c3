// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal command recording and submission tests.  The command/pool/ring
// implementation is intentionally kept behind the public RHI entry points so
// these tests also exercise the resource-state and attachment descriptions
// that callers use.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::core::test;

fn void mtl_cmd_check_rgba8(char[] bytes, char r, char g, char b, char a)
{
	test::eq(bytes[0], r);
	test::eq(bytes[1], g);
	test::eq(bytes[2], b);
	test::eq(bytes[3], a);
}

fn Shader? mtl_cmd_test_shader(Device* device)
{
	return shader_init_graphics(device, {
		.vertex_stage = {
			.data = $embed("testdata/sanity_color.vert.metal"),
			.entry_point = "vertexMain",
		},
		.has_vertex_stage = true,
		.fragment_stage = {
			.data = $embed("testdata/sanity_color.frag.metal"),
			.entry_point = "fragmentMain",
		},
		.has_fragment_stage = true,
	});
}

fn void mtl_cmd_pool_record_submit() @test
{
	@with_mtl_device(; Device* device)
	{
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);

		cmd_begin(&cmd, device)!!;
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void mtl_cmd_ring_allocates_and_advances() @test
{
	@with_mtl_device(; Device* device)
	{
		CommandRingBuffer{2, 2, true} ring = command_ring_buffer_init{2, 2, true}(
			device, &device.graphics_queue)!!;
		defer command_ring_buffer_deinit{2, 2, true}(&ring, device);

		CommandRingElement first = command_ring_buffer_get{2, 2, true}(&ring, device, 1);
		test::@check(first.pool != null);
		test::eq((uint)first.cmds.len, 1u);
		test::eq(ring.pool_index, (sz)0);
		test::eq(ring.cmd_index, (sz)1);

		ring.advance();
		CommandRingElement second = command_ring_buffer_get{2, 2, true}(&ring, device, 2);
		test::@check(second.pool != null);
		test::eq((uint)second.cmds.len, 2u);
		test::eq(ring.pool_index, (sz)1);
		test::eq(ring.cmd_index, (sz)2);
	};
}

fn void mtl_cmd_shared_buffer_copy_round_trip() @test
{
	@with_mtl_device(; Device* device)
	{
		Buffer src = buffer_init_general(device, {
			.size = 16,
			.stride = 4,
			.usage = { .transfer_src = true },
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&src, device);
		Buffer dst = buffer_init_general(device, {
			.size = 16,
			.stride = 4,
			.usage = { .transfer_dst = true },
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&dst, device);

		char[16] input = { 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
			0x90, 0xA0, 0xB0, 0xC0, 0xD0, 0xE0, 0xF0, 0x01 };
		buffer_write(&src, device, 0, input[..]);

		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &src,
			.after = { .copy_src = true },
			.after_stages = { .copy = true },
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &dst,
			.after = { .copy_dst = true },
			.after_stages = { .copy = true },
		});
		cmd_copy_buffer(&cmd, device, &src, 0, &dst, 0, 16);
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &dst,
			.before = { .copy_dst = true },
			.after = { .host_read = true },
			.after_stages = { .host = true },
		});
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;

		for (sz i = 0; i < 16; i++) test::eq(dst.mapped_region[i], input[i]);
	};
}

fn void mtl_cmd_render_target_clear_to_buffer() @test
{
	@with_mtl_device(; Device* device)
	{
		Image target = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .transfer_src = true, .color_attachment = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&target, device);
		ImageView target_view = image_view_init(device, &target, {
			.view_type = COLOR_ATTACHMENT,
			.format = RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&target_view, device);
		Buffer readback = buffer_init_general(device, {
			.size = 64,
			.stride = 4,
			.usage = { .transfer_dst = true },
			.buffer_usage = READBACK,
		})!!;
		defer buffer_deinit(&readback, device);

		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .render_target = true },
			.after_stages = { .color_attachment = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_begin_rendering(&cmd, device, {
			.color_attachments = { {
				.view = target_view,
				.load_op = CLEAR,
				.store_op = STORE,
				.clear_color = { 1, 0, 0, 1 },
			} },
			.render_area = { .width = 4, .height = 4 },
		});
		cmd_end_rendering(&cmd, device);
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .copy_src = true },
			.after_stages = { .copy = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &readback,
			.after = { .copy_dst = true },
			.after_stages = { .copy = true },
		});
		cmd_copy_texture_to_buffer(&cmd, device, {
			.src = &target,
			.dst = &readback,
			.bytes_per_row = 16,
			.bytes_per_image = 64,
			.layer_count = 1,
			.aspect = COLOR,
			.width = 4,
			.height = 4,
			.depth = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &readback,
			.before = { .copy_dst = true },
			.after = { .host_read = true },
			.after_stages = { .host = true },
		});
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		mtl_cmd_check_rgba8(readback.mapped_region, (char)255, (char)0, (char)0, (char)255);
		mtl_cmd_check_rgba8(readback.mapped_region[60..], (char)255, (char)0, (char)0, (char)255);
	};
}

fn void mtl_cmd_depth_attachment_begin_end() @test
{
	@with_mtl_device(; Device* device)
	{
		Image depth = image_init(device, {
			.image_type = D2,
			.format = D32_SFLOAT,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .depth_stencil_attachment = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&depth, device);
		ImageView depth_view = image_view_init(device, &depth, {
			.view_type = DEPTH_STENCIL_ATTACHMENT,
			.format = D32_SFLOAT,
			.aspect = DEPTH,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&depth_view, device);

		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, {
			.image = &depth,
			.after = { .depth_write = true },
			.aspect = DEPTH,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_begin_rendering(&cmd, device, {
			.render_area = { .width = 4, .height = 4 },
			.depth_attachment = {
				.view = depth_view,
				.load_op = CLEAR,
				.store_op = STORE,
				.clear_depth = 1,
			},
			.has_depth_attachment = true,
		});
		cmd_end_rendering(&cmd, device);
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
	};
}

fn void mtl_cmd_sanity_color_push_constant_draw() @test
{
	@with_mtl_device(; Device* device)
	{
		Shader shader = mtl_cmd_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { { .format = RGBA8_UNORM } },
			.push_constant_size = 16,
		})!!;
		defer pipeline_deinit(&pipeline, device);
		Image target = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .transfer_src = true, .color_attachment = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&target, device);
		ImageView target_view = image_view_init(device, &target, {
			.view_type = COLOR_ATTACHMENT,
			.format = RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&target_view, device);
		Buffer readback = buffer_init_general(device, {
			.size = 64,
			.stride = 4,
			.usage = { .transfer_dst = true },
			.buffer_usage = READBACK,
		})!!;
		defer buffer_deinit(&readback, device);

		// float4(0, 1, 0, 1), as used by the MSL push constant struct.
		char[16] green = { 0, 0, 0, 0, 0, 0, 128, 63, 0, 0, 0, 0, 0, 0, 128, 63 };
		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .render_target = true },
			.after_stages = { .color_attachment = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_begin_rendering(&cmd, device, {
			.color_attachments = { {
				.view = target_view,
				.load_op = CLEAR,
				.store_op = STORE,
				.clear_color = { 0, 0, 0, 1 },
			} },
			.render_area = { .width = 4, .height = 4 },
		});
		cmd_set_viewport(&cmd, device, { .width = 4, .height = -4, .max_depth = 1 });
		cmd_bind_pipeline(&cmd, device, &pipeline);
		cmd_set_push_constants(&cmd, device, &pipeline, green[..]);
		cmd_draw(&cmd, device, 3);
		cmd_end_rendering(&cmd, device);
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .copy_src = true },
			.after_stages = { .copy = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_copy_texture_to_buffer(&cmd, device, {
			.src = &target,
			.dst = &readback,
			.bytes_per_row = 16,
			.bytes_per_image = 64,
			.layer_count = 1,
			.aspect = COLOR,
			.width = 4,
			.height = 4,
			.depth = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &readback,
			.before = { .copy_dst = true },
			.after = { .host_read = true },
			.after_stages = { .host = true },
		});
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		mtl_cmd_check_rgba8(readback.mapped_region, (char)0, (char)255, (char)0, (char)255);
	};
}

fn void mtl_cmd_indirect_draw() @test
{
	@with_mtl_device(; Device* device)
	{
		Shader shader = mtl_cmd_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { { .format = RGBA8_UNORM } },
			.push_constant_size = 16,
		})!!;
		defer pipeline_deinit(&pipeline, device);
		Image target = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .transfer_src = true, .color_attachment = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&target, device);
		ImageView target_view = image_view_init(device, &target, {
			.view_type = COLOR_ATTACHMENT,
			.format = RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&target_view, device);
		Buffer readback = buffer_init_general(device, {
			.size = 64,
			.stride = 4,
			.usage = { .transfer_dst = true },
			.buffer_usage = READBACK,
		})!!;
		defer buffer_deinit(&readback, device);
		Buffer indirect = buffer_init_general(device, {
			.size = 16,
			.stride = 16,
			.usage = { .indirect = true },
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&indirect, device);
		uint[4] draw_args = { 3, 1, 0, 0 };
		buffer_write(&indirect, device, 0, ((char*)&draw_args[0])[:16]);
		// float4(0, 0, 1, 1), as used by the MSL push constant struct.
		char[16] blue = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 63, 0, 0, 128, 63 };

		Pool pool = pool_init(device, &device.graphics_queue)!!;
		defer pool_deinit(&pool, device);
		Cmd cmd = cmd_init(device, &pool)!!;
		defer cmd_deinit(&cmd, device, &pool);
		cmd_begin(&cmd, device)!!;
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .render_target = true },
			.after_stages = { .color_attachment = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &indirect,
			.after = { .indirect_argument = true },
			.after_stages = { .draw_indirect = true },
		});
		cmd_begin_rendering(&cmd, device, {
			.color_attachments = { {
				.view = target_view,
				.load_op = CLEAR,
				.store_op = STORE,
				.clear_color = { 0, 0, 0, 1 },
			} },
			.render_area = { .width = 4, .height = 4 },
		});
		cmd_set_viewport(&cmd, device, { .width = 4, .height = -4, .max_depth = 1 });
		cmd_bind_pipeline(&cmd, device, &pipeline);
		cmd_set_push_constants(&cmd, device, &pipeline, blue[..]);
		cmd_draw_indirect(&cmd, device, &indirect, 0, 1, 16);
		cmd_end_rendering(&cmd, device);
		cmd_image_barrier(&cmd, device, {
			.image = &target,
			.after = { .copy_src = true },
			.after_stages = { .copy = true },
			.aspect = COLOR,
			.mip_count = 1,
			.layer_count = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &readback,
			.after = { .copy_dst = true },
			.after_stages = { .copy = true },
		});
		cmd_copy_texture_to_buffer(&cmd, device, {
			.src = &target,
			.dst = &readback,
			.bytes_per_row = 16,
			.bytes_per_image = 64,
			.layer_count = 1,
			.aspect = COLOR,
			.width = 4,
			.height = 4,
			.depth = 1,
		});
		cmd_buffer_barrier(&cmd, device, {
			.buffer = &readback,
			.before = { .copy_dst = true },
			.after = { .host_read = true },
			.after_stages = { .host = true },
		});
		cmd_end(&cmd, device)!!;
		Cmd*[1] cmds = { &cmd };
		queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
		queue_wait_idle(&device.graphics_queue, device)!!;
		mtl_cmd_check_rgba8(readback.mapped_region, (char)0, (char)0, (char)255, (char)255);
	};
}

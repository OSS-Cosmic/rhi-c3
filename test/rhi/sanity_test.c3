// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-parameterized GPU sanity suite ported from rhi/sanity_test.odin.
// This C3 target currently enables only Vulkan; keeping Backend in the
// environment and runner preserves the generic harness shape for later
// backends without creating un-gated tests for them.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::core::test;
import std::collections::list;
import std::atomic;
import vk;

const char[*] SANITY_COLOR_VERT_SPV @align(4) = $embed("../../../rhi/testdata/sanity_color.vert.spv");
const char[*] SANITY_COLOR_FRAG_SPV @align(4) = $embed("../../../rhi/testdata/sanity_color.frag.spv");

const uint SANITY_WIDTH = 64;
const uint SANITY_HEIGHT = 64;
const uint SANITY_ROW_PITCH = 256;

struct SanityEnv
{
	Backend backend;
	List{PhysicalAdapter} adapters;
	Device dev;
	bool has_dev;
	uint errors;
	vk::DebugUtilsMessengerEXT messenger;
}

alias SanityCheck = fn void(SanityEnv* env);

fn vk::Bool32 sanity_messenger_callback(
	vk::DebugUtilsMessageSeverityFlagBitsEXT message_severity,
	vk::DebugUtilsMessageTypeFlagsEXT message_types,
	vk::DebugUtilsMessengerCallbackDataEXT* callback_data,
	void* user_data)
{
	SanityEnv* env = (SanityEnv*)user_data;
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) atomic::fetch_add(&env.errors, 1u);
	return vk::FALSE;
}

fn void sanity_env_init(SanityEnv* env, Backend backend)
{
	*env = { .backend = backend };
	switch (backend)
	{
		case VK:
			renderer_init({ .backend = VK, .vk = { .app_name = "rhi-sanity", .enable_validation_layer = true } })!!;
			if (vk::createDebugUtilsMessengerEXT)
			{
				vk::DebugUtilsMessengerCreateInfoEXT info = {
					.sType = vk::StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
					.pfnUserCallback = &sanity_messenger_callback,
					.pUserData = env,
					.messageSeverity = vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
					.messageType = vk::DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
				};
				vk_check(vk::createDebugUtilsMessengerEXT(renderer.vk.instance, &info, null, &env.messenger))!!;
			}
		default:
			abort("sanity suite backend is not compiled");
	}
	env.adapters = enumerate_adapters()!!;
	test::@check(env.adapters.len() >= 1);
	env.dev = device_init(&env.adapters[default_select_adapter(env.adapters.array_view())])!!;
	env.has_dev = true;
}

fn void sanity_env_deinit(SanityEnv* env)
{
	if (env.has_dev)
	{
		device_deinit(&env.dev);
		env.has_dev = false;
	}
	env.adapters.free();
	if (env.messenger != 0 && vk::destroyDebugUtilsMessengerEXT)
	{
		vk::destroyDebugUtilsMessengerEXT(renderer.vk.instance, env.messenger, null);
		env.messenger = 0;
	}
	renderer_deinit();
}

fn void sanity_expect_no_validation_errors(SanityEnv* env)
{
	test::eq(env.errors, 0u);
}

fn Shader? sanity_shader(Device* device)
{
	return shader_init_graphics(device, {
		.vertex_stage = { .data = SANITY_COLOR_VERT_SPV[..], .entry_point = "main" },
		.has_vertex_stage = true,
		.fragment_stage = { .data = SANITY_COLOR_FRAG_SPV[..], .entry_point = "main" },
		.has_fragment_stage = true,
	});
}

fn void sanity_render_and_expect(SanityEnv* env, float[4] clear_color, char[4] want, Pipeline* pipeline = null)
{
	Device* dev = &env.dev;
	Image image = image_init(dev, { .image_type = D2, .format = RGBA8_UNORM, .width = SANITY_WIDTH, .height = SANITY_HEIGHT, .depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1, .tiling = OPTIMAL, .usage = { .color_attachment = true, .transfer_src = true }, .memory_usage = PREFER_DEVICE })!!;
	defer image_deinit(&image, dev);
	ImageView view = image_view_init(dev, &image, { .view_type = COLOR_ATTACHMENT, .format = RGBA8_UNORM, .aspect = COLOR, .mip_num = 1, .layer_num = 1 })!!;
	defer image_view_deinit(&view, dev);
	Buffer readback = buffer_init_general(dev, { .size = SANITY_ROW_PITCH * SANITY_HEIGHT, .usage = { .transfer_dst = true }, .buffer_usage = READBACK })!!;
	defer buffer_deinit(&readback, dev);
	Pool pool = pool_init(dev, &dev.graphics_queue)!!;
	defer pool_deinit(&pool, dev);
	Cmd cmd = cmd_init(dev, &pool)!!;
	defer cmd_deinit(&cmd, dev, &pool);
	cmd_begin(&cmd, dev)!!;
	cmd_image_barrier(&cmd, dev, { .image = &image, .after = { .render_target = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
	cmd_begin_rendering(&cmd, dev, { .color_attachments = { { .view = view, .load_op = CLEAR, .store_op = STORE, .clear_color = clear_color } }, .render_area = { .width = SANITY_WIDTH, .height = SANITY_HEIGHT } });
	if (pipeline)
	{
		cmd_bind_pipeline(&cmd, dev, pipeline);
		cmd_set_viewport(&cmd, dev, { .width = SANITY_WIDTH, .height = SANITY_HEIGHT, .min_depth = 0, .max_depth = 1 });
		cmd_set_scissor(&cmd, dev, { .width = SANITY_WIDTH, .height = SANITY_HEIGHT });
		char[16] color = { 0, 0, (char)0x80, 0x3f, 0, 0, 0, 0, (char)0xcd, (char)0xcc, 0x4c, 0x3e, 0, 0, (char)0x80, 0x3f };
		cmd_set_push_constants(&cmd, dev, pipeline, color[..]);
		cmd_draw(&cmd, dev, 3);
	}
	cmd_end_rendering(&cmd, dev);
	cmd_image_barrier(&cmd, dev, { .image = &image, .before = { .render_target = true }, .after = { .copy_src = true }, .aspect = COLOR, .mip_count = 1, .layer_count = 1 });
	cmd_copy_texture_to_buffer(&cmd, dev, { .src = &image, .dst = &readback, .bytes_per_row = SANITY_ROW_PITCH, .width = SANITY_WIDTH, .height = SANITY_HEIGHT, .depth = 1, .layer_count = 1, .aspect = COLOR });
	cmd_buffer_barrier(&cmd, dev, { .buffer = &readback, .before = { .copy_dst = true }, .after = { .host_read = true }, .size = SANITY_ROW_PITCH * SANITY_HEIGHT });
	cmd_end(&cmd, dev)!!;
	Cmd*[1] cmds = { &cmd };
	queue_submit(&dev.graphics_queue, dev, { .cmds = cmds[..] })!!;
	queue_wait_idle(&dev.graphics_queue, dev)!!;
	test::@check(readback.mapped_region.len == (usz)(SANITY_ROW_PITCH * SANITY_HEIGHT));
	for (uint y = 0; y < SANITY_HEIGHT; y++)
	{
		for (uint x = 0; x < SANITY_WIDTH; x++)
		{
			for (uint channel = 0; channel < 4; channel++) test::eq(readback.mapped_region[y * SANITY_ROW_PITCH + x * 4 + channel], want[channel]);
		}
	}
}

fn void sanity_device(SanityEnv* env)
{
	test::@check(env.adapters.len() >= 1);
	test::@check(env.has_dev);
	queue_wait_idle(&env.dev.graphics_queue, &env.dev)!!;
	sanity_expect_no_validation_errors(env);
}

fn void sanity_buffer_host_write_read(SanityEnv* env)
{
	Buffer buffer = buffer_init_general(&env.dev, { .size = 256, .persistent_map = true, .sequential_access = true, .usage = { .transfer_src = true }, .buffer_usage = PREFER_HOST })!!;
	defer buffer_deinit(&buffer, &env.dev);
	char[256] payload;
	for (sz i = 0; i < 256; i++) payload[i] = (char)(i * 13 + 5);
	buffer_write(&buffer, &env.dev, 0, payload[..]);
	buffer_flush(&buffer, &env.dev);
	for (sz i = 0; i < 256; i++) test::eq(buffer.mapped_region[i], payload[i]);
	sanity_expect_no_validation_errors(env);
}

fn void sanity_buffer_copy_roundtrip(SanityEnv* env)
{
	Buffer upload = buffer_init_general(&env.dev, { .size = 256, .persistent_map = true, .usage = { .transfer_src = true }, .buffer_usage = PREFER_HOST })!!;
	defer buffer_deinit(&upload, &env.dev);
	Buffer gpu = buffer_init_general(&env.dev, { .size = 256, .usage = { .transfer_src = true, .transfer_dst = true }, .buffer_usage = PREFER_DEVICE })!!;
	defer buffer_deinit(&gpu, &env.dev);
	Buffer readback = buffer_init_general(&env.dev, { .size = 256, .usage = { .transfer_dst = true }, .buffer_usage = READBACK })!!;
	defer buffer_deinit(&readback, &env.dev);
	char[128] payload;
	for (sz i = 0; i < 128; i++) payload[i] = (char)(i * 7 + 3);
	buffer_write(&upload, &env.dev, 0, payload[..]);
	buffer_flush(&upload, &env.dev);
	Pool pool = pool_init(&env.dev, &env.dev.graphics_queue)!!;
	defer pool_deinit(&pool, &env.dev);
	Cmd cmd = cmd_init(&env.dev, &pool)!!;
	defer cmd_deinit(&cmd, &env.dev, &pool);
	cmd_begin(&cmd, &env.dev)!!;
	cmd_copy_buffer(&cmd, &env.dev, &upload, 0, &gpu, 64, 128);
	cmd_buffer_barrier(&cmd, &env.dev, { .buffer = &gpu, .before = { .copy_dst = true }, .after = { .copy_src = true }, .size = 256 });
	cmd_copy_buffer(&cmd, &env.dev, &gpu, 64, &readback, 0, 128);
	cmd_buffer_barrier(&cmd, &env.dev, { .buffer = &readback, .before = { .copy_dst = true }, .after = { .host_read = true }, .size = 256 });
	cmd_end(&cmd, &env.dev)!!;
	Cmd*[1] cmds = { &cmd };
	queue_submit(&env.dev.graphics_queue, &env.dev, { .cmds = cmds[..] })!!;
	queue_wait_idle(&env.dev.graphics_queue, &env.dev)!!;
	for (sz i = 0; i < 128; i++) test::eq(readback.mapped_region[i], payload[i]);
	sanity_expect_no_validation_errors(env);
}

fn void sanity_clear_readback(SanityEnv* env)
{
	sanity_render_and_expect(env, { 0.2, 0.6, 1, 1 }, { 51, 153, (char)255, (char)255 });
	sanity_expect_no_validation_errors(env);
}

fn void sanity_draw_push_constants(SanityEnv* env)
{
	Shader shader = sanity_shader(&env.dev)!!;
	defer shader_deinit(&shader, &env.dev);
	Pipeline pipeline = pipeline_init_graphics(&env.dev, { .shader = &shader, .colors = { { .format = RGBA8_UNORM } }, .push_constant_size = 16 })!!;
	defer pipeline_deinit(&pipeline, &env.dev);
	sanity_render_and_expect(env, { 0, 0, 0, 1 }, { (char)255, 0, 51, (char)255 }, &pipeline);
	sanity_expect_no_validation_errors(env);
}

fn void sanity_timeline(SanityEnv* env)
{
	Timeline timeline = timeline_init(&env.dev)!!;
	defer timeline_deinit(&timeline, &env.dev);
	Pool pool = pool_init(&env.dev, &env.dev.graphics_queue)!!;
	defer pool_deinit(&pool, &env.dev);
	Cmd cmd = cmd_init(&env.dev, &pool)!!;
	defer cmd_deinit(&cmd, &env.dev, &pool);
	for (uint i = 0; i < 2; i++)
	{
		pool_reset(&pool, &env.dev)!!;
		cmd_begin(&cmd, &env.dev)!!;
		cmd_end(&cmd, &env.dev)!!;
		ulong value = timeline_next(&timeline);
		Cmd*[1] cmds = { &cmd };
		queue_submit(&env.dev.graphics_queue, &env.dev, { .cmds = cmds[..], .signals = { { .timeline = &timeline, .value = value } } })!!;
		timeline_wait(&timeline, &env.dev, value)!!;
		test::@check(timeline_completed(&timeline, &env.dev)!! >= value);
	}
	sanity_expect_no_validation_errors(env);
}

fn void sanity_fence(SanityEnv* env)
{
	Fence signaled = fence_init(&env.dev, true)!!;
	defer fence_deinit(&signaled, &env.dev);
	test::eq(fence_status(&signaled, &env.dev)!!, FenceStatus.COMPLETE);
	Fence*[1] signaled_list = { &signaled };
	fence_wait(&env.dev, signaled_list[..])!!;
	Fence unsignaled = fence_init(&env.dev, false)!!;
	defer fence_deinit(&unsignaled, &env.dev);
	test::eq(fence_status(&unsignaled, &env.dev)!!, FenceStatus.INCOMPLETE);
	sanity_expect_no_validation_errors(env);
}

fn void sanity_command_ring(SanityEnv* env)
{
	CommandRingBuffer{2, 1, true} ring = command_ring_buffer_init{2, 1, true}(&env.dev, &env.dev.graphics_queue)!!;
	defer command_ring_buffer_deinit{2, 1, true}(&ring, &env.dev);
	CommandRingElement element = command_ring_buffer_get{2, 1, true}(&ring, &env.dev, 1);
	command_ring_element_wait(&element, &env.dev)!!;
	pool_reset(element.pool, &env.dev)!!;
	cmd_begin(&element.cmds[0], &env.dev)!!;
	cmd_end(&element.cmds[0], &env.dev)!!;
	Cmd*[1] cmds = { &element.cmds[0] };
	queue_submit(&env.dev.graphics_queue, &env.dev, { .cmds = cmds[..], .completion = &element })!!;
	command_ring_element_wait(&element, &env.dev)!!;
	ring.advance();
	CommandRingElement next = command_ring_buffer_get{2, 1, true}(&ring, &env.dev, 1);
	command_ring_element_wait(&next, &env.dev)!!;
	queue_wait_idle(&env.dev.graphics_queue, &env.dev)!!;
	sanity_expect_no_validation_errors(env);
}

fn void sanity_run(Backend backend, SanityCheck check)
{
	SanityEnv env;
	sanity_env_init(&env, backend);
	defer sanity_env_deinit(&env);
	check(&env);
	sanity_expect_no_validation_errors(&env);
}

fn void test_sanity_device_vk() @test { sanity_run(VK, &sanity_device); }
fn void test_sanity_buffer_host_write_read_vk() @test { sanity_run(VK, &sanity_buffer_host_write_read); }
fn void test_sanity_buffer_copy_roundtrip_vk() @test { sanity_run(VK, &sanity_buffer_copy_roundtrip); }
fn void test_sanity_clear_readback_vk() @test { sanity_run(VK, &sanity_clear_readback); }
fn void test_sanity_draw_push_constants_vk() @test { sanity_run(VK, &sanity_draw_push_constants); }
fn void test_sanity_timeline_vk() @test { sanity_run(VK, &sanity_timeline); }
fn void test_sanity_fence_vk() @test { sanity_run(VK, &sanity_fence); }
fn void test_sanity_command_ring_vk() @test { sanity_run(VK, &sanity_command_ring); }

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan rpi allocator and Program tests ported from the approved section of
// rhi/vulkan_test.odin.  The RPI Vulkan implementation is staged separately;
// these tests intentionally name the C3 RPI types and entry points that the
// implementation ticket supplies.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::atomic;
import std::collections::list;
import std::core::test;
import vk;

const char[*] RPI_TEST_FULLSCREEN_VERT_SPV @align(4) = $embed("../../../rhi/testdata/fullscreen.vert.spv");
const char[*] RPI_TEST_MANDELBROT_FRAG_SPV @align(4) = $embed("../../../rhi/testdata/mandelbrot.frag.spv");

fn vk::DescriptorSetLayout? rpi_test_descriptor_set_layout(Device* device)
{
	vk::DescriptorSetLayoutBinding binding = {
		.binding = 0,
		.descriptorType = vk::DescriptorType.SAMPLER,
		.descriptorCount = 1,
		.stageFlags = vk::SHADER_STAGE_FRAGMENT_BIT,
	};
	vk::DescriptorSetLayoutCreateInfo info = {
		.sType = vk::StructureType.DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		.bindingCount = 1,
		.pBindings = &binding,
	};
	vk::DescriptorSetLayout layout;
	vk_check(device.backend.vk.vtable.createDescriptorSetLayout(
		device.backend.vk.device, &info, null, &layout))!!;
	return layout;
}

macro @with_rpi_allocator_device(; @body(Device* device))
{
	renderer_init({ .backend = VK, .vk = { .app_name = "rhi-rpi-test" } })!!;
	defer renderer_deinit();
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	test::@check(adapters.len() >= 1);
	Device device = device_init(&adapters[default_select_adapter(adapters.array_view())])!!;
	defer device_deinit(&device);
	@body(&device);
}

fn void rpi_descriptor_set_alloc_resolve_vk() @test
{
	@with_rpi_allocator_device(; Device* device)
	{
		vk::DescriptorSetLayout layout = rpi_test_descriptor_set_layout(device)!!;
		defer device.backend.vk.vtable.destroyDescriptorSetLayout(device.backend.vk.device, layout, null);
		RpiDescriptorSetAlloc allocator = rpi_descriptor_set_alloc_init(layout, { .sampler = 1 }, RPI_FRAMES_IN_FLIGHT);
		defer rpi_descriptor_set_alloc_free(&allocator, device);

		bool found;
		RpiDescriptorSetSlot* set_a = rpi_descriptor_set_alloc_resolve(&allocator, device, 0, 0xA, &found)!!;
		test::@check(!found);
		test::@check(set_a != null && set_a.handle != 0);
		vk::DescriptorSet a_handle = set_a.handle;

		RpiDescriptorSetSlot* set_a2 = rpi_descriptor_set_alloc_resolve(&allocator, device, 1, 0xA, &found)!!;
		test::@check(found);
		test::@check(set_a2 == set_a);

		RpiDescriptorSetSlot* set_b = rpi_descriptor_set_alloc_resolve(&allocator, device, 1, 0xB, &found)!!;
		test::@check(!found);
		test::@check(set_b != set_a);
		test::@check(set_b.handle != a_handle);

		uint frame = 1 + RPI_FRAMES_IN_FLIGHT + 1;
		RpiDescriptorSetSlot* set_c = rpi_descriptor_set_alloc_resolve(&allocator, device, frame, 0xC, &found)!!;
		test::@check(!found);
		test::eq(set_c.handle, a_handle);

		rpi_descriptor_set_alloc_resolve(&allocator, device, frame, 0xA, &found)!!;
		test::@check(!found);
	};
}

fn void rpi_descriptor_set_alloc_grows_pools_vk() @test
{
	@with_rpi_allocator_device(; Device* device)
	{
		vk::DescriptorSetLayout layout = rpi_test_descriptor_set_layout(device)!!;
		defer device.backend.vk.vtable.destroyDescriptorSetLayout(device.backend.vk.device, layout, null);
		RpiDescriptorSetAlloc allocator = rpi_descriptor_set_alloc_init(layout, { .sampler = 1 }, RPI_FRAMES_IN_FLIGHT);
		defer rpi_descriptor_set_alloc_free(&allocator, device);

		RpiDescriptorSetSlot* early;
		bool found;
		for (ulong i = 0; i < 100; i++)
		{
			RpiDescriptorSetSlot* set = rpi_descriptor_set_alloc_resolve(&allocator, device, 0, 1000 + i, &found)!!;
			test::@check(!found);
			if (i == 3) early = set;
		}
		test::@check(allocator.pools.len() >= 2);

		RpiDescriptorSetSlot* set = rpi_descriptor_set_alloc_resolve(&allocator, device, 0, 1003, &found)!!;
		test::@check(found);
		test::@check(set == early);
		test::eq(early.hash, 1003ul);
	};
}

fn void rpi_descriptor_set_alloc_recycle_lone_slot_vk() @test
{
	@with_rpi_allocator_device(; Device* device)
	{
		vk::DescriptorSetLayout layout = rpi_test_descriptor_set_layout(device)!!;
		defer device.backend.vk.vtable.destroyDescriptorSetLayout(device.backend.vk.device, layout, null);
		RpiDescriptorSetAlloc allocator = rpi_descriptor_set_alloc_init(layout, { .sampler = 1 }, RPI_FRAMES_IN_FLIGHT);
		defer rpi_descriptor_set_alloc_free(&allocator, device);

		bool found;
		RpiDescriptorSetSlot* s = rpi_descriptor_set_alloc_resolve(&allocator, device, 0, 1, &found)!!;
		test::@check(!found);

		uint frame = RPI_FRAMES_IN_FLIGHT + 1;
		RpiDescriptorSetSlot* s2 = rpi_descriptor_set_alloc_resolve(&allocator, device, frame, 2, &found)!!;
		test::@check(!found);
		test::@check(s2 == s);
		test::@check(s.qu_next == null && s.qu_prev == null && allocator.queue_begin == s && allocator.queue_end == s);

		RpiDescriptorSetSlot* s3 = rpi_descriptor_set_alloc_resolve(&allocator, device, frame, 3, &found)!!;
		test::@check(!found);
		test::@check(s3 != s);
		test::@check(allocator.queue_begin == s && allocator.queue_end == s3 && s.qu_next == s3 && s3.qu_prev == s && s.qu_prev == null);

		s2 = rpi_descriptor_set_alloc_resolve(&allocator, device, frame, 2, &found)!!;
		test::@check(found);
		test::@check(s2 == s);
		test::@check(allocator.queue_begin == s3 && allocator.queue_end == s && s3.qu_prev == null && s.qu_next == null);
	};
}

// ---- Program test harness -------------------------------------------------

struct ProgramTestEnv
{
	List{PhysicalAdapter} adapters;
	Device dev;
	bool has_dev;
	uint errors;
	vk::DebugUtilsMessengerEXT messenger;
}

fn vk::Bool32 program_test_messenger_callback(
	vk::DebugUtilsMessageSeverityFlagBitsEXT message_severity,
	vk::DebugUtilsMessageTypeFlagsEXT message_types,
	vk::DebugUtilsMessengerCallbackDataEXT* callback_data,
	void* user_data)
{
	ProgramTestEnv* env = (ProgramTestEnv*)user_data;
	if (message_severity & vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT)
	{
		atomic::fetch_add(&env.errors, 1u);
		log::error("rpi program Vulkan validation error: %s", callback_data.pMessage);
	}
	return vk::FALSE;
}

fn bool program_test_env_init(ProgramTestEnv* env)
{
	*env = {};
	if (catch err = renderer_init({ .backend = VK, .vk = { .app_name = "rhi-rpi-program-test", .enable_validation_layer = true } }))
	{
		log::info("rpi program test skipped: Vulkan renderer unavailable");
		return false;
	}
	if (vk::createDebugUtilsMessengerEXT)
	{
		vk::DebugUtilsMessengerCreateInfoEXT info = {
			.sType = vk::StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
			.pfnUserCallback = &program_test_messenger_callback,
			.pUserData = env,
			.messageSeverity = vk::DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
			.messageType = vk::DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk::DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
		};
		if (catch err = vk_check(vk::createDebugUtilsMessengerEXT(renderer.vk.instance, &info, null, &env.messenger)))
		{
			log::info("rpi program test skipped: debug messenger unavailable");
			renderer_deinit();
			return false;
		}
	}
	List{PhysicalAdapter}? adapters = enumerate_adapters();
	if (catch err = adapters)
	{
		log::info("rpi program test skipped: adapter enumeration failed");
		program_test_env_deinit(env);
		return false;
	}
	env.adapters = adapters;
	if (env.adapters.len() == 0)
	{
		log::info("rpi program test skipped: no Vulkan adapter");
		program_test_env_deinit(env);
		return false;
	}
	Device? dev = device_init(&env.adapters[default_select_adapter(env.adapters.array_view())]);
	if (catch err = dev)
	{
		log::info("rpi program test skipped: device initialization failed");
		program_test_env_deinit(env);
		return false;
	}
	env.dev = dev;
	env.has_dev = true;
	return true;
}

fn void program_test_env_deinit(ProgramTestEnv* env)
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

fn ProgramModuleStage[2] program_test_modules()
{
	return {
		{ .stage = VERTEX, .data = RPI_TEST_FULLSCREEN_VERT_SPV[..], .entry_point = "main" },
		{ .stage = FRAGMENT, .data = RPI_TEST_MANDELBROT_FRAG_SPV[..], .entry_point = "main" },
	};
}

const ProgramLayoutBinding[2] PROGRAM_TEST_BINDINGS = {
	{ .name = "tex", .set = 0, .binding = 0, .descriptor_type = SAMPLED_IMAGE, .count = 1, .stages = { .fragment = true } },
	{ .name = "smp", .set = 0, .binding = 1, .descriptor_type = SAMPLER, .count = 1, .stages = { .fragment = true } },
};

fn Sampler program_test_sampler(Device* device, SamplerFilter filter)
{
	return sampler_init(device, {
		.min_filter = filter,
		.mag_filter = filter,
		.mip_map_mode = NEAREST,
		.address_u = CLAMP_TO_EDGE,
		.address_v = CLAMP_TO_EDGE,
		.address_w = CLAMP_TO_EDGE,
		.max_anisotropy = 1,
		.compare_func = NEVER,
	})!!;
}

struct ProgramTestTarget
{
	Image image;
	ImageView view;
}

fn ProgramTestTarget program_test_target(Device* device)
{
	Image image = image_init(device, {
		.image_type = D2, .format = RGBA8_UNORM, .width = 64, .height = 64,
		.depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1,
		.tiling = OPTIMAL, .usage = { .color_attachment = true },
		.memory_usage = PREFER_DEVICE,
	})!!;
	ImageView view = image_view_init(device, &image, {
		.view_type = COLOR_ATTACHMENT, .format = RGBA8_UNORM, .aspect = COLOR,
		.base_mip = 0, .mip_num = 1, .base_layer = 0, .layer_num = 1,
	})!!;
	return { .image = image, .view = view };
}

fn void program_test_begin_rendering(Cmd* cmd, Device* device, Image* image, ImageView view)
{
	cmd_image_barrier(cmd, device, {
		.image = image, .before = {}, .after = { .render_target = true },
		.aspect = COLOR, .layer_count = 1, .mip_count = 1,
	});
	cmd_begin_rendering(cmd, device, {
		.color_attachments = {{ .view = view, .load_op = CLEAR, .store_op = STORE, .clear_color = { 0, 0, 0, 1 } }},
		.render_area = { .width = 64, .height = 64 },
	});
	cmd_set_viewport(cmd, device, { .width = 64, .height = 64, .max_depth = 1 });
	cmd_set_scissor(cmd, device, { .width = 64, .height = 64 });
}

fn void program_test_submit(Cmd* cmd, Device* device)
{
	cmd_end(cmd, device)!!;
	Cmd*[1] cmds = { cmd };
	queue_submit(&device.graphics_queue, device, { .cmds = cmds[..] })!!;
	queue_wait_idle(&device.graphics_queue, device)!!;
}

fn void program_test_expect_no_validation_errors(ProgramTestEnv* env)
{
	test::eq(@atomic_load(env.errors), 0u);
}

fn void rpi_program_pipeline_cache_vk() @test
{
	ProgramTestEnv env;
	if (!program_test_env_init(&env)) return;
	Device* device = &env.dev;
	ProgramModuleStage[2] modules = program_test_modules();
	Program program = program_init(device, modules[..], {})!!;
	ProgramTestTarget target = program_test_target(device);
	Pool pool = pool_init(device, &device.graphics_queue)!!;
	Cmd cmd = cmd_init(device, &pool)!!;

	cmd_begin(&cmd, device)!!;
	program_test_begin_rendering(&cmd, device, &target.image, target.view);
	ProgramGraphicsPipelineDesc desc = {
		.topology = TRIANGLE_LIST, .cull_mode = NONE, .front_face = CLOCKWISE,
		.depth_compare = ALWAYS, .colors = {{ .format = RGBA8_UNORM }},
	};
	program_bind_pipeline(&program, device, &cmd, 1, desc)!!;
	program_bind_pipeline(&program, device, &cmd, 1, desc)!!;
	test::eq(program.pipelines.len(), 1);
	cmd_draw(&cmd, device, 3);
	cmd_end_rendering(&cmd, device);
	program_test_submit(&cmd, device);

	cmd_deinit(&cmd, device, &pool);
	pool_deinit(&pool, device);
	image_view_deinit(&target.view, device);
	image_deinit(&target.image, device);
	program_deinit(&program, device);
	program_test_env_deinit(&env);
	program_test_expect_no_validation_errors(&env);
}

fn void rpi_program_reflection_vk() @test
{
	ProgramTestEnv env;
	if (!program_test_env_init(&env)) return;
	Device* device = &env.dev;
	ProgramModuleStage[2] modules = program_test_modules();
	Program program = program_init(device, modules[..], { .bindings = PROGRAM_TEST_BINDINGS[..] })!!;
	ProgramBindingReflection* smp = program_find_reflection(&program, descriptor_binding_id("smp"));
	test::@check(smp != null);
	if (smp != null)
	{
		test::eq(smp.set, (ushort)0);
		test::eq(smp.base_register, (ushort)1);
		test::eq(smp.descriptor_type, DescriptorType.SAMPLER);
		test::@check(!smp.is_array);
	}
	test::@check(program_find_reflection(&program, descriptor_binding_id("missing")) == null);
	test::@check(program.sets[0].used);
	test::eq(program.sets[0].sizes.sampled_image, 1u);
	test::eq(program.sets[0].sizes.sampler, 1u);

	program_deinit(&program, device);
	program_test_env_deinit(&env);
	program_test_expect_no_validation_errors(&env);
}

fn void rpi_program_bind_descriptors_vk() @test
{
	ProgramTestEnv env;
	if (!program_test_env_init(&env)) return;
	Device* device = &env.dev;
	ProgramModuleStage[2] modules = program_test_modules();
	Program program = program_init(device, modules[..], { .bindings = PROGRAM_TEST_BINDINGS[..] })!!;
	Sampler nearest = program_test_sampler(device, NEAREST);
	Sampler linear = program_test_sampler(device, LINEAR);
	Image tex = image_init(device, {
		.image_type = D2, .format = RGBA8_UNORM, .width = 4, .height = 4,
		.depth = 1, .mip_levels = 1, .array_layers = 1, .samples = S1,
		.tiling = OPTIMAL, .usage = { .sampled = true, .transfer_dst = true },
		.memory_usage = PREFER_DEVICE,
	})!!;
	ImageView tex_view = image_view_init(device, &tex, {
		.view_type = SHADER_RESOURCE_2D, .format = RGBA8_UNORM, .aspect = COLOR,
		.mip_num = 1, .layer_num = 1,
	})!!;
	ProgramTestTarget target = program_test_target(device);
	Pool pool = pool_init(device, &device.graphics_queue)!!;
	Cmd cmd = cmd_init(device, &pool)!!;

	cmd_begin(&cmd, device)!!;
	cmd_image_barrier(&cmd, device, {
		.image = &tex, .before = {}, .after = { .shader_resource = true },
		.aspect = COLOR, .layer_count = 1, .mip_count = 1,
	});
	program_test_begin_rendering(&cmd, device, &target.image, target.view);
	program_bind_pipeline(&program, device, &cmd, 1, {
		.topology = TRIANGLE_LIST, .cull_mode = NONE, .front_face = CLOCKWISE,
		.depth_compare = ALWAYS, .colors = {{ .format = RGBA8_UNORM }},
	})!!;

	DescriptorBinding[3] first = {
		descriptor_binding("tex", descriptor_sampled_image(&tex_view), 0),
		descriptor_binding("smp", descriptor_sampler(&nearest), 0),
		descriptor_binding("unused", descriptor_sampler(&nearest), 0),
	};
	DescriptorBinding[2] second = {
		descriptor_binding("tex", descriptor_sampled_image(&tex_view), 0),
		descriptor_binding("smp", descriptor_sampler(&linear), 0),
	};
	program_bind_descriptors(&program, device, &cmd, 0, first[..], GRAPHICS)!!;
	cmd_draw(&cmd, device, 3);
	program_bind_descriptors(&program, device, &cmd, 0, first[..], GRAPHICS)!!;
	cmd_draw(&cmd, device, 3);
	program_bind_descriptors(&program, device, &cmd, 0, second[..], GRAPHICS)!!;
	cmd_draw(&cmd, device, 3);
	cmd_end_rendering(&cmd, device);
	program_test_submit(&cmd, device);

	RpiDescriptorSetAlloc* alloc = &program.sets[0].backend.vk.alloc;
	test::eq(alloc.pools.len(), 1);
	test::eq(alloc.reserved.len(), RPI_DESCRIPTOR_SETS_PER_POOL - 2);
	cmd_deinit(&cmd, device, &pool);
	pool_deinit(&pool, device);
	image_view_deinit(&target.view, device);
	image_deinit(&target.image, device);
	image_view_deinit(&tex_view, device);
	image_deinit(&tex, device);
	sampler_deinit(&linear, device);
	sampler_deinit(&nearest, device);
	program_deinit(&program, device);
	program_test_env_deinit(&env);
	program_test_expect_no_validation_errors(&env);
}

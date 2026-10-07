// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan resource tests. Resource portions. The command pool/copy front is not ported yet, so the
// image upload test checks the synchronous upload path and its validation
// result; buffer/image/sampler/descriptor handles are checked directly.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::core::test;
import std::collections::list;
import vk;

// The Vulkan shader module API consumes a uint pointer. Keep the embedded
// blobs word-aligned even though $embed itself produces a byte array.
const char[*] FULLSCREEN_VERT_SPV @align(4) = $embed("testdata/fullscreen.vert.spv");
const char[*] MANDELBROT_FRAG_SPV @align(4) = $embed("testdata/mandelbrot.frag.spv");

macro @with_vk_resource_device(;@body(Device* device))
{
	renderer_init({ .backend = VK, .vk = { .app_name = "rhi-test", .enable_validation_layer = true } })!!;
	defer renderer_deinit();
	uint validation_errors = vk_validation_error_count;
	// Resource and device defers are registered after this one, so this check
	// runs after resource/device destruction but before the instance is gone.
	defer test::eq(vk_validation_error_count, validation_errors);
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	test::@check(adapters.len() >= 1);
	Device device = device_init(&adapters[default_select_adapter(adapters.array_view())])!!;
	defer device_deinit(&device);
	@body(&device);
}

fn Shader? vk_test_shader(Device* device)
{
	return shader_init_graphics(device, {
		.vertex_stage = { .data = FULLSCREEN_VERT_SPV[..], .entry_point = "main" },
		.has_vertex_stage = true,
		.fragment_stage = { .data = MANDELBROT_FRAG_SPV[..], .entry_point = "main" },
		.has_fragment_stage = true,
	});
}

fn void buffer_create_write_destroy_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Buffer buffer = buffer_init_general(device, {
			.size = 256,
			.persistent_map = true,
			.sequential_access = true,
			.usage = { .vertex_buffer = true, .transfer_dst = true },
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&buffer, device);
		test::@check(!buffer_is_empty(&buffer));
		test::@check(buffer.mapped_region.ptr != null);

		char[4] data = { 42, 43, 44, 45 };
		buffer_write(&buffer, device, 0, data[..]);
		test::eq(buffer.mapped_region[0], data[0]);

		MappedMemoryRange mapped = buffer_get_mapped_region(&buffer, 0, 4)!!;
		test::@check(mapped.memory_range.len == (usz)4);
	};
}

fn void buffer_readback_is_mapped_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Buffer buffer = buffer_init_general(device, {
			.size = 256,
			.usage = { .transfer_dst = true },
			.buffer_usage = READBACK,
		})!!;
		defer buffer_deinit(&buffer, device);
		test::@check(!buffer_is_empty(&buffer));
		test::@check(buffer.mapped_region.ptr != null);
		test::@check(buffer.mapped_region.len >= (usz)256);

		for (sz i = 0; i < 256; i++) buffer.mapped_region[i] = (char)i;
		for (sz i = 0; i < 256; i++) test::eq(buffer.mapped_region[i], (char)i);
	};
}

fn void image_view_create_destroy_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Image image = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 64,
			.height = 64,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true, .transfer_dst = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&image, device);
		test::@check(!image_is_empty(&image));

		ImageView view = image_view_init(device, &image, {
			.view_type = SHADER_RESOURCE_2D,
			.format = RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&view, device);
		test::@check(!image_view_is_empty(&view));
		test::@check(view.backend.vk.view != vk::NULL_HANDLE);
	};
}

fn void image_upload_vk_test() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Image image = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 8,
			.height = 8,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true, .transfer_dst = true, .transfer_src = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&image, device);

		char[8 * 8 * 4] pixels;
		for (uint y = 0; y < 8; y++)
		{
			for (uint x = 0; x < 8; x++)
			{
				char v = (x + y) % 2 == 0 ? (char)0xff : (char)0;
				uint i = (y * 8 + x) * 4;
				pixels[i + 0] = v;
				pixels[i + 1] = (char)(x * 16);
				pixels[i + 2] = (char)(y * 16);
				pixels[i + 3] = (char)0xff;
			}
		}

		image_upload(&image, device, {
			.data = pixels[..],
			.extent = { .width = 8, .height = 8, .depth = 1 },
			.layer_count = 1,
		})!!;
		test::@check(image.backend.vk.image != vk::NULL_HANDLE);
	};
}

fn void shader_init_graphics_vk_test() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Shader shader = vk_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		test::@check(shader.backend.vk.vertex_module != vk::NULL_HANDLE);
		test::@check(shader.backend.vk.pixel_module != vk::NULL_HANDLE);
		ShaderStages stages = shader_stages(&shader);
		test::@check(stages.vertex);
		test::@check(stages.pixel);
	};
}

fn void pipeline_init_graphics_vk_test() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Shader shader = vk_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { { .format = RGBA8_UNORM } },
		})!!;
		defer pipeline_deinit(&pipeline, device);
		test::@check(pipeline.backend.vk.pipeline != vk::NULL_HANDLE);
		test::@check(pipeline.backend.vk.layout != vk::NULL_HANDLE);
	};
}

fn void pipeline_init_graphics_depth_blend_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Shader shader = vk_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { {
				.format = RGBA8_UNORM,
				.blend = BLEND_STATE_STRAIGHT_ALPHA,
				.has_blend = true,
			} },
			.depth = { .format = D32_SFLOAT, .write = true, .compare = LESS },
			.has_depth = true,
		})!!;
		defer pipeline_deinit(&pipeline, device);
		test::@check(pipeline.backend.vk.pipeline != vk::NULL_HANDLE);
		test::@check(pipeline.backend.vk.layout != vk::NULL_HANDLE);
	};
}

fn void sampler_create_destroy_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Sampler nearest = sampler_init(device, {
			.min_filter = NEAREST,
			.mag_filter = NEAREST,
			.mip_map_mode = NEAREST,
			.address_u = CLAMP_TO_EDGE,
			.address_v = CLAMP_TO_EDGE,
			.address_w = CLAMP_TO_EDGE,
			.max_anisotropy = 1,
			.compare_func = NEVER,
		})!!;
		defer sampler_deinit(&nearest, device);

		Sampler aniso = sampler_init(device, {
			.min_filter = LINEAR,
			.mag_filter = LINEAR,
			.mip_map_mode = LINEAR,
			.address_u = REPEAT,
			.address_v = REPEAT,
			.address_w = REPEAT,
			.max_anisotropy = 4,
			.compare_func = NEVER,
		})!!;
		defer sampler_deinit(&aniso, device);
		test::@check(!sampler_is_empty(&nearest));
		test::@check(!sampler_is_empty(&aniso));
		test::@check(nearest.cookie != aniso.cookie);
	};
}

fn void descriptor_handles_vk() @test
{
	@with_vk_resource_device(; Device* device)
	{
		Sampler sampler = sampler_init(device, {
			.min_filter = LINEAR,
			.mag_filter = LINEAR,
			.mip_map_mode = LINEAR,
			.address_u = CLAMP_TO_EDGE,
			.address_v = CLAMP_TO_EDGE,
			.address_w = CLAMP_TO_EDGE,
			.max_anisotropy = 1,
			.compare_func = NEVER,
		})!!;
		defer sampler_deinit(&sampler, device);

		Image image = image_init(device, {
			.image_type = D2,
			.format = RGBA8_UNORM,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 1,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true, .transfer_dst = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&image, device);
		ImageView view = image_view_init(device, &image, {
			.view_type = SHADER_RESOURCE_2D,
			.format = RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 1,
			.base_layer = 0,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&view, device);

		Buffer buffer = buffer_init_general(device, {
			.size = 256,
			.stride = 4,
			.persistent_map = true,
			.usage = { .shader_resource_storage = true },
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&buffer, device);

		Descriptor image_desc = descriptor_sampled_image(&view);
		test::@check(!descriptor_is_empty(image_desc));
		test::eq(image_desc.type, DescriptorType.SAMPLED_IMAGE);
		test::@check(image_desc.handle == (ulong)view.backend.vk.view);

		Descriptor sampler_desc = descriptor_sampler(&sampler);
		test::@check(!descriptor_is_empty(sampler_desc));
		test::eq(sampler_desc.type, DescriptorType.SAMPLER);
		test::@check(sampler_desc.handle == (ulong)sampler.backend.vk.sampler);

		Descriptor buffer_desc = descriptor_storage_buffer(&buffer, 0, 256);
		test::@check(!descriptor_is_empty(buffer_desc));
		test::eq(buffer_desc.type, DescriptorType.STORAGE_BUFFER);
		test::@check(buffer_desc.handle == (ulong)buffer.backend.vk.buffer);
		test::@check(descriptor_is_empty(descriptor_storage_buffer(&buffer, 0, 512)));
	};
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal resource and pipeline-table tests. These are type-checked by the
// macOS cross-check and run only where a Metal device is available.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::core::test;
import std::collections::list;
import mtl;

macro @with_mtl_resource_device(;@body(Device* device))
{
	renderer_init({ .backend = MTL, .mtl = {} })!!;
	defer renderer_deinit();
	List{PhysicalAdapter} adapters = enumerate_adapters()!!;
	defer adapters.free();
	Device device = device_init(&adapters[default_select_adapter(adapters.array_view())])!!;
	defer device_deinit(&device);
	@body(&device);
}

fn Shader? mtl_test_shader(Device* device)
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

fn void mtl_format_table_maps_equivalent_formats() @test
{
	test::eq(to_mtl_pixel_format(Format.A8_UNORM), mtl::PixelFormat.A8UNORM);
	test::eq(to_mtl_pixel_format(Format.RGBA8_UNORM), mtl::PixelFormat.RGBA8UNORM);
	test::eq(to_mtl_pixel_format(Format.BGRA8_SRGB), mtl::PixelFormat.BGRA8UNORM_SRGB);
	test::eq(to_mtl_pixel_format(Format.RG16_SFLOAT), mtl::PixelFormat.RG16FLOAT);
	test::eq(to_mtl_pixel_format(Format.RGBA32_SFLOAT), mtl::PixelFormat.RGBA32FLOAT);
	test::eq(to_mtl_pixel_format(Format.D24_UNORM_S8_UINT), mtl::PixelFormat.DEPTH24UNORM_STENCIL8);
	test::eq(to_mtl_pixel_format(Format.D32_SFLOAT_S8_UINT_X24), mtl::PixelFormat.DEPTH32FLOAT_STENCIL8);
	test::eq(to_mtl_pixel_format(Format.X24_R8_UINT), mtl::PixelFormat.X24_STENCIL8);
	test::eq(to_mtl_pixel_format(Format.BC7_RGBA_SRGB), mtl::PixelFormat.BC7_RGBAUNORM_SRGB);
	test::eq(to_mtl_pixel_format(Format.ETC2_R8G8B8A8_UNORM), mtl::PixelFormat.EAC_RGBA8);
	test::eq(to_mtl_pixel_format(Format.UNKNOWN), mtl::PixelFormat.INVALID);
	test::eq(to_mtl_pixel_format(Format.RGB8_UNORM), mtl::PixelFormat.INVALID);
	test::eq(from_mtl_pixel_format(mtl::PixelFormat.RGBA8UNORM), Format.RGBA8_UNORM);
	test::eq(from_mtl_pixel_format(mtl::PixelFormat.X24_STENCIL8), Format.X24_R8_UINT);
}

fn void mtl_pipeline_state_mappings_cover_front_types() @test
{
	test::eq(mtl_attribute_vertex_format(VertexFormat.FLOAT3), mtl::VertexFormat.FLOAT3);
	test::eq(mtl_compare_function(CompareOp.GREATER_EQUAL), mtl::CompareFunction.GREATER_EQUAL);
	test::eq(mtl_blend_factor(BlendFactor.ONE_MINUS_SRC_ALPHA), mtl::BlendFactor.ONE_MINUS_SOURCE_ALPHA);
	test::eq(mtl_blend_operation(BlendOp.REVERSE_SUBTRACT), mtl::BlendOperation.REVERSE_SUBTRACT);
	test::eq(mtl_color_write_mask({ .r = true, .b = true }), mtl::COLOR_WRITE_MASK_RED | mtl::COLOR_WRITE_MASK_BLUE);
	test::eq(mtl_primitive_type(PrimitiveTopology.LINE_STRIP), mtl::PrimitiveType.LINE_STRIP);
	test::eq(mtl_cull_mode(CullMode.BACK), mtl::CullMode.BACK);
	test::eq(mtl_winding(FrontFace.COUNTER_CLOCKWISE), mtl::Winding.COUNTER_CLOCKWISE);
}

fn void mtl_texture_slot_resolution_keeps_bindings_and_hashes() @test
{
	TextureSlot[MAX_TEXTURE_BINDINGS] slots;
	uint count = resolve_texture_slots({
		{ .name = "albedo", .binding = 3, .has_sampler_name = true, .sampler_name = "linear", .has_sampler_binding = true, .sampler_binding = 4 },
		{ .name = "normal", .binding = 5 },
	}, &slots)!!;
	test::eq(count, 2u);
	test::eq(slots[0].name_hash, descriptor_name_hash("albedo"));
	test::@check(slots[0].has_sampler_name_hash);
	test::eq(slots[0].sampler_name_hash, descriptor_name_hash("linear"));
	test::eq(slots[0].binding, 3u);
	test::@check(slots[0].has_sampler_binding);
	test::eq(slots[0].sampler_binding, 4u);
	test::eq(slots[1].name_hash, descriptor_name_hash("normal"));
	test::@check(!slots[1].has_sampler_name_hash);
	test::@check(!slots[1].has_sampler_binding);

	if (catch err = resolve_texture_slot({ .name = "bad", .has_sampler_binding = true, .sampler_binding = 1 }))
	{
		test::@check(err == SAMPLER_NAME_REQUIRED);
	}
	else
	{
		test::@check(false, "a sampler binding without a sampler name must fail");
	}
}

fn void mtl_images_create_and_destroy() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Image image = image_init(device, {
			.image_type = D2,
			.format = Format.RGBA8_UNORM,
			.width = 8,
			.height = 8,
			.depth = 1,
			.mip_levels = 2,
			.array_layers = 2,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true, .transfer_dst = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		test::@check(image.cookie != 0);
		test::@check(image.backend.mtl.texture != null);
		test::@check(image.backend.mtl.texture_type == mtl::TextureType.TYPE_2D_ARRAY);
		test::eq(image.backend.mtl.mip_levels, 2u);
		test::eq(image.backend.mtl.array_layers, 2u);

		image_deinit(&image, device);
		test::@check(image.cookie == 0);
		test::@check(image.backend.mtl.texture == null);
	};
}

fn void mtl_shared_and_private_buffers_have_expected_ownership() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Buffer shared = buffer_init_general(device, {
			.size = 256,
			.stride = 16,
			.buffer_usage = PREFER_HOST,
		})!!;
		defer buffer_deinit(&shared, device);
		test::@check(shared.cookie != 0);
		test::@check(shared.backend.mtl.buffer != null);
		test::@check(shared.backend.mtl.shared);
		test::@check(shared.mapped_region.len == (usz)256);

		char[4] bytes = { 1, 2, 3, 4 };
		buffer_write(&shared, device, 12, bytes[..]);
		test::eq(shared.mapped_region[12], (char)1);
		test::eq(shared.mapped_region[15], (char)4);

		Buffer private_buffer = buffer_init_general(device, {
			.size = 256,
			.stride = 16,
			.buffer_usage = PREFER_DEVICE,
		})!!;
		defer buffer_deinit(&private_buffer, device);
		test::@check(private_buffer.backend.mtl.buffer != null);
		test::@check(!private_buffer.backend.mtl.shared);
		test::@check(private_buffer.mapped_region.len == (usz)0);
	};
}

fn void mtl_image_views_cover_full_and_sub_ranges() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Image image = image_init(device, {
			.image_type = D2,
			.format = Format.RGBA8_UNORM,
			.width = 8,
			.height = 8,
			.depth = 1,
			.mip_levels = 2,
			.array_layers = 2,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&image, device);

		ImageView full = image_view_init(device, &image, {
			.view_type = SHADER_RESOURCE_2D_ARRAY,
			.format = Format.RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 0,
			.mip_num = 2,
			.base_layer = 0,
			.layer_num = 2,
		})!!;
		defer image_view_deinit(&full, device);
		test::@check(full.cookie != 0);
		test::@check(full.backend.mtl.texture != null);
		test::@check(full.backend.mtl.aliases_parent);
		test::@check(full.backend.mtl.texture == full.backend.mtl.parent);

		ImageView sub = image_view_init(device, &image, {
			.view_type = SHADER_RESOURCE_2D_ARRAY,
			.format = Format.RGBA8_UNORM,
			.aspect = COLOR,
			.base_mip = 1,
			.mip_num = 1,
			.base_layer = 1,
			.layer_num = 1,
		})!!;
		defer image_view_deinit(&sub, device);
		test::@check(sub.cookie != 0);
		test::@check(sub.backend.mtl.texture != null);
		test::@check(sub.backend.mtl.parent != null);
		test::@check(!sub.backend.mtl.aliases_parent);
		test::@check(sub.backend.mtl.texture != sub.backend.mtl.parent);
	};
}

fn void mtl_image_upload_accepts_full_and_sub_regions() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Image image = image_init(device, {
			.image_type = D2,
			.format = Format.RGBA8_UNORM,
			.width = 4,
			.height = 4,
			.depth = 1,
			.mip_levels = 2,
			.array_layers = 1,
			.samples = S1,
			.tiling = OPTIMAL,
			.usage = { .sampled = true, .transfer_dst = true },
			.memory_usage = PREFER_DEVICE,
		})!!;
		defer image_deinit(&image, device);

		char[64] full_pixels = { [0..63] = 0 };
		image_upload(&image, device, {
			.data = full_pixels[..],
			.extent = { .width = 4, .height = 4, .depth = 1 },
			.layer_count = 1,
		})!!;

		char[32] sub_pixels = { [0..31] = 0 };
		image_upload(&image, device, {
			.data = sub_pixels[..],
			.extent = { .width = 2, .height = 2, .depth = 1 },
			.layer_count = 1,
			.origin = { .x = 1, .y = 1, .z = 0 },
			.bytes_per_row = 20,
			.rows_per_image = 5,
		})!!;
		test::@check(image.backend.mtl.texture != null);
	};
}

fn void mtl_sampler_create_and_destroy() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Sampler sampler = sampler_init(device, {
			.min_filter = LINEAR,
			.mag_filter = LINEAR,
			.mip_map_mode = LINEAR,
			.address_u = REPEAT,
			.address_v = CLAMP_TO_EDGE,
			.address_w = MIRROR,
			.mip_lod_bias = 0,
			.set_lod_range = true,
			.min_lod = 0,
			.max_lod = 4,
			.max_anisotropy = 4,
			.compare_func = ALWAYS,
		})!!;
		test::@check(sampler.cookie != 0);
		test::@check(sampler.backend.mtl.state != null);

		sampler_deinit(&sampler, device);
		test::@check(sampler.cookie == 0);
		test::@check(sampler.backend.mtl.state == null);
	};
}

fn void mtl_shader_init_embeds_sanity_stages() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Shader shader = mtl_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		test::@check(shader.cookie != 0);
		test::@check(shader.backend.mtl.vertex_library != null);
		test::@check(shader.backend.mtl.vertex_function != null);
		test::@check(shader.backend.mtl.fragment_library != null);
		test::@check(shader.backend.mtl.fragment_function != null);
		ShaderStages stages = shader_stages(&shader);
		test::@check(stages.vertex);
		test::@check(stages.pixel);
	};
}

fn void mtl_pipeline_init_plain() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Shader shader = mtl_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { { .format = Format.RGBA8_UNORM } },
		})!!;
		defer pipeline_deinit(&pipeline, device);
		test::@check(pipeline.cookie != 0);
		test::@check(pipeline.backend.mtl.state != null);
		test::@check(pipeline.backend.mtl.depth_stencil == null);
		test::eq(pipeline.backend.mtl.texture_slot_count, 0u);
	};
}

fn void mtl_pipeline_init_depth() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Shader shader = mtl_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { { .format = Format.RGBA8_UNORM } },
			.depth = { .format = Format.D32_SFLOAT, .write = true, .compare = LESS },
			.has_depth = true,
		})!!;
		defer pipeline_deinit(&pipeline, device);
		test::@check(pipeline.cookie != 0);
		test::@check(pipeline.backend.mtl.state != null);
		test::@check(pipeline.backend.mtl.depth_stencil != null);
	};
}

fn void mtl_pipeline_init_blend() @test
{
	@with_mtl_resource_device(; Device* device)
	{
		Shader shader = mtl_test_shader(device)!!;
		defer shader_deinit(&shader, device);
		Pipeline pipeline = pipeline_init_graphics(device, {
			.shader = &shader,
			.colors = { {
				.format = Format.RGBA8_UNORM,
				.blend = BLEND_STATE_STRAIGHT_ALPHA,
				.has_blend = true,
			} },
		})!!;
		defer pipeline_deinit(&pipeline, device);
		test::@check(pipeline.cookie != 0);
		test::@check(pipeline.backend.mtl.state != null);
		test::@check(pipeline.backend.mtl.depth_stencil == null);
	};
}

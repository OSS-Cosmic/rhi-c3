// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

fn void default_select_adapter_prefers_discrete_over_integrated() @test
{
	PhysicalAdapter[] adapters = {
		{ .adapter_type = INTEGRATED, .video_memory_size = 8ul * 1024 * 1024 * 1024 },
		{ .adapter_type = DISCRETE, .video_memory_size = 1024 * 1024 },
	};
	sz result = default_select_adapter(adapters);
	test::eq(result, (sz)1);
}

fn void default_select_adapter_prefers_higher_preset_at_equal_type() @test
{
	PhysicalAdapter[] adapters = {
		{ .adapter_type = DISCRETE, .preset_level = LOW, .video_memory_size = 1024 * 1024 * 1024 },
		{ .adapter_type = DISCRETE, .preset_level = ULTRA, .video_memory_size = 1024 * 1024 * 1024 },
	};
	sz result = default_select_adapter(adapters);
	test::eq(result, (sz)1);
}

fn void default_select_adapter_prefers_more_vram_at_equal_type_and_preset() @test
{
	PhysicalAdapter[] adapters = {
		{ .adapter_type = DISCRETE, .preset_level = HIGH, .video_memory_size = 2ul * 1024 * 1024 * 1024 },
		{ .adapter_type = DISCRETE, .preset_level = HIGH, .video_memory_size = 8ul * 1024 * 1024 * 1024 },
	};
	sz result = default_select_adapter(adapters);
	test::eq(result, (sz)1);
}

fn void default_select_adapter_single_adapter_returns_zero() @test
{
	PhysicalAdapter[] adapters = {
		{ .adapter_type = DISCRETE, .preset_level = HIGH, .video_memory_size = 4ul * 1024 * 1024 * 1024 },
	};
	sz result = default_select_adapter(adapters);
	test::eq(result, (sz)0);
}

fn void gpu_preset_lookup_known_and_unknown() @test
{
	PresetLevel result_rtx4090 = gpu_preset_lookup(0x10DE, 0x2684);
	test::eq(result_rtx4090, PresetLevel.ULTRA);

	PresetLevel result_unknown = gpu_preset_lookup(0, 0);
	test::eq(result_unknown, PresetLevel.NONE);
}

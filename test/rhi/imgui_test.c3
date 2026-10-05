// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi @feat(RHI_IMGUI & RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import std::core::test;

macro sz @offset($Type, #field)
{
	$Type* value = null;
	return (sz)(iptr)&value.$eval($stringify(#field));
}

// Keep the renderer's private ABI mirror tied to the pinned ImGui layout.
// The vendor test covers the public declarations; these checks cover the
// reduced structs used by the renderer without requiring a live ImGui context.
fn void imgui_layer_layout() @test
{
	test::eq(ImguiVec2::size, 8u);
	test::eq(ImguiVec4::size, 16u);
	test::eq(ImguiDrawVert::size, 20u);
	test::eq(ImguiDrawCmd::size, 72u);
	test::eq(ImguiDrawList::size, 224u);
	test::eq(ImguiDrawData::size, 72u);
	test::eq(@offset(ImguiDrawData, cmd_lists), 16);
	test::eq(@offset(ImguiDrawData, display_size), 40);
	test::eq(@offset(ImguiDrawData, framebuffer_scale), 48);
}

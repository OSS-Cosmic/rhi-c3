// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module imgui;
import std::core::test;

alias CreateContextFn = fn Context(FontAtlas*);
alias DestroyContextFn = fn void(Context);

// These values are measured from the pinned C++ headers with the same
// C++17/no-obsolete-functions build used by c3/build.py imgui. They mirror
// vendor/imgui/imgui_test.odin and intentionally catch a changed generated
// dear-bindings ABI or an incorrect ImGui build define.
fn void layout() @test
{
	@check_size(DrawVert, 20);
	@check_offset(DrawVert, pos, 0);
	@check_offset(DrawVert, uv, 8);
	@check_offset(DrawVert, col, 16);
	@check_size(DrawIdx, 2);
	@check_size(Vec2, 8);
	@check_size(Vec4, 16);
	@check_size(TextureID, 8);
	@check_size(Context, 8);
	@check_size(TextureRef, 16);
	@check_size(StoragePair, 16);

	@check_size(ImGuiIO, 3096);
	@check_offset(ImGuiIO, backend_flags, 4);
	@check_offset(ImGuiIO, display_size, 8);
	@check_offset(ImGuiIO, fonts, 56);
	@check_offset(ImGuiIO, mouse_pos, 232);
	@check_offset(ImGuiIO, input_queue_characters, 3048);
	@check_offset(ImGuiIO, font_global_scale, 3064);
	@check_offset(ImGuiIO, get_clipboard_text_fn, 3072);

	@check_size(ImGuiStyle, 1356);

	@check_size(DrawCmd, 72);
	@check_offset(DrawCmd, clip_rect, 0);
	@check_offset(DrawCmd, tex_ref, 16);
	@check_offset(DrawCmd, vtx_offset, 32);
	@check_offset(DrawCmd, idx_offset, 36);
	@check_offset(DrawCmd, elem_count, 40);
	@check_offset(DrawCmd, user_callback, 48);

	@check_size(DrawList, 224);
	@check_offset(DrawList, cmd_buffer, 0);
	@check_offset(DrawList, vtx_buffer, 32);

	@check_size(DrawData, 72);
	@check_offset(DrawData, cmd_lists_count, 4);
	@check_offset(DrawData, total_vtx_count, 12);
	@check_offset(DrawData, cmd_lists, 16);
	@check_offset(DrawData, display_size, 40);

	@check_size(FontAtlas, 760);
	@check_offset(FontAtlas, tex_ref, 40);
	@check_offset(FontAtlas, tex_data, 56);
	@check_offset(FontAtlas, temp_rect, 736);
}

macro sz @offset($Type, #field)
{
	$Type* value = null;
	return (sz)(iptr)&value.$eval($stringify(#field));
}

macro void @check_size($Type, usz expected)
{
	usz actual = $Type::size;
	test::eq(actual, expected);
}

macro void @check_offset($Type, #field, sz expected)
{
	test::eq(@offset($Type, #field), expected);
}

// Taking addresses forces the linker to resolve the actual archive members;
// this is deliberately a link smoke test, not a fake implementation.
fn void link() @test
{
	// These typed assignments catch an accidental extra pointer layer on the
	// opaque Context handle even when this test is run compile-only.
	CreateContextFn create_context_typed = &create_context;
	DestroyContextFn destroy_context_typed = &destroy_context;
	void* create_context_fn = (void*)&create_context;
	void* render_fn = (void*)&render;
	void* get_draw_data_fn = (void*)&get_draw_data;
	test::eq(create_context_typed != null, true);
	test::eq(destroy_context_typed != null, true);
	test::eq(create_context_fn != null, true);
	test::eq(render_fn != null, true);
	test::eq(get_draw_data_fn != null, true);
}

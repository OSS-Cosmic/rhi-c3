// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Minimal C3 declarations for the pinned Dear ImGui/dear-bindings build in
// vendor/imgui.  These are C ABI declarations; the implementation is the
// real libimgui.a produced by c3/build.py imgui.
module imgui;

typedef Context @constinit = inline void*;
typedef Font @constinit = inline void*;
typedef Viewport @constinit = inline void*;
typedef TextureID @constinit = ulong;
typedef DrawIdx @constinit = ushort;
typedef WindowFlags @constinit = uint;
typedef BackendFlags @constinit = uint;
typedef SliderFlags @constinit = uint;

alias GetClipboardTextFn = fn ZString(void*);
alias SetClipboardTextFn = fn void(void*, ZString);

struct Vec2
{
	float x;
	float y;
}

struct Vec4
{
	float x;
	float y;
	float z;
	float w;
}

struct TextureRef
{
	void* tex_data;
	TextureID tex_id;
}

struct StoragePair
{
	uint key;
	union
	{
		int val_i;
		float val_f;
		void* val_ptr;
	}
}

struct VectorWchar
{
	int size;
	int capacity;
	ushort* data;
}

struct ImGuiIO
{
	uint config_flags;
	BackendFlags backend_flags;
	Vec2 display_size;
	char[40] _before_fonts;
	FontAtlas* fonts;
	char[168] _before_mouse_pos;
	Vec2 mouse_pos;
	char[2808] _before_input_queue_characters;
	VectorWchar input_queue_characters;
	float font_global_scale;
	GetClipboardTextFn get_clipboard_text_fn;
	SetClipboardTextFn set_clipboard_text_fn;
	void* clipboard_user_data;
}

// Style is intentionally opaque here. Its complete layout is still pinned by
// the ABI test, while callers use the Dear ImGui setter functions below.
struct ImGuiStyle
{
	char[1356] _abi;
}

struct DrawVert
{
	Vec2 pos;
	Vec2 uv;
	uint col;
}

struct DrawCmd
{
	Vec4 clip_rect;
	TextureRef tex_ref;
	uint vtx_offset;
	uint idx_offset;
	uint elem_count;
	void* user_callback;
	void* user_callback_data;
	int data_size;
	int data_offset;
}

struct VectorDrawCmd
{
	int size;
	int capacity;
	DrawCmd* data;
}

struct VectorDrawIdx
{
	int size;
	int capacity;
	DrawIdx* data;
}

struct VectorDrawVert
{
	int size;
	int capacity;
	DrawVert* data;
}

struct DrawList
{
	VectorDrawCmd cmd_buffer;
	VectorDrawIdx idx_buffer;
	VectorDrawVert vtx_buffer;
	char[176] _abi;
}

struct VectorDrawListPtr
{
	int size;
	int capacity;
	DrawList** data;
}

struct DrawData
{
	bool valid;
	int cmd_lists_count;
	int total_idx_count;
	int total_vtx_count;
	VectorDrawListPtr cmd_lists;
	Vec2 display_pos;
	Vec2 display_size;
	Vec2 framebuffer_scale;
	Viewport owner_viewport;
	void* textures;
}

struct FontAtlasRect
{
	ushort x;
	ushort y;
	ushort width;
	ushort height;
	Vec2 uv0;
	Vec2 uv1;
}

// Sparse declaration of the generated ImFontAtlas. The omitted fields are
// kept as explicit ABI padding so the legacy texture-data API remains safe.
struct FontAtlas
{
	char[40] _before_tex_ref;
	TextureRef tex_ref;
	void* tex_data;
	char[672] _before_temp_rect;
	FontAtlasRect temp_rect;
}

const BackendFlags BACKEND_FLAGS_RENDERER_HAS_VTX_OFFSET = 1 << 3;

// Context is already an opaque pointer handle; do not add another pointer
// layer to the C ABI declarations below.
extern fn Context create_context(FontAtlas* shared_font_atlas) @cname("ImGui_CreateContext");
extern fn void destroy_context(Context context) @cname("ImGui_DestroyContext");
extern fn bool debug_check_version_and_data_layout(ZString version, usz sz_io, usz sz_style, usz sz_vec2, usz sz_vec4, usz sz_draw_vert, usz sz_draw_idx) @cname("ImGui_DebugCheckVersionAndDataLayout");
extern fn ImGuiIO* get_io() @cname("ImGui_GetIO");
extern fn ImGuiStyle* get_style() @cname("ImGui_GetStyle");
extern fn void style_colors_dark(ImGuiStyle* dst) @cname("ImGui_StyleColorsDark");
extern fn void new_frame() @cname("ImGui_NewFrame");
extern fn void render() @cname("ImGui_Render");
extern fn DrawData* get_draw_data() @cname("ImGui_GetDrawData");
extern fn void show_demo_window(bool* open) @cname("ImGui_ShowDemoWindow");
extern fn bool begin(ZString name, bool* open, WindowFlags flags) @cname("ImGui_Begin");
extern fn void end() @cname("ImGui_End");
extern fn void text(ZString format, ...) @cname("ImGui_Text");
extern fn bool checkbox(ZString label, bool* value) @cname("ImGui_Checkbox");
extern fn bool slider_float(ZString label, float* value, float min, float max, ZString format, SliderFlags flags) @cname("ImGui_SliderFloat");

extern fn void io_add_mouse_pos_event(ImGuiIO* io, float x, float y) @cname("ImGuiIO_AddMousePosEvent");
extern fn void io_add_mouse_button_event(ImGuiIO* io, int button, bool down) @cname("ImGuiIO_AddMouseButtonEvent");
extern fn void io_add_mouse_wheel_event(ImGuiIO* io, float x_wheel, float y_wheel) @cname("ImGuiIO_AddMouseWheelEvent");
extern fn void font_atlas_get_tex_data_as_rgba32(FontAtlas* atlas, char** pixels, int* width, int* height, int* bytes_per_pixel) @cname("ImFontAtlas_GetTexDataAsRGBA32");
extern fn void font_atlas_set_tex_id(FontAtlas* atlas, TextureID tex_id) @cname("ImFontAtlas_SetTexID");

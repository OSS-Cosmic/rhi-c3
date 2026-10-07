// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
//
// Plain C interface over upstream Dear ImGui (vendor/imgui_c/imgui submodule), for the
// C3 bindings in src/vendor/imgui/imgui.c3 and src/rhi/imgui.c3. Upstream
// exposes C++ only (namespaced functions, member functions, default
// arguments, C++ varargs), so each function here is a thin extern "C"
// forwarder with the C name the C3 side declares via @cname. Only functions
// the C3 code calls are exported; add more here when a binding needs them.
//
// Opaque pointers are used for ImGuiIO/ImGuiStyle/ImDrawData/ImFontAtlas/
// ImGuiContext; their layouts are mirrored by hand in C3 and pinned by
// test/vendor/imgui/imgui_test.c3.
#ifndef IMGUI_C_H
#define IMGUI_C_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ImGuiContext ImGuiContext;
typedef struct ImGuiIO ImGuiIO;
typedef struct ImGuiStyle ImGuiStyle;
typedef struct ImDrawData ImDrawData;
typedef struct ImFontAtlas ImFontAtlas;

// Context and layout check.
ImGuiContext* ImGui_CreateContext(ImFontAtlas* shared_font_atlas);
void ImGui_DestroyContext(ImGuiContext* ctx);
void ImGui_SetCurrentContext(ImGuiContext* ctx);
bool ImGui_DebugCheckVersionAndDataLayout(const char* version, size_t sz_io, size_t sz_style,
                                          size_t sz_vec2, size_t sz_vec4, size_t sz_drawvert,
                                          size_t sz_drawidx);

// State and frame loop.
ImGuiIO* ImGui_GetIO(void);
ImGuiStyle* ImGui_GetStyle(void);
void ImGui_StyleColorsDark(ImGuiStyle* dst);
void ImGui_NewFrame(void);
void ImGui_Render(void);
ImDrawData* ImGui_GetDrawData(void);

// Widgets (flags are plain ints; ImGui_Text forwards C varargs to TextV).
void ImGui_ShowDemoWindow(bool* open);
bool ImGui_Begin(const char* name, bool* open, int flags);
void ImGui_End(void);
void ImGui_Text(const char* fmt, ...);
bool ImGui_Checkbox(const char* label, bool* value);
bool ImGui_SliderFloat(const char* label, float* value, float min, float max, const char* format,
                       int flags);
void ImGui_Separator(void);

// Input queue.
void ImGuiIO_AddKeyEvent(ImGuiIO* io, int key, bool down);
void ImGuiIO_AddMousePosEvent(ImGuiIO* io, float x, float y);
void ImGuiIO_AddMouseButtonEvent(ImGuiIO* io, int button, bool down);
void ImGuiIO_AddMouseWheelEvent(ImGuiIO* io, float wheel_x, float wheel_y);
void ImGuiIO_AddFocusEvent(ImGuiIO* io, bool focused);
void ImGuiIO_AddInputCharacter(ImGuiIO* io, unsigned int c);

// Legacy font atlas path (upstream gates these behind
// !IMGUI_DISABLE_OBSOLETE_FUNCTIONS, so the library is built without that
// define).
void ImFontAtlas_GetTexDataAsRGBA32(ImFontAtlas* atlas, unsigned char** out_pixels, int* out_width,
                                    int* out_height, int* out_bytes_per_pixel);
void ImFontAtlas_SetTexID(ImFontAtlas* atlas, uint64_t tex_id);

#ifdef __cplusplus
}
#endif

#endif

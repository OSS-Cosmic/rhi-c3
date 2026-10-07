// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
//
// extern "C" forwarders over upstream Dear ImGui; see imgui_c.h.
#include <stdarg.h>

#include "imgui.h"
#include "imgui_c.h"

extern "C" {

ImGuiContext* ImGui_CreateContext(ImFontAtlas* shared_font_atlas) {
    return ImGui::CreateContext(shared_font_atlas);
}
void ImGui_DestroyContext(ImGuiContext* ctx) { ImGui::DestroyContext(ctx); }
void ImGui_SetCurrentContext(ImGuiContext* ctx) { ImGui::SetCurrentContext(ctx); }
bool ImGui_DebugCheckVersionAndDataLayout(const char* version, size_t sz_io, size_t sz_style,
                                          size_t sz_vec2, size_t sz_vec4, size_t sz_drawvert,
                                          size_t sz_drawidx) {
    return ImGui::DebugCheckVersionAndDataLayout(version, sz_io, sz_style, sz_vec2, sz_vec4,
                                                 sz_drawvert, sz_drawidx);
}

ImGuiIO* ImGui_GetIO(void) { return &ImGui::GetIO(); }
ImGuiStyle* ImGui_GetStyle(void) { return &ImGui::GetStyle(); }
void ImGui_StyleColorsDark(ImGuiStyle* dst) { ImGui::StyleColorsDark(dst); }
void ImGui_NewFrame(void) { ImGui::NewFrame(); }
void ImGui_Render(void) { ImGui::Render(); }
ImDrawData* ImGui_GetDrawData(void) { return ImGui::GetDrawData(); }

void ImGui_ShowDemoWindow(bool* open) { ImGui::ShowDemoWindow(open); }
bool ImGui_Begin(const char* name, bool* open, int flags) {
    return ImGui::Begin(name, open, (ImGuiWindowFlags)flags);
}
void ImGui_End(void) { ImGui::End(); }
void ImGui_Text(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    ImGui::TextV(fmt, args);
    va_end(args);
}
bool ImGui_Checkbox(const char* label, bool* value) { return ImGui::Checkbox(label, value); }
bool ImGui_SliderFloat(const char* label, float* value, float min, float max, const char* format,
                       int flags) {
    return ImGui::SliderFloat(label, value, min, max, format, (ImGuiSliderFlags)flags);
}
void ImGui_Separator(void) { ImGui::Separator(); }

void ImGuiIO_AddKeyEvent(ImGuiIO* io, int key, bool down) { io->AddKeyEvent((ImGuiKey)key, down); }
void ImGuiIO_AddMousePosEvent(ImGuiIO* io, float x, float y) { io->AddMousePosEvent(x, y); }
void ImGuiIO_AddMouseButtonEvent(ImGuiIO* io, int button, bool down) {
    io->AddMouseButtonEvent(button, down);
}
void ImGuiIO_AddMouseWheelEvent(ImGuiIO* io, float wheel_x, float wheel_y) {
    io->AddMouseWheelEvent(wheel_x, wheel_y);
}
void ImGuiIO_AddFocusEvent(ImGuiIO* io, bool focused) { io->AddFocusEvent(focused); }
void ImGuiIO_AddInputCharacter(ImGuiIO* io, unsigned int c) { io->AddInputCharacter(c); }

void ImFontAtlas_GetTexDataAsRGBA32(ImFontAtlas* atlas, unsigned char** out_pixels, int* out_width,
                                    int* out_height, int* out_bytes_per_pixel) {
    atlas->GetTexDataAsRGBA32(out_pixels, out_width, out_height, out_bytes_per_pixel);
}
void ImFontAtlas_SetTexID(ImFontAtlas* atlas, uint64_t tex_id) {
    atlas->SetTexID((ImTextureID)tex_id);
}

}  // extern "C"

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#ifndef __c3__
#define __c3__

typedef void* c3typeid_t;
typedef void* c3fault_t;
typedef struct { void* ptr; size_t len; } c3slice_t;
typedef struct { void* ptr; c3typeid_t type; } c3any_t;

#endif

/* TYPES */
typedef uint32_t rhi__GlHandle;
typedef int32_t std_core_cinterop__CInt;
typedef int32_t std_core__sz;

/* FUNCTIONS */
extern uint32_t wgpu_adapter_get(void);
extern uint32_t wgpu_device_get(void);
extern uint32_t wgpu_device_get_queue(uint32_t device);
extern uint32_t wgpu_adapter_name(uint32_t adapter, uint8_t* ptr, uint32_t len);
extern uint32_t wgpu_adapter_vendor_id(uint32_t adapter);
extern uint32_t wgpu_adapter_device_id(uint32_t adapter);
extern uint32_t wgpu_adapter_type(uint32_t adapter);
extern uint32_t wgpu_adapter_limit(uint32_t adapter, uint8_t* ptr, uint32_t len);
extern void wgpu_release(uint32_t handle);
extern uint32_t wgpu_surface_create(uint8_t* ptr, uint32_t len);
extern uint32_t wgpu_surface_preferred_format(void);
extern void wgpu_surface_configure(uint32_t surface, uint32_t device, uint32_t format, uint32_t width, uint32_t height);
extern uint32_t wgpu_surface_get_current_texture(uint32_t surface);
extern uint32_t wgpu_device_create_texture(uint32_t device, uint32_t format, uint32_t width, uint32_t height, uint32_t depth_or_layers, uint32_t mip_levels, uint32_t samples, uint32_t dimension, uint32_t usage);
extern void wgpu_queue_write_texture(uint32_t queue, uint32_t texture, uint32_t mip, uint32_t x, uint32_t y, uint32_t z, uint32_t width, uint32_t height, uint32_t depth, uint8_t* ptr, uint32_t len, uint32_t bytes_per_row, uint32_t rows_per_image);
extern uint32_t wgpu_texture_create_view(uint32_t texture, uint32_t format, uint32_t dimension, uint32_t aspect, uint32_t base_mip, uint32_t mip_count, uint32_t base_layer, uint32_t layer_count);
extern uint32_t wgpu_device_create_buffer(uint32_t device, uint32_t size, uint32_t usage);
extern void wgpu_queue_write_buffer(uint32_t queue, uint32_t buffer, uint32_t offset, uint8_t* ptr, uint32_t len);
extern uint32_t wgpu_device_create_shader_module(uint32_t device, uint8_t* ptr, uint32_t len);
extern uint32_t wgpu_device_create_render_pipeline(uint32_t device, uint32_t vs, uint8_t* vs_entry, uint32_t vs_len, uint32_t fs, uint8_t* fs_entry, uint32_t fs_len, uint32_t color_format, uint32_t depth_format, uint32_t topology, uint32_t cull, uint32_t front, uint32_t depth_write, uint32_t depth_compare, uint32_t stride, uint32_t* attrs, uint32_t attrs_len, uint32_t blend_enable, uint32_t src_color, uint32_t dst_color, uint32_t color_op, uint32_t src_alpha, uint32_t dst_alpha, uint32_t alpha_op, uint32_t write_mask);
extern uint32_t wgpu_device_create_sampler(uint32_t device, uint32_t mag, uint32_t min, uint32_t mip, uint32_t address_u, uint32_t address_v, uint32_t address_w, float lod_min, float lod_max, uint32_t anisotropy);
extern uint32_t wgpu_device_create_bind_group_textures(uint32_t device, uint32_t layout, uint32_t* entries, uint32_t entries_len);
extern uint32_t wgpu_render_pipeline_get_bind_group_layout(uint32_t pipeline, uint32_t index);
extern uint32_t wgpu_device_create_bind_group_uniform(uint32_t device, uint32_t layout, uint32_t buffer, uint32_t offset, uint32_t size);
extern uint32_t wgpu_device_create_command_encoder(uint32_t device);
extern uint32_t wgpu_command_encoder_begin_render_pass(uint32_t encoder, uint32_t color_view, uint32_t color_load, uint32_t color_store, float clear_r, float clear_g, float clear_b, float clear_a, uint32_t depth_view, uint32_t depth_load, uint32_t depth_store, float clear_depth);
extern void wgpu_command_encoder_copy_buffer_to_buffer(uint32_t encoder, uint32_t src, uint32_t src_offset, uint32_t dst, uint32_t dst_offset, uint32_t size);
extern uint32_t wgpu_command_encoder_finish(uint32_t encoder);
extern void wgpu_render_pass_set_viewport(uint32_t pass, float x, float y, float width, float height, float min_depth, float max_depth);
extern void wgpu_render_pass_set_scissor_rect(uint32_t pass, uint32_t x, uint32_t y, uint32_t width, uint32_t height);
extern void wgpu_render_pass_set_pipeline(uint32_t pass, uint32_t pipeline);
extern void wgpu_render_pass_set_bind_group(uint32_t pass, uint32_t index, uint32_t bind_group);
extern void wgpu_render_pass_set_vertex_buffer(uint32_t pass, uint32_t slot, uint32_t buffer, uint32_t offset);
extern void wgpu_render_pass_set_index_buffer(uint32_t pass, uint32_t buffer, uint32_t format, uint32_t offset);
extern void wgpu_render_pass_draw(uint32_t pass, uint32_t vertices, uint32_t instances, uint32_t first_vertex, uint32_t first_instance);
extern void wgpu_render_pass_draw_indexed(uint32_t pass, uint32_t indices, uint32_t instances, uint32_t first_index, int32_t base_vertex, uint32_t first_instance);
extern void wgpu_render_pass_end(uint32_t pass);
extern void wgpu_queue_submit(uint32_t queue, uint32_t* commands, uint32_t count);
extern void wgpu_queue_on_submitted_work_done(uint32_t queue, uint32_t* out_value, uint32_t lo, uint32_t hi);
extern void wgpu_log(uint32_t level, uint8_t* ptr, uint32_t len);
extern uint32_t gl_available(void);
extern uint32_t gl_renderer_name(uint8_t* ptr, uint32_t len);
extern int32_t gl_get_parameter_int(uint32_t pname);
extern rhi__GlHandle gl_create_buffer(uint32_t target, uint32_t size, uint32_t usage);
extern void gl_delete_buffer(rhi__GlHandle buffer);
extern void gl_buffer_sub_data(uint32_t target, rhi__GlHandle buffer, uint32_t offset, uint8_t* ptr, uint32_t len);
extern void gl_copy_buffer_sub_data(uint32_t src_target, rhi__GlHandle src, uint32_t src_offset, uint32_t dst_target, rhi__GlHandle dst, uint32_t dst_offset, uint32_t size);
extern rhi__GlHandle gl_create_texture_2d(uint32_t internal_format, uint32_t width, uint32_t height, uint32_t levels);
extern void gl_delete_texture(rhi__GlHandle texture);
extern void gl_tex_sub_image_2d(rhi__GlHandle texture, uint32_t level, int32_t x, int32_t y, uint32_t width, uint32_t height, uint32_t format, uint32_t type, uint8_t* ptr, uint32_t len);
extern void gl_tex_sub_image_2d_from_buffer(rhi__GlHandle texture, uint32_t level, int32_t x, int32_t y, uint32_t width, uint32_t height, uint32_t format, uint32_t type, rhi__GlHandle buffer, uint32_t offset, uint32_t row_length);
extern rhi__GlHandle gl_create_sampler(uint32_t min_filter, uint32_t mag_filter, uint32_t wrap_s, uint32_t wrap_t, uint32_t wrap_r);
extern void gl_delete_sampler(rhi__GlHandle sampler);
extern void gl_bind_texture_unit(uint32_t unit, rhi__GlHandle texture, rhi__GlHandle sampler);
extern int32_t gl_set_sampler_unit(rhi__GlHandle program, uint8_t* ptr, uint32_t len, uint32_t unit);
extern rhi__GlHandle gl_create_framebuffer(void);
extern void gl_delete_framebuffer(rhi__GlHandle framebuffer);
extern void gl_framebuffer_texture_2d(rhi__GlHandle framebuffer, uint32_t attachment, rhi__GlHandle texture);
extern uint32_t gl_check_framebuffer_status(rhi__GlHandle framebuffer);
extern void gl_bind_framebuffer(rhi__GlHandle framebuffer);
extern void gl_blit_to_canvas(rhi__GlHandle framebuffer, uint32_t width, uint32_t height);
extern rhi__GlHandle gl_create_program(uint8_t* vs_ptr, uint32_t vs_len, uint8_t* fs_ptr, uint32_t fs_len, uint8_t* err_ptr, uint32_t err_len);
extern void gl_delete_program(rhi__GlHandle program);
extern void gl_use_program(rhi__GlHandle program);
extern int32_t gl_uniform_location(rhi__GlHandle program, uint8_t* ptr, uint32_t len);
extern void gl_uniform_raw(int32_t location, uint32_t type, uint8_t* ptr, uint32_t len);
extern rhi__GlHandle gl_create_vertex_array(void);
extern void gl_delete_vertex_array(rhi__GlHandle vao);
extern void gl_bind_vertex_array(rhi__GlHandle vao);
extern void gl_vertex_attrib_pointer(rhi__GlHandle vao, rhi__GlHandle buffer, uint32_t location, uint32_t components, uint32_t stride, uint32_t offset);
extern void gl_vao_set_element_buffer(rhi__GlHandle vao, rhi__GlHandle buffer);
extern void gl_viewport(int32_t x, int32_t y, int32_t width, int32_t height, float min_depth, float max_depth);
extern void gl_scissor(int32_t x, int32_t y, uint32_t width, uint32_t height);
extern void gl_set_enabled(uint32_t cap, bool enabled);
extern void gl_depth_func(uint32_t func);
extern void gl_depth_mask(bool enabled);
extern void gl_cull_face(uint32_t mode);
extern void gl_front_face(uint32_t mode);
extern void gl_color_mask(bool r, bool g, bool b, bool a);
extern void gl_blend_func_separate(uint32_t src_rgb, uint32_t dst_rgb, uint32_t src_alpha, uint32_t dst_alpha);
extern void gl_blend_equation_separate(uint32_t rgb, uint32_t alpha);
extern void gl_clear_color(float r, float g, float b, float a);
extern void gl_clear_depth(float depth);
extern void gl_clear_stencil(uint32_t stencil);
extern void gl_draw_arrays(uint32_t mode, uint32_t first, uint32_t count, uint32_t instances);
extern void gl_draw_elements(uint32_t mode, uint32_t count, uint32_t type, uint32_t offset, uint32_t instances);
extern void gl_finish(void);
extern rhi__GlHandle gl_fence_sync(void);
extern bool gl_client_wait_sync(rhi__GlHandle sync);
extern void gl_delete_sync(rhi__GlHandle sync);
extern void _initialize(void);
extern std_core_cinterop__CInt memcmp(void* s1, void* s2, ptrdiff_t n);
extern void* memset(void* str, std_core_cinterop__CInt c, ptrdiff_t n);
extern void* memcpy(void* dst, void* src, ptrdiff_t n);

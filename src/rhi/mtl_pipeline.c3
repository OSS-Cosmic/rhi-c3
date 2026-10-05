// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal graphics pipeline. Port of the `.mtl` arm of rhi-zig's
// `pipeline.zig` `init_graphics`/`deinit`.
//
// Extension: per-attachment blending (rhi-zig rejects any blend state with
// `error.BlendUnsupportedOnMetal`), raster state and texture slots.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import mtl;

// Metal buffer index of vertex-buffer slot 0; push constants own index 0.
// See "Metal binding-index convention" in c3/README.md.
const uint MTL_VERTEX_BUFFER_BASE = 1;

struct PipelineMtl
{
	// Owned: +1 from -newRenderPipelineStateWithDescriptor:error:.
	mtl::RenderPipelineState state;
	// Owned; null when the pipeline has no depth attachment.
	mtl::DepthStencilState depth_stencil;
	// Raster state Metal sets on the encoder rather than the pipeline.
	mtl::CullMode cull_mode;
	mtl::Winding winding;
	mtl::PrimitiveType primitive_type;
	uint push_constant_size;
	TextureSlot[MAX_TEXTURE_BINDINGS] texture_slots;
	uint texture_slot_count;
}

fn Pipeline? pipeline_init_graphics_mtl(Device* device, PipelineGraphicsOptions options)
{
	if (options.colors.len > MAX_COLOR_ATTACHMENTS) return MULTIPLE_RENDER_TARGETS_UNSUPPORTED~;
	ShaderMtl* sh = &options.shader.backend.mtl;
	if (!sh.vertex_function) return MISSING_SHADER_STAGE~;
	foreach (target : options.colors)
	{
		if (to_mtl_pixel_format(target.format) == mtl::PixelFormat.INVALID) return UNSUPPORTED_FEATURE~;
	}
	if (options.has_depth)
	{
		FormatProperties depth_props = format_get_props(options.depth.format);
		if (!depth_props.is_depth) return UNSUPPORTED_FEATURE~;
		if (to_mtl_pixel_format(options.depth.format) == mtl::PixelFormat.INVALID) return UNSUPPORTED_FEATURE~;
	}

	// Resolved before any Metal object exists, so a failure needs no unwinding.
	PipelineMtl result = {
		.cull_mode = mtl_cull_mode(options.raster.cull_mode),
		.winding = mtl_winding(options.raster.front_face),
		.primitive_type = mtl_primitive_type(options.raster.topology),
		.push_constant_size = options.push_constant_size,
	};
	result.texture_slot_count = resolve_texture_slots(options.texture_bindings, &result.texture_slots)!;

	mtl::Device dev = device.backend.mtl.device;
	objc::@autoreleasepool()
	{
		mtl::RenderPipelineDescriptor desc = mtl::new_render_pipeline_descriptor();
		defer desc.release();
		desc.set_vertex_function(sh.vertex_function);
		if (sh.fragment_function) desc.set_fragment_function(sh.fragment_function);

		mtl::RenderPipelineColorAttachmentDescriptorArray attachments = desc.color_attachments();
		foreach (i, target : options.colors)
		{
			mtl::RenderPipelineColorAttachmentDescriptor a = attachments.object((mtl::NSUInteger)i);
			a.set_pixel_format(to_mtl_pixel_format(target.format));
			if (!target.has_blend)
			{
				// Keep the front-end's explicit "blend absent" state explicit in
				// the descriptor instead of relying on Metal's defaults.
				a.set_blending_enabled(false);
				a.set_write_mask(mtl::COLOR_WRITE_MASK_ALL);
				continue;
			}
			BlendState blend = target.blend;
			a.set_blending_enabled(true);
			a.set_source_rgb_blend_factor(mtl_blend_factor(blend.src_color));
			a.set_destination_rgb_blend_factor(mtl_blend_factor(blend.dst_color));
			a.set_rgb_blend_operation(mtl_blend_operation(blend.color_op));
			a.set_source_alpha_blend_factor(mtl_blend_factor(blend.src_alpha));
			a.set_destination_alpha_blend_factor(mtl_blend_factor(blend.dst_alpha));
			a.set_alpha_blend_operation(mtl_blend_operation(blend.alpha_op));
			a.set_write_mask(mtl_color_write_mask(blend.write_mask));
		}

		if (options.has_depth)
		{
			mtl::PixelFormat pixel_format = to_mtl_pixel_format(options.depth.format);
			desc.set_depth_attachment_pixel_format(pixel_format);
			// A combined format is attached to both points; Metal takes the
			// same pixel format for each.
			if (format_get_props(options.depth.format).is_stencil) desc.set_stencil_attachment_pixel_format(pixel_format);
		}

		if (options.has_vertex_layout)
		{
			// The front declares a single per-vertex layout at vertex-buffer
			// slot 0.
			mtl::NSUInteger buffer_index = (mtl::NSUInteger)MTL_VERTEX_BUFFER_BASE;
			mtl::VertexDescriptor vd = mtl::vertex_descriptor();
			foreach (attr : options.vertex_layout.attributes)
			{
				mtl::VertexAttributeDescriptor a = vd.attributes().object(attr.location);
				a.set_format(mtl_attribute_vertex_format(attr.format));
				a.set_offset(attr.offset);
				a.set_buffer_index(buffer_index);
			}
			mtl::VertexBufferLayoutDescriptor l = vd.layouts().object(buffer_index);
			l.set_stride(options.vertex_layout.stride);
			l.set_step_function(mtl::VertexStepFunction.PER_VERTEX);
			l.set_step_rate(1);
			desc.set_vertex_descriptor(vd);
		}

		mtl::NSError err = null;
		result.state = dev.new_render_pipeline_state(desc, &err);
		if (!result.state)
		{
			if (err)
			{
				log::error("MTLRenderPipelineState: %s", err.localized_description().utf8());
			}
			else
			{
				log::error("MTLRenderPipelineState creation failed");
			}
			return INITIALIZATION_FAILED~;
		}

		if (options.has_depth)
		{
			mtl::DepthStencilDescriptor dss_desc = mtl::new_depth_stencil_descriptor();
			defer dss_desc.release();
			dss_desc.set_depth_compare_function(mtl_compare_function(options.depth.compare));
			dss_desc.set_depth_write_enabled(options.depth.write);
			result.depth_stencil = dev.new_depth_stencil_state(dss_desc);
			if (!result.depth_stencil)
			{
				log::error("MTLDepthStencilState creation failed");
				result.state.release();
				return INITIALIZATION_FAILED~;
			}
		}
	};
	return { .cookie = next_cookie(), .backend.mtl = result };
}

fn void pipeline_deinit_mtl(Pipeline* p, Device* device)
{
	PipelineMtl* m = &p.backend.mtl;
	if (m.depth_stencil) m.depth_stencil.release();
	if (m.state) m.state.release();
	*m = {};
	p.cookie = 0;
}

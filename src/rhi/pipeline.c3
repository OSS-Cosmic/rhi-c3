// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral minimal graphics pipeline, port of the Vulkan arm of
// rhi-zig's pipeline.zig `init_graphics`.
module rhi;

const MAX_COLOR_ATTACHMENTS = 8;

enum VertexFormat : char
{
	FLOAT,
	FLOAT2,
	FLOAT3,
	FLOAT4,
}

struct VertexAttribute
{
	uint location;
	VertexFormat format;
	uint offset;
}

struct VertexLayout
{
	uint stride;
	VertexAttribute[] attributes;
}

enum BlendFactor : char
{
	ZERO,
	ONE,
	SRC_COLOR,
	ONE_MINUS_SRC_COLOR,
	DST_COLOR,
	ONE_MINUS_DST_COLOR,
	SRC_ALPHA,
	ONE_MINUS_SRC_ALPHA,
	DST_ALPHA,
	ONE_MINUS_DST_ALPHA,
	CONSTANT_COLOR,
	ONE_MINUS_CONSTANT_COLOR,
	CONSTANT_ALPHA,
	ONE_MINUS_CONSTANT_ALPHA,
	SRC_ALPHA_SATURATE,
}

enum BlendOp : char
{
	ADD,
	SUBTRACT,
	REVERSE_SUBTRACT,
	MIN,
	MAX,
}

enum CompareOp : char
{
	NEVER,
	LESS,
	EQUAL,
	LESS_EQUAL,
	GREATER,
	NOT_EQUAL,
	GREATER_EQUAL,
	ALWAYS,
}

enum WriteMaskFlag : char { R, G, B, A }
bitstruct WriteMask : char
{
	bool r : 0;
	bool g : 1;
	bool b : 2;
	bool a : 3;
}

const WriteMask WRITE_MASK_ALL = { .r = true, .g = true, .b = true, .a = true };

struct BlendState
{
	BlendFactor src_color;
	BlendFactor dst_color;
	BlendOp color_op;
	BlendFactor src_alpha;
	BlendFactor dst_alpha;
	BlendOp alpha_op;
	WriteMask write_mask;
}

// Straight (non-premultiplied) alpha: src.rgb*src.a + dst.rgb*(1-src.a).
const BlendState BLEND_STATE_STRAIGHT_ALPHA = { .src_color = SRC_ALPHA, .dst_color = ONE_MINUS_SRC_ALPHA, .color_op = ADD, .src_alpha = ONE, .dst_alpha = ONE_MINUS_SRC_ALPHA, .alpha_op = ADD, .write_mask = WRITE_MASK_ALL };

// Premultiplied alpha: the source already carries rgb*a.
const BlendState BLEND_STATE_PREMULTIPLIED_ALPHA = { .src_color = ONE, .dst_color = ONE_MINUS_SRC_ALPHA, .color_op = ADD, .src_alpha = ONE, .dst_alpha = ONE_MINUS_SRC_ALPHA, .alpha_op = ADD, .write_mask = WRITE_MASK_ALL };

// Additive, for glows and particles. Leaves destination alpha alone.
const BlendState BLEND_STATE_ADDITIVE = { .src_color = SRC_ALPHA, .dst_color = ONE, .color_op = ADD, .src_alpha = ZERO, .dst_alpha = ONE, .alpha_op = ADD, .write_mask = WRITE_MASK_ALL };

struct ColorTarget
{
	Format format;
	BlendState blend;
	bool has_blend;
}

struct DepthState
{
	Format format;
	bool write;
	CompareOp compare;
}

// The zero value of each raster enum is the state the Vulkan path has always
// baked: triangle list, no culling, clockwise front faces.
enum PrimitiveTopology : char
{
	TRIANGLE_LIST,
	TRIANGLE_STRIP,
	LINE_LIST,
	LINE_STRIP,
	POINT_LIST,
}

enum CullMode : char
{
	NONE,
	FRONT,
	BACK,
}

enum FrontFace : char
{
	CLOCKWISE,
	COUNTER_CLOCKWISE,
}

struct RasterState
{
	PrimitiveTopology topology;
	CullMode cull_mode;
	FrontFace front_face;
}

const MAX_TEXTURE_BINDINGS = 8;

// A texture the fragment stage reads, and the sampler it is sampled with.
// Both are addressed by name at bind time, hashed with `descriptor_name_hash`.
// An entry's index in `Pipeline_Graphics_Options.texture_bindings` is its
// WebGL2 texture unit; on WebGPU `binding`/`sampler_binding` are the
// `@binding(n)` numbers within `@group(1)` (group 0 is the push-constant
// uniform buffer). Vulkan ignores these declarations.
struct TextureBinding
{
	String name;
	uint binding;
	// Required whenever `sampler_binding` is set: a sampler descriptor is
	// matched on its name.
	String sampler_name;
	bool has_sampler_name;
	uint sampler_binding;
	bool has_sampler_binding;
}

// A `Texture_Binding` as resolved at pipeline creation.
struct TextureSlot
{
	ulong name_hash;
	ulong sampler_name_hash;
	bool has_sampler_name_hash;
	uint binding;
	uint sampler_binding;
	bool has_sampler_binding;
}

struct PipelineGraphicsOptions
{
	Shader* shader;
	ColorTarget[] colors;
	DepthState depth;
	bool has_depth;
	VertexLayout vertex_layout;
	bool has_vertex_layout;
	RasterState raster;
	uint push_constant_size;
	TextureBinding[] texture_bindings;
}

struct Pipeline
{
	ulong cookie;
	union backend
	{
		PipelineVk vk;
		PipelineMtl mtl;
		PipelineWgpu wgpu;
		PipelineWebgl webgl;
		PipelineDx12 dx12;
	}
}

// Hashes a slot's declared names once, so binding a descriptor to it is a
// hash compare. A sampler binding with no name would be unaddressable.
fn TextureSlot? resolve_texture_slot(TextureBinding tb)
{
	if (tb.has_sampler_binding && !tb.has_sampler_name) return SAMPLER_NAME_REQUIRED~;
	TextureSlot slot = {
		.name_hash = descriptor_name_hash(tb.name),
		.binding = tb.binding,
		.sampler_binding = tb.sampler_binding,
		.has_sampler_binding = tb.has_sampler_binding,
	};
	if (tb.has_sampler_name)
	{
		slot.sampler_name_hash = descriptor_name_hash(tb.sampler_name);
		slot.has_sampler_name_hash = true;
	}
	return slot;
}

// Resolves every declared texture binding into `out`, returning the count.
fn uint? resolve_texture_slots(TextureBinding[] bindings, TextureSlot[MAX_TEXTURE_BINDINGS]* out)
{
	if (bindings.len > MAX_TEXTURE_BINDINGS) return TOO_MANY_TEXTURE_BINDINGS~;
	foreach (i, tb : bindings)
	{
		(*out)[i] = resolve_texture_slot(tb)!;
	}
	return (uint)bindings.len;
}

fn Pipeline? pipeline_init_graphics(Device* device, PipelineGraphicsOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return pipeline_init_graphics_vk(device, options);
			$endif
		case DX12:
			$if HAS_DX12:
				return pipeline_init_graphics_dx12(device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				return pipeline_init_graphics_mtl(device, options);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return pipeline_init_graphics_wgpu(device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return pipeline_init_graphics_webgl(device, options);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void pipeline_deinit(Pipeline* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				pipeline_deinit_vk(p, device);
			$endif
		case DX12:
			$if HAS_DX12:
				pipeline_deinit_dx12(p, device);
			$endif
		case MTL:
			$if HAS_MTL:
				pipeline_deinit_mtl(p, device);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				pipeline_deinit_wgpu(p, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				pipeline_deinit_webgl(p, device);
			$endif
	}
}

fn bool pipeline_is_empty(Pipeline* p)
{
	return p.cookie == 0;
}

// ---- metal ----

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

// ---- dx12 ----

// Direct3D 12 graphics pipeline: a root signature plus a graphics PSO.
//
// Root signature layout (parameter index in brackets):
//   [0] push constants as 32-bit root constants at b0 (when push_constant_size > 0)
//   next: SRV descriptor table, t0.. one per texture binding
//   next: sampler descriptor table, s0.. one per texture binding
// Viewport and scissor are dynamic by nature in D3D12.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct PipelineDx12
{
	// Owned.
	d3d12::PipelineState* state;
	// Owned.
	d3d12::RootSignature* root_signature;
	// Set on the command list at draw time rather than baked into the PSO.
	d3d12::PrimitiveTopology topology;
	uint push_constant_size;
	// Root parameter indices, or `uint::max` when absent.
	uint push_constant_param;
	uint srv_table_param;
	uint sampler_table_param;
	// Vertex buffer slot 0 stride, for IASetVertexBuffers.
	uint vertex_stride;
	TextureSlot[MAX_TEXTURE_BINDINGS] texture_slots;
	uint texture_slot_count;
}

fn dxgi::Format dx12_vertex_format(VertexFormat format) @local
{
	switch (format)
	{
		case FLOAT: return dxgi::Format.R32_FLOAT;
		case FLOAT2: return dxgi::Format.R32G32_FLOAT;
		case FLOAT3: return dxgi::Format.R32G32B32_FLOAT;
		case FLOAT4: return dxgi::Format.R32G32B32A32_FLOAT;
	}
}

fn d3d12::Blend dx12_blend(BlendFactor factor) @local
{
	switch (factor)
	{
		case ZERO: return d3d12::Blend.ZERO;
		case ONE: return d3d12::Blend.ONE;
		case SRC_COLOR: return d3d12::Blend.SRC_COLOR;
		case ONE_MINUS_SRC_COLOR: return d3d12::Blend.INV_SRC_COLOR;
		case DST_COLOR: return d3d12::Blend.DEST_COLOR;
		case ONE_MINUS_DST_COLOR: return d3d12::Blend.INV_DEST_COLOR;
		case SRC_ALPHA: return d3d12::Blend.SRC_ALPHA;
		case ONE_MINUS_SRC_ALPHA: return d3d12::Blend.INV_SRC_ALPHA;
		case DST_ALPHA: return d3d12::Blend.DEST_ALPHA;
		case ONE_MINUS_DST_ALPHA: return d3d12::Blend.INV_DEST_ALPHA;
		case CONSTANT_COLOR:
		case CONSTANT_ALPHA: return d3d12::Blend.BLEND_FACTOR;
		case ONE_MINUS_CONSTANT_COLOR:
		case ONE_MINUS_CONSTANT_ALPHA: return d3d12::Blend.INV_BLEND_FACTOR;
		case SRC_ALPHA_SATURATE: return d3d12::Blend.SRC_ALPHA_SAT;
	}
}

fn d3d12::BlendOp dx12_blend_op(BlendOp op) @local
{
	switch (op)
	{
		case ADD: return d3d12::BlendOp.ADD;
		case SUBTRACT: return d3d12::BlendOp.SUBTRACT;
		case REVERSE_SUBTRACT: return d3d12::BlendOp.REV_SUBTRACT;
		case MIN: return d3d12::BlendOp.MIN;
		case MAX: return d3d12::BlendOp.MAX;
	}
}

fn d3d12::ComparisonFunc dx12_compare_func(CompareOp op) @local
{
	switch (op)
	{
		case NEVER: return d3d12::ComparisonFunc.NEVER;
		case LESS: return d3d12::ComparisonFunc.LESS;
		case EQUAL: return d3d12::ComparisonFunc.EQUAL;
		case LESS_EQUAL: return d3d12::ComparisonFunc.LESS_EQUAL;
		case GREATER: return d3d12::ComparisonFunc.GREATER;
		case NOT_EQUAL: return d3d12::ComparisonFunc.NOT_EQUAL;
		case GREATER_EQUAL: return d3d12::ComparisonFunc.GREATER_EQUAL;
		case ALWAYS: return d3d12::ComparisonFunc.ALWAYS;
	}
}

fn d3d12::CullMode dx12_cull_mode(CullMode mode) @local
{
	switch (mode)
	{
		case NONE: return d3d12::CullMode.NONE;
		case FRONT: return d3d12::CullMode.FRONT;
		case BACK: return d3d12::CullMode.BACK;
	}
}

fn d3d12::PrimitiveTopologyType dx12_topology_type(PrimitiveTopology topology) @local
{
	switch (topology)
	{
		case POINT_LIST: return d3d12::PrimitiveTopologyType.POINT;
		case LINE_LIST:
		case LINE_STRIP: return d3d12::PrimitiveTopologyType.LINE;
		case TRIANGLE_LIST:
		case TRIANGLE_STRIP: return d3d12::PrimitiveTopologyType.TRIANGLE;
	}
}

fn d3d12::PrimitiveTopology dx12_topology(PrimitiveTopology topology) @local
{
	switch (topology)
	{
		case POINT_LIST: return d3d12::PrimitiveTopology.POINTLIST;
		case LINE_LIST: return d3d12::PrimitiveTopology.LINELIST;
		case LINE_STRIP: return d3d12::PrimitiveTopology.LINESTRIP;
		case TRIANGLE_LIST: return d3d12::PrimitiveTopology.TRIANGLELIST;
		case TRIANGLE_STRIP: return d3d12::PrimitiveTopology.TRIANGLESTRIP;
	}
}

// Serializes and creates the root signature described in the file header.
fn void? dx12_create_root_signature(d3d12::Device* dev, PipelineDx12* out, d3d12::RootSignature** out_signature) @local
{
	d3d12::RootParameter[3] params = {};
	d3d12::DescriptorRange[2] ranges = {};
	uint count = 0;

	if (out.push_constant_size > 0)
	{
		out.push_constant_param = count;
		params[count++] = {
			.parameter_type = d3d12::RootParameterType.CONSTANTS_32BIT,
			.constants = { .shader_register = 0, .register_space = 0, .num_32bit_values = (out.push_constant_size + 3) / 4 },
			.shader_visibility = d3d12::ShaderVisibility.ALL,
		};
	}
	if (out.texture_slot_count > 0)
	{
		ranges[0] = {
			.range_type = d3d12::DescriptorRangeType.SRV,
			.num_descriptors = out.texture_slot_count,
			.base_shader_register = 0,
			.register_space = 0,
			.offset_in_descriptors_from_table_start = d3d12::APPEND_ALIGNED_ELEMENT,
		};
		ranges[1] = {
			.range_type = d3d12::DescriptorRangeType.SAMPLER,
			.num_descriptors = out.texture_slot_count,
			.base_shader_register = 0,
			.register_space = 0,
			.offset_in_descriptors_from_table_start = d3d12::APPEND_ALIGNED_ELEMENT,
		};
		out.srv_table_param = count;
		params[count++] = {
			.parameter_type = d3d12::RootParameterType.DESCRIPTOR_TABLE,
			.descriptor_table = { .num_descriptor_ranges = 1, .descriptor_ranges = &ranges[0] },
			.shader_visibility = d3d12::ShaderVisibility.PIXEL,
		};
		out.sampler_table_param = count;
		params[count++] = {
			.parameter_type = d3d12::RootParameterType.DESCRIPTOR_TABLE,
			.descriptor_table = { .num_descriptor_ranges = 1, .descriptor_ranges = &ranges[1] },
			.shader_visibility = d3d12::ShaderVisibility.PIXEL,
		};
	}

	d3d12::RootSignatureDesc desc = {
		.num_parameters = count,
		.parameters = count > 0 ? &params[0] : null,
		.flags = d3d12::ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
	};

	dxgi::Blob* blob;
	dxgi::Blob* error_blob;
	dxgi::HResult hr = d3d12::serialize_root_signature(&desc, d3d12::RootSignatureVersion.V1_0, &blob, &error_blob);
	if (error_blob) dxgi::release(error_blob);
	if (dxgi::failed(hr) || !blob)
	{
		if (blob) dxgi::release(blob);
		return INITIALIZATION_FAILED~;
	}
	defer dxgi::release(blob);

	Guid iid = d3d12::IID_ROOT_SIGNATURE;
	dx12_check(dev.vtbl.create_root_signature(
		dev, 0, blob.vtbl.get_buffer_pointer(blob), blob.vtbl.get_buffer_size(blob), &iid, (void**)out_signature))!;
}

fn Pipeline? pipeline_init_graphics_dx12(Device* device, PipelineGraphicsOptions options)
{
	if (options.colors.len > MAX_COLOR_ATTACHMENTS) return MULTIPLE_RENDER_TARGETS_UNSUPPORTED~;
	ShaderDx12* shader = &options.shader.backend.dx12;
	if (shader.vertex.len == 0) return MISSING_SHADER_STAGE~;

	foreach (target : options.colors)
	{
		if (format_to_dxgi(target.format) == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	}
	if (options.has_depth)
	{
		if (!format_get_props(options.depth.format).is_depth) return UNSUPPORTED_FEATURE~;
		if (format_to_dxgi(options.depth.format) == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	}
	if (options.has_vertex_layout) assert(options.vertex_layout.attributes.len <= MAX_COLOR_ATTACHMENTS);

	PipelineDx12 result = {
		.topology = dx12_topology(options.raster.topology),
		.push_constant_size = options.push_constant_size,
		.push_constant_param = uint::max,
		.srv_table_param = uint::max,
		.sampler_table_param = uint::max,
		.vertex_stride = options.has_vertex_layout ? options.vertex_layout.stride : 0,
	};
	result.texture_slot_count = resolve_texture_slots(options.texture_bindings, &result.texture_slots)!;

	d3d12::Device* dev = device.backend.dx12.device;
	d3d12::RootSignature* root_signature;
	dx12_create_root_signature(dev, &result, &root_signature)!;

	d3d12::GraphicsPipelineStateDesc desc = {
		.root_signature = root_signature,
		.vs = shader_bytecode_dx12(shader.vertex),
		.ps = shader_bytecode_dx12(shader.pixel),
		.ds = shader_bytecode_dx12(shader.domain),
		.hs = shader_bytecode_dx12(shader.hull),
		.gs = shader_bytecode_dx12(shader.geometry),
		.sample_mask = 0xFFFFFFFF,
		.rasterizer_state = {
			.fill_mode = d3d12::FillMode.SOLID,
			.cull_mode = dx12_cull_mode(options.raster.cull_mode),
			.front_counter_clockwise = options.raster.front_face == COUNTER_CLOCKWISE ? 1 : 0,
			.depth_clip_enable = 1,
			.conservative_raster = d3d12::ConservativeRasterizationMode.OFF,
		},
		.depth_stencil_state = {
			.depth_enable = options.has_depth ? 1 : 0,
			.depth_write_mask = options.has_depth && options.depth.write ? d3d12::DepthWriteMask.ALL : d3d12::DepthWriteMask.ZERO,
			.depth_func = options.has_depth ? dx12_compare_func(options.depth.compare) : d3d12::ComparisonFunc.LESS,
		},
		.ib_strip_cut_value = d3d12::IndexBufferStripCutValue.DISABLED,
		.primitive_topology_type = dx12_topology_type(options.raster.topology),
		.num_render_targets = (uint)options.colors.len,
		.dsv_format = options.has_depth ? format_to_dxgi(options.depth.format) : dxgi::Format.UNKNOWN,
		.sample_desc = { .count = 1, .quality = 0 },
		.flags = d3d12::PIPELINE_STATE_FLAG_NONE,
	};
	desc.blend_state.independent_blend_enable = 1;

	foreach (i, target : options.colors)
	{
		BlendState blend = {
			.src_color = ONE,
			.dst_color = ZERO,
			.color_op = ADD,
			.src_alpha = ONE,
			.dst_alpha = ZERO,
			.alpha_op = ADD,
			.write_mask = WRITE_MASK_ALL,
		};
		if (target.has_blend) blend = target.blend;

		d3d12::ColorWriteEnable write_mask = 0;
		if (blend.write_mask.r) write_mask |= d3d12::COLOR_WRITE_ENABLE_RED;
		if (blend.write_mask.g) write_mask |= d3d12::COLOR_WRITE_ENABLE_GREEN;
		if (blend.write_mask.b) write_mask |= d3d12::COLOR_WRITE_ENABLE_BLUE;
		if (blend.write_mask.a) write_mask |= d3d12::COLOR_WRITE_ENABLE_ALPHA;

		desc.rtv_formats[i] = format_to_dxgi(target.format);
		desc.blend_state.render_target[i] = {
			.blend_enable = target.has_blend ? 1 : 0,
			.logic_op_enable = 0,
			.src_blend = dx12_blend(blend.src_color),
			.dest_blend = dx12_blend(blend.dst_color),
			.blend_op = dx12_blend_op(blend.color_op),
			.src_blend_alpha = dx12_blend(blend.src_alpha),
			.dest_blend_alpha = dx12_blend(blend.dst_alpha),
			.blend_op_alpha = dx12_blend_op(blend.alpha_op),
			.logic_op = d3d12::LogicOp.NOOP,
			.render_target_write_mask = write_mask,
		};
	}

	// DXC lowers `[[vk::location(n)]]` / GLSL `location = n` inputs to
	// TEXCOORDn, so attributes are matched by location through that semantic.
	d3d12::InputElementDesc[MAX_COLOR_ATTACHMENTS] elements = {};
	if (options.has_vertex_layout)
	{
		foreach (i, attribute : options.vertex_layout.attributes)
		{
			elements[i] = {
				.semantic_name = "TEXCOORD",
				.semantic_index = attribute.location,
				.format = dx12_vertex_format(attribute.format),
				.input_slot = 0,
				.aligned_byte_offset = attribute.offset,
				.input_slot_class = d3d12::InputClassification.PER_VERTEX_DATA,
				.instance_data_step_rate = 0,
			};
		}
		desc.input_layout = {
			.input_element_descs = &elements[0],
			.num_elements = (uint)options.vertex_layout.attributes.len,
		};
	}

	d3d12::PipelineState* state;
	Guid iid = d3d12::IID_PIPELINE_STATE;
	if (catch err = dx12_check(dev.vtbl.create_graphics_pipeline_state(dev, &desc, &iid, (void**)&state)))
	{
		dxgi::release(root_signature);
		return err~;
	}

	result.state = state;
	result.root_signature = root_signature;
	return {
		.cookie = next_cookie(),
		.backend.dx12 = result,
	};
}

fn void pipeline_deinit_dx12(Pipeline* pipeline, Device* device)
{
	PipelineDx12* state = &pipeline.backend.dx12;
	if (state.state) dxgi::release(state.state);
	if (state.root_signature) dxgi::release(state.root_signature);
	*state = {};
	pipeline.cookie = 0;
}

// ---- vulkan ----

module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import vk;

struct PipelineVk
{
	vk::Pipeline pipeline;
	vk::PipelineLayout layout;
}

fn vk::BlendFactor to_vk_blend_factor(BlendFactor factor) @private
{
	switch (factor)
	{
	case ZERO: return vk::BlendFactor.ZERO;
	case ONE: return vk::BlendFactor.ONE;
	case SRC_COLOR: return vk::BlendFactor.SRC_COLOR;
	case ONE_MINUS_SRC_COLOR: return vk::BlendFactor.ONE_MINUS_SRC_COLOR;
	case DST_COLOR: return vk::BlendFactor.DST_COLOR;
	case ONE_MINUS_DST_COLOR: return vk::BlendFactor.ONE_MINUS_DST_COLOR;
	case SRC_ALPHA: return vk::BlendFactor.SRC_ALPHA;
	case ONE_MINUS_SRC_ALPHA: return vk::BlendFactor.ONE_MINUS_SRC_ALPHA;
	case DST_ALPHA: return vk::BlendFactor.DST_ALPHA;
	case ONE_MINUS_DST_ALPHA: return vk::BlendFactor.ONE_MINUS_DST_ALPHA;
	case CONSTANT_COLOR: return vk::BlendFactor.CONSTANT_COLOR;
	case ONE_MINUS_CONSTANT_COLOR: return vk::BlendFactor.ONE_MINUS_CONSTANT_COLOR;
	case CONSTANT_ALPHA: return vk::BlendFactor.CONSTANT_ALPHA;
	case ONE_MINUS_CONSTANT_ALPHA: return vk::BlendFactor.ONE_MINUS_CONSTANT_ALPHA;
	case SRC_ALPHA_SATURATE: return vk::BlendFactor.SRC_ALPHA_SATURATE;
	}
}

fn vk::BlendOp to_vk_blend_op(BlendOp op) @private
{
	switch (op)
	{
	case ADD: return vk::BlendOp.ADD;
	case SUBTRACT: return vk::BlendOp.SUBTRACT;
	case REVERSE_SUBTRACT: return vk::BlendOp.REVERSE_SUBTRACT;
	case MIN: return vk::BlendOp.MIN;
	case MAX: return vk::BlendOp.MAX;
	}
}

fn vk::CompareOp to_vk_compare_op(CompareOp op) @private
{
	switch (op)
	{
	case NEVER: return vk::CompareOp.NEVER;
	case LESS: return vk::CompareOp.LESS;
	case EQUAL: return vk::CompareOp.EQUAL;
	case LESS_EQUAL: return vk::CompareOp.LESS_OR_EQUAL;
	case GREATER: return vk::CompareOp.GREATER;
	case NOT_EQUAL: return vk::CompareOp.NOT_EQUAL;
	case GREATER_EQUAL: return vk::CompareOp.GREATER_OR_EQUAL;
	case ALWAYS: return vk::CompareOp.ALWAYS;
	}
}

fn vk::Format to_vk_vertex_format(VertexFormat format) @private
{
	switch (format)
	{
	case FLOAT: return vk::Format.R32_SFLOAT;
	case FLOAT2: return vk::Format.R32G32_SFLOAT;
	case FLOAT3: return vk::Format.R32G32B32_SFLOAT;
	case FLOAT4: return vk::Format.R32G32B32A32_SFLOAT;
	}
}

fn vk::PrimitiveTopology to_vk_topology(PrimitiveTopology topology) @private
{
	switch (topology)
	{
	case POINT_LIST: return vk::PrimitiveTopology.POINT_LIST;
	case LINE_LIST: return vk::PrimitiveTopology.LINE_LIST;
	case LINE_STRIP: return vk::PrimitiveTopology.LINE_STRIP;
	case TRIANGLE_LIST: return vk::PrimitiveTopology.TRIANGLE_LIST;
	case TRIANGLE_STRIP: return vk::PrimitiveTopology.TRIANGLE_STRIP;
	}
}

fn vk::CullModeFlags to_vk_cull_mode(CullMode mode) @private
{
	switch (mode)
	{
	case NONE: return 0;
	case FRONT: return vk::CULL_MODE_FRONT_BIT;
	case BACK: return vk::CULL_MODE_BACK_BIT;
	}
}

fn vk::FrontFace to_vk_front_face(FrontFace face) @private
{
	switch (face)
	{
	case CLOCKWISE: return vk::FrontFace.CLOCKWISE;
	case COUNTER_CLOCKWISE: return vk::FrontFace.COUNTER_CLOCKWISE;
	}
}

fn Pipeline? pipeline_init_graphics_vk(Device* device, PipelineGraphicsOptions options)
{
	ShaderVk shader = options.shader.backend.vk;
	assert(options.colors.len <= MAX_COLOR_ATTACHMENTS);

	vk::PipelineShaderStageCreateInfo[2] stages = {
		{
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_VERTEX_BIT,
			.module_ = shader.vertex_module,
			.pName = "main",
		},
		{
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_FRAGMENT_BIT,
			.module_ = shader.pixel_module,
			.pName = "main",
		},
	};

	vk::PipelineColorBlendAttachmentState[MAX_COLOR_ATTACHMENTS] color_attachments = {};
	vk::Format[MAX_COLOR_ATTACHMENTS] color_formats = {};
	foreach (i, target : options.colors) {
		BlendState blend = {
			.src_color = ONE,
			.dst_color = ZERO,
			.color_op = ADD,
			.src_alpha = ONE,
			.dst_alpha = ZERO,
			.alpha_op = ADD,
			.write_mask = WRITE_MASK_ALL,
		};
		if (target.has_blend) blend = target.blend;

		vk::ColorComponentFlags write_mask = 0;
		if (blend.write_mask.r) write_mask |= vk::COLOR_COMPONENT_R_BIT;
		if (blend.write_mask.g) write_mask |= vk::COLOR_COMPONENT_G_BIT;
		if (blend.write_mask.b) write_mask |= vk::COLOR_COMPONENT_B_BIT;
		if (blend.write_mask.a) write_mask |= vk::COLOR_COMPONENT_A_BIT;

		color_formats[i] = to_vk_format(target.format);
		color_attachments[i] = {
			.blendEnable = target.has_blend ? vk::TRUE : vk::FALSE,
			.srcColorBlendFactor = to_vk_blend_factor(blend.src_color),
			.dstColorBlendFactor = to_vk_blend_factor(blend.dst_color),
			.colorBlendOp = to_vk_blend_op(blend.color_op),
			.srcAlphaBlendFactor = to_vk_blend_factor(blend.src_alpha),
			.dstAlphaBlendFactor = to_vk_blend_factor(blend.dst_alpha),
			.alphaBlendOp = to_vk_blend_op(blend.alpha_op),
			.colorWriteMask = write_mask,
		};
	}

	vk::DynamicState[2] dynamic_states = {
		vk::DynamicState.VIEWPORT,
		vk::DynamicState.SCISSOR,
	};
	vk::PipelineDynamicStateCreateInfo dynamic_state = {
		.sType = vk::StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		.dynamicStateCount = dynamic_states.len,
		.pDynamicStates = &dynamic_states[0],
	};
	vk::PipelineColorBlendStateCreateInfo color_blend = {
		.sType = vk::StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		.logicOpEnable = vk::FALSE,
		.logicOp = vk::LogicOp.CLEAR,
		.attachmentCount = options.colors.len,
		.pAttachments = &color_attachments[0],
		.blendConstants = { 0, 0, 0, 0 },
	};
	vk::PipelineViewportStateCreateInfo viewport = {
		.sType = vk::StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = 1,
		.scissorCount = 1,
	};

	vk::PipelineRasterizationStateCreateInfo rasterization = {
		.sType = vk::StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		.depthClampEnable = vk::FALSE,
		.rasterizerDiscardEnable = vk::FALSE,
		.polygonMode = vk::PolygonMode.FILL,
		.cullMode = to_vk_cull_mode(options.raster.cull_mode),
		.frontFace = to_vk_front_face(options.raster.front_face),
		.depthBiasEnable = vk::FALSE,
		.lineWidth = 1.0,
	};
	vk::PipelineInputAssemblyStateCreateInfo input_assembly = {
		.sType = vk::StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		.topology = to_vk_topology(options.raster.topology),
		.primitiveRestartEnable = vk::FALSE,
	};
	vk::PipelineMultisampleStateCreateInfo multisample = {
		.sType = vk::StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		.rasterizationSamples = vk::SAMPLE_COUNT_1_BIT,
		.sampleShadingEnable = vk::FALSE,
	};

	vk::VertexInputBindingDescription binding = {};
	vk::VertexInputAttributeDescription[MAX_COLOR_ATTACHMENTS] attributes = {};
	vk::PipelineVertexInputStateCreateInfo vertex_input = {
		.sType = vk::StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
	};
	if (options.has_vertex_layout) {
		assert(options.vertex_layout.attributes.len <= MAX_COLOR_ATTACHMENTS);
		binding = {
			.binding = 0,
			.stride = options.vertex_layout.stride,
			.inputRate = vk::VertexInputRate.VERTEX,
		};
		foreach (i, attribute : options.vertex_layout.attributes) {
			attributes[i] = {
				.location = attribute.location,
				.binding = 0,
				.format = to_vk_vertex_format(attribute.format),
				.offset = attribute.offset,
			};
		}
		vertex_input.vertexBindingDescriptionCount = 1;
		vertex_input.pVertexBindingDescriptions = &binding;
		vertex_input.vertexAttributeDescriptionCount = options.vertex_layout.attributes.len;
		vertex_input.pVertexAttributeDescriptions = &attributes[0];
	}

	vk::PushConstantRange[1] push_constants = {};
	vk::PipelineLayoutCreateInfo layout_info = {
		.sType = vk::StructureType.PIPELINE_LAYOUT_CREATE_INFO,
	};
	if (options.push_constant_size > 0) {
		push_constants[0] = {
			.stageFlags = vk::SHADER_STAGE_VERTEX_BIT,
			.offset = 0,
			.size = options.push_constant_size,
		};
		layout_info.pushConstantRangeCount = 1;
		layout_info.pPushConstantRanges = &push_constants[0];
	}

	vk::PipelineLayout layout;
	vk_check(device.backend.vk.vtable.createPipelineLayout(device.backend.vk.device, &layout_info, null, &layout))!;

	vk::PipelineDepthStencilStateCreateInfo depth_stencil = {
		.sType = vk::StructureType.PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		.depthTestEnable = options.has_depth ? vk::TRUE : vk::FALSE,
		.depthWriteEnable = options.has_depth && options.depth.write ? vk::TRUE : vk::FALSE,
		.depthCompareOp = options.has_depth ? to_vk_compare_op(options.depth.compare) : vk::CompareOp.LESS,
		.depthBoundsTestEnable = vk::FALSE,
		.stencilTestEnable = vk::FALSE,
		.minDepthBounds = 0.0,
		.maxDepthBounds = 1.0,
	};

	vk::PipelineRenderingCreateInfo rendering = {
		.sType = vk::StructureType.PIPELINE_RENDERING_CREATE_INFO,
		.colorAttachmentCount = options.colors.len,
		.pColorAttachmentFormats = &color_formats[0],
		.depthAttachmentFormat = options.has_depth ? to_vk_format(options.depth.format) : vk::Format.UNDEFINED,
		.stencilAttachmentFormat = options.has_depth && format_get_props(options.depth.format).is_stencil
			? to_vk_format(options.depth.format)
			: vk::Format.UNDEFINED,
	};

	vk::GraphicsPipelineCreateInfo pipeline_info = {
		.sType = vk::StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
		.stageCount = stages.len,
		.pStages = &stages[0],
		.pVertexInputState = &vertex_input,
		.pInputAssemblyState = &input_assembly,
		.pViewportState = &viewport,
		.pRasterizationState = &rasterization,
		.pMultisampleState = &multisample,
		.pDepthStencilState = &depth_stencil,
		.pColorBlendState = &color_blend,
		.pDynamicState = &dynamic_state,
		.layout = layout,
		.basePipelineIndex = -1,
	};
	vk_add_next(&pipeline_info, &rendering);

	vk::Pipeline pipeline;
	if (catch err = vk_check(device.backend.vk.vtable.createGraphicsPipelines(
		device.backend.vk.device, vk::NULL_HANDLE, 1, &pipeline_info, null, &pipeline))) {
		device.backend.vk.vtable.destroyPipelineLayout(device.backend.vk.device, layout, null);
		return err~;
	}

	return {
		.cookie = next_cookie(),
		.backend.vk = { .pipeline = pipeline, .layout = layout },
	};
}

fn void pipeline_deinit_vk(Pipeline* pipeline, Device* device)
{
	if (pipeline.backend.vk.pipeline != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyPipeline(device.backend.vk.device, pipeline.backend.vk.pipeline, null);
	}
	if (pipeline.backend.vk.layout != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyPipelineLayout(device.backend.vk.device, pipeline.backend.vk.layout, null);
	}
	pipeline.backend.vk = {};
	pipeline.cookie = 0;
}

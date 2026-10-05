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

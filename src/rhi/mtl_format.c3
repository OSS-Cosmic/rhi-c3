// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal enum mapping: rhi formats and pipeline/sampler state to their MTL
// equivalents. The pixel format table extends rhi-zig's `metal.zig`
// `to_mtl_pixel_format`, and the vertex format and compare function mappings
// extend `pipeline.zig`'s `mtl_vertex_format` and `CompareOp.to_mtl`. The
// blend, sampler and raster mappings are new (rhi-zig has no blending).
//
// Depth/stencil queries go through `format_get_props(f).is_depth` /
// `.is_stencil`.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct MtlFormatMapping
{
	Format rhi;
	mtl::PixelFormat mtl;
}

// rhi-zig only mapped RGBA8_UNORM, BGRA8_UNORM, BGRA8_SRGB and D32_SFLOAT;
// every other row is an extension. Formats without an equivalent
// MTLPixelFormat have no row and resolve to `INVALID`: luminance formats,
// 24-bit RGB/BGR, RGB32, D16_UNORM_S8_UINT, R24_UNORM_X8 and
// R32_SFLOAT_X8_X24. Depth24Unorm_Stencil8 is available on macOS Intel/AMD
// devices (but not Apple GPUs), so it is still the correct macOS mapping.
const MtlFormatMapping[*] MTL_FORMAT_MAPPINGS = {
	{ .rhi = Format.UNKNOWN, .mtl = mtl::PixelFormat.INVALID },
	{ .rhi = Format.A8_UNORM, .mtl = mtl::PixelFormat.A8UNORM },
	{ .rhi = Format.D32_SFLOAT_S8_UINT, .mtl = mtl::PixelFormat.DEPTH32FLOAT_STENCIL8 },
	{ .rhi = Format.R8_UNORM, .mtl = mtl::PixelFormat.R8UNORM },
	{ .rhi = Format.R8_SNORM, .mtl = mtl::PixelFormat.R8SNORM },
	{ .rhi = Format.R8_UINT, .mtl = mtl::PixelFormat.R8UINT },
	{ .rhi = Format.R8_SINT, .mtl = mtl::PixelFormat.R8SINT },
	{ .rhi = Format.RG8_UNORM, .mtl = mtl::PixelFormat.RG8UNORM },
	{ .rhi = Format.RG8_SNORM, .mtl = mtl::PixelFormat.RG8SNORM },
	{ .rhi = Format.RG8_UINT, .mtl = mtl::PixelFormat.RG8UINT },
	{ .rhi = Format.RG8_SINT, .mtl = mtl::PixelFormat.RG8SINT },
	{ .rhi = Format.BGRA8_UNORM, .mtl = mtl::PixelFormat.BGRA8UNORM },
	{ .rhi = Format.BGRA8_SRGB, .mtl = mtl::PixelFormat.BGRA8UNORM_SRGB },
	{ .rhi = Format.RGBA8_UNORM, .mtl = mtl::PixelFormat.RGBA8UNORM },
	{ .rhi = Format.RGBA8_SNORM, .mtl = mtl::PixelFormat.RGBA8SNORM },
	{ .rhi = Format.RGBA8_UINT, .mtl = mtl::PixelFormat.RGBA8UINT },
	{ .rhi = Format.RGBA8_SINT, .mtl = mtl::PixelFormat.RGBA8SINT },
	{ .rhi = Format.RGBA8_SRGB, .mtl = mtl::PixelFormat.RGBA8UNORM_SRGB },
	{ .rhi = Format.R16_UNORM, .mtl = mtl::PixelFormat.R16UNORM },
	{ .rhi = Format.R16_SNORM, .mtl = mtl::PixelFormat.R16SNORM },
	{ .rhi = Format.R16_UINT, .mtl = mtl::PixelFormat.R16UINT },
	{ .rhi = Format.R16_SINT, .mtl = mtl::PixelFormat.R16SINT },
	{ .rhi = Format.R16_SFLOAT, .mtl = mtl::PixelFormat.R16FLOAT },
	{ .rhi = Format.RG16_UNORM, .mtl = mtl::PixelFormat.RG16UNORM },
	{ .rhi = Format.RG16_SNORM, .mtl = mtl::PixelFormat.RG16SNORM },
	{ .rhi = Format.RG16_UINT, .mtl = mtl::PixelFormat.RG16UINT },
	{ .rhi = Format.RG16_SINT, .mtl = mtl::PixelFormat.RG16SINT },
	{ .rhi = Format.RG16_SFLOAT, .mtl = mtl::PixelFormat.RG16FLOAT },
	{ .rhi = Format.RGBA16_UNORM, .mtl = mtl::PixelFormat.RGBA16UNORM },
	{ .rhi = Format.RGBA16_SNORM, .mtl = mtl::PixelFormat.RGBA16SNORM },
	{ .rhi = Format.RGBA16_UINT, .mtl = mtl::PixelFormat.RGBA16UINT },
	{ .rhi = Format.RGBA16_SINT, .mtl = mtl::PixelFormat.RGBA16SINT },
	{ .rhi = Format.RGBA16_SFLOAT, .mtl = mtl::PixelFormat.RGBA16FLOAT },
	{ .rhi = Format.R32_UINT, .mtl = mtl::PixelFormat.R32UINT },
	{ .rhi = Format.R32_SINT, .mtl = mtl::PixelFormat.R32SINT },
	{ .rhi = Format.R32_SFLOAT, .mtl = mtl::PixelFormat.R32FLOAT },
	{ .rhi = Format.RG32_UINT, .mtl = mtl::PixelFormat.RG32UINT },
	{ .rhi = Format.RG32_SINT, .mtl = mtl::PixelFormat.RG32SINT },
	{ .rhi = Format.RG32_SFLOAT, .mtl = mtl::PixelFormat.RG32FLOAT },
	{ .rhi = Format.RGBA32_UINT, .mtl = mtl::PixelFormat.RGBA32UINT },
	{ .rhi = Format.RGBA32_SINT, .mtl = mtl::PixelFormat.RGBA32SINT },
	{ .rhi = Format.RGBA32_SFLOAT, .mtl = mtl::PixelFormat.RGBA32FLOAT },
	{ .rhi = Format.R10_G10_B10_A2_UNORM, .mtl = mtl::PixelFormat.RGB10A2UNORM },
	{ .rhi = Format.R10_G10_B10_A2_UINT, .mtl = mtl::PixelFormat.RGB10A2UINT },
	{ .rhi = Format.R11_G11_B10_UFLOAT, .mtl = mtl::PixelFormat.RG11B10FLOAT },
	{ .rhi = Format.R9_G9_B9_E5_UNORM, .mtl = mtl::PixelFormat.RGB9E5FLOAT },
	// Packed 16-bit formats: Apple GPUs only (not Intel/AMD Macs).
	{ .rhi = Format.R5_G6_B5_UNORM, .mtl = mtl::PixelFormat.B5G6R5UNORM },
	{ .rhi = Format.R5_G5_B5_A1_UNORM, .mtl = mtl::PixelFormat.BGR5A1UNORM },
	{ .rhi = Format.R4_G4_B4_A4_UNORM, .mtl = mtl::PixelFormat.ABGR4UNORM },
	{ .rhi = Format.BC1_RGBA_UNORM, .mtl = mtl::PixelFormat.BC1_RGBA },
	{ .rhi = Format.BC1_RGBA_SRGB, .mtl = mtl::PixelFormat.BC1_RGBA_SRGB },
	{ .rhi = Format.BC2_RGBA_UNORM, .mtl = mtl::PixelFormat.BC2_RGBA },
	{ .rhi = Format.BC2_RGBA_SRGB, .mtl = mtl::PixelFormat.BC2_RGBA_SRGB },
	{ .rhi = Format.BC3_RGBA_UNORM, .mtl = mtl::PixelFormat.BC3_RGBA },
	{ .rhi = Format.BC3_RGBA_SRGB, .mtl = mtl::PixelFormat.BC3_RGBA_SRGB },
	{ .rhi = Format.BC4_R_UNORM, .mtl = mtl::PixelFormat.BC4_RUNORM },
	{ .rhi = Format.BC4_R_SNORM, .mtl = mtl::PixelFormat.BC4_RSNORM },
	{ .rhi = Format.BC5_RG_UNORM, .mtl = mtl::PixelFormat.BC5_RGUNORM },
	{ .rhi = Format.BC5_RG_SNORM, .mtl = mtl::PixelFormat.BC5_RGSNORM },
	{ .rhi = Format.BC6H_RGB_UFLOAT, .mtl = mtl::PixelFormat.BC6H_RGBUFLOAT },
	{ .rhi = Format.BC6H_RGB_SFLOAT, .mtl = mtl::PixelFormat.BC6H_RGBFLOAT },
	{ .rhi = Format.BC7_RGBA_UNORM, .mtl = mtl::PixelFormat.BC7_RGBAUNORM },
	{ .rhi = Format.BC7_RGBA_SRGB, .mtl = mtl::PixelFormat.BC7_RGBAUNORM_SRGB },
	{ .rhi = Format.D16_UNORM, .mtl = mtl::PixelFormat.DEPTH16UNORM },
	{ .rhi = Format.D32_SFLOAT, .mtl = mtl::PixelFormat.DEPTH32FLOAT },
	{ .rhi = Format.D24_UNORM_S8_UINT, .mtl = mtl::PixelFormat.DEPTH24UNORM_STENCIL8 },
	{ .rhi = Format.D32_SFLOAT_S8_UINT_X24, .mtl = mtl::PixelFormat.DEPTH32FLOAT_STENCIL8 },
	{ .rhi = Format.X24_R8_UINT, .mtl = mtl::PixelFormat.X24_STENCIL8 },
	// Stencil-only view of Depth32Float_Stencil8. MTLPixelFormatStencil8 has
	// no rhi Format.
	{ .rhi = Format.X32_R8_UINT_X24, .mtl = mtl::PixelFormat.X32_STENCIL8 },
	{ .rhi = Format.ETC2_R8G8B8_UNORM, .mtl = mtl::PixelFormat.ETC2_RGB8 }, // Canonical for this block type normally
	{ .rhi = Format.ETC1_R8G8B8_OES, .mtl = mtl::PixelFormat.ETC2_RGB8 }, // Alias
	{ .rhi = Format.ETC2_R8G8B8_SRGB, .mtl = mtl::PixelFormat.ETC2_RGB8_SRGB },
	{ .rhi = Format.ETC2_R8G8B8A1_UNORM, .mtl = mtl::PixelFormat.ETC2_RGB8A1 },
	{ .rhi = Format.ETC2_R8G8B8A1_SRGB, .mtl = mtl::PixelFormat.ETC2_RGB8A1_SRGB },
	{ .rhi = Format.ETC2_R8G8B8A8_UNORM, .mtl = mtl::PixelFormat.EAC_RGBA8 },
	{ .rhi = Format.ETC2_R8G8B8A8_SRGB, .mtl = mtl::PixelFormat.EAC_RGBA8_SRGB },
	{ .rhi = Format.ETC2_EAC_R11_UNORM, .mtl = mtl::PixelFormat.EAC_R11UNORM },
	{ .rhi = Format.ETC2_EAC_R11_SNORM, .mtl = mtl::PixelFormat.EAC_R11SNORM },
	{ .rhi = Format.ETC2_EAC_R11G11_UNORM, .mtl = mtl::PixelFormat.EAC_RG11UNORM },
	{ .rhi = Format.ETC2_EAC_R11G11_SNORM, .mtl = mtl::PixelFormat.EAC_RG11SNORM },
};

fn mtl::PixelFormat to_mtl_pixel_format(Format f)
{
	foreach (m : MTL_FORMAT_MAPPINGS)
	{
		if (m.rhi == f) return m.mtl;
	}
	return mtl::PixelFormat.INVALID;
}

fn Format from_mtl_pixel_format(mtl::PixelFormat p)
{
	foreach (m : MTL_FORMAT_MAPPINGS)
	{
		if (m.mtl == p) return m.rhi;
	}
	return Format.UNKNOWN;
}

// Vertex attribute format for a `Format`, following rhi-zig's
// `rpi/pipeline_desc.zig` `to_mtl_vertex_format` (the four float formats),
// extended to every format MTLVertexFormat can express.
fn mtl::VertexFormat mtl_vertex_format(Format f)
{
	switch (f)
	{
		case R8_UNORM: return mtl::VertexFormat.UCHAR_NORMALIZED;
		case R8_SNORM: return mtl::VertexFormat.CHAR_NORMALIZED;
		case R8_UINT: return mtl::VertexFormat.UCHAR;
		case R8_SINT: return mtl::VertexFormat.CHAR;
		case RG8_UNORM: return mtl::VertexFormat.UCHAR2_NORMALIZED;
		case RG8_SNORM: return mtl::VertexFormat.CHAR2_NORMALIZED;
		case RG8_UINT: return mtl::VertexFormat.UCHAR2;
		case RG8_SINT: return mtl::VertexFormat.CHAR2;
		case BGRA8_UNORM: return mtl::VertexFormat.UCHAR4_NORMALIZED_BGRA;
		case RGB8_UNORM: return mtl::VertexFormat.UCHAR3_NORMALIZED;
		case RGBA8_UNORM: return mtl::VertexFormat.UCHAR4_NORMALIZED;
		case RGBA8_SNORM: return mtl::VertexFormat.CHAR4_NORMALIZED;
		case RGBA8_UINT: return mtl::VertexFormat.UCHAR4;
		case RGBA8_SINT: return mtl::VertexFormat.CHAR4;
		case R16_UNORM: return mtl::VertexFormat.USHORT_NORMALIZED;
		case R16_SNORM: return mtl::VertexFormat.SHORT_NORMALIZED;
		case R16_UINT: return mtl::VertexFormat.USHORT;
		case R16_SINT: return mtl::VertexFormat.SHORT;
		case R16_SFLOAT: return mtl::VertexFormat.HALF;
		case RG16_UNORM: return mtl::VertexFormat.USHORT2_NORMALIZED;
		case RG16_SNORM: return mtl::VertexFormat.SHORT2_NORMALIZED;
		case RG16_UINT: return mtl::VertexFormat.USHORT2;
		case RG16_SINT: return mtl::VertexFormat.SHORT2;
		case RG16_SFLOAT: return mtl::VertexFormat.HALF2;
		case RGBA16_UNORM: return mtl::VertexFormat.USHORT4_NORMALIZED;
		case RGBA16_SNORM: return mtl::VertexFormat.SHORT4_NORMALIZED;
		case RGBA16_UINT: return mtl::VertexFormat.USHORT4;
		case RGBA16_SINT: return mtl::VertexFormat.SHORT4;
		case RGBA16_SFLOAT: return mtl::VertexFormat.HALF4;
		case R32_UINT: return mtl::VertexFormat.UINT;
		case R32_SINT: return mtl::VertexFormat.INT;
		case R32_SFLOAT: return mtl::VertexFormat.FLOAT;
		case RG32_UINT: return mtl::VertexFormat.UINT2;
		case RG32_SINT: return mtl::VertexFormat.INT2;
		case RG32_SFLOAT: return mtl::VertexFormat.FLOAT2;
		case RGB32_UINT: return mtl::VertexFormat.UINT3;
		case RGB32_SINT: return mtl::VertexFormat.INT3;
		case RGB32_SFLOAT: return mtl::VertexFormat.FLOAT3;
		case RGBA32_UINT: return mtl::VertexFormat.UINT4;
		case RGBA32_SINT: return mtl::VertexFormat.INT4;
		case RGBA32_SFLOAT: return mtl::VertexFormat.FLOAT4;
		case R10_G10_B10_A2_UNORM: return mtl::VertexFormat.UINT1010102_NORMALIZED;
		case R11_G11_B10_UFLOAT: return mtl::VertexFormat.FLOAT_RG11B10;
		case R9_G9_B9_E5_UNORM: return mtl::VertexFormat.FLOAT_RGB9E5;
		default: return mtl::VertexFormat.INVALID;
	}
}

// Port of rhi-zig pipeline.zig `mtl_vertex_format`, for the front
// `VertexAttribute.format`.
fn mtl::VertexFormat mtl_attribute_vertex_format(VertexFormat f)
{
	switch (f)
	{
		case FLOAT: return mtl::VertexFormat.FLOAT;
		case FLOAT2: return mtl::VertexFormat.FLOAT2;
		case FLOAT3: return mtl::VertexFormat.FLOAT3;
		case FLOAT4: return mtl::VertexFormat.FLOAT4;
	}
}

// Port of rhi-zig pipeline.zig `CompareOp.to_mtl`.
fn mtl::CompareFunction mtl_compare_function(CompareOp op)
{
	switch (op)
	{
		case NEVER: return mtl::CompareFunction.NEVER;
		case LESS: return mtl::CompareFunction.LESS;
		case EQUAL: return mtl::CompareFunction.EQUAL;
		case LESS_EQUAL: return mtl::CompareFunction.LESS_EQUAL;
		case GREATER: return mtl::CompareFunction.GREATER;
		case NOT_EQUAL: return mtl::CompareFunction.NOT_EQUAL;
		case GREATER_EQUAL: return mtl::CompareFunction.GREATER_EQUAL;
		case ALWAYS: return mtl::CompareFunction.ALWAYS;
	}
}

fn mtl::BlendFactor mtl_blend_factor(BlendFactor f)
{
	switch (f)
	{
		case ZERO: return mtl::BlendFactor.ZERO;
		case ONE: return mtl::BlendFactor.ONE;
		case SRC_COLOR: return mtl::BlendFactor.SOURCE_COLOR;
		case ONE_MINUS_SRC_COLOR: return mtl::BlendFactor.ONE_MINUS_SOURCE_COLOR;
		case DST_COLOR: return mtl::BlendFactor.DESTINATION_COLOR;
		case ONE_MINUS_DST_COLOR: return mtl::BlendFactor.ONE_MINUS_DESTINATION_COLOR;
		case SRC_ALPHA: return mtl::BlendFactor.SOURCE_ALPHA;
		case ONE_MINUS_SRC_ALPHA: return mtl::BlendFactor.ONE_MINUS_SOURCE_ALPHA;
		case DST_ALPHA: return mtl::BlendFactor.DESTINATION_ALPHA;
		case ONE_MINUS_DST_ALPHA: return mtl::BlendFactor.ONE_MINUS_DESTINATION_ALPHA;
		case CONSTANT_COLOR: return mtl::BlendFactor.BLEND_COLOR;
		case ONE_MINUS_CONSTANT_COLOR: return mtl::BlendFactor.ONE_MINUS_BLEND_COLOR;
		case CONSTANT_ALPHA: return mtl::BlendFactor.BLEND_ALPHA;
		case ONE_MINUS_CONSTANT_ALPHA: return mtl::BlendFactor.ONE_MINUS_BLEND_ALPHA;
		case SRC_ALPHA_SATURATE: return mtl::BlendFactor.SOURCE_ALPHA_SATURATED;
	}
}

fn mtl::BlendOperation mtl_blend_operation(BlendOp op)
{
	switch (op)
	{
		case ADD: return mtl::BlendOperation.ADD;
		case SUBTRACT: return mtl::BlendOperation.SUBTRACT;
		case REVERSE_SUBTRACT: return mtl::BlendOperation.REVERSE_SUBTRACT;
		case MIN: return mtl::BlendOperation.MIN;
		case MAX: return mtl::BlendOperation.MAX;
	}
}

fn mtl::ColorWriteMask mtl_color_write_mask(WriteMask mask)
{
	mtl::ColorWriteMask result = mtl::COLOR_WRITE_MASK_NONE;
	if (mask.r) result |= mtl::COLOR_WRITE_MASK_RED;
	if (mask.g) result |= mtl::COLOR_WRITE_MASK_GREEN;
	if (mask.b) result |= mtl::COLOR_WRITE_MASK_BLUE;
	if (mask.a) result |= mtl::COLOR_WRITE_MASK_ALPHA;
	return result;
}

fn mtl::SamplerMinMagFilter mtl_sampler_min_mag_filter(SamplerFilter f)
{
	switch (f)
	{
		case NEAREST: return mtl::SamplerMinMagFilter.NEAREST;
		case LINEAR: return mtl::SamplerMinMagFilter.LINEAR;
	}
}

fn mtl::SamplerMipFilter mtl_sampler_mip_filter(SamplerMipmap m)
{
	switch (m)
	{
		case NEAREST: return mtl::SamplerMipFilter.NEAREST;
		case LINEAR: return mtl::SamplerMipFilter.LINEAR;
	}
}

// `SamplerDesc` has no border color, so CLAMP_TO_BORDER samples Metal's
// default (MTLSamplerBorderColorTransparentBlack).
fn mtl::SamplerAddressMode mtl_sampler_address_mode(SamplerAddress a)
{
	switch (a)
	{
		case MIRROR: return mtl::SamplerAddressMode.MIRROR_REPEAT;
		case REPEAT: return mtl::SamplerAddressMode.REPEAT;
		case CLAMP_TO_EDGE: return mtl::SamplerAddressMode.CLAMP_TO_EDGE;
		case CLAMP_TO_BORDER: return mtl::SamplerAddressMode.CLAMP_TO_BORDER_COLOR;
	}
}

fn mtl::CompareFunction mtl_sampler_compare_function(SamplerCompare c)
{
	switch (c)
	{
		case NEVER: return mtl::CompareFunction.NEVER;
		case LESS: return mtl::CompareFunction.LESS;
		case EQUAL: return mtl::CompareFunction.EQUAL;
		case LESS_EQUAL: return mtl::CompareFunction.LESS_EQUAL;
		case GREATER: return mtl::CompareFunction.GREATER;
		case NOT_EQUAL: return mtl::CompareFunction.NOT_EQUAL;
		case GREATER_EQUAL: return mtl::CompareFunction.GREATER_EQUAL;
		case ALWAYS: return mtl::CompareFunction.ALWAYS;
	}
}

// Port of rhi-zig rpi/pipeline_desc.zig `Topology.to_mtl`.
fn mtl::PrimitiveType mtl_primitive_type(PrimitiveTopology t)
{
	switch (t)
	{
		case TRIANGLE_LIST: return mtl::PrimitiveType.TRIANGLE;
		case TRIANGLE_STRIP: return mtl::PrimitiveType.TRIANGLE_STRIP;
		case LINE_LIST: return mtl::PrimitiveType.LINE;
		case LINE_STRIP: return mtl::PrimitiveType.LINE_STRIP;
		case POINT_LIST: return mtl::PrimitiveType.POINT;
	}
}

fn mtl::CullMode mtl_cull_mode(CullMode c)
{
	switch (c)
	{
		case NONE: return mtl::CullMode.NONE;
		case FRONT: return mtl::CullMode.FRONT;
		case BACK: return mtl::CullMode.BACK;
	}
}

fn mtl::Winding mtl_winding(FrontFace f)
{
	switch (f)
	{
		case CLOCKWISE: return mtl::Winding.CLOCKWISE;
		case COUNTER_CLOCKWISE: return mtl::Winding.COUNTER_CLOCKWISE;
	}
}

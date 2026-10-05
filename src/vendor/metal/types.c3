// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Plain-old-data structs and enums shared across the Metal / Foundation /
// QuartzCore bindings, ported from rhi-zig deps/metal/src/types.zig. These
// mirror the C structs and NS_ENUM / NS_OPTIONS values of the system
// frameworks, declared directly with the layout and integer values the
// Objective-C runtime expects.
//
// Enums are `constdef X : inline NSUInteger` with explicit values (`inline`
// so they pass straight into the NSUInteger msgSend slots); members are upper
// snake case minus the type prefix (`PixelFormat.BGRA8UNORM`). Option sets follow c3/src/vendor/vulkan:
// `typedef ResourceOptions @constinit = NSUInteger;` with one module constant
// per bit (`mtl::RESOURCE_STORAGE_MODE_PRIVATE`).
module mtl @feat(DARWIN);
import std::os::macos::objc;

alias NSUInteger = objc::NSUInteger;
alias NSInteger = objc::NSInteger;

// -- Geometry --------------------------------------------------------------

// CGSize (CoreGraphics). Used by CAMetalLayer.set_drawable_size.
struct CGSize
{
	double width;
	double height;
}

// MTLSize (MTLTypes.h).
struct Size
{
	NSUInteger width;
	NSUInteger height;
	NSUInteger depth;
}

// MTLOrigin (MTLTypes.h).
struct Origin
{
	NSUInteger x;
	NSUInteger y;
	NSUInteger z;
}

// MTLRegion (MTLTypes.h).
struct Region
{
	Origin origin;
	Size size;
}

// MTLClearColor (MTLRenderPass.h), RGBA in the [0, 1] range.
struct ClearColor
{
	double red;
	double green;
	double blue;
	double alpha;
}

// MTLViewport (MTLRenderCommandEncoder.h).
struct Viewport
{
	double origin_x;
	double origin_y;
	double width;
	double height;
	double znear;
	double zfar;
}

// MTLScissorRect (MTLRenderCommandEncoder.h).
struct ScissorRect
{
	NSUInteger x;
	NSUInteger y;
	NSUInteger width;
	NSUInteger height;
}

// -- Enums (values from the Apple / metal-cpp headers) ---------------------

// MTLPixelFormat (MTLPixelFormat.h). Curated subset; extend as needed.
constdef PixelFormat : inline NSUInteger
{
	INVALID         = 0,
	A8UNORM         = 1,
	R8UNORM         = 10,
	R8UNORM_SRGB    = 11,
	R8SNORM         = 12,
	R8UINT          = 13,
	R8SINT          = 14,
	R16UNORM        = 20,
	R16SNORM        = 22,
	R16UINT         = 23,
	R16SINT         = 24,
	R16FLOAT        = 25,
	RG8UNORM        = 30,
	RG8UNORM_SRGB   = 31,
	RG8SNORM        = 32,
	RG8UINT         = 33,
	RG8SINT         = 34,
	B5G6R5UNORM     = 40,
	A1BGR5UNORM     = 41,
	ABGR4UNORM      = 42,
	BGR5A1UNORM     = 43,
	R32UINT         = 53,
	R32SINT         = 54,
	R32FLOAT        = 55,
	RG16UNORM       = 60,
	RG16SNORM       = 62,
	RG16UINT        = 63,
	RG16SINT        = 64,
	RG16FLOAT       = 65,
	RGBA8UNORM      = 70,
	RGBA8UNORM_SRGB = 71,
	RGBA8SNORM      = 72,
	RGBA8UINT       = 73,
	RGBA8SINT       = 74,
	BGRA8UNORM      = 80,
	BGRA8UNORM_SRGB = 81,
	RGB10A2UNORM    = 90,
	RGB10A2UINT     = 91,
	RG11B10FLOAT    = 92,
	RGB9E5FLOAT     = 93,
	BGR10A2UNORM    = 94,
	RG32UINT        = 103,
	RG32SINT        = 104,
	RG32FLOAT       = 105,
	RGBA16UNORM     = 110,
	RGBA16SNORM     = 112,
	RGBA16UINT      = 113,
	RGBA16SINT      = 114,
	RGBA16FLOAT     = 115,
	RGBA32UINT      = 123,
	RGBA32SINT      = 124,
	RGBA32FLOAT     = 125,
	BC1_RGBA        = 130,
	BC1_RGBA_SRGB   = 131,
	BC2_RGBA        = 132,
	BC2_RGBA_SRGB   = 133,
	BC3_RGBA        = 134,
	BC3_RGBA_SRGB   = 135,
	BC4_RUNORM      = 140,
	BC4_RSNORM      = 141,
	BC5_RGUNORM     = 142,
	BC5_RGSNORM     = 143,
	BC6H_RGBFLOAT   = 150,
	BC6H_RGBUFLOAT  = 151,
	BC7_RGBAUNORM   = 152,
	BC7_RGBAUNORM_SRGB = 153,
	EAC_R11UNORM    = 170,
	EAC_R11SNORM    = 172,
	EAC_RG11UNORM   = 174,
	EAC_RG11SNORM   = 176,
	EAC_RGBA8       = 178,
	EAC_RGBA8_SRGB  = 179,
	ETC2_RGB8       = 180,
	ETC2_RGB8_SRGB  = 181,
	ETC2_RGB8A1     = 182,
	ETC2_RGB8A1_SRGB = 183,
	DEPTH16UNORM    = 250,
	DEPTH32FLOAT    = 252,
	STENCIL8        = 253,
	DEPTH24UNORM_STENCIL8 = 255, // Intel/AMD Macs only, never on Apple silicon.
	DEPTH32FLOAT_STENCIL8 = 260,
	X32_STENCIL8    = 261,
	X24_STENCIL8    = 262,
}

// MTLLoadAction (MTLRenderPass.h).
constdef LoadAction : inline NSUInteger
{
	DONT_CARE = 0,
	LOAD      = 1,
	CLEAR     = 2,
}

// MTLStoreAction (MTLRenderPass.h).
constdef StoreAction : inline NSUInteger
{
	DONT_CARE                     = 0,
	STORE                         = 1,
	MULTISAMPLE_RESOLVE           = 2,
	STORE_AND_MULTISAMPLE_RESOLVE = 3,
}

// MTLPrimitiveType (MTLRenderCommandEncoder.h).
constdef PrimitiveType : inline NSUInteger
{
	POINT          = 0,
	LINE           = 1,
	LINE_STRIP     = 2,
	TRIANGLE       = 3,
	TRIANGLE_STRIP = 4,
}

// MTLIndexType (MTLStageInputOutputDescriptor.h).
constdef IndexType : inline NSUInteger
{
	UINT16 = 0,
	UINT32 = 1,
}

// MTLCompareFunction (MTLDepthStencil.h).
constdef CompareFunction : inline NSUInteger
{
	NEVER         = 0,
	LESS          = 1,
	EQUAL         = 2,
	LESS_EQUAL    = 3,
	GREATER       = 4,
	NOT_EQUAL     = 5,
	GREATER_EQUAL = 6,
	ALWAYS        = 7,
}

// MTLVertexFormat (MTLVertexDescriptor.h). Curated subset.
constdef VertexFormat : inline NSUInteger
{
	INVALID = 0,
	UCHAR2  = 1,
	UCHAR3  = 2,
	UCHAR4  = 3,
	CHAR2   = 4,
	CHAR3   = 5,
	CHAR4   = 6,
	UCHAR2_NORMALIZED = 7,
	UCHAR3_NORMALIZED = 8,
	UCHAR4_NORMALIZED = 9,
	CHAR2_NORMALIZED  = 10,
	CHAR3_NORMALIZED  = 11,
	CHAR4_NORMALIZED  = 12,
	USHORT2 = 13,
	USHORT3 = 14,
	USHORT4 = 15,
	SHORT2  = 16,
	SHORT3  = 17,
	SHORT4  = 18,
	USHORT2_NORMALIZED = 19,
	USHORT3_NORMALIZED = 20,
	USHORT4_NORMALIZED = 21,
	SHORT2_NORMALIZED  = 22,
	SHORT3_NORMALIZED  = 23,
	SHORT4_NORMALIZED  = 24,
	HALF2   = 25,
	HALF3   = 26,
	HALF4   = 27,
	FLOAT   = 28,
	FLOAT2  = 29,
	FLOAT3  = 30,
	FLOAT4  = 31,
	INT     = 32,
	INT2    = 33,
	INT3    = 34,
	INT4    = 35,
	UINT    = 36,
	UINT2   = 37,
	UINT3   = 38,
	UINT4   = 39,
	INT1010102_NORMALIZED  = 40,
	UINT1010102_NORMALIZED = 41,
	UCHAR4_NORMALIZED_BGRA = 42,
	UCHAR   = 45,
	CHAR    = 46,
	UCHAR_NORMALIZED  = 47,
	CHAR_NORMALIZED   = 48,
	USHORT  = 49,
	SHORT   = 50,
	USHORT_NORMALIZED = 51,
	SHORT_NORMALIZED  = 52,
	HALF    = 53,
	FLOAT_RG11B10     = 54,
	FLOAT_RGB9E5      = 55,
}

// MTLVertexStepFunction (MTLVertexDescriptor.h).
constdef VertexStepFunction : inline NSUInteger
{
	CONSTANT     = 0,
	PER_VERTEX   = 1,
	PER_INSTANCE = 2,
}

// MTLTextureType (MTLTexture.h).
constdef TextureType : inline NSUInteger
{
	TYPE_1D                   = 0,
	TYPE_1D_ARRAY             = 1,
	TYPE_2D                   = 2,
	TYPE_2D_ARRAY             = 3,
	TYPE_2D_MULTISAMPLE       = 4,
	TYPE_CUBE                 = 5,
	TYPE_CUBE_ARRAY           = 6,
	TYPE_3D                   = 7,
	TYPE_2D_MULTISAMPLE_ARRAY = 8,
	TYPE_TEXTURE_BUFFER       = 9,
}

// MTLCPUCacheMode (MTLResource.h).
constdef CPUCacheMode : inline NSUInteger
{
	DEFAULT_CACHE  = 0,
	WRITE_COMBINED = 1,
}

// MTLStorageMode (MTLResource.h).
constdef StorageMode : inline NSUInteger
{
	SHARED     = 0,
	MANAGED    = 1,
	PRIVATE    = 2,
	MEMORYLESS = 3,
}

// MTLHazardTrackingMode (MTLResource.h).
constdef HazardTrackingMode : inline NSUInteger
{
	DEFAULT   = 0,
	UNTRACKED = 1,
	TRACKED   = 2,
}

// MTLBlendFactor (MTLRenderPipeline.h).
constdef BlendFactor : inline NSUInteger
{
	ZERO                        = 0,
	ONE                         = 1,
	SOURCE_COLOR                = 2,
	ONE_MINUS_SOURCE_COLOR      = 3,
	SOURCE_ALPHA                = 4,
	ONE_MINUS_SOURCE_ALPHA      = 5,
	DESTINATION_COLOR           = 6,
	ONE_MINUS_DESTINATION_COLOR = 7,
	DESTINATION_ALPHA           = 8,
	ONE_MINUS_DESTINATION_ALPHA = 9,
	SOURCE_ALPHA_SATURATED      = 10,
	BLEND_COLOR                 = 11,
	ONE_MINUS_BLEND_COLOR       = 12,
	BLEND_ALPHA                 = 13,
	ONE_MINUS_BLEND_ALPHA       = 14,
	SOURCE1_COLOR               = 15,
	ONE_MINUS_SOURCE1_COLOR     = 16,
	SOURCE1_ALPHA               = 17,
	ONE_MINUS_SOURCE1_ALPHA     = 18,
}

// MTLBlendOperation (MTLRenderPipeline.h).
constdef BlendOperation : inline NSUInteger
{
	ADD              = 0,
	SUBTRACT         = 1,
	REVERSE_SUBTRACT = 2,
	MIN              = 3,
	MAX              = 4,
}

// MTLSamplerMinMagFilter (MTLSampler.h).
constdef SamplerMinMagFilter : inline NSUInteger
{
	NEAREST = 0,
	LINEAR  = 1,
}

// MTLSamplerMipFilter (MTLSampler.h).
constdef SamplerMipFilter : inline NSUInteger
{
	NOT_MIPMAPPED = 0,
	NEAREST       = 1,
	LINEAR        = 2,
}

// MTLSamplerAddressMode (MTLSampler.h).
constdef SamplerAddressMode : inline NSUInteger
{
	CLAMP_TO_EDGE         = 0,
	MIRROR_CLAMP_TO_EDGE  = 1,
	REPEAT                = 2,
	MIRROR_REPEAT         = 3,
	CLAMP_TO_ZERO         = 4,
	CLAMP_TO_BORDER_COLOR = 5,
}

// MTLSamplerBorderColor (MTLSampler.h).
constdef SamplerBorderColor : inline NSUInteger
{
	TRANSPARENT_BLACK = 0,
	OPAQUE_BLACK      = 1,
	OPAQUE_WHITE      = 2,
}

// MTLCullMode (MTLRenderCommandEncoder.h).
constdef CullMode : inline NSUInteger
{
	NONE  = 0,
	FRONT = 1,
	BACK  = 2,
}

// MTLWinding (MTLRenderCommandEncoder.h).
constdef Winding : inline NSUInteger
{
	CLOCKWISE         = 0,
	COUNTER_CLOCKWISE = 1,
}

// -- Option sets (NS_OPTIONS backed by NSUInteger) -------------------------

// MTLResourceOptions (MTLResource.h): CPU cache mode in bits 0..3, storage
// mode in bits 4..7, hazard tracking mode in bits 8..9. Zero is
// StorageModeShared | CPUCacheModeDefaultCache, matching Metal's default.
typedef ResourceOptions @constinit = NSUInteger;
const ResourceOptions RESOURCE_CPU_CACHE_MODE_DEFAULT_CACHE  = 0x0;
const ResourceOptions RESOURCE_CPU_CACHE_MODE_WRITE_COMBINED = 0x1;
const ResourceOptions RESOURCE_STORAGE_MODE_SHARED           = 0x00;
const ResourceOptions RESOURCE_STORAGE_MODE_MANAGED          = 0x10;
const ResourceOptions RESOURCE_STORAGE_MODE_PRIVATE          = 0x20;
const ResourceOptions RESOURCE_STORAGE_MODE_MEMORYLESS       = 0x30;
const ResourceOptions RESOURCE_HAZARD_TRACKING_MODE_DEFAULT   = 0x000;
const ResourceOptions RESOURCE_HAZARD_TRACKING_MODE_UNTRACKED = 0x100;
const ResourceOptions RESOURCE_HAZARD_TRACKING_MODE_TRACKED   = 0x200;

// MTLTextureUsage (MTLTexture.h).
typedef TextureUsage @constinit = NSUInteger;
const TextureUsage TEXTURE_USAGE_UNKNOWN           = 0x00;
const TextureUsage TEXTURE_USAGE_SHADER_READ       = 0x01;
const TextureUsage TEXTURE_USAGE_SHADER_WRITE      = 0x02;
const TextureUsage TEXTURE_USAGE_RENDER_TARGET     = 0x04;
const TextureUsage TEXTURE_USAGE_PIXEL_FORMAT_VIEW = 0x10;
const TextureUsage TEXTURE_USAGE_SHADER_ATOMIC     = 0x20;

// MTLColorWriteMask (MTLRenderPipeline.h).
typedef ColorWriteMask @constinit = NSUInteger;
const ColorWriteMask COLOR_WRITE_MASK_NONE  = 0x0;
const ColorWriteMask COLOR_WRITE_MASK_RED   = 0x8;
const ColorWriteMask COLOR_WRITE_MASK_GREEN = 0x4;
const ColorWriteMask COLOR_WRITE_MASK_BLUE  = 0x2;
const ColorWriteMask COLOR_WRITE_MASK_ALPHA = 0x1;
const ColorWriteMask COLOR_WRITE_MASK_ALL   = 0xf;

// MTLBarrierScope (MTLCommandEncoder.h).
typedef BarrierScope @constinit = NSUInteger;
const BarrierScope BARRIER_SCOPE_BUFFERS        = 0x1;
const BarrierScope BARRIER_SCOPE_TEXTURES       = 0x2;
const BarrierScope BARRIER_SCOPE_RENDER_TARGETS = 0x4;

// MTLRenderStages (MTLRenderCommandEncoder.h).
typedef RenderStages @constinit = NSUInteger;
const RenderStages RENDER_STAGE_VERTEX   = 0x01;
const RenderStages RENDER_STAGE_FRAGMENT = 0x02;
const RenderStages RENDER_STAGE_TILE     = 0x04;
const RenderStages RENDER_STAGE_OBJECT   = 0x08;
const RenderStages RENDER_STAGE_MESH     = 0x10;

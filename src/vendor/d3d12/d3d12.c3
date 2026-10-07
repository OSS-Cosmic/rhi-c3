// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// C3 bindings for Direct3D 12 (d3d12.h) covering what the ATDD-Redux D3D12
// renderer uses: device/queue/allocator/command list (through
// ID3D12GraphicsCommandList5), fences, resources, descriptor heaps, root
// signatures, graphics/compute pipeline states, command signatures, query
// heaps, render passes and DXR (acceleration structures, state objects,
// DispatchRays). Hand-written; COM conventions are described in dxgi.c3.
//
// Naming: the D3D12_ / ID3D12 prefixes are dropped (`d3d12::Device`,
// `d3d12::ResourceDesc`). Enums are `constdef`, flag sets are
// `typedef X @constinit = uint` with one module constant per bit, named
// <SET>_<BIT> (e.g. RESOURCE_STATE_COPY_DEST). Layouts are pinned down by
// layout.c3 ($assert) and test/vendor/d3d12/d3d12_test.c3.
module d3d12;
import dxgi;

const uint DEFAULT_SHADER_4_COMPONENT_MAPPING = 0x1688; // D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0,1,2,3)
const uint RESOURCE_BARRIER_ALL_SUBRESOURCES = 0xFFFFFFFF;
const uint APPEND_ALIGNED_ELEMENT = 0xFFFFFFFF;
const uint DEFAULT_RESOURCE_PLACEMENT_ALIGNMENT = 65536;
const uint TEXTURE_DATA_PITCH_ALIGNMENT = 256;
const uint TEXTURE_DATA_PLACEMENT_ALIGNMENT = 512;
const uint SHADER_IDENTIFIER_SIZE_IN_BYTES = 32;
const uint RAYTRACING_SHADER_TABLE_BYTE_ALIGNMENT = 32;
const uint RAYTRACING_SHADER_RECORD_BYTE_ALIGNMENT = 64;
const uint RAYTRACING_INSTANCE_DESC_BYTE_ALIGNMENT = 16;
const uint RAYTRACING_ACCELERATION_STRUCTURE_BYTE_ALIGNMENT = 256;
const uint SIMULTANEOUS_RENDER_TARGET_COUNT = 8;
const ulong MAX_FENCE_WAIT = 0xFFFFFFFF; // INFINITE for WaitForSingleObject

// -- Enums ---------------------------------------------------------------------

// D3D_FEATURE_LEVEL.
constdef FeatureLevel : uint
{
	LEVEL_11_0 = 0xb000,
	LEVEL_11_1 = 0xb100,
	LEVEL_12_0 = 0xc000,
	LEVEL_12_1 = 0xc100,
	LEVEL_12_2 = 0xc200,
}

constdef CommandListType : uint
{
	DIRECT        = 0,
	BUNDLE        = 1,
	COMPUTE       = 2,
	COPY          = 3,
	VIDEO_DECODE  = 4,
	VIDEO_PROCESS = 5,
	VIDEO_ENCODE  = 6,
}

typedef CommandQueueFlags @constinit = uint;
const CommandQueueFlags COMMAND_QUEUE_FLAG_NONE                = 0;
const CommandQueueFlags COMMAND_QUEUE_FLAG_DISABLE_GPU_TIMEOUT = 1;

constdef CommandQueuePriority : int
{
	NORMAL          = 0,
	HIGH            = 100,
	GLOBAL_REALTIME = 10000,
}

constdef HeapType : uint
{
	DEFAULT  = 1,
	UPLOAD   = 2,
	READBACK = 3,
	CUSTOM   = 4,
}

constdef CpuPageProperty : uint
{
	UNKNOWN       = 0,
	NOT_AVAILABLE = 1,
	WRITE_COMBINE = 2,
	WRITE_BACK    = 3,
}

constdef MemoryPool : uint
{
	UNKNOWN = 0,
	L0      = 1,
	L1      = 2,
}

typedef HeapFlags @constinit = uint;
const HeapFlags HEAP_FLAG_NONE                           = 0x0;
const HeapFlags HEAP_FLAG_SHARED                         = 0x1;
const HeapFlags HEAP_FLAG_DENY_BUFFERS                   = 0x4;
const HeapFlags HEAP_FLAG_ALLOW_DISPLAY                  = 0x8;
const HeapFlags HEAP_FLAG_SHARED_CROSS_ADAPTER           = 0x20;
const HeapFlags HEAP_FLAG_DENY_RT_DS_TEXTURES            = 0x40;
const HeapFlags HEAP_FLAG_DENY_NON_RT_DS_TEXTURES        = 0x80;
const HeapFlags HEAP_FLAG_ALLOW_ONLY_BUFFERS             = 0xC0;
const HeapFlags HEAP_FLAG_ALLOW_ONLY_NON_RT_DS_TEXTURES  = 0x44;
const HeapFlags HEAP_FLAG_ALLOW_ONLY_RT_DS_TEXTURES      = 0x84;

constdef ResourceDimension : uint
{
	UNKNOWN   = 0,
	BUFFER    = 1,
	TEXTURE1D = 2,
	TEXTURE2D = 3,
	TEXTURE3D = 4,
}

constdef TextureLayout : uint
{
	UNKNOWN                = 0,
	ROW_MAJOR              = 1,
	UNDEFINED_64KB_SWIZZLE = 2,
	STANDARD_64KB_SWIZZLE  = 3,
}

typedef ResourceFlags @constinit = uint;
const ResourceFlags RESOURCE_FLAG_NONE                       = 0x0;
const ResourceFlags RESOURCE_FLAG_ALLOW_RENDER_TARGET        = 0x1;
const ResourceFlags RESOURCE_FLAG_ALLOW_DEPTH_STENCIL        = 0x2;
const ResourceFlags RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS     = 0x4;
const ResourceFlags RESOURCE_FLAG_DENY_SHADER_RESOURCE       = 0x8;
const ResourceFlags RESOURCE_FLAG_ALLOW_CROSS_ADAPTER        = 0x10;
const ResourceFlags RESOURCE_FLAG_ALLOW_SIMULTANEOUS_ACCESS  = 0x20;

typedef ResourceStates @constinit = uint;
const ResourceStates RESOURCE_STATE_COMMON                            = 0x0;
const ResourceStates RESOURCE_STATE_PRESENT                           = 0x0;
const ResourceStates RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER        = 0x1;
const ResourceStates RESOURCE_STATE_INDEX_BUFFER                      = 0x2;
const ResourceStates RESOURCE_STATE_RENDER_TARGET                     = 0x4;
const ResourceStates RESOURCE_STATE_UNORDERED_ACCESS                  = 0x8;
const ResourceStates RESOURCE_STATE_DEPTH_WRITE                       = 0x10;
const ResourceStates RESOURCE_STATE_DEPTH_READ                        = 0x20;
const ResourceStates RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE         = 0x40;
const ResourceStates RESOURCE_STATE_PIXEL_SHADER_RESOURCE             = 0x80;
const ResourceStates RESOURCE_STATE_STREAM_OUT                        = 0x100;
const ResourceStates RESOURCE_STATE_INDIRECT_ARGUMENT                 = 0x200;
const ResourceStates RESOURCE_STATE_PREDICATION                       = 0x200;
const ResourceStates RESOURCE_STATE_COPY_DEST                         = 0x400;
const ResourceStates RESOURCE_STATE_COPY_SOURCE                       = 0x800;
const ResourceStates RESOURCE_STATE_RESOLVE_DEST                      = 0x1000;
const ResourceStates RESOURCE_STATE_RESOLVE_SOURCE                    = 0x2000;
const ResourceStates RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE = 0x400000;
const ResourceStates RESOURCE_STATE_SHADING_RATE_SOURCE               = 0x1000000;
const ResourceStates RESOURCE_STATE_GENERIC_READ                      = 0xAC3;

constdef ResourceBarrierType : uint
{
	TRANSITION = 0,
	ALIASING   = 1,
	UAV        = 2,
}

typedef ResourceBarrierFlags @constinit = uint;
const ResourceBarrierFlags RESOURCE_BARRIER_FLAG_NONE       = 0;
const ResourceBarrierFlags RESOURCE_BARRIER_FLAG_BEGIN_ONLY = 1;
const ResourceBarrierFlags RESOURCE_BARRIER_FLAG_END_ONLY   = 2;

constdef DescriptorHeapType : uint
{
	CBV_SRV_UAV = 0,
	SAMPLER     = 1,
	RTV         = 2,
	DSV         = 3,
}

typedef DescriptorHeapFlags @constinit = uint;
const DescriptorHeapFlags DESCRIPTOR_HEAP_FLAG_NONE           = 0;
const DescriptorHeapFlags DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE = 1;

constdef DescriptorRangeType : uint
{
	SRV     = 0,
	UAV     = 1,
	CBV     = 2,
	SAMPLER = 3,
}

typedef DescriptorRangeFlags @constinit = uint;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_NONE                                    = 0x0;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE                    = 0x1;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_DATA_VOLATILE                           = 0x2;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_DATA_STATIC_WHILE_SET_AT_EXECUTE        = 0x4;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_DATA_STATIC                             = 0x8;
const DescriptorRangeFlags DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_STATIC_KEEPING_BUFFER_BOUNDS_CHECKS = 0x10000;

typedef RootDescriptorFlags @constinit = uint;
const RootDescriptorFlags ROOT_DESCRIPTOR_FLAG_NONE                             = 0x0;
const RootDescriptorFlags ROOT_DESCRIPTOR_FLAG_DATA_VOLATILE                    = 0x2;
const RootDescriptorFlags ROOT_DESCRIPTOR_FLAG_DATA_STATIC_WHILE_SET_AT_EXECUTE = 0x4;
const RootDescriptorFlags ROOT_DESCRIPTOR_FLAG_DATA_STATIC                      = 0x8;

constdef RootParameterType : uint
{
	DESCRIPTOR_TABLE = 0,
	CONSTANTS_32BIT  = 1,
	CBV              = 2,
	SRV              = 3,
	UAV              = 4,
}

constdef ShaderVisibility : uint
{
	ALL           = 0,
	VERTEX        = 1,
	HULL          = 2,
	DOMAIN        = 3,
	GEOMETRY      = 4,
	PIXEL         = 5,
	AMPLIFICATION = 6,
	MESH          = 7,
}

typedef RootSignatureFlags @constinit = uint;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_NONE                                = 0x0;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT = 0x1;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_VERTEX_SHADER_ROOT_ACCESS      = 0x2;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS        = 0x4;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS      = 0x8;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS    = 0x10;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS       = 0x20;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_ALLOW_STREAM_OUTPUT                 = 0x40;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_LOCAL_ROOT_SIGNATURE                = 0x80;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_AMPLIFICATION_SHADER_ROOT_ACCESS = 0x100;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_DENY_MESH_SHADER_ROOT_ACCESS        = 0x200;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_CBV_SRV_UAV_HEAP_DIRECTLY_INDEXED   = 0x400;
const RootSignatureFlags ROOT_SIGNATURE_FLAG_SAMPLER_HEAP_DIRECTLY_INDEXED       = 0x800;

// D3D_ROOT_SIGNATURE_VERSION.
constdef RootSignatureVersion : uint
{
	V1_0 = 1,
	V1_1 = 2,
}

// D3D12_FILTER (the common values; others follow the same bit layout).
constdef Filter : uint
{
	MIN_MAG_MIP_POINT                     = 0x00,
	MIN_MAG_POINT_MIP_LINEAR              = 0x01,
	MIN_POINT_MAG_LINEAR_MIP_POINT        = 0x04,
	MIN_POINT_MAG_MIP_LINEAR              = 0x05,
	MIN_LINEAR_MAG_MIP_POINT              = 0x10,
	MIN_LINEAR_MAG_POINT_MIP_LINEAR       = 0x11,
	MIN_MAG_LINEAR_MIP_POINT              = 0x14,
	MIN_MAG_MIP_LINEAR                    = 0x15,
	ANISOTROPIC                           = 0x55,
	COMPARISON_MIN_MAG_MIP_POINT          = 0x80,
	COMPARISON_MIN_MAG_MIP_LINEAR         = 0x95,
	COMPARISON_ANISOTROPIC                = 0xD5,
	MINIMUM_MIN_MAG_MIP_LINEAR            = 0x115,
	MAXIMUM_MIN_MAG_MIP_LINEAR            = 0x195,
}

constdef TextureAddressMode : uint
{
	WRAP        = 1,
	MIRROR      = 2,
	CLAMP       = 3,
	BORDER      = 4,
	MIRROR_ONCE = 5,
}

constdef ComparisonFunc : uint
{
	NEVER         = 1,
	LESS          = 2,
	EQUAL         = 3,
	LESS_EQUAL    = 4,
	GREATER       = 5,
	NOT_EQUAL     = 6,
	GREATER_EQUAL = 7,
	ALWAYS        = 8,
}

constdef StaticBorderColor : uint
{
	TRANSPARENT_BLACK = 0,
	OPAQUE_BLACK      = 1,
	OPAQUE_WHITE      = 2,
}

constdef Blend : uint
{
	ZERO             = 1,
	ONE              = 2,
	SRC_COLOR        = 3,
	INV_SRC_COLOR    = 4,
	SRC_ALPHA        = 5,
	INV_SRC_ALPHA    = 6,
	DEST_ALPHA       = 7,
	INV_DEST_ALPHA   = 8,
	DEST_COLOR       = 9,
	INV_DEST_COLOR   = 10,
	SRC_ALPHA_SAT    = 11,
	BLEND_FACTOR     = 14,
	INV_BLEND_FACTOR = 15,
	SRC1_COLOR       = 16,
	INV_SRC1_COLOR   = 17,
	SRC1_ALPHA       = 18,
	INV_SRC1_ALPHA   = 19,
}

constdef BlendOp : uint
{
	ADD          = 1,
	SUBTRACT     = 2,
	REV_SUBTRACT = 3,
	MIN          = 4,
	MAX          = 5,
}

constdef LogicOp : uint
{
	CLEAR         = 0,
	SET           = 1,
	COPY          = 2,
	COPY_INVERTED = 3,
	NOOP          = 4,
	INVERT        = 5,
	AND           = 6,
	NAND          = 7,
	OR            = 8,
	NOR           = 9,
	XOR           = 10,
	EQUIV         = 11,
	AND_REVERSE   = 12,
	AND_INVERTED  = 13,
	OR_REVERSE    = 14,
	OR_INVERTED   = 15,
}

typedef ColorWriteEnable @constinit = char;
const ColorWriteEnable COLOR_WRITE_ENABLE_RED   = 1;
const ColorWriteEnable COLOR_WRITE_ENABLE_GREEN = 2;
const ColorWriteEnable COLOR_WRITE_ENABLE_BLUE  = 4;
const ColorWriteEnable COLOR_WRITE_ENABLE_ALPHA = 8;
const ColorWriteEnable COLOR_WRITE_ENABLE_ALL   = 15;

constdef FillMode : uint
{
	WIREFRAME = 2,
	SOLID     = 3,
}

constdef CullMode : uint
{
	NONE  = 1,
	FRONT = 2,
	BACK  = 3,
}

constdef ConservativeRasterizationMode : uint
{
	OFF = 0,
	ON  = 1,
}

constdef DepthWriteMask : uint
{
	ZERO = 0,
	ALL  = 1,
}

constdef StencilOp : uint
{
	KEEP     = 1,
	ZERO     = 2,
	REPLACE  = 3,
	INCR_SAT = 4,
	DECR_SAT = 5,
	INVERT   = 6,
	INCR     = 7,
	DECR     = 8,
}

constdef InputClassification : uint
{
	PER_VERTEX_DATA   = 0,
	PER_INSTANCE_DATA = 1,
}

constdef IndexBufferStripCutValue : uint
{
	DISABLED    = 0,
	VALUE_FFFF  = 1,
	VALUE_FFFFFFFF = 2,
}

constdef PrimitiveTopologyType : uint
{
	UNDEFINED = 0,
	POINT     = 1,
	LINE      = 2,
	TRIANGLE  = 3,
	PATCH     = 4,
}

// D3D_PRIMITIVE_TOPOLOGY (IASetPrimitiveTopology).
constdef PrimitiveTopology : uint
{
	UNDEFINED     = 0,
	POINTLIST     = 1,
	LINELIST      = 2,
	LINESTRIP     = 3,
	TRIANGLELIST  = 4,
	TRIANGLESTRIP = 5,
}

typedef PipelineStateFlags @constinit = uint;
const PipelineStateFlags PIPELINE_STATE_FLAG_NONE       = 0;
const PipelineStateFlags PIPELINE_STATE_FLAG_TOOL_DEBUG = 1;

constdef SrvDimension : uint
{
	UNKNOWN                      = 0,
	BUFFER                       = 1,
	TEXTURE1D                    = 2,
	TEXTURE1DARRAY               = 3,
	TEXTURE2D                    = 4,
	TEXTURE2DARRAY               = 5,
	TEXTURE2DMS                  = 6,
	TEXTURE2DMSARRAY             = 7,
	TEXTURE3D                    = 8,
	TEXTURECUBE                  = 9,
	TEXTURECUBEARRAY             = 10,
	RAYTRACING_ACCELERATION_STRUCTURE = 11,
}

constdef UavDimension : uint
{
	UNKNOWN        = 0,
	BUFFER         = 1,
	TEXTURE1D      = 2,
	TEXTURE1DARRAY = 3,
	TEXTURE2D      = 4,
	TEXTURE2DARRAY = 5,
	TEXTURE3D      = 8,
}

constdef RtvDimension : uint
{
	UNKNOWN          = 0,
	BUFFER           = 1,
	TEXTURE1D        = 2,
	TEXTURE1DARRAY   = 3,
	TEXTURE2D        = 4,
	TEXTURE2DARRAY   = 5,
	TEXTURE2DMS      = 6,
	TEXTURE2DMSARRAY = 7,
	TEXTURE3D        = 8,
}

constdef DsvDimension : uint
{
	UNKNOWN          = 0,
	TEXTURE1D        = 1,
	TEXTURE1DARRAY   = 2,
	TEXTURE2D        = 3,
	TEXTURE2DARRAY   = 4,
	TEXTURE2DMS      = 5,
	TEXTURE2DMSARRAY = 6,
}

typedef DsvFlags @constinit = uint;
const DsvFlags DSV_FLAG_NONE              = 0;
const DsvFlags DSV_FLAG_READ_ONLY_DEPTH   = 1;
const DsvFlags DSV_FLAG_READ_ONLY_STENCIL = 2;

typedef ClearFlags @constinit = uint;
const ClearFlags CLEAR_FLAG_DEPTH   = 1;
const ClearFlags CLEAR_FLAG_STENCIL = 2;

typedef BufferSrvFlags @constinit = uint;
const BufferSrvFlags BUFFER_SRV_FLAG_NONE = 0;
const BufferSrvFlags BUFFER_SRV_FLAG_RAW  = 1;

typedef BufferUavFlags @constinit = uint;
const BufferUavFlags BUFFER_UAV_FLAG_NONE = 0;
const BufferUavFlags BUFFER_UAV_FLAG_RAW  = 1;

constdef TextureCopyType : uint
{
	SUBRESOURCE_INDEX    = 0,
	PLACED_FOOTPRINT     = 1,
}

constdef QueryHeapType : uint
{
	OCCLUSION           = 0,
	TIMESTAMP           = 1,
	PIPELINE_STATISTICS = 2,
	SO_STATISTICS       = 3,
}

constdef QueryType : uint
{
	OCCLUSION           = 0,
	BINARY_OCCLUSION    = 1,
	TIMESTAMP           = 2,
	PIPELINE_STATISTICS = 3,
}

constdef PredicationOp : uint
{
	EQUAL_ZERO     = 0,
	NOT_EQUAL_ZERO = 1,
}

constdef IndirectArgumentType : uint
{
	DRAW                  = 0,
	DRAW_INDEXED          = 1,
	DISPATCH              = 2,
	VERTEX_BUFFER_VIEW    = 3,
	INDEX_BUFFER_VIEW     = 4,
	CONSTANT              = 5,
	CONSTANT_BUFFER_VIEW  = 6,
	SHADER_RESOURCE_VIEW  = 7,
	UNORDERED_ACCESS_VIEW = 8,
	DISPATCH_RAYS         = 9,
	DISPATCH_MESH         = 10,
}

constdef FenceFlags : uint
{
	NONE                 = 0,
	SHARED               = 1,
	SHARED_CROSS_ADAPTER = 2,
}

// D3D12_FEATURE (the queries the renderer issues).
constdef Feature : uint
{
	D3D12_OPTIONS                  = 0,
	ARCHITECTURE                   = 1,
	FEATURE_LEVELS                 = 2,
	FORMAT_SUPPORT                 = 3,
	MULTISAMPLE_QUALITY_LEVELS     = 4,
	GPU_VIRTUAL_ADDRESS_SUPPORT    = 6,
	SHADER_MODEL                   = 7,
	D3D12_OPTIONS1                 = 8,
	ROOT_SIGNATURE                 = 12,
	D3D12_OPTIONS5                 = 27,
	D3D12_OPTIONS7                 = 32,
}

constdef RaytracingTier : uint
{
	NOT_SUPPORTED = 0,
	TIER_1_0      = 10,
	TIER_1_1      = 11,
}

constdef MeshShaderTier : uint
{
	NOT_SUPPORTED = 0,
	TIER_1        = 10,
}

constdef RenderPassTier : uint
{
	TIER_0 = 0,
	TIER_1 = 1,
	TIER_2 = 2,
}

// D3D_SHADER_MODEL.
constdef ShaderModel : uint
{
	SM_6_0 = 0x60,
	SM_6_5 = 0x65,
	SM_6_6 = 0x66,
	SM_6_7 = 0x67,
}

// -- Render passes (ID3D12GraphicsCommandList4) --------------------------------

constdef RenderPassBeginningAccessType : uint
{
	DISCARD   = 0,
	PRESERVE  = 1,
	CLEAR     = 2,
	NO_ACCESS = 3,
}

constdef RenderPassEndingAccessType : uint
{
	DISCARD   = 0,
	PRESERVE  = 1,
	RESOLVE   = 2,
	NO_ACCESS = 3,
}

typedef RenderPassFlags @constinit = uint;
const RenderPassFlags RENDER_PASS_FLAG_NONE               = 0;
const RenderPassFlags RENDER_PASS_FLAG_ALLOW_UAV_WRITES   = 1;
const RenderPassFlags RENDER_PASS_FLAG_SUSPENDING_PASS    = 2;
const RenderPassFlags RENDER_PASS_FLAG_RESUMING_PASS      = 4;

constdef ResolveMode : uint
{
	DECOMPRESS = 0,
	MIN        = 1,
	MAX        = 2,
	AVERAGE    = 3,
}

// -- Raytracing ----------------------------------------------------------------

constdef RaytracingGeometryType : uint
{
	TRIANGLES                     = 0,
	PROCEDURAL_PRIMITIVE_AABBS    = 1,
}

typedef RaytracingGeometryFlags @constinit = uint;
const RaytracingGeometryFlags RAYTRACING_GEOMETRY_FLAG_NONE                          = 0;
const RaytracingGeometryFlags RAYTRACING_GEOMETRY_FLAG_OPAQUE                        = 1;
const RaytracingGeometryFlags RAYTRACING_GEOMETRY_FLAG_NO_DUPLICATE_ANYHIT_INVOCATION = 2;

typedef RaytracingAccelerationStructureBuildFlags @constinit = uint;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_NONE             = 0;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_ALLOW_UPDATE     = 0x1;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_ALLOW_COMPACTION = 0x2;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_PREFER_FAST_TRACE = 0x4;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_PREFER_FAST_BUILD = 0x8;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_MINIMIZE_MEMORY  = 0x10;
const RaytracingAccelerationStructureBuildFlags BUILD_FLAG_PERFORM_UPDATE   = 0x20;

constdef RaytracingAccelerationStructureCopyMode : uint
{
	CLONE                      = 0,
	COMPACT                    = 1,
	VISUALIZATION_DECODE_FOR_TOOLS = 2,
	SERIALIZE                  = 3,
	DESERIALIZE                = 4,
}

constdef RaytracingAccelerationStructureType : uint
{
	TOP_LEVEL    = 0,
	BOTTOM_LEVEL = 1,
}

constdef ElementsLayout : uint
{
	ARRAY              = 0,
	ARRAY_OF_POINTERS  = 1,
}

typedef RaytracingInstanceFlags @constinit = uint;
const RaytracingInstanceFlags RAYTRACING_INSTANCE_FLAG_NONE                          = 0;
const RaytracingInstanceFlags RAYTRACING_INSTANCE_FLAG_TRIANGLE_CULL_DISABLE         = 1;
const RaytracingInstanceFlags RAYTRACING_INSTANCE_FLAG_TRIANGLE_FRONT_COUNTERCLOCKWISE = 2;
const RaytracingInstanceFlags RAYTRACING_INSTANCE_FLAG_FORCE_OPAQUE                  = 4;
const RaytracingInstanceFlags RAYTRACING_INSTANCE_FLAG_FORCE_NON_OPAQUE              = 8;

constdef RaytracingAccelerationStructurePostbuildInfoType : uint
{
	COMPACTED_SIZE      = 0,
	TOOLS_VISUALIZATION = 1,
	SERIALIZATION       = 2,
	CURRENT_SIZE        = 3,
}

constdef StateObjectType : uint
{
	COLLECTION            = 0,
	RAYTRACING_PIPELINE   = 3,
}

constdef StateSubobjectType : uint
{
	STATE_OBJECT_CONFIG                   = 0,
	GLOBAL_ROOT_SIGNATURE                 = 1,
	LOCAL_ROOT_SIGNATURE                  = 2,
	NODE_MASK                             = 3,
	DXIL_LIBRARY                          = 5,
	EXISTING_COLLECTION                   = 6,
	SUBOBJECT_TO_EXPORTS_ASSOCIATION      = 7,
	DXIL_SUBOBJECT_TO_EXPORTS_ASSOCIATION = 8,
	RAYTRACING_SHADER_CONFIG              = 9,
	RAYTRACING_PIPELINE_CONFIG            = 10,
	HIT_GROUP                             = 11,
	RAYTRACING_PIPELINE_CONFIG1           = 12,
}

constdef HitGroupType : uint
{
	TRIANGLES                   = 0,
	PROCEDURAL_PRIMITIVE        = 1,
}

// -- Basic structs -------------------------------------------------------------

struct Rect
{
	int left;
	int top;
	int right;
	int bottom;
}

struct Viewport
{
	float top_left_x;
	float top_left_y;
	float width;
	float height;
	float min_depth;
	float max_depth;
}

// D3D12_BOX.
struct ResourceBox
{
	uint left;
	uint top;
	uint front;
	uint right;
	uint bottom;
	uint back;
}

// D3D12_RANGE (Map/Unmap).
struct ResourceRange
{
	usz begin;
	usz end;
}

struct CpuDescriptorHandle
{
	usz ptr;
}

struct GpuDescriptorHandle
{
	ulong ptr;
}

alias GpuVirtualAddress = ulong;

struct ShaderBytecode
{
	void* bytecode;
	usz length;
}

struct CachedPipelineState
{
	void* cached_blob;
	usz cached_blob_size_in_bytes;
}

struct HeapProperties
{
	HeapType type;
	CpuPageProperty cpu_page_property;
	MemoryPool memory_pool_preference;
	uint creation_node_mask;
	uint visible_node_mask;
}

struct HeapDesc
{
	ulong size_in_bytes;
	HeapProperties properties;
	ulong alignment;
	HeapFlags flags;
}

struct ResourceDesc
{
	ResourceDimension dimension;
	ulong alignment;
	ulong width;
	uint height;
	ushort depth_or_array_size;
	ushort mip_levels;
	Format format;
	SampleDesc sample_desc;
	TextureLayout layout;
	ResourceFlags flags;
}

struct ResourceAllocationInfo
{
	ulong size_in_bytes;
	ulong alignment;
}

struct DepthStencilValue
{
	float depth;
	char stencil;
}

struct ClearValue
{
	Format format;
	union
	{
		float[4] color;
		DepthStencilValue depth_stencil;
	}
}

struct ResourceTransitionBarrier
{
	Resource* resource;
	uint subresource;
	ResourceStates state_before;
	ResourceStates state_after;
}

struct ResourceAliasingBarrier
{
	Resource* resource_before;
	Resource* resource_after;
}

struct ResourceUavBarrier
{
	Resource* resource;
}

struct ResourceBarrier
{
	ResourceBarrierType type;
	ResourceBarrierFlags flags;
	union
	{
		ResourceTransitionBarrier transition;
		ResourceAliasingBarrier aliasing;
		ResourceUavBarrier uav;
	}
}

struct SubresourceFootprint
{
	Format format;
	uint width;
	uint height;
	uint depth;
	uint row_pitch;
}

struct PlacedSubresourceFootprint
{
	ulong offset;
	SubresourceFootprint footprint;
}

struct TextureCopyLocation
{
	Resource* resource;
	TextureCopyType type;
	union
	{
		PlacedSubresourceFootprint placed_footprint;
		uint subresource_index;
	}
}

struct VertexBufferView
{
	GpuVirtualAddress buffer_location;
	uint size_in_bytes;
	uint stride_in_bytes;
}

struct IndexBufferView
{
	GpuVirtualAddress buffer_location;
	uint size_in_bytes;
	Format format;
}

struct CommandQueueDesc
{
	CommandListType type;
	int priority;
	CommandQueueFlags flags;
	uint node_mask;
}

struct DescriptorHeapDesc
{
	DescriptorHeapType type;
	uint num_descriptors;
	DescriptorHeapFlags flags;
	uint node_mask;
}

struct QueryHeapDesc
{
	QueryHeapType type;
	uint count;
	uint node_mask;
}

struct SamplerDesc
{
	Filter filter;
	TextureAddressMode address_u;
	TextureAddressMode address_v;
	TextureAddressMode address_w;
	float mip_lod_bias;
	uint max_anisotropy;
	ComparisonFunc comparison_func;
	float[4] border_color;
	float min_lod;
	float max_lod;
}

struct ConstantBufferViewDesc
{
	GpuVirtualAddress buffer_location;
	uint size_in_bytes;
}

// -- View descs ----------------------------------------------------------------

struct BufferSrv
{
	ulong first_element;
	uint num_elements;
	uint structure_byte_stride;
	BufferSrvFlags flags;
}

struct Tex2DSrv
{
	uint most_detailed_mip;
	uint mip_levels;
	uint plane_slice;
	float resource_min_lod_clamp;
}

struct Tex2DArraySrv
{
	uint most_detailed_mip;
	uint mip_levels;
	uint first_array_slice;
	uint array_size;
	uint plane_slice;
	float resource_min_lod_clamp;
}

struct Tex3DSrv
{
	uint most_detailed_mip;
	uint mip_levels;
	float resource_min_lod_clamp;
}

struct TexCubeSrv
{
	uint most_detailed_mip;
	uint mip_levels;
	float resource_min_lod_clamp;
}

struct RaytracingAccelerationStructureSrv
{
	GpuVirtualAddress location;
}

struct ShaderResourceViewDesc
{
	Format format;
	SrvDimension view_dimension;
	uint shader_4_component_mapping;
	union
	{
		BufferSrv buffer;
		Tex2DSrv texture2d;
		Tex2DArraySrv texture2d_array;
		Tex3DSrv texture3d;
		TexCubeSrv texture_cube;
		RaytracingAccelerationStructureSrv raytracing_acceleration_structure;
	}
}

struct BufferUav
{
	ulong first_element;
	uint num_elements;
	uint structure_byte_stride;
	ulong counter_offset_in_bytes;
	BufferUavFlags flags;
}

struct Tex2DUav
{
	uint mip_slice;
	uint plane_slice;
}

struct Tex2DArrayUav
{
	uint mip_slice;
	uint first_array_slice;
	uint array_size;
	uint plane_slice;
}

struct Tex3DUav
{
	uint mip_slice;
	uint first_w_slice;
	uint w_size;
}

struct UnorderedAccessViewDesc
{
	Format format;
	UavDimension view_dimension;
	union
	{
		BufferUav buffer;
		Tex2DUav texture2d;
		Tex2DArrayUav texture2d_array;
		Tex3DUav texture3d;
	}
}

struct BufferRtv
{
	ulong first_element;
	uint num_elements;
}

struct Tex2DRtv
{
	uint mip_slice;
	uint plane_slice;
}

struct Tex2DArrayRtv
{
	uint mip_slice;
	uint first_array_slice;
	uint array_size;
	uint plane_slice;
}

struct Tex3DRtv
{
	uint mip_slice;
	uint first_w_slice;
	uint w_size;
}

struct RenderTargetViewDesc
{
	Format format;
	RtvDimension view_dimension;
	union
	{
		BufferRtv buffer;
		Tex2DRtv texture2d;
		Tex2DArrayRtv texture2d_array;
		Tex3DRtv texture3d;
	}
}

struct Tex2DDsv
{
	uint mip_slice;
}

struct Tex2DArrayDsv
{
	uint mip_slice;
	uint first_array_slice;
	uint array_size;
}

struct DepthStencilViewDesc
{
	Format format;
	DsvDimension view_dimension;
	DsvFlags flags;
	union
	{
		Tex2DDsv texture2d;
		Tex2DArrayDsv texture2d_array;
	}
}

// -- Root signature --------------------------------------------------------------

// D3D12_DESCRIPTOR_RANGE (v1.0).
struct DescriptorRange
{
	DescriptorRangeType range_type;
	uint num_descriptors;
	uint base_shader_register;
	uint register_space;
	uint offset_in_descriptors_from_table_start;
}

// D3D12_DESCRIPTOR_RANGE1 (v1.1).
struct DescriptorRange1
{
	DescriptorRangeType range_type;
	uint num_descriptors;
	uint base_shader_register;
	uint register_space;
	DescriptorRangeFlags flags;
	uint offset_in_descriptors_from_table_start;
}

struct RootConstants
{
	uint shader_register;
	uint register_space;
	uint num_32bit_values;
}

struct RootDescriptor
{
	uint shader_register;
	uint register_space;
}

struct RootDescriptor1
{
	uint shader_register;
	uint register_space;
	RootDescriptorFlags flags;
}

struct RootDescriptorTable
{
	uint num_descriptor_ranges;
	DescriptorRange* descriptor_ranges;
}

struct RootDescriptorTable1
{
	uint num_descriptor_ranges;
	DescriptorRange1* descriptor_ranges;
}

struct RootParameter
{
	RootParameterType parameter_type;
	union
	{
		RootDescriptorTable descriptor_table;
		RootConstants constants;
		RootDescriptor descriptor;
	}
	ShaderVisibility shader_visibility;
}

struct RootParameter1
{
	RootParameterType parameter_type;
	union
	{
		RootDescriptorTable1 descriptor_table;
		RootConstants constants;
		RootDescriptor1 descriptor;
	}
	ShaderVisibility shader_visibility;
}

struct StaticSamplerDesc
{
	Filter filter;
	TextureAddressMode address_u;
	TextureAddressMode address_v;
	TextureAddressMode address_w;
	float mip_lod_bias;
	uint max_anisotropy;
	ComparisonFunc comparison_func;
	StaticBorderColor border_color;
	float min_lod;
	float max_lod;
	uint shader_register;
	uint register_space;
	ShaderVisibility shader_visibility;
}

struct RootSignatureDesc
{
	uint num_parameters;
	RootParameter* parameters;
	uint num_static_samplers;
	StaticSamplerDesc* static_samplers;
	RootSignatureFlags flags;
}

struct RootSignatureDesc1
{
	uint num_parameters;
	RootParameter1* parameters;
	uint num_static_samplers;
	StaticSamplerDesc* static_samplers;
	RootSignatureFlags flags;
}

struct VersionedRootSignatureDesc
{
	RootSignatureVersion version;
	union
	{
		RootSignatureDesc desc_1_0;
		RootSignatureDesc1 desc_1_1;
	}
}

// -- Pipeline state --------------------------------------------------------------

struct SoDeclarationEntry
{
	uint stream;
	ZString semantic_name;
	uint semantic_index;
	char start_component;
	char component_count;
	char output_slot;
}

struct StreamOutputDesc
{
	SoDeclarationEntry* so_declaration;
	uint num_entries;
	uint* buffer_strides;
	uint num_strides;
	uint rasterized_stream;
}

struct RenderTargetBlendDesc
{
	Bool32 blend_enable;
	Bool32 logic_op_enable;
	Blend src_blend;
	Blend dest_blend;
	BlendOp blend_op;
	Blend src_blend_alpha;
	Blend dest_blend_alpha;
	BlendOp blend_op_alpha;
	LogicOp logic_op;
	ColorWriteEnable render_target_write_mask;
}

struct BlendDesc
{
	Bool32 alpha_to_coverage_enable;
	Bool32 independent_blend_enable;
	RenderTargetBlendDesc[8] render_target;
}

struct RasterizerDesc
{
	FillMode fill_mode;
	CullMode cull_mode;
	Bool32 front_counter_clockwise;
	int depth_bias;
	float depth_bias_clamp;
	float slope_scaled_depth_bias;
	Bool32 depth_clip_enable;
	Bool32 multisample_enable;
	Bool32 antialiased_line_enable;
	uint forced_sample_count;
	ConservativeRasterizationMode conservative_raster;
}

struct DepthStencilOpDesc
{
	StencilOp stencil_fail_op;
	StencilOp stencil_depth_fail_op;
	StencilOp stencil_pass_op;
	ComparisonFunc stencil_func;
}

struct DepthStencilDesc
{
	Bool32 depth_enable;
	DepthWriteMask depth_write_mask;
	ComparisonFunc depth_func;
	Bool32 stencil_enable;
	char stencil_read_mask;
	char stencil_write_mask;
	DepthStencilOpDesc front_face;
	DepthStencilOpDesc back_face;
}

struct InputElementDesc
{
	ZString semantic_name;
	uint semantic_index;
	Format format;
	uint input_slot;
	uint aligned_byte_offset;
	InputClassification input_slot_class;
	uint instance_data_step_rate;
}

struct InputLayoutDesc
{
	InputElementDesc* input_element_descs;
	uint num_elements;
}

struct GraphicsPipelineStateDesc
{
	RootSignature* root_signature;
	ShaderBytecode vs;
	ShaderBytecode ps;
	ShaderBytecode ds;
	ShaderBytecode hs;
	ShaderBytecode gs;
	StreamOutputDesc stream_output;
	BlendDesc blend_state;
	uint sample_mask;
	RasterizerDesc rasterizer_state;
	DepthStencilDesc depth_stencil_state;
	InputLayoutDesc input_layout;
	IndexBufferStripCutValue ib_strip_cut_value;
	PrimitiveTopologyType primitive_topology_type;
	uint num_render_targets;
	Format[8] rtv_formats;
	Format dsv_format;
	SampleDesc sample_desc;
	uint node_mask;
	CachedPipelineState cached_pso;
	PipelineStateFlags flags;
}

struct ComputePipelineStateDesc
{
	RootSignature* root_signature;
	ShaderBytecode cs;
	uint node_mask;
	CachedPipelineState cached_pso;
	PipelineStateFlags flags;
}

// -- Indirect execution ------------------------------------------------------------

struct IndirectArgumentVertexBuffer
{
	uint slot;
}

struct IndirectArgumentConstant
{
	uint root_parameter_index;
	uint dest_offset_in_32bit_values;
	uint num_32bit_values;
}

struct IndirectArgumentRootView
{
	uint root_parameter_index;
}

struct IndirectArgumentDesc
{
	IndirectArgumentType type;
	union
	{
		IndirectArgumentVertexBuffer vertex_buffer;
		IndirectArgumentConstant constant;
		IndirectArgumentRootView view;
	}
}

struct CommandSignatureDesc
{
	uint byte_stride;
	uint num_argument_descs;
	IndirectArgumentDesc* argument_descs;
	uint node_mask;
}

// Argument buffer records consumed by ExecuteIndirect.
struct DrawArguments
{
	uint vertex_count_per_instance;
	uint instance_count;
	uint start_vertex_location;
	uint start_instance_location;
}

struct DrawIndexedArguments
{
	uint index_count_per_instance;
	uint instance_count;
	uint start_index_location;
	int base_vertex_location;
	uint start_instance_location;
}

struct DispatchArguments
{
	uint thread_group_count_x;
	uint thread_group_count_y;
	uint thread_group_count_z;
}

// -- Feature data ------------------------------------------------------------------

struct FeatureDataOptions5
{
	Bool32 srv_only_tiled_resource_tier3;
	RenderPassTier render_passes_tier;
	RaytracingTier raytracing_tier;
}

struct FeatureDataOptions7
{
	MeshShaderTier mesh_shader_tier;
	uint sampler_feedback_tier;
}

struct FeatureDataShaderModel
{
	ShaderModel highest_shader_model;
}

struct FeatureDataRootSignature
{
	RootSignatureVersion highest_version;
}

struct FeatureDataFeatureLevels
{
	uint num_feature_levels;
	FeatureLevel* feature_levels_requested;
	FeatureLevel max_supported_feature_level;
}

struct FeatureDataGpuVirtualAddressSupport
{
	uint max_gpu_virtual_address_bits_per_resource;
	uint max_gpu_virtual_address_bits_per_process;
}

// -- Render pass descs -----------------------------------------------------------------

struct RenderPassBeginningAccessClear
{
	ClearValue clear_value;
}

struct RenderPassBeginningAccess
{
	RenderPassBeginningAccessType type;
	union
	{
		RenderPassBeginningAccessClear clear;
	}
}

struct ResolveSubresourceParameters
{
	uint src_subresource;
	uint dst_subresource;
	uint dst_x;
	uint dst_y;
	Rect src_rect;
}

struct RenderPassEndingAccessResolve
{
	Resource* src_resource;
	Resource* dst_resource;
	uint subresource_count;
	ResolveSubresourceParameters* subresource_parameters;
	Format format;
	ResolveMode resolve_mode;
	Bool32 preserve_resolve_source;
}

struct RenderPassEndingAccess
{
	RenderPassEndingAccessType type;
	union
	{
		RenderPassEndingAccessResolve resolve;
	}
}

struct RenderPassRenderTargetDesc
{
	CpuDescriptorHandle cpu_descriptor;
	RenderPassBeginningAccess beginning_access;
	RenderPassEndingAccess ending_access;
}

struct RenderPassDepthStencilDesc
{
	CpuDescriptorHandle cpu_descriptor;
	RenderPassBeginningAccess depth_beginning_access;
	RenderPassBeginningAccess stencil_beginning_access;
	RenderPassEndingAccess depth_ending_access;
	RenderPassEndingAccess stencil_ending_access;
}

// -- Raytracing structs ------------------------------------------------------------------

struct GpuVirtualAddressRange
{
	GpuVirtualAddress start_address;
	ulong size_in_bytes;
}

struct GpuVirtualAddressAndStride
{
	GpuVirtualAddress start_address;
	ulong stride_in_bytes;
}

struct GpuVirtualAddressRangeAndStride
{
	GpuVirtualAddress start_address;
	ulong size_in_bytes;
	ulong stride_in_bytes;
}

struct RaytracingGeometryTrianglesDesc
{
	GpuVirtualAddress transform_3x4;
	Format index_format;
	Format vertex_format;
	uint index_count;
	uint vertex_count;
	GpuVirtualAddress index_buffer;
	GpuVirtualAddressAndStride vertex_buffer;
}

struct RaytracingGeometryAabbsDesc
{
	ulong aabb_count;
	GpuVirtualAddressAndStride aabbs;
}

struct RaytracingGeometryDesc
{
	RaytracingGeometryType type;
	RaytracingGeometryFlags flags;
	union
	{
		RaytracingGeometryTrianglesDesc triangles;
		RaytracingGeometryAabbsDesc aabbs;
	}
}

struct BuildRaytracingAccelerationStructureInputs
{
	RaytracingAccelerationStructureType type;
	RaytracingAccelerationStructureBuildFlags flags;
	uint num_descs;
	ElementsLayout descs_layout;
	union
	{
		GpuVirtualAddress instance_descs;
		RaytracingGeometryDesc* geometry_descs;
		RaytracingGeometryDesc** geometry_descs_ptrs;
	}
}

struct BuildRaytracingAccelerationStructureDesc
{
	GpuVirtualAddress dest_acceleration_structure_data;
	BuildRaytracingAccelerationStructureInputs inputs;
	GpuVirtualAddress source_acceleration_structure_data;
	GpuVirtualAddress scratch_acceleration_structure_data;
}

struct RaytracingAccelerationStructurePrebuildInfo
{
	ulong result_data_max_size_in_bytes;
	ulong scratch_data_size_in_bytes;
	ulong update_scratch_data_size_in_bytes;
}

struct RaytracingAccelerationStructurePostbuildInfoDesc
{
	GpuVirtualAddress dest_buffer;
	RaytracingAccelerationStructurePostbuildInfoType info_type;
}

// D3D12_RAYTRACING_INSTANCE_DESC. The two packed 24+8 bit fields are exposed
// as raw words; use the helpers below to build them.
struct RaytracingInstanceDesc
{
	float[12] transform;
	uint instance_id_and_mask;
	uint hit_group_offset_and_flags;
	GpuVirtualAddress acceleration_structure;
}

// InstanceID (low 24 bits) | InstanceMask (high 8 bits).
fn uint pack_instance_id_and_mask(uint instance_id, char mask) => (instance_id & 0xFFFFFF) | ((uint)mask << 24);

// InstanceContributionToHitGroupIndex (low 24 bits) | Flags (high 8 bits).
fn uint pack_hit_group_offset_and_flags(uint hit_group_offset, RaytracingInstanceFlags flags) => (hit_group_offset & 0xFFFFFF) | (((uint)flags & 0xFF) << 24);

struct DispatchRaysDesc
{
	GpuVirtualAddressRange ray_generation_shader_record;
	GpuVirtualAddressRangeAndStride miss_shader_table;
	GpuVirtualAddressRangeAndStride hit_group_table;
	GpuVirtualAddressRangeAndStride callable_shader_table;
	uint width;
	uint height;
	uint depth;
}

struct StateSubobject
{
	StateSubobjectType type;
	void* desc;
}

struct StateObjectDesc
{
	StateObjectType type;
	uint num_subobjects;
	StateSubobject* subobjects;
}

struct ExportDesc
{
	Char16* name;
	Char16* export_to_rename;
	uint flags;
}

struct DxilLibraryDesc
{
	ShaderBytecode dxil_library;
	uint num_exports;
	ExportDesc* exports;
}

struct HitGroupDesc
{
	Char16* hit_group_export;
	HitGroupType type;
	Char16* any_hit_shader_import;
	Char16* closest_hit_shader_import;
	Char16* intersection_shader_import;
}

struct RaytracingShaderConfig
{
	uint max_payload_size_in_bytes;
	uint max_attribute_size_in_bytes;
}

struct RaytracingPipelineConfig
{
	uint max_trace_recursion_depth;
}

struct GlobalRootSignature
{
	RootSignature* global_root_signature;
}

struct LocalRootSignature
{
	RootSignature* local_root_signature;
}

struct SubobjectToExportsAssociation
{
	StateSubobject* subobject_to_associate;
	uint num_exports;
	Char16** exports;
}

// -- Interfaces ------------------------------------------------------------------------

const Guid IID_OBJECT             = { 0xc4fec28f, 0x7966, 0x4e95, { 0x9f, 0x94, 0xf4, 0x31, 0xcb, 0x56, 0xc3, 0xb8 } };
const Guid IID_DEVICE_CHILD       = { 0x905db94b, 0xa00c, 0x4140, { 0x9d, 0xf5, 0x2b, 0x64, 0xca, 0x9e, 0xa3, 0x57 } };
const Guid IID_PAGEABLE           = { 0x63ee58fb, 0x1268, 0x4835, { 0x86, 0xda, 0xf0, 0x08, 0xce, 0x62, 0xf0, 0xd6 } };
const Guid IID_DEVICE             = { 0x189819f1, 0x1db6, 0x4b57, { 0xbe, 0x54, 0x18, 0x21, 0x33, 0x9b, 0x85, 0xf7 } };
const Guid IID_DEVICE5            = { 0x8b4f173b, 0x2fea, 0x4b80, { 0x8f, 0x58, 0x43, 0x07, 0x19, 0x1a, 0xb9, 0x5d } };
const Guid IID_COMMAND_QUEUE      = { 0x0ec870a6, 0x5d7e, 0x4c22, { 0x8c, 0xfc, 0x5b, 0xaa, 0xe0, 0x76, 0x16, 0xed } };
const Guid IID_COMMAND_ALLOCATOR  = { 0x6102dee4, 0xaf59, 0x4b09, { 0xb9, 0x99, 0xb4, 0x4d, 0x73, 0xf0, 0x9b, 0x24 } };
const Guid IID_COMMAND_LIST       = { 0x7116d91c, 0xe7e4, 0x47ce, { 0xb8, 0xc6, 0xec, 0x81, 0x68, 0xf4, 0x37, 0xe5 } };
const Guid IID_GRAPHICS_COMMAND_LIST  = { 0x5b160d0f, 0xac1b, 0x4185, { 0x8b, 0xa8, 0xb3, 0xae, 0x42, 0xa5, 0xa4, 0x55 } };
const Guid IID_GRAPHICS_COMMAND_LIST4 = { 0x8754318e, 0xd3a9, 0x4541, { 0x98, 0xcf, 0x64, 0x5b, 0x50, 0xdc, 0x48, 0x74 } };
const Guid IID_GRAPHICS_COMMAND_LIST5 = { 0x55050859, 0x4024, 0x474c, { 0x87, 0xf5, 0x64, 0x72, 0xea, 0xee, 0x44, 0xea } };
const Guid IID_FENCE              = { 0x0a753dcf, 0xc4d8, 0x4b91, { 0xad, 0xf6, 0xbe, 0x5a, 0x60, 0xd9, 0x5a, 0x76 } };
const Guid IID_RESOURCE           = { 0x696442be, 0xa72e, 0x4059, { 0xbc, 0x79, 0x5b, 0x5c, 0x98, 0x04, 0x0f, 0xad } };
const Guid IID_DESCRIPTOR_HEAP    = { 0x8efb471d, 0x616c, 0x4f49, { 0x90, 0xf7, 0x12, 0x7b, 0xb7, 0x63, 0xfa, 0x51 } };
const Guid IID_ROOT_SIGNATURE     = { 0xc54a6b66, 0x72df, 0x4ee8, { 0x8b, 0xe5, 0xa9, 0x46, 0xa1, 0x42, 0x92, 0x14 } };
const Guid IID_PIPELINE_STATE     = { 0x765a30f3, 0xf624, 0x4c6f, { 0xa8, 0x28, 0xac, 0xe9, 0x48, 0x62, 0x24, 0x45 } };
const Guid IID_COMMAND_SIGNATURE  = { 0xc36a797c, 0xec80, 0x4f0a, { 0x89, 0x85, 0xa7, 0xb2, 0x47, 0x50, 0x82, 0xd1 } };
const Guid IID_QUERY_HEAP         = { 0x0d9658ae, 0xed45, 0x469e, { 0xa6, 0x1d, 0x97, 0x0e, 0xc5, 0x83, 0xca, 0xb4 } };
const Guid IID_STATE_OBJECT       = { 0x47016943, 0xfca8, 0x4594, { 0x93, 0xea, 0xaf, 0x25, 0x8b, 0x55, 0x34, 0x6d } };
const Guid IID_STATE_OBJECT_PROPERTIES = { 0xde5fa827, 0x9bf9, 0x4f26, { 0x89, 0xff, 0xd7, 0xf5, 0x6f, 0xde, 0x38, 0x60 } };
const Guid IID_DEBUG              = { 0x344488b7, 0x6846, 0x474b, { 0xb9, 0x89, 0xf0, 0x27, 0x44, 0x82, 0x45, 0xe0 } };

alias ProcObjectSetName = fn HResult(void* self, Char16* name);

// ID3D12Object / ID3D12DeviceChild.
struct ObjectVtbl
{
	inline UnknownVtbl base;
	void* get_private_data;
	void* set_private_data;
	void* set_private_data_interface;
	ProcObjectSetName set_name;
}

alias ProcDeviceChildGetDevice = fn HResult(void* self, Guid* riid, void** device);

struct DeviceChildVtbl
{
	inline ObjectVtbl base;
	ProcDeviceChildGetDevice get_device;
}

alias ProcDebugEnableDebugLayer = fn void(void* self);

// ID3D12Debug.
struct DebugVtbl
{
	inline UnknownVtbl base;
	ProcDebugEnableDebugLayer enable_debug_layer;
}

struct Debug
{
	DebugVtbl* vtbl;
}

alias ProcFenceGetCompletedValue = fn ulong(void* self);
alias ProcFenceSetEventOnCompletion = fn HResult(void* self, ulong value, Handle event);
alias ProcFenceSignal = fn HResult(void* self, ulong value);

// ID3D12Fence.
struct FenceVtbl
{
	inline DeviceChildVtbl base;
	ProcFenceGetCompletedValue get_completed_value;
	ProcFenceSetEventOnCompletion set_event_on_completion;
	ProcFenceSignal signal;
}

struct Fence
{
	FenceVtbl* vtbl;
}

alias ProcCommandAllocatorReset = fn HResult(void* self);

// ID3D12CommandAllocator.
struct CommandAllocatorVtbl
{
	inline DeviceChildVtbl base;
	ProcCommandAllocatorReset reset;
}

struct CommandAllocator
{
	CommandAllocatorVtbl* vtbl;
}

alias ProcCommandQueueExecuteCommandLists = fn void(void* self, uint num_command_lists, CommandList** command_lists);
alias ProcCommandQueueSignal = fn HResult(void* self, Fence* fence, ulong value);
alias ProcCommandQueueWait = fn HResult(void* self, Fence* fence, ulong value);
alias ProcCommandQueueGetTimestampFrequency = fn HResult(void* self, ulong* frequency);
alias ProcCommandQueueGetDesc = fn CommandQueueDesc*(void* self, CommandQueueDesc* ret);

// ID3D12CommandQueue.
struct CommandQueueVtbl
{
	inline DeviceChildVtbl base;
	void* update_tile_mappings;
	void* copy_tile_mappings;
	ProcCommandQueueExecuteCommandLists execute_command_lists;
	void* set_marker;
	void* begin_event;
	void* end_event;
	ProcCommandQueueSignal signal;
	ProcCommandQueueWait wait;
	ProcCommandQueueGetTimestampFrequency get_timestamp_frequency;
	void* get_clock_calibration;
	ProcCommandQueueGetDesc get_desc;
}

struct CommandQueue
{
	CommandQueueVtbl* vtbl;
}

alias ProcCommandListGetType = fn CommandListType(void* self);

// ID3D12CommandList (base of the graphics list).
struct CommandListVtbl
{
	inline DeviceChildVtbl base;
	ProcCommandListGetType get_type;
}

struct CommandList
{
	CommandListVtbl* vtbl;
}

alias ProcGraphicsCommandListClose = fn HResult(void* self);
alias ProcGraphicsCommandListReset = fn HResult(void* self, CommandAllocator* allocator, PipelineState* initial_state);
alias ProcGraphicsCommandListClearState = fn void(void* self, PipelineState* pipeline_state);
alias ProcGraphicsCommandListDrawInstanced = fn void(void* self, uint vertex_count_per_instance, uint instance_count, uint start_vertex_location, uint start_instance_location);
alias ProcGraphicsCommandListDrawIndexedInstanced = fn void(void* self, uint index_count_per_instance, uint instance_count, uint start_index_location, int base_vertex_location, uint start_instance_location);
alias ProcGraphicsCommandListDispatch = fn void(void* self, uint x, uint y, uint z);
alias ProcGraphicsCommandListCopyBufferRegion = fn void(void* self, Resource* dst, ulong dst_offset, Resource* src, ulong src_offset, ulong num_bytes);
alias ProcGraphicsCommandListCopyTextureRegion = fn void(void* self, TextureCopyLocation* dst, uint dst_x, uint dst_y, uint dst_z, TextureCopyLocation* src, ResourceBox* src_box);
alias ProcGraphicsCommandListCopyResource = fn void(void* self, Resource* dst, Resource* src);
alias ProcGraphicsCommandListResolveSubresource = fn void(void* self, Resource* dst, uint dst_subresource, Resource* src, uint src_subresource, Format format);
alias ProcGraphicsCommandListIaSetPrimitiveTopology = fn void(void* self, PrimitiveTopology topology);
alias ProcGraphicsCommandListRsSetViewports = fn void(void* self, uint num_viewports, Viewport* viewports);
alias ProcGraphicsCommandListRsSetScissorRects = fn void(void* self, uint num_rects, Rect* rects);
alias ProcGraphicsCommandListOmSetBlendFactor = fn void(void* self, float[4]* blend_factor);
alias ProcGraphicsCommandListOmSetStencilRef = fn void(void* self, uint stencil_ref);
alias ProcGraphicsCommandListSetPipelineState = fn void(void* self, PipelineState* pipeline_state);
alias ProcGraphicsCommandListResourceBarrier = fn void(void* self, uint num_barriers, ResourceBarrier* barriers);
alias ProcGraphicsCommandListExecuteBundle = fn void(void* self, GraphicsCommandList* command_list);
alias ProcGraphicsCommandListSetDescriptorHeaps = fn void(void* self, uint num_heaps, DescriptorHeap** heaps);
alias ProcGraphicsCommandListSetComputeRootSignature = fn void(void* self, RootSignature* root_signature);
alias ProcGraphicsCommandListSetGraphicsRootSignature = fn void(void* self, RootSignature* root_signature);
alias ProcGraphicsCommandListSetComputeRootDescriptorTable = fn void(void* self, uint root_parameter_index, GpuDescriptorHandle base_descriptor);
alias ProcGraphicsCommandListSetGraphicsRootDescriptorTable = fn void(void* self, uint root_parameter_index, GpuDescriptorHandle base_descriptor);
alias ProcGraphicsCommandListSetComputeRoot32bitConstant = fn void(void* self, uint root_parameter_index, uint data, uint dest_offset);
alias ProcGraphicsCommandListSetGraphicsRoot32bitConstant = fn void(void* self, uint root_parameter_index, uint data, uint dest_offset);
alias ProcGraphicsCommandListSetComputeRoot32bitConstants = fn void(void* self, uint root_parameter_index, uint num_values, void* data, uint dest_offset);
alias ProcGraphicsCommandListSetGraphicsRoot32bitConstants = fn void(void* self, uint root_parameter_index, uint num_values, void* data, uint dest_offset);
alias ProcGraphicsCommandListSetComputeRootConstantBufferView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListSetGraphicsRootConstantBufferView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListSetComputeRootShaderResourceView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListSetGraphicsRootShaderResourceView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListSetComputeRootUnorderedAccessView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListSetGraphicsRootUnorderedAccessView = fn void(void* self, uint root_parameter_index, GpuVirtualAddress address);
alias ProcGraphicsCommandListIaSetIndexBuffer = fn void(void* self, IndexBufferView* view);
alias ProcGraphicsCommandListIaSetVertexBuffers = fn void(void* self, uint start_slot, uint num_views, VertexBufferView* views);
alias ProcGraphicsCommandListOmSetRenderTargets = fn void(void* self, uint num_render_target_descriptors, CpuDescriptorHandle* render_target_descriptors, Bool32 single_descriptor_handle, CpuDescriptorHandle* depth_stencil_descriptor);
alias ProcGraphicsCommandListClearDepthStencilView = fn void(void* self, CpuDescriptorHandle dsv, ClearFlags flags, float depth, char stencil, uint num_rects, Rect* rects);
alias ProcGraphicsCommandListClearRenderTargetView = fn void(void* self, CpuDescriptorHandle rtv, float[4]* color_rgba, uint num_rects, Rect* rects);
alias ProcGraphicsCommandListClearUnorderedAccessViewUint = fn void(void* self, GpuDescriptorHandle view_gpu, CpuDescriptorHandle view_cpu, Resource* resource, uint[4]* values, uint num_rects, Rect* rects);
alias ProcGraphicsCommandListClearUnorderedAccessViewFloat = fn void(void* self, GpuDescriptorHandle view_gpu, CpuDescriptorHandle view_cpu, Resource* resource, float[4]* values, uint num_rects, Rect* rects);
alias ProcGraphicsCommandListBeginQuery = fn void(void* self, QueryHeap* heap, QueryType type, uint index);
alias ProcGraphicsCommandListEndQuery = fn void(void* self, QueryHeap* heap, QueryType type, uint index);
alias ProcGraphicsCommandListResolveQueryData = fn void(void* self, QueryHeap* heap, QueryType type, uint start_index, uint num_queries, Resource* dst_buffer, ulong aligned_dst_buffer_offset);
alias ProcGraphicsCommandListExecuteIndirect = fn void(void* self, CommandSignature* command_signature, uint max_command_count, Resource* argument_buffer, ulong argument_buffer_offset, Resource* count_buffer, ulong count_buffer_offset);
alias ProcGraphicsCommandListBeginRenderPass = fn void(void* self, uint num_render_targets, RenderPassRenderTargetDesc* render_targets, RenderPassDepthStencilDesc* depth_stencil, RenderPassFlags flags);
alias ProcGraphicsCommandListEndRenderPass = fn void(void* self);
alias ProcGraphicsCommandListBuildRaytracingAccelerationStructure = fn void(void* self, BuildRaytracingAccelerationStructureDesc* desc, uint num_postbuild_info_descs, RaytracingAccelerationStructurePostbuildInfoDesc* postbuild_info_descs);
alias ProcGraphicsCommandListEmitRaytracingAccelerationStructurePostbuildInfo = fn void(void* self, RaytracingAccelerationStructurePostbuildInfoDesc* desc, uint num_source_acceleration_structures, GpuVirtualAddress* source_acceleration_structure_data);
alias ProcGraphicsCommandListCopyRaytracingAccelerationStructure = fn void(void* self, GpuVirtualAddress dest_acceleration_structure_data, GpuVirtualAddress source_acceleration_structure_data, RaytracingAccelerationStructureCopyMode mode);
alias ProcGraphicsCommandListSetPipelineState1 = fn void(void* self, StateObject* state_object);
alias ProcGraphicsCommandListDispatchRays = fn void(void* self, DispatchRaysDesc* desc);

// ID3D12GraphicsCommandList .. ID3D12GraphicsCommandList5.
struct GraphicsCommandListVtbl
{
	inline CommandListVtbl base;
	ProcGraphicsCommandListClose close;
	ProcGraphicsCommandListReset reset;
	ProcGraphicsCommandListClearState clear_state;
	ProcGraphicsCommandListDrawInstanced draw_instanced;
	ProcGraphicsCommandListDrawIndexedInstanced draw_indexed_instanced;
	ProcGraphicsCommandListDispatch dispatch;
	ProcGraphicsCommandListCopyBufferRegion copy_buffer_region;
	ProcGraphicsCommandListCopyTextureRegion copy_texture_region;
	ProcGraphicsCommandListCopyResource copy_resource;
	void* copy_tiles;
	ProcGraphicsCommandListResolveSubresource resolve_subresource;
	ProcGraphicsCommandListIaSetPrimitiveTopology ia_set_primitive_topology;
	ProcGraphicsCommandListRsSetViewports rs_set_viewports;
	ProcGraphicsCommandListRsSetScissorRects rs_set_scissor_rects;
	ProcGraphicsCommandListOmSetBlendFactor om_set_blend_factor;
	ProcGraphicsCommandListOmSetStencilRef om_set_stencil_ref;
	ProcGraphicsCommandListSetPipelineState set_pipeline_state;
	ProcGraphicsCommandListResourceBarrier resource_barrier;
	ProcGraphicsCommandListExecuteBundle execute_bundle;
	ProcGraphicsCommandListSetDescriptorHeaps set_descriptor_heaps;
	ProcGraphicsCommandListSetComputeRootSignature set_compute_root_signature;
	ProcGraphicsCommandListSetGraphicsRootSignature set_graphics_root_signature;
	ProcGraphicsCommandListSetComputeRootDescriptorTable set_compute_root_descriptor_table;
	ProcGraphicsCommandListSetGraphicsRootDescriptorTable set_graphics_root_descriptor_table;
	ProcGraphicsCommandListSetComputeRoot32bitConstant set_compute_root_32bit_constant;
	ProcGraphicsCommandListSetGraphicsRoot32bitConstant set_graphics_root_32bit_constant;
	ProcGraphicsCommandListSetComputeRoot32bitConstants set_compute_root_32bit_constants;
	ProcGraphicsCommandListSetGraphicsRoot32bitConstants set_graphics_root_32bit_constants;
	ProcGraphicsCommandListSetComputeRootConstantBufferView set_compute_root_constant_buffer_view;
	ProcGraphicsCommandListSetGraphicsRootConstantBufferView set_graphics_root_constant_buffer_view;
	ProcGraphicsCommandListSetComputeRootShaderResourceView set_compute_root_shader_resource_view;
	ProcGraphicsCommandListSetGraphicsRootShaderResourceView set_graphics_root_shader_resource_view;
	ProcGraphicsCommandListSetComputeRootUnorderedAccessView set_compute_root_unordered_access_view;
	ProcGraphicsCommandListSetGraphicsRootUnorderedAccessView set_graphics_root_unordered_access_view;
	ProcGraphicsCommandListIaSetIndexBuffer ia_set_index_buffer;
	ProcGraphicsCommandListIaSetVertexBuffers ia_set_vertex_buffers;
	void* so_set_targets;
	ProcGraphicsCommandListOmSetRenderTargets om_set_render_targets;
	ProcGraphicsCommandListClearDepthStencilView clear_depth_stencil_view;
	ProcGraphicsCommandListClearRenderTargetView clear_render_target_view;
	ProcGraphicsCommandListClearUnorderedAccessViewUint clear_unordered_access_view_uint;
	ProcGraphicsCommandListClearUnorderedAccessViewFloat clear_unordered_access_view_float;
	void* discard_resource;
	ProcGraphicsCommandListBeginQuery begin_query;
	ProcGraphicsCommandListEndQuery end_query;
	ProcGraphicsCommandListResolveQueryData resolve_query_data;
	void* set_predication;
	void* set_marker;
	void* begin_event;
	void* end_event;
	ProcGraphicsCommandListExecuteIndirect execute_indirect;
	// ID3D12GraphicsCommandList1
	void* atomic_copy_buffer_uint;
	void* atomic_copy_buffer_uint64;
	void* om_set_depth_bounds;
	void* set_sample_positions;
	void* resolve_subresource_region;
	void* set_view_instance_mask;
	// ID3D12GraphicsCommandList2
	void* write_buffer_immediate;
	// ID3D12GraphicsCommandList3
	void* set_protected_resource_session;
	// ID3D12GraphicsCommandList4
	ProcGraphicsCommandListBeginRenderPass begin_render_pass;
	ProcGraphicsCommandListEndRenderPass end_render_pass;
	void* initialize_meta_command;
	void* execute_meta_command;
	ProcGraphicsCommandListBuildRaytracingAccelerationStructure build_raytracing_acceleration_structure;
	ProcGraphicsCommandListEmitRaytracingAccelerationStructurePostbuildInfo emit_raytracing_acceleration_structure_postbuild_info;
	ProcGraphicsCommandListCopyRaytracingAccelerationStructure copy_raytracing_acceleration_structure;
	ProcGraphicsCommandListSetPipelineState1 set_pipeline_state1;
	ProcGraphicsCommandListDispatchRays dispatch_rays;
	// ID3D12GraphicsCommandList5
	void* rs_set_shading_rate;
	void* rs_set_shading_rate_image;
}

struct GraphicsCommandList
{
	GraphicsCommandListVtbl* vtbl;
}

alias GraphicsCommandList4 = GraphicsCommandList;
alias GraphicsCommandList5 = GraphicsCommandList;

alias ProcResourceMap = fn HResult(void* self, uint subresource, ResourceRange* read_range, void** data);
alias ProcResourceUnmap = fn void(void* self, uint subresource, ResourceRange* written_range);
alias ProcResourceGetDesc = fn ResourceDesc*(void* self, ResourceDesc* ret);
alias ProcResourceGetGpuVirtualAddress = fn GpuVirtualAddress(void* self);

// ID3D12Resource.
struct ResourceVtbl
{
	inline DeviceChildVtbl base;
	ProcResourceMap map;
	ProcResourceUnmap unmap;
	ProcResourceGetDesc get_desc;
	ProcResourceGetGpuVirtualAddress get_gpu_virtual_address;
	void* write_to_subresource;
	void* read_from_subresource;
	void* get_heap_properties;
}

struct Resource
{
	ResourceVtbl* vtbl;
}

alias ProcHeapGetDesc = fn HeapDesc*(void* self, HeapDesc* ret);

// ID3D12Heap.
struct HeapVtbl
{
	inline DeviceChildVtbl base;
	ProcHeapGetDesc get_desc;
}

struct Heap
{
	HeapVtbl* vtbl;
}

alias ProcDescriptorHeapGetDesc = fn DescriptorHeapDesc*(void* self, DescriptorHeapDesc* ret);
alias ProcDescriptorHeapGetCpuDescriptorHandleForHeapStart = fn CpuDescriptorHandle*(void* self, CpuDescriptorHandle* ret);
alias ProcDescriptorHeapGetGpuDescriptorHandleForHeapStart = fn GpuDescriptorHandle*(void* self, GpuDescriptorHandle* ret);

// ID3D12DescriptorHeap.
struct DescriptorHeapVtbl
{
	inline DeviceChildVtbl base;
	ProcDescriptorHeapGetDesc get_desc;
	ProcDescriptorHeapGetCpuDescriptorHandleForHeapStart get_cpu_descriptor_handle_for_heap_start;
	ProcDescriptorHeapGetGpuDescriptorHandleForHeapStart get_gpu_descriptor_handle_for_heap_start;
}

struct DescriptorHeap
{
	DescriptorHeapVtbl* vtbl;
}

// ID3D12RootSignature, ID3D12CommandSignature, ID3D12QueryHeap carry no
// methods of their own beyond ID3D12DeviceChild.
struct RootSignature
{
	DeviceChildVtbl* vtbl;
}

struct CommandSignature
{
	DeviceChildVtbl* vtbl;
}

struct QueryHeap
{
	DeviceChildVtbl* vtbl;
}

alias ProcPipelineStateGetCachedBlob = fn HResult(void* self, Blob** blob);

// ID3D12PipelineState.
struct PipelineStateVtbl
{
	inline DeviceChildVtbl base;
	ProcPipelineStateGetCachedBlob get_cached_blob;
}

struct PipelineState
{
	PipelineStateVtbl* vtbl;
}

// ID3D12StateObject (no methods) and ID3D12StateObjectProperties.
struct StateObject
{
	DeviceChildVtbl* vtbl;
}

alias ProcStateObjectPropertiesGetShaderIdentifier = fn void*(void* self, Char16* export_name);
alias ProcStateObjectPropertiesGetShaderStackSize = fn ulong(void* self, Char16* export_name);
alias ProcStateObjectPropertiesGetPipelineStackSize = fn ulong(void* self);
alias ProcStateObjectPropertiesSetPipelineStackSize = fn void(void* self, ulong pipeline_stack_size_in_bytes);

struct StateObjectPropertiesVtbl
{
	inline UnknownVtbl base;
	ProcStateObjectPropertiesGetShaderIdentifier get_shader_identifier;
	ProcStateObjectPropertiesGetShaderStackSize get_shader_stack_size;
	ProcStateObjectPropertiesGetPipelineStackSize get_pipeline_stack_size;
	ProcStateObjectPropertiesSetPipelineStackSize set_pipeline_stack_size;
}

struct StateObjectProperties
{
	StateObjectPropertiesVtbl* vtbl;
}

alias ProcDeviceGetNodeCount = fn uint(void* self);
alias ProcDeviceCreateCommandQueue = fn HResult(void* self, CommandQueueDesc* desc, Guid* riid, void** command_queue);
alias ProcDeviceCreateCommandAllocator = fn HResult(void* self, CommandListType type, Guid* riid, void** command_allocator);
alias ProcDeviceCreateGraphicsPipelineState = fn HResult(void* self, GraphicsPipelineStateDesc* desc, Guid* riid, void** pipeline_state);
alias ProcDeviceCreateComputePipelineState = fn HResult(void* self, ComputePipelineStateDesc* desc, Guid* riid, void** pipeline_state);
alias ProcDeviceCreateCommandList = fn HResult(void* self, uint node_mask, CommandListType type, CommandAllocator* allocator, PipelineState* initial_state, Guid* riid, void** command_list);
alias ProcDeviceCheckFeatureSupport = fn HResult(void* self, Feature feature, void* feature_support_data, uint size);
alias ProcDeviceCreateDescriptorHeap = fn HResult(void* self, DescriptorHeapDesc* desc, Guid* riid, void** heap);
alias ProcDeviceGetDescriptorHandleIncrementSize = fn uint(void* self, DescriptorHeapType type);
alias ProcDeviceCreateRootSignature = fn HResult(void* self, uint node_mask, void* blob_with_root_signature, usz blob_length, Guid* riid, void** root_signature);
alias ProcDeviceCreateConstantBufferView = fn void(void* self, ConstantBufferViewDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCreateShaderResourceView = fn void(void* self, Resource* resource, ShaderResourceViewDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCreateUnorderedAccessView = fn void(void* self, Resource* resource, Resource* counter_resource, UnorderedAccessViewDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCreateRenderTargetView = fn void(void* self, Resource* resource, RenderTargetViewDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCreateDepthStencilView = fn void(void* self, Resource* resource, DepthStencilViewDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCreateSampler = fn void(void* self, SamplerDesc* desc, CpuDescriptorHandle dest);
alias ProcDeviceCopyDescriptors = fn void(void* self, uint num_dest_ranges, CpuDescriptorHandle* dest_range_starts, uint* dest_range_sizes, uint num_src_ranges, CpuDescriptorHandle* src_range_starts, uint* src_range_sizes, DescriptorHeapType type);
alias ProcDeviceCopyDescriptorsSimple = fn void(void* self, uint num_descriptors, CpuDescriptorHandle dest_range_start, CpuDescriptorHandle src_range_start, DescriptorHeapType type);
alias ProcDeviceGetResourceAllocationInfo = fn ResourceAllocationInfo*(void* self, ResourceAllocationInfo* ret, uint visible_mask, uint num_resource_descs, ResourceDesc* resource_descs);
alias ProcDeviceGetCustomHeapProperties = fn HeapProperties*(void* self, HeapProperties* ret, uint node_mask, HeapType type);
alias ProcDeviceCreateCommittedResource = fn HResult(void* self, HeapProperties* heap_properties, HeapFlags heap_flags, ResourceDesc* desc, ResourceStates initial_state, ClearValue* optimized_clear_value, Guid* riid, void** resource);
alias ProcDeviceCreateHeap = fn HResult(void* self, HeapDesc* desc, Guid* riid, void** heap);
alias ProcDeviceCreatePlacedResource = fn HResult(void* self, Heap* heap, ulong heap_offset, ResourceDesc* desc, ResourceStates initial_state, ClearValue* optimized_clear_value, Guid* riid, void** resource);
alias ProcDeviceCreateReservedResource = fn HResult(void* self, ResourceDesc* desc, ResourceStates initial_state, ClearValue* optimized_clear_value, Guid* riid, void** resource);
alias ProcDeviceMakeResident = fn HResult(void* self, uint num_objects, void** objects);
alias ProcDeviceEvict = fn HResult(void* self, uint num_objects, void** objects);
alias ProcDeviceCreateFence = fn HResult(void* self, ulong initial_value, FenceFlags flags, Guid* riid, void** fence);
alias ProcDeviceGetDeviceRemovedReason = fn HResult(void* self);
alias ProcDeviceGetCopyableFootprints = fn void(void* self, ResourceDesc* resource_desc, uint first_subresource, uint num_subresources, ulong base_offset, PlacedSubresourceFootprint* layouts, uint* num_rows, ulong* row_size_in_bytes, ulong* total_bytes);
alias ProcDeviceCreateQueryHeap = fn HResult(void* self, QueryHeapDesc* desc, Guid* riid, void** heap);
alias ProcDeviceSetStablePowerState = fn HResult(void* self, Bool32 enable);
alias ProcDeviceCreateCommandSignature = fn HResult(void* self, CommandSignatureDesc* desc, RootSignature* root_signature, Guid* riid, void** command_signature);
alias ProcDeviceGetAdapterLuid = fn Luid*(void* self, Luid* ret);
alias ProcDeviceCreateStateObject = fn HResult(void* self, StateObjectDesc* desc, Guid* riid, void** state_object);
alias ProcDeviceGetRaytracingAccelerationStructurePrebuildInfo = fn void(void* self, BuildRaytracingAccelerationStructureInputs* desc, RaytracingAccelerationStructurePrebuildInfo* info);

// ID3D12Device .. ID3D12Device5.
struct DeviceVtbl
{
	inline ObjectVtbl base;
	// ID3D12Device
	ProcDeviceGetNodeCount get_node_count;
	ProcDeviceCreateCommandQueue create_command_queue;
	ProcDeviceCreateCommandAllocator create_command_allocator;
	ProcDeviceCreateGraphicsPipelineState create_graphics_pipeline_state;
	ProcDeviceCreateComputePipelineState create_compute_pipeline_state;
	ProcDeviceCreateCommandList create_command_list;
	ProcDeviceCheckFeatureSupport check_feature_support;
	ProcDeviceCreateDescriptorHeap create_descriptor_heap;
	ProcDeviceGetDescriptorHandleIncrementSize get_descriptor_handle_increment_size;
	ProcDeviceCreateRootSignature create_root_signature;
	ProcDeviceCreateConstantBufferView create_constant_buffer_view;
	ProcDeviceCreateShaderResourceView create_shader_resource_view;
	ProcDeviceCreateUnorderedAccessView create_unordered_access_view;
	ProcDeviceCreateRenderTargetView create_render_target_view;
	ProcDeviceCreateDepthStencilView create_depth_stencil_view;
	ProcDeviceCreateSampler create_sampler;
	ProcDeviceCopyDescriptors copy_descriptors;
	ProcDeviceCopyDescriptorsSimple copy_descriptors_simple;
	ProcDeviceGetResourceAllocationInfo get_resource_allocation_info;
	ProcDeviceGetCustomHeapProperties get_custom_heap_properties;
	ProcDeviceCreateCommittedResource create_committed_resource;
	ProcDeviceCreateHeap create_heap;
	ProcDeviceCreatePlacedResource create_placed_resource;
	ProcDeviceCreateReservedResource create_reserved_resource;
	void* create_shared_handle;
	void* open_shared_handle;
	void* open_shared_handle_by_name;
	ProcDeviceMakeResident make_resident;
	ProcDeviceEvict evict;
	ProcDeviceCreateFence create_fence;
	ProcDeviceGetDeviceRemovedReason get_device_removed_reason;
	ProcDeviceGetCopyableFootprints get_copyable_footprints;
	ProcDeviceCreateQueryHeap create_query_heap;
	ProcDeviceSetStablePowerState set_stable_power_state;
	ProcDeviceCreateCommandSignature create_command_signature;
	void* get_resource_tiling;
	ProcDeviceGetAdapterLuid get_adapter_luid;
	// ID3D12Device1
	void* create_pipeline_library;
	void* set_event_on_multiple_fence_completion;
	void* set_residency_priority;
	// ID3D12Device2
	void* create_pipeline_state;
	// ID3D12Device3
	void* open_existing_heap_from_address;
	void* open_existing_heap_from_file_mapping;
	void* enqueue_make_resident;
	// ID3D12Device4
	void* create_command_list1;
	void* create_protected_resource_session;
	void* create_committed_resource1;
	void* create_heap1;
	void* create_reserved_resource1;
	void* get_resource_allocation_info1;
	// ID3D12Device5
	void* create_lifetime_tracker;
	void* remove_device;
	void* enumerate_meta_commands;
	void* enumerate_meta_command_parameters;
	void* create_meta_command;
	ProcDeviceCreateStateObject create_state_object;
	ProcDeviceGetRaytracingAccelerationStructurePrebuildInfo get_raytracing_acceleration_structure_prebuild_info;
	void* check_driver_matching_identifier;
}

struct Device
{
	DeviceVtbl* vtbl;
}

alias Device5 = Device;

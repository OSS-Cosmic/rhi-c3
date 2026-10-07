// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// C3 bindings for the COM/DXGI slice of the Windows graphics stack that the
// D3D12 backend needs: GUIDs, HRESULT, IUnknown, DXGI_FORMAT, and the
// IDXGIFactory6 / IDXGIAdapter3 / IDXGISwapChain3 interface family.
//
// Hand-written (no generator): the surface is small and stable. See
// d3d12.c3 for the D3D12 half and procedures.c3 for the DLL entry points.
//
// COM conventions used throughout both modules:
//   * An interface is `struct X { XVtbl* vtbl; }`; a COM pointer is `X*`.
//   * A vtable lists every slot in the exact order of the Windows headers,
//     base interfaces first (`inline` embeds the base vtable). Slots this
//     project does not call are typed `void*` so the order is preserved
//     without having to model every signature.
//   * Every slot takes the receiver as `void* self`, so a derived pointer can
//     call inherited slots without a cast: `dev.vtbl.create_fence(dev, ...)`.
//   * Methods that return a struct by value in C++ take a hidden return
//     pointer on Windows x64; those are modelled with an explicit `out`
//     parameter that is also returned (`GetDesc`, `GetCPUDescriptorHandle...`).
//   * Type layouts are plain data and compile on every target so that the
//     host test suite can pin struct sizes; only the DLL imports
//     (procedures.c3) are gated to Windows.
module dxgi;

alias HResult = int;
alias Bool32 = int;
alias Handle = void*;
alias Hwnd = void*;

const HResult S_OK = 0;
const HResult S_FALSE = 1;
const HResult E_FAIL = (HResult)0x80004005U;
const HResult E_NOINTERFACE = (HResult)0x80004002U;
const HResult E_INVALIDARG = (HResult)0x80070057U;
const HResult E_OUTOFMEMORY = (HResult)0x8007000EU;
const HResult DXGI_ERROR_NOT_FOUND = (HResult)0x887A0002U;
const HResult DXGI_ERROR_DEVICE_REMOVED = (HResult)0x887A0005U;
const HResult DXGI_ERROR_DEVICE_HUNG = (HResult)0x887A0006U;
const HResult DXGI_ERROR_DEVICE_RESET = (HResult)0x887A0007U;
const HResult DXGI_ERROR_WAS_STILL_DRAWING = (HResult)0x887A000AU;

fn bool failed(HResult hr) => hr < 0;
fn bool succeeded(HResult hr) => hr >= 0;

// GUID / IID (16 bytes, 4-aligned).
struct Guid
{
	uint data1;
	ushort data2;
	ushort data3;
	char[8] data4;
}

// LUID.
struct Luid
{
	uint low_part;
	int high_part;
}

// -- IUnknown ----------------------------------------------------------------

alias ProcUnknownQueryInterface = fn HResult(void* self, Guid* riid, void** object);
alias ProcUnknownAddRef = fn uint(void* self);
alias ProcUnknownRelease = fn uint(void* self);

struct UnknownVtbl
{
	ProcUnknownQueryInterface query_interface;
	ProcUnknownAddRef add_ref;
	ProcUnknownRelease release;
}

struct Unknown
{
	UnknownVtbl* vtbl;
}

// IUnknown helpers usable on any COM pointer.
macro uint add_ref(com) => ((Unknown*)com).vtbl.add_ref(com);
macro uint release(com) => ((Unknown*)com).vtbl.release(com);
macro HResult query_interface(com, Guid* riid, void** object) => ((Unknown*)com).vtbl.query_interface(com, riid, object);

const Guid IID_IUNKNOWN = { 0x00000000, 0x0000, 0x0000, { 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46 } };

alias ProcBlobGetBufferPointer = fn void*(void* self);
alias ProcBlobGetBufferSize = fn usz(void* self);

// ID3DBlob / ID3D10Blob (d3dcommon.h).
struct BlobVtbl
{
	inline UnknownVtbl base;
	ProcBlobGetBufferPointer get_buffer_pointer;
	ProcBlobGetBufferSize get_buffer_size;
}

struct Blob
{
	BlobVtbl* vtbl;
}

const Guid IID_BLOB = { 0x8ba5fb08, 0x5195, 0x40e2, { 0xac, 0x58, 0x0d, 0x98, 0x9c, 0x3a, 0x01, 0x02 } };

// -- DXGI_FORMAT ---------------------------------------------------------------

constdef Format : uint
{
	UNKNOWN                    = 0,
	R32G32B32A32_TYPELESS      = 1,
	R32G32B32A32_FLOAT         = 2,
	R32G32B32A32_UINT          = 3,
	R32G32B32A32_SINT          = 4,
	R32G32B32_TYPELESS         = 5,
	R32G32B32_FLOAT            = 6,
	R32G32B32_UINT             = 7,
	R32G32B32_SINT             = 8,
	R16G16B16A16_TYPELESS      = 9,
	R16G16B16A16_FLOAT         = 10,
	R16G16B16A16_UNORM         = 11,
	R16G16B16A16_UINT          = 12,
	R16G16B16A16_SNORM         = 13,
	R16G16B16A16_SINT          = 14,
	R32G32_TYPELESS            = 15,
	R32G32_FLOAT               = 16,
	R32G32_UINT                = 17,
	R32G32_SINT                = 18,
	R32G8X24_TYPELESS          = 19,
	D32_FLOAT_S8X24_UINT       = 20,
	R32_FLOAT_X8X24_TYPELESS   = 21,
	X32_TYPELESS_G8X24_UINT    = 22,
	R10G10B10A2_TYPELESS       = 23,
	R10G10B10A2_UNORM          = 24,
	R10G10B10A2_UINT           = 25,
	R11G11B10_FLOAT            = 26,
	R8G8B8A8_TYPELESS          = 27,
	R8G8B8A8_UNORM             = 28,
	R8G8B8A8_UNORM_SRGB        = 29,
	R8G8B8A8_UINT              = 30,
	R8G8B8A8_SNORM             = 31,
	R8G8B8A8_SINT              = 32,
	R16G16_TYPELESS            = 33,
	R16G16_FLOAT               = 34,
	R16G16_UNORM               = 35,
	R16G16_UINT                = 36,
	R16G16_SNORM               = 37,
	R16G16_SINT                = 38,
	R32_TYPELESS               = 39,
	D32_FLOAT                  = 40,
	R32_FLOAT                  = 41,
	R32_UINT                   = 42,
	R32_SINT                   = 43,
	R24G8_TYPELESS             = 44,
	D24_UNORM_S8_UINT          = 45,
	R24_UNORM_X8_TYPELESS      = 46,
	X24_TYPELESS_G8_UINT       = 47,
	R8G8_TYPELESS              = 48,
	R8G8_UNORM                 = 49,
	R8G8_UINT                  = 50,
	R8G8_SNORM                 = 51,
	R8G8_SINT                  = 52,
	R16_TYPELESS               = 53,
	R16_FLOAT                  = 54,
	D16_UNORM                  = 55,
	R16_UNORM                  = 56,
	R16_UINT                   = 57,
	R16_SNORM                  = 58,
	R16_SINT                   = 59,
	R8_TYPELESS                = 60,
	R8_UNORM                   = 61,
	R8_UINT                    = 62,
	R8_SNORM                   = 63,
	R8_SINT                    = 64,
	A8_UNORM                   = 65,
	R1_UNORM                   = 66,
	R9G9B9E5_SHAREDEXP         = 67,
	R8G8_B8G8_UNORM            = 68,
	G8R8_G8B8_UNORM            = 69,
	BC1_TYPELESS               = 70,
	BC1_UNORM                  = 71,
	BC1_UNORM_SRGB             = 72,
	BC2_TYPELESS               = 73,
	BC2_UNORM                  = 74,
	BC2_UNORM_SRGB             = 75,
	BC3_TYPELESS               = 76,
	BC3_UNORM                  = 77,
	BC3_UNORM_SRGB             = 78,
	BC4_TYPELESS               = 79,
	BC4_UNORM                  = 80,
	BC4_SNORM                  = 81,
	BC5_TYPELESS               = 82,
	BC5_UNORM                  = 83,
	BC5_SNORM                  = 84,
	B5G6R5_UNORM               = 85,
	B5G5R5A1_UNORM             = 86,
	B8G8R8A8_UNORM             = 87,
	B8G8R8X8_UNORM             = 88,
	R10G10B10_XR_BIAS_A2_UNORM = 89,
	B8G8R8A8_TYPELESS          = 90,
	B8G8R8A8_UNORM_SRGB        = 91,
	B8G8R8X8_TYPELESS          = 92,
	B8G8R8X8_UNORM_SRGB        = 93,
	BC6H_TYPELESS              = 94,
	BC6H_UF16                  = 95,
	BC6H_SF16                  = 96,
	BC7_TYPELESS               = 97,
	BC7_UNORM                  = 98,
	BC7_UNORM_SRGB             = 99,
}

struct SampleDesc
{
	uint count;
	uint quality;
}

// -- Enums and flags ---------------------------------------------------------

constdef SwapEffect : uint
{
	DISCARD         = 0,
	SEQUENTIAL      = 1,
	FLIP_SEQUENTIAL = 3,
	FLIP_DISCARD    = 4,
}

constdef Scaling : uint
{
	STRETCH              = 0,
	NONE                 = 1,
	ASPECT_RATIO_STRETCH = 2,
}

constdef AlphaMode : uint
{
	UNSPECIFIED   = 0,
	PREMULTIPLIED = 1,
	STRAIGHT      = 2,
	IGNORE        = 3,
}

constdef GpuPreference : uint
{
	UNSPECIFIED      = 0,
	MINIMUM_POWER    = 1,
	HIGH_PERFORMANCE = 2,
}

constdef MemorySegmentGroup : uint
{
	LOCAL     = 0,
	NON_LOCAL = 1,
}

// DXGI_FEATURE.
constdef Feature : uint
{
	PRESENT_ALLOW_TEARING = 0,
}

// DXGI_USAGE.
typedef Usage @constinit = uint;
const Usage USAGE_SHADER_INPUT         = 0x00000010;
const Usage USAGE_RENDER_TARGET_OUTPUT = 0x00000020;
const Usage USAGE_BACK_BUFFER          = 0x00000040;

// DXGI_SWAP_CHAIN_FLAG.
typedef SwapChainFlags @constinit = uint;
const SwapChainFlags SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH            = 0x00000002;
const SwapChainFlags SWAP_CHAIN_FLAG_FRAME_LATENCY_WAITABLE_OBJECT = 0x00000040;
const SwapChainFlags SWAP_CHAIN_FLAG_ALLOW_TEARING                 = 0x00000800;

// DXGI_PRESENT.
typedef PresentFlags @constinit = uint;
const PresentFlags PRESENT_TEST                = 0x00000001;
const PresentFlags PRESENT_DO_NOT_WAIT         = 0x00000008;
const PresentFlags PRESENT_ALLOW_TEARING       = 0x00000200;

// DXGI_ADAPTER_FLAG.
typedef AdapterFlags @constinit = uint;
const AdapterFlags ADAPTER_FLAG_REMOTE   = 0x1;
const AdapterFlags ADAPTER_FLAG_SOFTWARE = 0x2;

// CreateDXGIFactory2 flags and MakeWindowAssociation flags.
const uint CREATE_FACTORY_DEBUG = 0x1;
const uint MWA_NO_WINDOW_CHANGES = 1U << 0;
const uint MWA_NO_ALT_ENTER = 1U << 1;
const uint MWA_NO_PRINT_SCREEN = 1U << 2;

// -- Structs -----------------------------------------------------------------

// DXGI_SWAP_CHAIN_DESC1.
struct SwapChainDesc1
{
	uint width;
	uint height;
	Format format;
	Bool32 stereo;
	SampleDesc sample_desc;
	Usage buffer_usage;
	uint buffer_count;
	Scaling scaling;
	SwapEffect swap_effect;
	AlphaMode alpha_mode;
	SwapChainFlags flags;
}

// DXGI_ADAPTER_DESC1. `description` is UTF-16.
struct AdapterDesc1
{
	ushort[128] description;
	uint vendor_id;
	uint device_id;
	uint sub_sys_id;
	uint revision;
	usz dedicated_video_memory;
	usz dedicated_system_memory;
	usz shared_system_memory;
	Luid adapter_luid;
	AdapterFlags flags;
}

// DXGI_QUERY_VIDEO_MEMORY_INFO.
struct QueryVideoMemoryInfo
{
	ulong budget;
	ulong current_usage;
	ulong available_for_reservation;
	ulong current_reservation;
}

// -- Interfaces ----------------------------------------------------------------

const Guid IID_DXGI_OBJECT     = { 0xaec22fb8, 0x76f3, 0x4639, { 0x9b, 0xe0, 0x28, 0xeb, 0x43, 0xa6, 0x7a, 0x2e } };
const Guid IID_DXGI_FACTORY    = { 0x7b7166ec, 0x21c7, 0x44ae, { 0xb2, 0x1a, 0xc9, 0xae, 0x32, 0x1a, 0xe3, 0x69 } };
const Guid IID_DXGI_FACTORY1   = { 0x770aae78, 0xf26f, 0x4dba, { 0xa8, 0x29, 0x25, 0x3c, 0x83, 0xd1, 0xb3, 0x87 } };
const Guid IID_DXGI_FACTORY2   = { 0x50c83a1c, 0xe072, 0x4c48, { 0x87, 0xb0, 0x36, 0x30, 0xfa, 0x36, 0xa6, 0xd0 } };
const Guid IID_DXGI_FACTORY3   = { 0x25483823, 0xcd46, 0x4c7d, { 0x86, 0xca, 0x47, 0xaa, 0x95, 0xb8, 0x37, 0xbd } };
const Guid IID_DXGI_FACTORY4   = { 0x1bc6ea02, 0xef36, 0x464f, { 0xbf, 0x0c, 0x21, 0xca, 0x39, 0xe5, 0x16, 0x8a } };
const Guid IID_DXGI_FACTORY5   = { 0x7632e1f5, 0xee65, 0x4dca, { 0x87, 0xfd, 0x84, 0xcd, 0x75, 0xf8, 0x83, 0x8d } };
const Guid IID_DXGI_FACTORY6   = { 0xc1b6694f, 0xff09, 0x44a9, { 0xb0, 0x3c, 0x77, 0x90, 0x0a, 0x0a, 0x1d, 0x17 } };
const Guid IID_DXGI_ADAPTER    = { 0x2411e7e1, 0x12ac, 0x4ccf, { 0xbd, 0x14, 0x97, 0x98, 0xe8, 0x53, 0x4d, 0xc0 } };
const Guid IID_DXGI_ADAPTER1   = { 0x29038f61, 0x3839, 0x4626, { 0x91, 0xfd, 0x08, 0x68, 0x79, 0x01, 0x1a, 0x05 } };
const Guid IID_DXGI_ADAPTER3   = { 0x645967a4, 0x1392, 0x4310, { 0xa7, 0x98, 0x80, 0x53, 0xce, 0x3e, 0x93, 0xfd } };
const Guid IID_DXGI_SWAP_CHAIN  = { 0x310d36a0, 0xd2e7, 0x4c0a, { 0xaa, 0x04, 0x6a, 0x9d, 0x23, 0xb8, 0x88, 0x6a } };
const Guid IID_DXGI_SWAP_CHAIN1 = { 0x790a45f7, 0x0d42, 0x4876, { 0x98, 0x3a, 0x0a, 0x55, 0xcf, 0xe6, 0xf4, 0xaa } };
const Guid IID_DXGI_SWAP_CHAIN3 = { 0x94d99bdb, 0xf1f8, 0x4ab0, { 0xb2, 0x36, 0x7d, 0xa0, 0x17, 0x0e, 0xda, 0xb1 } };

alias ProcObjectGetParent = fn HResult(void* self, Guid* riid, void** parent);

// IDXGIObject.
struct ObjectVtbl
{
	inline UnknownVtbl base;
	void* set_private_data;
	void* set_private_data_interface;
	void* get_private_data;
	ProcObjectGetParent get_parent;
}

alias ProcFactoryEnumAdapters = fn HResult(void* self, uint index, Adapter** adapter);
alias ProcFactoryMakeWindowAssociation = fn HResult(void* self, Hwnd window, uint flags);
alias ProcFactoryEnumAdapters1 = fn HResult(void* self, uint index, Adapter1** adapter);
alias ProcFactoryIsCurrent = fn Bool32(void* self);
alias ProcFactoryCreateSwapChainForHwnd = fn HResult(void* self, void* device, Hwnd window, SwapChainDesc1* desc, void* fullscreen_desc, void* restrict_to_output, SwapChain1** swap_chain);
alias ProcFactoryGetCreationFlags = fn uint(void* self);
alias ProcFactoryEnumAdapterByLuid = fn HResult(void* self, Luid luid, Guid* riid, void** adapter);
alias ProcFactoryEnumWarpAdapter = fn HResult(void* self, Guid* riid, void** adapter);
alias ProcFactoryCheckFeatureSupport = fn HResult(void* self, Feature feature, void* feature_support_data, uint size);
alias ProcFactoryEnumAdapterByGpuPreference = fn HResult(void* self, uint index, GpuPreference preference, Guid* riid, void** adapter);

// IDXGIFactory .. IDXGIFactory6. Slots for interfaces this project does not
// use are `void*` placeholders (see the file header).
struct FactoryVtbl
{
	inline ObjectVtbl base;
	// IDXGIFactory
	ProcFactoryEnumAdapters enum_adapters;
	ProcFactoryMakeWindowAssociation make_window_association;
	void* get_window_association;
	void* create_swap_chain;
	void* create_software_adapter;
	// IDXGIFactory1
	ProcFactoryEnumAdapters1 enum_adapters1;
	ProcFactoryIsCurrent is_current;
	// IDXGIFactory2
	void* is_windowed_stereo_enabled;
	ProcFactoryCreateSwapChainForHwnd create_swap_chain_for_hwnd;
	void* create_swap_chain_for_core_window;
	void* get_shared_resource_adapter_luid;
	void* register_stereo_status_window;
	void* register_stereo_status_event;
	void* unregister_stereo_status;
	void* register_occlusion_status_window;
	void* register_occlusion_status_event;
	void* unregister_occlusion_status;
	void* create_swap_chain_for_composition;
	// IDXGIFactory3
	ProcFactoryGetCreationFlags get_creation_flags;
	// IDXGIFactory4
	ProcFactoryEnumAdapterByLuid enum_adapter_by_luid;
	ProcFactoryEnumWarpAdapter enum_warp_adapter;
	// IDXGIFactory5
	ProcFactoryCheckFeatureSupport check_feature_support;
	// IDXGIFactory6
	ProcFactoryEnumAdapterByGpuPreference enum_adapter_by_gpu_preference;
}

struct Factory
{
	FactoryVtbl* vtbl;
}

// Every factory revision shares the FactoryVtbl layout; the typed aliases
// document which interface a pointer was queried as.
alias Factory1 = Factory;
alias Factory2 = Factory;
alias Factory3 = Factory;
alias Factory4 = Factory;
alias Factory5 = Factory;
alias Factory6 = Factory;

alias ProcAdapterGetDesc1 = fn HResult(void* self, AdapterDesc1* desc);
alias ProcAdapterQueryVideoMemoryInfo = fn HResult(void* self, uint node_index, MemorySegmentGroup segment_group, QueryVideoMemoryInfo* info);

// IDXGIAdapter .. IDXGIAdapter3.
struct AdapterVtbl
{
	inline ObjectVtbl base;
	// IDXGIAdapter
	void* enum_outputs;
	void* get_desc;
	void* check_interface_support;
	// IDXGIAdapter1
	ProcAdapterGetDesc1 get_desc1;
	// IDXGIAdapter2
	void* get_desc2;
	// IDXGIAdapter3
	void* register_hardware_content_protection_teardown_status_event;
	void* unregister_hardware_content_protection_teardown_status;
	ProcAdapterQueryVideoMemoryInfo query_video_memory_info;
	void* set_video_memory_reservation;
	void* register_video_memory_budget_change_notification_event;
	void* unregister_video_memory_budget_change_notification;
}

struct Adapter
{
	AdapterVtbl* vtbl;
}

alias Adapter1 = Adapter;
alias Adapter3 = Adapter;

alias ProcSwapChainGetDevice = fn HResult(void* self, Guid* riid, void** device);
alias ProcSwapChainPresent = fn HResult(void* self, uint sync_interval, PresentFlags flags);
alias ProcSwapChainGetBuffer = fn HResult(void* self, uint buffer, Guid* riid, void** surface);
alias ProcSwapChainResizeBuffers = fn HResult(void* self, uint buffer_count, uint width, uint height, Format format, SwapChainFlags flags);
alias ProcSwapChainPresent1 = fn HResult(void* self, uint sync_interval, PresentFlags flags, void* present_parameters);
alias ProcSwapChainSetMaximumFrameLatency = fn HResult(void* self, uint max_latency);
alias ProcSwapChainGetFrameLatencyWaitableObject = fn Handle(void* self);
alias ProcSwapChainGetCurrentBackBufferIndex = fn uint(void* self);

// IDXGISwapChain .. IDXGISwapChain3.
struct SwapChainVtbl
{
	inline ObjectVtbl base;
	// IDXGIDeviceSubObject
	ProcSwapChainGetDevice get_device;
	// IDXGISwapChain
	ProcSwapChainPresent present;
	ProcSwapChainGetBuffer get_buffer;
	void* set_fullscreen_state;
	void* get_fullscreen_state;
	void* get_desc;
	ProcSwapChainResizeBuffers resize_buffers;
	void* resize_target;
	void* get_containing_output;
	void* get_frame_statistics;
	void* get_last_present_count;
	// IDXGISwapChain1
	void* get_desc1;
	void* get_fullscreen_desc;
	void* get_hwnd;
	void* get_core_window;
	ProcSwapChainPresent1 present1;
	void* is_temporary_mono_supported;
	void* get_restrict_to_output;
	void* set_background_color;
	void* get_background_color;
	void* set_rotation;
	void* get_rotation;
	// IDXGISwapChain2
	void* set_source_size;
	void* get_source_size;
	ProcSwapChainSetMaximumFrameLatency set_maximum_frame_latency;
	void* get_maximum_frame_latency;
	ProcSwapChainGetFrameLatencyWaitableObject get_frame_latency_waitable_object;
	void* set_matrix_transform;
	void* get_matrix_transform;
	// IDXGISwapChain3
	ProcSwapChainGetCurrentBackBufferIndex get_current_back_buffer_index;
	void* check_color_space_support;
	void* set_color_space1;
	void* resize_buffers1;
}

struct SwapChain
{
	SwapChainVtbl* vtbl;
}

alias SwapChain1 = SwapChain;
alias SwapChain3 = SwapChain;

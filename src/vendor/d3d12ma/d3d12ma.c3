// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// C3 bindings for D3D12MemoryAllocator through the C shim in
// vendor/d3d12ma/d3d12ma_c.{h,cpp} (Windows x64 only; the shim is built by
// `meson compile -C build-meson d3d12ma` with a mingw cross compiler and is not part of
// project.json's linked-libraries, so Linux/macOS host links never need it).
//
// D3D12/DXGI objects are opaque `void*` here so this module does not depend on
// the src/vendor/d3d12 bindings: pass ID3D12Device*, IDXGIAdapter*,
// const D3D12_RESOURCE_DESC* and const D3D12_CLEAR_VALUE* as void*. HRESULTs
// are `int` (negative = failure). Struct layouts mirror d3d12ma_c.h.
module d3d12ma;

typedef Allocator @constinit = inline void*;
typedef Allocation @constinit = inline void*;

typedef AllocatorFlags @constinit = uint;
const AllocatorFlags ALLOCATOR_FLAG_NONE                                = 0x0;
const AllocatorFlags ALLOCATOR_FLAG_SINGLETHREADED                      = 0x1;
const AllocatorFlags ALLOCATOR_FLAG_ALWAYS_COMMITTED                    = 0x2;
const AllocatorFlags ALLOCATOR_FLAG_DEFAULT_POOLS_NOT_ZEROED            = 0x4;
const AllocatorFlags ALLOCATOR_FLAG_MSAA_TEXTURES_ALWAYS_COMMITTED      = 0x8;
const AllocatorFlags ALLOCATOR_FLAG_DONT_PREFER_SMALL_BUFFERS_COMMITTED = 0x10;
const AllocatorFlags ALLOCATOR_FLAG_DONT_USE_TIGHT_ALIGNMENT            = 0x20;

typedef AllocationFlags @constinit = uint;
const AllocationFlags ALLOCATION_FLAG_NONE                = 0x0;
const AllocationFlags ALLOCATION_FLAG_COMMITTED           = 0x1;
const AllocationFlags ALLOCATION_FLAG_NEVER_ALLOCATE      = 0x2;
const AllocationFlags ALLOCATION_FLAG_WITHIN_BUDGET       = 0x4;
const AllocationFlags ALLOCATION_FLAG_UPPER_ADDRESS       = 0x8;
const AllocationFlags ALLOCATION_FLAG_CAN_ALIAS           = 0x10;
const AllocationFlags ALLOCATION_FLAG_STRATEGY_MIN_MEMORY = 0x00010000;
const AllocationFlags ALLOCATION_FLAG_STRATEGY_MIN_TIME   = 0x00020000;
const AllocationFlags ALLOCATION_FLAG_STRATEGY_MIN_OFFSET = 0x00040000;

// Segment groups for get_memory_capacity (DXGI_MEMORY_SEGMENT_GROUP_*).
const uint SEGMENT_GROUP_LOCAL     = 0;
const uint SEGMENT_GROUP_NON_LOCAL = 1;

struct AllocatorDesc
{
	AllocatorFlags flags;
	uint           _pad;
	ulong          preferred_block_size; // 0 = default (64 MiB)
	void*          device;               // ID3D12Device*
	void*          adapter;              // IDXGIAdapter*
}

struct AllocationDesc
{
	AllocationFlags flags;
	int             heap_type;        // D3D12_HEAP_TYPE
	uint            extra_heap_flags; // D3D12_HEAP_FLAGS
	uint            _pad;
	void*           private_data;
}

struct Statistics
{
	uint  block_count;
	uint  allocation_count;
	ulong block_bytes;
	ulong allocation_bytes;
}

struct Budget
{
	Statistics stats;
	ulong      usage_bytes;
	ulong      budget_bytes;
}

extern fn int create_allocator(AllocatorDesc* desc, Allocator* out_allocator) @cname("d3d12mac_create_allocator");
extern fn void destroy_allocator(Allocator allocator) @cname("d3d12mac_destroy_allocator");

// resource_desc: const D3D12_RESOURCE_DESC*; clear_value: optional const
// D3D12_CLEAR_VALUE*; initial_state: D3D12_RESOURCE_STATES. out_resource
// (optional) receives an ID3D12Resource* reference the caller must Release.
extern fn int create_resource(Allocator allocator, AllocationDesc* alloc_desc, void* resource_desc, uint initial_state, void* clear_value, Allocation* out_allocation, void** out_resource) @cname("d3d12mac_create_resource");
// Raw memory without a resource (size a multiple of 64 KiB), for aliasing.
extern fn int allocate_memory(Allocator allocator, AllocationDesc* alloc_desc, ulong size, ulong alignment, Allocation* out_allocation) @cname("d3d12mac_allocate_memory");
// Places another resource inside `allocation`; caller Releases out_resource.
extern fn int create_aliasing_resource(Allocator allocator, Allocation allocation, ulong allocation_local_offset, void* resource_desc, uint initial_state, void* clear_value, void** out_resource) @cname("d3d12mac_create_aliasing_resource");
// Releases the allocation and the resource it owns.
extern fn void free_allocation(Allocation allocation) @cname("d3d12mac_free_allocation");

extern fn void* allocation_get_resource(Allocation allocation) @cname("d3d12mac_allocation_get_resource");
extern fn void* allocation_get_heap(Allocation allocation) @cname("d3d12mac_allocation_get_heap");
extern fn ulong allocation_get_offset(Allocation allocation) @cname("d3d12mac_allocation_get_offset");
extern fn ulong allocation_get_size(Allocation allocation) @cname("d3d12mac_allocation_get_size");
extern fn void* allocation_get_private_data(Allocation allocation) @cname("d3d12mac_allocation_get_private_data");

extern fn int map(Allocation allocation, ulong read_begin, ulong read_end, void** out_data) @cname("d3d12mac_map");
extern fn void unmap(Allocation allocation, ulong written_begin, ulong written_end) @cname("d3d12mac_unmap");

extern fn void get_budget(Allocator allocator, Budget* out_local, Budget* out_non_local) @cname("d3d12mac_get_budget");
extern fn void calculate_total_statistics(Allocator allocator, Statistics* out_total) @cname("d3d12mac_calculate_total_statistics");
extern fn int is_uma(Allocator allocator) @cname("d3d12mac_is_uma");
extern fn ulong get_memory_capacity(Allocator allocator, uint segment_group) @cname("d3d12mac_get_memory_capacity");

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
//
// Plain C interface over D3D12MemoryAllocator (C++), for the C3 bindings in
// src/vendor/d3d12ma/d3d12ma.c3. All D3D12/DXGI objects cross the boundary as
// void*, D3D12 enums/flags as 32-bit integers and D3D12_RESOURCE_DESC /
// D3D12_CLEAR_VALUE as pointers to the native structs. HRESULTs are returned
// as int32_t (negative = failure).
#ifndef D3D12MA_C_H
#define D3D12MA_C_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct D3D12MAC_Allocator_T* D3D12MAC_Allocator;
typedef struct D3D12MAC_Allocation_T* D3D12MAC_Allocation;

// ALLOCATOR_FLAGS (D3D12MA::ALLOCATOR_FLAG_*).
#define D3D12MAC_ALLOCATOR_FLAG_NONE                             0x0u
#define D3D12MAC_ALLOCATOR_FLAG_SINGLETHREADED                   0x1u
#define D3D12MAC_ALLOCATOR_FLAG_ALWAYS_COMMITTED                 0x2u
#define D3D12MAC_ALLOCATOR_FLAG_DEFAULT_POOLS_NOT_ZEROED         0x4u
#define D3D12MAC_ALLOCATOR_FLAG_MSAA_TEXTURES_ALWAYS_COMMITTED   0x8u
#define D3D12MAC_ALLOCATOR_FLAG_DONT_PREFER_SMALL_BUFFERS_COMMITTED 0x10u
#define D3D12MAC_ALLOCATOR_FLAG_DONT_USE_TIGHT_ALIGNMENT         0x20u

// ALLOCATION_FLAGS (D3D12MA::ALLOCATION_FLAG_*).
#define D3D12MAC_ALLOCATION_FLAG_NONE                0x0u
#define D3D12MAC_ALLOCATION_FLAG_COMMITTED           0x1u
#define D3D12MAC_ALLOCATION_FLAG_NEVER_ALLOCATE      0x2u
#define D3D12MAC_ALLOCATION_FLAG_WITHIN_BUDGET       0x4u
#define D3D12MAC_ALLOCATION_FLAG_UPPER_ADDRESS       0x8u
#define D3D12MAC_ALLOCATION_FLAG_CAN_ALIAS           0x10u
#define D3D12MAC_ALLOCATION_FLAG_STRATEGY_MIN_MEMORY 0x00010000u
#define D3D12MAC_ALLOCATION_FLAG_STRATEGY_MIN_TIME   0x00020000u
#define D3D12MAC_ALLOCATION_FLAG_STRATEGY_MIN_OFFSET 0x00040000u

typedef struct D3D12MAC_AllocatorDesc {
    uint32_t flags;               // D3D12MAC_ALLOCATOR_FLAG_*
    uint32_t _pad;
    uint64_t preferred_block_size; // 0 = default (64 MiB)
    void*    device;              // ID3D12Device*
    void*    adapter;             // IDXGIAdapter*
} D3D12MAC_AllocatorDesc;

typedef struct D3D12MAC_AllocationDesc {
    uint32_t flags;            // D3D12MAC_ALLOCATION_FLAG_*
    int32_t  heap_type;        // D3D12_HEAP_TYPE
    uint32_t extra_heap_flags; // D3D12_HEAP_FLAGS
    uint32_t _pad;
    void*    private_data;
} D3D12MAC_AllocationDesc;

typedef struct D3D12MAC_Statistics {
    uint32_t block_count;
    uint32_t allocation_count;
    uint64_t block_bytes;
    uint64_t allocation_bytes;
} D3D12MAC_Statistics;

typedef struct D3D12MAC_Budget {
    D3D12MAC_Statistics stats;
    uint64_t usage_bytes;
    uint64_t budget_bytes;
} D3D12MAC_Budget;

// Allocator lifetime. `device` and `adapter` are AddRef'd by the allocator.
int32_t d3d12mac_create_allocator(const D3D12MAC_AllocatorDesc* desc, D3D12MAC_Allocator* out_allocator);
void    d3d12mac_destroy_allocator(D3D12MAC_Allocator allocator);

// Allocates memory and creates a resource (CreateResource). `resource_desc` is
// a const D3D12_RESOURCE_DESC*, `clear_value` an optional const
// D3D12_CLEAR_VALUE*. `out_resource` (optional) receives an extra
// ID3D12Resource* reference the caller must Release; the allocation also holds
// its own reference, dropped by d3d12mac_free_allocation.
int32_t d3d12mac_create_resource(
    D3D12MAC_Allocator allocator,
    const D3D12MAC_AllocationDesc* alloc_desc,
    const void* resource_desc,
    uint32_t initial_state, // D3D12_RESOURCE_STATES
    const void* clear_value,
    D3D12MAC_Allocation* out_allocation,
    void** out_resource);

// Allocates raw memory without a resource (AllocateMemory); pair with
// d3d12mac_create_aliasing_resource. `size` must be a multiple of 64 KiB.
int32_t d3d12mac_allocate_memory(
    D3D12MAC_Allocator allocator,
    const D3D12MAC_AllocationDesc* alloc_desc,
    uint64_t size,
    uint64_t alignment,
    D3D12MAC_Allocation* out_allocation);

// Creates another resource placed inside `allocation` (CreateAliasingResource).
// The caller owns the returned ID3D12Resource* and must Release it; it is
// not bound to the allocation. Allocation must not be committed.
int32_t d3d12mac_create_aliasing_resource(
    D3D12MAC_Allocator allocator,
    D3D12MAC_Allocation allocation,
    uint64_t allocation_local_offset,
    const void* resource_desc,
    uint32_t initial_state,
    const void* clear_value,
    void** out_resource);

// Releases the allocation and the resource it owns.
void d3d12mac_free_allocation(D3D12MAC_Allocation allocation);

// Allocation queries. The returned resource is not AddRef'd.
void*    d3d12mac_allocation_get_resource(D3D12MAC_Allocation allocation);
void*    d3d12mac_allocation_get_heap(D3D12MAC_Allocation allocation); // ID3D12Heap*, null if committed
uint64_t d3d12mac_allocation_get_offset(D3D12MAC_Allocation allocation);
uint64_t d3d12mac_allocation_get_size(D3D12MAC_Allocation allocation);
void*    d3d12mac_allocation_get_private_data(D3D12MAC_Allocation allocation);

// ID3D12Resource::Map / Unmap on the allocation's resource, subresource 0.
// `read_begin`/`read_end` give the CPU read range; pass both 0 for write-only.
int32_t d3d12mac_map(D3D12MAC_Allocation allocation, uint64_t read_begin, uint64_t read_end, void** out_data);
void    d3d12mac_unmap(D3D12MAC_Allocation allocation, uint64_t written_begin, uint64_t written_end);

// Budget per segment group (local = VRAM / shared, non_local = system memory).
// Either output may be null.
void d3d12mac_get_budget(D3D12MAC_Allocator allocator, D3D12MAC_Budget* out_local, D3D12MAC_Budget* out_non_local);
// Totals across all heaps (slower than get_budget).
void d3d12mac_calculate_total_statistics(D3D12MAC_Allocator allocator, D3D12MAC_Statistics* out_total);
int32_t  d3d12mac_is_uma(D3D12MAC_Allocator allocator);
uint64_t d3d12mac_get_memory_capacity(D3D12MAC_Allocator allocator, uint32_t segment_group);

#ifdef __cplusplus
}
#endif

#endif // D3D12MA_C_H

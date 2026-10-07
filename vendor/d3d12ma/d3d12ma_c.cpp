// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only
#include "d3d12ma_c.h"
#include "D3D12MemAlloc.h"

static_assert(sizeof(D3D12MAC_Statistics) == sizeof(D3D12MA::Statistics), "statistics layout");
static_assert(sizeof(D3D12MAC_Budget) == sizeof(D3D12MA::Budget), "budget layout");

static D3D12MA::Allocator* A(D3D12MAC_Allocator a) { return reinterpret_cast<D3D12MA::Allocator*>(a); }
static D3D12MA::Allocation* L(D3D12MAC_Allocation a) { return reinterpret_cast<D3D12MA::Allocation*>(a); }
static D3D12MAC_Allocation W(D3D12MA::Allocation* a) { return reinterpret_cast<D3D12MAC_Allocation>(a); }

static D3D12MA::ALLOCATION_DESC to_native(const D3D12MAC_AllocationDesc* d)
{
    D3D12MA::ALLOCATION_DESC out = {};
    out.Flags = (D3D12MA::ALLOCATION_FLAGS)d->flags;
    out.HeapType = (D3D12_HEAP_TYPE)d->heap_type;
    out.ExtraHeapFlags = (D3D12_HEAP_FLAGS)d->extra_heap_flags;
    out.pPrivateData = d->private_data;
    return out;
}

static void copy_stats(D3D12MAC_Statistics* out, const D3D12MA::Statistics& s)
{
    out->block_count = s.BlockCount;
    out->allocation_count = s.AllocationCount;
    out->block_bytes = s.BlockBytes;
    out->allocation_bytes = s.AllocationBytes;
}

static void copy_budget(D3D12MAC_Budget* out, const D3D12MA::Budget& b)
{
    copy_stats(&out->stats, b.Stats);
    out->usage_bytes = b.UsageBytes;
    out->budget_bytes = b.BudgetBytes;
}

extern "C" {

int32_t d3d12mac_create_allocator(const D3D12MAC_AllocatorDesc* desc, D3D12MAC_Allocator* out_allocator)
{
    D3D12MA::ALLOCATOR_DESC d = {};
    d.Flags = (D3D12MA::ALLOCATOR_FLAGS)desc->flags;
    d.pDevice = static_cast<ID3D12Device*>(desc->device);
    d.PreferredBlockSize = desc->preferred_block_size;
    d.pAdapter = static_cast<IDXGIAdapter*>(desc->adapter);
    D3D12MA::Allocator* allocator = nullptr;
    HRESULT hr = D3D12MA::CreateAllocator(&d, &allocator);
    *out_allocator = reinterpret_cast<D3D12MAC_Allocator>(allocator);
    return (int32_t)hr;
}

void d3d12mac_destroy_allocator(D3D12MAC_Allocator allocator)
{
    if (allocator) A(allocator)->Release();
}

int32_t d3d12mac_create_resource(
    D3D12MAC_Allocator allocator, const D3D12MAC_AllocationDesc* alloc_desc, const void* resource_desc,
    uint32_t initial_state, const void* clear_value, D3D12MAC_Allocation* out_allocation, void** out_resource)
{
    D3D12MA::ALLOCATION_DESC d = to_native(alloc_desc);
    D3D12MA::Allocation* allocation = nullptr;
    HRESULT hr = A(allocator)->CreateResource(
        &d, static_cast<const D3D12_RESOURCE_DESC*>(resource_desc), (D3D12_RESOURCE_STATES)initial_state,
        static_cast<const D3D12_CLEAR_VALUE*>(clear_value), &allocation,
        __uuidof(ID3D12Resource), out_resource);
    *out_allocation = W(allocation);
    return (int32_t)hr;
}

int32_t d3d12mac_allocate_memory(
    D3D12MAC_Allocator allocator, const D3D12MAC_AllocationDesc* alloc_desc,
    uint64_t size, uint64_t alignment, D3D12MAC_Allocation* out_allocation)
{
    D3D12MA::ALLOCATION_DESC d = to_native(alloc_desc);
    D3D12_RESOURCE_ALLOCATION_INFO info = {};
    info.SizeInBytes = size;
    info.Alignment = alignment;
    D3D12MA::Allocation* allocation = nullptr;
    HRESULT hr = A(allocator)->AllocateMemory(&d, &info, &allocation);
    *out_allocation = W(allocation);
    return (int32_t)hr;
}

int32_t d3d12mac_create_aliasing_resource(
    D3D12MAC_Allocator allocator, D3D12MAC_Allocation allocation, uint64_t allocation_local_offset,
    const void* resource_desc, uint32_t initial_state, const void* clear_value, void** out_resource)
{
    return (int32_t)A(allocator)->CreateAliasingResource(
        L(allocation), allocation_local_offset, static_cast<const D3D12_RESOURCE_DESC*>(resource_desc),
        (D3D12_RESOURCE_STATES)initial_state, static_cast<const D3D12_CLEAR_VALUE*>(clear_value),
        __uuidof(ID3D12Resource), out_resource);
}

void d3d12mac_free_allocation(D3D12MAC_Allocation allocation)
{
    if (allocation) L(allocation)->Release();
}

void* d3d12mac_allocation_get_resource(D3D12MAC_Allocation allocation) { return L(allocation)->GetResource(); }
void* d3d12mac_allocation_get_heap(D3D12MAC_Allocation allocation) { return L(allocation)->GetHeap(); }
uint64_t d3d12mac_allocation_get_offset(D3D12MAC_Allocation allocation) { return L(allocation)->GetOffset(); }
uint64_t d3d12mac_allocation_get_size(D3D12MAC_Allocation allocation) { return L(allocation)->GetSize(); }
void* d3d12mac_allocation_get_private_data(D3D12MAC_Allocation allocation) { return L(allocation)->GetPrivateData(); }

int32_t d3d12mac_map(D3D12MAC_Allocation allocation, uint64_t read_begin, uint64_t read_end, void** out_data)
{
    D3D12_RANGE range = { (SIZE_T)read_begin, (SIZE_T)read_end };
    return (int32_t)L(allocation)->GetResource()->Map(0, &range, out_data);
}

void d3d12mac_unmap(D3D12MAC_Allocation allocation, uint64_t written_begin, uint64_t written_end)
{
    D3D12_RANGE range = { (SIZE_T)written_begin, (SIZE_T)written_end };
    L(allocation)->GetResource()->Unmap(0, &range);
}

void d3d12mac_get_budget(D3D12MAC_Allocator allocator, D3D12MAC_Budget* out_local, D3D12MAC_Budget* out_non_local)
{
    D3D12MA::Budget local = {}, non_local = {};
    A(allocator)->GetBudget(out_local ? &local : nullptr, out_non_local ? &non_local : nullptr);
    if (out_local) copy_budget(out_local, local);
    if (out_non_local) copy_budget(out_non_local, non_local);
}

void d3d12mac_calculate_total_statistics(D3D12MAC_Allocator allocator, D3D12MAC_Statistics* out_total)
{
    D3D12MA::TotalStatistics stats = {};
    A(allocator)->CalculateStatistics(&stats);
    copy_stats(out_total, stats.Total.Stats);
}

int32_t d3d12mac_is_uma(D3D12MAC_Allocator allocator) { return A(allocator)->IsUMA() ? 1 : 0; }

uint64_t d3d12mac_get_memory_capacity(D3D12MAC_Allocator allocator, uint32_t segment_group)
{
    return A(allocator)->GetMemoryCapacity(segment_group);
}

} // extern "C"

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU query pool. Port of HPL2's `RIQueryPool`
// (RIQuery.h / RIQuery.cpp).
//
// Backend asymmetry, all of it contained here:
//   Vulkan  reads the pool directly and needs every query RESET on a command
//           buffer before it is begun, so `cmd_reset_query_pool` records a
//           vkCmdResetQueryPool and `cmd_resolve_query_pool` is a no-op.
//   D3D12   has no reset but cannot be read until the data is RESOLVED into a
//           readback buffer, so reset is a no-op and resolve records the copy.
// Record both on every backend; each is a no-op where it is not needed.
// Metal and the web backends have no occlusion-query support yet.
module rhi;

enum QueryType : char
{
	// Exact number of samples that passed. Vulkan needs the
	// `occlusionQueryPrecise` device feature; init downgrades to
	// OCCLUSION_BINARY and republishes the granted type in `QueryPool.type`
	// when it is absent. D3D12 always supports it.
	OCCLUSION,
	// "Did any sample pass": 0, or a non-zero value with no defined magnitude.
	OCCLUSION_BINARY,
}

struct QueryPoolDesc
{
	QueryType type;
	uint query_count;
}

struct QueryPool
{
	uint query_count;
	// Queries covered by the most recent resolve. Vulkan keeps it at
	// `query_count` (the pool is always readable); D3D12 uses it to reject a
	// read of a range no resolve has filled.
	uint resolved_count;
	// The type actually granted (see `QueryType.OCCLUSION`).
	QueryType type;
	union backend
	{
		QueryPoolVk vk;
		QueryPoolDx12 dx12;
	}
}

// The type a backend grants for `requested`: precise counting is a device
// feature, so without it OCCLUSION downgrades to OCCLUSION_BINARY.
fn QueryType query_type_granted(QueryType requested, bool precise_supported)
{
	if (requested == OCCLUSION && !precise_supported) return OCCLUSION_BINARY;
	return requested;
}

// True when [first, first + count) lies inside a pool of `query_count`
// queries. Written to survive `first + count` wrapping.
fn bool query_range_valid(uint query_count, uint first, uint count)
{
	return count != 0 && first <= query_count && count <= query_count - first;
}

// True when a read of [first, first + count) is covered by a resolve of the
// first `resolved_count` queries.
fn bool query_range_resolved(uint resolved_count, uint first, uint count)
{
	return (ulong)first + (ulong)count <= (ulong)resolved_count;
}

fn bool query_pool_is_empty(QueryPool* p)
{
	return p.query_count == 0;
}

fn bool query_pool_is_precise(QueryPool* p)
{
	return p.type == OCCLUSION;
}

fn QueryPool? query_pool_init(Device* device, QueryPoolDesc desc)
{
	if (desc.query_count == 0) return UNSUPPORTED_FEATURE~;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return query_pool_init_vk(device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return query_pool_init_dx12(device, desc);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	unreachable();
}

fn void query_pool_deinit(QueryPool* p, Device* device)
{
	if (p.query_count == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				query_pool_deinit_vk(p, device);
			$endif
		case DX12:
			$if HAS_DX12:
				query_pool_deinit_dx12(p, device);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	*p = {};
}

// Host read of `count` 64-bit results starting at `first`. Returns false when
// the results are not ready yet (Vulkan VK_NOT_READY), the range is invalid,
// or (D3D12) no resolve has covered it. Never blocks. `results` must hold at
// least `count` values.
fn bool query_pool_get_results(QueryPool* p, Device* device, uint first, uint count, ulong* results)
{
	if (results == null || p.query_count == 0) return false;
	if (!query_range_valid(p.query_count, first, count)) return false;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return query_pool_get_results_vk(p, device, first, count, results);
			$endif
		case DX12:
			$if HAS_DX12:
				return query_pool_get_results_dx12(p, device, first, count, results);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return false;
}

// Record a reset of [first, first + count). Vulkan requires it before the
// queries are begun; no-op elsewhere.
fn void cmd_reset_query_pool(Cmd* c, Device* device, QueryPool* p, uint first, uint count)
{
	if (p.query_count == 0 || !query_range_valid(p.query_count, first, count)) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_reset_query_pool_vk(c, device, p, first, count);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_reset_query_pool_dx12(c, device, p, first, count);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
}

// Record a resolve of [first, first + count) into host-readable memory.
// Needed on D3D12 only; no-op elsewhere.
fn void cmd_resolve_query_pool(Cmd* c, Device* device, QueryPool* p, uint first, uint count)
{
	if (p.query_count == 0 || !query_range_valid(p.query_count, first, count)) return;
	switch (renderer.backend)
	{
		case VK:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
		case DX12:
			$if HAS_DX12:
				cmd_resolve_query_pool_dx12(c, device, p, first, count);
			$endif
	}
}

// ---- vulkan ----

// Vulkan occlusion query pool. Backs query.c3.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct QueryPoolVk
{
	vk::QueryPool pool;
}

fn QueryPool? query_pool_init_vk(Device* device, QueryPoolDesc desc)
{
	vk::QueryPoolCreateInfo info = {
		.sType = vk::StructureType.STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO,
		.queryType = vk::QueryType.QUERY_TYPE_OCCLUSION,
		.queryCount = desc.query_count,
	};
	vk::QueryPool pool;
	vk_check(vk::vkCreateQueryPool(device.backend.vk.device, &info, null, &pool))!;
	return {
		.query_count = desc.query_count,
		// The pool itself is always host-readable on Vulkan.
		.resolved_count = desc.query_count,
		.type = query_type_granted(desc.type, device.backend.vk.occlusion_query_precise),
		.backend.vk = { .pool = pool },
	};
}

fn void query_pool_deinit_vk(QueryPool* p, Device* device)
{
	if (p.backend.vk.pool != (vk::QueryPool)0)
	{
		vk::destroyQueryPool(device.backend.vk.device, p.backend.vk.pool, null);
	}
	p.backend.vk = {};
}

fn bool query_pool_get_results_vk(QueryPool* p, Device* device, uint first, uint count, ulong* results)
{
	// No WAIT bit: NOT_READY is a valid "try again next frame", not an error.
	vk::Result r = vk::vkGetQueryPoolResults(
		device.backend.vk.device, p.backend.vk.pool, first, count,
		(usz)count * 8, results, 8, vk::QueryResultFlagBits.QUERY_RESULT_64_BIT); // 8 = one 64-bit result
	return r == vk::Result.SUCCESS;
}

fn void cmd_reset_query_pool_vk(Cmd* c, Device* device, QueryPool* p, uint first, uint count)
{
	vk::cmdResetQueryPool(c.backend.vk.cmd, p.backend.vk.pool, first, count);
}

// ---- d3d12 ----

// D3D12 occlusion query pool: an occlusion query heap plus a READBACK buffer
// that `cmd_resolve_query_pool` resolves into. Backs query.c3.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct QueryPoolDx12
{
	// Owned.
	d3d12::QueryHeap* heap;
	// Owned: one 64-bit slot per query, persistently mapped.
	Buffer readback;
	d3d12::QueryType query_type;
}

fn QueryPool? query_pool_init_dx12(Device* device, QueryPoolDesc desc)
{
	d3d12::Device* dev = device.backend.dx12.device;
	d3d12::QueryHeapDesc heap_desc = {
		.type = d3d12::QueryHeapType.OCCLUSION,
		.count = desc.query_count,
	};
	dxgi::Guid iid = d3d12::IID_QUERY_HEAP;
	d3d12::QueryHeap* heap;
	dx12_check(dev.vtbl.create_query_heap(dev, &heap_desc, &iid, (void**)&heap))!;

	Buffer? readback = buffer_init_general(device, {
		.size = (sz)desc.query_count * 8,
		.buffer_usage = READBACK,
	});
	if (catch err = readback)
	{
		dxgi::release(heap);
		return err~;
	}
	return {
		.query_count = desc.query_count,
		// Nothing is readable until a resolve covers it.
		.resolved_count = 0,
		// D3D12 always supports precise counting.
		.type = desc.type,
		.backend.dx12 = {
			.heap = heap,
			.readback = readback,
			.query_type = desc.type == QueryType.OCCLUSION_BINARY
				? d3d12::QueryType.BINARY_OCCLUSION
				: d3d12::QueryType.OCCLUSION,
		},
	};
}

fn void query_pool_deinit_dx12(QueryPool* p, Device* device)
{
	QueryPoolDx12* q = &p.backend.dx12;
	buffer_deinit(&q.readback, device);
	if (q.heap) dxgi::release(q.heap);
	*q = {};
}

fn bool query_pool_get_results_dx12(QueryPool* p, Device* device, uint first, uint count, ulong* results)
{
	(void)device;
	if (!query_range_resolved(p.resolved_count, first, count)) return false;
	char[] region = p.backend.dx12.readback.mapped_region;
	if (region.ptr == null) return false;
	mem::copy(results, region.ptr + (usz)first * 8, (usz)count * 8);
	return true;
}

// D3D12 queries need no reset; they are overwritten when begun.
fn void cmd_reset_query_pool_dx12(Cmd* c, Device* device, QueryPool* p, uint first, uint count)
{
	(void)c;
	(void)device;
	(void)p;
	(void)first;
	(void)count;
}

fn void cmd_resolve_query_pool_dx12(Cmd* c, Device* device, QueryPool* p, uint first, uint count)
{
	(void)device;
	QueryPoolDx12* q = &p.backend.dx12;
	d3d12::GraphicsCommandList* list = c.backend.dx12.list;
	list.vtbl.resolve_query_data(list, q.heap, q.query_type, first, count, q.readback.backend.dx12.resource, (ulong)first * 8);
	// The resolve covers a prefix for readers; record the high-water mark.
	if (first + count > p.resolved_count) p.resolved_count = first + count;
}

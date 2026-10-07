// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral acceleration structure types. Only the D3D12 arm exists so
// far (see the DX12 section below); the other backends have no accel support.
module rhi;

enum AccelStructureType : char
{
	BOTTOM_LEVEL,
	TOP_LEVEL,
}

bitstruct AccelBuildFlags : ushort
{
	bool allow_update : 0;
	bool allow_compaction : 1;
	bool prefer_fast_trace : 2;
	bool prefer_fast_build : 3;
	bool minimize_memory : 4;
	bool allow_data_access : 5;
}

bitstruct AccelGeometryFlags : char
{
	bool opaque : 0;
	bool no_duplicate_any_hit_invocation : 1;
}

enum AccelGeometryType : char
{
	TRIANGLES,
	AABBS,
}

enum AccelBuildMode : char
{
	BUILD,
	UPDATE,
}

// Layout matches D3D12_RAYTRACING_AABB / VkAabbPositionsKHR.
struct AccelAabb
{
	float min_x, min_y, min_z;
	float max_x, max_y, max_z;
}

struct AccelTrianglesDesc
{
	Buffer* vertex_buffer;
	ulong vertex_offset;
	uint vertex_num;
	uint vertex_stride;
	Format vertex_format;
	// Null for unindexed geometry.
	Buffer* index_buffer;
	ulong index_offset;
	uint index_num;
	IndexType index_type;
	// Null for identity. Row-major 3x4 float matrix.
	Buffer* transform_buffer;
	ulong transform_offset;
}

struct AccelAabbsDesc
{
	Buffer* buffer;
	ulong offset;
	uint num;
	// Zero means tightly packed `AccelAabb`.
	uint stride;
}

struct AccelGeometryDesc
{
	AccelGeometryType type;
	AccelGeometryFlags flags;
	AccelTrianglesDesc triangles;
	AccelAabbsDesc aabbs;
}

struct AccelStructureDesc
{
	AccelStructureType type;
	AccelBuildFlags flags;
	// BLAS shape, used for sizing.
	AccelGeometryDesc[] geometries;
	// TLAS shape, used for sizing.
	uint instance_num;
	// Caller-owned buffer created with `acceleration_structure_storage`.
	Buffer* storage;
	ulong storage_offset;
	ulong storage_size;
}

struct AccelStructureMemoryReqs
{
	ulong storage_size;
	ulong build_scratch_size;
	ulong update_scratch_size;
}

struct AccelStructure
{
	AccelStructureType type;
	AccelBuildFlags flags;
	ulong cookie;
	union backend
	{
		AccelStructureDx12 dx12;
	}
}

struct BuildBlasDesc
{
	AccelStructure* dst;
	AccelStructure* src;
	Buffer* scratch_buffer;
	ulong scratch_offset;
	AccelGeometryDesc[] geometries;
	AccelBuildMode mode;
}

struct BuildTlasDesc
{
	AccelStructure* dst;
	AccelStructure* src;
	Buffer* scratch_buffer;
	ulong scratch_offset;
	Buffer* instance_buffer;
	ulong instance_offset;
	uint instance_num;
	AccelBuildMode mode;
}

// ---- dx12 ----

// Direct3D 12 (DXR) acceleration structures. Port of ATDD-Redux
// `RID3D12AccelStructure.cpp`.
//
// D3D12 has no acceleration-structure object: an AS is a region of a buffer
// created with `acceleration_structure_storage`. `AccelStructureDx12` only
// snapshots that region's GPU virtual address and borrows the storage
// buffer's resource for debug naming; it owns nothing and releases nothing.
//
// Barriers: callers emit ACCEL_WRITE -> ACCEL_READ memory barriers around
// builds; `dx12_resource_states` lowers those to the right UAV barrier, so
// nothing here emits one.
//
// The front accel types live at the top of this file. Nothing else references
// this section yet.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

// Borrowed from the storage buffer; `resource` is never released here.
struct AccelStructureDx12
{
	ulong device_address;
	d3d12::Resource* resource;
}

// AccelBuildFlags -> D3D12 build flags. `allow_data_access` has no D3D12
// counterpart and is dropped rather than approximated.
fn d3d12::RaytracingAccelerationStructureBuildFlags dx12_accel_build_flags(AccelBuildFlags flags)
{
	d3d12::RaytracingAccelerationStructureBuildFlags out = d3d12::BUILD_FLAG_NONE;
	if (flags.allow_update) out |= d3d12::BUILD_FLAG_ALLOW_UPDATE;
	if (flags.allow_compaction) out |= d3d12::BUILD_FLAG_ALLOW_COMPACTION;
	if (flags.prefer_fast_trace) out |= d3d12::BUILD_FLAG_PREFER_FAST_TRACE;
	if (flags.prefer_fast_build) out |= d3d12::BUILD_FLAG_PREFER_FAST_BUILD;
	if (flags.minimize_memory) out |= d3d12::BUILD_FLAG_MINIMIZE_MEMORY;
	return out;
}

fn d3d12::RaytracingGeometryFlags dx12_accel_geometry_flags(AccelGeometryFlags flags)
{
	d3d12::RaytracingGeometryFlags out = d3d12::RAYTRACING_GEOMETRY_FLAG_NONE;
	if (flags.opaque) out |= d3d12::RAYTRACING_GEOMETRY_FLAG_OPAQUE;
	if (flags.no_duplicate_any_hit_invocation) out |= d3d12::RAYTRACING_GEOMETRY_FLAG_NO_DUPLICATE_ANYHIT_INVOCATION;
	return out;
}

// Assumed: `Buffer.backend.dx12.gpu_address` is the buffer's
// GetGPUVirtualAddress, captured at creation.
fn ulong dx12_buffer_address(Buffer* b)
{
	return b.backend.dx12.gpu_address;
}

// AccelGeometryDesc -> D3D12_RAYTRACING_GEOMETRY_DESC. `resolve_addresses` is
// false for prebuild size queries, where only the shape (counts, formats,
// strides) is consulted and the buffers need not be bound yet. Returns the
// primitive count.
fn uint dx12_fill_geometry(AccelGeometryDesc* src, d3d12::RaytracingGeometryDesc* out, bool resolve_addresses)
{
	*out = {};
	out.flags = dx12_accel_geometry_flags(src.flags);
	switch (src.type)
	{
		case TRIANGLES:
			AccelTrianglesDesc* tri = &src.triangles;
			out.type = d3d12::RaytracingGeometryType.TRIANGLES;
			d3d12::RaytracingGeometryTrianglesDesc* t = &out.triangles;
			t.vertex_format = format_to_dxgi(tri.vertex_format);
			t.vertex_count = tri.vertex_num;
			t.vertex_buffer.stride_in_bytes = tri.vertex_stride;
			// Unindexed geometry passes a null index buffer; D3D12 signals that
			// with a DXGI_FORMAT_UNKNOWN index format and a zero index count.
			t.index_format = tri.index_buffer == null ? dxgi::Format.UNKNOWN
				: (tri.index_type == IndexType.UINT16 ? dxgi::Format.R16_UINT : dxgi::Format.R32_UINT);
			t.index_count = tri.index_buffer == null ? 0 : tri.index_num;
			if (resolve_addresses)
			{
				t.vertex_buffer.start_address = dx12_buffer_address(tri.vertex_buffer) + tri.vertex_offset;
				t.index_buffer = tri.index_buffer == null ? 0 : dx12_buffer_address(tri.index_buffer) + tri.index_offset;
				// A zero transform address means identity.
				t.transform_3x4 = tri.transform_buffer == null ? 0 : dx12_buffer_address(tri.transform_buffer) + tri.transform_offset;
			}
			uint index_count = tri.index_buffer == null ? tri.vertex_num : tri.index_num;
			return index_count / 3;
		case AABBS:
			AccelAabbsDesc* aab = &src.aabbs;
			out.type = d3d12::RaytracingGeometryType.PROCEDURAL_PRIMITIVE_AABBS;
			out.aabbs.aabb_count = aab.num;
			out.aabbs.aabbs.stride_in_bytes = aab.stride != 0 ? aab.stride : AccelAabb::size;
			if (resolve_addresses) out.aabbs.aabbs.start_address = dx12_buffer_address(aab.buffer) + aab.offset;
			return aab.num;
	}
}

// Assumed: `DeviceDx12.device` (d3d12::Device*, the same type as Device5) and
// `DeviceDx12.raytracing_tier` (d3d12::RaytracingTier or an int; 0 = none).
fn bool dx12_dxr_available(Device* device)
{
	return device.backend.dx12.device != null && (uint)device.backend.dx12.raytracing_tier >= 1;
}

// Prebuild sizes for `desc`. All outputs are zero when DXR is unavailable.
fn AccelStructureMemoryReqs accel_structure_get_memory_reqs_dx12(Device* device, AccelStructureDesc* desc)
{
	if (desc == null || !dx12_dxr_available(device)) return {};

	d3d12::BuildRaytracingAccelerationStructureInputs inputs;
	inputs.flags = dx12_accel_build_flags(desc.flags);
	inputs.descs_layout = d3d12::ElementsLayout.ARRAY;

	AccelStructureMemoryReqs reqs;
	@pool()
	{
		if (desc.type == AccelStructureType.BOTTOM_LEVEL)
		{
			inputs.type = d3d12::RaytracingAccelerationStructureType.BOTTOM_LEVEL;
			d3d12::RaytracingGeometryDesc[] geometries = mem::talloc_array(d3d12::RaytracingGeometryDesc, desc.geometries.len);
			foreach (i, &g : desc.geometries) dx12_fill_geometry(g, &geometries[i], false);
			inputs.num_descs = (uint)geometries.len;
			inputs.geometry_descs = geometries.ptr;
		}
		else
		{
			// TLAS sizing scales with the instance count only. An empty TLAS is
			// a legal build, but drivers may report 0 bytes for zero instances,
			// leaving no storage to init on; size it as one instance.
			inputs.type = d3d12::RaytracingAccelerationStructureType.TOP_LEVEL;
			inputs.num_descs = max(desc.instance_num, 1u);
		}

		d3d12::RaytracingAccelerationStructurePrebuildInfo info;
		d3d12::Device* dev = device.backend.dx12.device;
		dev.vtbl.get_raytracing_acceleration_structure_prebuild_info(dev, &inputs, &info);
		reqs.storage_size = info.result_data_max_size_in_bytes;
		reqs.build_scratch_size = info.scratch_data_size_in_bytes;
		reqs.update_scratch_size = info.update_scratch_data_size_in_bytes;
	};
	return reqs;
}

fn AccelStructure? accel_structure_init_dx12(Device* device, AccelStructureDesc* desc)
{
	if (!dx12_dxr_available(device))
	{
		log::error("DX12: acceleration structure requested on an adapter without DXR support");
		return UNSUPPORTED_FEATURE~;
	}
	if (desc == null || desc.storage == null || buffer_is_empty(desc.storage) || desc.storage_size == 0)
	{
		log::error("DX12: acceleration structure needs a non-empty storage buffer and a storage_size from get_memory_reqs");
		return INITIALIZATION_FAILED~;
	}
	ulong base = dx12_buffer_address(desc.storage);
	if (base == 0)
	{
		log::error("DX12: acceleration-structure storage buffer has no GPU virtual address");
		return INITIALIZATION_FAILED~;
	}
	ulong address = base + desc.storage_offset;
	// The destination of a build must be aligned. A misaligned offset is a
	// caller bug the debug layer would otherwise report as a build error.
	if (address % d3d12::RAYTRACING_ACCELERATION_STRUCTURE_BYTE_ALIGNMENT != 0)
	{
		log::error("DX12: acceleration-structure storage offset is not 256-byte aligned");
		return INITIALIZATION_FAILED~;
	}
	// Assumed: `AccelStructure` has `type`, `flags`, `cookie` and the
	// `backend.dx12` union arm; `next_cookie()` yields a globally unique id so
	// a reused address cannot collide in descriptor-set caches.
	return {
		.type = desc.type,
		.flags = desc.flags,
		.cookie = next_cookie(),
		.backend.dx12 = { .device_address = address, .resource = desc.storage.backend.dx12.resource },
	};
}

fn void accel_structure_deinit_dx12(AccelStructure* as, Device* device)
{
	// No release: resource is borrowed from the caller-owned storage buffer.
	as.backend.dx12 = {};
	as.cookie = 0;
}

fn void accel_structure_set_debug_name_dx12(AccelStructure* as, Device* device, String name)
{
	d3d12::Resource* res = as.backend.dx12.resource;
	if (res == null || name.len == 0) return;
	// Narrow to UTF-16; non-ASCII code units become '?'.
	ushort[256] wide;
	usz n = min((usz)name.len, (usz)wide.len - 1);
	for (usz i = 0; i < n; i++) wide[i] = name[i] < 0x80 ? (ushort)name[i] : '?';
	wide[n] = 0;
	res.vtbl.set_name(res, (void*)&wide);
}

fn bool accel_structure_is_empty_dx12(AccelStructure* as)
{
	return as.backend.dx12.device_address == 0;
}

// `CmdDx12.list` is a d3d12::GraphicsCommandList, the same type as
// GraphicsCommandList4; null when the device lacks DXR support.
fn d3d12::GraphicsCommandList4* dx12_dxr_cmd_list(Cmd* c, Device* device)
{
	if (!dx12_dxr_available(device)) return null;
	return c.backend.dx12.list;
}

fn void dx12_record_build(d3d12::GraphicsCommandList4* list, d3d12::BuildRaytracingAccelerationStructureDesc* build)
{
	assert(build.scratch_acceleration_structure_data % d3d12::RAYTRACING_ACCELERATION_STRUCTURE_BYTE_ALIGNMENT == 0, "scratch address must be 256-byte aligned");
	list.vtbl.build_raytracing_acceleration_structure(list, build, 0, null);
}

fn void cmd_build_blas_dx12(Cmd* c, Device* device, BuildBlasDesc[] descs)
{
	if (descs.len == 0) return;
	d3d12::GraphicsCommandList4* list = dx12_dxr_cmd_list(c, device);
	assert(list != null, "DXR builds need ID3D12GraphicsCommandList4 or newer");
	if (list == null) return;

	foreach (&d : descs)
	{
		assert(d.dst != null && d.dst.backend.dx12.device_address != 0, "dst must be initialized");
		assert(d.scratch_buffer != null);
		assert(d.geometries.len > 0);
		@pool()
		{
			d3d12::RaytracingGeometryDesc[] geometries = mem::talloc_array(d3d12::RaytracingGeometryDesc, d.geometries.len);
			foreach (i, &g : d.geometries)
			{
				uint prims = dx12_fill_geometry(g, &geometries[i], true);
				// Unbound or freed geometry yields an AS whose address later
				// faults the TLAS build that references it.
				assert(prims > 0);
				if (geometries[i].type == d3d12::RaytracingGeometryType.TRIANGLES)
				{
					assert(geometries[i].triangles.vertex_buffer.start_address != 0);
				}
			}

			d3d12::BuildRaytracingAccelerationStructureDesc build;
			build.inputs.type = d3d12::RaytracingAccelerationStructureType.BOTTOM_LEVEL;
			build.inputs.flags = dx12_accel_build_flags(d.dst.flags);
			build.inputs.descs_layout = d3d12::ElementsLayout.ARRAY;
			build.inputs.num_descs = (uint)geometries.len;
			build.inputs.geometry_descs = geometries.ptr;
			if (d.mode == AccelBuildMode.UPDATE)
			{
				build.inputs.flags |= d3d12::BUILD_FLAG_PERFORM_UPDATE;
				assert(d.src != null, "UPDATE mode needs a source acceleration structure");
			}
			build.dest_acceleration_structure_data = d.dst.backend.dx12.device_address;
			build.source_acceleration_structure_data = d.src == null ? 0 : d.src.backend.dx12.device_address;
			build.scratch_acceleration_structure_data = dx12_buffer_address(d.scratch_buffer) + d.scratch_offset;
			// D3D12 has no batched form; one call per acceleration structure.
			dx12_record_build(list, &build);
		};
	}
}

fn void cmd_build_tlas_dx12(Cmd* c, Device* device, BuildTlasDesc[] descs)
{
	if (descs.len == 0) return;
	d3d12::GraphicsCommandList4* list = dx12_dxr_cmd_list(c, device);
	assert(list != null, "DXR builds need ID3D12GraphicsCommandList4 or newer");
	if (list == null) return;

	foreach (&d : descs)
	{
		assert(d.dst != null && d.dst.backend.dx12.device_address != 0, "dst must be initialized");
		assert(d.scratch_buffer != null);
		assert(d.instance_buffer != null);
		// instance_num == 0 is a legal build: an empty TLAS keeps the RT
		// descriptor pushes valid for worlds with no RT geometry.

		d3d12::BuildRaytracingAccelerationStructureDesc build;
		build.inputs.type = d3d12::RaytracingAccelerationStructureType.TOP_LEVEL;
		build.inputs.flags = dx12_accel_build_flags(d.dst.flags);
		build.inputs.descs_layout = d3d12::ElementsLayout.ARRAY;
		build.inputs.num_descs = d.instance_num;
		if (d.instance_num != 0)
		{
			ulong instance_address = dx12_buffer_address(d.instance_buffer);
			assert(instance_address != 0);
			build.inputs.instance_descs = instance_address + d.instance_offset;
		}
		if (d.mode == AccelBuildMode.UPDATE)
		{
			build.inputs.flags |= d3d12::BUILD_FLAG_PERFORM_UPDATE;
			assert(d.src != null, "UPDATE mode needs a source acceleration structure");
		}
		build.dest_acceleration_structure_data = d.dst.backend.dx12.device_address;
		build.source_acceleration_structure_data = d.src == null ? 0 : d.src.backend.dx12.device_address;
		build.scratch_acceleration_structure_data = dx12_buffer_address(d.scratch_buffer) + d.scratch_offset;
		dx12_record_build(list, &build);
	}
}

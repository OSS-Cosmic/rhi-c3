// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral acceleration structure types and entry points. Vulkan
// (VK_KHR_acceleration_structure) and D3D12 (DXR) are implemented in their own
// sections below; Metal, WebGPU and WebGL2 have no accel support and report
// UNSUPPORTED_FEATURE.
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
		AccelStructureVk vk;
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

bitstruct AccelInstanceFlags : char
{
	bool triangle_cull_disable : 0;
	bool triangle_flip_facing : 1;
	bool force_opaque : 2;
	bool force_non_opaque : 3;
}

// One TLAS instance. Fill a buffer of these (created with
// `acceleration_structure_build_input | device_address`) and pass it as
// `BuildTlasDesc.instance_buffer`. 64 bytes; identical layout for
// VkAccelerationStructureInstanceKHR and D3D12_RAYTRACING_INSTANCE_DESC.
struct AccelInstance
{
	// Row-major 3x4 object-to-world matrix.
	float[12] transform;
	// custom_index in the low 24 bits, visibility mask in the high 8.
	uint custom_index_and_mask;
	// SBT record offset in the low 24 bits, AccelInstanceFlags in the high 8.
	uint sbt_offset_and_flags;
	// accel_structure_device_address() of the BLAS.
	ulong blas_address;
}

<* @require AccelInstance::size == 64 *>
fn AccelInstance accel_instance(AccelStructure* blas, float[12] transform, uint custom_index = 0, char mask = 0xff, uint sbt_offset = 0, AccelInstanceFlags flags = {})
{
	return {
		.transform = transform,
		.custom_index_and_mask = (custom_index & 0xFFFFFF) | ((uint)mask << 24),
		.sbt_offset_and_flags = (sbt_offset & 0xFFFFFF) | ((uint)(char)flags << 24),
		.blas_address = accel_structure_device_address(blas),
	};
}

const float[12] ACCEL_IDENTITY_TRANSFORM = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0 };

fn bool accel_structure_is_empty(AccelStructure* as) => as.cookie == 0;

// Storage and scratch sizes needed before creating `desc`. All zero when the
// backend or adapter has no acceleration-structure support.
fn AccelStructureMemoryReqs accel_structure_get_memory_reqs(Device* device, AccelStructureDesc* desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return accel_structure_get_memory_reqs_vk(device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return accel_structure_get_memory_reqs_dx12(device, desc);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return {};
}

// Creates the structure over `desc.storage` (sized from the memory reqs).
// Building it is a separate command: `cmd_build_blas` / `cmd_build_tlas`.
fn AccelStructure? accel_structure_init(Device* device, AccelStructureDesc* desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return accel_structure_init_vk(device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return accel_structure_init_dx12(device, desc);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return UNSUPPORTED_FEATURE~;
}

fn void accel_structure_deinit(AccelStructure* as, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				accel_structure_deinit_vk(as, device);
			$endif
		case DX12:
			$if HAS_DX12:
				accel_structure_deinit_dx12(as, device);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
}

// The address shaders and `AccelInstance.blas_address` refer to.
fn ulong accel_structure_device_address(AccelStructure* as)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return as.backend.vk.device_address;
			$endif
		case DX12:
			$if HAS_DX12:
				return as.backend.dx12.device_address;
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return 0;
}

// Records BLAS builds or updates. The caller owns barriers: vertex/index data
// in ACCEL_BUILD_INPUT before, ACCEL_WRITE -> ACCEL_READ after.
fn void cmd_build_blas(Cmd* c, Device* device, BuildBlasDesc[] descs)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_build_blas_vk(c, device, descs);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_build_blas_dx12(c, device, descs);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
}

fn void cmd_build_tlas(Cmd* c, Device* device, BuildTlasDesc[] descs)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				cmd_build_tlas_vk(c, device, descs);
			$endif
		case DX12:
			$if HAS_DX12:
				cmd_build_tlas_dx12(c, device, descs);
			$endif
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
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

// ---- vulkan ----

// VK_KHR_acceleration_structure. Port of rhi-zig `acceleration_structure.zig`
// (itself from ATDD-Redux `RIRenderer.cpp` RI_VK_FillGeometry / getMemoryReqs /
// init / build).
//
// A Vulkan AS is an object created over a region of a buffer made with
// `acceleration_structure_storage`; the buffer stays caller-owned. Geometry and
// scratch buffers need `device_address` usage (implied on adapters with buffer
// device address). Buffer offsets are folded into the device addresses, so the
// build ranges carry no offsets.
//
// Barriers are the caller's: ACCEL_BUILD_INPUT on geometry before a build,
// ACCEL_WRITE -> ACCEL_READ after it.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct AccelStructureVk
{
	vk::AccelerationStructureKHR handle;
	ulong device_address;
}

fn bool vk_accel_available(Device* device) @local
{
	return device.adapter.backend.vk.is_acceleration_structure_supported;
}

fn ulong vk_accel_buffer_address(Device* device, Buffer* b, ulong offset) @local
{
	vk::BufferDeviceAddressInfo info = {
		.sType = vk::StructureType.STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO,
		.buffer = b.backend.vk.buffer,
	};
	return (ulong)vk::getBufferDeviceAddress(device.backend.vk.device, &info) + offset;
}

// The address a build writes its scratch to: `buffer + offset` rounded up to the
// adapter's scratch alignment. `accel_structure_get_memory_reqs` pads the scratch
// sizes by `alignment - 1`, so a buffer of that size always has room.
fn ulong vk_accel_scratch_address(Device* device, Buffer* b, ulong offset) @local
{
	ulong address = vk_accel_buffer_address(device, b, offset);
	ulong alignment = (ulong)device.adapter.scratch_buffer_offset_alignment;
	if (alignment > 1) address = (address + alignment - 1) / alignment * alignment;
	return address;
}

fn vk::BuildAccelerationStructureFlagsKHR vk_accel_build_flags(AccelBuildFlags flags) @local
{
	vk::BuildAccelerationStructureFlagsKHR out = 0;
	if (flags.allow_update) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_ALLOW_UPDATE_BIT_KHR;
	if (flags.allow_compaction) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_ALLOW_COMPACTION_BIT_KHR;
	if (flags.prefer_fast_trace) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_TRACE_BIT_KHR;
	if (flags.prefer_fast_build) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_PREFER_FAST_BUILD_BIT_KHR;
	if (flags.minimize_memory) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_LOW_MEMORY_BIT_KHR;
	if (flags.allow_data_access) out |= vk::BuildAccelerationStructureFlagBitsKHR.BUILD_ACCELERATION_STRUCTURE_ALLOW_DATA_ACCESS_BIT_KHR;
	return out;
}

// AccelGeometryDesc -> VkAccelerationStructureGeometryKHR; returns the
// primitive count. `resolve_addresses` is false for size queries, where only
// counts, formats and strides are read and the buffers need not exist yet.
fn uint vk_accel_fill_geometry(Device* device, AccelGeometryDesc* src, vk::AccelerationStructureGeometryKHR* out, bool resolve_addresses) @local
{
	*out = { .sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR };
	vk::GeometryFlagsKHR flags = 0;
	if (src.flags.opaque) flags |= vk::GeometryFlagBitsKHR.GEOMETRY_OPAQUE_BIT_KHR;
	if (src.flags.no_duplicate_any_hit_invocation) flags |= vk::GeometryFlagBitsKHR.GEOMETRY_NO_DUPLICATE_ANY_HIT_INVOCATION_BIT_KHR;
	out.flags = flags;

	switch (src.type)
	{
		case TRIANGLES:
			AccelTrianglesDesc* t = &src.triangles;
			out.geometryType = vk::GeometryTypeKHR.GEOMETRY_TYPE_TRIANGLES_KHR;
			out.geometry.triangles = {
				.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_TRIANGLES_DATA_KHR,
				.vertexFormat = to_vk_format(t.vertex_format),
				.vertexStride = t.vertex_stride,
				.maxVertex = t.vertex_num > 0 ? t.vertex_num - 1 : 0,
				.indexType = t.index_buffer == null
					? vk::IndexType.INDEX_TYPE_NONE_KHR
					: (t.index_type == UINT16 ? vk::IndexType.INDEX_TYPE_UINT16 : vk::IndexType.INDEX_TYPE_UINT32),
			};
			if (resolve_addresses)
			{
				out.geometry.triangles.vertexData.deviceAddress = vk_accel_buffer_address(device, t.vertex_buffer, t.vertex_offset);
				if (t.index_buffer != null) out.geometry.triangles.indexData.deviceAddress = vk_accel_buffer_address(device, t.index_buffer, t.index_offset);
				if (t.transform_buffer != null) out.geometry.triangles.transformData.deviceAddress = vk_accel_buffer_address(device, t.transform_buffer, t.transform_offset);
			}
			return (t.index_buffer != null ? t.index_num : t.vertex_num) / 3;
		case AABBS:
			AccelAabbsDesc* a = &src.aabbs;
			out.geometryType = vk::GeometryTypeKHR.GEOMETRY_TYPE_AABBS_KHR;
			out.geometry.aabbs = {
				.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_AABBS_DATA_KHR,
				.stride = a.stride > 0 ? a.stride : AccelAabb::size,
			};
			if (resolve_addresses) out.geometry.aabbs.data.deviceAddress = vk_accel_buffer_address(device, a.buffer, a.offset);
			return a.num;
	}
}

fn vk::AccelerationStructureGeometryKHR vk_accel_instances_geometry(ulong address) @local
{
	vk::AccelerationStructureGeometryKHR g = {
		.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_KHR,
		.geometryType = vk::GeometryTypeKHR.GEOMETRY_TYPE_INSTANCES_KHR,
	};
	g.geometry.instances = {
		.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_GEOMETRY_INSTANCES_DATA_KHR,
		.arrayOfPointers = vk::FALSE,
	};
	g.geometry.instances.data.deviceAddress = address;
	return g;
}

fn vk::AccelerationStructureTypeKHR vk_accel_type(AccelStructureType type) @local
{
	return type == TOP_LEVEL
		? vk::AccelerationStructureTypeKHR.ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR
		: vk::AccelerationStructureTypeKHR.ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR;
}

fn vk::BuildAccelerationStructureModeKHR vk_accel_mode(AccelBuildMode mode) @local
{
	return mode == UPDATE
		? vk::BuildAccelerationStructureModeKHR.BUILD_ACCELERATION_STRUCTURE_MODE_UPDATE_KHR
		: vk::BuildAccelerationStructureModeKHR.BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR;
}

fn AccelStructureMemoryReqs accel_structure_get_memory_reqs_vk(Device* device, AccelStructureDesc* desc)
{
	if (desc == null || !vk_accel_available(device)) return {};
	AccelStructureMemoryReqs reqs;
	@pool()
	{
		vk::AccelerationStructureBuildGeometryInfoKHR info = {
			.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR,
			.type = vk_accel_type(desc.type),
			.flags = vk_accel_build_flags(desc.flags),
			.mode = vk::BuildAccelerationStructureModeKHR.BUILD_ACCELERATION_STRUCTURE_MODE_BUILD_KHR,
		};
		vk::AccelerationStructureBuildSizesInfoKHR sizes = { .sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_SIZES_INFO_KHR };
		if (desc.type == BOTTOM_LEVEL)
		{
			vk::AccelerationStructureGeometryKHR[] geometries = mem::talloc_array(vk::AccelerationStructureGeometryKHR, desc.geometries.len);
			uint[] counts = mem::talloc_array(uint, desc.geometries.len);
			foreach (i, &g : desc.geometries) counts[i] = vk_accel_fill_geometry(device, g, &geometries[i], false);
			info.geometryCount = (uint)geometries.len;
			info.pGeometries = geometries.ptr;
			vk::extensions.vkGetAccelerationStructureBuildSizesKHR(
				device.backend.vk.device, vk::AccelerationStructureBuildTypeKHR.ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
				&info, counts.ptr, &sizes);
		}
		else
		{
			// An empty TLAS is legal but may size to 0 bytes; size it as one instance.
			vk::AccelerationStructureGeometryKHR geometry = vk_accel_instances_geometry(0);
			uint count = max(desc.instance_num, 1u);
			info.geometryCount = 1;
			info.pGeometries = &geometry;
			vk::extensions.vkGetAccelerationStructureBuildSizesKHR(
				device.backend.vk.device, vk::AccelerationStructureBuildTypeKHR.ACCELERATION_STRUCTURE_BUILD_TYPE_DEVICE_KHR,
				&info, &count, &sizes);
		}
		// Builds round the scratch address up to the adapter alignment, so size
		// the scratch buffer with that much slack.
		ulong slack = device.adapter.scratch_buffer_offset_alignment > 1 ? (ulong)device.adapter.scratch_buffer_offset_alignment - 1 : 0;
		reqs.storage_size = sizes.accelerationStructureSize;
		reqs.build_scratch_size = sizes.buildScratchSize + slack;
		reqs.update_scratch_size = sizes.updateScratchSize + slack;
	};
	return reqs;
}

fn AccelStructure? accel_structure_init_vk(Device* device, AccelStructureDesc* desc)
{
	if (!vk_accel_available(device))
	{
		log::error("Vulkan: acceleration structure requested on an adapter without VK_KHR_acceleration_structure");
		return UNSUPPORTED_FEATURE~;
	}
	if (desc == null || desc.storage == null || buffer_is_empty(desc.storage) || desc.storage_size == 0)
	{
		log::error("Vulkan: acceleration structure needs a non-empty storage buffer and a storage_size from get_memory_reqs");
		return INITIALIZATION_FAILED~;
	}
	vk::AccelerationStructureCreateInfoKHR create_info = {
		.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_CREATE_INFO_KHR,
		.buffer = desc.storage.backend.vk.buffer,
		.offset = desc.storage_offset,
		.size = desc.storage_size,
		.type = vk_accel_type(desc.type),
	};
	vk::AccelerationStructureKHR handle;
	vk_check(vk::extensions.vkCreateAccelerationStructureKHR(device.backend.vk.device, &create_info, null, &handle))!;
	vk::AccelerationStructureDeviceAddressInfoKHR address_info = {
		.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_DEVICE_ADDRESS_INFO_KHR,
		.accelerationStructure = handle,
	};
	return {
		.type = desc.type,
		.flags = desc.flags,
		.cookie = next_cookie(),
		.backend.vk = {
			.handle = handle,
			.device_address = (ulong)vk::extensions.vkGetAccelerationStructureDeviceAddressKHR(device.backend.vk.device, &address_info),
		},
	};
}

// The storage buffer is the caller's and is not released.
fn void accel_structure_deinit_vk(AccelStructure* as, Device* device)
{
	if (as.backend.vk.handle != (vk::AccelerationStructureKHR)0)
	{
		vk::extensions.vkDestroyAccelerationStructureKHR(device.backend.vk.device, as.backend.vk.handle, null);
	}
	as.backend.vk = {};
	as.cookie = 0;
}

fn void cmd_build_blas_vk(Cmd* c, Device* device, BuildBlasDesc[] descs)
{
	if (descs.len == 0) return;
	@pool()
	{
		vk::AccelerationStructureBuildGeometryInfoKHR[] infos = mem::talloc_array(vk::AccelerationStructureBuildGeometryInfoKHR, descs.len);
		vk::AccelerationStructureBuildRangeInfoKHR*[] range_ptrs = mem::talloc_array(vk::AccelerationStructureBuildRangeInfoKHR*, descs.len);
		foreach (i, &d : descs)
		{
			assert(d.dst != null && d.dst.type == BOTTOM_LEVEL, "cmd_build_blas: dst must be a bottom-level structure");
			assert(d.mode == BUILD || d.src != null, "cmd_build_blas: UPDATE needs a src");
			vk::AccelerationStructureGeometryKHR[] geometries = mem::talloc_array(vk::AccelerationStructureGeometryKHR, d.geometries.len);
			vk::AccelerationStructureBuildRangeInfoKHR[] ranges = mem::talloc_array(vk::AccelerationStructureBuildRangeInfoKHR, d.geometries.len);
			foreach (j, &g : d.geometries)
			{
				ranges[j] = { .primitiveCount = vk_accel_fill_geometry(device, g, &geometries[j], true) };
			}
			infos[i] = {
				.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR,
				.type = vk::AccelerationStructureTypeKHR.ACCELERATION_STRUCTURE_TYPE_BOTTOM_LEVEL_KHR,
				.flags = vk_accel_build_flags(d.dst.flags),
				.mode = vk_accel_mode(d.mode),
				.srcAccelerationStructure = d.src != null ? d.src.backend.vk.handle : (vk::AccelerationStructureKHR)0,
				.dstAccelerationStructure = d.dst.backend.vk.handle,
				.geometryCount = (uint)geometries.len,
				.pGeometries = geometries.ptr,
			};
			infos[i].scratchData.deviceAddress = vk_accel_scratch_address(device, d.scratch_buffer, d.scratch_offset);
			range_ptrs[i] = ranges.ptr;
		}
		// The binding types the last parameter as one range pointer; the C API
		// takes an array of them.
		vk::extensions.vkCmdBuildAccelerationStructuresKHR(
			c.backend.vk.cmd, (uint)descs.len, infos.ptr, (vk::AccelerationStructureBuildRangeInfoKHR*)(void*)range_ptrs.ptr);
	};
}

fn void cmd_build_tlas_vk(Cmd* c, Device* device, BuildTlasDesc[] descs)
{
	if (descs.len == 0) return;
	@pool()
	{
		vk::AccelerationStructureBuildGeometryInfoKHR[] infos = mem::talloc_array(vk::AccelerationStructureBuildGeometryInfoKHR, descs.len);
		vk::AccelerationStructureGeometryKHR[] geometries = mem::talloc_array(vk::AccelerationStructureGeometryKHR, descs.len);
		vk::AccelerationStructureBuildRangeInfoKHR[] ranges = mem::talloc_array(vk::AccelerationStructureBuildRangeInfoKHR, descs.len);
		vk::AccelerationStructureBuildRangeInfoKHR*[] range_ptrs = mem::talloc_array(vk::AccelerationStructureBuildRangeInfoKHR*, descs.len);
		foreach (i, &d : descs)
		{
			assert(d.dst != null && d.dst.type == TOP_LEVEL, "cmd_build_tlas: dst must be a top-level structure");
			assert(d.mode == BUILD || d.src != null, "cmd_build_tlas: UPDATE needs a src");
			geometries[i] = vk_accel_instances_geometry(vk_accel_buffer_address(device, d.instance_buffer, d.instance_offset));
			ranges[i] = { .primitiveCount = d.instance_num };
			infos[i] = {
				.sType = vk::StructureType.STRUCTURE_TYPE_ACCELERATION_STRUCTURE_BUILD_GEOMETRY_INFO_KHR,
				.type = vk::AccelerationStructureTypeKHR.ACCELERATION_STRUCTURE_TYPE_TOP_LEVEL_KHR,
				.flags = vk_accel_build_flags(d.dst.flags),
				.mode = vk_accel_mode(d.mode),
				.srcAccelerationStructure = d.src != null ? d.src.backend.vk.handle : (vk::AccelerationStructureKHR)0,
				.dstAccelerationStructure = d.dst.backend.vk.handle,
				.geometryCount = 1,
				.pGeometries = &geometries[i],
			};
			infos[i].scratchData.deviceAddress = vk_accel_scratch_address(device, d.scratch_buffer, d.scratch_offset);
			range_ptrs[i] = &ranges[i];
		}
		vk::extensions.vkCmdBuildAccelerationStructuresKHR(
			c.backend.vk.cmd, (uint)descs.len, infos.ptr, (vk::AccelerationStructureBuildRangeInfoKHR*)(void*)range_ptrs.ptr);
	};
}

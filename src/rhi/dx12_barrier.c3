// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// D3D12 barrier translation: `ResourceState` / `BarrierStages` to legacy
// `D3D12_RESOURCE_STATES` and the transition/UAV decision. Port of the state
// mapping in ATDD-Redux `RID3D12Barrier.cpp`. The vendor binding has no
// enhanced-barrier (`D3D12_BARRIER_*`) types, so only legacy states exist.
//
// Everything here is pure (no device, no COM), so it compiles and is tested
// on every host. The `cmd_resource_barrier_dx12` recorder that consumes it is
// gated by `HAS_DX12`.
module rhi;
import d3d12;

// Bits that put the resource in a writable state. D3D12 forbids combining
// any of them with another state bit.
const d3d12::ResourceStates DX12_WRITE_STATES =
	d3d12::RESOURCE_STATE_RENDER_TARGET
	| d3d12::RESOURCE_STATE_UNORDERED_ACCESS
	| d3d12::RESOURCE_STATE_DEPTH_WRITE
	| d3d12::RESOURCE_STATE_STREAM_OUT
	| d3d12::RESOURCE_STATE_COPY_DEST
	| d3d12::RESOURCE_STATE_RESOLVE_DEST
	| d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE;

enum Dx12BarrierKind : char
{
	// Same state, nothing to order.
	NONE,
	// `ResourceBarrier(TRANSITION)`.
	TRANSITION,
	// `ResourceBarrier(UAV)`: UAV to UAV (or acceleration structure to itself).
	UAV,
}

// Translate `state` to D3D12 resource states. `stages` narrows a shader
// resource read to the pixel or non-pixel bit; an empty set keeps both.
// The empty state (UNDEFINED) and `general`/`present` map to COMMON (0).
fn d3d12::ResourceStates dx12_resource_states(ResourceState state, BarrierStages stages = {})
{
	d3d12::ResourceStates r = d3d12::RESOURCE_STATE_COMMON;
	if (state.render_target) r |= d3d12::RESOURCE_STATE_RENDER_TARGET;
	if (state.render_target_read) r |= d3d12::RESOURCE_STATE_RENDER_TARGET;
	if (state.depth_write) r |= d3d12::RESOURCE_STATE_DEPTH_WRITE;
	if (state.depth_read) r |= d3d12::RESOURCE_STATE_DEPTH_READ;
	if (state.shader_resource) r |= dx12_shader_resource_states(stages);
	if (state.storage_read || state.storage_write || state.clear_storage) r |= d3d12::RESOURCE_STATE_UNORDERED_ACCESS;
	if (state.copy_src) r |= d3d12::RESOURCE_STATE_COPY_SOURCE;
	// A readback heap resource is fixed at COPY_DEST.
	if (state.copy_dst || state.host_read) r |= d3d12::RESOURCE_STATE_COPY_DEST;
	if (state.indirect_argument) r |= d3d12::RESOURCE_STATE_INDIRECT_ARGUMENT;
	if (state.vertex_buffer || state.constant_buffer) r |= d3d12::RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER;
	if (state.index_buffer) r |= d3d12::RESOURCE_STATE_INDEX_BUFFER;
	if (state.accel_read || state.accel_write) r |= d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE;
	// Build inputs are plain buffers read by the build.
	if (state.accel_build_input) r |= d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
	return dx12_resolve_conflicts(r);
}

fn d3d12::ResourceStates dx12_shader_resource_states(BarrierStages stages)
{
	bool pixel = stages.fragment;
	bool non_pixel = stages.vertex || stages.compute || stages.ray_tracing;
	if (pixel && !non_pixel) return d3d12::RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
	if (non_pixel && !pixel) return d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
	return d3d12::RESOURCE_STATE_PIXEL_SHADER_RESOURCE | d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
}

// D3D12 rejects a write state combined with any other bit. When a set mixes
// them, keep only the write bits (the stronger requirement); several write
// bits at once are still invalid and left for the caller to see.
fn d3d12::ResourceStates dx12_resolve_conflicts(d3d12::ResourceStates r)
{
	d3d12::ResourceStates writes = r & DX12_WRITE_STATES;
	if (writes != 0) return writes;
	return r;
}

// True when `r` is a legal D3D12 state: at most one write bit, and a write
// bit never mixed with read bits.
fn bool dx12_resource_states_valid(d3d12::ResourceStates r)
{
	uint writes = (uint)(r & DX12_WRITE_STATES);
	if (writes == 0) return true;
	return (writes & (writes - 1)) == 0 && (uint)r == writes;
}

// What `cmd_resource_barrier_dx12` must emit between two states.
fn Dx12BarrierKind dx12_barrier_kind(d3d12::ResourceStates before, d3d12::ResourceStates after)
{
	if (before == after)
	{
		bool uav = (uint)(before & d3d12::RESOURCE_STATE_UNORDERED_ACCESS) != 0;
		bool accel = (uint)(before & d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE) != 0;
		return (uav || accel) ? Dx12BarrierKind.UAV : Dx12BarrierKind.NONE;
	}
	return Dx12BarrierKind.TRANSITION;
}

// Image aspect to the plane subresource count multiplier is device specific,
// so only the aspect mask is decided here: true when the barrier touches the
// depth plane / stencil plane.
fn bool dx12_aspect_has_depth(BarrierAspect a) => a == BarrierAspect.DEPTH || a == BarrierAspect.DEPTH_STENCIL;
fn bool dx12_aspect_has_stencil(BarrierAspect a) => a == BarrierAspect.STENCIL || a == BarrierAspect.DEPTH_STENCIL;

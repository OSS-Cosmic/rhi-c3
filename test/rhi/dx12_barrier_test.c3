// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;
import d3d12;

fn void dx12_states_single_bits() @test
{
	test::eq(dx12_resource_states({}), d3d12::RESOURCE_STATE_COMMON);
	test::eq(dx12_resource_states({ .general = true }), d3d12::RESOURCE_STATE_COMMON);
	test::eq(dx12_resource_states({ .present = true }), d3d12::RESOURCE_STATE_PRESENT);
	test::eq(dx12_resource_states({ .render_target = true }), d3d12::RESOURCE_STATE_RENDER_TARGET);
	test::eq(dx12_resource_states({ .depth_write = true }), d3d12::RESOURCE_STATE_DEPTH_WRITE);
	test::eq(dx12_resource_states({ .depth_read = true }), d3d12::RESOURCE_STATE_DEPTH_READ);
	test::eq(dx12_resource_states({ .copy_src = true }), d3d12::RESOURCE_STATE_COPY_SOURCE);
	test::eq(dx12_resource_states({ .copy_dst = true }), d3d12::RESOURCE_STATE_COPY_DEST);
	test::eq(dx12_resource_states({ .indirect_argument = true }), d3d12::RESOURCE_STATE_INDIRECT_ARGUMENT);
	test::eq(dx12_resource_states({ .index_buffer = true }), d3d12::RESOURCE_STATE_INDEX_BUFFER);
	test::eq(dx12_resource_states({ .vertex_buffer = true }), d3d12::RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER);
	test::eq(dx12_resource_states({ .constant_buffer = true }), d3d12::RESOURCE_STATE_VERTEX_AND_CONSTANT_BUFFER);
	test::eq(dx12_resource_states({ .storage_write = true }), d3d12::RESOURCE_STATE_UNORDERED_ACCESS);
	test::eq(dx12_resource_states({ .clear_storage = true }), d3d12::RESOURCE_STATE_UNORDERED_ACCESS);
	test::eq(dx12_resource_states({ .accel_write = true }), d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE);
	test::eq(dx12_resource_states({ .accel_build_input = true }), d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
}

fn void dx12_states_shader_resource_follows_stages() @test
{
	ResourceState srv = { .shader_resource = true };
	test::eq(dx12_resource_states(srv, { .fragment = true }), d3d12::RESOURCE_STATE_PIXEL_SHADER_RESOURCE);
	test::eq(dx12_resource_states(srv, { .compute = true }), d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
	test::eq(dx12_resource_states(srv, { .vertex = true }), d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE);
	d3d12::ResourceStates both = d3d12::RESOURCE_STATE_PIXEL_SHADER_RESOURCE | d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE;
	test::eq(dx12_resource_states(srv), both);
	test::eq(dx12_resource_states(srv, { .fragment = true, .compute = true }), both);
}

fn void dx12_states_combine_reads_and_drop_reads_next_to_writes() @test
{
	d3d12::ResourceStates reads = d3d12::RESOURCE_STATE_INDEX_BUFFER | d3d12::RESOURCE_STATE_COPY_SOURCE;
	test::eq(dx12_resource_states({ .index_buffer = true, .copy_src = true }), reads);
	test::eq(dx12_resource_states({ .copy_src = true, .copy_dst = true }), d3d12::RESOURCE_STATE_COPY_DEST);
	test::eq(dx12_resource_states({ .storage_read = true, .storage_write = true }), d3d12::RESOURCE_STATE_UNORDERED_ACCESS);
}

fn void dx12_states_valid_rejects_mixed_writes() @test
{
	test::eq(dx12_resource_states_valid(d3d12::RESOURCE_STATE_COMMON), true);
	test::eq(dx12_resource_states_valid(d3d12::RESOURCE_STATE_RENDER_TARGET), true);
	test::eq(dx12_resource_states_valid(d3d12::RESOURCE_STATE_INDEX_BUFFER | d3d12::RESOURCE_STATE_COPY_SOURCE), true);
	test::eq(dx12_resource_states_valid(d3d12::RESOURCE_STATE_RENDER_TARGET | d3d12::RESOURCE_STATE_COPY_SOURCE), false);
	test::eq(dx12_resource_states_valid(d3d12::RESOURCE_STATE_RENDER_TARGET | d3d12::RESOURCE_STATE_COPY_DEST), false);
}

fn void dx12_barrier_kind_picks_transition_or_uav() @test
{
	test::eq(dx12_barrier_kind(d3d12::RESOURCE_STATE_COPY_DEST, d3d12::RESOURCE_STATE_COPY_SOURCE), Dx12BarrierKind.TRANSITION);
	test::eq(dx12_barrier_kind(d3d12::RESOURCE_STATE_COPY_SOURCE, d3d12::RESOURCE_STATE_COPY_SOURCE), Dx12BarrierKind.NONE);
	test::eq(dx12_barrier_kind(d3d12::RESOURCE_STATE_UNORDERED_ACCESS, d3d12::RESOURCE_STATE_UNORDERED_ACCESS), Dx12BarrierKind.UAV);
	test::eq(dx12_barrier_kind(d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE, d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE), Dx12BarrierKind.UAV);
	test::eq(dx12_barrier_kind(d3d12::RESOURCE_STATE_UNORDERED_ACCESS, d3d12::RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE), Dx12BarrierKind.TRANSITION);
}

fn void dx12_aspect_planes() @test
{
	test::eq(dx12_aspect_has_depth(BarrierAspect.COLOR), false);
	test::eq(dx12_aspect_has_depth(BarrierAspect.DEPTH), true);
	test::eq(dx12_aspect_has_stencil(BarrierAspect.DEPTH), false);
	test::eq(dx12_aspect_has_stencil(BarrierAspect.STENCIL), true);
	test::eq(dx12_aspect_has_depth(BarrierAspect.DEPTH_STENCIL), true);
	test::eq(dx12_aspect_has_stencil(BarrierAspect.DEPTH_STENCIL), true);
}

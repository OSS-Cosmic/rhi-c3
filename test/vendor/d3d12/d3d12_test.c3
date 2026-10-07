// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module d3d12;
import dxgi, std::core::test;

// Struct sizes are additionally pinned at compile time by
// src/vendor/d3d12/layout.c3; these tests cover the same ABI from the test
// runner plus enum values and vtable slot offsets, so they run on any host.
// Plain assert: test::eq rejects untyped literal operands in c3c 0.8.4.

fn void struct_sizes() @test
{
	usz resource_desc = ResourceDesc::size;
	usz barrier = ResourceBarrier::size;
	usz pso = GraphicsPipelineStateDesc::size;
	usz instance = RaytracingInstanceDesc::size;
	assert(resource_desc == 56);
	assert(barrier == 32);
	assert(pso == 656);
	assert(instance == 64);
}

fn void enum_values() @test
{
	uint rgba8 = (uint)Format.R8G8B8A8_UNORM;
	uint bc7 = (uint)Format.BC7_UNORM_SRGB;
	uint level = (uint)FeatureLevel.LEVEL_12_0;
	uint copy_queue = (uint)CommandListType.COPY;
	uint generic_read = (uint)RESOURCE_STATE_GENERIC_READ;
	uint accel = (uint)RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE;
	assert(rgba8 == 28);
	assert(bc7 == 99);
	assert(level == 0xc000);
	assert(copy_queue == 3);
	assert(generic_read == 0xAC3);
	assert(accel == 0x400000);
}

// COM vtables are plain arrays of pointers: a slot's offset is 8 * its index
// in the Windows headers.
fn void vtable_slots() @test
{
	usz release = $reflect(UnknownVtbl.release).offset;
	usz execute = $reflect(CommandQueueVtbl.execute_command_lists).offset;
	usz create_fence = $reflect(DeviceVtbl.create_fence).offset;
	usz dispatch_rays = $reflect(GraphicsCommandListVtbl.dispatch_rays).offset;
	usz state_object = $reflect(DeviceVtbl.create_state_object).offset;
	usz present = $reflect(SwapChainVtbl.present).offset;
	usz back_buffer = $reflect(SwapChainVtbl.get_current_back_buffer_index).offset;
	assert(release == 8 * 2);
	assert(execute == 8 * 10);
	assert(create_fence == 8 * 36);
	assert(dispatch_rays == 8 * 76);
	assert(state_object == 8 * 62);
	assert(present == 8 * 8);
	assert(back_buffer == 8 * 36);
}

fn void guid_layout() @test
{
	uint data1 = IID_DEVICE.data1;
	char first = dxgi::IID_IUNKNOWN.data4[0];
	char last = dxgi::IID_IUNKNOWN.data4[7];
	assert(data1 == 0x189819f1);
	assert(first == 0xC0);
	assert(last == 0x46);
}

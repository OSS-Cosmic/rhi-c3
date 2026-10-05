// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal logical device. Port of the `.mtl` arms of rhi-zig's `device.zig`
// `init`/`deinit`.
//
// Metal has one device-level MTLCommandQueue type with no queue families:
// the single queue created here is the graphics queue, and there is no
// separate compute or transfer queue.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct DeviceMtl
{
	// Owned: a retain on the adapter's MTLDevice.
	mtl::Device device;
	// Owned; `graphics_queue` borrows it.
	mtl::CommandQueue queue;
}

fn Device? device_init_mtl(PhysicalAdapter* adapter, Allocator allocator = mem)
{
	mtl::Device device = adapter.backend.mtl.device;
	if (!device) return INITIALIZATION_FAILED~;
	mtl::CommandQueue queue = device.new_command_queue();
	if (!queue) return INITIALIZATION_FAILED~;
	mtl::SharedEvent completion_event = device.new_shared_event();
	if (!completion_event)
	{
		queue.release();
		return INITIALIZATION_FAILED~;
	}
	device.retain();
	return {
		.graphics_queue = { .backend.mtl = { .queue = queue, .completion_event = completion_event } },
		.adapter = *adapter,
		.allocator = allocator,
		.backend.mtl = { .device = device, .queue = queue },
	};
}

fn void device_deinit_mtl(Device* d)
{
	QueueMtl* graphics = &d.graphics_queue.backend.mtl;
	if (graphics.completion_event) graphics.completion_event.release();
	*graphics = {};
	DeviceMtl* state = &d.backend.mtl;
	if (state.queue) state.queue.release();
	if (state.device) state.device.release();
	*state = {};
}

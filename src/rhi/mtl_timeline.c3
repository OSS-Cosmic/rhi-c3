// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal timeline: an MTLSharedEvent, whose signaled value is the GPU side of
// the front's monotonic counter. Submits wait on and signal it through
// encodeWaitForEvent/encodeSignalEvent (see mtl_queue.c3).
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct TimelineMtl
{
	mtl::SharedEvent event;
}

fn Timeline? timeline_init_mtl(Device* device)
{
	mtl::SharedEvent event = device.backend.mtl.device.new_shared_event();
	if (!event) return INITIALIZATION_FAILED~;
	return { .backend.mtl = { .event = event } };
}

fn void timeline_deinit_mtl(Timeline* t, Device* device)
{
	if (t.backend.mtl.event) t.backend.mtl.event.release();
	t.backend.mtl = {};
}

fn ulong? timeline_completed_mtl(Timeline* t, Device* device)
{
	return t.backend.mtl.event.signaled_value();
}

fn void? timeline_wait_mtl(Timeline* t, Device* device, ulong value)
{
	mtl_shared_event_wait(t.backend.mtl.event, value);
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal fence. Mirrors the D3D12 fence (rhi/d3d12.odin `Fence_Dx12`): a
// one-shot fence is an MTLSharedEvent with a fixed target `armed`, complete
// once the event reaches it. A fence created signaled starts at the target.
// As on D3D12, QueueSubmitDesc carries no fence, so nothing signals an
// unsignaled fence until a submit path that takes one lands.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct FenceMtl
{
	mtl::SharedEvent event;
	ulong armed;
}

fn Fence? fence_init_mtl(Device* device, bool signaled)
{
	ulong armed = 1;
	mtl::SharedEvent event = device.backend.mtl.device.new_shared_event();
	if (!event) return INITIALIZATION_FAILED~;
	if (signaled) event.set_signaled_value(armed);
	return { .backend.mtl = { .event = event, .armed = armed } };
}

fn void fence_deinit_mtl(Fence* f, Device* device)
{
	if (f.backend.mtl.event) f.backend.mtl.event.release();
	f.backend.mtl = {};
}

// Waits for every fence in turn (wait-all semantics).
fn void? fence_wait_mtl(Device* device, Fence*[] fences)
{
	foreach (f : fences) mtl_shared_event_wait(f.backend.mtl.event, f.backend.mtl.armed);
}

fn FenceStatus? fence_status_mtl(Fence* f, Device* device)
{
	return f.backend.mtl.event.signaled_value() >= f.backend.mtl.armed ? COMPLETE : INCOMPLETE;
}

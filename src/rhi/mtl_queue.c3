// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal queue. Port of the `.mtl` arm of rhi-zig's `queue.zig`, with submit
// following `QueueSubmitDesc` the way the D3D12 backend (rhi/d3d12.odin
// `queue_submit_dx12`) does.
//
// CmdMtl and CommandRingElementMtl are defined by the command and ring
// backends. The queue only owns submission-side shared-event state.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import std::thread, std::time;
import mtl;

struct QueueMtl
{
	// Borrowed from `DeviceMtl`.
	mtl::CommandQueue queue;
	// Owned (released by device_deinit_mtl). Signalled with
	// `completion_value` by every submit that carries a completion element.
	mtl::SharedEvent completion_event;
	ulong completion_value;
}

// Blocks until `event` reaches `value`. MTLSharedEvent has no blocking CPU
// wait short of a MTLSharedEventListener block callback, so poll.
fn void mtl_shared_event_wait(mtl::SharedEvent event, ulong value)
{
	if (!event || value == 0) return;
	while (event.signaled_value() < value) thread::sleep(100 * time::US);
}

// Commits a fresh command buffer and waits for it. Buffers on one queue run
// in commit order, so this drains everything committed before it. rhi-zig
// made this a no-op; this is a real wait.
fn void? queue_wait_idle_mtl(Queue* q, Device* device)
{
	mtl::CommandQueue queue = q.backend.mtl.queue;
	if (!queue) return UNKNOWN~;
	objc::@autoreleasepool()
	{
		mtl::CommandBuffer command_buffer = queue.command_buffer();
		if (!command_buffer) return UNKNOWN~;
		command_buffer.commit();
		command_buffer.wait_until_completed();
	};
}

// Commits each Cmd's command buffer in order. An event wait only holds back
// the passes encoded after it, and the Cmds are already recorded, so timeline
// waits go into a leading carrier command buffer committed first (MoltenVK
// does the same). Signals and the completion stamp go on the last buffer.
// With no Cmds the carrier alone carries waits and signals.
// Shared submit path. A drawable is optional so swapchain submission can
// schedule presentation on the last command buffer before anything commits,
// while ordinary queue_submit keeps its existing behavior.
fn void? queue_submit_mtl_internal(Queue* q, Device* device, QueueSubmitDesc desc, mtl::CAMetalDrawable present_drawable)
{
	assert(desc.binary_waits.len == 0 && desc.binary_signals.len == 0, "Metal: binary semaphores are Vulkan-only");
	QueueMtl* state = &q.backend.mtl;
	if (!state.queue) return UNKNOWN~;
	foreach (c : desc.cmds)
	{
		if (!c.backend.mtl.command_buffer) return UNKNOWN~;
	}

	objc::@autoreleasepool()
	{
		mtl::CommandBuffer carrier = null;
		if (desc.waits.len > 0 || desc.cmds.len == 0)
		{
			carrier = state.queue.command_buffer();
			if (!carrier) return UNKNOWN~;
		}
		foreach (op : desc.waits)
		{
			carrier.encode_wait_for_event(op.timeline.backend.mtl.event, op.value);
		}

		mtl::CommandBuffer last = desc.cmds.len > 0 ? desc.cmds[^1].backend.mtl.command_buffer : carrier;
		foreach (op : desc.signals)
		{
			last.encode_signal_event(op.timeline.backend.mtl.event, op.value);
		}
		ulong stamped_value = 0;
		if (desc.completion && state.completion_event)
		{
			stamped_value = ++state.completion_value;
			last.encode_signal_event(state.completion_event, stamped_value);
		}
		if (present_drawable) last.present_drawable(present_drawable.id());

		if (carrier) carrier.commit();
		foreach (c : desc.cmds) c.backend.mtl.command_buffer.commit();

		// command_ring_element_wait_mtl waits on the element.
		if (stamped_value != 0)
		{
			desc.completion.backend.mtl = { .event = state.completion_event, .value = stamped_value };
		}
	};
}

fn void? queue_submit_mtl(Queue* q, Device* device, QueueSubmitDesc desc)
{
	return queue_submit_mtl_internal(q, device, desc, null);
}

// Used only by the Metal swapchain: presentation must be encoded before the
// command buffer is committed, while retaining normal timeline and ring
// completion stamping.
fn void? queue_submit_mtl_present(Queue* q, Device* device, QueueSubmitDesc desc, mtl::CAMetalDrawable drawable)
{
	return queue_submit_mtl_internal(q, device, desc, drawable);
}

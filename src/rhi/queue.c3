// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral queue handle. Port of rhi-zig's `queue.zig`. A submit is
// described by `QueueSubmitDesc` (modeled on HPL2's `RISubmitDesc`): the
// command buffers, timeline waits/signals, Vulkan-only binary semaphores for
// swapchain acquire/present, and an optional ring element to stamp.
// WebGPU and WebGL2 expose a single ordered graphics queue.
module rhi;

struct Queue
{
	union backend
	{
		QueueVk vk;
		QueueWgpu wgpu;
		QueueWebgl webgl;
		QueueDx12 dx12;
		QueueMtl mtl;
	}
}

fn void? queue_wait_idle(Queue* q, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return queue_wait_idle_vk(q, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return queue_wait_idle_dx12(q, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return queue_wait_idle_mtl(q, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return queue_wait_idle_wgpu(q, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return queue_wait_idle_webgl(q, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

struct TimelineOp
{
	Timeline* timeline;
	ulong value;          // from timeline_next
	BarrierStages stages; // empty => all commands; ignored by D3D12/web
}

struct QueueSubmitDesc
{
	Cmd*[] cmds;
	TimelineOp[] waits;
	TimelineOp[] signals;
	// Vulkan swapchain acquire/present still needs binary semaphores; other
	// backends must receive these empty (assert).
	Semaphore*[] binary_waits;
	// Wait stage per binary_waits entry, by index. Missing entries (a
	// shorter or empty slice) and empty sets mean all commands.
	BarrierStages[] binary_wait_stages;
	Semaphore*[] binary_signals;
	CommandRingElement* completion; // nullable; stamped after a successful submit
}

fn void? queue_submit(Queue* q, Device* device, QueueSubmitDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return queue_submit_vk(q, device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return queue_submit_dx12(q, device, desc);
			$endif
		case MTL:
			$if HAS_MTL:
				return queue_submit_mtl(q, device, desc);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return queue_submit_wgpu(q, device, desc);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return queue_submit_webgl(q, device, desc);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

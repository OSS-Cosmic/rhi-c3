// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU timeline: a monotonic CPU-side counter mirrored by a
// GPU completion signal. Port of rhi-zig's `timeline.zig`, dispatched to the
// Vulkan (timeline semaphore), D3D12 (ID3D12Fence + Win32 event), WebGPU and
// WebGL2 backends. Browser timelines can only be polled with
// `timeline_completed`; `timeline_wait` is unsupported there.
module rhi;
import std::collections::list, std::collections::deque;

struct Timeline
{
	// CPU-side monotonic counter; mirrors the value last handed to a GPU submit.
	ulong signal_value;
	union backend
	{
		TimelineVk vk;
		TimelineWgpu wgpu;
		TimelineWebgl webgl;
		TimelineDx12 dx12;
		TimelineMtl mtl;
	}
}

fn Timeline? timeline_init(Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return timeline_init_vk(device);
			$endif
		case DX12:
			$if HAS_DX12:
				return timeline_init_dx12(device);
			$endif
		case MTL:
			$if HAS_MTL:
				return timeline_init_mtl(device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return timeline_init_wgpu(device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return timeline_init_webgl(device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void timeline_deinit(Timeline* t, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				timeline_deinit_vk(t, device);
			$endif
		case DX12:
			$if HAS_DX12:
				timeline_deinit_dx12(t, device);
			$endif
		case MTL:
			$if HAS_MTL:
				timeline_deinit_mtl(t, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				timeline_deinit_wgpu(t, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				timeline_deinit_webgl(t, device);
			$endif
	}
}

// Reserve the next signal value. Call immediately before the submit that signals it.
fn ulong timeline_next(Timeline* t)
{
	t.signal_value += 1;
	return t.signal_value;
}

// The highest value handed out by timeline_next — i.e. the latest in-flight submit.
fn ulong timeline_pending(Timeline* t)
{
	return t.signal_value;
}

// Query how far the GPU has actually progressed. Non-blocking; poll this in the frame loop.
fn ulong? timeline_completed(Timeline* t, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return timeline_completed_vk(t, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return timeline_completed_dx12(t, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return timeline_completed_mtl(t, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return timeline_completed_wgpu(t, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return timeline_completed_webgl(t, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

// Block until the GPU reaches value. Use at shutdown only; prefer polling timeline_completed in the frame loop.
fn void? timeline_wait(Timeline* t, Device* device, ulong value)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return timeline_wait_vk(t, device, value);
			$endif
		case DX12:
			$if HAS_DX12:
				return timeline_wait_dx12(t, device, value);
			$endif
		case MTL:
			$if HAS_MTL:
				return timeline_wait_mtl(t, device, value);
			$endif
		case WGPU:
		case WEBGL:
			// Blocking a browser task would starve the very callbacks that
			// complete the timeline (WebGPU `onSubmittedWorkDone`), and WebGL2's
			// MAX_CLIENT_WAIT_TIMEOUT_WEBGL is 0. Poll timeline_completed instead.
			return UNSUPPORTED_FEATURE~;
	}
	return UNSUPPORTED_BACKEND~;
}

// ---- deferral ----

// Per-frame deferred-release helper for the RHI.
//
// While a frame records work you `enqueue` (ref) every resource it touches
// so nothing is discarded while the GPU may still be reading it. `seal` closes
// the frame, tagging its marked items with the timeline value at which the GPU
// will be finished. Once that value has passed, `drain` releases (derefs) every
// item belonging to completed frames, oldest first — letting a finished frame
// discard its resources as quickly as possible.
//
// `items` is a FIFO of every marked item; `batches` records, per sealed frame,
// its timeline value and how many items it owns.

alias DerefFn = fn void(void*);

struct DeferralBatch
{
	ulong value;
	sz len;
}

struct DeferralItem
{
	void* data;
	DerefFn deref;
}

// Per-frame deferred-release queue. See module doc comment above.
struct TimelineDeferral
{
	List{DeferralBatch} batches;
	Deque{DeferralItem} items;
	// Items enqueued since the last `seal`, waiting to be batched.
	sz pending;
}

fn void TimelineDeferral.init(&self, Allocator allocator = mem)
{
	self.batches.init(allocator);
	self.items.init(allocator);
	self.pending = 0;
}

fn void TimelineDeferral.deinit(&self)
{
	self.batches.free();
	self.items.free();
}

fn void TimelineDeferral.enqueue(&self, void* data, DerefFn ref, DerefFn deref)
{
	ref(data);
	self.items.push({ .data = data, .deref = deref });
	self.pending++;
}

// Typed enqueue: takes `fn void(T*)` callbacks for `item: T*` and casts them
// to `fn void(void*)`.
macro void TimelineDeferral.enqueue_typed(&self, item, ref, deref)
{
	self.enqueue((void*)item, (DerefFn)ref, (DerefFn)deref);
}

fn void TimelineDeferral.seal(&self, ulong value)
{
	if (self.pending == 0) return;
	self.batches.push({ .value = value, .len = self.pending });
	self.pending = 0;
}

fn void TimelineDeferral.drain(&self, ulong value)
{
	sz drained = 0;
	while (drained < self.batches.len())
	{
		DeferralBatch batch = self.batches[drained];
		if (batch.value > value) break;
		for (sz n = 0; n < batch.len; n++)
		{
			DeferralItem item = self.items.pop_first()!!;
			item.deref(item.data);
		}
		drained++;
	}
	if (drained > 0)
	{
		sz remaining = self.batches.len() - drained;
		DeferralBatch[] view = self.batches.array_view();
		for (sz i = 0; i < remaining; i++) view[i] = view[drained + i];
		self.batches.size = remaining;
	}
}

// ---- metal ----

// Metal timeline: an MTLSharedEvent, whose signaled value is the GPU side of
// the front's monotonic counter. Submits wait on and signal it through
// encodeWaitForEvent/encodeSignalEvent (see queue.c3).
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

// ---- dx12 ----

// Direct3D 12 timeline: an ID3D12Fence whose completed value is the GPU side
// of the front's monotonic counter, plus a Win32 event for CPU waits
// (SetEventOnCompletion). Submits wait on and signal it through
// ID3D12CommandQueue::Wait/Signal (see queue.c3).
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct TimelineDx12
{
	d3d12::Fence* fence;
	dxgi::Handle event;
}

fn Timeline? timeline_init_dx12(Device* device)
{
	d3d12::Fence* fence;
	dxgi::Handle event;
	dx12_fence_create(device, 0, &fence, &event)!;
	return { .backend.dx12 = { .fence = fence, .event = event } };
}

fn void timeline_deinit_dx12(Timeline* t, Device* device)
{
	dx12_fence_destroy(t.backend.dx12.fence, t.backend.dx12.event);
	t.backend.dx12 = {};
}

fn ulong? timeline_completed_dx12(Timeline* t, Device* device)
{
	d3d12::Fence* fence = t.backend.dx12.fence;
	return fence.vtbl.get_completed_value(fence);
}

fn void? timeline_wait_dx12(Timeline* t, Device* device, ulong value)
{
	dx12_fence_wait(t.backend.dx12.fence, t.backend.dx12.event, value)!;
}

// ---- vulkan ----

// Vulkan timeline: a timeline-type VkSemaphore.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct TimelineVk
{
	vk::Semaphore semaphore;
}

fn Timeline? timeline_init_vk(Device* device)
{
	vk::SemaphoreTypeCreateInfo timeline_info = {
		.sType = SEMAPHORE_TYPE_CREATE_INFO,
		.semaphoreType = TIMELINE,
		.initialValue = 0,
	};
	vk::SemaphoreCreateInfo create_info = { .sType = SEMAPHORE_CREATE_INFO };
	vk_add_next(&create_info, &timeline_info);

	vk::Semaphore semaphore;
	vk_check(device.backend.vk.vtable.createSemaphore(device.backend.vk.device, &create_info, null, &semaphore))!;
	return { .signal_value = 0, .backend.vk = { .semaphore = semaphore } };
}

fn void timeline_deinit_vk(Timeline* t, Device* device)
{
	device.backend.vk.vtable.destroySemaphore(device.backend.vk.device, t.backend.vk.semaphore, null);
	t.backend.vk.semaphore = 0;
}

fn ulong? timeline_completed_vk(Timeline* t, Device* device)
{
	ulong value;
	vk_check(device.backend.vk.vtable.getSemaphoreCounterValue(device.backend.vk.device, t.backend.vk.semaphore, &value))!;
	return value;
}

fn void? timeline_wait_vk(Timeline* t, Device* device, ulong value)
{
	vk::SemaphoreWaitInfo wait_info = {
		.sType = SEMAPHORE_WAIT_INFO,
		.semaphoreCount = 1,
		.pSemaphores = &t.backend.vk.semaphore,
		.pValues = &value,
	};
	return vk_check(device.backend.vk.vtable.waitSemaphores(device.backend.vk.device, &wait_info, ulong::max));
}

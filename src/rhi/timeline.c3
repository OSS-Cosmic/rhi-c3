// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU timeline: a monotonic CPU-side counter mirrored by a
// GPU completion signal. Port of rhi-zig's `timeline.zig`, dispatched to the
// Vulkan (timeline semaphore), D3D12 (ID3D12Fence + Win32 event), WebGPU and
// WebGL2 backends. Browser timelines can only be polled with
// `timeline_completed`; `timeline_wait` is unsupported there.
module rhi;

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

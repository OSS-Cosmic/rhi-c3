// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU fence: a CPU-waitable one-shot signal. Port of rhi-zig's
// `fence.zig`.
//
// The browser arms are implemented inline: a browser frame cannot block on
// the GPU, WebGPU and WebGL2 expose a single ordered graphics queue, and the
// browser keeps submitted resources alive on its own (GL defers deleting
// objects until the commands referencing them retire). A fence therefore has
// nothing to carry and nothing to wait on.
module rhi;

struct FenceWgpu { char _unused; }
struct FenceWebgl { char _unused; }

struct Fence
{
	union backend
	{
		FenceVk vk;
		FenceWgpu wgpu;
		FenceWebgl webgl;
		FenceDx12 dx12;
		FenceMtl mtl;
	}
}

enum FenceStatus
{
	COMPLETE,
	INCOMPLETE,
}

fn Fence? fence_init(Device* device, bool signaled)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_init_vk(device, signaled);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_init_dx12(device, signaled);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_init_mtl(device, signaled);
			$endif
		case WGPU:
		case WEBGL:
			// Nothing to create; see the file header.
			return {};
	}
	return UNSUPPORTED_BACKEND~;
}

fn void fence_deinit(Fence* f, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				fence_deinit_vk(f, device);
			$endif
		case DX12:
			$if HAS_DX12:
				fence_deinit_dx12(f, device);
			$endif
		case MTL:
			$if HAS_MTL:
				fence_deinit_mtl(f, device);
			$endif
		case WGPU:
		case WEBGL:
			break;
	}
}

fn void? fence_wait(Device* device, Fence*[] fences)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_wait_vk(device, fences);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_wait_dx12(device, fences);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_wait_mtl(device, fences);
			$endif
		case WGPU:
		case WEBGL:
			// Cannot block a browser task; the ordered queue already sequences
			// later submits after earlier ones.
			return;
	}
	return UNSUPPORTED_BACKEND~;
}

fn FenceStatus? fence_status(Fence* f, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return fence_status_vk(f, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return fence_status_dx12(f, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return fence_status_mtl(f, device);
			$endif
		case WGPU:
		case WEBGL:
			// Resources are kept alive by the browser, so a fence is always safe
			// to treat as complete. Use a `Timeline` to observe real progress.
			return COMPLETE;
	}
	return UNSUPPORTED_BACKEND~;
}

// ---- metal ----

// Metal fence. Mirrors the D3D12 fence: a
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

// ---- dx12 ----

// Direct3D 12 fence. Mirrors the Metal fence: a one-shot fence is
// an ID3D12Fence with a fixed target `armed` (1), complete once the fence
// value reaches it. A fence created signaled starts at the target. A Win32
// event handle backs CPU waits.
//
// QueueSubmitDesc carries no fence, so nothing signals an unsignaled fence
// until a submit path that takes one lands.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct FenceDx12
{
	d3d12::Fence* fence;
	dxgi::Handle event;
	ulong armed;
}

// Creates an ID3D12Fence at `initial` plus a auto-reset event for waiting on it.
fn void? dx12_fence_create(Device* device, ulong initial, d3d12::Fence** out_fence, dxgi::Handle* out_event)
{
	d3d12::Device* dev = device.backend.dx12.device;
	Guid iid = d3d12::IID_FENCE;
	d3d12::Fence* fence;
	dx12_check(dev.vtbl.create_fence(dev, initial, d3d12::FenceFlags.NONE, &iid, (void**)&fence))!;
	dxgi::Handle event = d3d12::create_event_w(null, 0, 0, null);
	if (!event)
	{
		dxgi::release(fence);
		return INITIALIZATION_FAILED~;
	}
	*out_fence = fence;
	*out_event = event;
}

fn void dx12_fence_destroy(d3d12::Fence* fence, dxgi::Handle event)
{
	if (event) d3d12::close_handle(event);
	if (fence) dxgi::release(fence);
}

// Blocks until `fence` reaches `value`.
fn void? dx12_fence_wait(d3d12::Fence* fence, dxgi::Handle event, ulong value)
{
	if (fence.vtbl.get_completed_value(fence) >= value) return;
	dx12_check(fence.vtbl.set_event_on_completion(fence, value, event))!;
	if (d3d12::wait_for_single_object(event, d3d12::INFINITE) != d3d12::WAIT_OBJECT_0) return UNKNOWN~;
}

fn Fence? fence_init_dx12(Device* device, bool signaled)
{
	ulong armed = 1;
	d3d12::Fence* fence;
	dxgi::Handle event;
	dx12_fence_create(device, signaled ? armed : 0, &fence, &event)!;
	return { .backend.dx12 = { .fence = fence, .event = event, .armed = armed } };
}

fn void fence_deinit_dx12(Fence* f, Device* device)
{
	dx12_fence_destroy(f.backend.dx12.fence, f.backend.dx12.event);
	f.backend.dx12 = {};
}

// Waits for every fence in turn (wait-all semantics).
fn void? fence_wait_dx12(Device* device, Fence*[] fences)
{
	foreach (f : fences) dx12_fence_wait(f.backend.dx12.fence, f.backend.dx12.event, f.backend.dx12.armed)!;
}

fn FenceStatus? fence_status_dx12(Fence* f, Device* device)
{
	d3d12::Fence* fence = f.backend.dx12.fence;
	return fence.vtbl.get_completed_value(fence) >= f.backend.dx12.armed ? COMPLETE : INCOMPLETE;
}

// ---- vulkan ----

// Vulkan fence. Vulkan fence section.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct FenceVk
{
	vk::Fence fence;
}

fn Fence? fence_init_vk(Device* device, bool signaled)
{
	vk::FenceCreateFlags flags;
	if (signaled) flags = vk::FENCE_CREATE_SIGNALED_BIT;
	vk::FenceCreateInfo create_info = {
		.sType = FENCE_CREATE_INFO,
		.flags = flags,
	};
	vk::Fence fence;
	vk_check(device.backend.vk.vtable.createFence(device.backend.vk.device, &create_info, null, &fence))!;
	return { .backend.vk = { .fence = fence } };
}

fn void fence_deinit_vk(Fence* f, Device* device)
{
	device.backend.vk.vtable.destroyFence(device.backend.vk.device, f.backend.vk.fence, null);
	f.backend.vk.fence = 0;
}

fn void? fence_wait_vk(Device* device, Fence*[] fences)
{
	assert(fences.len <= 16);
	vk::Fence[16] vk_fences;
	foreach (i, f : fences)
	{
		vk_fences[i] = f.backend.vk.fence;
	}
	return vk_check(device.backend.vk.vtable.waitForFences(device.backend.vk.device, (uint)fences.len, &vk_fences, vk::TRUE, ulong::max));
}

fn FenceStatus? fence_status_vk(Fence* f, Device* device)
{
	vk::Result r = device.backend.vk.vtable.getFenceStatus(device.backend.vk.device, f.backend.vk.fence);
	switch (r)
	{
		case vk::Result.SUCCESS:
			return COMPLETE;
		case vk::Result.NOT_READY:
			return INCOMPLETE;
		default:
			// A C3 optional carries only the fault; `.Incomplete` is dropped.
			vk_check(r)!;
			return INCOMPLETE;
	}
}

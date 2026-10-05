// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan fence, binary semaphore and timeline. Port of the `---- fence ----`,
// `---- semaphore ----` and `---- timeline ----` sections of rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

// ---- fence ----

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
			// Odin returns `.Incomplete` beside the error; C3 drops it.
			vk_check(r)!;
			return INCOMPLETE;
	}
}

// ---- semaphore ----

struct SemaphoreVk
{
	vk::Semaphore semaphore;
}

fn Semaphore? semaphore_init_vk(Device* device)
{
	vk::SemaphoreCreateInfo create_info = { .sType = SEMAPHORE_CREATE_INFO };
	vk::Semaphore semaphore;
	vk_check(device.backend.vk.vtable.createSemaphore(device.backend.vk.device, &create_info, null, &semaphore))!;
	return { .backend.vk = { .semaphore = semaphore } };
}

fn void semaphore_deinit_vk(Semaphore* s, Device* device)
{
	device.backend.vk.vtable.destroySemaphore(device.backend.vk.device, s.backend.vk.semaphore, null);
	s.backend.vk.semaphore = 0;
}

// ---- timeline ----

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

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan command-ring storage and synchronization. Port of the command-ring
// section of rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct CommandRingElementVk
{
	vk::Semaphore semaphore;
	vk::Fence fence;
}

struct CommandRingBufferVk <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	vk::Fence[CMD_PER_POOL][POOL_COUNT] fences;
	vk::Semaphore[CMD_PER_POOL][POOL_COUNT] semaphores;
}

fn void? command_ring_element_wait_vk(CommandRingElement* e, Device* device)
{
	if (e == null || e.backend.vk.fence == 0) return;
	vk::Fence fence = e.backend.vk.fence;
	return vk_check(device.backend.vk.vtable.waitForFences(
		device.backend.vk.device, 1, &fence, vk::TRUE, ulong::max));
}

// Called as `command_ring_buffer_init_vk{POOL_COUNT, CMD_PER_POOL,
// SYNC_PRIMITIVE}(device, queue)`.
fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init_vk(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} result = {};
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		result.pools[pool_index] = pool_init_vk(device, queue)!;
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			result.cmds[pool_index][cmd_index] = cmd_init_vk(device, &result.pools[pool_index])!;
			$if SYNC_PRIMITIVE:
				vk::SemaphoreCreateInfo semaphore_info = { .sType = SEMAPHORE_CREATE_INFO };
				vk_check(device.backend.vk.vtable.createSemaphore(
					device.backend.vk.device, &semaphore_info, null,
					&result.backend.vk.semaphores[pool_index][cmd_index]))!;
				vk::FenceCreateInfo fence_info = {
					.sType = FENCE_CREATE_INFO,
					.flags = vk::FENCE_CREATE_SIGNALED_BIT,
				};
				vk_check(device.backend.vk.vtable.createFence(
					device.backend.vk.device, &fence_info, null,
					&result.backend.vk.fences[pool_index][cmd_index]))!;
			$endif
		}
	}
	// The first get uses the last initialized pool, matching the Odin ring.
	result.pool_index = POOL_COUNT - 1;
	result.cmd_index = 0;
	result.fence_index = 0;
	return result;
}

fn void command_ring_buffer_deinit_vk(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		$if SYNC_PRIMITIVE:
			for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
			{
				device.backend.vk.vtable.destroySemaphore(
					device.backend.vk.device, r.backend.vk.semaphores[pool_index][cmd_index], null);
				device.backend.vk.vtable.destroyFence(
					device.backend.vk.device, r.backend.vk.fences[pool_index][cmd_index], null);
			}
		$endif
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			cmd_deinit(&r.cmds[pool_index][cmd_index], device, &r.pools[pool_index]);
		}
		pool_deinit_vk(&r.pools[pool_index], device);
	}
	*r = {};
}

fn CommandRingElement command_ring_buffer_get_vk(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	(void)device;
	assert(r.pool_index < POOL_COUNT, "Vulkan: command ring must be advanced before get");
	assert(num_cmds > 0 && num_cmds <= CMD_PER_POOL - r.cmd_index,
		"Vulkan: command ring command range exhausted");
	CommandRingElement result = {
		.cmds = r.cmds[r.pool_index][r.cmd_index : num_cmds],
		.pool = &r.pools[r.pool_index],
	};
	$if SYNC_PRIMITIVE:
		result.backend.vk = {
			.semaphore = r.backend.vk.semaphores[r.pool_index][r.fence_index],
			.fence = r.backend.vk.fences[r.pool_index][r.fence_index],
		};
	$endif
	r.fence_index += 1;
	r.cmd_index += num_cmds;
	return result;
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan command-pool management. Port of the pool section of
// rhi/vulkan.odin.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct PoolVk
{
	Queue* queue;
	vk::CommandPool pool;
}

fn Pool? pool_init_vk(Device* device, Queue* queue)
{
	vk::CommandPoolCreateInfo info = {
		.sType = vk::StructureType.COMMAND_POOL_CREATE_INFO,
		.flags = vk::COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
		.queueFamilyIndex = queue.backend.vk.family_index,
	};
	vk::CommandPool command_pool;
	vk_check(device.backend.vk.vtable.createCommandPool(device.backend.vk.device, &info, null, &command_pool))!;
	return { .backend.vk = { .queue = queue, .pool = command_pool } };
}

fn void? pool_reset_vk(Pool* pool, Device* device)
{
	return vk_check(device.backend.vk.vtable.resetCommandPool(device.backend.vk.device, pool.backend.vk.pool, 0));
}

fn void pool_deinit_vk(Pool* pool, Device* device)
{
	device.backend.vk.vtable.destroyCommandPool(device.backend.vk.device, pool.backend.vk.pool, null);
}

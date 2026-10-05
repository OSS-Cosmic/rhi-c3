// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal command-ring storage. A ring element is stamped by queue submission
// with the queue's shared event; waiting it before pool reuse provides the
// same lifetime boundary as a Vulkan fence.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct CommandRingElementMtl
{
	// Borrowed from QueueMtl.
	mtl::SharedEvent event;
	ulong value;
}

struct CommandRingBufferMtl <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	char _unused;
}

fn void? command_ring_element_wait_mtl(CommandRingElement* e, Device* device)
{
	if (e == null || !e.backend.mtl.event || e.backend.mtl.value == 0) return;
	mtl_shared_event_wait(e.backend.mtl.event, e.backend.mtl.value);
	return;
}

// Called as `command_ring_buffer_init_mtl{POOL_COUNT, CMD_PER_POOL,
// SYNC_PRIMITIVE}(device, queue)`.
fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init_mtl(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} result = {
		.pool_index = POOL_COUNT,
		.cmd_index = 0,
		.fence_index = 0,
	};
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		result.pools[pool_index] = pool_init_mtl(device, queue)!;
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			result.cmds[pool_index][cmd_index] = cmd_init_mtl(device, &result.pools[pool_index])!;
		}
	}
	return result;
}

fn void command_ring_buffer_deinit_mtl(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			cmd_deinit(&r.cmds[pool_index][cmd_index], device, &r.pools[pool_index]);
		}
		pool_deinit_mtl(&r.pools[pool_index], device);
	}
	*r = {};
}

fn CommandRingElement command_ring_buffer_get_mtl(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	assert(r.pool_index < POOL_COUNT, "Metal: command ring must be advanced before get");
	assert(num_cmds > 0 && num_cmds <= CMD_PER_POOL - r.cmd_index, "Metal: command ring command range exhausted");
	CommandRingElement result = {
		.cmds = r.cmds[r.pool_index][r.cmd_index .. r.cmd_index + num_cmds],
		.pool = &r.pools[r.pool_index],
		.backend.mtl = {},
	};
	r.cmd_index += num_cmds;
	return result;
}

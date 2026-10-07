// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral command ring. Port of rhi-zig's `cmd.zig`
// `CommandRingElement` and `CommandRingBuffer`, dispatched to the Vulkan,
// WebGPU and WebGL2 backends.
//
// The `CommandRingElement*` / `CommandRingBuffer*` stand-ins for backends that
// are not compiled in live in backend_stubs.c3.
module rhi;

struct CommandRingElement
{
	Cmd[] cmds;
	Pool* pool;
	union backend
	{
		CommandRingElementVk vk;
		CommandRingElementDx12 dx12;
		CommandRingElementMtl mtl;
		CommandRingElementWgpu wgpu;
		CommandRingElementWebgl webgl;
	}
}

fn void? command_ring_element_wait(CommandRingElement* e, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return command_ring_element_wait_vk(e, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return command_ring_element_wait_dx12(e, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return command_ring_element_wait_mtl(e, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return command_ring_element_wait_wgpu(e, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return command_ring_element_wait_webgl(e, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

struct CommandRingBuffer <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	sz pool_index;
	sz cmd_index;
	sz fence_index;
	Pool[POOL_COUNT] pools;
	// Indexed `cmds[pool][cmd]`.
	Cmd[CMD_PER_POOL][POOL_COUNT] cmds;
	union backend
	{
		CommandRingBufferVk{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} vk;
		CommandRingBufferDx12{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} dx12;
		CommandRingBufferMtl{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} mtl;
		CommandRingBufferWgpu{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} wgpu;
		CommandRingBufferWebgl{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} webgl;
	}
}

// Called as `command_ring_buffer_init{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue)`.
fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return command_ring_buffer_init_vk{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue);
			$endif
		case DX12:
			$if HAS_DX12:
				return command_ring_buffer_init_dx12{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue);
			$endif
		case MTL:
			$if HAS_MTL:
				return command_ring_buffer_init_mtl{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return command_ring_buffer_init_wgpu{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return command_ring_buffer_init_webgl{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}(device, queue);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void command_ring_buffer_deinit(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				command_ring_buffer_deinit_vk(r, device);
			$endif
		case DX12:
			$if HAS_DX12:
				command_ring_buffer_deinit_dx12(r, device);
			$endif
		case MTL:
			$if HAS_MTL:
				command_ring_buffer_deinit_mtl(r, device);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				command_ring_buffer_deinit_wgpu(r, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				command_ring_buffer_deinit_webgl(r, device);
			$endif
	}
}

// Advance to the next command slot.
fn void CommandRingBuffer.advance(&self)
{
	self.pool_index = (self.pool_index + 1) % (sz)POOL_COUNT;
	self.cmd_index = 0;
	self.fence_index = 0;
}

fn CommandRingElement command_ring_buffer_get(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return command_ring_buffer_get_vk(r, device, num_cmds);
			$endif
		case DX12:
			$if HAS_DX12:
				return command_ring_buffer_get_dx12(r, device, num_cmds);
			$endif
		case MTL:
			$if HAS_MTL:
				return command_ring_buffer_get_mtl(r, device, num_cmds);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return command_ring_buffer_get_wgpu(r, device, num_cmds);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return command_ring_buffer_get_webgl(r, device, num_cmds);
			$endif
	}
	return {};
}

// ---- metal ----

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

// ---- dx12 ----

// Direct3D 12 command-ring storage. A ring element is stamped by queue
// submission with the queue's completion fence and the value signalled behind
// the submit; waiting it before pool reset provides the same lifetime boundary
// as a Vulkan fence.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct CommandRingElementDx12
{
	// Borrowed from QueueDx12.
	d3d12::Fence* fence;
	dxgi::Handle event;
	ulong value;
}

struct CommandRingBufferDx12 <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	char _unused;
}

fn void? command_ring_element_wait_dx12(CommandRingElement* e, Device* device)
{
	if (e == null || !e.backend.dx12.fence || e.backend.dx12.value == 0) return;
	return dx12_fence_wait(e.backend.dx12.fence, e.backend.dx12.event, e.backend.dx12.value);
}

// Called as `command_ring_buffer_init_dx12{POOL_COUNT, CMD_PER_POOL,
// SYNC_PRIMITIVE}(device, queue)`.
fn CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}? command_ring_buffer_init_dx12(Device* device, Queue* queue) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE} result = {};
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		result.pools[pool_index] = pool_init_dx12(device, queue)!;
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			result.cmds[pool_index][cmd_index] = cmd_init(device, &result.pools[pool_index])!;
		}
	}
	// The first get uses the last initialized pool, matching the Vulkan ring.
	result.pool_index = POOL_COUNT - 1;
	result.cmd_index = 0;
	result.fence_index = 0;
	return result;
}

fn void command_ring_buffer_deinit_dx12(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	for (sz pool_index = 0; pool_index < POOL_COUNT; pool_index++)
	{
		for (sz cmd_index = 0; cmd_index < CMD_PER_POOL; cmd_index++)
		{
			cmd_deinit(&r.cmds[pool_index][cmd_index], device, &r.pools[pool_index]);
		}
		pool_deinit_dx12(&r.pools[pool_index], device);
	}
	*r = {};
}

fn CommandRingElement command_ring_buffer_get_dx12(CommandRingBuffer{POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE}* r, Device* device, sz num_cmds) <POOL_COUNT, CMD_PER_POOL, SYNC_PRIMITIVE>
{
	(void)device;
	assert(r.pool_index < POOL_COUNT, "D3D12: command ring must be advanced before get");
	assert(num_cmds > 0 && num_cmds <= CMD_PER_POOL - r.cmd_index,
		"D3D12: command ring command range exhausted");
	CommandRingElement result = {
		.cmds = r.cmds[r.pool_index][r.cmd_index : num_cmds],
		.pool = &r.pools[r.pool_index],
		.backend.dx12 = {},
	};
	r.fence_index += 1;
	r.cmd_index += num_cmds;
	return result;
}

// ---- vulkan ----

// Vulkan command-ring storage and synchronization.
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
	// The first get uses the last initialized pool.
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

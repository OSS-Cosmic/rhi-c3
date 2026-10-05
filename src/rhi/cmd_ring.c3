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

// Odin's `command_ring_buffer_advance`.
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

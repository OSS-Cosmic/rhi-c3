// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral buffer. Port of the Vulkan arm of rhi-zig's `buffer.zig`
// `Buffer` type.
module rhi;

enum BufferUsageFlag : char
{
	SHADER_RESOURCE,
	SHADER_RESOURCE_STORAGE,
	TRANSFER_SRC,
	TRANSFER_DST,
	INDIRECT,
	DEVICE_ADDRESS,
	VERTEX_BUFFER,
	INDEX_BUFFER,
	CONSTANT_BUFFER,
	ARGUMENT_BUFFER,
	SCRATCH_BUFFER,
	SHADER_BINDING_TABLE,
	ACCELERATION_STRUCTURE_BUILD_INPUT,
	ACCELERATION_STRUCTURE_STORAGE,
	MICROMAP_BUILD_INPUT,
	MICROMAP_STORAGE,
}

bitstruct BufferUsage : ushort
{
	bool shader_resource : 0;
	bool shader_resource_storage : 1;
	bool transfer_src : 2;
	bool transfer_dst : 3;
	bool indirect : 4;
	bool device_address : 5;
	bool vertex_buffer : 6;
	bool index_buffer : 7;
	bool constant_buffer : 8;
	bool argument_buffer : 9;
	bool scratch_buffer : 10;
	bool shader_binding_table : 11;
	bool acceleration_structure_build_input : 12;
	bool acceleration_structure_storage : 13;
	bool micromap_build_input : 14;
	bool micromap_storage : 15;
}

enum BufferMemoryUsage : char
{
	AUTO,
	PREFER_DEVICE,
	PREFER_HOST,
	// Host-readable buffer for GPU-to-CPU copies. Host-visible and
	// host-cached on Vulkan (always mapped), HEAP_TYPE_READBACK on D3D12
	// (always mapped), and the same as Prefer_Host on web.
	READBACK,
}

// Note: rhi-zig defaults transfer_src/transfer_dst to true, but this port
// requires the caller to set them explicitly.
struct BufferDesc
{
	sz size;
	sz stride;
	bool persistent_map;
	bool sequential_access;
	BufferUsage usage;
	BufferMemoryUsage buffer_usage;
}

struct Buffer
{
	ulong cookie;
	char[] mapped_region;
	union backend
	{
		BufferVk vk;
		BufferDx12 dx12;
		BufferWgpu wgpu;
		BufferWebgl webgl;
		BufferMtl mtl;
	}
}

fn Buffer? buffer_init_general(Device* device, BufferDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return buffer_init_general_vk(device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return buffer_init_general_dx12(device, desc);
			$endif
		case MTL:
			$if HAS_MTL:
				return buffer_init_general_mtl(device, desc);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return buffer_init_general_wgpu(device, desc);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return buffer_init_general_webgl(device, desc);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void buffer_deinit(Buffer* b, Device* device)
{
	if (b.cookie == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				buffer_deinit_vk(b, device);
			$endif
		case DX12:
			$if HAS_DX12:
				buffer_deinit_dx12(b, device);
			$endif
		case MTL:
			$if HAS_MTL:
				buffer_deinit_mtl(b, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				buffer_deinit_wgpu(b, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				buffer_deinit_webgl(b, device);
			$endif
	}
	// All backends share this guard, making deinit idempotent at the RHI layer
	// and ensuring the handle and its optional shadow have one owner.
	b.cookie = 0;
	b.mapped_region = {};
}

fn bool buffer_is_empty(Buffer* b)
{
	return b.cookie == 0;
}

// Per-frame write path. Vulkan copies into the persistent mapping. On web
// backends it writes into the wasm shadow if one exists (pushed later by
// buffer_flush), otherwise it issues a queue write directly. WebGPU's
// queue.writeBuffer is ordered before later submits; WebGL's bufferSubData
// runs immediately, ahead of the deferred command replay at submit.
//
// The direct WebGPU path requires offset and length to be multiples of 4, and
// the buffer must have been created with `.Transfer_Dst` (or persistent_map),
// since wgpu_buffer_usage only adds COPY_DST in those cases.
fn void buffer_write(Buffer* b, Device* device, sz offset, char[] bytes)
{
	if (bytes.len == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				buffer_write_vk(b, device, offset, bytes);
				return;
			$endif
		case DX12:
			break;
		case MTL:
			// Private (PREFER_DEVICE) Metal buffers have no host mapping; they
			// must be filled with a blit instead.
			if (b.mapped_region.ptr == null)
			{
				log::error("buffer_write: unsupported on a Private Metal buffer (fill it with a blit)");
				return;
			}
		case WGPU:
			$if HAS_WGPU:
				buffer_write_wgpu(b, device, offset, bytes);
				return;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				buffer_write_webgl(b, device, offset, bytes);
				return;
			$endif
	}
	if (b.mapped_region.ptr == null)
	{
		abort("buffer_write: buffer has no host mapping (create it with persistent_map)");
	}
	sz region_len = (sz)b.mapped_region.len;
	if (offset < 0 || offset > region_len || (sz)bytes.len > region_len - offset)
	{
		abort("buffer_write: range is outside the buffer");
	}
	b.mapped_region[offset : bytes.len] = bytes[..];
}

struct MappedMemoryRange
{
	sz offset;
	Buffer* buffer;
	char[] memory_range;
}

fn bool mapped_memory_range_is_empty(MappedMemoryRange* m)
{
	return m.memory_range.len == 0;
}

fn MappedMemoryRange? buffer_get_mapped_region(Buffer* b, sz offset, sz size)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return buffer_get_mapped_region_vk(b, offset, size);
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	if (b.mapped_region.ptr == null) return BUFFER_NOT_MAPPED~;
	sz region_len = (sz)b.mapped_region.len;
	if (offset < 0 || size < 0 || offset > region_len || size > region_len - offset)
	{
		return UNSUPPORTED_FEATURE~;
	}
	return { .offset = offset, .buffer = b, .memory_range = b.mapped_region[offset : size] };
}

// Validates a browser buffer size and narrows it to the u32 the JS bridge
// takes. `max_size` is the backend limit (WGPU_MAX_BUFFER_SIZE or
// WEBGL_MAX_BUFFER_SIZE).
fn uint? web_buffer_size(sz size, ulong max_size)
{
	if (size <= 0 || (ulong)size > max_size) return UNSUPPORTED_FEATURE~;
	return (uint)size;
}

// Validates a buffer_write range on web backends that write straight to the
// GPU buffer. `align` is the required offset/length multiple (4 for WebGPU
// queue.writeBuffer, 1 otherwise).
fn void? web_buffer_write_range(sz offset, sz length, sz size, sz align)
{
	if (offset < 0 || length < 0 || offset > size || length > size - offset)
	{
		return UNSUPPORTED_FEATURE~;
	}
	if (align > 1 && (offset % align != 0 || length % align != 0))
	{
		return UNSUPPORTED_FEATURE~;
	}
}

// Push host writes to the GPU buffer. Vulkan's mapping is already visible and
// Metal shared memory is coherent, so neither has work here.
//
// On web backends `mapped_region` is a wasm-memory shadow, so this must be
// called after host writes and before any submit that reads the buffer.
// WebGPU uses queue.writeBuffer, which is ordered before later submits;
// WebGL issues bufferSubData immediately, ahead of the deferred command
// replay at submit.
fn void buffer_flush(Buffer* b, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				buffer_flush_vk(b, device);
			$endif
			break;
		case DX12:
		case MTL:
			break;
		case WGPU:
			$if HAS_WGPU:
				buffer_flush_wgpu(b, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				buffer_flush_webgl(b, device);
			$endif
	}
}

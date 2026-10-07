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

// ---- metal ----

// Metal buffer. Port of the `.mtl` arms of rhi-zig's `buffer.zig`
// `initGeneral`/`deinit`.
//
// Shared storage is CPU-visible and always mapped, so `mapped_region` points
// straight at the buffer's contents (no staging/blit needed on Apple Silicon).
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct BufferMtl
{
	// Owned: +1 from -newBufferWithLength:options:.
	mtl::Buffer buffer;
	ulong size;
	bool shared;
}

fn Buffer? buffer_init_general_mtl(Device* device, BufferDesc desc)
{
	if (desc.size <= 0) return UNSUPPORTED_FEATURE~;
	if ((ulong)desc.size > device.adapter.buffer_max_size) return UNSUPPORTED_FEATURE~;
	// rhi-zig always uses StorageModeShared. Extension: PREFER_DEVICE maps to
	// StorageModePrivate (GPU-only, no host mapping; fill it with a blit).
	bool shared = desc.buffer_usage != PREFER_DEVICE;
	mtl::ResourceOptions options = shared ? mtl::RESOURCE_STORAGE_MODE_SHARED : mtl::RESOURCE_STORAGE_MODE_PRIVATE;
	mtl::Buffer buffer = device.backend.mtl.device.new_buffer((NSUInteger)desc.size, options);
	if (!buffer) return OUT_OF_DEVICE_MEMORY~;
	char[] mapped_region;
	if (shared)
	{
		char* contents = (char*)buffer.contents();
		if (contents)
		{
			mapped_region = contents[:desc.size];
		}
		else
		{
			buffer.release();
			return INITIALIZATION_FAILED~;
		}
	}
	return {
		.cookie = next_cookie(),
		.mapped_region = mapped_region,
		.backend.mtl = { .buffer = buffer, .size = (ulong)desc.size, .shared = shared },
	};
}

fn void buffer_deinit_mtl(Buffer* b, Device* device)
{
	if (b.backend.mtl.buffer) b.backend.mtl.buffer.release();
	b.backend.mtl = {};
}

// ---- dx12 ----

// Direct3D 12 buffer. Port of the `.dx12` arms of rhi-zig's `buffer.zig`
// `initGeneral`/`deinit`: a committed-or-placed buffer resource from
// D3D12MemoryAllocator in a DEFAULT, UPLOAD or READBACK heap. CPU-visible
// heaps are persistently mapped and exposed through `Buffer.mapped_region`.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi, d3d12ma;

struct BufferDx12
{
	// Owned: frees the underlying resource too.
	d3d12ma::Allocation allocation;
	// Borrowed from `allocation`.
	d3d12::Resource* resource;
	d3d12::GpuVirtualAddress gpu_address;
	d3d12::HeapType heap_type;
	// The state the resource was created in.
	d3d12::ResourceStates initial_state;
	ulong size;
	// Persistent CPU mapping, or null for DEFAULT heap buffers.
	void* mapped;
}

fn d3d12::HeapType buffer_heap_type_dx12(BufferDesc desc) @private
{
	switch (desc.buffer_usage)
	{
		case READBACK: return d3d12::HeapType.READBACK;
		case PREFER_HOST: return d3d12::HeapType.UPLOAD;
		case AUTO:
		case PREFER_DEVICE:
			// A persistent mapping needs a CPU-visible heap.
			return desc.persistent_map ? d3d12::HeapType.UPLOAD : d3d12::HeapType.DEFAULT;
	}
}

fn Buffer? buffer_init_general_dx12(Device* device, BufferDesc desc)
{
	if (desc.size <= 0) return UNSUPPORTED_FEATURE~;
	if ((ulong)desc.size > device.adapter.buffer_max_size) return UNSUPPORTED_FEATURE~;

	d3d12::HeapType heap_type = buffer_heap_type_dx12(desc);
	// UPLOAD heaps must be created GENERIC_READ and READBACK heaps COPY_DEST;
	// neither can transition.
	d3d12::ResourceStates initial_state = d3d12::RESOURCE_STATE_COMMON;
	if (heap_type == d3d12::HeapType.UPLOAD)
	{
		initial_state = d3d12::RESOURCE_STATE_GENERIC_READ;
	}
	else if (heap_type == d3d12::HeapType.READBACK)
	{
		initial_state = d3d12::RESOURCE_STATE_COPY_DEST;
	}
	else if (desc.usage.acceleration_structure_storage)
	{
		initial_state = d3d12::RESOURCE_STATE_RAYTRACING_ACCELERATION_STRUCTURE;
	}

	// UAV access is only legal on DEFAULT heap resources.
	d3d12::ResourceFlags flags = d3d12::RESOURCE_FLAG_NONE;
	if (heap_type == d3d12::HeapType.DEFAULT
		&& (desc.usage.shader_resource_storage || desc.usage.scratch_buffer || desc.usage.acceleration_structure_storage))
	{
		flags |= d3d12::RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
	}

	d3d12::ResourceDesc resource_desc = {
		.dimension = d3d12::ResourceDimension.BUFFER,
		.alignment = 0,
		.width = (ulong)desc.size,
		.height = 1,
		.depth_or_array_size = 1,
		.mip_levels = 1,
		.format = dxgi::Format.UNKNOWN,
		.sample_desc = { .count = 1, .quality = 0 },
		.layout = d3d12::TextureLayout.ROW_MAJOR,
		.flags = flags,
	};
	d3d12ma::AllocationDesc alloc_desc = { .heap_type = (int)heap_type };

	d3d12ma::Allocation allocation;
	int hr = d3d12ma::create_resource(device.backend.dx12.allocator, &alloc_desc, &resource_desc, (uint)initial_state, null, &allocation, null);
	if (hr < 0 || !allocation) return OUT_OF_DEVICE_MEMORY~;

	d3d12::Resource* resource = (d3d12::Resource*)d3d12ma::allocation_get_resource(allocation);
	void* mapped;
	char[] mapped_region;
	if (heap_type != d3d12::HeapType.DEFAULT)
	{
		// READBACK is read by the CPU; UPLOAD is write-only (empty read range).
		ulong read_end = heap_type == d3d12::HeapType.READBACK ? (ulong)desc.size : 0;
		if (d3d12ma::map(allocation, 0, read_end, &mapped) < 0 || !mapped)
		{
			d3d12ma::free_allocation(allocation);
			return INITIALIZATION_FAILED~;
		}
		mapped_region = ((char*)mapped)[:desc.size];
	}
	return {
		.cookie = next_cookie(),
		.mapped_region = mapped_region,
		.backend.dx12 = {
			.allocation = allocation,
			.resource = resource,
			.gpu_address = resource.vtbl.get_gpu_virtual_address(resource),
			.heap_type = heap_type,
			.initial_state = initial_state,
			.size = (ulong)desc.size,
			.mapped = mapped,
		},
	};
}

fn void buffer_deinit_dx12(Buffer* b, Device* device)
{
	BufferDx12* state = &b.backend.dx12;
	if (state.allocation)
	{
		if (state.mapped) d3d12ma::unmap(state.allocation, 0, 0);
		d3d12ma::free_allocation(state.allocation);
	}
	*state = {};
}

// ---- vulkan ----

// Vulkan buffers backed by VMA.; host-visible allocations expose their mapped bytes through
// the front Buffer.mapped_region slice.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk, vma;

struct BufferVk
{
	vk::Buffer buffer;
	vma::Allocation allocation;
	ulong size;
}

fn vk::BufferUsageFlags buffer_usage_flags_vk(Device* device, BufferDesc desc) @private
{
	vk::BufferUsageFlags usage;
	if (desc.usage.device_address || device.adapter.backend.vk.is_buffer_device_address_supported) {
		usage |= vk::BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;
	}
	if (desc.usage.transfer_dst) usage |= vk::BUFFER_USAGE_TRANSFER_DST_BIT;
	if (desc.usage.transfer_src) usage |= vk::BUFFER_USAGE_TRANSFER_SRC_BIT;
	if (desc.usage.vertex_buffer) usage |= vk::BUFFER_USAGE_VERTEX_BUFFER_BIT;
	if (desc.usage.index_buffer) usage |= vk::BUFFER_USAGE_INDEX_BUFFER_BIT;
	if (desc.usage.constant_buffer) usage |= vk::BUFFER_USAGE_UNIFORM_BUFFER_BIT;
	if (desc.usage.argument_buffer || desc.usage.indirect) usage |= vk::BUFFER_USAGE_INDIRECT_BUFFER_BIT;
	if (desc.usage.scratch_buffer) usage |= vk::BUFFER_USAGE_STORAGE_BUFFER_BIT;
	if (desc.usage.shader_binding_table) usage |= vk::BUFFER_USAGE_SHADER_BINDING_TABLE_BIT_KHR;
	if (desc.usage.acceleration_structure_storage) usage |= vk::BUFFER_USAGE_ACCELERATION_STRUCTURE_STORAGE_BIT_KHR;
	if (desc.usage.acceleration_structure_build_input) usage |= vk::BUFFER_USAGE_ACCELERATION_STRUCTURE_BUILD_INPUT_READ_ONLY_BIT_KHR;
	if (desc.usage.micromap_storage) usage |= vk::BUFFER_USAGE_MICROMAP_STORAGE_BIT_EXT;
	if (desc.usage.micromap_build_input) usage |= vk::BUFFER_USAGE_MICROMAP_BUILD_INPUT_READ_ONLY_BIT_EXT;
	if (desc.stride == 0 || desc.stride == 4)
	{
		if (desc.usage.shader_resource) usage |= vk::BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT;
		if (desc.usage.shader_resource_storage) usage |= vk::BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT;
	}
	if (desc.stride > 0)
	{
		usage |= vk::BUFFER_USAGE_STORAGE_BUFFER_BIT;
	}
	return usage;
}

fn vma::AllocationCreateInfo buffer_allocation_info_vk(BufferDesc desc) @private
{
	vma::AllocationCreateInfo info = {};
	switch (desc.buffer_usage)
	{
		case AUTO: info.usage = vma::MemoryUsage.AUTO;
		case PREFER_DEVICE: info.usage = vma::MemoryUsage.AUTO_PREFER_DEVICE;
		case PREFER_HOST: info.usage = vma::MemoryUsage.AUTO_PREFER_HOST;
		case READBACK:
			info.usage = vma::MemoryUsage.AUTO_PREFER_HOST;
			info.flags |= vma::ALLOCATION_CREATE_HOST_ACCESS_RANDOM_BIT;
			info.flags |= vma::ALLOCATION_CREATE_MAPPED_BIT;
	}
	if (desc.persistent_map && desc.buffer_usage != READBACK)
	{
		info.flags |= desc.sequential_access
			? vma::ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT
			: vma::ALLOCATION_CREATE_HOST_ACCESS_RANDOM_BIT;
		info.flags |= vma::ALLOCATION_CREATE_MAPPED_BIT;
	}
	return info;
}

fn Buffer? buffer_init_general_vk(Device* device, BufferDesc desc)
{
	if (desc.size <= 0) return UNSUPPORTED_FEATURE~;
	vk::BufferCreateInfo create_info = {
		.sType = vk::StructureType.BUFFER_CREATE_INFO,
		.size = (vk::DeviceSize)desc.size,
		.usage = buffer_usage_flags_vk(device, desc),
		.sharingMode = vk::SharingMode.EXCLUSIVE,
	};
	vma::AllocationCreateInfo allocation_info = buffer_allocation_info_vk(desc);
	vk::Buffer buffer;
	vma::Allocation allocation;
	vma::AllocationInfo vma_info;
	vk::Result result = vma::create_buffer(device.backend.vk.vma_allocator, &create_info, &allocation_info, &buffer, &allocation, &vma_info);
	vk_check(result)!;

	char[] mapped_region;
	if (vma_info.mapped_data != null) {
		mapped_region = ((char*)vma_info.mapped_data)[:desc.size];
	}
	return {
		.cookie = next_cookie(),
		.mapped_region = mapped_region,
		.backend.vk = { .buffer = buffer, .allocation = allocation, .size = (ulong)desc.size },
	};
}

fn void buffer_deinit_vk(Buffer* b, Device* device)
{
	if (b.backend.vk.allocation != null) {
		vma::destroy_buffer(device.backend.vk.vma_allocator, b.backend.vk.buffer, b.backend.vk.allocation);
	}
	b.backend.vk = {};
}

// These helpers are dispatched by the front buffer API. The VMA mapping is
// already the authoritative host region, and VMA handles the allocation's
// coherency policy for this backend.
fn void buffer_write_vk(Buffer* b, Device* device, sz offset, char[] bytes)
{
	(void)device;
	if (b.mapped_region.ptr == null)
	{
		abort("buffer_write: buffer has no host mapping (create it with persistent_map)");
	}
	sz region_len = (sz)b.mapped_region.len;
	if (offset < 0 || offset > region_len || (sz)bytes.len > region_len - offset) {
		abort("buffer_write: range is outside the buffer");
	}
	b.mapped_region[offset : bytes.len] = bytes[..];
}

fn MappedMemoryRange? buffer_get_mapped_region_vk(Buffer* b, sz offset, sz size)
{
	if (b.mapped_region.ptr == null) return BUFFER_NOT_MAPPED~;
	sz region_len = (sz)b.mapped_region.len;
	if (offset < 0 || size < 0 || offset > region_len || size > region_len - offset) {
		return UNSUPPORTED_FEATURE~;
	}
	return { .offset = offset, .buffer = b, .memory_range = b.mapped_region[offset : size] };
}

fn void buffer_flush_vk(Buffer* b, Device* device)
{
	(void)b;
	(void)device;
}

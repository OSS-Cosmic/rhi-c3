// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan buffers backed by VMA. Port of the buffer arm in
// rhi/vulkan.odin; host-visible allocations expose their mapped bytes through
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

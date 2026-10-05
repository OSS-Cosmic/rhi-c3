// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Frame-aware Vulkan descriptor-set allocation. Port of the allocator section
// in rhi/vulkan.odin (and HPL2's RIDescriptorSetAllocator).
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;
import std::collections::list;

const uint RPI_FRAMES_IN_FLIGHT = 5;
const uint RPI_DESCRIPTOR_SETS_PER_POOL = 64;
const uint RPI_ALLOC_HASH_BUCKETS = 256;
const uint RPI_SLOT_BLOCK_SIZE = 1024;

// A cached descriptor set with intrusive LRU-queue and hash-chain links.
// Slots live in separately allocated fixed-size blocks so List growth can
// never invalidate a slot pointer already present in either chain.
struct RpiDescriptorSetSlot
{
	ulong hash;
	uint frame_count;
	RpiDescriptorSetSlot* qu_next;
	RpiDescriptorSetSlot* qu_prev;
	RpiDescriptorSetSlot* h_next;
	RpiDescriptorSetSlot* h_prev;
	vk::DescriptorPool pool;
	vk::DescriptorSet handle;
}

struct RpiDescriptorSetSlotBlock
{
	RpiDescriptorSetSlot[] slots;
}

// The per-descriptor-set LRU allocator.
struct RpiDescriptorSetAlloc
{
	uint frames_in_flight;
	RpiPoolSizes sizes;
	vk::DescriptorSetLayout set_layout;
	RpiDescriptorSetSlot*[RPI_ALLOC_HASH_BUCKETS] hash_slots;
	RpiDescriptorSetSlot* queue_begin;
	RpiDescriptorSetSlot* queue_end;
	List{RpiDescriptorSetSlot*} reserved;
	List{vk::DescriptorPool} pools;
	List{RpiDescriptorSetSlotBlock} blocks;
	sz block_index;
	Allocator allocator;
}

fn RpiDescriptorSetAlloc rpi_descriptor_set_alloc_init(vk::DescriptorSetLayout set_layout, RpiPoolSizes sizes, uint frames_in_flight, Allocator allocator = mem)
{
	RpiDescriptorSetAlloc result = {
		.frames_in_flight = frames_in_flight,
		.sizes = sizes,
		.set_layout = set_layout,
		.allocator = allocator,
	};
	result.reserved.init(allocator);
	result.pools.init(allocator);
	result.blocks.init(allocator);
	return result;
}

// The GPU must be idle: cached descriptor sets and their pools must no longer
// be referenced by any command buffer.
fn void rpi_descriptor_set_alloc_free(RpiDescriptorSetAlloc* a, Device* device)
{
	foreach (pool : a.pools)
	{
		device.backend.vk.vtable.destroyDescriptorPool(device.backend.vk.device, pool, null);
	}
	foreach (&block : a.blocks)
	{
		alloc::free(a.allocator, block.slots.ptr);
	}
	a.pools.free();
	a.reserved.free();
	a.blocks.free();
	*a = {};
}

// Resolve a descriptor set for a monotonically increasing frame counter and
// content hash. `found` is true for a cache hit; on a miss the caller must
// write the returned set before binding it.
fn RpiDescriptorSetSlot*? rpi_descriptor_set_alloc_resolve(RpiDescriptorSetAlloc* a, Device* device, uint frame_count, ulong hash, bool* found)
{
	*found = false;
	uint hash_index = (uint)(hash % RPI_ALLOC_HASH_BUCKETS);

	// Cache hit: move the slot to the MRU end of the queue.
	for (RpiDescriptorSetSlot* slot = a.hash_slots[hash_index]; slot != null; slot = slot.h_next)
	{
		if (slot.hash != hash) continue;
		if (a.queue_end != slot)
		{
			if (a.queue_begin == slot)
			{
				a.queue_begin = slot.qu_next;
				if (slot.qu_next != null) slot.qu_next.qu_prev = null;
			}
			else
			{
				if (slot.qu_prev != null) slot.qu_prev.qu_next = slot.qu_next;
				if (slot.qu_next != null) slot.qu_next.qu_prev = slot.qu_prev;
			}
			slot.qu_next = null;
			slot.qu_prev = a.queue_end;
			if (a.queue_end != null) a.queue_end.qu_next = slot;
			a.queue_end = slot;
		}
		slot.frame_count = frame_count;
		*found = true;
		return slot;
	}

	// Recycle the LRU head only after the frame-safety window has elapsed.
	RpiDescriptorSetSlot* begin = a.queue_begin;
	if (begin != null && frame_count > begin.frame_count + a.frames_in_flight)
	{
		rpi_descriptor_set_alloc_detach(a, begin);
		begin.frame_count = frame_count;
		begin.hash = hash;
		rpi_descriptor_set_alloc_attach(a, begin);
		return begin;
	}

	// No reusable set: allocate another pool and reserve its fresh slots.
	if (a.reserved.len() == 0)
	{
		rpi_descriptor_set_alloc_create_pool(a, device)!;
		assert(a.reserved.len() > 0);
	}
	RpiDescriptorSetSlot* slot = a.reserved[a.reserved.len() - 1];
	a.reserved.remove_last()!!;
	slot.hash = hash;
	slot.frame_count = frame_count;
	rpi_descriptor_set_alloc_attach(a, slot);
	return slot;
}

// Create one descriptor pool sized for one set's reflected descriptor counts,
// then allocate RPI_DESCRIPTOR_SETS_PER_POOL sets into the reserve.
fn void? rpi_descriptor_set_alloc_create_pool(RpiDescriptorSetAlloc* a, Device* device) @private
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;
	vk::Device dev = device.backend.vk.device;
	vk::DescriptorPoolSize[5] pool_sizes;
	uint pool_size_count = 0;

	if (a.sizes.sampler > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.SAMPLER, .descriptorCount = a.sizes.sampler * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.sampled_image > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.SAMPLED_IMAGE, .descriptorCount = a.sizes.sampled_image * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.storage_image > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.STORAGE_IMAGE, .descriptorCount = a.sizes.storage_image * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.uniform_buffer > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.UNIFORM_BUFFER, .descriptorCount = a.sizes.uniform_buffer * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.storage_buffer > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.STORAGE_BUFFER, .descriptorCount = a.sizes.storage_buffer * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}

	vk::DescriptorPoolCreateInfo pool_info = {
		.sType = vk::StructureType.DESCRIPTOR_POOL_CREATE_INFO,
		.flags = vk::DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
		.maxSets = RPI_DESCRIPTOR_SETS_PER_POOL,
		.poolSizeCount = pool_size_count,
		.pPoolSizes = pool_size_count > 0 ? &pool_sizes[0] : null,
	};
	vk::DescriptorPool pool;
	vk::Result result = vtable.createDescriptorPool(dev, &pool_info, null, &pool);
	if (result != vk::Result.SUCCESS) return vk_check(result);

	vk::DescriptorSetLayout[RPI_DESCRIPTOR_SETS_PER_POOL] layouts;
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++) layouts[i] = a.set_layout;
	vk::DescriptorSet[RPI_DESCRIPTOR_SETS_PER_POOL] handles;
	vk::DescriptorSetAllocateInfo alloc_info = {
		.sType = vk::StructureType.DESCRIPTOR_SET_ALLOCATE_INFO,
		.descriptorPool = pool,
		.descriptorSetCount = RPI_DESCRIPTOR_SETS_PER_POOL,
		.pSetLayouts = &layouts[0],
	};
	result = vtable.allocateDescriptorSets(dev, &alloc_info, &handles[0]);
	if (result != vk::Result.SUCCESS)
	{
		vtable.destroyDescriptorPool(dev, pool, null);
		return vk_check(result);
	}

	// alloc_slot can fail while adding a new stable block. Restore only the
	// allocator metadata created by this pool before propagating that failure.
	sz old_block_count = a.blocks.len();
	sz old_block_index = a.block_index;
	bool committed = false;
	defer if (!committed)
	{
		a.block_index = old_block_index;
		while (a.blocks.len() > old_block_count)
		{
			RpiDescriptorSetSlotBlock* block = &a.blocks[a.blocks.len() - 1];
			alloc::free(a.allocator, block.slots.ptr);
			a.blocks.remove_last()!!;
		}
		vtable.destroyDescriptorPool(dev, pool, null);
	};

	RpiDescriptorSetSlot*[RPI_DESCRIPTOR_SETS_PER_POOL] slots;
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++)
	{
		slots[i] = rpi_descriptor_set_alloc_alloc_slot(a)!;
		slots[i].pool = pool;
		slots[i].handle = handles[i];
	}
	a.pools.push(pool);
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++) a.reserved.push(slots[i]);
	committed = true;
}

// Allocate the next slot from the current fixed heap block, allocating a new
// block only when the current block is exhausted.
fn RpiDescriptorSetSlot*? rpi_descriptor_set_alloc_alloc_slot(RpiDescriptorSetAlloc* a) @private
{
	if (a.blocks.len() == 0 || a.block_index == RPI_SLOT_BLOCK_SIZE)
	{
		RpiDescriptorSetSlot[] slots = alloc::alloc_array_try(a.allocator, RpiDescriptorSetSlot, RPI_SLOT_BLOCK_SIZE)!;
		slots[..] = {};
		a.blocks.push({ .slots = slots });
		a.block_index = 0;
	}
	RpiDescriptorSetSlotBlock* block = &a.blocks[a.blocks.len() - 1];
	RpiDescriptorSetSlot* slot = &block.slots[a.block_index];
	a.block_index += 1;
	return slot;
}

// Append a slot at the MRU queue end and prepend it in its hash bucket.
fn void rpi_descriptor_set_alloc_attach(RpiDescriptorSetAlloc* a, RpiDescriptorSetSlot* slot) @private
{
	slot.qu_next = null;
	slot.qu_prev = a.queue_end;
	if (a.queue_end != null) a.queue_end.qu_next = slot;
	a.queue_end = slot;
	if (a.queue_begin == null) a.queue_begin = slot;

	uint hash_index = (uint)(slot.hash % RPI_ALLOC_HASH_BUCKETS);
	slot.h_prev = null;
	slot.h_next = a.hash_slots[hash_index];
	if (a.hash_slots[hash_index] != null) a.hash_slots[hash_index].h_prev = slot;
	a.hash_slots[hash_index] = slot;
}

// Unlink a slot from both the LRU queue and its hash bucket.
fn void rpi_descriptor_set_alloc_detach(RpiDescriptorSetAlloc* a, RpiDescriptorSetSlot* slot) @private
{
	if (a.queue_begin == slot)
	{
		a.queue_begin = slot.qu_next;
		if (slot.qu_next != null) slot.qu_next.qu_prev = null;
		if (a.queue_end == slot) a.queue_end = null;
	}
	else if (a.queue_end == slot)
	{
		a.queue_end = slot.qu_prev;
		if (slot.qu_prev != null) slot.qu_prev.qu_next = null;
	}
	else
	{
		if (slot.qu_prev != null) slot.qu_prev.qu_next = slot.qu_next;
		if (slot.qu_next != null) slot.qu_next.qu_prev = slot.qu_prev;
	}

	uint hash_index = (uint)(slot.hash % RPI_ALLOC_HASH_BUCKETS);
	if (a.hash_slots[hash_index] == slot)
	{
		a.hash_slots[hash_index] = slot.h_next;
		if (slot.h_next != null) slot.h_next.h_prev = null;
	}
	else
	{
		if (slot.h_prev != null) slot.h_prev.h_next = slot.h_next;
		if (slot.h_next != null) slot.h_next.h_prev = slot.h_prev;
	}
	slot.h_prev = null;
	slot.h_next = null;
}

fn vk::DescriptorType vk_descriptor_type_from(DescriptorType type)
{
	switch (type)
	{
		case SAMPLED_IMAGE: return vk::DescriptorType.SAMPLED_IMAGE;
		case STORAGE_IMAGE: return vk::DescriptorType.STORAGE_IMAGE;
		case SAMPLER: return vk::DescriptorType.SAMPLER;
		case UNIFORM_BUFFER: return vk::DescriptorType.UNIFORM_BUFFER;
		case STORAGE_BUFFER: return vk::DescriptorType.STORAGE_BUFFER;
		case ACCELERATION_STRUCTURE: return vk::DescriptorType.ACCELERATION_STRUCTURE_KHR;
	}
}

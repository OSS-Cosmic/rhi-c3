// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Port of Sebastian Aaltonen's OffsetAllocator (MIT, 2023).
//
// A two-level segregated-fit (TLSF-like) allocator that hands out
// `(offset, size)` ranges from a fixed-size virtual region. Designed for
// sub-allocating GPU buffer/heap regions, but the implementation here
// manages only metadata — the caller owns the underlying storage.
module rhi::alloc;

const NUM_TOP_BINS = 32;
const BINS_PER_LEAF = 8;
const TOP_BINS_INDEX_SHIFT = 3;
const LEAF_BINS_INDEX_MASK = 0x7;
const NUM_LEAF_BINS = NUM_TOP_BINS * BINS_PER_LEAF;

// 16-bit node indices halve the metadata cost but cap max_allocs at 65536.
// Match the C++ default (32-bit).
alias NodeIndex = uint;

const uint NO_SPACE = 0xffffffff;

struct OffsetAllocation
{
	uint offset;
	NodeIndex metadata;
}

const OffsetAllocation OFFSET_ALLOCATION_NONE = { NO_SPACE, NO_SPACE };

struct StorageReport
{
	uint total_free_space;
	uint largest_free_region;
}

struct StorageRegion
{
	uint size;
	uint count;
}

struct StorageReportFull
{
	StorageRegion[NUM_LEAF_BINS] free_regions;
}

// Floating-point-style size→bin mapping. Bins are spaced log-linearly so
// that the worst-case overhead of rounding to a bin is a fixed percentage.
const uint MANTISSA_BITS = 3;
const uint MANTISSA_VALUE = 1 << MANTISSA_BITS;
const uint MANTISSA_MASK = MANTISSA_VALUE - 1;

fn uint small_float_uint_to_float_round_up(uint size)
{
	uint exp = 0;
	uint mantissa = 0;

	if (size < MANTISSA_VALUE)
	{
		mantissa = size;
	}
	else
	{
		uint leading_zeros = (uint)size.clz();
		uint highest_set = 31 - leading_zeros;
		uint mantissa_start = highest_set - MANTISSA_BITS;
		exp = mantissa_start + 1;
		mantissa = (size >> mantissa_start) & MANTISSA_MASK;

		uint low_bits_mask = (1u << mantissa_start) - 1;
		if ((size & low_bits_mask) != 0) mantissa += 1;
	}

	// `+` (not `|`) so that a mantissa overflow carries into the exponent.
	return (exp << MANTISSA_BITS) + mantissa;
}

fn uint small_float_uint_to_float_round_down(uint size)
{
	uint exp = 0;
	uint mantissa = 0;

	if (size < MANTISSA_VALUE)
	{
		mantissa = size;
	}
	else
	{
		uint leading_zeros = (uint)size.clz();
		uint highest_set = 31 - leading_zeros;
		uint mantissa_start = highest_set - MANTISSA_BITS;
		exp = mantissa_start + 1;
		mantissa = (size >> mantissa_start) & MANTISSA_MASK;
	}

	return (exp << MANTISSA_BITS) | mantissa;
}

// Named `small_float_float_to_uint` in the Odin tree; renamed so it doesn't
// collide with the `small_float_float_to_uint` @test in the same module.
fn uint small_float_to_uint(uint float_value)
{
	uint exponent = float_value >> MANTISSA_BITS;
	uint mantissa = float_value & MANTISSA_MASK;
	if (exponent == 0) return mantissa;
	return (mantissa | MANTISSA_VALUE) << (exponent - 1);
}

fn uint find_lowest_set_bit_after(uint bit_mask, uint start_bit_index) @private
{
	// The C version relies on `1 << 32` UB wrapping to 1 on x86. Guard explicitly.
	if (start_bit_index >= 32) return NO_SPACE;
	uint mask_before = (1u << start_bit_index) - 1;
	uint mask_after = ~mask_before;
	uint bits_after = bit_mask & mask_after;
	if (bits_after == 0) return NO_SPACE;
	return (uint)bits_after.ctz();
}

const uint NODE_UNUSED = 0xffffffff;

struct OffsetNode
{
	uint data_offset;
	uint data_size;
	NodeIndex bin_list_prev;
	NodeIndex bin_list_next;
	NodeIndex neighbor_prev;
	NodeIndex neighbor_next;
	bool used;
}

const OffsetNode OFFSET_NODE_EMPTY @private = {
	.bin_list_prev = NODE_UNUSED,
	.bin_list_next = NODE_UNUSED,
	.neighbor_prev = NODE_UNUSED,
	.neighbor_next = NODE_UNUSED,
};

struct OffsetAllocator
{
	Allocator allocator;
	uint size;
	uint max_allocs;
	uint free_storage;
	uint used_bins_top;
	char[NUM_TOP_BINS] used_bins;
	NodeIndex[NUM_LEAF_BINS] bin_indices;
	OffsetNode[] nodes;
	NodeIndex[] free_nodes;
	uint free_offset;
}

fn void? OffsetAllocator.init(&self, uint size, uint max_allocs, Allocator allocator = mem)
{
	*self = {
		.allocator = allocator,
		.size = size,
		.max_allocs = max_allocs,
	};
	return self.reset();
}

fn void OffsetAllocator.deinit(&self)
{
	mem::alloc::free(self.allocator, self.nodes.ptr);
	mem::alloc::free(self.allocator, self.free_nodes.ptr);
	self.nodes = {};
	self.free_nodes = {};
}

fn void? OffsetAllocator.reset(&self)
{
	self.free_storage = 0;
	self.used_bins_top = 0;
	self.free_offset = self.max_allocs - 1;

	self.used_bins = {};
	self.bin_indices[..] = NODE_UNUSED;

	self.deinit();

	self.nodes = mem::alloc::alloc_array_try(self.allocator, OffsetNode, (sz)self.max_allocs)!;
	self.nodes[..] = OFFSET_NODE_EMPTY;

	self.free_nodes = mem::alloc::alloc_array_try(self.allocator, NodeIndex, (sz)self.max_allocs)!;
	// Stack of free indices — pop from the top so node 0 comes out first.
	for (uint i = 0; i < self.max_allocs; i++)
	{
		self.free_nodes[i] = self.max_allocs - i - 1;
	}

	// The whole region begins as a single free node spanning [0, size).
	self.insert_node_into_bin(self.size, 0);
}

fn OffsetAllocation OffsetAllocator.allocate(&self, uint alloc_size)
{
	if (self.free_offset == 0) return OFFSET_ALLOCATION_NONE;

	// Round up: smallest bin that is guaranteed to fit `alloc_size`.
	uint min_bin_index = small_float_uint_to_float_round_up(alloc_size);

	uint min_top_bin_index = min_bin_index >> TOP_BINS_INDEX_SHIFT;
	uint min_leaf_bin_index = min_bin_index & LEAF_BINS_INDEX_MASK;

	uint top_bin_index = min_top_bin_index;
	uint leaf_bin_index = NO_SPACE;

	// Probe the rounded-up bin first. May fail (the rounded-up leaf within
	// this top bin can be empty even though other leaves above it aren't).
	if ((self.used_bins_top & (1u << top_bin_index)) != 0)
	{
		leaf_bin_index = find_lowest_set_bit_after((uint)self.used_bins[top_bin_index], min_leaf_bin_index);
	}

	// Fall back to the next non-empty top bin. Any leaf there fits.
	if (leaf_bin_index == NO_SPACE)
	{
		top_bin_index = find_lowest_set_bit_after(self.used_bins_top, min_top_bin_index + 1);
		if (top_bin_index == NO_SPACE) return OFFSET_ALLOCATION_NONE;
		leaf_bin_index = (uint)((uint)self.used_bins[top_bin_index]).ctz();
	}

	uint bin_index = (top_bin_index << TOP_BINS_INDEX_SHIFT) | leaf_bin_index;

	// Pop the head of the bin's linked list.
	NodeIndex node_index = self.bin_indices[bin_index];
	OffsetNode* node = &self.nodes[node_index];
	uint node_total_size = node.data_size;
	uint node_data_offset = node.data_offset;
	NodeIndex node_neighbor_next = node.neighbor_next;

	node.data_size = alloc_size;
	node.used = true;
	self.bin_indices[bin_index] = node.bin_list_next;
	if (node.bin_list_next != NODE_UNUSED)
	{
		self.nodes[node.bin_list_next].bin_list_prev = NODE_UNUSED;
	}
	self.free_storage -= node_total_size;

	// Update bin-occupancy bitmasks if the bin is now empty.
	if (self.bin_indices[bin_index] == NODE_UNUSED)
	{
		self.used_bins[top_bin_index] &= (char)~(1u << leaf_bin_index);
		if (self.used_bins[top_bin_index] == 0)
		{
			self.used_bins_top &= ~(1u << top_bin_index);
		}
	}

	// Push the unused tail back into the freelist as a smaller free node.
	uint reminder_size = node_total_size - alloc_size;
	if (reminder_size > 0)
	{
		NodeIndex new_node_index = self.insert_node_into_bin(reminder_size, node_data_offset + alloc_size);

		// Splice the new node between `node` and its old next neighbor.
		if (node_neighbor_next != NODE_UNUSED)
		{
			self.nodes[node_neighbor_next].neighbor_prev = new_node_index;
		}
		self.nodes[new_node_index].neighbor_prev = node_index;
		self.nodes[new_node_index].neighbor_next = node_neighbor_next;
		self.nodes[node_index].neighbor_next = new_node_index;
	}

	return { .offset = node_data_offset, .metadata = node_index };
}

fn void OffsetAllocator.free(&self, OffsetAllocation allocation)
{
	assert(allocation.metadata != NO_SPACE);
	if (self.nodes.len == 0) return;

	NodeIndex node_index = allocation.metadata;
	assert(self.nodes[node_index].used);

	uint offset = self.nodes[node_index].data_offset;
	uint size = self.nodes[node_index].data_size;

	// Coalesce with previous neighbor if it's free.
	NodeIndex prev_neighbor = self.nodes[node_index].neighbor_prev;
	if (prev_neighbor != NODE_UNUSED && !self.nodes[prev_neighbor].used)
	{
		offset = self.nodes[prev_neighbor].data_offset;
		size += self.nodes[prev_neighbor].data_size;

		self.remove_node_from_bin(prev_neighbor);

		assert(self.nodes[prev_neighbor].neighbor_next == node_index);
		self.nodes[node_index].neighbor_prev = self.nodes[prev_neighbor].neighbor_prev;
	}

	// Coalesce with next neighbor if it's free.
	NodeIndex next_neighbor = self.nodes[node_index].neighbor_next;
	if (next_neighbor != NODE_UNUSED && !self.nodes[next_neighbor].used)
	{
		size += self.nodes[next_neighbor].data_size;

		self.remove_node_from_bin(next_neighbor);

		assert(self.nodes[next_neighbor].neighbor_prev == node_index);
		self.nodes[node_index].neighbor_next = self.nodes[next_neighbor].neighbor_next;
	}

	NodeIndex final_neighbor_next = self.nodes[node_index].neighbor_next;
	NodeIndex final_neighbor_prev = self.nodes[node_index].neighbor_prev;

	// Return the freed node to the freelist.
	self.free_offset += 1;
	self.free_nodes[self.free_offset] = node_index;

	// Re-insert the (possibly coalesced) free range as a new bin node.
	NodeIndex combined_node_index = self.insert_node_into_bin(size, offset);

	if (final_neighbor_next != NODE_UNUSED)
	{
		self.nodes[combined_node_index].neighbor_next = final_neighbor_next;
		self.nodes[final_neighbor_next].neighbor_prev = combined_node_index;
	}
	if (final_neighbor_prev != NODE_UNUSED)
	{
		self.nodes[combined_node_index].neighbor_prev = final_neighbor_prev;
		self.nodes[final_neighbor_prev].neighbor_next = combined_node_index;
	}
}

fn uint OffsetAllocator.insert_node_into_bin(&self, uint size, uint data_offset)
{
	// Round down: pick the largest bin that the size is still guaranteed
	// to satisfy (so any allocation rounded *up* into this bin will fit).
	uint bin_index = small_float_uint_to_float_round_down(size);

	uint top_bin_index = bin_index >> TOP_BINS_INDEX_SHIFT;
	uint leaf_bin_index = bin_index & LEAF_BINS_INDEX_MASK;

	if (self.bin_indices[bin_index] == NODE_UNUSED)
	{
		self.used_bins[top_bin_index] |= (char)(1u << leaf_bin_index);
		self.used_bins_top |= 1u << top_bin_index;
	}

	NodeIndex top_node_index = self.bin_indices[bin_index];
	NodeIndex node_index = self.free_nodes[self.free_offset];
	// Unsigned wrap matches the C code. The `free_offset == 0` guard in
	// `OffsetAllocator.allocate` prevents this from being read back as an
	// out-of-bounds index.
	self.free_offset -= 1;

	OffsetNode node = OFFSET_NODE_EMPTY;
	node.data_offset = data_offset;
	node.data_size = size;
	node.bin_list_next = top_node_index;
	self.nodes[node_index] = node;
	if (top_node_index != NODE_UNUSED)
	{
		self.nodes[top_node_index].bin_list_prev = node_index;
	}
	self.bin_indices[bin_index] = node_index;

	self.free_storage += size;
	return node_index;
}

fn void OffsetAllocator.remove_node_from_bin(&self, uint node_index)
{
	uint node_data_size = self.nodes[node_index].data_size;
	NodeIndex node_bin_prev = self.nodes[node_index].bin_list_prev;
	NodeIndex node_bin_next = self.nodes[node_index].bin_list_next;

	if (node_bin_prev != NODE_UNUSED)
	{
		// Middle of a bin's linked list — just unlink.
		self.nodes[node_bin_prev].bin_list_next = node_bin_next;
		if (node_bin_next != NODE_UNUSED)
		{
			self.nodes[node_bin_next].bin_list_prev = node_bin_prev;
		}
	}
	else
	{
		// Head of the list — also has to update bin-occupancy bitmasks.
		uint bin_index = small_float_uint_to_float_round_down(node_data_size);
		uint top_bin_index = bin_index >> TOP_BINS_INDEX_SHIFT;
		uint leaf_bin_index = bin_index & LEAF_BINS_INDEX_MASK;

		self.bin_indices[bin_index] = node_bin_next;
		if (node_bin_next != NODE_UNUSED)
		{
			self.nodes[node_bin_next].bin_list_prev = NODE_UNUSED;
		}

		if (self.bin_indices[bin_index] == NODE_UNUSED)
		{
			self.used_bins[top_bin_index] &= (char)~(1u << leaf_bin_index);
			if (self.used_bins[top_bin_index] == 0)
			{
				self.used_bins_top &= ~(1u << top_bin_index);
			}
		}
	}

	self.free_offset += 1;
	self.free_nodes[self.free_offset] = node_index;
	self.free_storage -= node_data_size;
}

fn uint OffsetAllocator.allocation_size(&self, OffsetAllocation allocation)
{
	if (allocation.metadata == NO_SPACE) return 0;
	if (self.nodes.len == 0) return 0;
	return self.nodes[allocation.metadata].data_size;
}

fn StorageReport OffsetAllocator.storage_report(&self)
{
	uint largest_free_region = 0;
	uint free_storage = 0;

	if (self.free_offset > 0)
	{
		free_storage = self.free_storage;
		if (self.used_bins_top != 0)
		{
			uint top_bin_index = 31 - (uint)self.used_bins_top.clz();
			uint leaf_bin_index = 31 - (uint)((uint)self.used_bins[top_bin_index]).clz();
			largest_free_region = small_float_to_uint((top_bin_index << TOP_BINS_INDEX_SHIFT) | leaf_bin_index);
			assert(free_storage >= largest_free_region);
		}
	}

	return { .total_free_space = free_storage, .largest_free_region = largest_free_region };
}

fn StorageReportFull OffsetAllocator.storage_report_full(&self)
{
	StorageReportFull report;
	for (uint i = 0; i < NUM_LEAF_BINS; i++)
	{
		uint count = 0;
		NodeIndex node_index = self.bin_indices[i];
		while (node_index != NODE_UNUSED)
		{
			node_index = self.nodes[node_index].bin_list_next;
			count += 1;
		}
		report.free_regions[i] = { .size = small_float_to_uint(i), .count = count };
	}
	return report;
}

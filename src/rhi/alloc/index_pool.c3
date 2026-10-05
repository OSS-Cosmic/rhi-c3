// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// A pool of unique uint IDs.
//
// Hands out IDs from a fixed-size reserved range and accepts them back.
// The free set is stored as a sorted list of inclusive `[start, end]`
// ranges; returns coalesce with adjacent ranges so that the metadata
// stays compact even after long allocate/free histories.
//
// Ported from the C++ `hpl::IndexPool` in HPL2 (Amnesia64). The original
// had an asymmetric coalescing bug and missed some merges on insert;
// both are fixed here.
module rhi::alloc;
import std::collections::list;

excuse POOL_EMPTY;

const uint INVALID_INDEX = uint::max;

struct IdRange
{
	uint start;
	uint end;
}

struct IndexPool
{
	List{IdRange} available;
}

// Reserve IDs `[0, reserve)`. `reserve` must be > 0.
fn void IndexPool.init(&self, uint reserve, Allocator allocator = mem)
{
	assert(reserve > 0);
	self.available.init(allocator, 1);
	self.available.push({ .start = 0, .end = reserve - 1 });
}

fn void IndexPool.deinit(&self)
{
	self.available.free();
}

// Pop the highest free ID. Returns `POOL_EMPTY` when the pool is empty.
fn uint? IndexPool.request_id(&self)
{
	sz len = self.available.len();
	if (len == 0) return POOL_EMPTY~;
	IdRange* entry = &self.available[len - 1];
	if (entry.end == entry.start)
	{
		uint res = entry.start;
		self.available.remove_last()!!;
		return res;
	}
	uint res = entry.end;
	entry.end -= 1;
	return res;
}

// Reset to a single range `[0, max_end_seen]`, where `max_end_seen` is
// the highest range endpoint currently in the free list.
fn void IndexPool.reset(&self)
{
	uint max_end = 0;
	foreach (entry : self.available)
	{
		max_end = max(max_end, entry.end);
	}
	self.available.clear();
	// Capacity is preserved by `clear`, and was >= 1 from init.
	self.available.push({ .start = 0, .end = max_end });
}

// Reset to a single range `[0, reserve)`. `reserve` must be > 0.
fn void IndexPool.reset_to_reserved(&self, uint reserve)
{
	assert(reserve > 0);
	self.available.clear();
	self.available.push({ .start = 0, .end = reserve - 1 });
}

// Return a previously-requested ID to the pool.
// Asserts in debug if the ID is already free.
fn void IndexPool.return_id(&self, uint index)
{
	// Binary search: smallest i such that available[i].start > index,
	// or len if no such i exists.
	IdRange[] items = self.available.array_view();
	sz lo = 0;
	sz hi = items.len;
	while (lo < hi)
	{
		sz mid = lo + (hi - lo) / 2;
		if (items[mid].start > index)
		{
			hi = mid;
		}
		else
		{
			lo = mid + 1;
		}
	}
	sz insert_at = lo;

	// The candidate neighbors are insert_at - 1 (prev) and insert_at (next).
	bool has_prev = insert_at > 0;
	bool has_next = insert_at < items.len;

	// Duplicate-return detection.
	if (has_prev) assert(items[insert_at - 1].end < index);
	if (has_next) assert(items[insert_at].start > index);

	bool prev_adj = has_prev && items[insert_at - 1].end + 1 == index;
	bool next_adj = has_next && items[insert_at].start == index + 1;

	if (prev_adj && next_adj)
	{
		// Merge prev and next into a single range.
		items[insert_at - 1].end = items[insert_at].end;
		self.available.remove_at(insert_at);
	}
	else if (prev_adj)
	{
		items[insert_at - 1].end = index;
	}
	else if (next_adj)
	{
		items[insert_at].start = index;
	}
	else
	{
		self.available.insert_at(insert_at, { .start = index, .end = index });
	}
}

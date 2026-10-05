// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi::alloc;
import std::core::test, std::math::random;

// ---------------------------------------------------------------------------
// Offset allocator (ported from offsetAllocatorTests.cpp)
// ---------------------------------------------------------------------------

const uint REGION @private = 1024 * 1024 * 256;
const uint MAX_ALLOCS @private = 128 * 1024;

struct SmallFloatCase @private
{
	uint number;
	uint up;
	uint down;
}

fn void small_float_uint_to_float() @test
{
	// Denorms, exp=1 and exp=2 + mantissa = 0 are precise (3-bit mantissa).
	for (uint i = 0; i < 17; i++)
	{
		test::eq(small_float_uint_to_float_round_up(i), i);
		test::eq(small_float_uint_to_float_round_down(i), i);
	}

	SmallFloatCase[*] cases = {
		{ 17, 17, 16 },
		{ 118, 39, 38 },
		{ 1024, 64, 64 },
		{ 65536, 112, 112 },
		{ 529445, 137, 136 },
		{ 1048575, 144, 143 },
	};
	foreach (c : cases)
	{
		test::eq(small_float_uint_to_float_round_up(c.number), c.up);
		test::eq(small_float_uint_to_float_round_down(c.number), c.down);
	}
}

fn void small_float_float_to_uint() @test
{
	for (uint i = 0; i < 17; i++)
	{
		test::eq(small_float_to_uint(i), i);
	}
	// float→uint→float must be lossless for all values in this range.
	// Values >= 240 overflow uint.
	for (uint i = 0; i < 240; i++)
	{
		uint v = small_float_to_uint(i);
		test::eq(small_float_uint_to_float_round_up(v), i);
		test::eq(small_float_uint_to_float_round_down(v), i);
	}
}

fn void offset_allocator_basic() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation x = a.allocate(1337);
	test::eq(x.offset, 0u);
	a.free(x);
}

fn void expect_whole_region_free(OffsetAllocator* a) @private
{
	OffsetAllocation validate_all = a.allocate(REGION);
	test::eq(validate_all.offset, 0u);
	a.free(validate_all);
}

fn void offset_allocator_allocate_simple() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation x0 = a.allocate(0);
	test::eq(x0.offset, 0u);
	OffsetAllocation x1 = a.allocate(1);
	test::eq(x1.offset, 0u);
	OffsetAllocation x2 = a.allocate(123);
	test::eq(x2.offset, 1u);
	OffsetAllocation x3 = a.allocate(1234);
	test::eq(x3.offset, 124u);

	a.free(x0);
	a.free(x1);
	a.free(x2);
	a.free(x3);

	expect_whole_region_free(&a);
}

fn void offset_allocator_merge_trivial() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation x = a.allocate(1337);
	test::eq(x.offset, 0u);
	a.free(x);

	OffsetAllocation y = a.allocate(1337);
	test::eq(y.offset, 0u);
	a.free(y);

	expect_whole_region_free(&a);
}

fn void offset_allocator_reuse_trivial() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation x = a.allocate(1024);
	test::eq(x.offset, 0u);
	OffsetAllocation y = a.allocate(3456);
	test::eq(y.offset, 1024u);
	a.free(x);
	OffsetAllocation z = a.allocate(1024);
	test::eq(z.offset, 0u);
	a.free(z);
	a.free(y);

	expect_whole_region_free(&a);
}

fn void offset_allocator_reuse_complex() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation x = a.allocate(1024);
	test::eq(x.offset, 0u);
	OffsetAllocation y = a.allocate(3456);
	test::eq(y.offset, 1024u);
	a.free(x);

	OffsetAllocation z = a.allocate(2345);
	test::eq(z.offset, 1024u + 3456);
	OffsetAllocation w = a.allocate(456);
	test::eq(w.offset, 0u);
	OffsetAllocation v = a.allocate(512);
	test::eq(v.offset, 456u);

	StorageReport report = a.storage_report();
	test::eq(report.total_free_space, REGION - 3456 - 2345 - 456 - 512);
	test::ne(report.largest_free_region, report.total_free_space);

	a.free(z);
	a.free(w);
	a.free(y);
	a.free(v);

	expect_whole_region_free(&a);
}

fn void offset_allocator_zero_fragmentation() @test
{
	OffsetAllocator a;
	a.init(REGION, MAX_ALLOCS)!!;
	defer a.deinit();

	OffsetAllocation[256] allocations;
	for (uint i = 0; i < 256; i++)
	{
		allocations[i] = a.allocate(1024 * 1024);
		test::eq(allocations[i].offset, i * 1024 * 1024);
	}

	{
		StorageReport report = a.storage_report();
		test::eq(report.total_free_space, 0u);
		test::eq(report.largest_free_region, 0u);
	}

	// Free four random slots.
	a.free(allocations[243]);
	a.free(allocations[5]);
	a.free(allocations[123]);
	a.free(allocations[95]);

	// Free four contiguous slots — allocator must coalesce.
	a.free(allocations[151]);
	a.free(allocations[152]);
	a.free(allocations[153]);
	a.free(allocations[154]);

	allocations[243] = a.allocate(1024 * 1024);
	allocations[5] = a.allocate(1024 * 1024);
	allocations[123] = a.allocate(1024 * 1024);
	allocations[95] = a.allocate(1024 * 1024);
	allocations[151] = a.allocate(1024 * 1024 * 4); // 4x larger
	test::ne(allocations[243].offset, NO_SPACE);
	test::ne(allocations[5].offset, NO_SPACE);
	test::ne(allocations[123].offset, NO_SPACE);
	test::ne(allocations[95].offset, NO_SPACE);
	test::ne(allocations[151].offset, NO_SPACE);

	for (int i = 0; i < 256; i++)
	{
		if (i < 152 || i > 154) a.free(allocations[i]);
	}

	{
		StorageReport report = a.storage_report();
		test::eq(report.total_free_space, REGION);
		test::eq(report.largest_free_region, REGION);
	}

	expect_whole_region_free(&a);
}

// ---------------------------------------------------------------------------
// Segment allocator
// ---------------------------------------------------------------------------

fn void segment_alloc_wraps_at_max_elements() @test
{
	// max = 8 with 2 elements per frame walks the cursor 0 -> 2 -> 4 -> 6 -> 8.
	// num_segments = 3 keeps enough history reclaimed that the ring never fills,
	// so frame 3's perfect tail fit leaves element_offset == max, and frame 4
	// must wrap cleanly to offset 0.
	SegmentAlloc seg = segment_alloc_init({ .max_elements = 8, .element_stride = 4, .num_segments = 3 });

	uint[4] expected_offsets = { 0, 2, 4, 6 };
	for (int frame = 0; frame < 4; frame++)
	{
		SegmentReq req = seg.alloc((ulong)frame, 2)!!;
		test::eq(req.element_offset, expected_offsets[frame]);
		test::le(seg.element_offset, (usz)seg.max_elements);
	}

	// Frame 3's tail fit parks the write cursor exactly on max.
	test::eq(seg.element_offset, 8u);

	// Frame 4 must wrap to offset 0 instead of asserting.
	SegmentReq wrapped = seg.alloc(4, 2)!!;
	test::eq(wrapped.element_offset, 0u);
	test::le(seg.element_offset, (usz)seg.max_elements);
}

// ---------------------------------------------------------------------------
// Index pool
// ---------------------------------------------------------------------------

// Structs aren't equatable by default; lets test::eq compare ranges.
fn bool IdRange.equals(self, IdRange other) => self.start == other.start && self.end == other.end;

fn void expect_request(IndexPool* pool, uint expected) @private
{
	uint id = pool.request_id()!!;
	test::eq(id, expected);
}

fn void drain(IndexPool* pool) @private
{
	while (true)
	{
		if (catch pool.request_id()) break;
	}
}

fn void index_pool_basic_request_and_exhaust() @test
{
	IndexPool pool;
	pool.init(4);
	defer pool.deinit();

	expect_request(&pool, 3);
	expect_request(&pool, 2);
	expect_request(&pool, 1);
	expect_request(&pool, 0);
	test::@error(pool.request_id(), POOL_EMPTY);
}

fn void index_pool_return_coalesces_with_previous() @test
{
	IndexPool pool;
	pool.init(8);
	defer pool.deinit();
	drain(&pool);

	// Return in ascending order — should coalesce into one range.
	pool.return_id(0);
	pool.return_id(1);
	pool.return_id(2);
	test::eq(pool.available.len(), 1);
	test::eq(pool.available[0], (IdRange){ 0, 2 });
}

fn void index_pool_return_coalesces_with_next() @test
{
	IndexPool pool;
	pool.init(8);
	defer pool.deinit();
	drain(&pool);

	// Return in descending order — should coalesce into one range.
	pool.return_id(7);
	pool.return_id(6);
	pool.return_id(5);
	test::eq(pool.available.len(), 1);
	test::eq(pool.available[0], (IdRange){ 5, 7 });
}

fn void index_pool_return_bridges_two_ranges() @test
{
	IndexPool pool;
	pool.init(8);
	defer pool.deinit();
	drain(&pool);

	// Build the free list as two disjoint ranges: [0,2] and [4,6].
	foreach (id : (uint[]){ 0, 1, 2, 4, 5, 6 }) pool.return_id(id);
	test::eq(pool.available.len(), 2);

	// Returning 3 should bridge the two ranges.
	pool.return_id(3);
	test::eq(pool.available.len(), 1);
	test::eq(pool.available[0], (IdRange){ 0, 6 });
}

fn void index_pool_isolated_returns_produce_separate_ranges() @test
{
	IndexPool pool;
	pool.init(16);
	defer pool.deinit();
	drain(&pool);

	pool.return_id(2);
	pool.return_id(7);
	pool.return_id(12);

	test::eq(pool.available.len(), 3);
	test::eq(pool.available[0], (IdRange){ 2, 2 });
	test::eq(pool.available[1], (IdRange){ 7, 7 });
	test::eq(pool.available[2], (IdRange){ 12, 12 });
}

fn void index_pool_reset_to_reserved() @test
{
	IndexPool pool;
	pool.init(4);
	defer pool.deinit();

	(void)pool.request_id();
	(void)pool.request_id();
	pool.reset_to_reserved(8);

	test::eq(pool.available.len(), 1);
	test::eq(pool.available[0], (IdRange){ 0, 7 });
}

fn void index_pool_request_after_return_reuses_returned_id() @test
{
	IndexPool pool;
	pool.init(4);
	defer pool.deinit();

	uint a = pool.request_id()!!;
	(void)pool.request_id();
	pool.return_id(a);
	// a was the highest; after return it sits at the end of the free list,
	// so request_id pops it first.
	expect_request(&pool, a);
}

fn void index_pool_stress_round_trip_preserves_uniqueness() @test
{
	const uint N = 1024;
	IndexPool pool;
	pool.init(N);
	defer pool.deinit();

	bool[N] seen;
	uint[N] handed_out;
	for (uint i = 0; i < N; i++)
	{
		uint id = pool.request_id()!!;
		test::lt(id, N);
		test::@check(!seen[id], "id %d handed out twice", id);
		seen[id] = true;
		handed_out[i] = id;
	}
	test::@error(pool.request_id(), POOL_EMPTY);

	// Return everything in a scrambled order (Fisher-Yates).
	DefaultRandom rng;
	random::seed(&rng, 0xC0FFEE);
	for (int i = N - 1; i > 0; i--)
	{
		int j = random::next(&rng, i + 1);
		@swap(handed_out[i], handed_out[j]);
	}
	foreach (id : handed_out) pool.return_id(id);

	// Free list should have collapsed back to a single full range.
	test::eq(pool.available.len(), 1);
	test::eq(pool.available[0], (IdRange){ 0, N - 1 });
}

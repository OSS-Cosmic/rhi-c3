// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

// Fake blocks: no GPU, each block gets a distinct device address so carving
// can be checked. `fake_base_misalign` shifts the first block off alignment.
int fake_allocs;
int fake_frees;
sz fake_last_size;
ulong fake_misalign;

fn BlockMem fake_alloc(Device* device, ScratchAlloc* scratch, sz size)
{
	fake_allocs++;
	fake_last_size = size;
	return {
		.buffer = { .cookie = (ulong)fake_allocs },
		.device_address = 0x10000ul * (ulong)fake_allocs + fake_misalign,
	};
}

fn void fake_free(Device* device, BlockMem* block)
{
	fake_frees++;
	block.buffer.cookie = 0;
}

fn void fake_reset()
{
	fake_allocs = 0;
	fake_frees = 0;
	fake_last_size = 0;
	fake_misalign = 0;
}

fn ScratchAlloc fake_scratch(sz block_size, sz alignment)
{
	ScratchAlloc s;
	s.init({ .block_size = block_size, .alignment_req = alignment, .alloc = &fake_alloc, .free = &fake_free });
	return s;
}

fn void scratch_alignment_helpers() @test
{
	ulong r;
	test::eq(scratch_valid_alignment(256), true);
	test::eq(scratch_valid_alignment(0), false);
	test::eq(scratch_valid_alignment(24), false);

	test::eq(scratch_aligned_size(1, 256, &r), true);
	test::eq(r, 256ul);
	test::eq(scratch_aligned_size(256, 256, &r), true);
	test::eq(r, 256ul);
	test::eq(scratch_aligned_size(257, 256, &r), true);
	test::eq(r, 512ul);
	test::eq(scratch_aligned_size(~0ul, 256, &r), false);
	test::eq(scratch_aligned_address(0x1001, 0x100, &r), true);
	test::eq(r, 0x1100ul);
	test::eq(scratch_aligned_address(~0ul, 0x100, &r), false);
}

fn void scratch_carve_aligns_to_address() @test
{
	// Base 0x1040 is misaligned by 0xc0 (to 256): first slice pads to 0x1100.
	ScratchCarve c = scratch_carve(0x1040, 1024, 0, 256, 256);
	test::eq(c.valid, true);
	test::eq(c.fits, true);
	test::eq(c.offset, 0xc0ul);
	// Capacity is block_size from the aligned start, so 4 slices still fit.
	c = scratch_carve(0x1040, 1024, 0xc0 + 768, 256, 256);
	test::eq(c.fits, true);
	c = scratch_carve(0x1040, 1024, 0xc0 + 1024, 256, 256);
	test::eq(c.fits, false);
	test::eq(scratch_carve(0x1000, 1024, 0, 100, 256).valid, false);
}

fn void scratch_oneshot_offset_bounds() @test
{
	ulong off;
	test::eq(scratch_oneshot_offset(0x1040, 2048 + 255, 256, 2048, &off), true);
	test::eq(off, 0xc0ul);
	// Backing without slack cannot absorb the padding.
	test::eq(scratch_oneshot_offset(0x1040, 2048, 256, 2048, &off), false);
	test::eq(scratch_oneshot_offset(0x1000, 2048, 256, 2048, &off), true);
	test::eq(off, 0ul);
}

fn void scratch_alloc_aligns_within_block() @test
{
	fake_reset();
	ScratchAlloc s = fake_scratch(1024, 256);
	BufferScratchAllocReq a = s.alloc_from_scratch(null, 10);
	BufferScratchAllocReq b = s.alloc_from_scratch(null, 300);
	test::eq(a.buffer_offset, 0);
	test::eq(a.buffer_size, 10);
	test::eq(b.buffer_offset, 256);
	test::eq(b.buffer_size, 300);
	test::eq(b.device_address % 256, 0ul);
	test::eq(b.device_address, a.block.device_address + 256);
	test::eq(fake_allocs, 1);
	test::eq(fake_last_size, 1024);
	s.deinit(null);
}

fn void scratch_alloc_misaligned_base() @test
{
	fake_reset();
	fake_misalign = 0x40;
	ScratchAlloc s = fake_scratch(512, 256);
	BufferScratchAllocReq a = s.alloc_from_scratch(null, 256);
	BufferScratchAllocReq b = s.alloc_from_scratch(null, 256);
	test::eq(a.buffer_offset, 0xc0);
	test::eq(a.device_address % 256, 0ul);
	test::eq(b.buffer_offset, 0xc0 + 256);
	test::eq(b.device_address % 256, 0ul);
	test::eq(fake_allocs, 1);
	s.deinit(null);
}

fn void scratch_alloc_block_rollover() @test
{
	fake_reset();
	ScratchAlloc s = fake_scratch(512, 256);
	BufferScratchAllocReq a = s.alloc_from_scratch(null, 256);
	BufferScratchAllocReq b = s.alloc_from_scratch(null, 256);
	BufferScratchAllocReq c = s.alloc_from_scratch(null, 256);
	test::eq(a.block.buffer.cookie, b.block.buffer.cookie);
	test::eq(c.block.buffer.cookie != a.block.buffer.cookie, true);
	test::eq(c.buffer_offset, 0);
	test::eq(fake_allocs, 2);
	test::eq(s.used_block_count(), 2);
	test::eq(s.used_block(0).buffer.cookie, c.block.buffer.cookie);
	test::eq(s.used_block(1).buffer.cookie, a.block.buffer.cookie);
	s.deinit(null);
	test::eq(fake_frees, 2);
}

fn void scratch_alloc_reset_recycles_blocks() @test
{
	fake_reset();
	ScratchAlloc s = fake_scratch(512, 256);
	s.alloc_from_scratch(null, 512);
	s.alloc_from_scratch(null, 512);
	test::eq(fake_allocs, 2);
	s.reset(null);
	test::eq(s.block_offset, 0);
	test::eq(s.used_block_count(), 1);
	// Next frame: first request reuses current, the rollover reuses the pool.
	BufferScratchAllocReq a = s.alloc_from_scratch(null, 512);
	BufferScratchAllocReq b = s.alloc_from_scratch(null, 512);
	test::eq(a.buffer_offset, 0);
	test::eq(b.buffer_offset, 0);
	test::eq(a.block.buffer.cookie != b.block.buffer.cookie, true);
	test::eq(fake_allocs, 2);
	test::eq(fake_frees, 0);
	s.deinit(null);
	test::eq(fake_frees, 2);
}

fn void scratch_alloc_oversized_one_shot_freed_on_reset() @test
{
	fake_reset();
	ScratchAlloc s = fake_scratch(512, 256);
	BufferScratchAllocReq small = s.alloc_from_scratch(null, 100);
	BufferScratchAllocReq big = s.alloc_from_scratch(null, 1000);
	// Rounded to alignment: 1024. Own block; current untouched.
	test::eq(fake_last_size, 1024);
	test::eq(big.buffer_size, 1000);
	test::eq(big.buffer_offset, 0);
	test::eq(big.block.buffer.cookie != small.block.buffer.cookie, true);
	test::eq(s.current.buffer.cookie, small.block.buffer.cookie);
	test::eq(s.block_offset, 256);
	test::eq(s.used_block_count(), 2);
	test::eq(s.used_block(1).buffer.cookie, big.block.buffer.cookie);

	BufferScratchAllocReq next = s.alloc_from_scratch(null, 100);
	test::eq(next.buffer_offset, 256);

	s.reset(null);
	test::eq(fake_frees, 1);
	test::eq(s.used_block_count(), 1);
	s.deinit(null);
	test::eq(fake_frees, 2);
}

fn void scratch_alloc_rejects_bad_input() @test
{
	fake_reset();
	ScratchAlloc bad;
	bad.init({ .block_size = 512, .alignment_req = 100, .alloc = &fake_alloc });
	test::eq(bad.alloc_from_scratch(null, 16).buffer_size, 0);
	bad.deinit(null);

	ScratchAlloc s = fake_scratch(512, 256);
	test::eq(s.alloc_from_scratch(null, 0).buffer_size, 0);
	test::eq(fake_allocs, 0);
	s.deinit(null);
}

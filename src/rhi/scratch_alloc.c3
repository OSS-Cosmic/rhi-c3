// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Per-frame linear scratch allocator over a pool of fixed-size GPU blocks.
// Port of HPL2's `RIScratchAlloc`.
//
// Requests are carved from the current block; when it is full the block moves
// to `recycle` and a pooled (or fresh) block takes over. `reset` returns
// recycled blocks to the pool. Requests larger than a block get a one-shot
// block that is freed on the next `reset` rather than pooled.
//
// Offsets are anchored to the block's GPU address (not just its offset 0) so
// that `device_address` of every slice honours the requested alignment.
module rhi;
import std::collections::list;
import vk;

const RI_UNIFORM_SCRATCH_ALLOC_SIZE = 256 * 128;
const RI_UNIFORM_SCRATCH_REQ_ALIGNMENT = 256;

struct BlockMem
{
	Buffer buffer;
	// GPU address of buffer offset 0; 0 on backends without raw addresses.
	ulong device_address;
}

alias ScratchAllocBlockFn = fn BlockMem(Device* device, ScratchAlloc* scratch, sz size);
alias ScratchFreeBlockFn = fn void(Device* device, BlockMem* block);

struct ScratchAllocDesc
{
	sz block_size;
	sz alignment_req;
	ScratchAllocBlockFn alloc;
	// Optional; defaults to `buffer_deinit`.
	ScratchFreeBlockFn free;
}

struct ScratchAlloc
{
	Allocator allocator;
	List{BlockMem} recycle;
	List{BlockMem} pool;
	// One-shot blocks for requests > block_size. Freed on reset rather than
	// pooled: the wrong size to be reused for normal block-sized allocs.
	List{BlockMem} oversized;

	sz alignment_req;
	sz block_size;
	ScratchAllocBlockFn alloc;
	ScratchFreeBlockFn free;

	BlockMem current;
	sz block_offset;
}

struct BufferScratchAllocReq
{
	BlockMem block;
	char* mapped_address;
	sz buffer_offset;
	sz buffer_size;
	// block.device_address + buffer_offset
	ulong device_address;
}

// ---- pure carving math ----------------------------------------------------

fn bool scratch_valid_alignment(ulong alignment) @private
{
	return alignment != 0 && (alignment & (alignment - 1)) == 0;
}

fn bool scratch_add(ulong lhs, ulong rhs, ulong* result) @private
{
	if (lhs > ~0ul - rhs) return false;
	*result = lhs + rhs;
	return true;
}

fn bool scratch_aligned_size(ulong size, ulong alignment, ulong* result) @private
{
	if (!scratch_valid_alignment(alignment) || !scratch_add(size, alignment - 1, result)) return false;
	*result &= ~(alignment - 1);
	return true;
}

fn bool scratch_aligned_address(ulong address, ulong alignment, ulong* result) @private
{
	if (!scratch_valid_alignment(alignment) || !scratch_add(address, alignment - 1, result)) return false;
	*result &= ~(alignment - 1);
	return true;
}

struct ScratchCarve @private
{
	bool valid;
	// The request fits in the block at `offset`.
	bool fits;
	// `cursor` rounded up so (base_address + offset) is aligned.
	ulong offset;
}

// Place a request of `aligned_size` bytes (already rounded to `alignment`) in
// a block whose offset 0 is at `base_address`. The usable region is
// `block_size` bytes starting at the first aligned address of the block, so a
// misaligned base costs padding but never capacity.
fn ScratchCarve scratch_carve(ulong base_address, ulong block_size, ulong cursor, ulong alignment, ulong aligned_size) @private
{
	ulong start_address;
	ulong cursor_address;
	ulong end;
	ulong base_cursor;
	if (!scratch_aligned_address(base_address, alignment, &start_address)) return {};
	if (!scratch_add(start_address - base_address, block_size, &end)) return {};
	if (!scratch_add(base_address, cursor, &base_cursor)) return {};
	if (!scratch_aligned_address(base_cursor, alignment, &cursor_address)) return {};
	ulong offset = cursor_address - base_address;
	// A fresh block (cursor 0) begins at its first aligned address.
	bool fits = offset <= end && aligned_size <= end - offset;
	return { .valid = true, .fits = fits, .offset = offset };
}

// Offset of a request inside a one-shot block of `backing_size` bytes, or
// false if the aligned slice would not fit.
fn bool scratch_oneshot_offset(ulong base_address, ulong backing_size, ulong alignment, ulong request_size, ulong* offset) @private
{
	ulong aligned_address;
	if (!scratch_aligned_address(base_address, alignment, &aligned_address)) return false;
	ulong pad = aligned_address - base_address;
	if (pad > backing_size || request_size > backing_size - pad) return false;
	*offset = pad;
	return true;
}

// ---- block handlers -------------------------------------------------------

fn ulong scratch_block_device_address(Device* device, Buffer* b) @private
{
	$if HAS_VK:
		if (renderer.backend == VK)
		{
			vk::BufferDeviceAddressInfo info = {
				.sType = vk::StructureType.BUFFER_DEVICE_ADDRESS_INFO,
				.buffer = b.backend.vk.buffer,
			};
			return (ulong)device.backend.vk.vtable.getBufferDeviceAddress(device.backend.vk.device, &info);
		}
	$endif
	return 0;
}

fn void scratch_free_block(ScratchAlloc* scratch, Device* device, BlockMem* block) @private
{
	if (buffer_is_empty(&block.buffer)) return;
	if (scratch.free)
	{
		scratch.free(device, block);
	}
	else
	{
		buffer_deinit(&block.buffer, device);
	}
	*block = {};
}

// Host-visible constant-buffer blocks. The backing buffer carries
// `alignment_req - 1` bytes of slack so an unaligned base address can be
// padded without losing `size` usable bytes.
fn BlockMem scratch_uniform_alloc_handler(Device* device, ScratchAlloc* scratch, sz size)
{
	ulong backing;
	if (!scratch_add((ulong)size, (ulong)scratch.alignment_req - 1, &backing)) return {};
	BufferUsage usage = { .constant_buffer = true, .scratch_buffer = true };
	$if HAS_VK:
		// Vulkan needs a device address to align each slice against the real
		// GPU address of the buffer.
		if (renderer.backend == VK) usage.device_address = true;
	$endif
	Buffer? buffer = buffer_init_general(device, {
		.size = (sz)backing,
		.persistent_map = true,
		.sequential_access = true,
		.usage = usage,
		.buffer_usage = PREFER_HOST,
	});
	if (catch buffer) return {};
	BlockMem mem = { .buffer = buffer, .device_address = scratch_block_device_address(device, &buffer) };
	if (mem.buffer.mapped_region.ptr == null)
	{
		buffer_deinit(&mem.buffer, device);
		return {};
	}
	return mem;
}

// ---- lifecycle ------------------------------------------------------------

fn void ScratchAlloc.init(&self, ScratchAllocDesc desc, Allocator allocator = mem)
{
	*self = { .allocator = allocator };
	self.recycle.init(allocator);
	self.pool.init(allocator);
	self.oversized.init(allocator);
	// Left unconfigured (alloc == null) on a bad desc; every request then fails.
	if (!scratch_valid_alignment((ulong)desc.alignment_req) || desc.block_size <= 0 || !desc.alloc) return;
	self.alignment_req = desc.alignment_req;
	self.block_size = desc.block_size;
	self.alloc = desc.alloc;
	self.free = desc.free;
}

fn void ScratchAlloc.deinit(&self, Device* device)
{
	scratch_free_block(self, device, &self.current);
	foreach (&block : self.recycle) scratch_free_block(self, device, block);
	foreach (&block : self.pool) scratch_free_block(self, device, block);
	foreach (&block : self.oversized) scratch_free_block(self, device, block);
	self.recycle.free();
	self.pool.free();
	self.oversized.free();
	self.block_offset = 0;
}

// Invalidates every previously returned request. The current block stays
// current; recycled blocks return to the pool.
fn void ScratchAlloc.reset(&self, Device* device)
{
	foreach (block : self.recycle) self.pool.push(block);
	self.recycle.clear();

	// Oversized one-shots don't match block_size, so they can't be reused.
	foreach (&block : self.oversized) scratch_free_block(self, device, block);
	self.oversized.clear();

	self.block_offset = 0;
}

fn sz ScratchAlloc.used_block_count(&self)
{
	sz count = (sz)self.recycle.len() + (sz)self.oversized.len();
	if (!buffer_is_empty(&self.current.buffer)) count++;
	return count;
}

// Iteration order: current (if any), recycle[..], oversized[..].
fn BlockMem* ScratchAlloc.used_block(&self, sz index)
{
	sz cursor = 0;
	if (!buffer_is_empty(&self.current.buffer))
	{
		if (index == 0) return &self.current;
		cursor = 1;
	}
	sz recycle_end = cursor + (sz)self.recycle.len();
	if (index < recycle_end) return &self.recycle[(usz)(index - cursor)];
	return &self.oversized[(usz)(index - recycle_end)];
}

fn bool scratch_block_valid(ScratchAlloc* scratch, BlockMem* block) @private
{
	if (buffer_is_empty(&block.buffer)) return false;
	// Uniform blocks are written by the host, so they must be mapped.
	if (scratch.alloc == &scratch_uniform_alloc_handler && block.buffer.mapped_region.ptr == null) return false;
	return true;
}

// Returns an empty request (buffer_size == 0) on failure.
fn BufferScratchAllocReq ScratchAlloc.alloc_from_scratch(&self, Device* device, sz request_size)
{
	if (!self.alloc || self.block_size <= 0 || request_size <= 0) return {};
	ulong alignment = (ulong)self.alignment_req;
	ulong aligned_size;
	if (!scratch_aligned_size((ulong)request_size, alignment, &aligned_size)) return {};

	// Oversized one-shot: a block sized to this request, owned by the
	// oversized list until reset. `current` is untouched so later normal
	// requests keep filling it at the same offset.
	if (aligned_size > (ulong)self.block_size)
	{
		BlockMem one_shot = self.alloc(device, self, (sz)aligned_size);
		if (!scratch_block_valid(self, &one_shot))
		{
			scratch_free_block(self, device, &one_shot);
			return {};
		}
		// Backing includes alignment_req - 1 bytes of slack (see handlers).
		ulong backing = aligned_size + alignment - 1;
		ulong offset;
		if (!scratch_oneshot_offset(one_shot.device_address, backing, alignment, (ulong)request_size, &offset))
		{
			scratch_free_block(self, device, &one_shot);
			return {};
		}
		self.oversized.push(one_shot);
		return {
			.block = one_shot,
			.mapped_address = one_shot.buffer.mapped_region.ptr,
			.buffer_offset = (sz)offset,
			.buffer_size = request_size,
			.device_address = one_shot.device_address + offset,
		};
	}

	if (buffer_is_empty(&self.current.buffer))
	{
		BlockMem first = self.alloc(device, self, self.block_size);
		if (!scratch_block_valid(self, &first))
		{
			scratch_free_block(self, device, &first);
			return {};
		}
		self.current = first;
		self.block_offset = 0;
	}

	ScratchCarve carve = scratch_carve(self.current.device_address, (ulong)self.block_size, (ulong)self.block_offset, alignment, aligned_size);
	if (!carve.valid) return {};

	if (!carve.fits)
	{
		BlockMem next;
		if (self.pool.len() > 0)
		{
			next = self.pool.pop()!!;
		}
		else
		{
			next = self.alloc(device, self, self.block_size);
		}
		if (!scratch_block_valid(self, &next))
		{
			scratch_free_block(self, device, &next);
			return {};
		}
		// Re-anchor on the new block; a fresh block always fits aligned_size
		// since aligned_size <= block_size.
		carve = scratch_carve(next.device_address, (ulong)self.block_size, 0, alignment, aligned_size);
		if (!carve.valid || !carve.fits)
		{
			// Keep the block for reuse rather than leaking it.
			self.pool.push(next);
			return {};
		}
		self.recycle.push(self.current);
		self.current = next;
	}

	BufferScratchAllocReq req = {
		.block = self.current,
		.mapped_address = self.current.buffer.mapped_region.ptr,
		.buffer_offset = (sz)carve.offset,
		.buffer_size = request_size,
		.device_address = self.current.device_address + carve.offset,
	};
	self.block_offset = (sz)carve.offset + (sz)aligned_size;
	return req;
}

// Publish host writes to the GPU. No-op for GPU-only requests.
fn void scratch_alloc_finish(Device* device, BufferScratchAllocReq* req)
{
	if (!req || !req.mapped_address) return;
	buffer_flush(&req.block.buffer, device);
}

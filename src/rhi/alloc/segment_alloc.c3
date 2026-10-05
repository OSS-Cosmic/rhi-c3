// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi::alloc;

excuse NO_SPACE_LEFT;

const MAX_SEGMENTS = 8;

struct SegmentDesc
{
	uint max_elements;
	ushort element_stride;
	ushort num_segments;
}

struct SegmentReq
{
	ushort element_stride;
	uint element_offset;
	uint num_elements;
}

struct SegmentEntry @private
{
	ulong frame_num;
	usz num_elements;
}

// A ring-buffer segment allocator that tracks per-frame ownership of element ranges.
//
// Elements are sub-allocated linearly from a fixed-size ring buffer. Each frame
// is tracked as a named segment; segments are reclaimed once they are more than
// `num_segments` frames old, freeing their element range for reuse.
struct SegmentAlloc
{
	ushort element_stride;
	ushort num_segments;
	uint max_elements;
	char tail;
	char head;
	usz elements_consumed;
	usz element_offset;
	SegmentEntry[MAX_SEGMENTS] segment;
}

fn SegmentAlloc segment_alloc_init(SegmentDesc desc)
{
	assert(desc.num_segments < MAX_SEGMENTS);
	assert(desc.element_stride > 0);
	return {
		.element_stride = desc.element_stride,
		.num_segments = desc.num_segments,
		.max_elements = desc.max_elements,
		.tail = 0,
		.head = 1,
	};
}

// Sub-allocate `num_elements` elements for `frame_index`.
//
// Returns `NO_SPACE_LEFT` if there is not enough free space in the ring buffer.
// On a new frame index the head segment is advanced automatically.
// Old segments whose frame number is more than `num_segments` frames
// behind `frame_index` are reclaimed before the allocation is attempted.
fn SegmentReq? SegmentAlloc.alloc(&self, ulong frame_index, usz num_elements)
{
	usz max = (usz)self.max_elements;

	// Reclaim segments that are old enough.
	while (self.tail != self.head && frame_index >= self.segment[self.tail].frame_num + (ulong)self.num_segments)
	{
		assert(self.elements_consumed >= self.segment[self.tail].num_elements);
		self.elements_consumed -= self.segment[self.tail].num_elements;
		self.segment[self.tail] = {};
		self.tail = (self.tail + 1) % MAX_SEGMENTS;
	}

	// New frame — advance head.
	if (frame_index != self.segment[self.head].frame_num)
	{
		self.head = (self.head + 1) % MAX_SEGMENTS;
		self.segment[self.head] = { .frame_num = frame_index };
		assert(self.head != self.tail);
	}

	assert(self.element_offset <= max);

	// Not enough total free space.
	if (max - self.elements_consumed < num_elements) return NO_SPACE_LEFT~;

	// Try to fit linearly from the current write cursor.
	if (self.element_offset + num_elements <= max)
	{
		SegmentReq req = {
			.element_offset = (uint)self.element_offset,
			.element_stride = self.element_stride,
			.num_elements = (uint)num_elements,
		};
		self.element_offset += num_elements;
		self.elements_consumed += num_elements;
		self.segment[self.head].num_elements += num_elements;
		return req;
	}

	// Doesn't fit at the end — wrap around to offset 0.
	// The skipped tail padding is charged to the current segment so that
	// reclaim accounts for it when the segment is eventually freed.
	usz tail_remainder = max - self.element_offset;
	if (max - (self.elements_consumed + tail_remainder) >= num_elements)
	{
		self.segment[self.head].num_elements += tail_remainder;
		self.elements_consumed += tail_remainder;

		SegmentReq req = {
			.element_offset = 0,
			.element_stride = self.element_stride,
			.num_elements = (uint)num_elements,
		};
		self.element_offset = num_elements;
		self.elements_consumed += num_elements;
		self.segment[self.head].num_elements += num_elements;
		return req;
	}

	return NO_SPACE_LEFT~;
}

fn bool segment_is_continuous(usz current_offset, usz current_num_elements, usz next_offset) @inline
{
	return current_offset + current_num_elements == next_offset;
}

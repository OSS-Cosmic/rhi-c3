// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Per-frame deferred-release helper for the RHI.
//
// While a frame records work you `enqueue` (ref) every resource it touches
// so nothing is discarded while the GPU may still be reading it. `seal` closes
// the frame, tagging its marked items with the timeline value at which the GPU
// will be finished. Once that value has passed, `drain` releases (derefs) every
// item belonging to completed frames, oldest first — letting a finished frame
// discard its resources as quickly as possible.
//
// `items` is a FIFO of every marked item; `batches` records, per sealed frame,
// its timeline value and how many items it owns.
module rhi;
import std::collections::list, std::collections::deque;

alias DerefFn = fn void(void*);

struct DeferralBatch
{
	ulong value;
	sz len;
}

struct DeferralItem
{
	void* data;
	DerefFn deref;
}

// Per-frame deferred-release queue. See module doc comment above.
struct TimelineDeferral
{
	List{DeferralBatch} batches;
	Deque{DeferralItem} items;
	// Items enqueued since the last `seal`, waiting to be batched.
	sz pending;
}

fn void TimelineDeferral.init(&self, Allocator allocator = mem)
{
	self.batches.init(allocator);
	self.items.init(allocator);
	self.pending = 0;
}

fn void TimelineDeferral.deinit(&self)
{
	self.batches.free();
	self.items.free();
}

fn void TimelineDeferral.enqueue(&self, void* data, DerefFn ref, DerefFn deref)
{
	ref(data);
	self.items.push({ .data = data, .deref = deref });
	self.pending++;
}

// Odin's `timeline_deferral_enqueue_typed`: takes `fn void(T*)` callbacks for
// `item: T*` and casts them to `fn void(void*)`, as Odin's transmute does.
macro void TimelineDeferral.enqueue_typed(&self, item, ref, deref)
{
	self.enqueue((void*)item, (DerefFn)ref, (DerefFn)deref);
}

fn void TimelineDeferral.seal(&self, ulong value)
{
	if (self.pending == 0) return;
	self.batches.push({ .value = value, .len = self.pending });
	self.pending = 0;
}

fn void TimelineDeferral.drain(&self, ulong value)
{
	sz drained = 0;
	while (drained < self.batches.len())
	{
		DeferralBatch batch = self.batches[drained];
		if (batch.value > value) break;
		for (sz n = 0; n < batch.len; n++)
		{
			DeferralItem item = self.items.pop_first()!!;
			item.deref(item.data);
		}
		drained++;
	}
	if (drained > 0)
	{
		sz remaining = self.batches.len() - drained;
		DeferralBatch[] view = self.batches.array_view();
		for (sz i = 0; i < remaining; i++) view[i] = view[drained + i];
		self.batches.size = remaining;
	}
}

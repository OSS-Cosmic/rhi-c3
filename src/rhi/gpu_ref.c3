// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Reference-counted wrapper around a GPU resource. Port of rhi-zig's
// `gpu_ref.zig`. rhi-zig's two instantiations (`.heap` and `.embedded`) share
// one struct: `allocator` is null for embedded storage (the owner's memory;
// the final deref frees nothing) and a real allocator for heap storage (the
// final deref frees the box). In both cases the refcount starts at 1 (the
// creator holds a reference) and the final deref calls `finalize` to release
// the GPU resource. `ref`/`deref` take only the box, so instances flow through
// `TimelineDeferral`.
module rhi;
import std::atomic;

alias GpuRefFinalize <Type> = fn void(Type* inner, Device* device);

struct GpuRef <Type>
{
	uint references;
	Type inner;
	Device* device;
	GpuRefFinalize{Type} finalize;
	Allocator allocator;
}

// Heap-allocate a box. Refcount starts at 1; the final deref frees the box.
fn GpuRef{Type}*? gpu_ref_create(Device* device, Type value, GpuRefFinalize{Type} finalize, Allocator allocator = mem) <Type>
{
	GpuRef{Type}* result = alloc::new_try(allocator, GpuRef{Type})!;
	*result = {
		.references = 1,
		.inner = value,
		.device = device,
		.finalize = finalize,
		.allocator = allocator,
	};
	return result;
}

// Construct by value, no allocation. Refcount starts at 1; the final deref
// frees nothing. Must live at a stable address once shared: place it, then
// only `ref`/`deref` through a pointer — never copy it after the first ref.
fn GpuRef{Type} gpu_ref_init(Device* device, Type value, GpuRefFinalize{Type} finalize) <Type>
{
	return {
		.references = 1,
		.inner = value,
		.device = device,
		.finalize = finalize,
	};
}

// Whether any reference is still outstanding.
fn bool GpuRef.has_ref(&self)
{
	$if IS_WEB:
		return self.references > 0;
	$else
		return @atomic_load(self.references) > 0;
	$endif
}

fn void GpuRef.ref(&self)
{
	$if IS_WEB:
		self.references++;
	$else
		atomic::fetch_add(&self.references, 1u);
	$endif
}

fn void GpuRef.deref(&self)
{
	uint old;
	$if IS_WEB:
		old = self.references--;
	$else
		old = atomic::fetch_sub(&self.references, 1u);
	$endif
	if (old != 1) return;
	self.finalize(&self.inner, self.device);
	if (self.allocator) alloc::free(self.allocator, self);
}

// Enqueues the box in `td`, so it can flow through per-frame deferred release
// alongside plain resources.
fn void GpuRef.defer_into(&self, TimelineDeferral* td)
{
	td.enqueue_typed(self, &GpuRef{Type}.ref, &GpuRef{Type}.deref);
}

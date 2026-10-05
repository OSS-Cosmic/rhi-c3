// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

struct Fake @private
{
	uint* destroyed;
}

fn void fake_finalize(Fake* inner, Device* device) @private
{
	(*inner.destroyed)++;
}

fn void gpu_ref_heap_final_deref_finalizes_and_frees() @test
{
	Device dev;
	Device* device = &dev;
	uint destroyed = 0;

	// The test runner's leak checker proves the final deref frees the box.
	GpuRef{Fake}* r = gpu_ref_create{Fake}(device, { .destroyed = &destroyed }, &fake_finalize)!!;

	test::eq(r.references, 1u);

	r.ref();
	test::eq(r.references, 2u);

	r.deref();
	test::eq(destroyed, 0u);

	r.deref();
	test::eq(destroyed, 1u);
}

fn void gpu_ref_embedded_final_deref_finalizes_without_freeing() @test
{
	Device dev;
	Device* device = &dev;
	uint destroyed = 0;

	GpuRef{Fake} slot = gpu_ref_init{Fake}(device, { .destroyed = &destroyed }, &fake_finalize);
	test::eq(slot.references, 1u);

	slot.ref();
	test::eq(slot.references, 2u);

	slot.deref();
	test::eq(destroyed, 0u);

	slot.deref();
	test::eq(destroyed, 1u);
}

fn void gpu_ref_heap_flows_through_timeline_deferral() @test
{
	Device dev;
	Device* device = &dev;
	uint destroyed = 0;

	GpuRef{Fake}* r = gpu_ref_create{Fake}(device, { .destroyed = &destroyed }, &fake_finalize)!!;

	TimelineDeferral td;
	td.init();
	defer td.deinit();

	r.defer_into(&td);
	test::eq(r.references, 2u);

	td.seal(1);
	td.drain(1);
	test::eq(destroyed, 0u);
	test::eq(r.references, 1u);

	r.deref();
	test::eq(destroyed, 1u);
}

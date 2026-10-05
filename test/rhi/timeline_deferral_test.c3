// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

struct Resource @private
{
	int refs;
}

fn void resource_ref(void* data) @private
{
	Resource* r = data;
	r.refs++;
}

fn void resource_deref(void* data) @private
{
	Resource* r = data;
	r.refs--;
}

fn void timeline_deferral_drains_marked_items_when_their_frame_completes() @test
{
	TimelineDeferral td;
	td.init();
	defer td.deinit();

	Resource a, b, c;

	td.enqueue(&a, &resource_ref, &resource_deref);
	td.enqueue(&b, &resource_ref, &resource_deref);
	td.seal(1);

	td.enqueue(&c, &resource_ref, &resource_deref);
	td.seal(2);

	test::eq(a.refs, 1);
	test::eq(b.refs, 1);
	test::eq(c.refs, 1);

	td.drain(1);
	test::eq(a.refs, 0);
	test::eq(b.refs, 0);
	test::eq(c.refs, 1);
	test::eq(td.items.len(), 1);
	test::eq(td.batches.len(), 1);

	td.drain(2);
	test::eq(c.refs, 0);
	test::eq(td.items.len(), 0);
	test::eq(td.batches.len(), 0);
}

fn void timeline_deferral_drain_below_the_earliest_batch_is_a_no_op() @test
{
	TimelineDeferral td;
	td.init();
	defer td.deinit();

	Resource a, b;
	td.enqueue(&a, &resource_ref, &resource_deref);
	td.enqueue(&b, &resource_ref, &resource_deref);
	td.seal(5);

	td.drain(4);
	test::eq(a.refs, 1);
	test::eq(b.refs, 1);
	test::eq(td.items.len(), 2);
	test::eq(td.batches.len(), 1);
}

// C3 has no procedure-local types, so the heterogeneous test's types and
// callbacks live at module scope.
struct TestA @private
{
	int refs;
}

struct TestB @private
{
	int refs;
}

fn void test_a_ref(void* data) @private
{
	TestA* a = data;
	a.refs++;
}

fn void test_a_deref(void* data) @private
{
	TestA* a = data;
	a.refs--;
}

fn void test_b_ref(void* data) @private
{
	TestB* b = data;
	b.refs++;
}

fn void test_b_deref(void* data) @private
{
	TestB* b = data;
	b.refs--;
}

fn void timeline_deferral_releases_every_type_in_a_heterogeneous_batch() @test
{
	TimelineDeferral td;
	td.init();
	defer td.deinit();

	TestA a;
	TestB b;
	td.enqueue(&a, &test_a_ref, &test_a_deref);
	td.enqueue(&b, &test_b_ref, &test_b_deref);
	td.seal(1);

	test::eq(a.refs, 1);
	test::eq(b.refs, 1);

	td.drain(1);
	test::eq(a.refs, 0);
	test::eq(b.refs, 0);
	test::eq(td.items.len(), 0);
}

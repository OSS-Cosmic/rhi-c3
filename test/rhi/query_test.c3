// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

fn void query_type_granted_downgrades_without_precise() @test
{
	test::eq(query_type_granted(OCCLUSION, false), QueryType.OCCLUSION_BINARY);
	test::eq(query_type_granted(OCCLUSION, true), QueryType.OCCLUSION);
	test::eq(query_type_granted(OCCLUSION_BINARY, true), QueryType.OCCLUSION_BINARY);
	test::eq(query_type_granted(OCCLUSION_BINARY, false), QueryType.OCCLUSION_BINARY);
}

fn void query_pool_is_precise_follows_granted_type() @test
{
	QueryPool p = { .query_count = 4, .type = OCCLUSION };
	test::eq(query_pool_is_precise(&p), true);
	p.type = OCCLUSION_BINARY;
	test::eq(query_pool_is_precise(&p), false);
	test::eq(query_pool_is_empty(&p), false);
	QueryPool empty;
	test::eq(query_pool_is_empty(&empty), true);
}

fn void query_range_valid_rejects_out_of_range() @test
{
	test::eq(query_range_valid(8, 0, 8), true);
	test::eq(query_range_valid(8, 7, 1), true);
	test::eq(query_range_valid(8, 0, 0), false);
	test::eq(query_range_valid(8, 0, 9), false);
	test::eq(query_range_valid(8, 9, 1), false);
	test::eq(query_range_valid(8, 4, 0xFFFFFFFFu), false);
	test::eq(query_range_valid(8, 0xFFFFFFFFu, 2), false);
}

fn void query_range_resolved_covers_prefix() @test
{
	test::eq(query_range_resolved(4, 0, 4), true);
	test::eq(query_range_resolved(4, 2, 3), false);
	test::eq(query_range_resolved(0, 0, 1), false);
	test::eq(query_range_resolved(4, 0xFFFFFFFFu, 2), false);
}

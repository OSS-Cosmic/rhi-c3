// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

// The format table is data, and data rots silently. This walks every format so
// the table stays true.
fn void format_props_table_covers_every_format() @test
{
	foreach (f : Format::values)
	{
		FormatProperties props = format_get_props(f);
		test::eq(props.format, f);
		if (f == Format.UNKNOWN)
		{
			test::eq(props.stride, 0u);
			continue;
		}
		String tag = Format::names[f.ordinal].to_lower_tcopy();
		test::eq(props.name, tag);
		test::@check(props.stride > 0);
		test::@check(props.block_width >= 1);
		test::@check(props.block_height >= 1);
		// Only a block-compressed format covers more than one texel per block.
		if (!props.is_compressed)
		{
			test::eq(props.block_width, 1u);
			test::eq(props.block_height, 1u);
		}
	}
}

fn void next_cookie_is_monotonic_and_nonzero() @test
{
	ulong a = next_cookie();
	ulong b = next_cookie();
	test::@check(a != 0);
	test::@check(b > a);
}

fn void time_keeper_snaps_to_60hz() @test
{
	TimeKeeper step = { .tocks_per_s = 1_000_000 };
	step.produce(0);
	test::@check(!step.consume());
	// 16_667us is within tolerance of a 60 Hz frame: exactly one update.
	step.produce(16_667);
	test::@check(step.consume());
	test::@check(!step.consume());
}

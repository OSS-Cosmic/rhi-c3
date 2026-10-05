// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

fn void descriptor_name_hash_is_fnv1a_64() @test
{
	// The empty string hashes to the FNV-1a 64 offset basis.
	test::eq(descriptor_name_hash(""), 14695981039346656037ul);
	test::eq(descriptor_name_hash("a"), 0xaf63dc4c8601ec8cul);
}

fn void descriptor_cookie_empty_resource_is_empty() @test
{
	test::eq(descriptor_cookie(0, UNIFORM_BUFFER, 16, 256), 0ul);
	test::eq(descriptor_cookie(0, SAMPLED_IMAGE, 0, 0), 0ul);
}

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;
import std::core::test;

fn void pogo_next_index_alternates() @test
{
	test::eq(pogo_next_index(0), 1);
	test::eq(pogo_next_index(1), 0);
}

fn void pogo_shader_barrier_contents() @test
{
	Image img;
	ImageBarrier b = pogo_shader_barrier(&img, false);
	test::eq(b.image == &img, true);
	test::eq(b.before.render_target, true);
	test::eq(b.before.shader_resource, false);
	test::eq(b.after.shader_resource, true);
	test::eq(b.after.render_target, false);
	test::eq(b.after_stages.fragment, true);
	test::eq(b.before_stages == (BarrierStages){}, true);

	ImageBarrier init = pogo_shader_barrier(&img, true);
	test::eq(init.before == (ResourceState){}, true);
	test::eq(init.after.shader_resource, true);
}

fn void pogo_attachment_barrier_contents() @test
{
	Image img;
	ImageBarrier b = pogo_attachment_barrier(&img, false);
	test::eq(b.image == &img, true);
	test::eq(b.before.shader_resource, true);
	test::eq(b.before_stages.fragment, true);
	test::eq(b.after.render_target, true);
	test::eq(b.after_stages == (BarrierStages){}, true);

	ImageBarrier init = pogo_attachment_barrier(&img, true);
	test::eq(init.before == (ResourceState){}, true);
	test::eq(init.before_stages == (BarrierStages){}, true);
	test::eq(init.after.render_target, true);
}

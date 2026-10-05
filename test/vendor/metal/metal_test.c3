// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Port of rhi-zig deps/metal/src/root.zig's smoke test. Only built for
// Darwin (macOS arm64, see c3/src/vendor/metal/wrapper.c3); on other hosts
// `c3c test -C --target macos-aarch64` still type-checks it.
module mtl @feat(DARWIN);
import std::core::test;
import std::os::macos::objc;

// Layouts of the POD structs passed by value through objc_msgSend, from the
// arm64 Apple headers (NSUInteger and CGFloat are 8 bytes).
$assert Viewport::size == 48;
$assert ScissorRect::size == 32;
$assert ClearColor::size == 32;
$assert Region::size == 48;
$assert Size::size == 24;
$assert Origin::size == 24;
$assert CGSize::size == 16;
$assert NSRange::size == 16;

const ZString SMOKE_SHADER = `
#include <metal_stdlib>
using namespace metal;
vertex float4 smoke_vs(uint vid [[vertex_id]]) { return float4(0.0, 0.0, 0.0, 1.0); }
`;

// Device, name, queue, shared buffer write/read-back and a CAMetalLayer
// round-trip. A device may be absent in a headless CI VM; the test then
// passes without checking anything.
fn void smoke_device_buffer_layer() @test
{
	objc::@autoreleasepool()
	{
		Device device = create_system_default_device();
		if (device == null) return;
		defer device.release();

		// Reading a real property proves selector dispatch and the NSString
		// round-trip.
		ZString name = device.name().utf8();
		test::eq(name.len() > 0, true);

		CommandQueue queue = device.new_command_queue();
		test::eq(queue != null, true);
		defer queue.release();

		Buffer buffer = device.new_buffer(256, RESOURCE_STORAGE_MODE_SHARED);
		test::eq(buffer != null, true);
		defer buffer.release();
		test::eq(buffer.length(), (NSUInteger)256);

		uint* words = (uint*)buffer.contents();
		for (uint i = 0; i < 64; i++) words[i] = i * 3;
		uint* read_back = (uint*)buffer.contents();
		test::eq(read_back[0], 0u);
		test::eq(read_back[63], 189u);

		// Class-method factory + struct-argument selector (the ABI path).
		CAMetalLayer layer = ca_metal_layer();
		layer.set_device(device);
		layer.set_pixel_format(PixelFormat.BGRA8UNORM);
		layer.set_drawable_size({ .width = 64, .height = 64 });
		test::eq((NSUInteger)layer.pixel_format(), (NSUInteger)PixelFormat.BGRA8UNORM);

		// Struct-return selector (CGSize) over msgSend.
		CGSize size = layer.drawable_size();
		test::eq(size.width, 64.0);
	};
}

// newLibraryWithSource:options:error: on a trivial MSL library, then
// newFunctionWithName: for its one function.
fn void smoke_library_function() @test
{
	objc::@autoreleasepool()
	{
		Device device = create_system_default_device();
		if (device == null) return;
		defer device.release();

		NSError err;
		Library library = device.new_library_with_source(ns_string_from_utf8(SMOKE_SHADER), null, &err);
		if (library == null)
		{
			test::eq(err != null, true);
			abort("newLibraryWithSource failed: %s", err.localized_description().utf8());
		}
		defer library.release();

		Function function = library.new_function(ns_string_from_utf8("smoke_vs"));
		test::eq(function != null, true);
		defer function.release();

		Function missing = library.new_function(ns_string_from_utf8("no_such_function"));
		test::eq(missing == null, true);
	};
}

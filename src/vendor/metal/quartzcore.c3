// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// QuartzCore (CA) bindings, ported from rhi-zig
// deps/metal/src/quartzcore.zig: CAMetalLayer and CAMetalDrawable, the bridge
// between a window surface and Metal. Mirrors metal-cpp/QuartzCore. See
// wrapper.c3 for conventions and ownership.
module mtl @feat(DARWIN) @link(env::DARWIN, "QuartzCore.framework");
import std::os::macos::objc;

// -- CAMetalLayer ----------------------------------------------------------

typedef CAMetalLayer @constinit = inline void*;

fn void CAMetalLayer.retain(self) => retain(self);
fn void CAMetalLayer.release(self) => objc::release(self);

// +[CAMetalLayer layer] — a fresh autoreleased layer.
fn CAMetalLayer ca_metal_layer() => @class_msg_object(CAMetalLayer, "CAMetalLayer", "layer");

// -setDevice: — the Metal device the layer draws with.
fn void CAMetalLayer.set_device(self, Device device) => objc::msg_send(self, MsgVoidId, "setDevice:", device);

// -setPixelFormat:.
fn void CAMetalLayer.set_pixel_format(self, PixelFormat format) => objc::msg_send(self, MsgVoidUint, "setPixelFormat:", format);

// -pixelFormat.
fn PixelFormat CAMetalLayer.pixel_format(self) => (PixelFormat)objc::msg_send(self, MsgUint, "pixelFormat");

// -setDrawableSize:.
fn void CAMetalLayer.set_drawable_size(self, CGSize size) => objc::msg_send(self, MsgVoidCGSize, "setDrawableSize:", size);

// -drawableSize. Struct return: arm64 only (see wrapper.c3).
fn CGSize CAMetalLayer.drawable_size(self) => objc::msg_send(self, MsgCGSize, "drawableSize");

// -setMaximumDrawableCount: — 2 or 3.
fn void CAMetalLayer.set_maximum_drawable_count(self, NSUInteger count)
{
	objc::msg_send(self, MsgVoidUint, "setMaximumDrawableCount:", count);
}

// -setDisplaySyncEnabled: — false presents immediately (no vsync).
fn void CAMetalLayer.set_display_sync_enabled(self, bool enabled)
{
	objc::msg_send(self, MsgVoidBool, "setDisplaySyncEnabled:", enabled);
}

// -nextDrawable (autoreleased). Null if no drawable became available before
// the timeout.
fn CAMetalDrawable CAMetalLayer.next_drawable(self) => (CAMetalDrawable)objc::msg_send(self, MsgId, "nextDrawable");

// -- CAMetalDrawable (conforms to MTLDrawable) -----------------------------

typedef CAMetalDrawable @constinit = inline void*;

fn void CAMetalDrawable.retain(self) => retain(self);
fn void CAMetalDrawable.release(self) => objc::release(self);

// -texture — the renderable texture backing this drawable.
fn Texture CAMetalDrawable.texture(self) => (Texture)objc::msg_send(self, MsgId, "texture");

// The underlying id to hand to CommandBuffer.present_drawable.
fn ObjcId CAMetalDrawable.id(self) => (ObjcId)self;

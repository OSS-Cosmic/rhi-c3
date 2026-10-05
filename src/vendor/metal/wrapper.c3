// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// C3 bindings for Metal / Foundation / QuartzCore, ported from rhi-zig
// deps/metal/src (wrapper.zig, metal.zig, foundation.zig, quartzcore.zig,
// types.zig). This file holds the shared plumbing (wrapper.zig) and links
// libobjc; metal.c3, foundation.c3 and quartzcore.c3 hold the classes and
// link their frameworks, types.c3 holds the POD structs and enums.
//
// Every class is modelled the way metal-cpp models it: a typed view over an
// `objc_object*`, here `typedef Device @constinit = inline void*;` (distinct,
// compare with null). Each method forwards one message through
// objc::msg_send with the selector named in the matching Apple header.
// Methods are the selector in snake case: -newCommandQueue is
// Device.new_command_queue. C3 has no static methods, so class messages are
// module functions: alloc+init is new_<type>() (new_texture_descriptor()),
// class factories are named after the selector with the class as prefix
// where needed (render_pass_descriptor(), ca_metal_layer(),
// ns_string_from_utf8()).
//
// Ownership mirrors Cocoa. Anything returned from a new* / alloc+init / *Copy*
// call is owned by the caller (retain count 1): release it
// (`defer device.release();`). Property getters (name, nextDrawable,
// colorAttachments, ...) and class factories (+layer, +renderPassDescriptor)
// return autoreleased objects the caller does not own; retain() only to keep
// them past the current objc::@autoreleasepool. Calls that can fail return
// null.
//
// macOS arm64 only. objc_msgSend is called through a cast function pointer,
// which is only correct where no struct return needs objc_msgSend_stret
// (x86_64 returns large structs through that variant) and no float return
// needs objc_msgSend_fpret (i386). Selectors returning MTLSize / CGSize
// (Device.max_threads_per_threadgroup, CAMetalLayer.drawable_size) rely on
// this, so the module refuses to build for anything but AArch64.
module mtl @feat(DARWIN) @link(env::DARWIN, "objc");
import std::os::macos::objc;

$assert env::AARCH64 : "mtl: only macOS arm64 is supported; x86_64 would need objc_msgSend_stret for struct returns";

alias ObjcId = objc::ObjcId;
alias ObjcClass = objc::ObjcClass;
alias ObjcSelector = objc::ObjcSelector;

// objc_msgSend signatures, one per ABI shape: Msg<return><args...>, where Id
// is any object (or raw pointer), Uint is NSUInteger (also uint64_t on
// arm64), Ptr an `id*` out-parameter. Wrapped handles convert implicitly to
// ObjcId and enums to NSUInteger, so the typed methods stay the API surface.
alias MsgId = fn ObjcId(ObjcId, ObjcSelector);
alias MsgIdId = fn ObjcId(ObjcId, ObjcSelector, ObjcId);
alias MsgIdUint = fn ObjcId(ObjcId, ObjcSelector, NSUInteger);
alias MsgIdUintUint = fn ObjcId(ObjcId, ObjcSelector, NSUInteger, NSUInteger);
alias MsgIdIdUintUint = fn ObjcId(ObjcId, ObjcSelector, ObjcId, NSUInteger, NSUInteger);
alias MsgIdIdPtr = fn ObjcId(ObjcId, ObjcSelector, ObjcId, ObjcId*);
alias MsgIdIdIdPtr = fn ObjcId(ObjcId, ObjcSelector, ObjcId, ObjcId, ObjcId*);
alias MsgIdUintUintUintBool = fn ObjcId(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSUInteger, bool);
alias MsgIdUintUintRangeRange = fn ObjcId(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSRange, NSRange);
alias MsgZStr = fn ZString(ObjcId, ObjcSelector);
alias MsgUint = fn NSUInteger(ObjcId, ObjcSelector);
alias MsgInt = fn NSInteger(ObjcId, ObjcSelector);
alias MsgBool = fn bool(ObjcId, ObjcSelector);
alias MsgCGSize = fn CGSize(ObjcId, ObjcSelector);
alias MsgSize = fn Size(ObjcId, ObjcSelector);
alias MsgVoid = fn void(ObjcId, ObjcSelector);
alias MsgVoidId = fn void(ObjcId, ObjcSelector, ObjcId);
alias MsgVoidUint = fn void(ObjcId, ObjcSelector, NSUInteger);
alias MsgVoidBool = fn void(ObjcId, ObjcSelector, bool);
alias MsgVoidFloat = fn void(ObjcId, ObjcSelector, float);
alias MsgVoidDouble = fn void(ObjcId, ObjcSelector, double);
alias MsgVoidCGSize = fn void(ObjcId, ObjcSelector, CGSize);
alias MsgVoidViewport = fn void(ObjcId, ObjcSelector, Viewport);
alias MsgVoidScissorRect = fn void(ObjcId, ObjcSelector, ScissorRect);
alias MsgVoidClearColor = fn void(ObjcId, ObjcSelector, ClearColor);
alias MsgVoidIdUint = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger);
alias MsgVoidIdUintUint = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger, NSUInteger);
alias MsgVoidUintUintUint = fn void(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSUInteger);
alias MsgVoidUintUintUintUintUint = fn void(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSUInteger, NSUInteger, NSUInteger);
alias MsgVoidUintIdUint = fn void(ObjcId, ObjcSelector, NSUInteger, ObjcId, NSUInteger);
alias MsgVoidUintUintUintIdUint = fn void(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSUInteger, ObjcId, NSUInteger);
alias MsgVoidUintUintUintIdUintUintIntUint = fn void(ObjcId, ObjcSelector, NSUInteger, NSUInteger, NSUInteger, ObjcId, NSUInteger, NSUInteger, NSInteger, NSUInteger);
alias MsgVoidUintUintIdUintIdUint = fn void(ObjcId, ObjcSelector, NSUInteger, NSUInteger, ObjcId, NSUInteger, ObjcId, NSUInteger);
alias MsgVoidIdUintIdUintUint = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger, ObjcId, NSUInteger, NSUInteger);
alias MsgVoidIdUintUintUintSizeIdUintUintOrigin = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger, NSUInteger, NSUInteger, Size, ObjcId, NSUInteger, NSUInteger, Origin);
alias MsgVoidIdUintUintOriginSizeIdUintUintUint = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger, NSUInteger, Origin, Size, ObjcId, NSUInteger, NSUInteger, NSUInteger);
alias MsgVoidIdUintUintOriginSizeIdUintUintOrigin = fn void(ObjcId, ObjcSelector, ObjcId, NSUInteger, NSUInteger, Origin, Size, ObjcId, NSUInteger, NSUInteger, Origin);

// Look up a registered Objective-C class by name. Aborts if it is missing:
// the system frameworks are linked, so a miss means a typo in the name.
fn ObjcClass class_named(ZString name)
{
	ObjcClass cls = objc::getClass(name);
	if (!cls) abort("objc class not found: %s", name);
	return cls;
}

// +alloc then -init on `$class_name`, typed as $Type. Owned by the caller.
// Used for descriptor objects (MTLRenderPipelineDescriptor, ...).
macro @alloc_init($Type, ZString $class_name)
{
	ObjcId allocated = objc::alloc(class_named($class_name));
	return ($Type)objc::msg_send(allocated, MsgId, "init");
}

// Send a class (static) message with no arguments whose result is an object,
// typed as $Type. Null when the result is nil.
macro @class_msg_object($Type, ZString $class_name, ZString $selector)
{
	return ($Type)objc::msg_send(class_named($class_name), MsgId, $selector);
}

// -retain on any wrapped object; the result (the receiver) is dropped.
macro void retain(obj) => (void)objc::msg_send(obj, MsgId, "retain");

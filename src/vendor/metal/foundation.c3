// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Foundation (NS) bindings, ported from rhi-zig deps/metal/src/foundation.zig:
// the minimal slice the Metal layer needs (strings for shader source, labels
// and device names; error out-parameters; arrays). Mirrors the relevant parts
// of metal-cpp/Foundation. See wrapper.c3 for conventions and ownership.
module mtl @feat(DARWIN) @link(env::DARWIN, "Foundation.framework");
import std::os::macos::objc;

// NSUTF8StringEncoding (NSString.h).
const NSUInteger NS_UTF8_STRING_ENCODING = 4;

// NSRange (NSRange.h).
struct NSRange
{
	NSUInteger location;
	NSUInteger length;
}

// -- NSString --------------------------------------------------------------

typedef NSString @constinit = inline void*;

// +[NSString stringWithUTF8String:] — autoreleased NSString from a
// NUL-terminated UTF-8 string.
fn NSString ns_string_from_utf8(ZString text)
{
	return (NSString)objc::msg_send(class_named("NSString"), MsgIdId, "stringWithUTF8String:", (void*)text);
}

// +[NSString stringWithBytes:length:encoding:] (NSUTF8StringEncoding) —
// autoreleased NSString from a UTF-8 byte slice that need not be NUL-terminated.
fn NSString ns_string_from_utf8_slice(char[] bytes)
{
	return (NSString)objc::msg_send(class_named("NSString"), MsgIdIdUintUint, "stringWithBytes:length:encoding:", bytes.ptr, (NSUInteger)bytes.len, NS_UTF8_STRING_ENCODING);
}

// -UTF8String. The pointer is owned by the NSString; copy it to outlive the
// receiver.
fn ZString NSString.utf8(self) => objc::msg_send(self, MsgZStr, "UTF8String");

// -length (number of UTF-16 code units).
fn NSUInteger NSString.length(self) => objc::msg_send(self, MsgUint, "length");

fn void NSString.retain(self) => retain(self);
fn void NSString.release(self) => objc::release(self);

// -- NSError ---------------------------------------------------------------

// Typically received through the out-parameter of a failing *error: call.
typedef NSError @constinit = inline void*;

// -localizedDescription (autoreleased), a human-readable message.
fn NSString NSError.localized_description(self) => (NSString)objc::msg_send(self, MsgId, "localizedDescription");

// -code.
fn NSInteger NSError.code(self) => objc::msg_send(self, MsgInt, "code");

fn void NSError.retain(self) => retain(self);
fn void NSError.release(self) => objc::release(self);

// -- NSArray ---------------------------------------------------------------

typedef NSArray @constinit = inline void*;

// -count.
fn NSUInteger NSArray.count(self) => objc::msg_send(self, MsgUint, "count");

// -objectAtIndex:, typed as $Type (not owned).
macro NSArray.object_at_index(self, $Type, NSUInteger index)
{
	return ($Type)objc::msg_send(self, MsgIdUint, "objectAtIndex:", index);
}

fn void NSArray.retain(self) => retain(self);
fn void NSArray.release(self) => objc::release(self);

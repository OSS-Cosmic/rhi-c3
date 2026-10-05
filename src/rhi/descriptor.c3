// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;

// Descriptors are values rather than backend descriptor-set objects. The
// handle is consumed later by the WebGPU bind-group/GL replay code, or by the
// Vulkan descriptor-set writer. On Vulkan the image layout is not stored: the
// consumer picks it from `type` (`.Sampled_Image` -> SHADER_READ_ONLY_OPTIMAL,
// `.Storage_Image` -> GENERAL).
struct Descriptor
{
	// Unique id / descriptor-set cache key (0 == empty). Derived from the
	// referenced resource's own cookie folded with the binding parameters, so a
	// descriptor changes identity whenever the resource or its binding does,
	// and a resource with cookie 0 (uncreated) yields an empty descriptor.
	ulong cookie;
	// Backend-neutral descriptor category.
	DescriptorType type;
	// Resolved backend handle. On browser backends: a texture view / texture,
	// sampler or buffer id. On Vulkan: the raw non-dispatchable handle cast to
	// u64 (VkBuffer / VkImageView / VkSampler); on Metal, an Objective-C
	// object pointer cast to u64.
	ulong handle;
	ulong offset;
	ulong range;
}

// Stable identity for a named descriptor binding. The hash is what the binders
// look up; the name is kept for diagnostics.
struct DescriptorBindingID
{
	String name;
	ulong hash;
}

// A live binding handed to a binder: a name handle + the descriptor to write
// at it, optionally offset within an array.
struct DescriptorBinding
{
	DescriptorBindingID handle;
	uint register_offset;
	Descriptor descriptor;
}

// FNV-1a is deliberately kept here instead of depending on a backend or a
// runtime hash seed: shader binding IDs must be stable across wasm modules.
// The Zig reference uses Wyhash, so hashes are not identical across the two
// implementations; only names are comparable between them.
fn ulong descriptor_name_hash(String name)
{
	ulong h = 14695981039346656037;
	foreach (c : name)
	{
		h ^= (ulong)c;
		h *= 1099511628211;
	}
	return h;
}

fn DescriptorBindingID descriptor_binding_id(String name)
{
	return { .name = name, .hash = descriptor_name_hash(name) };
}

fn DescriptorBinding descriptor_binding(String name, Descriptor descriptor, uint register_offset)
{
	return {
		.handle = descriptor_binding_id(name),
		.register_offset = register_offset,
		.descriptor = descriptor,
	};
}

// Fold a resource cookie + binding params into the descriptor's identity
// cookie. A 0 resource cookie passes through as 0 (empty), and the result is
// nudged off 0 so a non-empty descriptor never aliases the empty sentinel.
fn ulong descriptor_cookie(ulong resource_cookie, DescriptorType kind, ulong a, ulong b)
{
	if (resource_cookie == 0) return 0;
	// SplitMix-style avalanche over all binding parameters. It is not used for
	// security; it only prevents descriptor cache keys from colliding with the
	// resource cookie when offset/range/view changes.
	ulong h = resource_cookie ^ ((ulong)kind.ordinal * 0x9e3779b97f4a7c15) ^ (a * 0xbf58476d1ce4e5b9) ^ (b * 0x94d049bb133111eb);
	h ^= h >> 30;
	h *= 0xbf58476d1ce4e5b9;
	h ^= h >> 27;
	h *= 0x94d049bb133111eb;
	h ^= h >> 31;
	if (h == 0) return 1;
	return h;
}

fn bool descriptor_is_empty(Descriptor d)
{
	return d.cookie == 0;
}

fn ulong descriptor_buffer_size(Buffer* b)
{
	if (b == null || b.cookie == 0) return 0;
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU:
				return (ulong)b.backend.wgpu.size;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return (ulong)b.backend.webgl.size;
			$endif
		case VK:
			$if HAS_VK:
				return b.backend.vk.size;
			$endif
		case MTL:
			$if HAS_MTL:
				return b.backend.mtl.size;
			$endif
		case DX12:
			break;
	}
	return 0;
}

// Buffer range descriptor. An empty or out-of-bounds range yields an empty
// descriptor.
fn Descriptor descriptor_buffer(Buffer* b, DescriptorType kind, ulong offset, ulong range)
{
	if (kind != UNIFORM_BUFFER && kind != STORAGE_BUFFER) return {};
	ulong size = descriptor_buffer_size(b);
	if (size == 0 || range == 0 || offset > size || range > size - offset) return {};
	ulong handle = 0;
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU:
				handle = (ulong)b.backend.wgpu.buffer;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				handle = (ulong)b.backend.webgl.buffer;
			$endif
		case VK:
			$if HAS_VK:
				handle = (ulong)b.backend.vk.buffer;
			$endif
		case MTL:
			$if HAS_MTL:
				handle = (ulong)b.backend.mtl.buffer;
			$endif
		case DX12:
			break;
	}
	if (handle == 0) return {};
	return {
		.cookie = descriptor_cookie(b.cookie, kind, offset, range),
		.type = kind,
		.handle = handle,
		.offset = offset,
		.range = range,
	};
}

fn Descriptor descriptor_uniform_buffer(Buffer* b, ulong offset, ulong range)
{
	return descriptor_buffer(b, UNIFORM_BUFFER, offset, range);
}

fn Descriptor descriptor_storage_buffer(Buffer* b, ulong offset, ulong range)
{
	return descriptor_buffer(b, STORAGE_BUFFER, offset, range);
}

// Image view descriptor. Only `.Sampled_Image` and `.Storage_Image` are image
// kinds; anything else yields an empty descriptor. The cookie comes from the
// view's own cookie, so distinct views of one image get distinct descriptors.
fn Descriptor descriptor_image(ImageView* v, DescriptorType kind)
{
	if (kind != SAMPLED_IMAGE && kind != STORAGE_IMAGE) return {};
	if (v == null || v.cookie == 0) return {};
	Descriptor d = {
		.cookie = descriptor_cookie(v.cookie, kind, 0, 0),
		.type = kind,
	};
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU:
				d.handle = (ulong)v.backend.wgpu.view;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				d.handle = (ulong)v.backend.webgl.texture;
			$endif
		case VK:
			$if HAS_VK:
				d.handle = (ulong)v.backend.vk.view;
			$endif
		case DX12:
			return {};
		case MTL:
			$if HAS_MTL:
				d.handle = (ulong)v.backend.mtl.texture;
			$endif
	}
	return d;
}

// Sampled (read-only) image.
fn Descriptor descriptor_sampled_image(ImageView* v)
{
	return descriptor_image(v, SAMPLED_IMAGE);
}

// Read/write storage image.
fn Descriptor descriptor_storage_image(ImageView* v)
{
	return descriptor_image(v, STORAGE_IMAGE);
}

fn Descriptor descriptor_sampler(Sampler* s)
{
	if (s == null || s.cookie == 0) return {};
	Descriptor d = {
		.cookie = descriptor_cookie(s.cookie, SAMPLER, 0, 0),
		.type = SAMPLER,
	};
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU:
				d.handle = (ulong)s.backend.wgpu.sampler;
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				d.handle = (ulong)s.backend.webgl.sampler;
			$endif
		case VK:
			$if HAS_VK:
				d.handle = (ulong)s.backend.vk.sampler;
			$endif
		case DX12:
			return {};
		case MTL:
			$if HAS_MTL:
				d.handle = (ulong)s.backend.mtl.state;
			$endif
	}
	return d;
}

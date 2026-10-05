// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal buffer. Port of the `.mtl` arms of rhi-zig's `buffer.zig`
// `initGeneral`/`deinit`.
//
// Shared storage is CPU-visible and always mapped, so `mapped_region` points
// straight at the buffer's contents (no staging/blit needed on Apple Silicon).
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct BufferMtl
{
	// Owned: +1 from -newBufferWithLength:options:.
	mtl::Buffer buffer;
	ulong size;
	bool shared;
}

fn Buffer? buffer_init_general_mtl(Device* device, BufferDesc desc)
{
	if (desc.size <= 0) return UNSUPPORTED_FEATURE~;
	if ((ulong)desc.size > device.adapter.buffer_max_size) return UNSUPPORTED_FEATURE~;
	// rhi-zig always uses StorageModeShared. Extension: PREFER_DEVICE maps to
	// StorageModePrivate (GPU-only, no host mapping; fill it with a blit).
	bool shared = desc.buffer_usage != PREFER_DEVICE;
	mtl::ResourceOptions options = shared ? mtl::RESOURCE_STORAGE_MODE_SHARED : mtl::RESOURCE_STORAGE_MODE_PRIVATE;
	mtl::Buffer buffer = device.backend.mtl.device.new_buffer((NSUInteger)desc.size, options);
	if (!buffer) return OUT_OF_DEVICE_MEMORY~;
	char[] mapped_region;
	if (shared)
	{
		char* contents = (char*)buffer.contents();
		if (contents)
		{
			mapped_region = contents[:desc.size];
		}
		else
		{
			buffer.release();
			return INITIALIZATION_FAILED~;
		}
	}
	return {
		.cookie = next_cookie(),
		.mapped_region = mapped_region,
		.backend.mtl = { .buffer = buffer, .size = (ulong)desc.size, .shared = shared },
	};
}

fn void buffer_deinit_mtl(Buffer* b, Device* device)
{
	if (b.backend.mtl.buffer) b.backend.mtl.buffer.release();
	b.backend.mtl = {};
}

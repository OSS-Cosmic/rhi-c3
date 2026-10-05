// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal renderer. Port of the `.mtl` arm of rhi-zig's `renderer.zig`
// `Renderer.init`.
//
// Metal has no instance object: an `MTLDevice` is created per adapter by
// `device_init`, so the renderer only records that Metal is the selected
// backend.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct RendererMtl
{
	char _unused;
}

fn void? renderer_init_mtl(RendererMtlOptions opts, Allocator allocator = mem)
{
	renderer = {
		.backend = MTL,
		.mtl = {},
	};
}

fn void renderer_deinit_mtl()
{
}

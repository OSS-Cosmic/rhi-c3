// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal has no binary semaphores; GPU-GPU synchronization uses timelines
// (MTLSharedEvent) instead. Keep this separate from the swapchain.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct SemaphoreMtl { char _unused; }

fn Semaphore? semaphore_init_mtl(Device* device)
{
	return UNSUPPORTED_FEATURE~;
}

fn void semaphore_deinit_mtl(Semaphore* s, Device* device)
{
}

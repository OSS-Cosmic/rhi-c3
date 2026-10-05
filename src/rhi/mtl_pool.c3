// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal has no command-pool object. PoolMtl is deliberately empty; the
// command ring still keeps the pool lifetime parallel with the other RHI
// backends and owns the command-buffer handles through CmdMtl.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);

struct PoolMtl { char _unused; }

fn Pool? pool_init_mtl(Device* device, Queue* queue)
{
	return { .backend.mtl = { ._unused = 0 } };
}

fn void? pool_reset_mtl(Pool* pool, Device* device)
{
	return;
}

fn void pool_deinit_mtl(Pool* pool, Device* device)
{
}

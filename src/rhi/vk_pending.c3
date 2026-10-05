// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Temporary stand-ins for the remaining Vulkan backend pieces.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

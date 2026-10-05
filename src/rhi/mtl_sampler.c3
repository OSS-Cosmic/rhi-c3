// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal sampler. New: rhi-zig's `.mtl` sampler arm is void. Follows the Vulkan
// backend: the compare function is mapped directly, with NEVER disabling comparison, and without
// `set_lod_range` the LOD clamps stay at Metal's defaults (0, FLT_MAX).
//
// MTLSamplerDescriptor has no LOD bias, so a non-zero `mip_lod_bias` cannot be
// represented by this backend and is rejected instead of being silently lost.
// SamplerDesc has no border color; CLAMP_TO_BORDER uses Metal's transparent
// black border color.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

const float MTL_MAX_ANISOTROPY = 16;

struct SamplerMtl
{
	// Owned: +1 from -newSamplerStateWithDescriptor:.
	mtl::SamplerState state;
}

fn Sampler? sampler_init_mtl(Device* device, SamplerDesc desc)
{
	if (desc.mip_lod_bias != 0) return UNSUPPORTED_FEATURE~;

	// Metal rejects lodMaxClamp < lodMinClamp; report it like the browser
	// backends do.
	if (desc.set_lod_range && !(desc.max_lod >= desc.min_lod)) return UNSUPPORTED_FEATURE~;

	// Values <= 1 and NaN retain Metal's default anisotropy of 1.
	NSUInteger anisotropy = 1;
	if (desc.max_anisotropy > 1)
	{
		anisotropy = desc.max_anisotropy >= MTL_MAX_ANISOTROPY ? (NSUInteger)MTL_MAX_ANISOTROPY : (NSUInteger)desc.max_anisotropy;
	}

	mtl::SamplerDescriptor sd = mtl::new_sampler_descriptor();
	if (!sd) return OUT_OF_DEVICE_MEMORY~;
	sd.set_min_filter(mtl_sampler_min_mag_filter(desc.min_filter));
	sd.set_mag_filter(mtl_sampler_min_mag_filter(desc.mag_filter));
	sd.set_mip_filter(mtl_sampler_mip_filter(desc.mip_map_mode));
	sd.set_s_address_mode(mtl_sampler_address_mode(desc.address_u));
	sd.set_t_address_mode(mtl_sampler_address_mode(desc.address_v));
	sd.set_r_address_mode(mtl_sampler_address_mode(desc.address_w));
	sd.set_max_anisotropy(anisotropy);
	if (desc.set_lod_range)
	{
		sd.set_lod_min_clamp(desc.min_lod);
		sd.set_lod_max_clamp(desc.max_lod);
	}
	sd.set_compare_function(mtl_sampler_compare_function(desc.compare_func));
	sd.set_normalized_coordinates(true);
	sd.set_border_color(mtl::SamplerBorderColor.TRANSPARENT_BLACK);

	mtl::SamplerState state = device.backend.mtl.device.new_sampler_state(sd);
	sd.release();
	if (!state) return OUT_OF_DEVICE_MEMORY~;
	return {
		.cookie = next_cookie(),
		.backend.mtl = { .state = state },
	};
}

fn void sampler_deinit_mtl(Sampler* s, Device* device)
{
	if (s.backend.mtl.state) s.backend.mtl.state.release();
	s.backend.mtl = {};
}

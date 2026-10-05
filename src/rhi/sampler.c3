// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;

enum SamplerFilter : char { NEAREST, LINEAR }
enum SamplerMipmap : char { NEAREST, LINEAR }
enum SamplerAddress : char { MIRROR, REPEAT, CLAMP_TO_EDGE, CLAMP_TO_BORDER }
enum SamplerCompare : char { NEVER, LESS, EQUAL, LESS_EQUAL, GREATER, NOT_EQUAL, GREATER_EQUAL, ALWAYS }

// Short aliases keep the public vocabulary close to the source RHI names.
alias FilterType = SamplerFilter;
alias MipmapMode = SamplerMipmap;
alias AddressMode = SamplerAddress;
alias CompareMode = SamplerCompare;

// Browser backends (WebGPU, WebGL2) reject `Clamp_To_Border` with
// `.Unsupported_Feature`: neither API has a border color, and the mode is
// reported rather than substituted. An inverted LOD range (`set_lod_range` with
// `max_lod < min_lod`) is rejected the same way.
struct SamplerDesc
{
	SamplerFilter min_filter;
	SamplerFilter mag_filter;
	SamplerMipmap mip_map_mode;
	SamplerAddress address_u;
	SamplerAddress address_v;
	SamplerAddress address_w;
	float mip_lod_bias;
	bool set_lod_range;
	float min_lod;
	float max_lod;
	float max_anisotropy;
	SamplerCompare compare_func;
}

struct Sampler
{
	ulong cookie;
	union backend
	{
		SamplerWgpu wgpu;
		SamplerWebgl webgl;
		SamplerDx12 dx12;
		SamplerVk vk;
		SamplerMtl mtl;
	}
}

fn Sampler? sampler_init(Device* device, SamplerDesc desc)
{
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU: return sampler_init_wgpu(device, desc); $endif
		case WEBGL:
			$if HAS_WEBGL: return sampler_init_webgl(device, desc); $endif
		case DX12:
			$if HAS_DX12: return sampler_init_dx12(device, desc); $endif
		case VK:
			$if HAS_VK: return sampler_init_vk(device, desc); $endif
		case MTL:
			$if HAS_MTL: return sampler_init_mtl(device, desc); $endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void sampler_deinit(Sampler* s, Device* device)
{
	if (s == null || s.cookie == 0) return;
	switch (renderer.backend)
	{
		case WGPU:
			$if HAS_WGPU: sampler_deinit_wgpu(s, device); $endif
		case WEBGL:
			$if HAS_WEBGL: sampler_deinit_webgl(s, device); $endif
		case DX12:
			$if HAS_DX12: sampler_deinit_dx12(s, device); $endif
		case VK:
			$if HAS_VK: sampler_deinit_vk(s, device); $endif
		case MTL:
			$if HAS_MTL: sampler_deinit_mtl(s, device); $endif
	}
	s.cookie = 0;
}

fn bool sampler_is_empty(Sampler* s) { return s == null || s.cookie == 0; }

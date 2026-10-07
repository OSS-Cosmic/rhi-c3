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

// ---- metal ----

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

// ---- dx12 ----

// Direct3D 12 sampler. Follows the Vulkan backend: the compare function maps
// directly with NEVER disabling comparison, and without `set_lod_range` the
// LOD clamps stay at (0, FLT_MAX). SamplerDesc has no border color, so
// CLAMP_TO_BORDER uses transparent black.
//
// The translated D3D12_SAMPLER_DESC is stored on the sampler. No sampler
// descriptor heap exists in the dx12 backend yet, so no CPU descriptor is
// created here; whoever adds the heap calls `CreateSampler` with `desc` (the
// pipeline's sampler descriptor table is the consumer).
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12;

// D3D12_FLOAT32_MAX.
const float DX12_FLOAT32_MAX = 3.402823466e+38;

struct SamplerDx12
{
	d3d12::SamplerDesc desc;
}

fn d3d12::TextureAddressMode dx12_sampler_address(SamplerAddress address) @private
{
	switch (address)
	{
		case MIRROR: return d3d12::TextureAddressMode.MIRROR;
		case REPEAT: return d3d12::TextureAddressMode.WRAP;
		case CLAMP_TO_EDGE: return d3d12::TextureAddressMode.CLAMP;
		case CLAMP_TO_BORDER: return d3d12::TextureAddressMode.BORDER;
	}
}

fn d3d12::ComparisonFunc dx12_sampler_compare(SamplerCompare compare) @private
{
	switch (compare)
	{
		case NEVER: return d3d12::ComparisonFunc.NEVER;
		case LESS: return d3d12::ComparisonFunc.LESS;
		case EQUAL: return d3d12::ComparisonFunc.EQUAL;
		case LESS_EQUAL: return d3d12::ComparisonFunc.LESS_EQUAL;
		case GREATER: return d3d12::ComparisonFunc.GREATER;
		case NOT_EQUAL: return d3d12::ComparisonFunc.NOT_EQUAL;
		case GREATER_EQUAL: return d3d12::ComparisonFunc.GREATER_EQUAL;
		case ALWAYS: return d3d12::ComparisonFunc.ALWAYS;
	}
}

// D3D12_FILTER bit layout: bit 0 mip, bit 2 mag, bit 4 min (set = linear),
// bit 7 comparison; ANISOTROPIC is 0x55.
fn d3d12::Filter dx12_sampler_filter(SamplerDesc desc, bool anisotropic, bool compare) @private
{
	uint bits = anisotropic ? 0x55 : 0;
	if (!anisotropic)
	{
		if (desc.min_filter == LINEAR) bits |= 0x10;
		if (desc.mag_filter == LINEAR) bits |= 0x04;
		if (desc.mip_map_mode == LINEAR) bits |= 0x01;
	}
	if (compare) bits |= 0x80;
	return (d3d12::Filter)bits;
}

fn Sampler? sampler_init_dx12(Device* device, SamplerDesc desc)
{
	// D3D12 has no inverted-LOD-range representation; report it like the
	// other backends.
	if (desc.set_lod_range && !(desc.max_lod >= desc.min_lod)) return UNSUPPORTED_FEATURE~;

	// Values <= 1 and NaN mean no anisotropic filtering.
	float max_anisotropy = 1;
	if (desc.max_anisotropy > 1)
	{
		max_anisotropy = desc.max_anisotropy < device.adapter.sampler_anisotropy_max
			? desc.max_anisotropy
			: device.adapter.sampler_anisotropy_max;
		if (!(max_anisotropy > 1)) max_anisotropy = 1;
	}
	bool anisotropic = max_anisotropy > 1;
	bool compare = desc.compare_func != NEVER;

	return {
		.cookie = next_cookie(),
		.backend.dx12 = {
			.desc = {
				.filter = dx12_sampler_filter(desc, anisotropic, compare),
				.address_u = dx12_sampler_address(desc.address_u),
				.address_v = dx12_sampler_address(desc.address_v),
				.address_w = dx12_sampler_address(desc.address_w),
				.mip_lod_bias = desc.mip_lod_bias,
				.max_anisotropy = (uint)max_anisotropy,
				.comparison_func = dx12_sampler_compare(desc.compare_func),
				.border_color = { 0, 0, 0, 0 },
				.min_lod = desc.set_lod_range ? desc.min_lod : 0,
				.max_lod = desc.set_lod_range ? desc.max_lod : DX12_FLOAT32_MAX,
			},
		},
	};
}

fn void sampler_deinit_dx12(Sampler* s, Device* device)
{
	s.backend.dx12 = {};
}

// ---- vulkan ----

module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import vk;

struct SamplerVk
{
	vk::Sampler sampler;
}

fn vk::SamplerAddressMode to_vk_sampler_address(SamplerAddress address) @private
{
	switch (address)
	{
	case MIRROR: return vk::SamplerAddressMode.MIRRORED_REPEAT;
	case REPEAT: return vk::SamplerAddressMode.REPEAT;
	case CLAMP_TO_EDGE: return vk::SamplerAddressMode.CLAMP_TO_EDGE;
	case CLAMP_TO_BORDER: return vk::SamplerAddressMode.CLAMP_TO_BORDER;
	}
}

fn vk::CompareOp to_vk_sampler_compare(SamplerCompare compare) @private
{
	switch (compare)
	{
	case NEVER: return vk::CompareOp.NEVER;
	case LESS: return vk::CompareOp.LESS;
	case EQUAL: return vk::CompareOp.EQUAL;
	case LESS_EQUAL: return vk::CompareOp.LESS_OR_EQUAL;
	case GREATER: return vk::CompareOp.GREATER;
	case NOT_EQUAL: return vk::CompareOp.NOT_EQUAL;
	case GREATER_EQUAL: return vk::CompareOp.GREATER_OR_EQUAL;
	case ALWAYS: return vk::CompareOp.ALWAYS;
	}
}

fn Sampler? sampler_init_vk(Device* device, SamplerDesc desc)
{
	float max_anisotropy = 1.0;
	if (desc.max_anisotropy > 1.0) {
		max_anisotropy = desc.max_anisotropy < device.adapter.sampler_anisotropy_max
			? desc.max_anisotropy
			: device.adapter.sampler_anisotropy_max;
		if (!(max_anisotropy > 1.0)) max_anisotropy = 1.0;
	}

	vk::SamplerCreateInfo info = {
		.sType = vk::StructureType.SAMPLER_CREATE_INFO,
		.magFilter = desc.mag_filter == LINEAR ? vk::Filter.LINEAR : vk::Filter.NEAREST,
		.minFilter = desc.min_filter == LINEAR ? vk::Filter.LINEAR : vk::Filter.NEAREST,
		.mipmapMode = desc.mip_map_mode == LINEAR ? vk::SamplerMipmapMode.LINEAR : vk::SamplerMipmapMode.NEAREST,
		.addressModeU = to_vk_sampler_address(desc.address_u),
		.addressModeV = to_vk_sampler_address(desc.address_v),
		.addressModeW = to_vk_sampler_address(desc.address_w),
		.mipLodBias = desc.mip_lod_bias,
		.anisotropyEnable = max_anisotropy > 1.0 ? vk::TRUE : vk::FALSE,
		.maxAnisotropy = max_anisotropy,
		.compareEnable = desc.compare_func != NEVER ? vk::TRUE : vk::FALSE,
		.compareOp = to_vk_sampler_compare(desc.compare_func),
		.minLod = desc.set_lod_range ? desc.min_lod : 0.0,
		.maxLod = desc.set_lod_range ? desc.max_lod : vk::LOD_CLAMP_NONE,
		.borderColor = vk::BorderColor.FLOAT_OPAQUE_BLACK,
		.unnormalizedCoordinates = vk::FALSE,
	};

	vk::Sampler sampler;
	vk_check(device.backend.vk.vtable.createSampler(device.backend.vk.device, &info, null, &sampler))!;
	return {
		.cookie = next_cookie(),
		.backend.vk = { .sampler = sampler },
	};
}

fn void sampler_deinit_vk(Sampler* sampler, Device* device)
{
	if (sampler.backend.vk.sampler != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroySampler(device.backend.vk.device, sampler.backend.vk.sampler, null);
	}
	sampler.backend.vk = {};
	sampler.cookie = 0;
}

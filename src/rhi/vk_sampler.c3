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

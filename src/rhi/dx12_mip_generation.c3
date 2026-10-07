// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Direct3D 12 compute mip chain generation. Port of ATDD-Redux
// `RID3D12MipGeneration.cpp`. Each mip is a 2x2 (2D array) or 2x2x2 (3D)
// box filter run as a compute dispatch over a ping-pong pair of scratch
// images; every result mip is copied back into the target image. Scratch
// images and descriptor / constant ranges are tracked per descriptor set so
// `mip_generation_reclaim_dx12` can release them once the GPU is done with
// that set's frame.
//
// The two compute shaders are DXIL blobs the caller supplies at init; the
// rhi tree embeds none yet.
//
// TODO: `generate` assumes `ImageDx12` exposes `resource`, `mip_levels` and
// `array_layers`, and that `cmd_image_barrier` / `cmd_copy_image` are real on
// D3D12 (both are no-op stand-ins today). Unlike the HPL2 original this pass
// does not go through the shadowed root-signature / descriptor-heap setters
// (no equivalent exists in this tree), so a later pipeline bind must set its
// own root signature and heaps.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi, d3d12ma;
import std::collections::list;

const uint MIP_CONSTANT_BUFFER_SIZE = 1024 * 1024;
const uint MIP_CONSTANT_BUFFER_ALIGNMENT = 256;
const uint MIP_MAX_DISPATCHES = MIP_CONSTANT_BUFFER_SIZE / MIP_CONSTANT_BUFFER_ALIGNMENT;
// One SRV and one UAV per dispatch.
const uint MIP_DESCRIPTORS_PER_DISPATCH = 2;
const uint MIP_SETS = 2;
const uint MIP_RANGE_OFFSET_APPEND = 0xFFFFFFFF;

// D3D12_FORMAT_SUPPORT1 / D3D12_FORMAT_SUPPORT2 bits the format probe reads.
const uint MIP_SUPPORT1_TEXTURE2D = 0x20;
const uint MIP_SUPPORT1_TEXTURE3D = 0x40;
const uint MIP_SUPPORT1_SHADER_LOAD = 0x100;
const uint MIP_SUPPORT1_SHADER_SAMPLE = 0x200;
const uint MIP_SUPPORT2_UAV_TYPED_STORE = 0x80;

// D3D12_FEATURE_DATA_FORMAT_SUPPORT; vendor/d3d12 has no binding for it.
struct MipFormatSupportDx12
{
	dxgi::Format format;
	uint support1;
	uint support2;
}

// `target` is the format of the image receiving the mips. `scratch` is what
// the compute passes read and write: sRGB targets filter in linear UNORM
// (the shader converts) because sRGB formats have no typed UAV store.
struct MipFormatDx12
{
	dxgi::Format target;
	dxgi::Format scratch;
	rhi::Format scratch_format;
}

struct MipScratchDx12
{
	Image source;
	Image intermediate;
	dxgi::Format format;
	uint width;
	uint height;
	uint depth;
	uint mip_levels;
	uint layer_count;
	bool is_3d;
}

// `depth > 1` selects the 3D path. `layer_count == 0` means one layer.
// `post_state` empty leaves the target's mips in COPY_SRC (mip 0) /
// COPY_DST (the rest).
struct MipGenerateDescDx12
{
	Image* target;
	rhi::Format format;
	uint width;
	uint height;
	uint depth;
	uint mip_levels;
	uint layer_count;
	uint array_offset;
	ResourceState current_state;
	BarrierStages current_stages;
	ResourceState post_state;
	BarrierStages post_stages;
}

struct MipGenerationDx12
{
	// Owned.
	d3d12::RootSignature* root_signature;
	d3d12::PipelineState* pipeline_2d_array;
	d3d12::PipelineState* pipeline_3d;
	d3d12::DescriptorHeap*[MIP_SETS] descriptor_heap;
	d3d12::Resource*[MIP_SETS] constant_buffer;
	d3d12ma::Allocation[MIP_SETS] constant_allocation;
	// Persistently mapped view of `constant_buffer`.
	char*[MIP_SETS] constant_data;
	uint[MIP_SETS] constant_offset;
	uint[MIP_SETS] descriptor_offset;
	uint[MIP_SETS] descriptor_capacity;
	bool[MIP_SETS] constant_mapped;
	uint descriptor_size;
	bool initialized;
	List{MipScratchDx12}[MIP_SETS] scratch;
}

fn bool mip_format_dx12(rhi::Format f, MipFormatDx12* out) @local
{
	switch (f)
	{
		case RGBA8_UNORM:
			*out = { dxgi::Format.R8G8B8A8_UNORM, dxgi::Format.R8G8B8A8_UNORM, RGBA8_UNORM };
			return true;
		case RGBA8_SRGB:
			*out = { dxgi::Format.R8G8B8A8_UNORM_SRGB, dxgi::Format.R8G8B8A8_UNORM, RGBA8_UNORM };
			return true;
		case RGBA16_SFLOAT:
			*out = { dxgi::Format.R16G16B16A16_FLOAT, dxgi::Format.R16G16B16A16_FLOAT, RGBA16_SFLOAT };
			return true;
		case RGBA32_SFLOAT:
			*out = { dxgi::Format.R32G32B32A32_FLOAT, dxgi::Format.R32G32B32A32_FLOAT, RGBA32_SFLOAT };
			return true;
		default:
			return false;
	}
}

fn bool mip_supports_dx12(d3d12::Device* dev, dxgi::Format f, uint dim, bool uav) @local
{
	MipFormatSupportDx12 s = { .format = f };
	if (dxgi::failed(dev.vtbl.check_feature_support(dev, d3d12::Feature.FORMAT_SUPPORT, &s, MipFormatSupportDx12::size))) return false;
	uint sample = MIP_SUPPORT1_SHADER_SAMPLE | MIP_SUPPORT1_SHADER_LOAD;
	return (s.support1 & dim) == dim
		&& (s.support1 & sample) == sample
		&& (!uav || (s.support2 & MIP_SUPPORT2_UAV_TYPED_STORE) != 0);
}

// The scratch image is copied straight into the target, so the formats must
// match except for the sRGB reinterpretation.
fn bool mip_copy_compatible_dx12(dxgi::Format target, dxgi::Format scratch) @local
{
	return (target == dxgi::Format.R8G8B8A8_UNORM_SRGB && scratch == dxgi::Format.R8G8B8A8_UNORM) || target == scratch;
}

fn bool mip_format_supported_dx12(Device* device, rhi::Format f, bool is_3d)
{
	d3d12::Device* dev = device.backend.dx12.device;
	MipFormatDx12 m;
	if (!dev || !mip_format_dx12(f, &m) || !mip_copy_compatible_dx12(m.target, m.scratch)) return false;
	uint dim = is_3d ? MIP_SUPPORT1_TEXTURE3D : MIP_SUPPORT1_TEXTURE2D;
	return mip_supports_dx12(dev, m.target, dim, false) && mip_supports_dx12(dev, m.scratch, dim, true);
}

fn uint mip_extent_dx12(uint size, uint mip) @local
{
	uint v = size >> mip;
	return v > 1 ? v : 1;
}

fn void mip_barrier_dx12(Cmd* cmd, Device* device, Image* image, ResourceState before, ResourceState after, BarrierStages before_stages, BarrierStages after_stages, uint mip, uint layer, uint layers) @local
{
	cmd_image_barrier(cmd, device, {
		.image = image,
		.before = before,
		.after = after,
		.before_stages = before_stages,
		.after_stages = after_stages,
		.base_mip = (ushort)mip,
		.mip_count = 1,
		.base_layer = (ushort)layer,
		.layer_count = (ushort)layers,
	});
}

// SRV over `src_mip` of the read image at `cpu`, UAV over `dst_mip` of the
// write image one descriptor later. The pair swaps roles every mip, so the
// parity of `src_mip` picks which scratch image is read.
fn void mip_views_dx12(d3d12::Device* dev, MipScratchDx12* s, uint src_mip, uint dst_mip, uint layers, d3d12::CpuDescriptorHandle cpu, uint stride) @local
{
	Image* read = (src_mip & 1) ? &s.intermediate : &s.source;
	Image* write = (src_mip & 1) ? &s.source : &s.intermediate;
	d3d12::ShaderResourceViewDesc srv = {
		.format = s.format,
		.shader_4_component_mapping = d3d12::DEFAULT_SHADER_4_COMPONENT_MAPPING,
	};
	d3d12::UnorderedAccessViewDesc uav = { .format = s.format };
	if (s.is_3d)
	{
		srv.view_dimension = d3d12::SrvDimension.TEXTURE3D;
		srv.texture3d = { .most_detailed_mip = src_mip, .mip_levels = 1 };
		uav.view_dimension = d3d12::UavDimension.TEXTURE3D;
		uav.texture3d = { .mip_slice = dst_mip, .first_w_slice = 0, .w_size = uint::max };
	}
	else
	{
		srv.view_dimension = d3d12::SrvDimension.TEXTURE2DARRAY;
		srv.texture2d_array = { .most_detailed_mip = src_mip, .mip_levels = 1, .first_array_slice = 0, .array_size = layers };
		uav.view_dimension = d3d12::UavDimension.TEXTURE2DARRAY;
		uav.texture2d_array = { .mip_slice = dst_mip, .first_array_slice = 0, .array_size = layers };
	}
	dev.vtbl.create_shader_resource_view(dev, read.backend.dx12.resource, &srv, cpu);
	cpu.ptr += stride;
	dev.vtbl.create_unordered_access_view(dev, write.backend.dx12.resource, null, &uav, cpu);
}

fn void? mip_create_pipeline_dx12(d3d12::Device* dev, d3d12::RootSignature* root, char[] code, d3d12::PipelineState** out) @local
{
	d3d12::ComputePipelineStateDesc desc = {
		.root_signature = root,
		.cs = { .bytecode = code.ptr, .length = code.len },
	};
	Guid iid = d3d12::IID_PIPELINE_STATE;
	dx12_check(dev.vtbl.create_compute_pipeline_state(dev, &desc, &iid, (void**)out))!;
}

// `cs_2d_array` / `cs_3d` are DXIL for the two mip kernels; they are only
// read during this call.
fn void? mip_generation_init_dx12(MipGenerationDx12* self, Device* device, char[] cs_2d_array, char[] cs_3d)
{
	d3d12::Device* dev = device.backend.dx12.device;
	d3d12ma::Allocator ma = device.backend.dx12.allocator;
	if (!dev || !ma || cs_2d_array.len == 0 || cs_3d.len == 0) return INITIALIZATION_FAILED~;
	*self = {};
	defer catch mip_generation_deinit_dx12(self, device);

	// Table 0: SRV t0. Table 1: UAV u0. Root CBV b0 carries the per-dispatch
	// constants.
	d3d12::DescriptorRange[2] ranges = {
		{ d3d12::DescriptorRangeType.SRV, 1, 0, 0, MIP_RANGE_OFFSET_APPEND },
		{ d3d12::DescriptorRangeType.UAV, 1, 0, 1, MIP_RANGE_OFFSET_APPEND },
	};
	d3d12::RootParameter[3] params = {};
	params[0] = {
		.parameter_type = d3d12::RootParameterType.DESCRIPTOR_TABLE,
		.descriptor_table = { 1, &ranges[0] },
		.shader_visibility = d3d12::ShaderVisibility.ALL,
	};
	params[1] = {
		.parameter_type = d3d12::RootParameterType.DESCRIPTOR_TABLE,
		.descriptor_table = { 1, &ranges[1] },
		.shader_visibility = d3d12::ShaderVisibility.ALL,
	};
	params[2] = {
		.parameter_type = d3d12::RootParameterType.CBV,
		.descriptor = { 0, 0 },
		.shader_visibility = d3d12::ShaderVisibility.ALL,
	};
	d3d12::RootSignatureDesc root_desc = {
		.num_parameters = 3,
		.parameters = &params[0],
		.flags = d3d12::ROOT_SIGNATURE_FLAG_NONE,
	};
	dxgi::Blob* blob;
	dxgi::Blob* error;
	if (dxgi::failed(d3d12::serialize_root_signature(&root_desc, d3d12::RootSignatureVersion.V1_0, &blob, &error)))
	{
		if (error) dxgi::release(error);
		return INITIALIZATION_FAILED~;
	}
	Guid root_iid = d3d12::IID_ROOT_SIGNATURE;
	dxgi::HResult hr = dev.vtbl.create_root_signature(dev, 0, blob.vtbl.get_buffer_pointer(blob), blob.vtbl.get_buffer_size(blob), &root_iid, (void**)&self.root_signature);
	dxgi::release(blob);
	if (error) dxgi::release(error);
	dx12_check(hr)!;

	mip_create_pipeline_dx12(dev, self.root_signature, cs_2d_array, &self.pipeline_2d_array)!;
	mip_create_pipeline_dx12(dev, self.root_signature, cs_3d, &self.pipeline_3d)!;

	d3d12::DescriptorHeapDesc heap_desc = {
		.type = d3d12::DescriptorHeapType.CBV_SRV_UAV,
		.num_descriptors = MIP_MAX_DISPATCHES * MIP_DESCRIPTORS_PER_DISPATCH,
		.flags = d3d12::DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
	};
	Guid heap_iid = d3d12::IID_DESCRIPTOR_HEAP;
	for (uint i = 0; i < MIP_SETS; i++)
	{
		dx12_check(dev.vtbl.create_descriptor_heap(dev, &heap_desc, &heap_iid, (void**)&self.descriptor_heap[i]))!;
		self.descriptor_capacity[i] = heap_desc.num_descriptors;
	}
	self.descriptor_size = dev.vtbl.get_descriptor_handle_increment_size(dev, d3d12::DescriptorHeapType.CBV_SRV_UAV);

	for (uint i = 0; i < MIP_SETS; i++)
	{
		d3d12::ResourceDesc rd = {
			.dimension = d3d12::ResourceDimension.BUFFER,
			.width = MIP_CONSTANT_BUFFER_SIZE,
			.height = 1,
			.depth_or_array_size = 1,
			.mip_levels = 1,
			.format = dxgi::Format.UNKNOWN,
			.sample_desc = { 1, 0 },
			.layout = d3d12::TextureLayout.ROW_MAJOR,
			.flags = d3d12::RESOURCE_FLAG_NONE,
		};
		d3d12ma::AllocationDesc ad = {
			.flags = d3d12ma::ALLOCATION_FLAG_NONE,
			.heap_type = (int)d3d12::HeapType.UPLOAD,
			.extra_heap_flags = (uint)d3d12::HEAP_FLAG_NONE,
		};
		if (d3d12ma::create_resource(ma, &ad, &rd, (uint)d3d12::RESOURCE_STATE_GENERIC_READ, null, &self.constant_allocation[i], (void**)&self.constant_buffer[i]) < 0)
		{
			return INITIALIZATION_FAILED~;
		}
		d3d12::Resource* buffer = self.constant_buffer[i];
		dx12_check(buffer.vtbl.map(buffer, 0, null, (void**)&self.constant_data[i]))!;
		self.constant_mapped[i] = true;
	}
	self.initialized = true;
}

// Releases the scratch images and rewinds the descriptor / constant ranges of
// `set`. Call once the GPU has finished every list that used the set.
fn void mip_generation_reclaim_dx12(MipGenerationDx12* self, Device* device, uint set)
{
	if (set >= MIP_SETS) return;
	foreach (&s : self.scratch[set].array_view())
	{
		image_deinit(&s.source, device);
		image_deinit(&s.intermediate, device);
	}
	self.scratch[set].clear();
	self.constant_offset[set] = 0;
	self.descriptor_offset[set] = 0;
}

fn void mip_generation_deinit_dx12(MipGenerationDx12* self, Device* device)
{
	for (uint i = 0; i < MIP_SETS; i++)
	{
		mip_generation_reclaim_dx12(self, device, i);
		self.scratch[i].free();
	}
	for (uint i = 0; i < MIP_SETS; i++)
	{
		d3d12::Resource* buffer = self.constant_buffer[i];
		if (buffer)
		{
			if (self.constant_mapped[i]) buffer.vtbl.unmap(buffer, 0, null);
			dxgi::release(buffer);
		}
		if (self.constant_allocation[i]) d3d12ma::free_allocation(self.constant_allocation[i]);
		if (self.descriptor_heap[i]) dxgi::release(self.descriptor_heap[i]);
	}
	if (self.pipeline_3d) dxgi::release(self.pipeline_3d);
	if (self.pipeline_2d_array) dxgi::release(self.pipeline_2d_array);
	if (self.root_signature) dxgi::release(self.root_signature);
	*self = {};
}

// Records mips 1..mip_levels-1 of `desc.target` on `cmd`. Fails without
// recording anything when the request or the per-set descriptor / constant
// budget cannot be met.
fn void? mip_generate_dx12(MipGenerationDx12* self, Device* device, Cmd* cmd, uint set, MipGenerateDescDx12 x)
{
	MipFormatDx12 mf;
	bool is_3d = x.depth > 1;
	uint layers = x.layer_count ? x.layer_count : 1;
	uint view_layers = is_3d ? 1 : layers;
	if (!self.initialized || set >= MIP_SETS || !x.target || !mip_format_dx12(x.format, &mf)
		|| !mip_format_supported_dx12(device, x.format, is_3d)
		|| !x.target.backend.dx12.resource || x.mip_levels < 2
		|| x.mip_levels > x.target.backend.dx12.mip_levels
		|| (!is_3d && (layers > x.target.backend.dx12.array_layers || x.array_offset > x.target.backend.dx12.array_layers - layers)))
	{
		return UNSUPPORTED_FEATURE~;
	}
	d3d12::GraphicsCommandList* list = cmd.backend.dx12.list;
	d3d12::Device* dev = device.backend.dx12.device;
	uint dispatches = x.mip_levels - 1;
	if (dispatches > MIP_MAX_DISPATCHES || !list || !self.descriptor_heap[set] || !self.constant_buffer[set]
		|| !self.constant_data[set] || !self.descriptor_size
		|| dispatches * MIP_DESCRIPTORS_PER_DISPATCH > self.descriptor_capacity[set]
		|| self.constant_offset[set] > MIP_CONSTANT_BUFFER_SIZE - dispatches * MIP_CONSTANT_BUFFER_ALIGNMENT
		|| self.descriptor_offset[set] > self.descriptor_capacity[set] - dispatches * MIP_DESCRIPTORS_PER_DISPATCH)
	{
		return UNSUPPORTED_FEATURE~;
	}

	ImageDesc image_desc = {
		.image_type = is_3d ? ImageType.D3 : ImageType.D2,
		.format = mf.scratch_format,
		.width = x.width,
		.height = x.height,
		.depth = is_3d ? x.depth : 1,
		.mip_levels = x.mip_levels,
		.array_layers = view_layers,
		.samples = ImageSampleCount.S1,
		.tiling = ImageTiling.OPTIMAL,
		.usage = { .sampled = true, .storage = true, .transfer_src = true, .transfer_dst = true },
		.memory_usage = ImageMemoryUsage.PREFER_DEVICE,
	};
	Image source = image_init(device, image_desc)!;
	Image? intermediate = image_init(device, image_desc);
	if (catch err = intermediate)
	{
		image_deinit(&source, device);
		return err~;
	}
	self.scratch[set].push({
		.source = source,
		.intermediate = intermediate,
		.format = mf.scratch,
		.width = x.width,
		.height = x.height,
		.depth = image_desc.depth,
		.mip_levels = x.mip_levels,
		.layer_count = view_layers,
		.is_3d = is_3d,
	});
	MipScratchDx12* sc = &self.scratch[set].array_view()[self.scratch[set].len() - 1];

	d3d12::DescriptorHeap* heap = self.descriptor_heap[set];
	list.vtbl.set_descriptor_heaps(list, 1, &heap);
	list.vtbl.set_compute_root_signature(list, self.root_signature);
	list.vtbl.set_pipeline_state(list, is_3d ? self.pipeline_3d : self.pipeline_2d_array);

	ResourceState copy_src = { .copy_src = true };
	ResourceState copy_dst = { .copy_dst = true };
	ResourceState shader_resource = { .shader_resource = true };
	ResourceState storage_write = { .storage_write = true };
	BarrierStages stage_copy = { .copy = true };
	BarrierStages stage_compute = { .compute = true };
	BarrierStages stage_none = {};

	// Mip 0 goes target -> source scratch; the loop then ping-pongs.
	mip_barrier_dx12(cmd, device, x.target, x.current_state, copy_src, x.current_stages, stage_copy, 0, x.array_offset, view_layers);
	mip_barrier_dx12(cmd, device, &sc.source, {}, copy_dst, stage_none, stage_copy, 0, 0, sc.layer_count);
	for (uint n = 0; n < view_layers; n++)
	{
		cmd_copy_image(cmd, device, x.target, &sc.source, {
			.src_mip_level = 0,
			.src_array_layer = x.array_offset + n,
			.dst_mip_level = 0,
			.dst_array_layer = n,
			.width = x.width,
			.height = x.height,
			.depth = is_3d ? x.depth : 1,
		});
	}
	mip_barrier_dx12(cmd, device, &sc.source, copy_dst, shader_resource, stage_copy, stage_compute, 0, 0, sc.layer_count);

	uint stride = self.descriptor_size;
	d3d12::GpuVirtualAddress cb_base = self.constant_buffer[set].vtbl.get_gpu_virtual_address(self.constant_buffer[set]);
	for (uint mip = 1; mip < x.mip_levels; mip++)
	{
		uint sw = mip_extent_dx12(x.width, mip - 1);
		uint sh = mip_extent_dx12(x.height, mip - 1);
		uint sd = mip_extent_dx12(x.depth, mip - 1);
		uint dw = mip_extent_dx12(x.width, mip);
		uint dh = mip_extent_dx12(x.height, mip);
		uint dd = mip_extent_dx12(x.depth, mip);
		Image* dst = (mip & 1) ? &sc.intermediate : &sc.source;

		mip_barrier_dx12(cmd, device, dst, {}, storage_write, stage_none, stage_compute, mip, 0, view_layers);
		d3d12::CpuDescriptorHandle cpu;
		heap.vtbl.get_cpu_descriptor_handle_for_heap_start(heap, &cpu);
		cpu.ptr += (usz)self.descriptor_offset[set] * stride;
		mip_views_dx12(dev, sc, mip - 1, mip, view_layers, cpu, stride);
		d3d12::GpuDescriptorHandle gpu;
		heap.vtbl.get_gpu_descriptor_handle_for_heap_start(heap, &gpu);
		gpu.ptr += (ulong)self.descriptor_offset[set] * stride;
		d3d12::GpuDescriptorHandle uav = { .ptr = gpu.ptr + stride };
		list.vtbl.set_compute_root_descriptor_table(list, 0, gpu);
		list.vtbl.set_compute_root_descriptor_table(list, 1, uav);

		uint[8] constants = { sw, sh, sd, 0, dw, dh, is_3d ? dd : layers, x.format == RGBA8_SRGB ? 1 : 0 };
		mem::copy(self.constant_data[set] + self.constant_offset[set], &constants, uint[8]::size);
		list.vtbl.set_compute_root_constant_buffer_view(list, 2, cb_base + self.constant_offset[set]);
		self.constant_offset[set] += MIP_CONSTANT_BUFFER_ALIGNMENT;
		self.descriptor_offset[set] += MIP_DESCRIPTORS_PER_DISPATCH;
		list.vtbl.dispatch(list, (dw + 7) / 8, (dh + 7) / 8, is_3d ? dd : layers);

		mip_barrier_dx12(cmd, device, dst, storage_write, copy_src, stage_compute, stage_copy, mip, 0, view_layers);
		mip_barrier_dx12(cmd, device, x.target, {}, copy_dst, stage_none, stage_copy, mip, x.array_offset, view_layers);
		for (uint n = 0; n < view_layers; n++)
		{
			cmd_copy_image(cmd, device, dst, x.target, {
				.src_mip_level = mip,
				.src_array_layer = n,
				.dst_mip_level = mip,
				.dst_array_layer = x.array_offset + n,
				.width = dw,
				.height = dh,
				.depth = is_3d ? dd : 1,
			});
		}
		if (mip + 1 < x.mip_levels)
		{
			mip_barrier_dx12(cmd, device, dst, copy_src, shader_resource, stage_copy, stage_compute, mip, 0, view_layers);
		}
	}

	if (x.post_state != (ResourceState){})
	{
		for (uint mip = 0; mip < x.mip_levels; mip++)
		{
			mip_barrier_dx12(cmd, device, x.target, mip ? copy_dst : copy_src, x.post_state, stage_copy, x.post_stages, mip, x.array_offset, view_layers);
		}
	}
}

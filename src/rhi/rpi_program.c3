// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// `Program`: the rpi-layer render program. Port of rhi-zig's `rpi/program.zig`
// (itself a port of HPL2's `RIProgram`). One program bundles, for one set of
// shader stages:
//   * owned copies of the per-stage shader binaries,
//   * a pipeline layout built from an explicit, caller-declared layout
//     (descriptor-set layouts + push-constant range),
//   * a pipeline cache keyed by a caller-chosen hash,
//   * descriptor sets resolved by binding *name* through the frame-aware
//     `RpiDescriptorSetAlloc`.
//
// Only the Vulkan arm exists; compute pipelines, ray tracing and bindless /
// external sets are not ported yet. Every other backend returns
// `UNSUPPORTED_BACKEND`.
//
// The `ProgramVk` / `ProgramPipelineSlotVk` / `ProgramDescriptorSetVk`
// stand-ins for a build without Vulkan live in backend_stubs.c3.
module rhi;
import std::collections::list, std::collections::map;

const PROGRAM_DESCRIPTOR_SET_MAX = 4;

enum ProgramStage : char
{
	VERTEX,
	FRAGMENT,
	COMPUTE,
}

// Odin's `bit_set[Program_Stage; u8]`.
bitstruct ProgramStageFlags : char
{
	bool vertex : 0;
	bool fragment : 1;
	bool compute : 2;
}

// One shader stage handed to `program_init`. `data` is borrowed and copied.
struct ProgramModuleStage
{
	ProgramStage stage;
	char[] data;
	String entry_point;
}

struct ProgramLayoutBinding
{
	String name;
	uint set;
	uint binding;
	DescriptorType descriptor_type;
	// Array size; 0 and 1 both declare a single descriptor.
	uint count;
	ProgramStageFlags stages;
}

struct ProgramPushConstantRange
{
	ProgramStageFlags stages;
	uint size;
}

// The explicit descriptor layout. rhi-zig declares it by hand rather than
// reflecting SPIR-V; real reflection can replace it later without touching
// the binders.
struct ProgramLayout
{
	ProgramLayoutBinding[] bindings;
	ProgramPushConstantRange push_constant;
	bool has_push_constant;
}

// A declared binding as looked up by name hash at bind time.
struct ProgramBindingReflection
{
	ulong hash;
	bool is_array;
	ushort set;
	ushort base_register;
	DescriptorType descriptor_type;
}

struct ProgramVertexStream
{
	uint binding;
	uint stride;
	bool per_instance;
}

struct ProgramVertexAttribute
{
	uint location;
	uint binding;
	Format format;
	uint offset;
}

struct ProgramColorAttachment
{
	Format format;
	BlendState blend;
	bool has_blend;
}

struct ProgramGraphicsPipelineDesc
{
	PrimitiveTopology topology;
	CullMode cull_mode;
	FrontFace front_face;
	bool depth_test;
	bool depth_write;
	CompareOp depth_compare;
	Format depth_format;
	bool has_depth_format;
	ProgramColorAttachment[] colors;
	ProgramVertexStream[] vertex_streams;
	ProgramVertexAttribute[] vertex_attributes;
}

enum ProgramBindPoint : char
{
	GRAPHICS,
	COMPUTE,
}

// Per-descriptor-type descriptor counts of one set, tallied from the layout
// and used to size that set's descriptor pools.
struct RpiPoolSizes
{
	uint sampler;
	uint sampled_image;
	uint storage_image;
	uint uniform_buffer;
	uint storage_buffer;
}

// Owned copy of one stage's binary. The entry point is NUL-terminated so it
// can be handed to `VkPipelineShaderStageCreateInfo::pName` as is.
struct ProgramShaderBinary
{
	char[] data;
	ZString entry_point;
}

struct ProgramPipelineSlot
{
	union backend
	{
		ProgramPipelineSlotVk vk;
	}
}

struct ProgramDescriptorSetSlot
{
	RpiPoolSizes sizes;
	// Whether any binding lands in this set.
	bool used;
	union backend
	{
		ProgramDescriptorSetVk vk;
	}
}

struct Program
{
	Allocator allocator;
	// Odin's `[Program_Stage]Program_Shader_Binary`: indexed by stage ordinal.
	ProgramShaderBinary[ProgramStage::len] shader_bins;
	List{ProgramBindingReflection} reflection;
	bool has_push_constant;
	uint push_constant_size;
	ProgramStageFlags push_constant_stages;
	HashMap{ulong, ProgramPipelineSlot} pipelines;
	ProgramDescriptorSetSlot[PROGRAM_DESCRIPTOR_SET_MAX] sets;
	union backend
	{
		ProgramVk vk;
	}
}

// Builds a program from its stages and an explicit layout. `modules` and
// `layout` are borrowed; the shader blobs and entry points are copied.
fn Program? program_init(Device* device, ProgramModuleStage[] modules, ProgramLayout layout, Allocator allocator = mem)
{
	Program p;
	p.allocator = allocator;
	p.reflection.init(allocator);
	p.pipelines.init(allocator);
	defer catch program_free_neutral(&p);

	foreach (m : modules)
	{
		ProgramShaderBinary* bin = &p.shader_bins[m.stage.ordinal];
		assert(bin.data.len == 0, "program_init: duplicate shader stage");
		// SPIR-V is read as u32 words, so keep the copy word-aligned (the
		// allocator's default alignment already covers 4 bytes).
		bin.data = alloc::alloc_array_try(allocator, char, m.data.len)!;
		bin.data[..] = m.data[..];
		bin.entry_point = m.entry_point.zstr_copy(allocator);
	}

	program_build_reflection(&p, layout);

	if (layout.has_push_constant)
	{
		p.has_push_constant = true;
		p.push_constant_size = layout.push_constant.size;
		p.push_constant_stages = layout.push_constant.stages;
	}

	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				program_init_vk(&p, device, layout)!;
				return p;
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return UNSUPPORTED_BACKEND~;
}

// Fills `reflection` (name hash -> set/register) and tallies the per-set pool
// sizes from the explicit layout. Backend-independent.
//
// `List` growth panics on OOM, so unlike Odin this cannot fail.
fn void program_build_reflection(Program* p, ProgramLayout layout) @private
{
	foreach (lb : layout.bindings)
	{
		assert(lb.set < PROGRAM_DESCRIPTOR_SET_MAX);
		p.reflection.push({
			.hash = descriptor_name_hash(lb.name),
			.is_array = lb.count > 1,
			.set = (ushort)lb.set,
			.base_register = (ushort)lb.binding,
			.descriptor_type = lb.descriptor_type,
		});

		ProgramDescriptorSetSlot* slot = &p.sets[lb.set];
		slot.used = true;
		uint n = max(1u, lb.count);
		switch (lb.descriptor_type)
		{
			case SAMPLER:
				slot.sizes.sampler += n;
			case SAMPLED_IMAGE:
				slot.sizes.sampled_image += n;
			case STORAGE_IMAGE:
				slot.sizes.storage_image += n;
			case UNIFORM_BUFFER:
				slot.sizes.uniform_buffer += n;
			case STORAGE_BUFFER:
				slot.sizes.storage_buffer += n;
			case ACCELERATION_STRUCTURE:
				// Ray tracing is not ported; no pool type is reserved for it.
				break;
		}
	}
}

fn void program_free_neutral(Program* p) @private
{
	foreach (&bin : p.shader_bins)
	{
		alloc::free(p.allocator, bin.data.ptr);
		alloc::free(p.allocator, (void*)bin.entry_point);
		*bin = {};
	}
	p.pipelines.free();
	p.reflection.free();
}

// The GPU must be idle: cached pipelines and descriptor sets are destroyed.
fn void program_deinit(Program* p, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				program_deinit_vk(p, device);
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	program_free_neutral(p);
	*p = {};
}

// The reflection entry declared under `id`'s name, or nil if there is none.
fn ProgramBindingReflection* program_find_reflection(Program* p, DescriptorBindingID id)
{
	foreach (&r : p.reflection)
	{
		if (r.hash == id.hash) return r;
	}
	return null;
}

// Builds (and caches under `pipeline_hash`) the graphics pipeline for `desc`,
// then binds it on `cmd`. The caller owns the hash: two descs that should
// share a pipeline must share a hash, and two that differ must not.
fn void? program_bind_pipeline(Program* p, Device* device, Cmd* cmd, ulong pipeline_hash, ProgramGraphicsPipelineDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return program_bind_pipeline_vk(p, device, cmd, pipeline_hash, desc);
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return UNSUPPORTED_BACKEND~;
}

// Uploads push constants against the program's layout and declared stages.
fn void program_push_constants(Program* p, Device* device, Cmd* cmd, char[] data, uint offset)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				program_push_constants_vk(p, device, cmd, data, offset);
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
}

// Resolves, writes and binds a descriptor set for every used set, looking
// `bindings` up by name. Unknown names and empty descriptors are skipped.
// `frame_index` is a monotonically increasing frame counter: sets are only
// recycled once they are `RPI_FRAMES_IN_FLIGHT` frames old.
fn void? program_bind_descriptors(Program* p, Device* device, Cmd* cmd, uint frame_index, DescriptorBinding[] bindings, ProgramBindPoint bind_point)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return program_bind_descriptors_vk(p, device, cmd, frame_index, bindings, bind_point);
			$endif
		case DX12:
		case MTL:
		case WGPU:
		case WEBGL:
			break;
	}
	return UNSUPPORTED_BACKEND~;
}

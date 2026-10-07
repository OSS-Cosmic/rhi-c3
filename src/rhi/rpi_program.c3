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

// Bit set of program stages.
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
	// Indexed by stage ordinal.
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
// `List` growth panics on OOM, so this cannot fail.
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

// ---- vulkan ----

// Vulkan arm of the render-program layer.
// (initialize_vk, bindPipelineVk, pushConstants and bindDescriptorsVk).
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;
import std::collections::list;

const PROGRAM_MAX_VERTEX_STREAMS = 8;
const PROGRAM_MAX_VERTEX_ATTRIBUTES = 16;

struct ProgramVk
{
	vk::PipelineLayout pipeline_layout;
	// Highest used descriptor-set index plus one.
	uint layout_count;
}

struct ProgramPipelineSlotVk
{
	vk::Pipeline pipeline;
}

struct ProgramDescriptorSetVk
{
	// Also populated for empty layouts used to fill set-index gaps.
	vk::DescriptorSetLayout set_layout;
	// Only populated for sets declared by the program layout.
	RpiDescriptorSetAlloc alloc;
}

fn vk::ShaderStageFlags program_stages_to_vk(ProgramStageFlags stages) @private
{
	vk::ShaderStageFlags flags;
	if (stages.vertex) flags |= vk::SHADER_STAGE_VERTEX_BIT;
	if (stages.fragment) flags |= vk::SHADER_STAGE_FRAGMENT_BIT;
	if (stages.compute) flags |= vk::SHADER_STAGE_COMPUTE_BIT;
	return flags;
}

fn void? program_init_vk(Program* p, Device* device, ProgramLayout layout)
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;
	vk::Device dev = device.backend.vk.device;

	// One list per set keeps the Vulkan binding and binding-flag arrays alive
	// through descriptor-set-layout creation, while still allowing gaps in the
	// set numbering to be filled with empty layouts.
	List{vk::DescriptorSetLayoutBinding}[PROGRAM_DESCRIPTOR_SET_MAX] set_bindings;
	List{vk::DescriptorBindingFlags}[PROGRAM_DESCRIPTOR_SET_MAX] set_flags;
	defer
	{
		for (uint i = 0; i < PROGRAM_DESCRIPTOR_SET_MAX; i++)
		{
			set_bindings[i].free();
			set_flags[i].free();
		}
	};
	for (uint i = 0; i < PROGRAM_DESCRIPTOR_SET_MAX; i++)
	{
		set_bindings[i].init(p.allocator);
		set_flags[i].init(p.allocator);
	}

	bool[PROGRAM_DESCRIPTOR_SET_MAX] has_array;
	foreach (lb : layout.bindings)
	{
		set_bindings[lb.set].push({
			.binding = lb.binding,
			.descriptorType = vk_descriptor_type_from(lb.descriptor_type),
			.descriptorCount = lb.count > 0 ? lb.count : 1,
			.stageFlags = program_stages_to_vk(lb.stages),
		});
		set_flags[lb.set].push(lb.count > 1 ? vk::DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT : 0);
		if (lb.count > 1) has_array[lb.set] = true;
	}

	uint layout_count = 0;
	for (uint i = 0; i < PROGRAM_DESCRIPTOR_SET_MAX; i++)
	{
		if (set_bindings[i].len() > 0) layout_count = i + 1;
	}

	vk::DescriptorSetLayout[PROGRAM_DESCRIPTOR_SET_MAX] set_layouts;
	for (uint i = 0; i < layout_count; i++)
	{
		vk::DescriptorSetLayoutCreateInfo create_info = {
			.sType = vk::StructureType.DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
			.bindingCount = (uint)set_bindings[i].len(),
			.pBindings = set_bindings[i].len() > 0 ? set_bindings[i].entries : null,
		};
		vk::DescriptorSetLayoutBindingFlagsCreateInfo flags_info = {
			.sType = vk::StructureType.DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO,
			.bindingCount = (uint)set_flags[i].len(),
			.pBindingFlags = set_flags[i].len() > 0 ? set_flags[i].entries : null,
		};
		if (has_array[i]) vk_add_next(&create_info, &flags_info);

		if (catch err = vk_check(vtable.createDescriptorSetLayout(dev, &create_info, null, &set_layouts[i])))
		{
			program_deinit_vk(p, device);
			return err~;
		}

		ProgramDescriptorSetSlot* slot = &p.sets[i];
		slot.backend.vk.set_layout = set_layouts[i];
		if (slot.used)
		{
			slot.backend.vk.alloc = rpi_descriptor_set_alloc_init(
				set_layouts[i], slot.sizes, RPI_FRAMES_IN_FLIGHT, p.allocator);
		}
	}

	vk::PushConstantRange[1] push_ranges;
	vk::PipelineLayoutCreateInfo layout_info = {
		.sType = vk::StructureType.PIPELINE_LAYOUT_CREATE_INFO,
		.setLayoutCount = layout_count,
		.pSetLayouts = layout_count > 0 ? &set_layouts[0] : null,
	};
	if (layout.has_push_constant)
	{
		push_ranges[0] = {
			.stageFlags = program_stages_to_vk(layout.push_constant.stages),
			.offset = 0,
			.size = layout.push_constant.size,
		};
		layout_info.pushConstantRangeCount = 1;
		layout_info.pPushConstantRanges = &push_ranges[0];
	}
	if (catch err = vk_check(vtable.createPipelineLayout(dev, &layout_info, null, &p.backend.vk.pipeline_layout)))
	{
		program_deinit_vk(p, device);
		return err~;
	}
	p.backend.vk.layout_count = layout_count;
	return;
}

fn void program_deinit_vk(Program* p, Device* device)
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;
	vk::Device dev = device.backend.vk.device;

	p.pipelines.@each(; ulong key, ProgramPipelineSlot slot)
	{
		(void)key;
		if (slot.backend.vk.pipeline != vk::NULL_HANDLE) {
			vtable.destroyPipeline(dev, slot.backend.vk.pipeline, null);
		}
	};
	p.pipelines.clear();

	for (uint i = 0; i < PROGRAM_DESCRIPTOR_SET_MAX; i++)
	{
		ProgramDescriptorSetSlot* slot = &p.sets[i];
		if (slot.used) rpi_descriptor_set_alloc_free(&slot.backend.vk.alloc, device);
		if (slot.backend.vk.set_layout != vk::NULL_HANDLE) {
			vtable.destroyDescriptorSetLayout(dev, slot.backend.vk.set_layout, null);
		}
		slot.backend.vk = {};
	}
	if (p.backend.vk.pipeline_layout != vk::NULL_HANDLE) {
		vtable.destroyPipelineLayout(dev, p.backend.vk.pipeline_layout, null);
	}
	p.backend.vk = {};
}

fn void program_destroy_pipeline_modules_vk(Device* device, vk::ShaderModule[] modules)
{
	foreach (shader_module : modules)
	{
		if (shader_module != vk::NULL_HANDLE) {
			device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader_module, null);
		}
	}
}

fn void? program_bind_pipeline_vk(Program* p, Device* device, Cmd* cmd, ulong pipeline_hash, ProgramGraphicsPipelineDesc desc)
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;
	vk::Device dev = device.backend.vk.device;

	if (try slot = p.pipelines.get_ref(pipeline_hash))
	{
		vtable.cmdBindPipeline(cmd.backend.vk.cmd, vk::PipelineBindPoint.GRAPHICS, slot.backend.vk.pipeline);
		return;
	}

	assert(desc.vertex_streams.len <= PROGRAM_MAX_VERTEX_STREAMS);
	assert(desc.vertex_attributes.len <= PROGRAM_MAX_VERTEX_ATTRIBUTES);
	assert(desc.colors.len <= MAX_COLOR_ATTACHMENTS);

	vk::VertexInputBindingDescription[PROGRAM_MAX_VERTEX_STREAMS] streams;
	foreach (i, stream : desc.vertex_streams)
	{
		streams[i] = {
			.binding = stream.binding,
			.stride = stream.stride,
			.inputRate = stream.per_instance ? vk::VertexInputRate.INSTANCE : vk::VertexInputRate.VERTEX,
		};
	}
	vk::VertexInputAttributeDescription[PROGRAM_MAX_VERTEX_ATTRIBUTES] attributes;
	foreach (i, attribute : desc.vertex_attributes)
	{
		attributes[i] = {
			.location = attribute.location,
			.binding = attribute.binding,
			.format = to_vk_format(attribute.format),
			.offset = attribute.offset,
		};
	}
	vk::PipelineVertexInputStateCreateInfo vertex_input = {
		.sType = vk::StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		.vertexBindingDescriptionCount = (uint)desc.vertex_streams.len,
		.pVertexBindingDescriptions = desc.vertex_streams.len > 0 ? &streams[0] : null,
		.vertexAttributeDescriptionCount = (uint)desc.vertex_attributes.len,
		.pVertexAttributeDescriptions = desc.vertex_attributes.len > 0 ? &attributes[0] : null,
	};

	vk::PipelineInputAssemblyStateCreateInfo input_assembly = {
		.sType = vk::StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		.topology = to_vk_topology(desc.topology),
		.primitiveRestartEnable = vk::FALSE,
	};
	vk::PipelineRasterizationStateCreateInfo raster = {
		.sType = vk::StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		.depthClampEnable = vk::FALSE,
		.rasterizerDiscardEnable = vk::FALSE,
		.polygonMode = vk::PolygonMode.FILL,
		.cullMode = to_vk_cull_mode(desc.cull_mode),
		.frontFace = to_vk_front_face(desc.front_face),
		.depthBiasEnable = vk::FALSE,
		.lineWidth = 1.0,
	};
	vk::PipelineViewportStateCreateInfo viewport_state = {
		.sType = vk::StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = 1,
		.scissorCount = 1,
	};
	vk::PipelineMultisampleStateCreateInfo multisample = {
		.sType = vk::StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		.rasterizationSamples = vk::SAMPLE_COUNT_1_BIT,
		.minSampleShading = 1.0,
	};
	vk::PipelineDepthStencilStateCreateInfo depth_stencil = {
		.sType = vk::StructureType.PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		.depthTestEnable = desc.depth_test ? vk::TRUE : vk::FALSE,
		.depthWriteEnable = desc.depth_write ? vk::TRUE : vk::FALSE,
		.depthCompareOp = to_vk_compare_op(desc.depth_compare),
		.depthBoundsTestEnable = vk::FALSE,
		.stencilTestEnable = vk::FALSE,
		.minDepthBounds = 0.0,
		.maxDepthBounds = 1.0,
	};

	vk::PipelineColorBlendAttachmentState[MAX_COLOR_ATTACHMENTS] blend_attachments;
	vk::Format[MAX_COLOR_ATTACHMENTS] color_formats;
	foreach (i, color : desc.colors)
	{
		BlendState blend = color.has_blend ? color.blend : {
			.src_color = ONE,
			.dst_color = ZERO,
			.color_op = ADD,
			.src_alpha = ONE,
			.dst_alpha = ZERO,
			.alpha_op = ADD,
			.write_mask = WRITE_MASK_ALL,
		};
		vk::ColorComponentFlags write_mask;
		if (blend.write_mask.r) write_mask |= vk::COLOR_COMPONENT_R_BIT;
		if (blend.write_mask.g) write_mask |= vk::COLOR_COMPONENT_G_BIT;
		if (blend.write_mask.b) write_mask |= vk::COLOR_COMPONENT_B_BIT;
		if (blend.write_mask.a) write_mask |= vk::COLOR_COMPONENT_A_BIT;
		blend_attachments[i] = {
			.blendEnable = color.has_blend ? vk::TRUE : vk::FALSE,
			.srcColorBlendFactor = to_vk_blend_factor(blend.src_color),
			.dstColorBlendFactor = to_vk_blend_factor(blend.dst_color),
			.colorBlendOp = to_vk_blend_op(blend.color_op),
			.srcAlphaBlendFactor = to_vk_blend_factor(blend.src_alpha),
			.dstAlphaBlendFactor = to_vk_blend_factor(blend.dst_alpha),
			.alphaBlendOp = to_vk_blend_op(blend.alpha_op),
			.colorWriteMask = write_mask,
		};
		color_formats[i] = to_vk_format(color.format);
	}
	vk::PipelineColorBlendStateCreateInfo color_blend = {
		.sType = vk::StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		.logicOpEnable = vk::FALSE,
		.logicOp = vk::LogicOp.CLEAR,
		.attachmentCount = (uint)desc.colors.len,
		.pAttachments = desc.colors.len > 0 ? &blend_attachments[0] : null,
	};
	vk::DynamicState[2] dynamic_states = { vk::DynamicState.VIEWPORT, vk::DynamicState.SCISSOR };
	vk::PipelineDynamicStateCreateInfo dynamic_state = {
		.sType = vk::StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		.dynamicStateCount = 2,
		.pDynamicStates = &dynamic_states[0],
	};
	vk::PipelineRenderingCreateInfo rendering = {
		.sType = vk::StructureType.PIPELINE_RENDERING_CREATE_INFO,
		.colorAttachmentCount = (uint)desc.colors.len,
		.pColorAttachmentFormats = desc.colors.len > 0 ? &color_formats[0] : null,
		.depthAttachmentFormat = vk::Format.UNDEFINED,
		.stencilAttachmentFormat = vk::Format.UNDEFINED,
	};
	if (desc.has_depth_format)
	{
		rendering.depthAttachmentFormat = to_vk_format(desc.depth_format);
		if (format_get_props(desc.depth_format).is_stencil) {
			rendering.stencilAttachmentFormat = rendering.depthAttachmentFormat;
		}
	}

	vk::ShaderModule[2] modules;
	vk::PipelineShaderStageCreateInfo[2] stages;
	uint stage_count = 0;
	ProgramShaderBinary* vertex = &p.shader_bins[ProgramStage.VERTEX.ordinal];
	if (vertex.data.len > 0)
	{
		assert(vertex.data.len % 4 == 0, "SPIR-V size must be a multiple of 4");
		vk::ShaderModuleCreateInfo info = {
			.sType = vk::StructureType.SHADER_MODULE_CREATE_INFO,
			.codeSize = vertex.data.len,
			.pCode = (uint*)vertex.data.ptr,
		};
		if (catch err = vk_check(vtable.createShaderModule(dev, &info, null, &modules[stage_count]))) {
			return err~;
		}
		stages[stage_count] = {
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_VERTEX_BIT,
			.module_ = modules[stage_count],
			.pName = vertex.entry_point,
		};
		stage_count++;
	}
	ProgramShaderBinary* fragment = &p.shader_bins[ProgramStage.FRAGMENT.ordinal];
	if (fragment.data.len > 0)
	{
		assert(fragment.data.len % 4 == 0, "SPIR-V size must be a multiple of 4");
		vk::ShaderModuleCreateInfo info = {
			.sType = vk::StructureType.SHADER_MODULE_CREATE_INFO,
			.codeSize = fragment.data.len,
			.pCode = (uint*)fragment.data.ptr,
		};
		if (catch err = vk_check(vtable.createShaderModule(dev, &info, null, &modules[stage_count])))
		{
			program_destroy_pipeline_modules_vk(device, modules[:stage_count]);
			return err~;
		}
		stages[stage_count] = {
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_FRAGMENT_BIT,
			.module_ = modules[stage_count],
			.pName = fragment.entry_point,
		};
		stage_count++;
	}

	vk::GraphicsPipelineCreateInfo create_info = {
		.sType = vk::StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
		.stageCount = stage_count,
		.pStages = stage_count > 0 ? &stages[0] : null,
		.pVertexInputState = &vertex_input,
		.pInputAssemblyState = &input_assembly,
		.pViewportState = &viewport_state,
		.pRasterizationState = &raster,
		.pMultisampleState = &multisample,
		.pDepthStencilState = &depth_stencil,
		.pColorBlendState = &color_blend,
		.pDynamicState = &dynamic_state,
		.layout = p.backend.vk.pipeline_layout,
		.subpass = 0,
		.basePipelineIndex = -1,
	};
	vk_add_next(&create_info, &rendering);

	vk::Pipeline pipeline;
	if (catch err = vk_check(vtable.createGraphicsPipelines(dev, vk::NULL_HANDLE, 1, &create_info, null, &pipeline)))
	{
		program_destroy_pipeline_modules_vk(device, modules[:stage_count]);
		return err~;
	}
	program_destroy_pipeline_modules_vk(device, modules[:stage_count]);

	ProgramPipelineSlot slot = { .backend.vk.pipeline = pipeline };
	p.pipelines[pipeline_hash] = slot;
	vtable.cmdBindPipeline(cmd.backend.vk.cmd, vk::PipelineBindPoint.GRAPHICS, pipeline);
	return;
}

fn void program_push_constants_vk(Program* p, Device* device, Cmd* cmd, char[] data, uint offset)
{
	assert(p.has_push_constant, "program_push_constants: layout declares no push constants");
	device.backend.vk.vtable.cmdPushConstants(
		cmd.backend.vk.cmd,
		p.backend.vk.pipeline_layout,
		program_stages_to_vk(p.push_constant_stages),
		offset,
		(uint)data.len,
		data.ptr,
	);
}

const ulong PROGRAM_DESCRIPTOR_SET_SEED = 0x6a09e667f3bcc909;

fn ulong program_hash_mix(ulong h, ulong v) @private
{
	ulong x = h ^ (v + 0x9e3779b97f4a7c15 + (h << 6) + (h >> 2));
	x = (x ^ (x >> 30)) * 0xbf58476d1ce4e5b9;
	x = (x ^ (x >> 27)) * 0x94d049bb133111eb;
	return x ^ (x >> 31);
}

fn void? program_bind_descriptors_vk(Program* p, Device* device, Cmd* cmd, uint frame_index, DescriptorBinding[] bindings, ProgramBindPoint bind_point)
{
	vk::PipelineBindPoint vk_bind = bind_point == GRAPHICS
		? vk::PipelineBindPoint.GRAPHICS
		: vk::PipelineBindPoint.COMPUTE;
	vk::DescriptorSet[PROGRAM_DESCRIPTOR_SET_MAX] sets_to_bind;
	uint first_set = 0;
	uint bind_count = 0;

	for (uint set_index = 0; set_index < PROGRAM_DESCRIPTOR_SET_MAX; set_index++)
	{
		ProgramDescriptorSetSlot* slot = &p.sets[set_index];
		if (!slot.used) continue;

		ulong hash = PROGRAM_DESCRIPTOR_SET_SEED;
		foreach (binding : bindings)
		{
			ProgramBindingReflection* reflection = program_find_reflection(p, binding.handle);
			if (reflection == null || reflection.set != set_index || descriptor_is_empty(binding.descriptor)) continue;
			if (reflection.descriptor_type != binding.descriptor.type) return DESCRIPTOR_TYPE_MISMATCH~;
			hash = program_hash_mix(hash, reflection.hash);
			hash = program_hash_mix(hash, (ulong)binding.register_offset);
			hash = program_hash_mix(hash, binding.descriptor.cookie);
		}
		if (hash == PROGRAM_DESCRIPTOR_SET_SEED) continue;

		bool found;
		RpiDescriptorSetSlot* set = rpi_descriptor_set_alloc_resolve(
			&slot.backend.vk.alloc, device, frame_index, hash, &found)!;
		if (!found)
		{
			vk::WriteDescriptorSet[32] writes;
			vk::DescriptorImageInfo[32] image_infos;
			vk::DescriptorBufferInfo[32] buffer_infos;
			uint n = 0;
			foreach (binding : bindings)
			{
				ProgramBindingReflection* reflection = program_find_reflection(p, binding.handle);
				if (reflection == null || reflection.set != set_index || descriptor_is_empty(binding.descriptor)) continue;
				if (n == writes.len)
				{
					device.backend.vk.vtable.updateDescriptorSets(device.backend.vk.device, n, &writes[0], 0, null);
					n = 0;
				}
				Descriptor d = binding.descriptor;
				writes[n] = {
					.sType = vk::StructureType.WRITE_DESCRIPTOR_SET,
					.dstSet = set.handle,
					.dstBinding = reflection.is_array ? reflection.base_register : reflection.base_register + binding.register_offset,
					.dstArrayElement = reflection.is_array ? binding.register_offset : 0,
					.descriptorCount = 1,
					.descriptorType = vk_descriptor_type_from(d.type),
				};
				switch (d.type)
				{
					case UNIFORM_BUFFER:
					case STORAGE_BUFFER:
						buffer_infos[n] = { .buffer = (vk::Buffer)d.handle, .offset = (vk::DeviceSize)d.offset, .range = (vk::DeviceSize)d.range };
						writes[n].pBufferInfo = &buffer_infos[n];
					case SAMPLED_IMAGE:
						image_infos[n] = { .imageView = (vk::ImageView)d.handle, .imageLayout = vk::ImageLayout.SHADER_READ_ONLY_OPTIMAL };
						writes[n].pImageInfo = &image_infos[n];
					case STORAGE_IMAGE:
						image_infos[n] = { .imageView = (vk::ImageView)d.handle, .imageLayout = vk::ImageLayout.GENERAL };
						writes[n].pImageInfo = &image_infos[n];
					case SAMPLER:
						image_infos[n] = { .sampler = (vk::Sampler)d.handle };
						writes[n].pImageInfo = &image_infos[n];
					case ACCELERATION_STRUCTURE:
						continue;
				}
				n++;
			}
			if (n > 0) {
				device.backend.vk.vtable.updateDescriptorSets(device.backend.vk.device, n, &writes[0], 0, null);
			}
		}

		if (bind_count > 0 && first_set + bind_count != set_index)
		{
			device.backend.vk.vtable.cmdBindDescriptorSets(
				cmd.backend.vk.cmd, vk_bind, p.backend.vk.pipeline_layout,
				first_set, bind_count, &sets_to_bind[0], 0, null);
			bind_count = 0;
		}
		if (bind_count == 0) first_set = set_index;
		sets_to_bind[bind_count] = set.handle;
		bind_count++;
	}
	if (bind_count > 0) {
		device.backend.vk.vtable.cmdBindDescriptorSets(
			cmd.backend.vk.cmd, vk_bind, p.backend.vk.pipeline_layout,
			first_set, bind_count, &sets_to_bind[0], 0, null);
	}
	return;
}

// Frame-aware Vulkan descriptor-set allocation. (and HPL2's RIDescriptorSetAllocator).
const uint RPI_FRAMES_IN_FLIGHT = 5;
const uint RPI_DESCRIPTOR_SETS_PER_POOL = 64;
const uint RPI_ALLOC_HASH_BUCKETS = 256;
const uint RPI_SLOT_BLOCK_SIZE = 1024;

// A cached descriptor set with intrusive LRU-queue and hash-chain links.
// Slots live in separately allocated fixed-size blocks so List growth can
// never invalidate a slot pointer already present in either chain.
struct RpiDescriptorSetSlot
{
	ulong hash;
	uint frame_count;
	RpiDescriptorSetSlot* qu_next;
	RpiDescriptorSetSlot* qu_prev;
	RpiDescriptorSetSlot* h_next;
	RpiDescriptorSetSlot* h_prev;
	vk::DescriptorPool pool;
	vk::DescriptorSet handle;
}

struct RpiDescriptorSetSlotBlock
{
	RpiDescriptorSetSlot[] slots;
}

// The per-descriptor-set LRU allocator.
struct RpiDescriptorSetAlloc
{
	uint frames_in_flight;
	RpiPoolSizes sizes;
	vk::DescriptorSetLayout set_layout;
	RpiDescriptorSetSlot*[RPI_ALLOC_HASH_BUCKETS] hash_slots;
	RpiDescriptorSetSlot* queue_begin;
	RpiDescriptorSetSlot* queue_end;
	List{RpiDescriptorSetSlot*} reserved;
	List{vk::DescriptorPool} pools;
	List{RpiDescriptorSetSlotBlock} blocks;
	sz block_index;
	Allocator allocator;
}

fn RpiDescriptorSetAlloc rpi_descriptor_set_alloc_init(vk::DescriptorSetLayout set_layout, RpiPoolSizes sizes, uint frames_in_flight, Allocator allocator = mem)
{
	RpiDescriptorSetAlloc result = {
		.frames_in_flight = frames_in_flight,
		.sizes = sizes,
		.set_layout = set_layout,
		.allocator = allocator,
	};
	result.reserved.init(allocator);
	result.pools.init(allocator);
	result.blocks.init(allocator);
	return result;
}

// The GPU must be idle: cached descriptor sets and their pools must no longer
// be referenced by any command buffer.
fn void rpi_descriptor_set_alloc_free(RpiDescriptorSetAlloc* a, Device* device)
{
	foreach (pool : a.pools)
	{
		device.backend.vk.vtable.destroyDescriptorPool(device.backend.vk.device, pool, null);
	}
	foreach (&block : a.blocks)
	{
		alloc::free(a.allocator, block.slots.ptr);
	}
	a.pools.free();
	a.reserved.free();
	a.blocks.free();
	*a = {};
}

// Resolve a descriptor set for a monotonically increasing frame counter and
// content hash. `found` is true for a cache hit; on a miss the caller must
// write the returned set before binding it.
fn RpiDescriptorSetSlot*? rpi_descriptor_set_alloc_resolve(RpiDescriptorSetAlloc* a, Device* device, uint frame_count, ulong hash, bool* found)
{
	*found = false;
	uint hash_index = (uint)(hash % RPI_ALLOC_HASH_BUCKETS);

	// Cache hit: move the slot to the MRU end of the queue.
	for (RpiDescriptorSetSlot* slot = a.hash_slots[hash_index]; slot != null; slot = slot.h_next)
	{
		if (slot.hash != hash) continue;
		if (a.queue_end != slot)
		{
			if (a.queue_begin == slot)
			{
				a.queue_begin = slot.qu_next;
				if (slot.qu_next != null) slot.qu_next.qu_prev = null;
			}
			else
			{
				if (slot.qu_prev != null) slot.qu_prev.qu_next = slot.qu_next;
				if (slot.qu_next != null) slot.qu_next.qu_prev = slot.qu_prev;
			}
			slot.qu_next = null;
			slot.qu_prev = a.queue_end;
			if (a.queue_end != null) a.queue_end.qu_next = slot;
			a.queue_end = slot;
		}
		slot.frame_count = frame_count;
		*found = true;
		return slot;
	}

	// Recycle the LRU head only after the frame-safety window has elapsed.
	RpiDescriptorSetSlot* begin = a.queue_begin;
	if (begin != null && frame_count > begin.frame_count + a.frames_in_flight)
	{
		rpi_descriptor_set_alloc_detach(a, begin);
		begin.frame_count = frame_count;
		begin.hash = hash;
		rpi_descriptor_set_alloc_attach(a, begin);
		return begin;
	}

	// No reusable set: allocate another pool and reserve its fresh slots.
	if (a.reserved.len() == 0)
	{
		rpi_descriptor_set_alloc_create_pool(a, device)!;
		assert(a.reserved.len() > 0);
	}
	RpiDescriptorSetSlot* slot = a.reserved[a.reserved.len() - 1];
	a.reserved.remove_last()!!;
	slot.hash = hash;
	slot.frame_count = frame_count;
	rpi_descriptor_set_alloc_attach(a, slot);
	return slot;
}

// Create one descriptor pool sized for one set's reflected descriptor counts,
// then allocate RPI_DESCRIPTOR_SETS_PER_POOL sets into the reserve.
fn void? rpi_descriptor_set_alloc_create_pool(RpiDescriptorSetAlloc* a, Device* device) @private
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;
	vk::Device dev = device.backend.vk.device;
	vk::DescriptorPoolSize[5] pool_sizes;
	uint pool_size_count = 0;

	if (a.sizes.sampler > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.SAMPLER, .descriptorCount = a.sizes.sampler * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.sampled_image > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.SAMPLED_IMAGE, .descriptorCount = a.sizes.sampled_image * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.storage_image > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.STORAGE_IMAGE, .descriptorCount = a.sizes.storage_image * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.uniform_buffer > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.UNIFORM_BUFFER, .descriptorCount = a.sizes.uniform_buffer * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}
	if (a.sizes.storage_buffer > 0)
	{
		pool_sizes[pool_size_count] = { .type = vk::DescriptorType.STORAGE_BUFFER, .descriptorCount = a.sizes.storage_buffer * RPI_DESCRIPTOR_SETS_PER_POOL };
		pool_size_count += 1;
	}

	vk::DescriptorPoolCreateInfo pool_info = {
		.sType = vk::StructureType.DESCRIPTOR_POOL_CREATE_INFO,
		.flags = vk::DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
		.maxSets = RPI_DESCRIPTOR_SETS_PER_POOL,
		.poolSizeCount = pool_size_count,
		.pPoolSizes = pool_size_count > 0 ? &pool_sizes[0] : null,
	};
	vk::DescriptorPool pool;
	vk::Result result = vtable.createDescriptorPool(dev, &pool_info, null, &pool);
	if (result != vk::Result.SUCCESS) return vk_check(result);

	vk::DescriptorSetLayout[RPI_DESCRIPTOR_SETS_PER_POOL] layouts;
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++) layouts[i] = a.set_layout;
	vk::DescriptorSet[RPI_DESCRIPTOR_SETS_PER_POOL] handles;
	vk::DescriptorSetAllocateInfo alloc_info = {
		.sType = vk::StructureType.DESCRIPTOR_SET_ALLOCATE_INFO,
		.descriptorPool = pool,
		.descriptorSetCount = RPI_DESCRIPTOR_SETS_PER_POOL,
		.pSetLayouts = &layouts[0],
	};
	result = vtable.allocateDescriptorSets(dev, &alloc_info, &handles[0]);
	if (result != vk::Result.SUCCESS)
	{
		vtable.destroyDescriptorPool(dev, pool, null);
		return vk_check(result);
	}

	// alloc_slot can fail while adding a new stable block. Restore only the
	// allocator metadata created by this pool before propagating that failure.
	sz old_block_count = a.blocks.len();
	sz old_block_index = a.block_index;
	bool committed = false;
	defer if (!committed)
	{
		a.block_index = old_block_index;
		while (a.blocks.len() > old_block_count)
		{
			RpiDescriptorSetSlotBlock* block = &a.blocks[a.blocks.len() - 1];
			alloc::free(a.allocator, block.slots.ptr);
			a.blocks.remove_last()!!;
		}
		vtable.destroyDescriptorPool(dev, pool, null);
	};

	RpiDescriptorSetSlot*[RPI_DESCRIPTOR_SETS_PER_POOL] slots;
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++)
	{
		slots[i] = rpi_descriptor_set_alloc_alloc_slot(a)!;
		slots[i].pool = pool;
		slots[i].handle = handles[i];
	}
	a.pools.push(pool);
	for (sz i = 0; i < RPI_DESCRIPTOR_SETS_PER_POOL; i++) a.reserved.push(slots[i]);
	committed = true;
}

// Allocate the next slot from the current fixed heap block, allocating a new
// block only when the current block is exhausted.
fn RpiDescriptorSetSlot*? rpi_descriptor_set_alloc_alloc_slot(RpiDescriptorSetAlloc* a) @private
{
	if (a.blocks.len() == 0 || a.block_index == RPI_SLOT_BLOCK_SIZE)
	{
		RpiDescriptorSetSlot[] slots = alloc::alloc_array_try(a.allocator, RpiDescriptorSetSlot, RPI_SLOT_BLOCK_SIZE)!;
		slots[..] = {};
		a.blocks.push({ .slots = slots });
		a.block_index = 0;
	}
	RpiDescriptorSetSlotBlock* block = &a.blocks[a.blocks.len() - 1];
	RpiDescriptorSetSlot* slot = &block.slots[a.block_index];
	a.block_index += 1;
	return slot;
}

// Append a slot at the MRU queue end and prepend it in its hash bucket.
fn void rpi_descriptor_set_alloc_attach(RpiDescriptorSetAlloc* a, RpiDescriptorSetSlot* slot) @private
{
	slot.qu_next = null;
	slot.qu_prev = a.queue_end;
	if (a.queue_end != null) a.queue_end.qu_next = slot;
	a.queue_end = slot;
	if (a.queue_begin == null) a.queue_begin = slot;

	uint hash_index = (uint)(slot.hash % RPI_ALLOC_HASH_BUCKETS);
	slot.h_prev = null;
	slot.h_next = a.hash_slots[hash_index];
	if (a.hash_slots[hash_index] != null) a.hash_slots[hash_index].h_prev = slot;
	a.hash_slots[hash_index] = slot;
}

// Unlink a slot from both the LRU queue and its hash bucket.
fn void rpi_descriptor_set_alloc_detach(RpiDescriptorSetAlloc* a, RpiDescriptorSetSlot* slot) @private
{
	if (a.queue_begin == slot)
	{
		a.queue_begin = slot.qu_next;
		if (slot.qu_next != null) slot.qu_next.qu_prev = null;
		if (a.queue_end == slot) a.queue_end = null;
	}
	else if (a.queue_end == slot)
	{
		a.queue_end = slot.qu_prev;
		if (slot.qu_prev != null) slot.qu_prev.qu_next = null;
	}
	else
	{
		if (slot.qu_prev != null) slot.qu_prev.qu_next = slot.qu_next;
		if (slot.qu_next != null) slot.qu_next.qu_prev = slot.qu_prev;
	}

	uint hash_index = (uint)(slot.hash % RPI_ALLOC_HASH_BUCKETS);
	if (a.hash_slots[hash_index] == slot)
	{
		a.hash_slots[hash_index] = slot.h_next;
		if (slot.h_next != null) slot.h_next.h_prev = null;
	}
	else
	{
		if (slot.h_prev != null) slot.h_prev.h_next = slot.h_next;
		if (slot.h_next != null) slot.h_next.h_prev = slot.h_prev;
	}
	slot.h_prev = null;
	slot.h_next = null;
}

fn vk::DescriptorType vk_descriptor_type_from(DescriptorType type)
{
	switch (type)
	{
		case SAMPLED_IMAGE: return vk::DescriptorType.SAMPLED_IMAGE;
		case STORAGE_IMAGE: return vk::DescriptorType.STORAGE_IMAGE;
		case SAMPLER: return vk::DescriptorType.SAMPLER;
		case UNIFORM_BUFFER: return vk::DescriptorType.UNIFORM_BUFFER;
		case STORAGE_BUFFER: return vk::DescriptorType.STORAGE_BUFFER;
		case ACCELERATION_STRUCTURE: return vk::DescriptorType.ACCELERATION_STRUCTURE_KHR;
	}
}

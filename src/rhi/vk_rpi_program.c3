// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan arm of the render-program layer. Port of rhi/vulkan.odin
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

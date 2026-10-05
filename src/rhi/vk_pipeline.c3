module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import vk;

struct PipelineVk
{
	vk::Pipeline pipeline;
	vk::PipelineLayout layout;
}

fn vk::BlendFactor to_vk_blend_factor(BlendFactor factor) @private
{
	switch (factor)
	{
	case ZERO: return vk::BlendFactor.ZERO;
	case ONE: return vk::BlendFactor.ONE;
	case SRC_COLOR: return vk::BlendFactor.SRC_COLOR;
	case ONE_MINUS_SRC_COLOR: return vk::BlendFactor.ONE_MINUS_SRC_COLOR;
	case DST_COLOR: return vk::BlendFactor.DST_COLOR;
	case ONE_MINUS_DST_COLOR: return vk::BlendFactor.ONE_MINUS_DST_COLOR;
	case SRC_ALPHA: return vk::BlendFactor.SRC_ALPHA;
	case ONE_MINUS_SRC_ALPHA: return vk::BlendFactor.ONE_MINUS_SRC_ALPHA;
	case DST_ALPHA: return vk::BlendFactor.DST_ALPHA;
	case ONE_MINUS_DST_ALPHA: return vk::BlendFactor.ONE_MINUS_DST_ALPHA;
	case CONSTANT_COLOR: return vk::BlendFactor.CONSTANT_COLOR;
	case ONE_MINUS_CONSTANT_COLOR: return vk::BlendFactor.ONE_MINUS_CONSTANT_COLOR;
	case CONSTANT_ALPHA: return vk::BlendFactor.CONSTANT_ALPHA;
	case ONE_MINUS_CONSTANT_ALPHA: return vk::BlendFactor.ONE_MINUS_CONSTANT_ALPHA;
	case SRC_ALPHA_SATURATE: return vk::BlendFactor.SRC_ALPHA_SATURATE;
	}
}

fn vk::BlendOp to_vk_blend_op(BlendOp op) @private
{
	switch (op)
	{
	case ADD: return vk::BlendOp.ADD;
	case SUBTRACT: return vk::BlendOp.SUBTRACT;
	case REVERSE_SUBTRACT: return vk::BlendOp.REVERSE_SUBTRACT;
	case MIN: return vk::BlendOp.MIN;
	case MAX: return vk::BlendOp.MAX;
	}
}

fn vk::CompareOp to_vk_compare_op(CompareOp op) @private
{
	switch (op)
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

fn vk::Format to_vk_vertex_format(VertexFormat format) @private
{
	switch (format)
	{
	case FLOAT: return vk::Format.R32_SFLOAT;
	case FLOAT2: return vk::Format.R32G32_SFLOAT;
	case FLOAT3: return vk::Format.R32G32B32_SFLOAT;
	case FLOAT4: return vk::Format.R32G32B32A32_SFLOAT;
	}
}

fn vk::PrimitiveTopology to_vk_topology(PrimitiveTopology topology) @private
{
	switch (topology)
	{
	case POINT_LIST: return vk::PrimitiveTopology.POINT_LIST;
	case LINE_LIST: return vk::PrimitiveTopology.LINE_LIST;
	case LINE_STRIP: return vk::PrimitiveTopology.LINE_STRIP;
	case TRIANGLE_LIST: return vk::PrimitiveTopology.TRIANGLE_LIST;
	case TRIANGLE_STRIP: return vk::PrimitiveTopology.TRIANGLE_STRIP;
	}
}

fn vk::CullModeFlags to_vk_cull_mode(CullMode mode) @private
{
	switch (mode)
	{
	case NONE: return 0;
	case FRONT: return vk::CULL_MODE_FRONT_BIT;
	case BACK: return vk::CULL_MODE_BACK_BIT;
	}
}

fn vk::FrontFace to_vk_front_face(FrontFace face) @private
{
	switch (face)
	{
	case CLOCKWISE: return vk::FrontFace.CLOCKWISE;
	case COUNTER_CLOCKWISE: return vk::FrontFace.COUNTER_CLOCKWISE;
	}
}

fn Pipeline? pipeline_init_graphics_vk(Device* device, PipelineGraphicsOptions options)
{
	ShaderVk shader = options.shader.backend.vk;
	assert(options.colors.len <= MAX_COLOR_ATTACHMENTS);

	vk::PipelineShaderStageCreateInfo[2] stages = {
		{
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_VERTEX_BIT,
			.module_ = shader.vertex_module,
			.pName = "main",
		},
		{
			.sType = vk::StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
			.stage = vk::SHADER_STAGE_FRAGMENT_BIT,
			.module_ = shader.pixel_module,
			.pName = "main",
		},
	};

	vk::PipelineColorBlendAttachmentState[MAX_COLOR_ATTACHMENTS] color_attachments = {};
	vk::Format[MAX_COLOR_ATTACHMENTS] color_formats = {};
	foreach (i, target : options.colors) {
		BlendState blend = {
			.src_color = ONE,
			.dst_color = ZERO,
			.color_op = ADD,
			.src_alpha = ONE,
			.dst_alpha = ZERO,
			.alpha_op = ADD,
			.write_mask = WRITE_MASK_ALL,
		};
		if (target.has_blend) blend = target.blend;

		vk::ColorComponentFlags write_mask = 0;
		if (blend.write_mask.r) write_mask |= vk::COLOR_COMPONENT_R_BIT;
		if (blend.write_mask.g) write_mask |= vk::COLOR_COMPONENT_G_BIT;
		if (blend.write_mask.b) write_mask |= vk::COLOR_COMPONENT_B_BIT;
		if (blend.write_mask.a) write_mask |= vk::COLOR_COMPONENT_A_BIT;

		color_formats[i] = to_vk_format(target.format);
		color_attachments[i] = {
			.blendEnable = target.has_blend ? vk::TRUE : vk::FALSE,
			.srcColorBlendFactor = to_vk_blend_factor(blend.src_color),
			.dstColorBlendFactor = to_vk_blend_factor(blend.dst_color),
			.colorBlendOp = to_vk_blend_op(blend.color_op),
			.srcAlphaBlendFactor = to_vk_blend_factor(blend.src_alpha),
			.dstAlphaBlendFactor = to_vk_blend_factor(blend.dst_alpha),
			.alphaBlendOp = to_vk_blend_op(blend.alpha_op),
			.colorWriteMask = write_mask,
		};
	}

	vk::DynamicState[2] dynamic_states = {
		vk::DynamicState.VIEWPORT,
		vk::DynamicState.SCISSOR,
	};
	vk::PipelineDynamicStateCreateInfo dynamic_state = {
		.sType = vk::StructureType.PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		.dynamicStateCount = dynamic_states.len,
		.pDynamicStates = &dynamic_states[0],
	};
	vk::PipelineColorBlendStateCreateInfo color_blend = {
		.sType = vk::StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		.logicOpEnable = vk::FALSE,
		.logicOp = vk::LogicOp.CLEAR,
		.attachmentCount = options.colors.len,
		.pAttachments = &color_attachments[0],
		.blendConstants = { 0, 0, 0, 0 },
	};
	vk::PipelineViewportStateCreateInfo viewport = {
		.sType = vk::StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		.viewportCount = 1,
		.scissorCount = 1,
	};

	vk::PipelineRasterizationStateCreateInfo rasterization = {
		.sType = vk::StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		.depthClampEnable = vk::FALSE,
		.rasterizerDiscardEnable = vk::FALSE,
		.polygonMode = vk::PolygonMode.FILL,
		.cullMode = to_vk_cull_mode(options.raster.cull_mode),
		.frontFace = to_vk_front_face(options.raster.front_face),
		.depthBiasEnable = vk::FALSE,
		.lineWidth = 1.0,
	};
	vk::PipelineInputAssemblyStateCreateInfo input_assembly = {
		.sType = vk::StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		.topology = to_vk_topology(options.raster.topology),
		.primitiveRestartEnable = vk::FALSE,
	};
	vk::PipelineMultisampleStateCreateInfo multisample = {
		.sType = vk::StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		.rasterizationSamples = vk::SAMPLE_COUNT_1_BIT,
		.sampleShadingEnable = vk::FALSE,
	};

	vk::VertexInputBindingDescription binding = {};
	vk::VertexInputAttributeDescription[MAX_COLOR_ATTACHMENTS] attributes = {};
	vk::PipelineVertexInputStateCreateInfo vertex_input = {
		.sType = vk::StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
	};
	if (options.has_vertex_layout) {
		assert(options.vertex_layout.attributes.len <= MAX_COLOR_ATTACHMENTS);
		binding = {
			.binding = 0,
			.stride = options.vertex_layout.stride,
			.inputRate = vk::VertexInputRate.VERTEX,
		};
		foreach (i, attribute : options.vertex_layout.attributes) {
			attributes[i] = {
				.location = attribute.location,
				.binding = 0,
				.format = to_vk_vertex_format(attribute.format),
				.offset = attribute.offset,
			};
		}
		vertex_input.vertexBindingDescriptionCount = 1;
		vertex_input.pVertexBindingDescriptions = &binding;
		vertex_input.vertexAttributeDescriptionCount = options.vertex_layout.attributes.len;
		vertex_input.pVertexAttributeDescriptions = &attributes[0];
	}

	vk::PushConstantRange[1] push_constants = {};
	vk::PipelineLayoutCreateInfo layout_info = {
		.sType = vk::StructureType.PIPELINE_LAYOUT_CREATE_INFO,
	};
	if (options.push_constant_size > 0) {
		push_constants[0] = {
			.stageFlags = vk::SHADER_STAGE_VERTEX_BIT,
			.offset = 0,
			.size = options.push_constant_size,
		};
		layout_info.pushConstantRangeCount = 1;
		layout_info.pPushConstantRanges = &push_constants[0];
	}

	vk::PipelineLayout layout;
	vk_check(device.backend.vk.vtable.createPipelineLayout(device.backend.vk.device, &layout_info, null, &layout))!;

	vk::PipelineDepthStencilStateCreateInfo depth_stencil = {
		.sType = vk::StructureType.PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
		.depthTestEnable = options.has_depth ? vk::TRUE : vk::FALSE,
		.depthWriteEnable = options.has_depth && options.depth.write ? vk::TRUE : vk::FALSE,
		.depthCompareOp = options.has_depth ? to_vk_compare_op(options.depth.compare) : vk::CompareOp.LESS,
		.depthBoundsTestEnable = vk::FALSE,
		.stencilTestEnable = vk::FALSE,
		.minDepthBounds = 0.0,
		.maxDepthBounds = 1.0,
	};

	vk::PipelineRenderingCreateInfo rendering = {
		.sType = vk::StructureType.PIPELINE_RENDERING_CREATE_INFO,
		.colorAttachmentCount = options.colors.len,
		.pColorAttachmentFormats = &color_formats[0],
		.depthAttachmentFormat = options.has_depth ? to_vk_format(options.depth.format) : vk::Format.UNDEFINED,
		.stencilAttachmentFormat = options.has_depth && format_get_props(options.depth.format).is_stencil
			? to_vk_format(options.depth.format)
			: vk::Format.UNDEFINED,
	};

	vk::GraphicsPipelineCreateInfo pipeline_info = {
		.sType = vk::StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
		.stageCount = stages.len,
		.pStages = &stages[0],
		.pVertexInputState = &vertex_input,
		.pInputAssemblyState = &input_assembly,
		.pViewportState = &viewport,
		.pRasterizationState = &rasterization,
		.pMultisampleState = &multisample,
		.pDepthStencilState = &depth_stencil,
		.pColorBlendState = &color_blend,
		.pDynamicState = &dynamic_state,
		.layout = layout,
		.basePipelineIndex = -1,
	};
	vk_add_next(&pipeline_info, &rendering);

	vk::Pipeline pipeline;
	if (catch err = vk_check(device.backend.vk.vtable.createGraphicsPipelines(
		device.backend.vk.device, vk::NULL_HANDLE, 1, &pipeline_info, null, &pipeline))) {
		device.backend.vk.vtable.destroyPipelineLayout(device.backend.vk.device, layout, null);
		return err~;
	}

	return {
		.cookie = next_cookie(),
		.backend.vk = { .pipeline = pipeline, .layout = layout },
	};
}

fn void pipeline_deinit_vk(Pipeline* pipeline, Device* device)
{
	if (pipeline.backend.vk.pipeline != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyPipeline(device.backend.vk.device, pipeline.backend.vk.pipeline, null);
	}
	if (pipeline.backend.vk.layout != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyPipelineLayout(device.backend.vk.device, pipeline.backend.vk.layout, null);
	}
	pipeline.backend.vk = {};
	pipeline.cookie = 0;
}

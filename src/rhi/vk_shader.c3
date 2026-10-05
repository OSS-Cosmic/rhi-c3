module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));

import vk;

struct ShaderVk
{
	vk::ShaderModule vertex_module;
	vk::ShaderModule tesselation_control_module;
	vk::ShaderModule tesselation_evaluation_module;
	vk::ShaderModule geometry_module;
	vk::ShaderModule pixel_module;
	vk::ShaderModule compute_module;
}

fn void? shader_create_module_vk(Device* device, char[] data, vk::ShaderModule* out_module) @private
{
	assert(data.len % 4 == 0);
	vk::ShaderModuleCreateInfo info = {
		.sType = vk::StructureType.SHADER_MODULE_CREATE_INFO,
		.codeSize = data.len,
		.pCode = (uint*)data.ptr,
	};
	vk::ShaderModule shader_module;
	vk_check(device.backend.vk.vtable.createShaderModule(device.backend.vk.device, &info, null, &shader_module))!;
	*out_module = shader_module;
}

fn void shader_destroy_modules_vk(Device* device, ShaderVk* shader) @private
{
	if (shader.vertex_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.vertex_module, null);
	}
	if (shader.tesselation_control_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.tesselation_control_module, null);
	}
	if (shader.tesselation_evaluation_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.tesselation_evaluation_module, null);
	}
	if (shader.geometry_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.geometry_module, null);
	}
	if (shader.pixel_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.pixel_module, null);
	}
	if (shader.compute_module != vk::NULL_HANDLE) {
		device.backend.vk.vtable.destroyShaderModule(device.backend.vk.device, shader.compute_module, null);
	}
	*shader = {};
}

fn Shader? shader_init_graphics_vk(Device* device, ShaderGraphicsOptions options)
{
	ShaderVk result = {};

	if (options.has_vertex_stage) {
		if (catch err = shader_create_module_vk(device, options.vertex_stage.data, &result.vertex_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}
	if (options.has_fragment_stage) {
		if (catch err = shader_create_module_vk(device, options.fragment_stage.data, &result.pixel_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}
	if (options.has_geometry_stage) {
		if (catch err = shader_create_module_vk(device, options.geometry_stage.data, &result.geometry_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}
	if (options.has_hull_stage) {
		if (catch err = shader_create_module_vk(device, options.hull_stage.data, &result.tesselation_control_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}
	if (options.has_domain_stage) {
		if (catch err = shader_create_module_vk(device, options.domain_stage.data, &result.tesselation_evaluation_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}
	if (options.has_comp_stage) {
		if (catch err = shader_create_module_vk(device, options.comp_stage.data, &result.compute_module)) {
			shader_destroy_modules_vk(device, &result);
			return err~;
		}
	}

	return {
		.cookie = next_cookie(),
		.backend.vk = result,
	};
}

fn void shader_deinit_vk(Shader* shader, Device* device)
{
	shader_destroy_modules_vk(device, &shader.backend.vk);
	shader.cookie = 0;
}

fn ShaderStages shader_stages_vk(Shader* shader)
{
	ShaderStages stages = {};
	stages.vertex = shader.backend.vk.vertex_module != vk::NULL_HANDLE;
	stages.tesselation_control = shader.backend.vk.tesselation_control_module != vk::NULL_HANDLE;
	stages.tesselation_evaluation = shader.backend.vk.tesselation_evaluation_module != vk::NULL_HANDLE;
	stages.geometry = shader.backend.vk.geometry_module != vk::NULL_HANDLE;
	stages.pixel = shader.backend.vk.pixel_module != vk::NULL_HANDLE;
	stages.compute = shader.backend.vk.compute_module != vk::NULL_HANDLE;
	return stages;
}

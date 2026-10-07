// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral GPU shader handle. Port of rhi-zig's `shader.zig`.
module rhi;

enum ShaderStage : char
{
	VERTEX,
	TESSELATION_CONTROL,
	TESSELATION_EVALUATION,
	GEOMETRY,
	PIXEL,
	COMPUTE,
}

bitstruct ShaderStages : char
{
	bool vertex : 0;
	bool tesselation_control : 1;
	bool tesselation_evaluation : 2;
	bool geometry : 3;
	bool pixel : 4;
	bool compute : 5;
}

const ShaderStages SHADER_STAGES_GRAPHICS = {
	.vertex = true,
	.tesselation_control = true,
	.tesselation_evaluation = true,
	.geometry = true,
	.pixel = true,
};

// One stage's code. `data` is backend-specific and supplied by the caller:
// SPIR-V words on Vulkan, DXIL on D3D12 (the DXBC-container blob dxc emits),
// WGSL source text on WebGPU, GLSL ES 3.00 source text on WebGL2, and MSL
// source text on Metal, where `entry_point` is required (the library is
// compiled at run time and the function looked up by that name; see the
// Metal binding-index convention in c3/README.md).
// `entry_point` names the WGSL entry function on WebGPU; Vulkan uses "main",
// D3D12 ignores it (the entry point is baked into the DXIL) and WebGL2
// ignores it (GLSL always enters at `main`).
struct ShaderStageDesc
{
	char[] data;
	String entry_point;
}

struct ShaderGraphicsOptions
{
	ShaderStageDesc vertex_stage;
	bool has_vertex_stage;
	ShaderStageDesc fragment_stage;
	bool has_fragment_stage;
	ShaderStageDesc geometry_stage;
	bool has_geometry_stage;
	ShaderStageDesc hull_stage;
	bool has_hull_stage;
	ShaderStageDesc domain_stage;
	bool has_domain_stage;
	ShaderStageDesc comp_stage;
	bool has_comp_stage;
}

struct Shader
{
	ulong cookie;
	union backend
	{
		ShaderVk vk;
		ShaderMtl mtl;
		ShaderWgpu wgpu;
		ShaderWebgl webgl;
		ShaderDx12 dx12;
	}
}

fn Shader? shader_init_graphics(Device* device, ShaderGraphicsOptions options)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return shader_init_graphics_vk(device, options);
			$endif
		case DX12:
			$if HAS_DX12:
				return shader_init_graphics_dx12(device, options);
			$endif
		case MTL:
			$if HAS_MTL:
				return shader_init_graphics_mtl(device, options);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return shader_init_graphics_wgpu(device, options);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return shader_init_graphics_webgl(device, options);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

fn void shader_deinit(Shader* s, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				shader_deinit_vk(s, device);
			$endif
		case DX12:
			$if HAS_DX12:
				shader_deinit_dx12(s, device);
			$endif
		case MTL:
			$if HAS_MTL:
				shader_deinit_mtl(s, device);
			$endif
			break;
		case WGPU:
			$if HAS_WGPU:
				shader_deinit_wgpu(s, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				shader_deinit_webgl(s, device);
			$endif
	}
}

fn bool shader_is_empty(Shader* s)
{
	return s.cookie == 0;
}

fn ShaderStages shader_stages(Shader* s)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return shader_stages_vk(s);
			$endif
		case DX12:
			$if HAS_DX12:
				return shader_stages_dx12(s);
			$endif
		case MTL:
			$if HAS_MTL:
				return shader_stages_mtl(s);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return shader_stages_wgpu(s);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return shader_stages_webgl(s);
			$endif
	}
	return {};
}

// ---- metal ----

// Metal shader. Port of the `.mtl` arm of rhi-zig's `shader.zig`.
//
// Each stage's `data` is MSL source compiled at run time into its own
// MTLLibrary; `entry_point` names the function looked up in it. Only vertex
// and fragment stages are supported.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import mtl;

struct ShaderMtl
{
	mtl::Library vertex_library;
	mtl::Function vertex_function;
	mtl::Library fragment_library;
	mtl::Function fragment_function;
	ShaderStages stages;
}

// Compiles one stage's MSL source and looks up its entry point. On success
// both `out_library` and `out_function` are owned by the caller; on failure
// nothing is left allocated.
fn void? mtl_compile_stage(mtl::Device device, ShaderStageDesc stage, String label, mtl::Library* out_library, mtl::Function* out_function) @private
{
	objc::@autoreleasepool()
	{
		mtl::NSString source = mtl::ns_string_from_utf8_slice(stage.data);
		mtl::NSError err = null;
		mtl::Library library = device.new_library_with_source(source, null, &err);
		if (!library)
		{
			if (err)
			{
				log::error("MSL compile (%s): %s", label, err.localized_description().utf8());
			}
			else
			{
				log::error("MSL compile (%s) failed", label);
			}
			return SHADER_COMPILATION_FAILED~;
		}
		mtl::Function function = library.new_function(mtl::ns_string_from_utf8_slice(stage.entry_point));
		if (!function)
		{
			log::error("MSL entry point not found (%s): %s", label, stage.entry_point);
			library.release();
			return SHADER_COMPILATION_FAILED~;
		}
		*out_library = library;
		*out_function = function;
	};
}

fn Shader? shader_init_graphics_mtl(Device* device, ShaderGraphicsOptions options)
{
	if (options.has_geometry_stage || options.has_hull_stage || options.has_domain_stage || options.has_comp_stage)
	{
		return UNSUPPORTED_SHADER_STAGE~;
	}
	mtl::Device dev = device.backend.mtl.device;
	Shader result = { .cookie = next_cookie(), .backend.mtl = {} };
	ShaderMtl* s = &result.backend.mtl;
	if (options.has_vertex_stage)
	{
		if (catch err = mtl_compile_stage(dev, options.vertex_stage, "vertex", &s.vertex_library, &s.vertex_function))
		{
			shader_deinit_mtl(&result, device);
			return err~;
		}
		s.stages.vertex = true;
	}
	if (options.has_fragment_stage)
	{
		if (catch err = mtl_compile_stage(dev, options.fragment_stage, "fragment", &s.fragment_library, &s.fragment_function))
		{
			shader_deinit_mtl(&result, device);
			return err~;
		}
		s.stages.pixel = true;
	}
	return result;
}

fn void shader_deinit_mtl(Shader* s, Device* device)
{
	ShaderMtl* m = &s.backend.mtl;
	if (m.vertex_function) m.vertex_function.release();
	if (m.vertex_library) m.vertex_library.release();
	if (m.fragment_function) m.fragment_function.release();
	if (m.fragment_library) m.fragment_library.release();
	*m = {};
	s.cookie = 0;
}

fn ShaderStages shader_stages_mtl(Shader* s)
{
	return s.backend.mtl.stages;
}

// ---- dx12 ----

// Direct3D 12 shader. D3D12 has no shader-module object: the DXIL (or DXBC)
// blob is handed to the pipeline state at creation, so a shader is just an
// owned copy of each stage's bytecode.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12;

struct ShaderDx12
{
	// Each slice is an owned copy; empty when the stage is absent.
	char[] vertex;
	char[] hull;
	char[] domain;
	char[] geometry;
	char[] pixel;
	char[] compute;
}

fn void? shader_copy_bytecode_dx12(char[] data, char[]* out) @local
{
	if (data.len == 0) return MISSING_SHADER_STAGE~;
	char* copy = mem::new_array(char, data.len);
	mem::copy(copy, data.ptr, data.len);
	*out = copy[:data.len];
}

fn void shader_free_bytecode_dx12(char[]* code) @local
{
	if (code.len > 0) mem::free(code.ptr);
	*code = {};
}

fn void shader_destroy_dx12(ShaderDx12* shader) @local
{
	shader_free_bytecode_dx12(&shader.vertex);
	shader_free_bytecode_dx12(&shader.hull);
	shader_free_bytecode_dx12(&shader.domain);
	shader_free_bytecode_dx12(&shader.geometry);
	shader_free_bytecode_dx12(&shader.pixel);
	shader_free_bytecode_dx12(&shader.compute);
}

// The view `D3D12_*_PIPELINE_STATE_DESC` wants. Points into the shader's own
// copy, so the shader must outlive the pipeline-creation call.
fn d3d12::ShaderBytecode shader_bytecode_dx12(char[] code)
{
	if (code.len == 0) return {};
	return { .bytecode = code.ptr, .length = code.len };
}

fn Shader? shader_init_graphics_dx12(Device* device, ShaderGraphicsOptions options)
{
	ShaderDx12 result = {};

	if (options.has_vertex_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.vertex_stage.data, &result.vertex))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}
	if (options.has_fragment_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.fragment_stage.data, &result.pixel))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}
	if (options.has_geometry_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.geometry_stage.data, &result.geometry))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}
	if (options.has_hull_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.hull_stage.data, &result.hull))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}
	if (options.has_domain_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.domain_stage.data, &result.domain))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}
	if (options.has_comp_stage)
	{
		if (catch err = shader_copy_bytecode_dx12(options.comp_stage.data, &result.compute))
		{
			shader_destroy_dx12(&result);
			return err~;
		}
	}

	return {
		.cookie = next_cookie(),
		.backend.dx12 = result,
	};
}

fn void shader_deinit_dx12(Shader* shader, Device* device)
{
	shader_destroy_dx12(&shader.backend.dx12);
	shader.cookie = 0;
}

fn ShaderStages shader_stages_dx12(Shader* shader)
{
	ShaderStages stages = {};
	stages.vertex = shader.backend.dx12.vertex.len > 0;
	stages.tesselation_control = shader.backend.dx12.hull.len > 0;
	stages.tesselation_evaluation = shader.backend.dx12.domain.len > 0;
	stages.geometry = shader.backend.dx12.geometry.len > 0;
	stages.pixel = shader.backend.dx12.pixel.len > 0;
	stages.compute = shader.backend.dx12.compute.len > 0;
	return stages;
}

// ---- vulkan ----

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

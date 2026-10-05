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

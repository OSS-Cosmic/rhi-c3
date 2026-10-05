// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

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

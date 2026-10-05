// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-agnostic Render Hardware Interface. Port of rhi-zig's `root.zig`.
//
// Backends are compiled in per platform and chosen at run time among those
// compiled in. Backend-specific code lives in this same module, one source
// file per backend, gated by `$if HAS_*`.
module rhi;
import std::atomic;

// `-D RHI_HEADLESS` compiles out every backend (a data-only build).
const bool RHI_HEADLESS = $feat(RHI_HEADLESS);

enum Backend : char
{
	VK,
	DX12,
	MTL,
	WGPU,
	WEBGL,
}

// Odin's `bit_set[Backend; u8]`: bit `1 << Backend.X.ordinal` per backend.
alias BackendSet = char;

const BackendSet BACKEND_VK = 1 << Backend.VK.ordinal;
const BackendSet BACKEND_DX12 = 1 << Backend.DX12.ordinal;
const BackendSet BACKEND_MTL = 1 << Backend.MTL.ordinal;
const BackendSet BACKEND_WGPU = 1 << Backend.WGPU.ordinal;
const BackendSet BACKEND_WEBGL = 1 << Backend.WEBGL.ordinal;

enum Selection : char
{
	DEFAULT,
	VK,
	DX12,
	MTL,
	WGPU,
	WEBGL,
}

// WebGPU and WebGL2 are web-only backends: they exist exactly on WebAssembly
// targets, and nowhere else.
const bool IS_WEB = env::ARCH_TYPE == ArchType.WASM32 || env::ARCH_TYPE == ArchType.WASM64;

// Port staging: a backend is compiled in only once its C3 port has landed.
// Each backend has a "ported" feature flag (`RHI_VK`, `RHI_DX12`, `RHI_MTL`,
// `RHI_WGPU`, `RHI_WEBGL`) that its backend ticket adds to `"features"` in
// c3/project.json; until then its `HAS_*` const is false, every dispatch arm
// for it is inert and backend_stubs.c3 supplies its stand-in payload structs.
//
// Top-level declarations can only be gated by feature flags (`@feat`), not by
// these consts, so each backend's gate is spelled twice: here as a const and
// in backend_stubs.c3 as the negated `@feat(...)` of its stand-in section
// (`WIN32`/`LINUX`/`DARWIN`/`WASM` are c3c's built-in platform features).
// Keep the two in sync.
const bool HAS_VK = $feat(RHI_VK) && !RHI_HEADLESS && !IS_WEB && (env::WIN32 || env::LINUX);
const bool HAS_DX12 = $feat(RHI_DX12) && !RHI_HEADLESS && !IS_WEB && env::WIN32;
const bool HAS_MTL = $feat(RHI_MTL) && !RHI_HEADLESS && !IS_WEB && env::DARWIN;
// Both web backends are compiled in and chosen at run time: the JS glue probes
// `navigator.gpu` first and falls back to WebGL2.
const bool HAS_WGPU = $feat(RHI_WGPU) && !RHI_HEADLESS && IS_WEB;
const bool HAS_WEBGL = $feat(RHI_WEBGL) && !RHI_HEADLESS && IS_WEB;

// The backends compiled in on this target: only ported ones are reported.
const BackendSet PLATFORM_API = (HAS_VK ? BACKEND_VK : 0)
	| (HAS_DX12 ? BACKEND_DX12 : 0)
	| (HAS_MTL ? BACKEND_MTL : 0)
	| (HAS_WGPU ? BACKEND_WGPU : 0)
	| (HAS_WEBGL ? BACKEND_WEBGL : 0);

fn bool platform_has_api(Backend api) @inline
{
	return (PLATFORM_API & (1 << api.ordinal)) != 0;
}

// Version of the contract between the wasm module and the JS glue.
//
// The two halves are separate files that a browser caches separately, so a
// stale `glue.js` can end up paired with a fresh `.wasm`. **Bump this whenever
// a foreign signature in the web backends changes**, and bump
// `GLUE_ABI_VERSION` in the glue to match.
const GLUE_ABI_VERSION = 5;

// Odin's `General_Error` enum. Odin's `Error` union (General_Error,
// Pipeline_Error, runtime.Allocator_Error) collapses into C3's single fault
// space: these faults, the allocator's faults, and Pipeline_Error's faults
// (declared below) all travel through `T?` returns.
faultdef
	UNSUPPORTED_BACKEND,
	UNSUPPORTED_FEATURE,
	INITIALIZATION_FAILED,
	OUT_OF_DEVICE_MEMORY,
	DEVICE_LOST,
	SURFACE_LOST,
	OUT_OF_DATE,
	TIMEOUT,
	BUFFER_NOT_MAPPED,
	UNKNOWN;

// Odin's `Pipeline_Error` enum (from pipeline.odin; its `None` is the absence
// of a fault).
faultdef
	SHADER_COMPILATION_FAILED,
	UNSUPPORTED_SHADER_STAGE,
	MISSING_SHADER_STAGE,
	MULTIPLE_RENDER_TARGETS_UNSUPPORTED,
	TOO_MANY_VERTEX_ATTRIBUTES,
	TOO_MANY_TEXTURE_BINDINGS,
	SAMPLER_NAME_REQUIRED,
	TEXTURE_BINDING_NOT_FOUND,
	BIND_GROUP_LAYOUT_MISSING,
	PUSH_CONSTANTS_NOT_FOUND,
	PUSH_CONSTANT_LAYOUT_MISMATCH,
	UNSUPPORTED_PUSH_CONSTANT_MEMBER,
	TOO_MANY_PUSH_CONSTANT_MEMBERS,
	DESCRIPTOR_MISSING,
	DESCRIPTOR_TYPE_MISMATCH,
	BINDING_NOT_FOUND,
	SAMPLER_REQUIRED;

// Backend-neutral descriptor category (mirrors `RIDescriptorType_e`). The
// engine uses separate sampled images + samplers (no combined-image-sampler).
enum DescriptorType : char
{
	SAMPLED_IMAGE,
	STORAGE_IMAGE,
	SAMPLER,
	UNIFORM_BUFFER,
	STORAGE_BUFFER,
	ACCELERATION_STRUCTURE,
}

// Monotonic source of resource identity cookies. A cookie is a stable, unique
// id stamped on a resource at creation; it is used as a descriptor-set cache
// key because a raw backend handle is unsafe as identity (handles get reused).
// `0` is reserved for "empty / uncreated".
ulong cookie_counter @private = 1;

fn ulong next_cookie()
{
	$if IS_WEB:
		// A web build is single-threaded (one browser main thread).
		return cookie_counter++;
	$else
		return atomic::fetch_add(&cookie_counter, (ulong)1);
	$endif
}

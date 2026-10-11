// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi;

enum Format : ushort
{
	UNKNOWN,
	// opengl specific
	L8_A8_UNORM,
	L8_UNORM,
	A8_UNORM,
	D16_UNORM_S8_UINT,
	D24_UNORM_S8_UINT,
	D32_SFLOAT_S8_UINT,
	R8_UNORM,
	R8_SNORM,
	R8_UINT,
	R8_SINT,
	RG8_UNORM,
	RG8_SNORM,
	RG8_UINT,
	RG8_SINT,
	BGRA8_UNORM,
	BGRA8_SRGB,
	BGR8_UNORM,
	RGB8_UNORM,
	RGBA8_UNORM,
	RGBA8_SNORM,
	RGBA8_UINT,
	RGBA8_SINT,
	RGBA8_SRGB,
	R16_UNORM,
	R16_SNORM,
	R16_UINT,
	R16_SINT,
	R16_SFLOAT,
	RG16_UNORM,
	RG16_SNORM,
	RG16_UINT,
	RG16_SINT,
	RG16_SFLOAT,
	RGBA16_UNORM,
	RGBA16_SNORM,
	RGBA16_UINT,
	RGBA16_SINT,
	RGBA16_SFLOAT,
	R32_UINT,
	R32_SINT,
	R32_SFLOAT,
	RG32_UINT,
	RG32_SINT,
	RG32_SFLOAT,
	RGB32_UINT,
	RGB32_SINT,
	RGB32_SFLOAT,
	RGBA32_UINT,
	RGBA32_SINT,
	RGBA32_SFLOAT,
	R10_G10_B10_A2_UNORM,
	R10_G10_B10_A2_UINT,
	R11_G11_B10_UFLOAT,
	R9_G9_B9_E5_UNORM,
	R5_G6_B5_UNORM,
	R5_G5_B5_A1_UNORM,
	R4_G4_B4_A4_UNORM,
	BC1_RGBA_UNORM,
	BC1_RGBA_SRGB,
	BC2_RGBA_UNORM,
	BC2_RGBA_SRGB,
	BC3_RGBA_UNORM,
	BC3_RGBA_SRGB,
	BC4_R_UNORM,
	BC4_R_SNORM,
	BC5_RG_UNORM,
	BC5_RG_SNORM,
	BC6H_RGB_UFLOAT,
	BC6H_RGB_SFLOAT,
	BC7_RGBA_UNORM,
	BC7_RGBA_SRGB,
	D16_UNORM,
	D32_SFLOAT,
	D32_SFLOAT_S8_UINT_X24,
	R24_UNORM_X8,
	X24_R8_UINT,
	X32_R8_UINT_X24,
	R32_SFLOAT_X8_X24,
	ETC1_R8G8B8_OES,
	ETC2_R8G8B8_UNORM,
	ETC2_R8G8B8_SRGB,
	ETC2_R8G8B8A1_UNORM,
	ETC2_R8G8B8A1_SRGB,
	ETC2_R8G8B8A8_UNORM,
	ETC2_R8G8B8A8_SRGB,
	ETC2_EAC_R11_UNORM,
	ETC2_EAC_R11_SNORM,
	ETC2_EAC_R11G11_UNORM,
	ETC2_EAC_R11G11_SNORM,
}

struct FormatProperties
{
	String name;                // format name
	Format format;              // self, filled in by `GetProps`
	char red_or_depth_bits;
	char green_or_stencil_bits;
	char blue_bits;             // B bits (0 if channels < 3)
	char alpha_bits;            // A (or shared exponent) bits (0 if channels < 4)
	char luminance_bits;        // L luminance
	uint stride;                // block size in bytes
	uint block_width;           // 1 for plain formats, >1 for compressed
	uint block_height;          // 1 for plain formats, >1 for compressed
	bool is_bgr;                // reversed channels (RGBA => BGRA)
	bool is_compressed;         // block-compressed format
	bool is_depth;              // has depth component
	bool is_exp_shared;         // shared exponent in alpha channel
	bool is_float;              // floating point
	bool is_packed;             // 16- or 32- bit packed
	bool is_integer;            // integer
	bool is_norm;               // [0; 1] normalized
	bool is_signed;             // signed
	bool is_srgb;               // sRGB
	bool is_stencil;            // has stencil component
}

fn usz format_channel_bit_width(FormatProperties self)
{
	return (usz)self.red_or_depth_bits + self.green_or_stencil_bits + self.blue_bits + self.alpha_bits + self.luminance_bits;
}

// Every `Format` must have an entry, in `Format` order: the table test walks
// all of them, so a missing or misplaced row fails `c3c test`.
const FormatProperties[Format::len] FORMAT_PROPS = {
	{ .name = "unknown", .format = Format.UNKNOWN },
	{ .name = "l8_a8_unorm", .format = Format.L8_A8_UNORM, .alpha_bits = 8, .luminance_bits = 8, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "l8_unorm", .format = Format.L8_UNORM, .luminance_bits = 8, .stride = 1, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "a8_unorm", .format = Format.A8_UNORM, .alpha_bits = 8, .stride = 1, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "d16_unorm_s8_uint", .format = Format.D16_UNORM_S8_UINT, .red_or_depth_bits = 16, .green_or_stencil_bits = 8, .stride = 3, .block_width = 1, .block_height = 1, .is_norm = true, .is_depth = true, .is_stencil = true },
	{ .name = "d24_unorm_s8_uint", .format = Format.D24_UNORM_S8_UINT, .red_or_depth_bits = 24, .green_or_stencil_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true, .is_depth = true, .is_stencil = true },
	{ .name = "d32_sfloat_s8_uint", .format = Format.D32_SFLOAT_S8_UINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 8, .stride = 8, .block_width = 1, .block_height = 1, .is_depth = true, .is_stencil = true, .is_float = true },
	{ .name = "r8_unorm", .format = Format.R8_UNORM, .red_or_depth_bits = 8, .stride = 1, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r8_snorm", .format = Format.R8_SNORM, .red_or_depth_bits = 8, .stride = 1, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "r8_uint", .format = Format.R8_UINT, .red_or_depth_bits = 8, .stride = 1, .block_width = 1, .block_height = 1 },
	{ .name = "r8_sint", .format = Format.R8_SINT, .red_or_depth_bits = 8, .stride = 1, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rg8_unorm", .format = Format.RG8_UNORM, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "rg8_snorm", .format = Format.RG8_SNORM, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "rg8_uint", .format = Format.RG8_UINT, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .stride = 2, .block_width = 1, .block_height = 1 },
	{ .name = "rg8_sint", .format = Format.RG8_SINT, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .stride = 2, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "bgra8_unorm", .format = Format.BGRA8_UNORM, .blue_bits = 8, .green_or_stencil_bits = 8, .red_or_depth_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true, .is_bgr = true },
	{ .name = "bgra8_srgb", .format = Format.BGRA8_SRGB, .blue_bits = 8, .green_or_stencil_bits = 8, .red_or_depth_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_srgb = true, .is_bgr = true },
	{ .name = "bgr8_unorm", .format = Format.BGR8_UNORM, .blue_bits = 8, .green_or_stencil_bits = 8, .red_or_depth_bits = 8, .stride = 3, .block_width = 1, .block_height = 1, .is_norm = true, .is_bgr = true },
	{ .name = "rgb8_unorm", .format = Format.RGB8_UNORM, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .stride = 3, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "rgba8_unorm", .format = Format.RGBA8_UNORM, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "rgba8_snorm", .format = Format.RGBA8_SNORM, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "rgba8_uint", .format = Format.RGBA8_UINT, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rgba8_sint", .format = Format.RGBA8_SINT, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_integer = true, .is_signed = true },
	{ .name = "rgba8_srgb", .format = Format.RGBA8_SRGB, .red_or_depth_bits = 8, .green_or_stencil_bits = 8, .blue_bits = 8, .alpha_bits = 8, .stride = 4, .block_width = 1, .block_height = 1, .is_srgb = true },
	{ .name = "r16_unorm", .format = Format.R16_UNORM, .red_or_depth_bits = 16, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r16_snorm", .format = Format.R16_SNORM, .red_or_depth_bits = 16, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "r16_uint", .format = Format.R16_UINT, .red_or_depth_bits = 16, .block_width = 1, .block_height = 1, .stride = 2 },
	{ .name = "r16_sint", .format = Format.R16_SINT, .red_or_depth_bits = 16, .stride = 2, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "r16_sfloat", .format = Format.R16_SFLOAT, .red_or_depth_bits = 16, .stride = 2, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "rg16_unorm", .format = Format.RG16_UNORM, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "rg16_snorm", .format = Format.RG16_SNORM, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "rg16_uint", .format = Format.RG16_UINT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .stride = 4, .block_width = 1, .block_height = 1 },
	{ .name = "rg16_sint", .format = Format.RG16_SINT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .stride = 4, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rg16_sfloat", .format = Format.RG16_SFLOAT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .stride = 4, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "rgba16_unorm", .format = Format.RGBA16_UNORM, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .alpha_bits = 16, .stride = 8, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "rgba16_snorm", .format = Format.RGBA16_SNORM, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .alpha_bits = 16, .stride = 8, .block_width = 1, .block_height = 1, .is_norm = true, .is_signed = true },
	{ .name = "rgba16_uint", .format = Format.RGBA16_UINT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .alpha_bits = 16, .stride = 8, .block_width = 1, .block_height = 1 },
	{ .name = "rgba16_sint", .format = Format.RGBA16_SINT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .alpha_bits = 16, .stride = 8, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rgba16_sfloat", .format = Format.RGBA16_SFLOAT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .alpha_bits = 16, .stride = 8, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "r32_uint", .format = Format.R32_UINT, .red_or_depth_bits = 32, .block_width = 1, .block_height = 1, .stride = 4 },
	{ .name = "r32_sint", .format = Format.R32_SINT, .red_or_depth_bits = 32, .stride = 4, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "r32_sfloat", .format = Format.R32_SFLOAT, .red_or_depth_bits = 32, .stride = 4, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "rg32_uint", .format = Format.RG32_UINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .block_width = 1, .block_height = 1, .stride = 8 },
	{ .name = "rg32_sint", .format = Format.RG32_SINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .stride = 8, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rg32_sfloat", .format = Format.RG32_SFLOAT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .stride = 8, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "rgb32_uint", .format = Format.RGB32_UINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .stride = 12, .block_width = 1, .block_height = 1 },
	{ .name = "rgb32_sint", .format = Format.RGB32_SINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .stride = 12, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rgb32_sfloat", .format = Format.RGB32_SFLOAT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .stride = 12, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "rgba32_uint", .format = Format.RGBA32_UINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .alpha_bits = 32, .stride = 16, .block_width = 1, .block_height = 1 },
	{ .name = "rgba32_sint", .format = Format.RGBA32_SINT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .alpha_bits = 32, .stride = 16, .block_width = 1, .block_height = 1, .is_integer = true },
	{ .name = "rgba32_sfloat", .format = Format.RGBA32_SFLOAT, .red_or_depth_bits = 32, .green_or_stencil_bits = 32, .blue_bits = 32, .alpha_bits = 32, .stride = 16, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "r10_g10_b10_a2_unorm", .format = Format.R10_G10_B10_A2_UNORM, .red_or_depth_bits = 10, .green_or_stencil_bits = 10, .blue_bits = 10, .alpha_bits = 2, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r10_g10_b10_a2_uint", .format = Format.R10_G10_B10_A2_UINT, .red_or_depth_bits = 10, .green_or_stencil_bits = 10, .blue_bits = 10, .alpha_bits = 2, .stride = 4, .block_width = 1, .block_height = 1 },
	{ .name = "r11_g11_b10_ufloat", .format = Format.R11_G11_B10_UFLOAT, .red_or_depth_bits = 11, .green_or_stencil_bits = 11, .blue_bits = 10, .stride = 4, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "r9_g9_b9_e5_unorm", .format = Format.R9_G9_B9_E5_UNORM, .red_or_depth_bits = 9, .green_or_stencil_bits = 9, .blue_bits = 9, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r5_g6_b5_unorm", .format = Format.R5_G6_B5_UNORM, .red_or_depth_bits = 5, .green_or_stencil_bits = 6, .blue_bits = 5, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r5_g5_b5_a1_unorm", .format = Format.R5_G5_B5_A1_UNORM, .red_or_depth_bits = 5, .green_or_stencil_bits = 5, .blue_bits = 5, .alpha_bits = 1, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "r4_g4_b4_a4_unorm", .format = Format.R4_G4_B4_A4_UNORM, .red_or_depth_bits = 4, .green_or_stencil_bits = 4, .blue_bits = 4, .alpha_bits = 4, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "bc1_rgba_unorm", .format = Format.BC1_RGBA_UNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc1_rgba_srgb", .format = Format.BC1_RGBA_SRGB, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "bc2_rgba_unorm", .format = Format.BC2_RGBA_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc2_rgba_srgb", .format = Format.BC2_RGBA_SRGB, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "bc3_rgba_unorm", .format = Format.BC3_RGBA_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc3_rgba_srgb", .format = Format.BC3_RGBA_SRGB, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "bc4_r_unorm", .format = Format.BC4_R_UNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc4_r_snorm", .format = Format.BC4_R_SNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true, .is_signed = true },
	{ .name = "bc5_rg_unorm", .format = Format.BC5_RG_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc5_rg_snorm", .format = Format.BC5_RG_SNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true, .is_signed = true },
	{ .name = "bc6h_rgb_ufloat", .format = Format.BC6H_RGB_UFLOAT, .red_or_depth_bits = 16, .green_or_stencil_bits = 16, .blue_bits = 16, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_float = true },
	{ .name = "bc6h_rgb_sfloat", .format = Format.BC6H_RGB_SFLOAT, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_float = true },
	{ .name = "bc7_rgba_unorm", .format = Format.BC7_RGBA_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "bc7_rgba_srgb", .format = Format.BC7_RGBA_SRGB, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "d16_unorm", .format = Format.D16_UNORM, .red_or_depth_bits = 16, .stride = 2, .block_width = 1, .block_height = 1, .is_norm = true, .is_depth = true },
	{ .name = "d32_sfloat", .format = Format.D32_SFLOAT, .red_or_depth_bits = 32, .stride = 4, .block_width = 1, .block_height = 1, .is_depth = true, .is_float = true },
	{ .name = "d32_sfloat_s8_uint_x24", .format = Format.D32_SFLOAT_S8_UINT_X24, .red_or_depth_bits = 32, .green_or_stencil_bits = 8, .stride = 8, .block_width = 1, .block_height = 1, .is_depth = true, .is_stencil = true, .is_float = true },
	{ .name = "r24_unorm_x8", .format = Format.R24_UNORM_X8, .red_or_depth_bits = 24, .stride = 4, .block_width = 1, .block_height = 1, .is_norm = true },
	{ .name = "x24_r8_uint", .format = Format.X24_R8_UINT, .red_or_depth_bits = 8, .stride = 4, .block_width = 1, .block_height = 1 },
	{ .name = "x32_r8_uint_x24", .format = Format.X32_R8_UINT_X24, .red_or_depth_bits = 8, .stride = 8, .block_width = 1, .block_height = 1 },
	{ .name = "r32_sfloat_x8_x24", .format = Format.R32_SFLOAT_X8_X24, .red_or_depth_bits = 32, .stride = 8, .block_width = 1, .block_height = 1, .is_float = true },
	{ .name = "etc1_r8g8b8_oes", .format = Format.ETC1_R8G8B8_OES, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true },
	{ .name = "etc2_r8g8b8_unorm", .format = Format.ETC2_R8G8B8_UNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "etc2_r8g8b8_srgb", .format = Format.ETC2_R8G8B8_SRGB, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "etc2_r8g8b8a1_unorm", .format = Format.ETC2_R8G8B8A1_UNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "etc2_r8g8b8a1_srgb", .format = Format.ETC2_R8G8B8A1_SRGB, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "etc2_r8g8b8a8_unorm", .format = Format.ETC2_R8G8B8A8_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "etc2_r8g8b8a8_srgb", .format = Format.ETC2_R8G8B8A8_SRGB, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_srgb = true },
	{ .name = "etc2_eac_r11_unorm", .format = Format.ETC2_EAC_R11_UNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "etc2_eac_r11_snorm", .format = Format.ETC2_EAC_R11_SNORM, .stride = 8, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true, .is_signed = true },
	{ .name = "etc2_eac_r11g11_unorm", .format = Format.ETC2_EAC_R11G11_UNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true },
	{ .name = "etc2_eac_r11g11_snorm", .format = Format.ETC2_EAC_R11G11_SNORM, .stride = 16, .block_width = 4, .block_height = 4, .is_compressed = true, .is_norm = true, .is_signed = true },
};

fn FormatProperties format_get_props(Format format) @inline
{
	return FORMAT_PROPS[format.ordinal];
}

// ---- metal ----

// Metal enum mapping: rhi formats and pipeline/sampler state to their MTL
// equivalents. The pixel format table extends rhi-zig's `metal.zig`
// `to_mtl_pixel_format`, and the vertex format and compare function mappings
// extend `pipeline.zig`'s `mtl_vertex_format` and `CompareOp.to_mtl`. The
// blend, sampler and raster mappings are new (rhi-zig has no blending).
//
// Depth/stencil queries go through `format_get_props(f).is_depth` /
// `.is_stencil`.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

fn mtl::PixelFormat to_mtl_pixel_format(Format f)
{
	switch (f)
	{
		case Format.UNKNOWN: return mtl::PixelFormat.INVALID;
		case Format.A8_UNORM: return mtl::PixelFormat.A8UNORM;
		case Format.D32_SFLOAT_S8_UINT: return mtl::PixelFormat.DEPTH32FLOAT_STENCIL8;
		case Format.R8_UNORM: return mtl::PixelFormat.R8UNORM;
		case Format.R8_SNORM: return mtl::PixelFormat.R8SNORM;
		case Format.R8_UINT: return mtl::PixelFormat.R8UINT;
		case Format.R8_SINT: return mtl::PixelFormat.R8SINT;
		case Format.RG8_UNORM: return mtl::PixelFormat.RG8UNORM;
		case Format.RG8_SNORM: return mtl::PixelFormat.RG8SNORM;
		case Format.RG8_UINT: return mtl::PixelFormat.RG8UINT;
		case Format.RG8_SINT: return mtl::PixelFormat.RG8SINT;
		case Format.BGRA8_UNORM: return mtl::PixelFormat.BGRA8UNORM;
		case Format.BGRA8_SRGB: return mtl::PixelFormat.BGRA8UNORM_SRGB;
		case Format.RGBA8_UNORM: return mtl::PixelFormat.RGBA8UNORM;
		case Format.RGBA8_SNORM: return mtl::PixelFormat.RGBA8SNORM;
		case Format.RGBA8_UINT: return mtl::PixelFormat.RGBA8UINT;
		case Format.RGBA8_SINT: return mtl::PixelFormat.RGBA8SINT;
		case Format.RGBA8_SRGB: return mtl::PixelFormat.RGBA8UNORM_SRGB;
		case Format.R16_UNORM: return mtl::PixelFormat.R16UNORM;
		case Format.R16_SNORM: return mtl::PixelFormat.R16SNORM;
		case Format.R16_UINT: return mtl::PixelFormat.R16UINT;
		case Format.R16_SINT: return mtl::PixelFormat.R16SINT;
		case Format.R16_SFLOAT: return mtl::PixelFormat.R16FLOAT;
		case Format.RG16_UNORM: return mtl::PixelFormat.RG16UNORM;
		case Format.RG16_SNORM: return mtl::PixelFormat.RG16SNORM;
		case Format.RG16_UINT: return mtl::PixelFormat.RG16UINT;
		case Format.RG16_SINT: return mtl::PixelFormat.RG16SINT;
		case Format.RG16_SFLOAT: return mtl::PixelFormat.RG16FLOAT;
		case Format.RGBA16_UNORM: return mtl::PixelFormat.RGBA16UNORM;
		case Format.RGBA16_SNORM: return mtl::PixelFormat.RGBA16SNORM;
		case Format.RGBA16_UINT: return mtl::PixelFormat.RGBA16UINT;
		case Format.RGBA16_SINT: return mtl::PixelFormat.RGBA16SINT;
		case Format.RGBA16_SFLOAT: return mtl::PixelFormat.RGBA16FLOAT;
		case Format.R32_UINT: return mtl::PixelFormat.R32UINT;
		case Format.R32_SINT: return mtl::PixelFormat.R32SINT;
		case Format.R32_SFLOAT: return mtl::PixelFormat.R32FLOAT;
		case Format.RG32_UINT: return mtl::PixelFormat.RG32UINT;
		case Format.RG32_SINT: return mtl::PixelFormat.RG32SINT;
		case Format.RG32_SFLOAT: return mtl::PixelFormat.RG32FLOAT;
		case Format.RGBA32_UINT: return mtl::PixelFormat.RGBA32UINT;
		case Format.RGBA32_SINT: return mtl::PixelFormat.RGBA32SINT;
		case Format.RGBA32_SFLOAT: return mtl::PixelFormat.RGBA32FLOAT;
		case Format.R10_G10_B10_A2_UNORM: return mtl::PixelFormat.RGB10A2UNORM;
		case Format.R10_G10_B10_A2_UINT: return mtl::PixelFormat.RGB10A2UINT;
		case Format.R11_G11_B10_UFLOAT: return mtl::PixelFormat.RG11B10FLOAT;
		case Format.R9_G9_B9_E5_UNORM: return mtl::PixelFormat.RGB9E5FLOAT;
		case Format.R5_G6_B5_UNORM: return mtl::PixelFormat.B5G6R5UNORM;
		case Format.R5_G5_B5_A1_UNORM: return mtl::PixelFormat.BGR5A1UNORM;
		case Format.R4_G4_B4_A4_UNORM: return mtl::PixelFormat.ABGR4UNORM;
		case Format.BC1_RGBA_UNORM: return mtl::PixelFormat.BC1_RGBA;
		case Format.BC1_RGBA_SRGB: return mtl::PixelFormat.BC1_RGBA_SRGB;
		case Format.BC2_RGBA_UNORM: return mtl::PixelFormat.BC2_RGBA;
		case Format.BC2_RGBA_SRGB: return mtl::PixelFormat.BC2_RGBA_SRGB;
		case Format.BC3_RGBA_UNORM: return mtl::PixelFormat.BC3_RGBA;
		case Format.BC3_RGBA_SRGB: return mtl::PixelFormat.BC3_RGBA_SRGB;
		case Format.BC4_R_UNORM: return mtl::PixelFormat.BC4_RUNORM;
		case Format.BC4_R_SNORM: return mtl::PixelFormat.BC4_RSNORM;
		case Format.BC5_RG_UNORM: return mtl::PixelFormat.BC5_RGUNORM;
		case Format.BC5_RG_SNORM: return mtl::PixelFormat.BC5_RGSNORM;
		case Format.BC6H_RGB_UFLOAT: return mtl::PixelFormat.BC6H_RGBUFLOAT;
		case Format.BC6H_RGB_SFLOAT: return mtl::PixelFormat.BC6H_RGBFLOAT;
		case Format.BC7_RGBA_UNORM: return mtl::PixelFormat.BC7_RGBAUNORM;
		case Format.BC7_RGBA_SRGB: return mtl::PixelFormat.BC7_RGBAUNORM_SRGB;
		case Format.D16_UNORM: return mtl::PixelFormat.DEPTH16UNORM;
		case Format.D32_SFLOAT: return mtl::PixelFormat.DEPTH32FLOAT;
		case Format.D24_UNORM_S8_UINT: return mtl::PixelFormat.DEPTH24UNORM_STENCIL8;
		case Format.D32_SFLOAT_S8_UINT_X24: return mtl::PixelFormat.DEPTH32FLOAT_STENCIL8;
		case Format.X24_R8_UINT: return mtl::PixelFormat.X24_STENCIL8;
		case Format.X32_R8_UINT_X24: return mtl::PixelFormat.X32_STENCIL8;
		case Format.ETC2_R8G8B8_UNORM: return mtl::PixelFormat.ETC2_RGB8;
		case Format.ETC1_R8G8B8_OES: return mtl::PixelFormat.ETC2_RGB8;
		case Format.ETC2_R8G8B8_SRGB: return mtl::PixelFormat.ETC2_RGB8_SRGB;
		case Format.ETC2_R8G8B8A1_UNORM: return mtl::PixelFormat.ETC2_RGB8A1;
		case Format.ETC2_R8G8B8A1_SRGB: return mtl::PixelFormat.ETC2_RGB8A1_SRGB;
		case Format.ETC2_R8G8B8A8_UNORM: return mtl::PixelFormat.EAC_RGBA8;
		case Format.ETC2_R8G8B8A8_SRGB: return mtl::PixelFormat.EAC_RGBA8_SRGB;
		case Format.ETC2_EAC_R11_UNORM: return mtl::PixelFormat.EAC_R11UNORM;
		case Format.ETC2_EAC_R11_SNORM: return mtl::PixelFormat.EAC_R11SNORM;
		case Format.ETC2_EAC_R11G11_UNORM: return mtl::PixelFormat.EAC_RG11UNORM;
		case Format.ETC2_EAC_R11G11_SNORM: return mtl::PixelFormat.EAC_RG11SNORM;
		default: return mtl::PixelFormat.INVALID;
	}
}

fn Format from_mtl_pixel_format(mtl::PixelFormat p)
{
	switch (p)
	{
		case mtl::PixelFormat.INVALID: return Format.UNKNOWN;
		case mtl::PixelFormat.A8UNORM: return Format.A8_UNORM;
		case mtl::PixelFormat.DEPTH32FLOAT_STENCIL8: return Format.D32_SFLOAT_S8_UINT;
		case mtl::PixelFormat.R8UNORM: return Format.R8_UNORM;
		case mtl::PixelFormat.R8SNORM: return Format.R8_SNORM;
		case mtl::PixelFormat.R8UINT: return Format.R8_UINT;
		case mtl::PixelFormat.R8SINT: return Format.R8_SINT;
		case mtl::PixelFormat.RG8UNORM: return Format.RG8_UNORM;
		case mtl::PixelFormat.RG8SNORM: return Format.RG8_SNORM;
		case mtl::PixelFormat.RG8UINT: return Format.RG8_UINT;
		case mtl::PixelFormat.RG8SINT: return Format.RG8_SINT;
		case mtl::PixelFormat.BGRA8UNORM: return Format.BGRA8_UNORM;
		case mtl::PixelFormat.BGRA8UNORM_SRGB: return Format.BGRA8_SRGB;
		case mtl::PixelFormat.RGBA8UNORM: return Format.RGBA8_UNORM;
		case mtl::PixelFormat.RGBA8SNORM: return Format.RGBA8_SNORM;
		case mtl::PixelFormat.RGBA8UINT: return Format.RGBA8_UINT;
		case mtl::PixelFormat.RGBA8SINT: return Format.RGBA8_SINT;
		case mtl::PixelFormat.RGBA8UNORM_SRGB: return Format.RGBA8_SRGB;
		case mtl::PixelFormat.R16UNORM: return Format.R16_UNORM;
		case mtl::PixelFormat.R16SNORM: return Format.R16_SNORM;
		case mtl::PixelFormat.R16UINT: return Format.R16_UINT;
		case mtl::PixelFormat.R16SINT: return Format.R16_SINT;
		case mtl::PixelFormat.R16FLOAT: return Format.R16_SFLOAT;
		case mtl::PixelFormat.RG16UNORM: return Format.RG16_UNORM;
		case mtl::PixelFormat.RG16SNORM: return Format.RG16_SNORM;
		case mtl::PixelFormat.RG16UINT: return Format.RG16_UINT;
		case mtl::PixelFormat.RG16SINT: return Format.RG16_SINT;
		case mtl::PixelFormat.RG16FLOAT: return Format.RG16_SFLOAT;
		case mtl::PixelFormat.RGBA16UNORM: return Format.RGBA16_UNORM;
		case mtl::PixelFormat.RGBA16SNORM: return Format.RGBA16_SNORM;
		case mtl::PixelFormat.RGBA16UINT: return Format.RGBA16_UINT;
		case mtl::PixelFormat.RGBA16SINT: return Format.RGBA16_SINT;
		case mtl::PixelFormat.RGBA16FLOAT: return Format.RGBA16_SFLOAT;
		case mtl::PixelFormat.R32UINT: return Format.R32_UINT;
		case mtl::PixelFormat.R32SINT: return Format.R32_SINT;
		case mtl::PixelFormat.R32FLOAT: return Format.R32_SFLOAT;
		case mtl::PixelFormat.RG32UINT: return Format.RG32_UINT;
		case mtl::PixelFormat.RG32SINT: return Format.RG32_SINT;
		case mtl::PixelFormat.RG32FLOAT: return Format.RG32_SFLOAT;
		case mtl::PixelFormat.RGBA32UINT: return Format.RGBA32_UINT;
		case mtl::PixelFormat.RGBA32SINT: return Format.RGBA32_SINT;
		case mtl::PixelFormat.RGBA32FLOAT: return Format.RGBA32_SFLOAT;
		case mtl::PixelFormat.RGB10A2UNORM: return Format.R10_G10_B10_A2_UNORM;
		case mtl::PixelFormat.RGB10A2UINT: return Format.R10_G10_B10_A2_UINT;
		case mtl::PixelFormat.RG11B10FLOAT: return Format.R11_G11_B10_UFLOAT;
		case mtl::PixelFormat.RGB9E5FLOAT: return Format.R9_G9_B9_E5_UNORM;
		case mtl::PixelFormat.B5G6R5UNORM: return Format.R5_G6_B5_UNORM;
		case mtl::PixelFormat.BGR5A1UNORM: return Format.R5_G5_B5_A1_UNORM;
		case mtl::PixelFormat.ABGR4UNORM: return Format.R4_G4_B4_A4_UNORM;
		case mtl::PixelFormat.BC1_RGBA: return Format.BC1_RGBA_UNORM;
		case mtl::PixelFormat.BC1_RGBA_SRGB: return Format.BC1_RGBA_SRGB;
		case mtl::PixelFormat.BC2_RGBA: return Format.BC2_RGBA_UNORM;
		case mtl::PixelFormat.BC2_RGBA_SRGB: return Format.BC2_RGBA_SRGB;
		case mtl::PixelFormat.BC3_RGBA: return Format.BC3_RGBA_UNORM;
		case mtl::PixelFormat.BC3_RGBA_SRGB: return Format.BC3_RGBA_SRGB;
		case mtl::PixelFormat.BC4_RUNORM: return Format.BC4_R_UNORM;
		case mtl::PixelFormat.BC4_RSNORM: return Format.BC4_R_SNORM;
		case mtl::PixelFormat.BC5_RGUNORM: return Format.BC5_RG_UNORM;
		case mtl::PixelFormat.BC5_RGSNORM: return Format.BC5_RG_SNORM;
		case mtl::PixelFormat.BC6H_RGBUFLOAT: return Format.BC6H_RGB_UFLOAT;
		case mtl::PixelFormat.BC6H_RGBFLOAT: return Format.BC6H_RGB_SFLOAT;
		case mtl::PixelFormat.BC7_RGBAUNORM: return Format.BC7_RGBA_UNORM;
		case mtl::PixelFormat.BC7_RGBAUNORM_SRGB: return Format.BC7_RGBA_SRGB;
		case mtl::PixelFormat.DEPTH16UNORM: return Format.D16_UNORM;
		case mtl::PixelFormat.DEPTH32FLOAT: return Format.D32_SFLOAT;
		case mtl::PixelFormat.DEPTH24UNORM_STENCIL8: return Format.D24_UNORM_S8_UINT;
		case mtl::PixelFormat.X24_STENCIL8: return Format.X24_R8_UINT;
		case mtl::PixelFormat.X32_STENCIL8: return Format.X32_R8_UINT_X24;
		case mtl::PixelFormat.ETC2_RGB8: return Format.ETC2_R8G8B8_UNORM;
		case mtl::PixelFormat.ETC2_RGB8_SRGB: return Format.ETC2_R8G8B8_SRGB;
		case mtl::PixelFormat.ETC2_RGB8A1: return Format.ETC2_R8G8B8A1_UNORM;
		case mtl::PixelFormat.ETC2_RGB8A1_SRGB: return Format.ETC2_R8G8B8A1_SRGB;
		case mtl::PixelFormat.EAC_RGBA8: return Format.ETC2_R8G8B8A8_UNORM;
		case mtl::PixelFormat.EAC_RGBA8_SRGB: return Format.ETC2_R8G8B8A8_SRGB;
		case mtl::PixelFormat.EAC_R11UNORM: return Format.ETC2_EAC_R11_UNORM;
		case mtl::PixelFormat.EAC_R11SNORM: return Format.ETC2_EAC_R11_SNORM;
		case mtl::PixelFormat.EAC_RG11UNORM: return Format.ETC2_EAC_R11G11_UNORM;
		case mtl::PixelFormat.EAC_RG11SNORM: return Format.ETC2_EAC_R11G11_SNORM;
		default: return Format.UNKNOWN;
	}
}

// Vertex attribute format for a `Format`, following rhi-zig's
// `rpi/pipeline_desc.zig` `to_mtl_vertex_format` (the four float formats),
// extended to every format MTLVertexFormat can express.
fn mtl::VertexFormat mtl_vertex_format(Format f)
{
	switch (f)
	{
		case R8_UNORM: return mtl::VertexFormat.UCHAR_NORMALIZED;
		case R8_SNORM: return mtl::VertexFormat.CHAR_NORMALIZED;
		case R8_UINT: return mtl::VertexFormat.UCHAR;
		case R8_SINT: return mtl::VertexFormat.CHAR;
		case RG8_UNORM: return mtl::VertexFormat.UCHAR2_NORMALIZED;
		case RG8_SNORM: return mtl::VertexFormat.CHAR2_NORMALIZED;
		case RG8_UINT: return mtl::VertexFormat.UCHAR2;
		case RG8_SINT: return mtl::VertexFormat.CHAR2;
		case BGRA8_UNORM: return mtl::VertexFormat.UCHAR4_NORMALIZED_BGRA;
		case RGB8_UNORM: return mtl::VertexFormat.UCHAR3_NORMALIZED;
		case RGBA8_UNORM: return mtl::VertexFormat.UCHAR4_NORMALIZED;
		case RGBA8_SNORM: return mtl::VertexFormat.CHAR4_NORMALIZED;
		case RGBA8_UINT: return mtl::VertexFormat.UCHAR4;
		case RGBA8_SINT: return mtl::VertexFormat.CHAR4;
		case R16_UNORM: return mtl::VertexFormat.USHORT_NORMALIZED;
		case R16_SNORM: return mtl::VertexFormat.SHORT_NORMALIZED;
		case R16_UINT: return mtl::VertexFormat.USHORT;
		case R16_SINT: return mtl::VertexFormat.SHORT;
		case R16_SFLOAT: return mtl::VertexFormat.HALF;
		case RG16_UNORM: return mtl::VertexFormat.USHORT2_NORMALIZED;
		case RG16_SNORM: return mtl::VertexFormat.SHORT2_NORMALIZED;
		case RG16_UINT: return mtl::VertexFormat.USHORT2;
		case RG16_SINT: return mtl::VertexFormat.SHORT2;
		case RG16_SFLOAT: return mtl::VertexFormat.HALF2;
		case RGBA16_UNORM: return mtl::VertexFormat.USHORT4_NORMALIZED;
		case RGBA16_SNORM: return mtl::VertexFormat.SHORT4_NORMALIZED;
		case RGBA16_UINT: return mtl::VertexFormat.USHORT4;
		case RGBA16_SINT: return mtl::VertexFormat.SHORT4;
		case RGBA16_SFLOAT: return mtl::VertexFormat.HALF4;
		case R32_UINT: return mtl::VertexFormat.UINT;
		case R32_SINT: return mtl::VertexFormat.INT;
		case R32_SFLOAT: return mtl::VertexFormat.FLOAT;
		case RG32_UINT: return mtl::VertexFormat.UINT2;
		case RG32_SINT: return mtl::VertexFormat.INT2;
		case RG32_SFLOAT: return mtl::VertexFormat.FLOAT2;
		case RGB32_UINT: return mtl::VertexFormat.UINT3;
		case RGB32_SINT: return mtl::VertexFormat.INT3;
		case RGB32_SFLOAT: return mtl::VertexFormat.FLOAT3;
		case RGBA32_UINT: return mtl::VertexFormat.UINT4;
		case RGBA32_SINT: return mtl::VertexFormat.INT4;
		case RGBA32_SFLOAT: return mtl::VertexFormat.FLOAT4;
		case R10_G10_B10_A2_UNORM: return mtl::VertexFormat.UINT1010102_NORMALIZED;
		case R11_G11_B10_UFLOAT: return mtl::VertexFormat.FLOAT_RG11B10;
		case R9_G9_B9_E5_UNORM: return mtl::VertexFormat.FLOAT_RGB9E5;
		default: return mtl::VertexFormat.INVALID;
	}
}

// Port of rhi-zig pipeline.zig `mtl_vertex_format`, for the front
// `VertexAttribute.format`.
fn mtl::VertexFormat mtl_attribute_vertex_format(VertexFormat f)
{
	switch (f)
	{
		case FLOAT: return mtl::VertexFormat.FLOAT;
		case FLOAT2: return mtl::VertexFormat.FLOAT2;
		case FLOAT3: return mtl::VertexFormat.FLOAT3;
		case FLOAT4: return mtl::VertexFormat.FLOAT4;
		case UBYTE4_NORM: return mtl::VertexFormat.UCHAR4_NORMALIZED;
	}
}

// Port of rhi-zig pipeline.zig `CompareOp.to_mtl`.
fn mtl::CompareFunction mtl_compare_function(CompareOp op)
{
	switch (op)
	{
		case NEVER: return mtl::CompareFunction.NEVER;
		case LESS: return mtl::CompareFunction.LESS;
		case EQUAL: return mtl::CompareFunction.EQUAL;
		case LESS_EQUAL: return mtl::CompareFunction.LESS_EQUAL;
		case GREATER: return mtl::CompareFunction.GREATER;
		case NOT_EQUAL: return mtl::CompareFunction.NOT_EQUAL;
		case GREATER_EQUAL: return mtl::CompareFunction.GREATER_EQUAL;
		case ALWAYS: return mtl::CompareFunction.ALWAYS;
	}
}

fn mtl::BlendFactor mtl_blend_factor(BlendFactor f)
{
	switch (f)
	{
		case ZERO: return mtl::BlendFactor.ZERO;
		case ONE: return mtl::BlendFactor.ONE;
		case SRC_COLOR: return mtl::BlendFactor.SOURCE_COLOR;
		case ONE_MINUS_SRC_COLOR: return mtl::BlendFactor.ONE_MINUS_SOURCE_COLOR;
		case DST_COLOR: return mtl::BlendFactor.DESTINATION_COLOR;
		case ONE_MINUS_DST_COLOR: return mtl::BlendFactor.ONE_MINUS_DESTINATION_COLOR;
		case SRC_ALPHA: return mtl::BlendFactor.SOURCE_ALPHA;
		case ONE_MINUS_SRC_ALPHA: return mtl::BlendFactor.ONE_MINUS_SOURCE_ALPHA;
		case DST_ALPHA: return mtl::BlendFactor.DESTINATION_ALPHA;
		case ONE_MINUS_DST_ALPHA: return mtl::BlendFactor.ONE_MINUS_DESTINATION_ALPHA;
		case CONSTANT_COLOR: return mtl::BlendFactor.BLEND_COLOR;
		case ONE_MINUS_CONSTANT_COLOR: return mtl::BlendFactor.ONE_MINUS_BLEND_COLOR;
		case CONSTANT_ALPHA: return mtl::BlendFactor.BLEND_ALPHA;
		case ONE_MINUS_CONSTANT_ALPHA: return mtl::BlendFactor.ONE_MINUS_BLEND_ALPHA;
		case SRC_ALPHA_SATURATE: return mtl::BlendFactor.SOURCE_ALPHA_SATURATED;
	}
}

fn mtl::BlendOperation mtl_blend_operation(BlendOp op)
{
	switch (op)
	{
		case ADD: return mtl::BlendOperation.ADD;
		case SUBTRACT: return mtl::BlendOperation.SUBTRACT;
		case REVERSE_SUBTRACT: return mtl::BlendOperation.REVERSE_SUBTRACT;
		case MIN: return mtl::BlendOperation.MIN;
		case MAX: return mtl::BlendOperation.MAX;
	}
}

fn mtl::ColorWriteMask mtl_color_write_mask(WriteMask mask)
{
	mtl::ColorWriteMask result = mtl::COLOR_WRITE_MASK_NONE;
	if (mask.r) result |= mtl::COLOR_WRITE_MASK_RED;
	if (mask.g) result |= mtl::COLOR_WRITE_MASK_GREEN;
	if (mask.b) result |= mtl::COLOR_WRITE_MASK_BLUE;
	if (mask.a) result |= mtl::COLOR_WRITE_MASK_ALPHA;
	return result;
}

fn mtl::SamplerMinMagFilter mtl_sampler_min_mag_filter(SamplerFilter f)
{
	switch (f)
	{
		case NEAREST: return mtl::SamplerMinMagFilter.NEAREST;
		case LINEAR: return mtl::SamplerMinMagFilter.LINEAR;
	}
}

fn mtl::SamplerMipFilter mtl_sampler_mip_filter(SamplerMipmap m)
{
	switch (m)
	{
		case NEAREST: return mtl::SamplerMipFilter.NEAREST;
		case LINEAR: return mtl::SamplerMipFilter.LINEAR;
	}
}

// `SamplerDesc` has no border color, so CLAMP_TO_BORDER samples Metal's
// default (MTLSamplerBorderColorTransparentBlack).
fn mtl::SamplerAddressMode mtl_sampler_address_mode(SamplerAddress a)
{
	switch (a)
	{
		case MIRROR: return mtl::SamplerAddressMode.MIRROR_REPEAT;
		case REPEAT: return mtl::SamplerAddressMode.REPEAT;
		case CLAMP_TO_EDGE: return mtl::SamplerAddressMode.CLAMP_TO_EDGE;
		case CLAMP_TO_BORDER: return mtl::SamplerAddressMode.CLAMP_TO_BORDER_COLOR;
	}
}

fn mtl::CompareFunction mtl_sampler_compare_function(SamplerCompare c)
{
	switch (c)
	{
		case NEVER: return mtl::CompareFunction.NEVER;
		case LESS: return mtl::CompareFunction.LESS;
		case EQUAL: return mtl::CompareFunction.EQUAL;
		case LESS_EQUAL: return mtl::CompareFunction.LESS_EQUAL;
		case GREATER: return mtl::CompareFunction.GREATER;
		case NOT_EQUAL: return mtl::CompareFunction.NOT_EQUAL;
		case GREATER_EQUAL: return mtl::CompareFunction.GREATER_EQUAL;
		case ALWAYS: return mtl::CompareFunction.ALWAYS;
	}
}

// Port of rhi-zig rpi/pipeline_desc.zig `Topology.to_mtl`.
fn mtl::PrimitiveType mtl_primitive_type(PrimitiveTopology t)
{
	switch (t)
	{
		case TRIANGLE_LIST: return mtl::PrimitiveType.TRIANGLE;
		case TRIANGLE_STRIP: return mtl::PrimitiveType.TRIANGLE_STRIP;
		case LINE_LIST: return mtl::PrimitiveType.LINE;
		case LINE_STRIP: return mtl::PrimitiveType.LINE_STRIP;
		case POINT_LIST: return mtl::PrimitiveType.POINT;
	}
}

fn mtl::CullMode mtl_cull_mode(CullMode c)
{
	switch (c)
	{
		case NONE: return mtl::CullMode.NONE;
		case FRONT: return mtl::CullMode.FRONT;
		case BACK: return mtl::CullMode.BACK;
	}
}

fn mtl::Winding mtl_winding(FrontFace f)
{
	switch (f)
	{
		case CLOCKWISE: return mtl::Winding.CLOCKWISE;
		case COUNTER_CLOCKWISE: return mtl::Winding.COUNTER_CLOCKWISE;
	}
}

// ---- dx12 ----

// Direct3D 12 format mapping: rhi `Format` to DXGI_FORMAT, plus the typeless,
// shader-resource-view and depth-stencil-view variants a depth texture needs.
// Follows ATDD-Redux's `ri_d3d12_*ToD3D12` tables. Pure translation, no
// device access.
//
// Formats without a DXGI equivalent resolve to `UNKNOWN`: luminance formats,
// 24-bit RGB/BGR, D16_UNORM_S8_UINT, R4_G4_B4_A4_UNORM (DXGI's B4G4R4A4 is
// not in the vendor enum) and ETC1/ETC2/EAC.
//
// Depth/stencil queries go through `format_get_props(f).is_depth` /
// `.is_stencil`.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import dxgi;

fn dxgi::Format format_to_dxgi(Format f)
{
	switch (f)
	{
		case A8_UNORM: return dxgi::Format.A8_UNORM;
		case D24_UNORM_S8_UINT: return dxgi::Format.D24_UNORM_S8_UINT;
		case D32_SFLOAT_S8_UINT: return dxgi::Format.D32_FLOAT_S8X24_UINT;
		case R8_UNORM: return dxgi::Format.R8_UNORM;
		case R8_SNORM: return dxgi::Format.R8_SNORM;
		case R8_UINT: return dxgi::Format.R8_UINT;
		case R8_SINT: return dxgi::Format.R8_SINT;
		case RG8_UNORM: return dxgi::Format.R8G8_UNORM;
		case RG8_SNORM: return dxgi::Format.R8G8_SNORM;
		case RG8_UINT: return dxgi::Format.R8G8_UINT;
		case RG8_SINT: return dxgi::Format.R8G8_SINT;
		case BGRA8_UNORM: return dxgi::Format.B8G8R8A8_UNORM;
		case BGRA8_SRGB: return dxgi::Format.B8G8R8A8_UNORM_SRGB;
		case RGBA8_UNORM: return dxgi::Format.R8G8B8A8_UNORM;
		case RGBA8_SNORM: return dxgi::Format.R8G8B8A8_SNORM;
		case RGBA8_UINT: return dxgi::Format.R8G8B8A8_UINT;
		case RGBA8_SINT: return dxgi::Format.R8G8B8A8_SINT;
		case RGBA8_SRGB: return dxgi::Format.R8G8B8A8_UNORM_SRGB;
		case R16_UNORM: return dxgi::Format.R16_UNORM;
		case R16_SNORM: return dxgi::Format.R16_SNORM;
		case R16_UINT: return dxgi::Format.R16_UINT;
		case R16_SINT: return dxgi::Format.R16_SINT;
		case R16_SFLOAT: return dxgi::Format.R16_FLOAT;
		case RG16_UNORM: return dxgi::Format.R16G16_UNORM;
		case RG16_SNORM: return dxgi::Format.R16G16_SNORM;
		case RG16_UINT: return dxgi::Format.R16G16_UINT;
		case RG16_SINT: return dxgi::Format.R16G16_SINT;
		case RG16_SFLOAT: return dxgi::Format.R16G16_FLOAT;
		case RGBA16_UNORM: return dxgi::Format.R16G16B16A16_UNORM;
		case RGBA16_SNORM: return dxgi::Format.R16G16B16A16_SNORM;
		case RGBA16_UINT: return dxgi::Format.R16G16B16A16_UINT;
		case RGBA16_SINT: return dxgi::Format.R16G16B16A16_SINT;
		case RGBA16_SFLOAT: return dxgi::Format.R16G16B16A16_FLOAT;
		case R32_UINT: return dxgi::Format.R32_UINT;
		case R32_SINT: return dxgi::Format.R32_SINT;
		case R32_SFLOAT: return dxgi::Format.R32_FLOAT;
		case RG32_UINT: return dxgi::Format.R32G32_UINT;
		case RG32_SINT: return dxgi::Format.R32G32_SINT;
		case RG32_SFLOAT: return dxgi::Format.R32G32_FLOAT;
		case RGB32_UINT: return dxgi::Format.R32G32B32_UINT;
		case RGB32_SINT: return dxgi::Format.R32G32B32_SINT;
		case RGB32_SFLOAT: return dxgi::Format.R32G32B32_FLOAT;
		case RGBA32_UINT: return dxgi::Format.R32G32B32A32_UINT;
		case RGBA32_SINT: return dxgi::Format.R32G32B32A32_SINT;
		case RGBA32_SFLOAT: return dxgi::Format.R32G32B32A32_FLOAT;
		case R10_G10_B10_A2_UNORM: return dxgi::Format.R10G10B10A2_UNORM;
		case R10_G10_B10_A2_UINT: return dxgi::Format.R10G10B10A2_UINT;
		case R11_G11_B10_UFLOAT: return dxgi::Format.R11G11B10_FLOAT;
		case R9_G9_B9_E5_UNORM: return dxgi::Format.R9G9B9E5_SHAREDEXP;
		case R5_G6_B5_UNORM: return dxgi::Format.B5G6R5_UNORM;
		case R5_G5_B5_A1_UNORM: return dxgi::Format.B5G5R5A1_UNORM;
		case BC1_RGBA_UNORM: return dxgi::Format.BC1_UNORM;
		case BC1_RGBA_SRGB: return dxgi::Format.BC1_UNORM_SRGB;
		case BC2_RGBA_UNORM: return dxgi::Format.BC2_UNORM;
		case BC2_RGBA_SRGB: return dxgi::Format.BC2_UNORM_SRGB;
		case BC3_RGBA_UNORM: return dxgi::Format.BC3_UNORM;
		case BC3_RGBA_SRGB: return dxgi::Format.BC3_UNORM_SRGB;
		case BC4_R_UNORM: return dxgi::Format.BC4_UNORM;
		case BC4_R_SNORM: return dxgi::Format.BC4_SNORM;
		case BC5_RG_UNORM: return dxgi::Format.BC5_UNORM;
		case BC5_RG_SNORM: return dxgi::Format.BC5_SNORM;
		case BC6H_RGB_UFLOAT: return dxgi::Format.BC6H_UF16;
		case BC6H_RGB_SFLOAT: return dxgi::Format.BC6H_SF16;
		case BC7_RGBA_UNORM: return dxgi::Format.BC7_UNORM;
		case BC7_RGBA_SRGB: return dxgi::Format.BC7_UNORM_SRGB;
		case D16_UNORM: return dxgi::Format.D16_UNORM;
		case D32_SFLOAT: return dxgi::Format.D32_FLOAT;
		case D32_SFLOAT_S8_UINT_X24: return dxgi::Format.D32_FLOAT_S8X24_UINT;
		case R24_UNORM_X8: return dxgi::Format.R24_UNORM_X8_TYPELESS;
		case X24_R8_UINT: return dxgi::Format.X24_TYPELESS_G8_UINT;
		case X32_R8_UINT_X24: return dxgi::Format.X32_TYPELESS_G8X24_UINT;
		case R32_SFLOAT_X8_X24: return dxgi::Format.R32_FLOAT_X8X24_TYPELESS;
		default: return dxgi::Format.UNKNOWN;
	}
}

// Typeless family of a format, for resources that are viewed as more than one
// type (depth textures sampled as color, sRGB render targets viewed as UNORM).
// Formats with no typeless sibling map to their plain DXGI format.
fn dxgi::Format format_to_dxgi_typeless(Format f)
{
	switch (f)
	{
		case D16_UNORM: return dxgi::Format.R16_TYPELESS;
		case D32_SFLOAT: return dxgi::Format.R32_TYPELESS;
		case D24_UNORM_S8_UINT: return dxgi::Format.R24G8_TYPELESS;
		case D32_SFLOAT_S8_UINT:
		case D32_SFLOAT_S8_UINT_X24: return dxgi::Format.R32G8X24_TYPELESS;
		case R8_UNORM:
		case R8_SNORM:
		case R8_UINT:
		case R8_SINT: return dxgi::Format.R8_TYPELESS;
		case RG8_UNORM:
		case RG8_SNORM:
		case RG8_UINT:
		case RG8_SINT: return dxgi::Format.R8G8_TYPELESS;
		case BGRA8_UNORM:
		case BGRA8_SRGB: return dxgi::Format.B8G8R8A8_TYPELESS;
		case RGBA8_UNORM:
		case RGBA8_SNORM:
		case RGBA8_UINT:
		case RGBA8_SINT:
		case RGBA8_SRGB: return dxgi::Format.R8G8B8A8_TYPELESS;
		case R16_UNORM:
		case R16_SNORM:
		case R16_UINT:
		case R16_SINT:
		case R16_SFLOAT: return dxgi::Format.R16_TYPELESS;
		case RG16_UNORM:
		case RG16_SNORM:
		case RG16_UINT:
		case RG16_SINT:
		case RG16_SFLOAT: return dxgi::Format.R16G16_TYPELESS;
		case RGBA16_UNORM:
		case RGBA16_SNORM:
		case RGBA16_UINT:
		case RGBA16_SINT:
		case RGBA16_SFLOAT: return dxgi::Format.R16G16B16A16_TYPELESS;
		case R32_UINT:
		case R32_SINT:
		case R32_SFLOAT: return dxgi::Format.R32_TYPELESS;
		case RG32_UINT:
		case RG32_SINT:
		case RG32_SFLOAT: return dxgi::Format.R32G32_TYPELESS;
		case RGB32_UINT:
		case RGB32_SINT:
		case RGB32_SFLOAT: return dxgi::Format.R32G32B32_TYPELESS;
		case RGBA32_UINT:
		case RGBA32_SINT:
		case RGBA32_SFLOAT: return dxgi::Format.R32G32B32A32_TYPELESS;
		case R10_G10_B10_A2_UNORM:
		case R10_G10_B10_A2_UINT: return dxgi::Format.R10G10B10A2_TYPELESS;
		case BC1_RGBA_UNORM:
		case BC1_RGBA_SRGB: return dxgi::Format.BC1_TYPELESS;
		case BC2_RGBA_UNORM:
		case BC2_RGBA_SRGB: return dxgi::Format.BC2_TYPELESS;
		case BC3_RGBA_UNORM:
		case BC3_RGBA_SRGB: return dxgi::Format.BC3_TYPELESS;
		case BC4_R_UNORM:
		case BC4_R_SNORM: return dxgi::Format.BC4_TYPELESS;
		case BC5_RG_UNORM:
		case BC5_RG_SNORM: return dxgi::Format.BC5_TYPELESS;
		case BC6H_RGB_UFLOAT:
		case BC6H_RGB_SFLOAT: return dxgi::Format.BC6H_TYPELESS;
		case BC7_RGBA_UNORM:
		case BC7_RGBA_SRGB: return dxgi::Format.BC7_TYPELESS;
		default: return format_to_dxgi(f);
	}
}

// Shader-resource-view format: depth formats read as their color
// counterpart, everything else is the plain DXGI format.
fn dxgi::Format format_to_dxgi_srv(Format f)
{
	switch (f)
	{
		case D16_UNORM: return dxgi::Format.R16_UNORM;
		case D32_SFLOAT: return dxgi::Format.R32_FLOAT;
		case D24_UNORM_S8_UINT: return dxgi::Format.R24_UNORM_X8_TYPELESS;
		case D32_SFLOAT_S8_UINT:
		case D32_SFLOAT_S8_UINT_X24: return dxgi::Format.R32_FLOAT_X8X24_TYPELESS;
		default: return format_to_dxgi(f);
	}
}

// Depth-stencil-view format; `UNKNOWN` for non-depth formats.
fn dxgi::Format format_to_dxgi_dsv(Format f)
{
	if (!format_get_props(f).is_depth) return dxgi::Format.UNKNOWN;
	return format_to_dxgi(f);
}

// ---- vulkan ----

module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

fn vk::Format to_vk_format(Format format)
{
	switch (format)
	{
		case Format.UNKNOWN: return vk::Format.FORMAT_UNDEFINED;
		case Format.D16_UNORM_S8_UINT: return vk::Format.FORMAT_D16_UNORM_S8_UINT;
		case Format.D24_UNORM_S8_UINT: return vk::Format.FORMAT_D24_UNORM_S8_UINT;
		case Format.D32_SFLOAT_S8_UINT: return vk::Format.FORMAT_D32_SFLOAT_S8_UINT;
		case Format.R8_UNORM: return vk::Format.FORMAT_R8_UNORM;
		case Format.R8_SNORM: return vk::Format.FORMAT_R8_SNORM;
		case Format.R8_UINT: return vk::Format.FORMAT_R8_UINT;
		case Format.R8_SINT: return vk::Format.FORMAT_R8_SINT;
		case Format.RG8_UNORM: return vk::Format.FORMAT_R8G8_UNORM;
		case Format.RG8_SNORM: return vk::Format.FORMAT_R8G8_SNORM;
		case Format.RG8_UINT: return vk::Format.FORMAT_R8G8_UINT;
		case Format.RG8_SINT: return vk::Format.FORMAT_R8G8_SINT;
		case Format.BGRA8_UNORM: return vk::Format.FORMAT_B8G8R8A8_UNORM;
		case Format.BGRA8_SRGB: return vk::Format.FORMAT_B8G8R8A8_SRGB;
		case Format.BGR8_UNORM: return vk::Format.FORMAT_B8G8R8_UNORM;
		case Format.RGB8_UNORM: return vk::Format.FORMAT_R8G8B8_UNORM;
		case Format.RGBA8_UNORM: return vk::Format.FORMAT_R8G8B8A8_UNORM;
		case Format.RGBA8_SNORM: return vk::Format.FORMAT_R8G8B8A8_SNORM;
		case Format.RGBA8_UINT: return vk::Format.FORMAT_R8G8B8A8_UINT;
		case Format.RGBA8_SINT: return vk::Format.FORMAT_R8G8B8A8_SINT;
		case Format.RGBA8_SRGB: return vk::Format.FORMAT_R8G8B8A8_SRGB;
		case Format.R16_UNORM: return vk::Format.FORMAT_R16_UNORM;
		case Format.R16_SNORM: return vk::Format.FORMAT_R16_SNORM;
		case Format.R16_UINT: return vk::Format.FORMAT_R16_UINT;
		case Format.R16_SINT: return vk::Format.FORMAT_R16_SINT;
		case Format.R16_SFLOAT: return vk::Format.FORMAT_R16_SFLOAT;
		case Format.RG16_UNORM: return vk::Format.FORMAT_R16G16_UNORM;
		case Format.RG16_SNORM: return vk::Format.FORMAT_R16G16_SNORM;
		case Format.RG16_UINT: return vk::Format.FORMAT_R16G16_UINT;
		case Format.RG16_SINT: return vk::Format.FORMAT_R16G16_SINT;
		case Format.RG16_SFLOAT: return vk::Format.FORMAT_R16G16_SFLOAT;
		case Format.RGBA16_UNORM: return vk::Format.FORMAT_R16G16B16A16_UNORM;
		case Format.RGBA16_SNORM: return vk::Format.FORMAT_R16G16B16A16_SNORM;
		case Format.RGBA16_UINT: return vk::Format.FORMAT_R16G16B16A16_UINT;
		case Format.RGBA16_SINT: return vk::Format.FORMAT_R16G16B16A16_SINT;
		case Format.RGBA16_SFLOAT: return vk::Format.FORMAT_R16G16B16A16_SFLOAT;
		case Format.R32_UINT: return vk::Format.FORMAT_R32_UINT;
		case Format.R32_SINT: return vk::Format.FORMAT_R32_SINT;
		case Format.R32_SFLOAT: return vk::Format.FORMAT_R32_SFLOAT;
		case Format.RG32_UINT: return vk::Format.FORMAT_R32G32_UINT;
		case Format.RG32_SINT: return vk::Format.FORMAT_R32G32_SINT;
		case Format.RG32_SFLOAT: return vk::Format.FORMAT_R32G32_SFLOAT;
		case Format.RGB32_UINT: return vk::Format.FORMAT_R32G32B32_UINT;
		case Format.RGB32_SINT: return vk::Format.FORMAT_R32G32B32_SINT;
		case Format.RGB32_SFLOAT: return vk::Format.FORMAT_R32G32B32_SFLOAT;
		case Format.RGBA32_UINT: return vk::Format.FORMAT_R32G32B32A32_UINT;
		case Format.RGBA32_SINT: return vk::Format.FORMAT_R32G32B32A32_SINT;
		case Format.RGBA32_SFLOAT: return vk::Format.FORMAT_R32G32B32A32_SFLOAT;
		case Format.R10_G10_B10_A2_UNORM: return vk::Format.FORMAT_A2B10G10R10_UNORM_PACK32;
		case Format.R10_G10_B10_A2_UINT: return vk::Format.FORMAT_A2B10G10R10_UINT_PACK32;
		case Format.R11_G11_B10_UFLOAT: return vk::Format.FORMAT_B10G11R11_UFLOAT_PACK32;
		case Format.R9_G9_B9_E5_UNORM: return vk::Format.FORMAT_E5B9G9R9_UFLOAT_PACK32;
		case Format.R5_G6_B5_UNORM: return vk::Format.FORMAT_R5G6B5_UNORM_PACK16;
		case Format.R5_G5_B5_A1_UNORM: return vk::Format.FORMAT_A1R5G5B5_UNORM_PACK16;
		case Format.R4_G4_B4_A4_UNORM: return vk::Format.FORMAT_A4R4G4B4_UNORM_PACK16;
		case Format.BC1_RGBA_UNORM: return vk::Format.FORMAT_BC1_RGBA_UNORM_BLOCK;
		case Format.BC1_RGBA_SRGB: return vk::Format.FORMAT_BC1_RGBA_SRGB_BLOCK;
		case Format.BC2_RGBA_UNORM: return vk::Format.FORMAT_BC2_UNORM_BLOCK;
		case Format.BC2_RGBA_SRGB: return vk::Format.FORMAT_BC2_SRGB_BLOCK;
		case Format.BC3_RGBA_UNORM: return vk::Format.FORMAT_BC3_UNORM_BLOCK;
		case Format.BC3_RGBA_SRGB: return vk::Format.FORMAT_BC3_SRGB_BLOCK;
		case Format.BC4_R_UNORM: return vk::Format.FORMAT_BC4_UNORM_BLOCK;
		case Format.BC4_R_SNORM: return vk::Format.FORMAT_BC4_SNORM_BLOCK;
		case Format.BC5_RG_UNORM: return vk::Format.FORMAT_BC5_UNORM_BLOCK;
		case Format.BC5_RG_SNORM: return vk::Format.FORMAT_BC5_SNORM_BLOCK;
		case Format.BC6H_RGB_UFLOAT: return vk::Format.FORMAT_BC6H_UFLOAT_BLOCK;
		case Format.BC6H_RGB_SFLOAT: return vk::Format.FORMAT_BC6H_SFLOAT_BLOCK;
		case Format.BC7_RGBA_UNORM: return vk::Format.FORMAT_BC7_UNORM_BLOCK;
		case Format.BC7_RGBA_SRGB: return vk::Format.FORMAT_BC7_SRGB_BLOCK;
		case Format.D16_UNORM: return vk::Format.FORMAT_D16_UNORM;
		case Format.D32_SFLOAT: return vk::Format.FORMAT_D32_SFLOAT;
		case Format.D32_SFLOAT_S8_UINT_X24: return vk::Format.FORMAT_D32_SFLOAT_S8_UINT;
		case Format.R24_UNORM_X8: return vk::Format.FORMAT_D24_UNORM_S8_UINT;
		case Format.X24_R8_UINT: return vk::Format.FORMAT_D24_UNORM_S8_UINT;
		case Format.X32_R8_UINT_X24: return vk::Format.FORMAT_D32_SFLOAT_S8_UINT;
		case Format.R32_SFLOAT_X8_X24: return vk::Format.FORMAT_D32_SFLOAT_S8_UINT;
		case Format.ETC2_R8G8B8_UNORM: return vk::Format.FORMAT_ETC2_R8G8B8_UNORM_BLOCK;
		case Format.ETC1_R8G8B8_OES: return vk::Format.FORMAT_ETC2_R8G8B8_UNORM_BLOCK;
		case Format.ETC2_R8G8B8_SRGB: return vk::Format.FORMAT_ETC2_R8G8B8_SRGB_BLOCK;
		case Format.ETC2_R8G8B8A1_UNORM: return vk::Format.FORMAT_ETC2_R8G8B8A1_UNORM_BLOCK;
		case Format.ETC2_R8G8B8A1_SRGB: return vk::Format.FORMAT_ETC2_R8G8B8A1_SRGB_BLOCK;
		case Format.ETC2_R8G8B8A8_UNORM: return vk::Format.FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK;
		case Format.ETC2_R8G8B8A8_SRGB: return vk::Format.FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK;
		case Format.ETC2_EAC_R11_UNORM: return vk::Format.FORMAT_EAC_R11_UNORM_BLOCK;
		case Format.ETC2_EAC_R11_SNORM: return vk::Format.FORMAT_EAC_R11_SNORM_BLOCK;
		case Format.ETC2_EAC_R11G11_UNORM: return vk::Format.FORMAT_EAC_R11G11_UNORM_BLOCK;
		case Format.ETC2_EAC_R11G11_SNORM: return vk::Format.FORMAT_EAC_R11G11_SNORM_BLOCK;
		default: return vk::Format.FORMAT_UNDEFINED;
	}
}

fn Format from_vk_format(vk::Format format)
{
	switch (format)
	{
		case vk::Format.FORMAT_UNDEFINED: return Format.UNKNOWN;
		case vk::Format.FORMAT_D16_UNORM_S8_UINT: return Format.D16_UNORM_S8_UINT;
		case vk::Format.FORMAT_D24_UNORM_S8_UINT: return Format.D24_UNORM_S8_UINT;
		case vk::Format.FORMAT_D32_SFLOAT_S8_UINT: return Format.D32_SFLOAT_S8_UINT;
		case vk::Format.FORMAT_R8_UNORM: return Format.R8_UNORM;
		case vk::Format.FORMAT_R8_SNORM: return Format.R8_SNORM;
		case vk::Format.FORMAT_R8_UINT: return Format.R8_UINT;
		case vk::Format.FORMAT_R8_SINT: return Format.R8_SINT;
		case vk::Format.FORMAT_R8G8_UNORM: return Format.RG8_UNORM;
		case vk::Format.FORMAT_R8G8_SNORM: return Format.RG8_SNORM;
		case vk::Format.FORMAT_R8G8_UINT: return Format.RG8_UINT;
		case vk::Format.FORMAT_R8G8_SINT: return Format.RG8_SINT;
		case vk::Format.FORMAT_B8G8R8A8_UNORM: return Format.BGRA8_UNORM;
		case vk::Format.FORMAT_B8G8R8A8_SRGB: return Format.BGRA8_SRGB;
		case vk::Format.FORMAT_B8G8R8_UNORM: return Format.BGR8_UNORM;
		case vk::Format.FORMAT_R8G8B8_UNORM: return Format.RGB8_UNORM;
		case vk::Format.FORMAT_R8G8B8A8_UNORM: return Format.RGBA8_UNORM;
		case vk::Format.FORMAT_R8G8B8A8_SNORM: return Format.RGBA8_SNORM;
		case vk::Format.FORMAT_R8G8B8A8_UINT: return Format.RGBA8_UINT;
		case vk::Format.FORMAT_R8G8B8A8_SINT: return Format.RGBA8_SINT;
		case vk::Format.FORMAT_R8G8B8A8_SRGB: return Format.RGBA8_SRGB;
		case vk::Format.FORMAT_R16_UNORM: return Format.R16_UNORM;
		case vk::Format.FORMAT_R16_SNORM: return Format.R16_SNORM;
		case vk::Format.FORMAT_R16_UINT: return Format.R16_UINT;
		case vk::Format.FORMAT_R16_SINT: return Format.R16_SINT;
		case vk::Format.FORMAT_R16_SFLOAT: return Format.R16_SFLOAT;
		case vk::Format.FORMAT_R16G16_UNORM: return Format.RG16_UNORM;
		case vk::Format.FORMAT_R16G16_SNORM: return Format.RG16_SNORM;
		case vk::Format.FORMAT_R16G16_UINT: return Format.RG16_UINT;
		case vk::Format.FORMAT_R16G16_SINT: return Format.RG16_SINT;
		case vk::Format.FORMAT_R16G16_SFLOAT: return Format.RG16_SFLOAT;
		case vk::Format.FORMAT_R16G16B16A16_UNORM: return Format.RGBA16_UNORM;
		case vk::Format.FORMAT_R16G16B16A16_SNORM: return Format.RGBA16_SNORM;
		case vk::Format.FORMAT_R16G16B16A16_UINT: return Format.RGBA16_UINT;
		case vk::Format.FORMAT_R16G16B16A16_SINT: return Format.RGBA16_SINT;
		case vk::Format.FORMAT_R16G16B16A16_SFLOAT: return Format.RGBA16_SFLOAT;
		case vk::Format.FORMAT_R32_UINT: return Format.R32_UINT;
		case vk::Format.FORMAT_R32_SINT: return Format.R32_SINT;
		case vk::Format.FORMAT_R32_SFLOAT: return Format.R32_SFLOAT;
		case vk::Format.FORMAT_R32G32_UINT: return Format.RG32_UINT;
		case vk::Format.FORMAT_R32G32_SINT: return Format.RG32_SINT;
		case vk::Format.FORMAT_R32G32_SFLOAT: return Format.RG32_SFLOAT;
		case vk::Format.FORMAT_R32G32B32_UINT: return Format.RGB32_UINT;
		case vk::Format.FORMAT_R32G32B32_SINT: return Format.RGB32_SINT;
		case vk::Format.FORMAT_R32G32B32_SFLOAT: return Format.RGB32_SFLOAT;
		case vk::Format.FORMAT_R32G32B32A32_UINT: return Format.RGBA32_UINT;
		case vk::Format.FORMAT_R32G32B32A32_SINT: return Format.RGBA32_SINT;
		case vk::Format.FORMAT_R32G32B32A32_SFLOAT: return Format.RGBA32_SFLOAT;
		case vk::Format.FORMAT_A2B10G10R10_UNORM_PACK32: return Format.R10_G10_B10_A2_UNORM;
		case vk::Format.FORMAT_A2B10G10R10_UINT_PACK32: return Format.R10_G10_B10_A2_UINT;
		case vk::Format.FORMAT_B10G11R11_UFLOAT_PACK32: return Format.R11_G11_B10_UFLOAT;
		case vk::Format.FORMAT_E5B9G9R9_UFLOAT_PACK32: return Format.R9_G9_B9_E5_UNORM;
		case vk::Format.FORMAT_R5G6B5_UNORM_PACK16: return Format.R5_G6_B5_UNORM;
		case vk::Format.FORMAT_A1R5G5B5_UNORM_PACK16: return Format.R5_G5_B5_A1_UNORM;
		case vk::Format.FORMAT_A4R4G4B4_UNORM_PACK16: return Format.R4_G4_B4_A4_UNORM;
		case vk::Format.FORMAT_BC1_RGBA_UNORM_BLOCK: return Format.BC1_RGBA_UNORM;
		case vk::Format.FORMAT_BC1_RGBA_SRGB_BLOCK: return Format.BC1_RGBA_SRGB;
		case vk::Format.FORMAT_BC2_UNORM_BLOCK: return Format.BC2_RGBA_UNORM;
		case vk::Format.FORMAT_BC2_SRGB_BLOCK: return Format.BC2_RGBA_SRGB;
		case vk::Format.FORMAT_BC3_UNORM_BLOCK: return Format.BC3_RGBA_UNORM;
		case vk::Format.FORMAT_BC3_SRGB_BLOCK: return Format.BC3_RGBA_SRGB;
		case vk::Format.FORMAT_BC4_UNORM_BLOCK: return Format.BC4_R_UNORM;
		case vk::Format.FORMAT_BC4_SNORM_BLOCK: return Format.BC4_R_SNORM;
		case vk::Format.FORMAT_BC5_UNORM_BLOCK: return Format.BC5_RG_UNORM;
		case vk::Format.FORMAT_BC5_SNORM_BLOCK: return Format.BC5_RG_SNORM;
		case vk::Format.FORMAT_BC6H_UFLOAT_BLOCK: return Format.BC6H_RGB_UFLOAT;
		case vk::Format.FORMAT_BC6H_SFLOAT_BLOCK: return Format.BC6H_RGB_SFLOAT;
		case vk::Format.FORMAT_BC7_UNORM_BLOCK: return Format.BC7_RGBA_UNORM;
		case vk::Format.FORMAT_BC7_SRGB_BLOCK: return Format.BC7_RGBA_SRGB;
		case vk::Format.FORMAT_D16_UNORM: return Format.D16_UNORM;
		case vk::Format.FORMAT_D32_SFLOAT: return Format.D32_SFLOAT;
		case vk::Format.FORMAT_ETC2_R8G8B8_UNORM_BLOCK: return Format.ETC2_R8G8B8_UNORM;
		case vk::Format.FORMAT_ETC2_R8G8B8_SRGB_BLOCK: return Format.ETC2_R8G8B8_SRGB;
		case vk::Format.FORMAT_ETC2_R8G8B8A1_UNORM_BLOCK: return Format.ETC2_R8G8B8A1_UNORM;
		case vk::Format.FORMAT_ETC2_R8G8B8A1_SRGB_BLOCK: return Format.ETC2_R8G8B8A1_SRGB;
		case vk::Format.FORMAT_ETC2_R8G8B8A8_UNORM_BLOCK: return Format.ETC2_R8G8B8A8_UNORM;
		case vk::Format.FORMAT_ETC2_R8G8B8A8_SRGB_BLOCK: return Format.ETC2_R8G8B8A8_SRGB;
		case vk::Format.FORMAT_EAC_R11_UNORM_BLOCK: return Format.ETC2_EAC_R11_UNORM;
		case vk::Format.FORMAT_EAC_R11_SNORM_BLOCK: return Format.ETC2_EAC_R11_SNORM;
		case vk::Format.FORMAT_EAC_R11G11_UNORM_BLOCK: return Format.ETC2_EAC_R11G11_UNORM;
		case vk::Format.FORMAT_EAC_R11G11_SNORM_BLOCK: return Format.ETC2_EAC_R11G11_SNORM;
		default: return Format.UNKNOWN;
	}
}

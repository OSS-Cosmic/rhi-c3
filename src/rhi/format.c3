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

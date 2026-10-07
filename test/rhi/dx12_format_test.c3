// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import std::core::test;
import dxgi;

fn void dx12_format_color_mappings() @test
{
	test::eq(format_to_dxgi(Format.UNKNOWN), dxgi::Format.UNKNOWN);
	test::eq(format_to_dxgi(Format.RGBA8_UNORM), dxgi::Format.R8G8B8A8_UNORM);
	test::eq(format_to_dxgi(Format.RGBA8_SRGB), dxgi::Format.R8G8B8A8_UNORM_SRGB);
	test::eq(format_to_dxgi(Format.BGRA8_UNORM), dxgi::Format.B8G8R8A8_UNORM);
	test::eq(format_to_dxgi(Format.BGRA8_SRGB), dxgi::Format.B8G8R8A8_UNORM_SRGB);
	test::eq(format_to_dxgi(Format.RGBA16_SFLOAT), dxgi::Format.R16G16B16A16_FLOAT);
	test::eq(format_to_dxgi(Format.RGB32_SFLOAT), dxgi::Format.R32G32B32_FLOAT);
	test::eq(format_to_dxgi(Format.R11_G11_B10_UFLOAT), dxgi::Format.R11G11B10_FLOAT);
	test::eq(format_to_dxgi(Format.BC7_RGBA_SRGB), dxgi::Format.BC7_UNORM_SRGB);
	test::eq(format_to_dxgi(Format.BC6H_RGB_UFLOAT), dxgi::Format.BC6H_UF16);
}

fn void dx12_format_unmapped_is_unknown() @test
{
	test::eq(format_to_dxgi(Format.L8_UNORM), dxgi::Format.UNKNOWN);
	test::eq(format_to_dxgi(Format.RGB8_UNORM), dxgi::Format.UNKNOWN);
	test::eq(format_to_dxgi(Format.D16_UNORM_S8_UINT), dxgi::Format.UNKNOWN);
	test::eq(format_to_dxgi(Format.ETC2_R8G8B8_UNORM), dxgi::Format.UNKNOWN);
}

fn void dx12_format_depth_views() @test
{
	test::eq(format_to_dxgi(Format.D32_SFLOAT), dxgi::Format.D32_FLOAT);
	test::eq(format_to_dxgi_typeless(Format.D32_SFLOAT), dxgi::Format.R32_TYPELESS);
	test::eq(format_to_dxgi_srv(Format.D32_SFLOAT), dxgi::Format.R32_FLOAT);
	test::eq(format_to_dxgi_dsv(Format.D32_SFLOAT), dxgi::Format.D32_FLOAT);

	test::eq(format_to_dxgi_typeless(Format.D16_UNORM), dxgi::Format.R16_TYPELESS);
	test::eq(format_to_dxgi_srv(Format.D16_UNORM), dxgi::Format.R16_UNORM);

	test::eq(format_to_dxgi_typeless(Format.D24_UNORM_S8_UINT), dxgi::Format.R24G8_TYPELESS);
	test::eq(format_to_dxgi_srv(Format.D24_UNORM_S8_UINT), dxgi::Format.R24_UNORM_X8_TYPELESS);
	test::eq(format_to_dxgi_dsv(Format.D24_UNORM_S8_UINT), dxgi::Format.D24_UNORM_S8_UINT);

	test::eq(format_to_dxgi_typeless(Format.D32_SFLOAT_S8_UINT), dxgi::Format.R32G8X24_TYPELESS);
	test::eq(format_to_dxgi_srv(Format.D32_SFLOAT_S8_UINT), dxgi::Format.R32_FLOAT_X8X24_TYPELESS);
	test::eq(format_to_dxgi_dsv(Format.D32_SFLOAT_S8_UINT), dxgi::Format.D32_FLOAT_S8X24_UINT);
}

fn void dx12_format_typeless_and_passthrough() @test
{
	test::eq(format_to_dxgi_typeless(Format.RGBA8_SRGB), dxgi::Format.R8G8B8A8_TYPELESS);
	test::eq(format_to_dxgi_typeless(Format.RGBA8_UNORM), dxgi::Format.R8G8B8A8_TYPELESS);
	test::eq(format_to_dxgi_typeless(Format.BC3_RGBA_SRGB), dxgi::Format.BC3_TYPELESS);
	// No typeless sibling: falls back to the plain format.
	test::eq(format_to_dxgi_typeless(Format.R11_G11_B10_UFLOAT), dxgi::Format.R11G11B10_FLOAT);
	test::eq(format_to_dxgi_srv(Format.RGBA8_UNORM), dxgi::Format.R8G8B8A8_UNORM);
	test::eq(format_to_dxgi_dsv(Format.RGBA8_UNORM), dxgi::Format.UNKNOWN);
}

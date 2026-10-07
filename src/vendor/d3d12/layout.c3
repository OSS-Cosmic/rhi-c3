// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Compile-time layout checks for the D3D12/DXGI bindings. Sizes are the
// Windows x64 ABI values from d3d12.h / dxgi1_*.h; they are evaluated on every
// target (skipped on 32-bit wasm) so a wrong field fails the build
// of whichever target is being compiled, including the windows-x64 check.
module d3d12 @feat(!WASM);
import dxgi;

$assert Guid::size == 16;
$assert Guid::alignment == 4;
$assert SampleDesc::size == 8;
$assert SwapChainDesc1::size == 48;
$assert AdapterDesc1::size == 312;
$assert QueryVideoMemoryInfo::size == 32;

$assert Rect::size == 16;
$assert Viewport::size == 24;
$assert ResourceBox::size == 24;
$assert HeapProperties::size == 20;
$assert HeapDesc::size == 48;
$assert ResourceDesc::size == 56;
$assert ClearValue::size == 20;
$assert ResourceBarrier::size == 32;
$assert PlacedSubresourceFootprint::size == 32;
$assert TextureCopyLocation::size == 48;
$assert VertexBufferView::size == 16;
$assert IndexBufferView::size == 16;
$assert CommandQueueDesc::size == 16;
$assert DescriptorHeapDesc::size == 16;
$assert SamplerDesc::size == 52;
$assert ShaderResourceViewDesc::size == 40;
$assert UnorderedAccessViewDesc::size == 40;
$assert RenderTargetViewDesc::size == 24;
$assert DepthStencilViewDesc::size == 24;
$assert DescriptorRange1::size == 24;
$assert RootParameter1::size == 32;
$assert StaticSamplerDesc::size == 52;
$assert RootSignatureDesc1::size == 40;
$assert VersionedRootSignatureDesc::size == 48;
$assert RenderTargetBlendDesc::size == 40;
$assert BlendDesc::size == 328;
$assert RasterizerDesc::size == 44;
$assert DepthStencilDesc::size == 52;
$assert InputElementDesc::size == 32;
$assert GraphicsPipelineStateDesc::size == 656;
$assert ComputePipelineStateDesc::size == 56;
$assert IndirectArgumentDesc::size == 16;
$assert CommandSignatureDesc::size == 24;
$assert RenderPassRenderTargetDesc::size == 88;
$assert RenderPassDepthStencilDesc::size == 168;
$assert RaytracingGeometryTrianglesDesc::size == 48;
$assert RaytracingGeometryDesc::size == 56;
$assert BuildRaytracingAccelerationStructureInputs::size == 24;
$assert BuildRaytracingAccelerationStructureDesc::size == 48;
$assert RaytracingAccelerationStructurePrebuildInfo::size == 24;
$assert RaytracingInstanceDesc::size == 64;
$assert DispatchRaysDesc::size == 104;
$assert StateSubobject::size == 16;
$assert DxilLibraryDesc::size == 32;
$assert HitGroupDesc::size == 40;

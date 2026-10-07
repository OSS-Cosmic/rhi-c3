// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// DLL entry points for the D3D12 / DXGI bindings (d3d12.dll, dxgi.dll,
// kernel32.dll). Windows only; the type bindings in d3d12.c3 / dxgi.c3 are
// platform independent so the host test suite can pin their layouts.
module d3d12 @feat(WIN32) @link(env::WIN32, "d3d12", "dxgi", "kernel32");
import dxgi;

// d3d12.dll. `adapter` is an IDXGIAdapter* (or null for the default adapter);
// `riid` selects the returned interface (IID_DEVICE, IID_DEVICE5, ...).
extern fn HResult create_device(void* adapter, FeatureLevel minimum_feature_level, Guid* riid, void** device) @cname("D3D12CreateDevice");
extern fn HResult get_debug_interface(Guid* riid, void** debug) @cname("D3D12GetDebugInterface");
extern fn HResult serialize_root_signature(RootSignatureDesc* desc, RootSignatureVersion version, Blob** blob, Blob** error_blob) @cname("D3D12SerializeRootSignature");
extern fn HResult serialize_versioned_root_signature(VersionedRootSignatureDesc* desc, Blob** blob, Blob** error_blob) @cname("D3D12SerializeVersionedRootSignature");

// dxgi.dll. `flags` is CREATE_FACTORY_DEBUG or 0.
extern fn HResult create_dxgi_factory2(uint flags, Guid* riid, void** factory) @cname("CreateDXGIFactory2");

// kernel32.dll, for fence completion waits.
const uint WAIT_OBJECT_0 = 0;
const uint WAIT_TIMEOUT = 0x102;
const uint WAIT_FAILED = 0xFFFFFFFF;
const uint INFINITE = 0xFFFFFFFF;

extern fn Handle create_event_w(void* attributes, Bool32 manual_reset, Bool32 initial_state, Char16* name) @cname("CreateEventW");
extern fn uint wait_for_single_object(Handle handle, uint milliseconds) @cname("WaitForSingleObject");
extern fn Bool32 close_handle(Handle handle) @cname("CloseHandle");

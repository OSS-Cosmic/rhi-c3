// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral image view handle. Port of the Vulkan arm of rhi-zig's
// `image_view.zig` `ImageView` type.
module rhi;
import d3d12, dxgi, mtl, vk;

enum ViewType : char
{
	SHADER_RESOURCE_1D,
	SHADER_RESOURCE_1D_ARRAY,
	SHADER_RESOURCE_2D,
	SHADER_RESOURCE_2D_ARRAY,
	SHADER_RESOURCE_CUBE,
	SHADER_RESOURCE_CUBE_ARRAY,
	SHADER_RESOURCE_3D,
	SHADER_RESOURCE_STORAGE_1D,
	SHADER_RESOURCE_STORAGE_1D_ARRAY,
	SHADER_RESOURCE_STORAGE_2D,
	SHADER_RESOURCE_STORAGE_2D_ARRAY,
	SHADER_RESOURCE_STORAGE_3D,
	COLOR_ATTACHMENT,
	DEPTH_STENCIL_ATTACHMENT,
	DEPTH_READONLY_STENCIL_ATTACHMENT,
	DEPTH_ATTACHMENT_STENCIL_READONLY,
	DEPTH_STENCIL_READONLY,
	SHADING_RATE_ATTACHMENT,
}

enum ImageAspect : char
{
	COLOR,
	DEPTH,
	STENCIL,
	DEPTH_STENCIL,
}

struct ViewDesc
{
	ViewType view_type;
	Format format;
	ImageAspect aspect;
	uint base_mip;
	uint mip_num;
	uint base_layer;
	uint layer_num;
}

struct ImageView
{
	ulong cookie;
	union backend
	{
		ImageViewVk vk;
		ImageViewDx12 dx12;
		ImageViewWgpu wgpu;
		ImageViewWebgl webgl;
		ImageViewMtlState mtl;
	}
}

<*
	@require [image] image != null && image.cookie != 0 :
	`Image views require an initialized image.`
*>
fn ImageView? image_view_init(Device* device, Image* image, ViewDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				{
	assert(image.backend.vk.image != (vk::Image)0, "image view requires a valid Vulkan image");
					vk::ImageViewCreateInfo create_info = {
						.sType = vk::StructureType.STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
						.image = image.backend.vk.image,
						.viewType = image_view_type_vk(desc.view_type),
						.format = to_vk_format(desc.format),
						.components = {
							.r = vk::ComponentSwizzle.COMPONENT_SWIZZLE_IDENTITY,
							.g = vk::ComponentSwizzle.COMPONENT_SWIZZLE_IDENTITY,
							.b = vk::ComponentSwizzle.COMPONENT_SWIZZLE_IDENTITY,
							.a = vk::ComponentSwizzle.COMPONENT_SWIZZLE_IDENTITY,
						},
						.subresourceRange = {
							.aspectMask = image_view_aspect_vk(desc.aspect),
							.baseMipLevel = desc.base_mip,
							.levelCount = desc.mip_num,
							.baseArrayLayer = desc.base_layer,
							.layerCount = desc.layer_num,
						},
					};
					vk::ImageView view;
					vk_check(vk::vkCreateImageView(device.backend.vk.device, &create_info, null, &view))!;
					return {
						.cookie = next_cookie(),
						.backend.vk = { .view = view, .borrowed = false },
					};
				}
			$endif
		case DX12:
			$if HAS_DX12:
				{
					assert(image != null && image.cookie != 0 && image.backend.dx12.resource &&
						desc.mip_num != 0 && desc.layer_num != 0,
						"DX12 image view requires an initialized image and a nonempty range");
					ImageDx12* parent = &image.backend.dx12;
					assert(desc.base_mip < parent.mip_levels && desc.mip_num <= parent.mip_levels - desc.base_mip &&
						desc.base_layer < parent.array_layers && desc.layer_num <= parent.array_layers - desc.base_layer,
						"DX12 image view range exceeds its image");
					assert(desc.view_type != ViewType.SHADING_RATE_ATTACHMENT,
						"DX12 does not support shading rate image views");

					d3d12::DescriptorHeapType heap_type;
					if (dx12_view_is_srv(desc.view_type) || dx12_view_is_uav(desc.view_type))
					{
						heap_type = d3d12::DescriptorHeapType.CBV_SRV_UAV;
					}
					else if (desc.view_type == ViewType.COLOR_ATTACHMENT)
					{
						heap_type = d3d12::DescriptorHeapType.RTV;
					}
					else
					{
						heap_type = d3d12::DescriptorHeapType.DSV;
					}

					d3d12::Device* dev = device.backend.dx12.device;
					d3d12::DescriptorHeapDesc heap_desc = {
						.type = heap_type,
						.num_descriptors = 1,
						.flags = d3d12::DESCRIPTOR_HEAP_FLAG_NONE,
					};
					Guid iid = d3d12::IID_DESCRIPTOR_HEAP;
					d3d12::DescriptorHeap* heap;
					if (dxgi::failed(dev.vtbl.create_descriptor_heap(dev, &heap_desc, &iid, (void**)&heap)) || !heap)
					{
						return OUT_OF_DEVICE_MEMORY~;
					}
					d3d12::CpuDescriptorHandle cpu;
					heap.vtbl.get_cpu_descriptor_handle_for_heap_start(heap, &cpu);

					d3d12::Resource* resource = parent.resource;
					dxgi::Format format;
					if (dx12_view_is_srv(desc.view_type))
					{
						d3d12::ShaderResourceViewDesc srv;
						if (catch err = dx12_fill_srv(&srv, parent, desc))
						{
							dxgi::release(heap);
							return err~;
						}
						format = srv.format;
						dev.vtbl.create_shader_resource_view(dev, resource, &srv, cpu);
					}
					else if (dx12_view_is_uav(desc.view_type))
					{
						d3d12::UnorderedAccessViewDesc uav;
						if (catch err = dx12_fill_uav(&uav, desc))
						{
							dxgi::release(heap);
							return err~;
						}
						format = uav.format;
						dev.vtbl.create_unordered_access_view(dev, resource, null, &uav, cpu);
					}
					else if (desc.view_type == ViewType.COLOR_ATTACHMENT)
					{
						d3d12::RenderTargetViewDesc rtv;
						if (catch err = dx12_fill_rtv(&rtv, parent, desc))
						{
							dxgi::release(heap);
							return err~;
						}
						format = rtv.format;
						dev.vtbl.create_render_target_view(dev, resource, &rtv, cpu);
					}
					else
					{
						d3d12::DepthStencilViewDesc dsv;
						if (catch err = dx12_fill_dsv(&dsv, parent, desc))
						{
							dxgi::release(heap);
							return err~;
						}
						format = dsv.format;
						dev.vtbl.create_depth_stencil_view(dev, resource, &dsv, cpu);
					}

					return {
						.cookie = next_cookie(),
						.backend.dx12 = {
							.heap = heap,
							.heap_type = heap_type,
							.cpu = cpu,
							.resource = resource,
							.format = format,
						},
					};
				}
			$endif
		case MTL:
			$if HAS_MTL:
				{
					assert(image != null && image.cookie != 0 && image.backend.mtl.texture &&
						desc.mip_num != 0 && desc.layer_num != 0,
						"Metal image view requires an initialized image and a nonempty range");
					ImageMtlState* parent_state = &image.backend.mtl;
					assert(desc.base_mip < parent_state.mip_levels && desc.mip_num <= parent_state.mip_levels - desc.base_mip &&
						desc.base_layer < parent_state.array_layers && desc.layer_num <= parent_state.array_layers - desc.base_layer,
						"Metal image view range exceeds its image");
					assert(parent_state.image_type != D3 || (desc.base_layer == 0 && desc.layer_num == 1),
						"Metal 3D image views must cover the single array layer");
					assert(to_mtl_pixel_format(desc.format) != mtl::PixelFormat.INVALID,
						"Metal image view format is unsupported");

					mtl::Texture parent = parent_state.texture;
					parent.retain();
					if (mtl_view_full_range(parent_state, desc))
					{
						return {
							.cookie = next_cookie(),
							.backend.mtl = { .texture = parent, .parent = parent, .aliases_parent = true },
						};
					}

					mtl::NSRange levels = { .location = desc.base_mip, .length = desc.mip_num };
					mtl::NSRange slices = { .location = desc.base_layer, .length = desc.layer_num };
					mtl::Texture view = parent.new_texture_view(
						to_mtl_pixel_format(desc.format), mtl_view_texture_type(desc.view_type), levels, slices);
					if (!view)
					{
						parent.release();
						return OUT_OF_DEVICE_MEMORY~;
					}
					return {
						.cookie = next_cookie(),
						.backend.mtl = { .texture = view, .parent = parent, .aliases_parent = false },
					};
				}
			$endif
		case WGPU:
			$if HAS_WGPU:
				{
					if (image == null || image.cookie == 0) return INITIALIZATION_FAILED~;
					ImageWgpu* state = &image.backend.wgpu;
					if (desc.base_mip >= state.mip_levels || desc.mip_num == 0 || desc.mip_num > state.mip_levels - desc.base_mip || desc.base_layer >= state.array_layers || desc.layer_num == 0 || desc.layer_num > state.array_layers - desc.base_layer) return UNSUPPORTED_FEATURE~;
					uint dimension;
					switch (desc.view_type)
					{
						case SHADER_RESOURCE_1D: dimension = 0;
						case SHADER_RESOURCE_STORAGE_1D: dimension = 0;
						case SHADER_RESOURCE_2D: dimension = 1;
						case SHADER_RESOURCE_STORAGE_2D: dimension = 1;
						case COLOR_ATTACHMENT: dimension = 1;
						case DEPTH_STENCIL_ATTACHMENT: dimension = 1;
						case DEPTH_READONLY_STENCIL_ATTACHMENT: dimension = 1;
						case DEPTH_ATTACHMENT_STENCIL_READONLY: dimension = 1;
						case DEPTH_STENCIL_READONLY: dimension = 1;
						case SHADER_RESOURCE_2D_ARRAY: dimension = 2;
						case SHADER_RESOURCE_STORAGE_2D_ARRAY: dimension = 2;
						case SHADER_RESOURCE_CUBE: dimension = 3;
						case SHADER_RESOURCE_CUBE_ARRAY: dimension = 4;
						case SHADER_RESOURCE_3D: dimension = 5;
						case SHADER_RESOURCE_STORAGE_3D: dimension = 5;
						default: return UNSUPPORTED_FEATURE~;
					}
					uint aspect = desc.aspect == COLOR || desc.aspect == DEPTH_STENCIL ? 0 : desc.aspect == STENCIL ? 1 : 2;
					WgpuTextureFormat format = wgpu_format(desc.format)!!;
					uint view = wgpu_texture_create_view(state.texture, (uint)format, dimension, aspect, desc.base_mip, desc.mip_num, desc.base_layer, desc.layer_num);
					if (view == 0) return OUT_OF_DEVICE_MEMORY~;
					return { .cookie = next_cookie(), .backend.wgpu = { .view = view } };
				}
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				{
					if (image == null || image.backend.webgl.texture == 0) return INITIALIZATION_FAILED~;
					ImageView v = {};
					v.backend.webgl.texture = image.backend.webgl.texture;
					v.backend.webgl.width = image.backend.webgl.width;
					v.backend.webgl.height = image.backend.webgl.height;
					if (desc.view_type == COLOR_ATTACHMENT || desc.view_type == DEPTH_STENCIL_ATTACHMENT)
					{
						v.backend.webgl.framebuffer = gl_create_framebuffer();
						uint attachment = desc.view_type == COLOR_ATTACHMENT ? GL_COLOR_ATTACHMENT0 : GL_DEPTH_STENCIL_ATTACHMENT;
						gl_framebuffer_texture_2d(v.backend.webgl.framebuffer, attachment, v.backend.webgl.texture);
						if (gl_check_framebuffer_status(v.backend.webgl.framebuffer) != 0x8CD5) return INITIALIZATION_FAILED~;
					}
					v.cookie = image.cookie ^ ((ulong)desc.base_mip << 32) ^ desc.base_layer + 1;
					return v;
				}
			$endif
	}
	unreachable();
}

fn void image_view_deinit(ImageView* v, Device* device)
{
	if (v == null || v.cookie == 0) return;
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				image_view_deinit_vk(v, device);
			$endif
		case DX12:
			$if HAS_DX12:
				image_view_deinit_dx12(v, device);
			$endif
		case MTL:
			$if HAS_MTL:
				image_view_deinit_mtl_impl(v, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				image_view_deinit_wgpu(v, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				image_view_deinit_webgl(v, device);
			$endif
	}
	// All backends share this guard, making deinit idempotent at the RHI layer.
	v.cookie = 0;
}

fn bool image_view_is_empty(ImageView* v)
{
	return v.cookie == 0;
}

// ---- metal ----

// Metal image views.  A view keeps the parent texture retained so an Image
// may be released only after all of its views have been released.  A full
// range, same-format view aliases the parent; sub-ranges use Metal's native
// texture-view object.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import mtl;

struct ImageViewMtlState
{
	mtl::Texture texture;
	mtl::Texture parent;
	bool aliases_parent;
}

fn mtl::TextureType mtl_view_texture_type(ViewType view_type)
{
	switch (view_type)
	{
		case SHADER_RESOURCE_1D: return mtl::TextureType.TYPE_1D;
		case SHADER_RESOURCE_1D_ARRAY: return mtl::TextureType.TYPE_1D_ARRAY;
		case SHADER_RESOURCE_2D: return mtl::TextureType.TYPE_2D;
		case SHADER_RESOURCE_2D_ARRAY: return mtl::TextureType.TYPE_2D_ARRAY;
		case SHADER_RESOURCE_CUBE: return mtl::TextureType.TYPE_CUBE;
		case SHADER_RESOURCE_CUBE_ARRAY: return mtl::TextureType.TYPE_CUBE_ARRAY;
		case SHADER_RESOURCE_3D: return mtl::TextureType.TYPE_3D;
		case SHADER_RESOURCE_STORAGE_1D: return mtl::TextureType.TYPE_1D;
		case SHADER_RESOURCE_STORAGE_1D_ARRAY: return mtl::TextureType.TYPE_1D_ARRAY;
		case SHADER_RESOURCE_STORAGE_2D: return mtl::TextureType.TYPE_2D;
		case SHADER_RESOURCE_STORAGE_2D_ARRAY: return mtl::TextureType.TYPE_2D_ARRAY;
		case SHADER_RESOURCE_STORAGE_3D: return mtl::TextureType.TYPE_3D;
		case COLOR_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_STENCIL_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_READONLY_STENCIL_ATTACHMENT: return mtl::TextureType.TYPE_2D;
		case DEPTH_ATTACHMENT_STENCIL_READONLY: return mtl::TextureType.TYPE_2D;
		case DEPTH_STENCIL_READONLY: return mtl::TextureType.TYPE_2D;
		case SHADING_RATE_ATTACHMENT: return mtl::TextureType.TYPE_2D;
	}
}

fn bool mtl_view_full_range(ImageMtlState* image, ViewDesc desc)
{
	return desc.base_mip == 0 && desc.mip_num == image.mip_levels &&
		desc.base_layer == 0 && desc.layer_num == image.array_layers &&
		desc.format == image.format && mtl_view_texture_type(desc.view_type) == image.texture_type;
}

fn void image_view_deinit_mtl_impl(ImageView* view, Device* device)
{
	if (view.backend.mtl.aliases_parent)
	{
		if (view.backend.mtl.parent) view.backend.mtl.parent.release();
	}
	else
	{
		if (view.backend.mtl.texture) view.backend.mtl.texture.release();
		if (view.backend.mtl.parent) view.backend.mtl.parent.release();
	}
	view.backend.mtl = {};
}

// ---- dx12 ----

// Direct3D 12 image views. A view owns a one-descriptor, non-shader-visible
// CPU descriptor heap holding its SRV, UAV, RTV or DSV; consumers copy the
// descriptor into their own shader-visible heap. The view does not retain the
// image's resource, so an Image must outlive its views.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct ImageViewDx12
{
	// Owned: single-descriptor CPU heap.
	d3d12::DescriptorHeap* heap;
	d3d12::DescriptorHeapType heap_type;
	d3d12::CpuDescriptorHandle cpu;
	// Borrowed from the parent image.
	d3d12::Resource* resource;
	dxgi::Format format;
}

fn bool dx12_view_is_srv(ViewType t)
{
	return t >= ViewType.SHADER_RESOURCE_1D && t <= ViewType.SHADER_RESOURCE_3D;
}

fn bool dx12_view_is_uav(ViewType t)
{
	return t >= ViewType.SHADER_RESOURCE_STORAGE_1D && t <= ViewType.SHADER_RESOURCE_STORAGE_3D;
}

// Plane 1 holds the stencil of a combined depth-stencil resource.
fn uint dx12_view_plane(ImageAspect aspect) => aspect == STENCIL ? 1 : 0;

fn dxgi::Format dx12_view_srv_format(ViewDesc desc)
{
	if (desc.aspect == STENCIL)
	{
		switch (desc.format)
		{
			case D24_UNORM_S8_UINT: return dxgi::Format.X24_TYPELESS_G8_UINT;
			case D32_SFLOAT_S8_UINT: return dxgi::Format.X32_TYPELESS_G8X24_UINT;
			default: return dxgi::Format.UNKNOWN;
		}
	}
	return format_to_dxgi_srv(desc.format);
}

fn void? dx12_fill_srv(d3d12::ShaderResourceViewDesc* out, ImageDx12* image, ViewDesc desc)
{
	dxgi::Format format = dx12_view_srv_format(desc);
	if (format == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	uint plane = dx12_view_plane(desc.aspect);
	*out = {
		.format = format,
		.shader_4_component_mapping = d3d12::DEFAULT_SHADER_4_COMPONENT_MAPPING,
	};
	switch (desc.view_type)
	{
		case SHADER_RESOURCE_1D:
			out.view_dimension = d3d12::SrvDimension.TEXTURE1D;
			out.texture2d = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num };
		case SHADER_RESOURCE_1D_ARRAY:
			out.view_dimension = d3d12::SrvDimension.TEXTURE1DARRAY;
			out.texture2d_array = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num,
				.first_array_slice = desc.base_layer, .array_size = desc.layer_num };
		case SHADER_RESOURCE_2D:
			if (image.sample_count > 1)
			{
				out.view_dimension = d3d12::SrvDimension.TEXTURE2DMS;
			}
			else
			{
				out.view_dimension = d3d12::SrvDimension.TEXTURE2D;
				out.texture2d = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num, .plane_slice = plane };
			}
		case SHADER_RESOURCE_2D_ARRAY:
			if (image.sample_count > 1)
			{
				out.view_dimension = d3d12::SrvDimension.TEXTURE2DMSARRAY;
				// D3D12_TEX2DMS_ARRAY_SRV { FirstArraySlice, ArraySize }.
				out.texture2d = { .most_detailed_mip = desc.base_layer, .mip_levels = desc.layer_num };
			}
			else
			{
				out.view_dimension = d3d12::SrvDimension.TEXTURE2DARRAY;
				out.texture2d_array = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num,
					.first_array_slice = desc.base_layer, .array_size = desc.layer_num, .plane_slice = plane };
			}
		case SHADER_RESOURCE_CUBE:
			out.view_dimension = d3d12::SrvDimension.TEXTURECUBE;
			out.texture_cube = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num };
		case SHADER_RESOURCE_CUBE_ARRAY:
			out.view_dimension = d3d12::SrvDimension.TEXTURECUBEARRAY;
			// D3D12_TEXCUBE_ARRAY_SRV { MostDetailedMip, MipLevels, First2DArrayFace, NumCubes }.
			out.texture2d_array = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num,
				.first_array_slice = desc.base_layer, .array_size = desc.layer_num / 6 };
		case SHADER_RESOURCE_3D:
			out.view_dimension = d3d12::SrvDimension.TEXTURE3D;
			out.texture3d = { .most_detailed_mip = desc.base_mip, .mip_levels = desc.mip_num };
		default:
			return UNSUPPORTED_FEATURE~;
	}
}

fn void? dx12_fill_uav(d3d12::UnorderedAccessViewDesc* out, ViewDesc desc)
{
	dxgi::Format format = format_to_dxgi(desc.format);
	if (format == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	*out = { .format = format };
	switch (desc.view_type)
	{
		case SHADER_RESOURCE_STORAGE_1D:
			out.view_dimension = d3d12::UavDimension.TEXTURE1D;
			out.texture2d = { .mip_slice = desc.base_mip };
		case SHADER_RESOURCE_STORAGE_1D_ARRAY:
			out.view_dimension = d3d12::UavDimension.TEXTURE1DARRAY;
			out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer, .array_size = desc.layer_num };
		case SHADER_RESOURCE_STORAGE_2D:
			out.view_dimension = d3d12::UavDimension.TEXTURE2D;
			out.texture2d = { .mip_slice = desc.base_mip, .plane_slice = dx12_view_plane(desc.aspect) };
		case SHADER_RESOURCE_STORAGE_2D_ARRAY:
			out.view_dimension = d3d12::UavDimension.TEXTURE2DARRAY;
			out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer,
				.array_size = desc.layer_num, .plane_slice = dx12_view_plane(desc.aspect) };
		case SHADER_RESOURCE_STORAGE_3D:
			out.view_dimension = d3d12::UavDimension.TEXTURE3D;
			out.texture3d = { .mip_slice = desc.base_mip, .first_w_slice = 0, .w_size = 0xFFFFFFFF };
		default:
			return UNSUPPORTED_FEATURE~;
	}
}

fn void? dx12_fill_rtv(d3d12::RenderTargetViewDesc* out, ImageDx12* image, ViewDesc desc)
{
	dxgi::Format format = format_to_dxgi(desc.format);
	if (format == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	*out = { .format = format };
	bool multisampled = image.sample_count > 1;
	bool array = image.array_layers > 1 || desc.layer_num > 1;
	switch (image.image_type)
	{
		case D1:
			out.view_dimension = array ? d3d12::RtvDimension.TEXTURE1DARRAY : d3d12::RtvDimension.TEXTURE1D;
			out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer, .array_size = desc.layer_num };
			// The non-array layout only has MipSlice, which shares the first field.
		case D2:
			if (multisampled)
			{
				out.view_dimension = array ? d3d12::RtvDimension.TEXTURE2DMSARRAY : d3d12::RtvDimension.TEXTURE2DMS;
				// TEX2DMS_ARRAY_RTV is { FirstArraySlice, ArraySize }.
				out.texture2d = { .mip_slice = desc.base_layer, .plane_slice = desc.layer_num };
			}
			else if (array)
			{
				out.view_dimension = d3d12::RtvDimension.TEXTURE2DARRAY;
				out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer,
					.array_size = desc.layer_num, .plane_slice = dx12_view_plane(desc.aspect) };
			}
			else
			{
				out.view_dimension = d3d12::RtvDimension.TEXTURE2D;
				out.texture2d = { .mip_slice = desc.base_mip, .plane_slice = dx12_view_plane(desc.aspect) };
			}
		case D3:
			out.view_dimension = d3d12::RtvDimension.TEXTURE3D;
			out.texture3d = { .mip_slice = desc.base_mip, .first_w_slice = 0, .w_size = 0xFFFFFFFF };
	}
}

fn void? dx12_fill_dsv(d3d12::DepthStencilViewDesc* out, ImageDx12* image, ViewDesc desc)
{
	dxgi::Format format = format_to_dxgi_dsv(desc.format);
	if (format == dxgi::Format.UNKNOWN) return UNSUPPORTED_FEATURE~;
	d3d12::DsvFlags flags = d3d12::DSV_FLAG_NONE;
	switch (desc.view_type)
	{
		case DEPTH_READONLY_STENCIL_ATTACHMENT: flags = d3d12::DSV_FLAG_READ_ONLY_DEPTH;
		case DEPTH_ATTACHMENT_STENCIL_READONLY: flags = d3d12::DSV_FLAG_READ_ONLY_STENCIL;
		case DEPTH_STENCIL_READONLY: flags = d3d12::DSV_FLAG_READ_ONLY_DEPTH | d3d12::DSV_FLAG_READ_ONLY_STENCIL;
		default:
	}
	*out = { .format = format, .flags = flags };
	bool multisampled = image.sample_count > 1;
	bool array = image.array_layers > 1 || desc.layer_num > 1;
	if (image.image_type == D1)
	{
		out.view_dimension = array ? d3d12::DsvDimension.TEXTURE1DARRAY : d3d12::DsvDimension.TEXTURE1D;
		out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer, .array_size = desc.layer_num };
	}
	else if (multisampled)
	{
		out.view_dimension = array ? d3d12::DsvDimension.TEXTURE2DMSARRAY : d3d12::DsvDimension.TEXTURE2DMS;
		// TEX2DMS_ARRAY_DSV is { FirstArraySlice, ArraySize }.
		out.texture2d_array = { .mip_slice = desc.base_layer, .first_array_slice = desc.layer_num };
	}
	else if (array)
	{
		out.view_dimension = d3d12::DsvDimension.TEXTURE2DARRAY;
		out.texture2d_array = { .mip_slice = desc.base_mip, .first_array_slice = desc.base_layer, .array_size = desc.layer_num };
	}
	else
	{
		out.view_dimension = d3d12::DsvDimension.TEXTURE2D;
		out.texture2d = { .mip_slice = desc.base_mip };
	}
}

fn void image_view_deinit_dx12(ImageView* v, Device* device)
{
	if (v.backend.dx12.heap) dxgi::release(v.backend.dx12.heap);
	v.backend.dx12 = {};
}

// ---- vulkan ----

// Vulkan image views.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct ImageViewVk
{
	vk::ImageView view;
	bool borrowed;
}

fn vk::ImageAspectFlags image_view_aspect_vk(ImageAspect aspect) @private
{
	switch (aspect)
	{
		case COLOR: return vk::ImageAspectFlagBits.IMAGE_ASPECT_COLOR_BIT;
		case DEPTH: return vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT;
		case STENCIL: return vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
		case DEPTH_STENCIL: return vk::ImageAspectFlagBits.IMAGE_ASPECT_DEPTH_BIT | vk::ImageAspectFlagBits.IMAGE_ASPECT_STENCIL_BIT;
	}
}

fn vk::ImageViewType image_view_type_vk(ViewType type) @private
{
	switch (type)
	{
		case SHADER_RESOURCE_1D:
		case SHADER_RESOURCE_STORAGE_1D: return vk::ImageViewType.IMAGE_VIEW_TYPE_1D;
		case SHADER_RESOURCE_1D_ARRAY:
		case SHADER_RESOURCE_STORAGE_1D_ARRAY: return vk::ImageViewType.IMAGE_VIEW_TYPE_1D_ARRAY;
		case SHADER_RESOURCE_2D:
		case SHADER_RESOURCE_STORAGE_2D:
		case COLOR_ATTACHMENT:
		case DEPTH_STENCIL_ATTACHMENT:
		case DEPTH_READONLY_STENCIL_ATTACHMENT:
		case DEPTH_ATTACHMENT_STENCIL_READONLY:
		case DEPTH_STENCIL_READONLY:
		case SHADING_RATE_ATTACHMENT: return vk::ImageViewType.IMAGE_VIEW_TYPE_2D;
		case SHADER_RESOURCE_2D_ARRAY:
		case SHADER_RESOURCE_STORAGE_2D_ARRAY: return vk::ImageViewType.IMAGE_VIEW_TYPE_2D_ARRAY;
		case SHADER_RESOURCE_CUBE: return vk::ImageViewType.IMAGE_VIEW_TYPE_CUBE;
		case SHADER_RESOURCE_CUBE_ARRAY: return vk::ImageViewType.IMAGE_VIEW_TYPE_CUBE_ARRAY;
		case SHADER_RESOURCE_3D:
		case SHADER_RESOURCE_STORAGE_3D: return vk::ImageViewType.IMAGE_VIEW_TYPE_3D;
	}
}

fn void image_view_deinit_vk(ImageView* v, Device* device)
{
	if (v.backend.vk.borrowed) return;
	if (v.backend.vk.view != (vk::ImageView)0) {
		vk::destroyImageView(device.backend.vk.device, v.backend.vk.view, null);
	}
	v.backend.vk = {};
}

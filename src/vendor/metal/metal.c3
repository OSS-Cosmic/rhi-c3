// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Metal (MTL) bindings, ported from rhi-zig deps/metal/src/metal.zig: the
// curated subset the RHI backend needs. Each type is a typed view over an
// `objc_object*`; methods forward to objc_msgSend with the selector named in
// the matching Apple header. See wrapper.c3 for conventions and ownership.
// Extend on demand.
module mtl @feat(DARWIN) @link(env::DARWIN, "Metal.framework");
import std::os::macos::objc;

// MTLCreateSystemDefaultDevice() — a C function exported by the Metal
// framework (not an Objective-C method). Returns null if Metal is
// unavailable. Owned by the caller.
extern fn Device create_system_default_device() @cname("MTLCreateSystemDefaultDevice");

// MTLCopyAllDevices() (MTLDevice.h, macOS only) — NSArray of every Device in
// the system. Owned by the caller (the array; its elements are retained by
// it).
extern fn NSArray copy_all_devices() @cname("MTLCopyAllDevices");

// -- Device ----------------------------------------------------------------

typedef Device @constinit = inline void*;

fn void Device.retain(self) => retain(self);
fn void Device.release(self) => objc::release(self);

// -name (autoreleased NSString).
fn NSString Device.name(self) => (NSString)objc::msg_send(self, MsgId, "name");

// -isLowPower — true for integrated GPUs.
fn bool Device.is_low_power(self) => objc::msg_send(self, MsgBool, "isLowPower");

// -registryID — IORegistry id, stable across processes.
fn ulong Device.registry_id(self) => objc::msg_send(self, MsgUint, "registryID");

// -recommendedMaxWorkingSetSize (bytes).
fn ulong Device.recommended_max_working_set_size(self) => objc::msg_send(self, MsgUint, "recommendedMaxWorkingSetSize");

// -hasUnifiedMemory.
fn bool Device.has_unified_memory(self) => objc::msg_send(self, MsgBool, "hasUnifiedMemory");

// -maxBufferLength (bytes).
fn NSUInteger Device.max_buffer_length(self) => objc::msg_send(self, MsgUint, "maxBufferLength");

// -maxThreadsPerThreadgroup. Struct return: arm64 only (see wrapper.c3).
fn Size Device.max_threads_per_threadgroup(self) => objc::msg_send(self, MsgSize, "maxThreadsPerThreadgroup");

// -newCommandQueue. Owned by the caller.
fn CommandQueue Device.new_command_queue(self) => (CommandQueue)objc::msg_send(self, MsgId, "newCommandQueue");

// -newBufferWithLength:options:. Owned by the caller.
fn Buffer Device.new_buffer(self, NSUInteger length, ResourceOptions options)
{
	return (Buffer)objc::msg_send(self, MsgIdUintUint, "newBufferWithLength:options:", length, (NSUInteger)options);
}

// -newBufferWithBytes:length:options: — initialised from CPU memory. Owned by
// the caller.
fn Buffer Device.new_buffer_with_bytes(self, void* bytes, NSUInteger length, ResourceOptions options)
{
	return (Buffer)objc::msg_send(self, MsgIdIdUintUint, "newBufferWithBytes:length:options:", bytes, length, (NSUInteger)options);
}

// -newTextureWithDescriptor:. Owned by the caller.
fn Texture Device.new_texture(self, TextureDescriptor descriptor)
{
	return (Texture)objc::msg_send(self, MsgIdId, "newTextureWithDescriptor:", descriptor);
}

// -newSamplerStateWithDescriptor:. Owned by the caller.
fn SamplerState Device.new_sampler_state(self, SamplerDescriptor descriptor)
{
	return (SamplerState)objc::msg_send(self, MsgIdId, "newSamplerStateWithDescriptor:", descriptor);
}

// -newDepthStencilStateWithDescriptor:. Owned by the caller.
fn DepthStencilState Device.new_depth_stencil_state(self, DepthStencilDescriptor descriptor)
{
	return (DepthStencilState)objc::msg_send(self, MsgIdId, "newDepthStencilStateWithDescriptor:", descriptor);
}

// -newSharedEvent. Owned by the caller.
fn SharedEvent Device.new_shared_event(self) => (SharedEvent)objc::msg_send(self, MsgId, "newSharedEvent");

// -newLibraryWithSource:options:error:. `options` may be null. On failure
// returns null and, if `out_err` is non-null, stores the (autoreleased)
// NSError. Owned by the caller.
fn Library Device.new_library_with_source(self, NSString source, CompileOptions options, NSError* out_err)
{
	ObjcId err_id = null;
	Library result = (Library)objc::msg_send(self, MsgIdIdIdPtr, "newLibraryWithSource:options:error:", source, options, &err_id);
	if (out_err) *out_err = (NSError)err_id;
	return result;
}

// -newRenderPipelineStateWithDescriptor:error:. On failure returns null and,
// if `out_err` is non-null, stores the (autoreleased) NSError. Owned by the
// caller.
fn RenderPipelineState Device.new_render_pipeline_state(self, RenderPipelineDescriptor descriptor, NSError* out_err)
{
	ObjcId err_id = null;
	RenderPipelineState result = (RenderPipelineState)objc::msg_send(self, MsgIdIdPtr, "newRenderPipelineStateWithDescriptor:error:", descriptor, &err_id);
	if (out_err) *out_err = (NSError)err_id;
	return result;
}

// -- Command submission ----------------------------------------------------

typedef CommandQueue @constinit = inline void*;

fn void CommandQueue.retain(self) => retain(self);
fn void CommandQueue.release(self) => objc::release(self);

// -commandBuffer (autoreleased).
fn CommandBuffer CommandQueue.command_buffer(self) => (CommandBuffer)objc::msg_send(self, MsgId, "commandBuffer");

// -setLabel:.
fn void CommandQueue.set_label(self, NSString label) => objc::msg_send(self, MsgVoidId, "setLabel:", label);

typedef CommandBuffer @constinit = inline void*;

fn void CommandBuffer.retain(self) => retain(self);
fn void CommandBuffer.release(self) => objc::release(self);

// -renderCommandEncoderWithDescriptor: (autoreleased).
fn RenderCommandEncoder CommandBuffer.render_command_encoder(self, RenderPassDescriptor descriptor)
{
	return (RenderCommandEncoder)objc::msg_send(self, MsgIdId, "renderCommandEncoderWithDescriptor:", descriptor);
}

// -blitCommandEncoder (autoreleased).
fn BlitCommandEncoder CommandBuffer.blit_command_encoder(self) => (BlitCommandEncoder)objc::msg_send(self, MsgId, "blitCommandEncoder");

// -presentDrawable: — schedules the drawable to be presented. `drawable` is
// any object conforming to MTLDrawable (e.g. a CAMetalDrawable); pass its
// underlying id (CAMetalDrawable.id()).
fn void CommandBuffer.present_drawable(self, ObjcId drawable) => objc::msg_send(self, MsgVoidId, "presentDrawable:", drawable);

// -encodeWaitForEvent:value: — GPU waits until `event` reaches `value`.
fn void CommandBuffer.encode_wait_for_event(self, SharedEvent event, ulong value)
{
	objc::msg_send(self, MsgVoidIdUint, "encodeWaitForEvent:value:", event, value);
}

// -encodeSignalEvent:value: — GPU sets `event` to `value` once prior work
// completes.
fn void CommandBuffer.encode_signal_event(self, SharedEvent event, ulong value)
{
	objc::msg_send(self, MsgVoidIdUint, "encodeSignalEvent:value:", event, value);
}

// -commit.
fn void CommandBuffer.commit(self) => objc::msg_send(self, MsgVoid, "commit");

// -waitUntilCompleted.
fn void CommandBuffer.wait_until_completed(self) => objc::msg_send(self, MsgVoid, "waitUntilCompleted");

typedef RenderCommandEncoder @constinit = inline void*;

fn void RenderCommandEncoder.retain(self) => retain(self);
fn void RenderCommandEncoder.release(self) => objc::release(self);

// -setRenderPipelineState:.
fn void RenderCommandEncoder.set_render_pipeline_state(self, RenderPipelineState state)
{
	objc::msg_send(self, MsgVoidId, "setRenderPipelineState:", state);
}

// -setVertexBuffer:offset:atIndex:.
fn void RenderCommandEncoder.set_vertex_buffer(self, Buffer buffer, NSUInteger offset, NSUInteger index)
{
	objc::msg_send(self, MsgVoidIdUintUint, "setVertexBuffer:offset:atIndex:", buffer, offset, index);
}

// -setVertexBytes:length:atIndex: — inline constant data (push constants).
fn void RenderCommandEncoder.set_vertex_bytes(self, void* bytes, NSUInteger length, NSUInteger index)
{
	objc::msg_send(self, MsgVoidIdUintUint, "setVertexBytes:length:atIndex:", bytes, length, index);
}

// -setFragmentBytes:length:atIndex: — inline constant data (push constants).
fn void RenderCommandEncoder.set_fragment_bytes(self, void* bytes, NSUInteger length, NSUInteger index)
{
	objc::msg_send(self, MsgVoidIdUintUint, "setFragmentBytes:length:atIndex:", bytes, length, index);
}

// -setFragmentTexture:atIndex:.
fn void RenderCommandEncoder.set_fragment_texture(self, Texture texture, NSUInteger index)
{
	objc::msg_send(self, MsgVoidIdUint, "setFragmentTexture:atIndex:", texture, index);
}

// -setFragmentSamplerState:atIndex:.
fn void RenderCommandEncoder.set_fragment_sampler_state(self, SamplerState sampler, NSUInteger index)
{
	objc::msg_send(self, MsgVoidIdUint, "setFragmentSamplerState:atIndex:", sampler, index);
}

// -setViewport:.
fn void RenderCommandEncoder.set_viewport(self, Viewport viewport) => objc::msg_send(self, MsgVoidViewport, "setViewport:", viewport);

// -setDepthStencilState:.
fn void RenderCommandEncoder.set_depth_stencil_state(self, DepthStencilState state)
{
	objc::msg_send(self, MsgVoidId, "setDepthStencilState:", state);
}

// -setScissorRect:.
fn void RenderCommandEncoder.set_scissor_rect(self, ScissorRect rect) => objc::msg_send(self, MsgVoidScissorRect, "setScissorRect:", rect);

// -setCullMode:.
fn void RenderCommandEncoder.set_cull_mode(self, CullMode mode) => objc::msg_send(self, MsgVoidUint, "setCullMode:", mode);

// -setFrontFacingWinding:.
fn void RenderCommandEncoder.set_front_facing_winding(self, Winding winding)
{
	objc::msg_send(self, MsgVoidUint, "setFrontFacingWinding:", winding);
}

// -drawPrimitives:vertexStart:vertexCount:.
fn void RenderCommandEncoder.draw_primitives(self, PrimitiveType primitive_type, NSUInteger vertex_start, NSUInteger vertex_count)
{
	objc::msg_send(self, MsgVoidUintUintUint, "drawPrimitives:vertexStart:vertexCount:", primitive_type, vertex_start, vertex_count);
}

// -drawPrimitives:vertexStart:vertexCount:instanceCount:baseInstance:.
fn void RenderCommandEncoder.draw_primitives_instanced(self, PrimitiveType primitive_type, NSUInteger vertex_start, NSUInteger vertex_count, NSUInteger instance_count, NSUInteger base_instance)
{
	objc::msg_send(self, MsgVoidUintUintUintUintUint, "drawPrimitives:vertexStart:vertexCount:instanceCount:baseInstance:", primitive_type, vertex_start, vertex_count, instance_count, base_instance);
}

// -drawPrimitives:indirectBuffer:indirectBufferOffset: — arguments read from
// an MTLDrawPrimitivesIndirectArguments in `indirect_buffer`.
fn void RenderCommandEncoder.draw_primitives_indirect(self, PrimitiveType primitive_type, Buffer indirect_buffer, NSUInteger indirect_buffer_offset)
{
	objc::msg_send(self, MsgVoidUintIdUint, "drawPrimitives:indirectBuffer:indirectBufferOffset:", primitive_type, indirect_buffer, indirect_buffer_offset);
}

// -drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:.
fn void RenderCommandEncoder.draw_indexed_primitives(self, PrimitiveType primitive_type, NSUInteger index_count, IndexType index_type, Buffer index_buffer, NSUInteger index_buffer_offset)
{
	objc::msg_send(self, MsgVoidUintUintUintIdUint, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:", primitive_type, index_count, index_type, index_buffer, index_buffer_offset);
}

// -drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:.
fn void RenderCommandEncoder.draw_indexed_primitives_instanced(self, PrimitiveType primitive_type, NSUInteger index_count, IndexType index_type, Buffer index_buffer, NSUInteger index_buffer_offset, NSUInteger instance_count, NSInteger base_vertex, NSUInteger base_instance)
{
	objc::msg_send(self, MsgVoidUintUintUintIdUintUintIntUint, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:", primitive_type, index_count, index_type, index_buffer, index_buffer_offset, instance_count, base_vertex, base_instance);
}

// -drawIndexedPrimitives:indexType:indexBuffer:indexBufferOffset:indirectBuffer:indirectBufferOffset:.
fn void RenderCommandEncoder.draw_indexed_primitives_indirect(self, PrimitiveType primitive_type, IndexType index_type, Buffer index_buffer, NSUInteger index_buffer_offset, Buffer indirect_buffer, NSUInteger indirect_buffer_offset)
{
	objc::msg_send(self, MsgVoidUintUintIdUintIdUint, "drawIndexedPrimitives:indexType:indexBuffer:indexBufferOffset:indirectBuffer:indirectBufferOffset:", primitive_type, index_type, index_buffer, index_buffer_offset, indirect_buffer, indirect_buffer_offset);
}

// -memoryBarrierWithScope:afterStages:beforeStages:.
fn void RenderCommandEncoder.memory_barrier(self, BarrierScope scope, RenderStages after_stages, RenderStages before_stages)
{
	objc::msg_send(self, MsgVoidUintUintUint, "memoryBarrierWithScope:afterStages:beforeStages:", (NSUInteger)scope, (NSUInteger)after_stages, (NSUInteger)before_stages);
}

// -endEncoding.
fn void RenderCommandEncoder.end_encoding(self) => objc::msg_send(self, MsgVoid, "endEncoding");

typedef BlitCommandEncoder @constinit = inline void*;

fn void BlitCommandEncoder.retain(self) => retain(self);
fn void BlitCommandEncoder.release(self) => objc::release(self);

// -copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:.
fn void BlitCommandEncoder.copy_buffer_to_buffer(self, Buffer source, NSUInteger source_offset, Buffer destination, NSUInteger destination_offset, NSUInteger size)
{
	objc::msg_send(self, MsgVoidIdUintIdUintUint, "copyFromBuffer:sourceOffset:toBuffer:destinationOffset:size:", source, source_offset, destination, destination_offset, size);
}

// -copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:.
fn void BlitCommandEncoder.copy_buffer_to_texture(self, Buffer source, NSUInteger source_offset, NSUInteger source_bytes_per_row, NSUInteger source_bytes_per_image, Size source_size, Texture destination, NSUInteger destination_slice, NSUInteger destination_level, Origin destination_origin)
{
	objc::msg_send(self, MsgVoidIdUintUintUintSizeIdUintUintOrigin, "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", source, source_offset, source_bytes_per_row, source_bytes_per_image, source_size, destination, destination_slice, destination_level, destination_origin);
}

// -copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toBuffer:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:.
fn void BlitCommandEncoder.copy_texture_to_buffer(self, Texture source, NSUInteger source_slice, NSUInteger source_level, Origin source_origin, Size source_size, Buffer destination, NSUInteger destination_offset, NSUInteger destination_bytes_per_row, NSUInteger destination_bytes_per_image)
{
	objc::msg_send(self, MsgVoidIdUintUintOriginSizeIdUintUintUint, "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toBuffer:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:", source, source_slice, source_level, source_origin, source_size, destination, destination_offset, destination_bytes_per_row, destination_bytes_per_image);
}

// -copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:.
fn void BlitCommandEncoder.copy_texture_to_texture(self, Texture source, NSUInteger source_slice, NSUInteger source_level, Origin source_origin, Size source_size, Texture destination, NSUInteger destination_slice, NSUInteger destination_level, Origin destination_origin)
{
	objc::msg_send(self, MsgVoidIdUintUintOriginSizeIdUintUintOrigin, "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", source, source_slice, source_level, source_origin, source_size, destination, destination_slice, destination_level, destination_origin);
}

// -endEncoding.
fn void BlitCommandEncoder.end_encoding(self) => objc::msg_send(self, MsgVoid, "endEncoding");

// -- Synchronisation -------------------------------------------------------

typedef SharedEvent @constinit = inline void*;

fn void SharedEvent.retain(self) => retain(self);
fn void SharedEvent.release(self) => objc::release(self);

// -signaledValue.
fn ulong SharedEvent.signaled_value(self) => objc::msg_send(self, MsgUint, "signaledValue");

// -setSignaledValue: — signal from the CPU.
fn void SharedEvent.set_signaled_value(self, ulong value) => objc::msg_send(self, MsgVoidUint, "setSignaledValue:", value);

// -- Resources -------------------------------------------------------------

typedef Buffer @constinit = inline void*;

fn void Buffer.retain(self) => retain(self);
fn void Buffer.release(self) => objc::release(self);

// -contents — CPU-accessible pointer (shared/managed storage only).
fn void* Buffer.contents(self) => objc::msg_send(self, MsgId, "contents");

// -length.
fn NSUInteger Buffer.length(self) => objc::msg_send(self, MsgUint, "length");

typedef Texture @constinit = inline void*;

fn void Texture.retain(self) => retain(self);
fn void Texture.release(self) => objc::release(self);

fn NSUInteger Texture.width(self) => objc::msg_send(self, MsgUint, "width");

fn NSUInteger Texture.height(self) => objc::msg_send(self, MsgUint, "height");

// -newTextureViewWithPixelFormat:textureType:levels:slices:. The texture must
// have TEXTURE_USAGE_PIXEL_FORMAT_VIEW if the format differs. Owned by the
// caller.
fn Texture Texture.new_texture_view(self, PixelFormat format, TextureType texture_type, NSRange levels, NSRange slices)
{
	return (Texture)objc::msg_send(self, MsgIdUintUintRangeRange, "newTextureViewWithPixelFormat:textureType:levels:slices:", format, texture_type, levels, slices);
}

typedef SamplerState @constinit = inline void*;

fn void SamplerState.retain(self) => retain(self);
fn void SamplerState.release(self) => objc::release(self);

// -- Shaders / pipeline state ----------------------------------------------

typedef Library @constinit = inline void*;

fn void Library.retain(self) => retain(self);
fn void Library.release(self) => objc::release(self);

// -newFunctionWithName:. Null if no such function. Owned by the caller.
fn Function Library.new_function(self, NSString function_name)
{
	return (Function)objc::msg_send(self, MsgIdId, "newFunctionWithName:", function_name);
}

typedef Function @constinit = inline void*;

fn void Function.retain(self) => retain(self);
fn void Function.release(self) => objc::release(self);

typedef RenderPipelineState @constinit = inline void*;

fn void RenderPipelineState.retain(self) => retain(self);
fn void RenderPipelineState.release(self) => objc::release(self);

typedef DepthStencilState @constinit = inline void*;

fn void DepthStencilState.retain(self) => retain(self);
fn void DepthStencilState.release(self) => objc::release(self);

// -- Descriptors (created via alloc+init or a class factory) ---------------

typedef CompileOptions @constinit = inline void*;

fn void CompileOptions.retain(self) => retain(self);
fn void CompileOptions.release(self) => objc::release(self);

// [[MTLCompileOptions alloc] init]. Owned by the caller.
fn CompileOptions new_compile_options() => @alloc_init(CompileOptions, "MTLCompileOptions");

typedef RenderPipelineDescriptor @constinit = inline void*;

fn void RenderPipelineDescriptor.retain(self) => retain(self);
fn void RenderPipelineDescriptor.release(self) => objc::release(self);

// [[MTLRenderPipelineDescriptor alloc] init]. Owned by the caller.
fn RenderPipelineDescriptor new_render_pipeline_descriptor() => @alloc_init(RenderPipelineDescriptor, "MTLRenderPipelineDescriptor");

fn void RenderPipelineDescriptor.set_vertex_function(self, Function function)
{
	objc::msg_send(self, MsgVoidId, "setVertexFunction:", function);
}

fn void RenderPipelineDescriptor.set_fragment_function(self, Function function)
{
	objc::msg_send(self, MsgVoidId, "setFragmentFunction:", function);
}

fn void RenderPipelineDescriptor.set_label(self, NSString label) => objc::msg_send(self, MsgVoidId, "setLabel:", label);

fn void RenderPipelineDescriptor.set_vertex_descriptor(self, VertexDescriptor vertex_descriptor)
{
	objc::msg_send(self, MsgVoidId, "setVertexDescriptor:", vertex_descriptor);
}

fn void RenderPipelineDescriptor.set_depth_attachment_pixel_format(self, PixelFormat format)
{
	objc::msg_send(self, MsgVoidUint, "setDepthAttachmentPixelFormat:", format);
}

fn void RenderPipelineDescriptor.set_stencil_attachment_pixel_format(self, PixelFormat format)
{
	objc::msg_send(self, MsgVoidUint, "setStencilAttachmentPixelFormat:", format);
}

// -colorAttachments (autoreleased array).
fn RenderPipelineColorAttachmentDescriptorArray RenderPipelineDescriptor.color_attachments(self)
{
	return (RenderPipelineColorAttachmentDescriptorArray)objc::msg_send(self, MsgId, "colorAttachments");
}

// -- MTLVertexDescriptor ---------------------------------------------------

typedef VertexDescriptor @constinit = inline void*;

fn void VertexDescriptor.retain(self) => retain(self);
fn void VertexDescriptor.release(self) => objc::release(self);

// +[MTLVertexDescriptor vertexDescriptor] (autoreleased).
fn VertexDescriptor vertex_descriptor() => @class_msg_object(VertexDescriptor, "MTLVertexDescriptor", "vertexDescriptor");

fn VertexAttributeDescriptorArray VertexDescriptor.attributes(self)
{
	return (VertexAttributeDescriptorArray)objc::msg_send(self, MsgId, "attributes");
}

fn VertexBufferLayoutDescriptorArray VertexDescriptor.layouts(self)
{
	return (VertexBufferLayoutDescriptorArray)objc::msg_send(self, MsgId, "layouts");
}

typedef VertexAttributeDescriptorArray @constinit = inline void*;

// -objectAtIndexedSubscript:.
fn VertexAttributeDescriptor VertexAttributeDescriptorArray.object(self, NSUInteger index)
{
	return (VertexAttributeDescriptor)objc::msg_send(self, MsgIdUint, "objectAtIndexedSubscript:", index);
}

typedef VertexAttributeDescriptor @constinit = inline void*;

fn void VertexAttributeDescriptor.set_format(self, VertexFormat format) => objc::msg_send(self, MsgVoidUint, "setFormat:", format);

fn void VertexAttributeDescriptor.set_offset(self, NSUInteger offset) => objc::msg_send(self, MsgVoidUint, "setOffset:", offset);

fn void VertexAttributeDescriptor.set_buffer_index(self, NSUInteger index) => objc::msg_send(self, MsgVoidUint, "setBufferIndex:", index);

typedef VertexBufferLayoutDescriptorArray @constinit = inline void*;

// -objectAtIndexedSubscript:.
fn VertexBufferLayoutDescriptor VertexBufferLayoutDescriptorArray.object(self, NSUInteger index)
{
	return (VertexBufferLayoutDescriptor)objc::msg_send(self, MsgIdUint, "objectAtIndexedSubscript:", index);
}

typedef VertexBufferLayoutDescriptor @constinit = inline void*;

fn void VertexBufferLayoutDescriptor.set_stride(self, NSUInteger stride) => objc::msg_send(self, MsgVoidUint, "setStride:", stride);

fn void VertexBufferLayoutDescriptor.set_step_function(self, VertexStepFunction step)
{
	objc::msg_send(self, MsgVoidUint, "setStepFunction:", step);
}

fn void VertexBufferLayoutDescriptor.set_step_rate(self, NSUInteger rate) => objc::msg_send(self, MsgVoidUint, "setStepRate:", rate);

// -- Render pipeline color attachments -------------------------------------

typedef RenderPipelineColorAttachmentDescriptorArray @constinit = inline void*;

// -objectAtIndexedSubscript:.
fn RenderPipelineColorAttachmentDescriptor RenderPipelineColorAttachmentDescriptorArray.object(self, NSUInteger index)
{
	return (RenderPipelineColorAttachmentDescriptor)objc::msg_send(self, MsgIdUint, "objectAtIndexedSubscript:", index);
}

typedef RenderPipelineColorAttachmentDescriptor @constinit = inline void*;

fn void RenderPipelineColorAttachmentDescriptor.set_pixel_format(self, PixelFormat format)
{
	objc::msg_send(self, MsgVoidUint, "setPixelFormat:", format);
}

// -setBlendingEnabled:.
fn void RenderPipelineColorAttachmentDescriptor.set_blending_enabled(self, bool enabled)
{
	objc::msg_send(self, MsgVoidBool, "setBlendingEnabled:", enabled);
}

// -setSourceRGBBlendFactor:.
fn void RenderPipelineColorAttachmentDescriptor.set_source_rgb_blend_factor(self, BlendFactor factor)
{
	objc::msg_send(self, MsgVoidUint, "setSourceRGBBlendFactor:", factor);
}

// -setDestinationRGBBlendFactor:.
fn void RenderPipelineColorAttachmentDescriptor.set_destination_rgb_blend_factor(self, BlendFactor factor)
{
	objc::msg_send(self, MsgVoidUint, "setDestinationRGBBlendFactor:", factor);
}

// -setRgbBlendOperation:.
fn void RenderPipelineColorAttachmentDescriptor.set_rgb_blend_operation(self, BlendOperation operation)
{
	objc::msg_send(self, MsgVoidUint, "setRgbBlendOperation:", operation);
}

// -setSourceAlphaBlendFactor:.
fn void RenderPipelineColorAttachmentDescriptor.set_source_alpha_blend_factor(self, BlendFactor factor)
{
	objc::msg_send(self, MsgVoidUint, "setSourceAlphaBlendFactor:", factor);
}

// -setDestinationAlphaBlendFactor:.
fn void RenderPipelineColorAttachmentDescriptor.set_destination_alpha_blend_factor(self, BlendFactor factor)
{
	objc::msg_send(self, MsgVoidUint, "setDestinationAlphaBlendFactor:", factor);
}

// -setAlphaBlendOperation:.
fn void RenderPipelineColorAttachmentDescriptor.set_alpha_blend_operation(self, BlendOperation operation)
{
	objc::msg_send(self, MsgVoidUint, "setAlphaBlendOperation:", operation);
}

// -setWriteMask:.
fn void RenderPipelineColorAttachmentDescriptor.set_write_mask(self, ColorWriteMask mask)
{
	objc::msg_send(self, MsgVoidUint, "setWriteMask:", (NSUInteger)mask);
}

// -- Render pass -----------------------------------------------------------

typedef RenderPassDescriptor @constinit = inline void*;

fn void RenderPassDescriptor.retain(self) => retain(self);
fn void RenderPassDescriptor.release(self) => objc::release(self);

// +[MTLRenderPassDescriptor renderPassDescriptor] (autoreleased).
fn RenderPassDescriptor render_pass_descriptor() => @class_msg_object(RenderPassDescriptor, "MTLRenderPassDescriptor", "renderPassDescriptor");

// -colorAttachments (autoreleased array).
fn RenderPassColorAttachmentDescriptorArray RenderPassDescriptor.color_attachments(self)
{
	return (RenderPassColorAttachmentDescriptorArray)objc::msg_send(self, MsgId, "colorAttachments");
}

// -depthAttachment (autoreleased).
fn RenderPassDepthAttachmentDescriptor RenderPassDescriptor.depth_attachment(self)
{
	return (RenderPassDepthAttachmentDescriptor)objc::msg_send(self, MsgId, "depthAttachment");
}

// -stencilAttachment (autoreleased).
fn RenderPassStencilAttachmentDescriptor RenderPassDescriptor.stencil_attachment(self)
{
	return (RenderPassStencilAttachmentDescriptor)objc::msg_send(self, MsgId, "stencilAttachment");
}

typedef RenderPassDepthAttachmentDescriptor @constinit = inline void*;

fn void RenderPassDepthAttachmentDescriptor.set_texture(self, Texture texture) => objc::msg_send(self, MsgVoidId, "setTexture:", texture);

fn void RenderPassDepthAttachmentDescriptor.set_load_action(self, LoadAction action)
{
	objc::msg_send(self, MsgVoidUint, "setLoadAction:", action);
}

fn void RenderPassDepthAttachmentDescriptor.set_store_action(self, StoreAction action)
{
	objc::msg_send(self, MsgVoidUint, "setStoreAction:", action);
}

fn void RenderPassDepthAttachmentDescriptor.set_clear_depth(self, double depth)
{
	objc::msg_send(self, MsgVoidDouble, "setClearDepth:", depth);
}

typedef RenderPassStencilAttachmentDescriptor @constinit = inline void*;

fn void RenderPassStencilAttachmentDescriptor.set_texture(self, Texture texture) => objc::msg_send(self, MsgVoidId, "setTexture:", texture);

fn void RenderPassStencilAttachmentDescriptor.set_load_action(self, LoadAction action)
{
	objc::msg_send(self, MsgVoidUint, "setLoadAction:", action);
}

fn void RenderPassStencilAttachmentDescriptor.set_store_action(self, StoreAction action)
{
	objc::msg_send(self, MsgVoidUint, "setStoreAction:", action);
}

fn void RenderPassStencilAttachmentDescriptor.set_clear_stencil(self, uint value)
{
	objc::msg_send(self, MsgVoidUint, "setClearStencil:", (NSUInteger)value);
}

typedef RenderPassColorAttachmentDescriptorArray @constinit = inline void*;

// -objectAtIndexedSubscript:.
fn RenderPassColorAttachmentDescriptor RenderPassColorAttachmentDescriptorArray.object(self, NSUInteger index)
{
	return (RenderPassColorAttachmentDescriptor)objc::msg_send(self, MsgIdUint, "objectAtIndexedSubscript:", index);
}

typedef RenderPassColorAttachmentDescriptor @constinit = inline void*;

fn void RenderPassColorAttachmentDescriptor.set_texture(self, Texture texture) => objc::msg_send(self, MsgVoidId, "setTexture:", texture);

fn void RenderPassColorAttachmentDescriptor.set_load_action(self, LoadAction action)
{
	objc::msg_send(self, MsgVoidUint, "setLoadAction:", action);
}

fn void RenderPassColorAttachmentDescriptor.set_store_action(self, StoreAction action)
{
	objc::msg_send(self, MsgVoidUint, "setStoreAction:", action);
}

fn void RenderPassColorAttachmentDescriptor.set_clear_color(self, ClearColor color)
{
	objc::msg_send(self, MsgVoidClearColor, "setClearColor:", color);
}

// -- MTLTextureDescriptor --------------------------------------------------

typedef TextureDescriptor @constinit = inline void*;

fn void TextureDescriptor.retain(self) => retain(self);
fn void TextureDescriptor.release(self) => objc::release(self);

// [[MTLTextureDescriptor alloc] init]. Owned by the caller.
fn TextureDescriptor new_texture_descriptor() => @alloc_init(TextureDescriptor, "MTLTextureDescriptor");

// +[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:width:height:mipmapped:]
// (autoreleased).
fn TextureDescriptor texture_2d_descriptor(PixelFormat format, NSUInteger width, NSUInteger height, bool mipmapped)
{
	return (TextureDescriptor)objc::msg_send(class_named("MTLTextureDescriptor"), MsgIdUintUintUintBool, "texture2DDescriptorWithPixelFormat:width:height:mipmapped:", format, width, height, mipmapped);
}

fn void TextureDescriptor.set_texture_type(self, TextureType texture_type)
{
	objc::msg_send(self, MsgVoidUint, "setTextureType:", texture_type);
}

fn void TextureDescriptor.set_pixel_format(self, PixelFormat format) => objc::msg_send(self, MsgVoidUint, "setPixelFormat:", format);

fn void TextureDescriptor.set_width(self, NSUInteger width) => objc::msg_send(self, MsgVoidUint, "setWidth:", width);

fn void TextureDescriptor.set_height(self, NSUInteger height) => objc::msg_send(self, MsgVoidUint, "setHeight:", height);

fn void TextureDescriptor.set_depth(self, NSUInteger depth) => objc::msg_send(self, MsgVoidUint, "setDepth:", depth);

fn void TextureDescriptor.set_array_length(self, NSUInteger length) => objc::msg_send(self, MsgVoidUint, "setArrayLength:", length);

fn void TextureDescriptor.set_mipmap_level_count(self, NSUInteger count)
{
	objc::msg_send(self, MsgVoidUint, "setMipmapLevelCount:", count);
}

fn void TextureDescriptor.set_sample_count(self, NSUInteger count) => objc::msg_send(self, MsgVoidUint, "setSampleCount:", count);

fn void TextureDescriptor.set_usage(self, TextureUsage usage) => objc::msg_send(self, MsgVoidUint, "setUsage:", (NSUInteger)usage);

fn void TextureDescriptor.set_resource_options(self, ResourceOptions options)
{
	objc::msg_send(self, MsgVoidUint, "setResourceOptions:", (NSUInteger)options);
}

fn void TextureDescriptor.set_cpu_cache_mode(self, CPUCacheMode mode) => objc::msg_send(self, MsgVoidUint, "setCpuCacheMode:", mode);

fn void TextureDescriptor.set_storage_mode(self, StorageMode mode) => objc::msg_send(self, MsgVoidUint, "setStorageMode:", mode);

fn void TextureDescriptor.set_hazard_tracking_mode(self, HazardTrackingMode mode)
{
	objc::msg_send(self, MsgVoidUint, "setHazardTrackingMode:", mode);
}

// -- MTLSamplerDescriptor --------------------------------------------------

typedef SamplerDescriptor @constinit = inline void*;

fn void SamplerDescriptor.retain(self) => retain(self);
fn void SamplerDescriptor.release(self) => objc::release(self);

// [[MTLSamplerDescriptor alloc] init]. Owned by the caller.
fn SamplerDescriptor new_sampler_descriptor() => @alloc_init(SamplerDescriptor, "MTLSamplerDescriptor");

fn void SamplerDescriptor.set_min_filter(self, SamplerMinMagFilter filter) => objc::msg_send(self, MsgVoidUint, "setMinFilter:", filter);

fn void SamplerDescriptor.set_mag_filter(self, SamplerMinMagFilter filter) => objc::msg_send(self, MsgVoidUint, "setMagFilter:", filter);

fn void SamplerDescriptor.set_mip_filter(self, SamplerMipFilter filter) => objc::msg_send(self, MsgVoidUint, "setMipFilter:", filter);

fn void SamplerDescriptor.set_s_address_mode(self, SamplerAddressMode mode)
{
	objc::msg_send(self, MsgVoidUint, "setSAddressMode:", mode);
}

fn void SamplerDescriptor.set_t_address_mode(self, SamplerAddressMode mode)
{
	objc::msg_send(self, MsgVoidUint, "setTAddressMode:", mode);
}

fn void SamplerDescriptor.set_r_address_mode(self, SamplerAddressMode mode)
{
	objc::msg_send(self, MsgVoidUint, "setRAddressMode:", mode);
}

fn void SamplerDescriptor.set_max_anisotropy(self, NSUInteger anisotropy)
{
	objc::msg_send(self, MsgVoidUint, "setMaxAnisotropy:", anisotropy);
}

fn void SamplerDescriptor.set_compare_function(self, CompareFunction func)
{
	objc::msg_send(self, MsgVoidUint, "setCompareFunction:", func);
}

fn void SamplerDescriptor.set_lod_min_clamp(self, float clamp) => objc::msg_send(self, MsgVoidFloat, "setLodMinClamp:", clamp);

fn void SamplerDescriptor.set_lod_max_clamp(self, float clamp) => objc::msg_send(self, MsgVoidFloat, "setLodMaxClamp:", clamp);

fn void SamplerDescriptor.set_border_color(self, SamplerBorderColor color)
{
	objc::msg_send(self, MsgVoidUint, "setBorderColor:", color);
}

fn void SamplerDescriptor.set_normalized_coordinates(self, bool normalized)
{
	objc::msg_send(self, MsgVoidBool, "setNormalizedCoordinates:", normalized);
}

// -setSupportArgumentBuffers: — required to put the sampler in an argument
// buffer.
fn void SamplerDescriptor.set_support_argument_buffers(self, bool support)
{
	objc::msg_send(self, MsgVoidBool, "setSupportArgumentBuffers:", support);
}

// -- MTLDepthStencilDescriptor ---------------------------------------------

typedef DepthStencilDescriptor @constinit = inline void*;

fn void DepthStencilDescriptor.retain(self) => retain(self);
fn void DepthStencilDescriptor.release(self) => objc::release(self);

// [[MTLDepthStencilDescriptor alloc] init]. Owned by the caller.
fn DepthStencilDescriptor new_depth_stencil_descriptor() => @alloc_init(DepthStencilDescriptor, "MTLDepthStencilDescriptor");

fn void DepthStencilDescriptor.set_depth_compare_function(self, CompareFunction func)
{
	objc::msg_send(self, MsgVoidUint, "setDepthCompareFunction:", func);
}

fn void DepthStencilDescriptor.set_depth_write_enabled(self, bool enabled)
{
	objc::msg_send(self, MsgVoidBool, "setDepthWriteEnabled:", enabled);
}

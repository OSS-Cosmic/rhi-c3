// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Backend-neutral queue handle. Port of rhi-zig's `queue.zig`. A submit is
// described by `QueueSubmitDesc` (modeled on HPL2's `RISubmitDesc`): the
// command buffers, timeline waits/signals, Vulkan-only binary semaphores for
// swapchain acquire/present, and an optional ring element to stamp.
// WebGPU and WebGL2 expose a single ordered graphics queue.
module rhi;

struct Queue
{
	union backend
	{
		QueueVk vk;
		QueueWgpu wgpu;
		QueueWebgl webgl;
		QueueDx12 dx12;
		QueueMtl mtl;
	}
}

fn void? queue_wait_idle(Queue* q, Device* device)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return queue_wait_idle_vk(q, device);
			$endif
		case DX12:
			$if HAS_DX12:
				return queue_wait_idle_dx12(q, device);
			$endif
		case MTL:
			$if HAS_MTL:
				return queue_wait_idle_mtl(q, device);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return queue_wait_idle_wgpu(q, device);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return queue_wait_idle_webgl(q, device);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

struct TimelineOp
{
	Timeline* timeline;
	ulong value;          // from timeline_next
	BarrierStages stages; // empty => all commands; ignored by D3D12/web
}

struct QueueSubmitDesc
{
	Cmd*[] cmds;
	TimelineOp[] waits;
	TimelineOp[] signals;
	// Vulkan swapchain acquire/present still needs binary semaphores; other
	// backends must receive these empty (assert).
	Semaphore*[] binary_waits;
	// Wait stage per binary_waits entry, by index. Missing entries (a
	// shorter or empty slice) and empty sets mean all commands.
	BarrierStages[] binary_wait_stages;
	Semaphore*[] binary_signals;
	CommandRingElement* completion; // nullable; stamped after a successful submit
}

fn void? queue_submit(Queue* q, Device* device, QueueSubmitDesc desc)
{
	switch (renderer.backend)
	{
		case VK:
			$if HAS_VK:
				return queue_submit_vk(q, device, desc);
			$endif
		case DX12:
			$if HAS_DX12:
				return queue_submit_dx12(q, device, desc);
			$endif
		case MTL:
			$if HAS_MTL:
				return queue_submit_mtl(q, device, desc);
			$endif
		case WGPU:
			$if HAS_WGPU:
				return queue_submit_wgpu(q, device, desc);
			$endif
		case WEBGL:
			$if HAS_WEBGL:
				return queue_submit_webgl(q, device, desc);
			$endif
	}
	return UNSUPPORTED_BACKEND~;
}

// ---- metal ----

// Metal queue. Port of the `.mtl` arm of rhi-zig's `queue.zig`, with submit
// following `QueueSubmitDesc` the way the D3D12 backend does.
//
// CmdMtl and CommandRingElementMtl are defined by the command and ring
// backends. The queue only owns submission-side shared-event state.
module rhi @feat(RHI_MTL & DARWIN & !RHI_HEADLESS);
import std::os::macos::objc;
import std::thread, std::time;
import mtl;

struct QueueMtl
{
	// Borrowed from `DeviceMtl`.
	mtl::CommandQueue queue;
	// Owned (released by device_deinit_mtl). Signalled with
	// `completion_value` by every submit that carries a completion element.
	mtl::SharedEvent completion_event;
	ulong completion_value;
}

// Blocks until `event` reaches `value`. MTLSharedEvent has no blocking CPU
// wait short of a MTLSharedEventListener block callback, so poll.
fn void mtl_shared_event_wait(mtl::SharedEvent event, ulong value)
{
	if (!event || value == 0) return;
	while (event.signaled_value() < value) thread::sleep(100 * time::US);
}

// Commits a fresh command buffer and waits for it. Buffers on one queue run
// in commit order, so this drains everything committed before it. rhi-zig
// made this a no-op; this is a real wait.
fn void? queue_wait_idle_mtl(Queue* q, Device* device)
{
	mtl::CommandQueue queue = q.backend.mtl.queue;
	if (!queue) return UNKNOWN~;
	objc::@autoreleasepool()
	{
		mtl::CommandBuffer command_buffer = queue.command_buffer();
		if (!command_buffer) return UNKNOWN~;
		command_buffer.commit();
		command_buffer.wait_until_completed();
	};
}

// Commits each Cmd's command buffer in order. An event wait only holds back
// the passes encoded after it, and the Cmds are already recorded, so timeline
// waits go into a leading carrier command buffer committed first (MoltenVK
// does the same). Signals and the completion stamp go on the last buffer.
// With no Cmds the carrier alone carries waits and signals.
// Shared submit path. A drawable is optional so swapchain submission can
// schedule presentation on the last command buffer before anything commits,
// while ordinary queue_submit keeps its existing behavior.
fn void? queue_submit_mtl_internal(Queue* q, Device* device, QueueSubmitDesc desc, mtl::CAMetalDrawable present_drawable)
{
	assert(desc.binary_waits.len == 0 && desc.binary_signals.len == 0, "Metal: binary semaphores are Vulkan-only");
	QueueMtl* state = &q.backend.mtl;
	if (!state.queue) return UNKNOWN~;
	foreach (c : desc.cmds)
	{
		if (!c.backend.mtl.command_buffer) return UNKNOWN~;
	}

	objc::@autoreleasepool()
	{
		mtl::CommandBuffer carrier = null;
		if (desc.waits.len > 0 || desc.cmds.len == 0)
		{
			carrier = state.queue.command_buffer();
			if (!carrier) return UNKNOWN~;
		}
		foreach (op : desc.waits)
		{
			carrier.encode_wait_for_event(op.timeline.backend.mtl.event, op.value);
		}

		mtl::CommandBuffer last = desc.cmds.len > 0 ? desc.cmds[^1].backend.mtl.command_buffer : carrier;
		foreach (op : desc.signals)
		{
			last.encode_signal_event(op.timeline.backend.mtl.event, op.value);
		}
		ulong stamped_value = 0;
		if (desc.completion && state.completion_event)
		{
			stamped_value = ++state.completion_value;
			last.encode_signal_event(state.completion_event, stamped_value);
		}
		if (present_drawable) last.present_drawable(present_drawable.id());

		if (carrier) carrier.commit();
		foreach (c : desc.cmds) c.backend.mtl.command_buffer.commit();

		// command_ring_element_wait_mtl waits on the element.
		if (stamped_value != 0)
		{
			desc.completion.backend.mtl = { .event = state.completion_event, .value = stamped_value };
		}
	};
}

fn void? queue_submit_mtl(Queue* q, Device* device, QueueSubmitDesc desc)
{
	return queue_submit_mtl_internal(q, device, desc, null);
}

// Used only by the Metal swapchain: presentation must be encoded before the
// command buffer is committed, while retaining normal timeline and ring
// completion stamping.
fn void? queue_submit_mtl_present(Queue* q, Device* device, QueueSubmitDesc desc, mtl::CAMetalDrawable drawable)
{
	return queue_submit_mtl_internal(q, device, desc, drawable);
}

// ---- dx12 ----

// Direct3D 12 queue. Port of the `.dx12` arm of rhi-zig's `queue.zig`, with
// submit following `QueueSubmitDesc`: timeline waits go to ID3D12CommandQueue::Wait,
// the command lists to ExecuteCommandLists, then timeline signals to Signal.
//
// CmdDx12 and CommandRingElementDx12 are defined by the command and ring
// backends. The queue only owns idle-wait state.
module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
import d3d12, dxgi;

struct QueueDx12
{
	// Owned (released by device_deinit_dx12).
	d3d12::CommandQueue* queue;
	// Owned. Signalled with `completion_value` by queue_wait_idle_dx12 and by
	// every submit that carries a completion element.
	d3d12::Fence* completion_fence;
	dxgi::Handle completion_event;
	ulong completion_value;
}

fn QueueDx12? dx12_queue_create(d3d12::Device* dev, d3d12::CommandListType type)
{
	d3d12::CommandQueueDesc desc = {
		.type = type,
		.priority = 0,
		.flags = d3d12::COMMAND_QUEUE_FLAG_NONE,
		.node_mask = 0,
	};
	Guid iid_queue = d3d12::IID_COMMAND_QUEUE;
	d3d12::CommandQueue* queue;
	dx12_check(dev.vtbl.create_command_queue(dev, &desc, &iid_queue, (void**)&queue))!;

	Guid iid_fence = d3d12::IID_FENCE;
	d3d12::Fence* fence;
	if (dxgi::failed(dev.vtbl.create_fence(dev, 0, d3d12::FenceFlags.NONE, &iid_fence, (void**)&fence)))
	{
		dxgi::release(queue);
		return INITIALIZATION_FAILED~;
	}
	dxgi::Handle event = d3d12::create_event_w(null, 0, 0, null);
	if (!event)
	{
		dxgi::release(fence);
		dxgi::release(queue);
		return INITIALIZATION_FAILED~;
	}
	return { .queue = queue, .completion_fence = fence, .completion_event = event };
}

fn void dx12_queue_destroy(QueueDx12* q)
{
	dx12_fence_destroy(q.completion_fence, q.completion_event);
	if (q.queue) dxgi::release(q.queue);
	*q = {};
}

// Signals the completion fence behind everything already submitted and
// returns the value it will reach.
fn ulong? dx12_queue_signal_completion(QueueDx12* state)
{
	ulong value = ++state.completion_value;
	dx12_check(state.queue.vtbl.signal(state.queue, state.completion_fence, value))!;
	return value;
}

fn void? queue_wait_idle_dx12(Queue* q, Device* device)
{
	QueueDx12* state = &q.backend.dx12;
	if (!state.queue) return UNKNOWN~;
	ulong value = dx12_queue_signal_completion(state)!;
	dx12_fence_wait(state.completion_fence, state.completion_event, value)!;
}

fn void? queue_submit_dx12(Queue* q, Device* device, QueueSubmitDesc desc)
{
	assert(desc.binary_waits.len == 0 && desc.binary_signals.len == 0, "D3D12: binary semaphores are Vulkan-only");
	QueueDx12* state = &q.backend.dx12;
	if (!state.queue) return UNKNOWN~;

	foreach (op : desc.waits)
	{
		dx12_check(state.queue.vtbl.wait(state.queue, op.timeline.backend.dx12.fence, op.value))!;
	}

	if (desc.cmds.len > 0)
	{
		// Each cmd's list was closed by `cmd_end_dx12`.
		d3d12::CommandList*[] lists = mem::talloc_array(d3d12::CommandList*, desc.cmds.len);
		foreach (i, c : desc.cmds) lists[i] = (d3d12::CommandList*)c.backend.dx12.list;
		state.queue.vtbl.execute_command_lists(state.queue, (uint)lists.len, lists.ptr);
	}

	foreach (op : desc.signals)
	{
		dx12_check(state.queue.vtbl.signal(state.queue, op.timeline.backend.dx12.fence, op.value))!;
	}

	if (desc.completion)
	{
		ulong value = dx12_queue_signal_completion(state)!;
		desc.completion.backend.dx12 = {
			.fence = state.completion_fence,
			.event = state.completion_event,
			.value = value,
		};
	}
}

// ---- vulkan ----

// Vulkan queue. Vulkan queue section.
//
// `CommandRingElementVk` is defined with the Vulkan command ring. CmdVk is
// defined with the command code.
module rhi @feat(RHI_VK & !RHI_HEADLESS & !WASM & (LINUX | WIN32));
import vk;

struct QueueVk
{
	vk::QueueFlags queue_flags;
	uint family_index;
	uint slot_index;
	vk::Queue queue;
}

fn void? queue_wait_idle_vk(Queue* q, Device* device)
{
	return vk_check(device.backend.vk.vtable.queueWaitIdle(q.backend.vk.queue));
}

// Submit-time stage scope for a timeline op. Unlike barriers there is no
// resource state to derive from, so an empty set means all commands.
fn vk::PipelineStageFlags2 vk_submit_stage_mask(BarrierStages stages)
{
	if ((ushort)stages == 0) return vk::PIPELINE_STAGE_2_ALL_COMMANDS_BIT;
	vk::PipelineStageFlags2 flags;
	if (stages.vertex) flags |= vk::PIPELINE_STAGE_2_VERTEX_SHADER_BIT;
	if (stages.fragment) flags |= vk::PIPELINE_STAGE_2_FRAGMENT_SHADER_BIT;
	if (stages.compute) flags |= vk::PIPELINE_STAGE_2_COMPUTE_SHADER_BIT;
	if (stages.ray_tracing) flags |= vk::PIPELINE_STAGE_2_RAY_TRACING_SHADER_BIT_KHR;
	if (stages.draw_indirect) flags |= vk::PIPELINE_STAGE_2_DRAW_INDIRECT_BIT;
	if (stages.copy) flags |= vk::PIPELINE_STAGE_2_COPY_BIT;
	if (stages.blit) flags |= vk::PIPELINE_STAGE_2_BLIT_BIT;
	if (stages.clear) flags |= vk::PIPELINE_STAGE_2_CLEAR_BIT;
	if (stages.accel_build) flags |= vk::PIPELINE_STAGE_2_ACCELERATION_STRUCTURE_BUILD_BIT_KHR;
	if (stages.color_attachment) flags |= vk::PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT;
	if (stages.host) flags |= vk::PIPELINE_STAGE_2_HOST_BIT;
	return flags;
}

// `fallback_fence` is internal (swapchain frame submit): signalled by this
// submit when `desc.completion` carries no fence. The caller resets it.
fn void? queue_submit_vk(Queue* q, Device* device, QueueSubmitDesc desc, vk::Fence fallback_fence = 0) => @pool()
{
	vk::DeviceVTable* vtable = &device.backend.vk.vtable;

	vk::CommandBufferSubmitInfo[] cbs = mem::temp_array(vk::CommandBufferSubmitInfo, desc.cmds.len);
	foreach (i, c : desc.cmds)
	{
		cbs[i] = { .sType = COMMAND_BUFFER_SUBMIT_INFO, .commandBuffer = c.backend.vk.cmd };
	}

	vk::SemaphoreSubmitInfo[] waits = mem::temp_array(vk::SemaphoreSubmitInfo, desc.waits.len + desc.binary_waits.len);
	foreach (i, op : desc.waits)
	{
		waits[i] = {
			.sType = SEMAPHORE_SUBMIT_INFO,
			.semaphore = op.timeline.backend.vk.semaphore,
			.value = op.value,
			.stageMask = vk_submit_stage_mask(op.stages),
		};
	}
	foreach (i, s : desc.binary_waits)
	{
		BarrierStages stages = i < desc.binary_wait_stages.len ? desc.binary_wait_stages[i] : {};
		waits[desc.waits.len + i] = {
			.sType = SEMAPHORE_SUBMIT_INFO,
			.semaphore = s.backend.vk.semaphore,
			.stageMask = vk_submit_stage_mask(stages),
		};
	}

	vk::SemaphoreSubmitInfo[] signals = mem::temp_array(vk::SemaphoreSubmitInfo, desc.signals.len + desc.binary_signals.len);
	foreach (i, op : desc.signals)
	{
		signals[i] = {
			.sType = SEMAPHORE_SUBMIT_INFO,
			.semaphore = op.timeline.backend.vk.semaphore,
			.value = op.value,
			.stageMask = vk_submit_stage_mask(op.stages),
		};
	}
	foreach (i, s : desc.binary_signals)
	{
		signals[desc.signals.len + i] = {
			.sType = SEMAPHORE_SUBMIT_INFO,
			.semaphore = s.backend.vk.semaphore,
			.stageMask = vk::PIPELINE_STAGE_2_ALL_COMMANDS_BIT,
		};
	}

	vk::SubmitInfo2 submit_info = {
		.sType = SUBMIT_INFO_2,
		.waitSemaphoreInfoCount = (uint)waits.len,
		.pWaitSemaphoreInfos = waits.len > 0 ? waits.ptr : null,
		.commandBufferInfoCount = (uint)cbs.len,
		.pCommandBufferInfos = cbs.len > 0 ? cbs.ptr : null,
		.signalSemaphoreInfoCount = (uint)signals.len,
		.pSignalSemaphoreInfos = signals.len > 0 ? signals.ptr : null,
	};

	// Ring fences are created signaled, so the completion fence is reset here
	// and re-signaled by this submit; command_ring_element_wait_vk waits on it.
	vk::Fence fence = fallback_fence;
	if (desc.completion && desc.completion.backend.vk.fence != 0)
	{
		fence = desc.completion.backend.vk.fence;
		vk_check(vtable.resetFences(device.backend.vk.device, 1, &fence))!;
	}
	return vk_check(vtable.queueSubmit2(q.backend.vk.queue, 1, &submit_info, fence));
}

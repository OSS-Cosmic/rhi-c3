// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Vulkan queue. Port of the `---- queue ----` section of rhi/vulkan.odin.
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

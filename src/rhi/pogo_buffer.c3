// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// Two-image ping-pong target. Port of HPL2's `RIPogoBuffer`: one half is the
// color attachment while the other is sampled, and `pogo_toggle` swaps them.
module rhi;

struct PogoBuffer
{
	Image[2] images;
	// Sampled (shader-resource) view of each half.
	ImageView[2] pogo_view;
	// Color-attachment view of each half. D3D12 needs an RTV-type view to
	// render into; the sampled view is rejected by begin rendering.
	ImageView[2] attachment_view;
	ushort attachment_index;
}

// Index of the half that becomes the attachment after a toggle.
fn ushort pogo_next_index(ushort index)
{
	return (index + 1) % 2;
}

// Hand-off transition: pogo attachment -> fragment-sampled resource.
// `initial` treats the contents as discarded (UNDEFINED source).
fn ImageBarrier pogo_shader_barrier(Image* image, bool initial)
{
	return {
		.image = image,
		.before = initial ? (ResourceState){} : (ResourceState){ .render_target = true },
		.after = { .shader_resource = true },
		.after_stages = { .fragment = true },
	};
}

// Reuse transition: fragment-sampled resource -> pogo attachment.
// `initial` treats the contents as discarded (UNDEFINED source).
fn ImageBarrier pogo_attachment_barrier(Image* image, bool initial)
{
	return {
		.image = image,
		.before = initial ? (ResourceState){} : (ResourceState){ .shader_resource = true },
		.before_stages = initial ? (BarrierStages){} : (BarrierStages){ .fragment = true },
		.after = { .render_target = true },
	};
}

// Rebuilds both halves; any previous halves are released first.
fn void? pogo_init(PogoBuffer* pogo, Device* device, uint width, uint height, Format format)
{
	pogo_deinit(pogo, device);
	pogo.attachment_index = 0;

	ImageDesc desc = {
		.image_type = D2,
		.format = format,
		.width = width,
		.height = height,
		.depth = 1,
		.mip_levels = 1,
		.array_layers = 1,
		.samples = S1,
		.tiling = OPTIMAL,
		// Storage lets compute passes write the attachment; transfer src/dst
		// back blit-based crops.
		.usage = { .transfer_src = true, .transfer_dst = true, .sampled = true, .storage = true, .color_attachment = true },
		.memory_usage = PREFER_DEVICE,
	};
	ViewDesc view_desc = {
		.view_type = SHADER_RESOURCE_2D,
		.format = format,
		.aspect = COLOR,
		.mip_num = 1,
		.layer_num = 1,
	};

	// Release partial state if any step fails.
	bool ok = false;
	defer if (!ok) pogo_deinit(pogo, device);
	for (usz p = 0; p < 2; p++)
	{
		pogo.images[p] = image_init(device, desc)!;
		view_desc.view_type = SHADER_RESOURCE_2D;
		pogo.pogo_view[p] = image_view_init(device, &pogo.images[p], view_desc)!;
		view_desc.view_type = COLOR_ATTACHMENT;
		pogo.attachment_view[p] = image_view_init(device, &pogo.images[p], view_desc)!;
	}
	ok = true;
}

// Idempotent: the deinit calls skip empty handles.
fn void pogo_deinit(PogoBuffer* pogo, Device* device)
{
	for (usz p = 0; p < 2; p++)
	{
		image_view_deinit(&pogo.pogo_view[p], device);
		image_view_deinit(&pogo.attachment_view[p], device);
		image_deinit(&pogo.images[p], device);
	}
}

// Hands the current attachment off to sampling and makes the other half the
// attachment.
fn void pogo_toggle(PogoBuffer* pogo, Cmd* c, Device* device)
{
	ImageBarrier[2] barriers;
	barriers[0] = pogo_shader_barrier(&pogo.images[pogo.attachment_index], false);
	pogo.attachment_index = pogo_next_index(pogo.attachment_index);
	barriers[1] = pogo_attachment_barrier(&pogo.images[pogo.attachment_index], false);
	cmd_resource_barrier(c, device, images: barriers[..]);
}

// The half currently being rendered into.
fn Descriptor pogo_attachment(PogoBuffer* pogo)
{
	return descriptor_sampled_image(&pogo.pogo_view[pogo.attachment_index]);
}

// The half that holds the previous pass's output.
fn Descriptor pogo_shader_resource(PogoBuffer* pogo)
{
	return descriptor_sampled_image(&pogo.pogo_view[pogo_next_index(pogo.attachment_index)]);
}

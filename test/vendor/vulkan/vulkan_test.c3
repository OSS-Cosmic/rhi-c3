// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module vk;
import std::core::test, std::io, libc;

// Sizes, alignments and offsets below were obtained on x86_64 Linux
// (Linux 7.0.0, Ubuntu cc 15.2.0) against the system headers
// /usr/include/vulkan/vulkan.h (VK_HEADER_VERSION 341, the same registry the
// bindings were generated from) with this program:
//
//   #include <stdio.h>
//   #include <stddef.h>
//   #include <vulkan/vulkan.h>
//   #define S(T) printf("%s size %zu align %zu\n", #T, sizeof(Vk##T), _Alignof(Vk##T))
//   #define O(T, f) printf("%s.%s %zu\n", #T, #f, offsetof(Vk##T, f))
//   int main(void) { S(ImageCreateInfo); O(ImageCreateInfo, extent); ... }
//
// compiled with `cc -std=c11 -o sizes sizes.c && ./sizes`. While writing the
// generator the same comparison was run for all 1125 structs and unions of
// vulkan_core.h (plus the Xlib and Wayland surface infos); all matched.
// `Type::size` is bound to a local first: passed straight to test::eq it
// fails eq's `values must be equatable` contract in c3c 0.8.4.
macro void @check_layout($Type, usz size, usz align)
{
	usz actual_size = $Type::size;
	usz actual_align = $Type::alignment;
	test::eq(actual_size, size);
	test::eq(actual_align, align);
}

macro void @check_offset(#field, usz offset)
{
	usz actual = $reflect(#field).offset;
	test::eq(actual, offset);
}

fn void struct_layout_matches_c() @test
{
	@check_layout(ImageCreateInfo, 88, 8);
	@check_layout(PhysicalDeviceProperties, 824, 8);
	@check_layout(PhysicalDeviceLimits, 504, 8);
	@check_layout(RenderingInfo, 72, 8);
	@check_layout(ImageMemoryBarrier2, 96, 8);
	@check_layout(DebugUtilsMessengerCallbackDataEXT, 96, 8);
	@check_layout(SwapchainCreateInfoKHR, 104, 8);
	@check_layout(PhysicalDeviceVulkan13Features, 80, 8);
	@check_layout(WriteDescriptorSet, 64, 8);
	@check_layout(AccelerationStructureInstanceKHR, 64, 8);
	@check_layout(AccelerationStructureSRTMotionInstanceNV, 144, 8);
	@check_layout(AccelerationStructureMotionInstanceNV, 152, 8);
	@check_layout(TransformMatrixKHR, 48, 4);
	@check_layout(ClearValue, 16, 4);
	@check_layout(ClearColorValue, 16, 4);
	@check_layout(BufferCreateInfo, 56, 8);
	@check_layout(AllocationCallbacks, 48, 8);
}

fn void field_offsets_match_c() @test
{
	@check_offset(ImageCreateInfo.extent, 28);
	@check_offset(ImageCreateInfo.usage, 56);
	@check_offset(ImageCreateInfo.initialLayout, 80);
	@check_offset(PhysicalDeviceProperties.limits, 296);
	@check_offset(PhysicalDeviceProperties.sparseProperties, 800);
	@check_offset(PhysicalDeviceLimits.nonCoherentAtomSize, 496);
	@check_offset(RenderingInfo.pStencilAttachment, 64);
	@check_offset(WriteDescriptorSet.pTexelBufferView, 56);
	@check_offset(AccelerationStructureInstanceKHR.accelerationStructureReference, 56);
	@check_offset(PhysicalDeviceVulkan13Features.maintenance4, 72);
	@check_offset(SwapchainCreateInfoKHR.oldSwapchain, 96);
}

// The C bitfields `instanceCustomIndex:24; mask:8` share one uint, low bits first.
fn void acceleration_structure_instance_bitfields() @test
{
	AccelerationStructureInstanceKHR inst;
	inst.instanceCustomIndex = 0xABCDEF;
	inst.mask = 0x12;
	inst.instanceShaderBindingTableRecordOffset = 7;
	inst.flags = GEOMETRY_INSTANCE_TRIANGLE_FACING_CULL_DISABLE_BIT_KHR;
	uint* words = (uint*)((char*)&inst + TransformMatrixKHR::size);
	test::eq(words[0], 0x12ABCDEFu);
	test::eq(words[1], 0x01000007u);
}

fn void constants_and_versions() @test
{
	test::eq(API_VERSION_1_3, (1u << 22) | (3u << 12));
	test::eq(@api_version_major(API_VERSION_1_4), 1u);
	test::eq(@api_version_minor(API_VERSION_1_4), 4u);
	test::eq(@make_version(1, 2, 3), (1u << 22) | (2u << 12) | 3u);
	test::eq(WHOLE_SIZE, ulong::max);
	test::eq(REMAINING_MIP_LEVELS, uint::max);
	test::eq(MAX_EXTENSION_NAME_SIZE, 256u);
	test::eq(KHR_SWAPCHAIN_EXTENSION_NAME.str_view(), "VK_KHR_swapchain");
	test::eq((int)Format.R8G8B8A8_UNORM, 37);
	test::eq((int)Result.ERROR_OUT_OF_DATE_KHR, -1000001004);
	test::eq((int)StructureType.SWAPCHAIN_CREATE_INFO_KHR, 1000001000);
	ImageAspectFlags aspect = IMAGE_ASPECT_COLOR_BIT | IMAGE_ASPECT_DEPTH_BIT;
	test::eq((uint)aspect, 3u);
	test::eq((ulong)PIPELINE_STAGE_2_ALL_COMMANDS_BIT, 0x10000ul);
}

// Loads libvulkan at run time (Linux only), queries the loader version and
// creates an instance and a device on the first physical device.
fn void runtime_smoke() @test
{
	$if env::LINUX:
		void* lib = libc::dlopen("libvulkan.so.1", libc::RTLD_NOW);
		if (!lib)
		{
			io::printn("libvulkan.so.1 not found, skipping the Vulkan smoke test");
			return;
		}
		defer libc::dlclose(lib);
		void* get_instance_proc_addr = libc::dlsym(lib, "vkGetInstanceProcAddr");
		test::@check(get_instance_proc_addr != null);
		load_proc_addresses_global(get_instance_proc_addr);
		test::@check(createInstance != null);

		uint version;
		test::eq(enumerateInstanceVersion(&version), Result.SUCCESS);
		test::@check(version >= API_VERSION_1_3, "loader version %s", version);

		ApplicationInfo app_info = {
			.sType = APPLICATION_INFO,
			.pApplicationName = "vk smoke test",
			.apiVersion = API_VERSION_1_3,
		};
		InstanceCreateInfo instance_info = {
			.sType = INSTANCE_CREATE_INFO,
			.pApplicationInfo = &app_info,
		};
		Instance instance;
		test::eq(createInstance(&instance_info, null, &instance), Result.SUCCESS);
		test::@check(instance != null);
		load_proc_addresses_instance(instance);
		defer destroyInstance(instance, null);

		uint count;
		test::eq(enumeratePhysicalDevices(instance, &count, null), Result.SUCCESS);
		if (count == 0) return;
		PhysicalDevice[16] devices;
		count = min(count, 16u);
		Result r = enumeratePhysicalDevices(instance, &count, &devices);
		test::@check(r == SUCCESS || r == INCOMPLETE);
		PhysicalDevice physical_device = devices[0];

		PhysicalDeviceProperties props;
		getPhysicalDeviceProperties(physical_device, &props);
		test::@check(props.apiVersion >= API_VERSION_1_0);
		test::@check(props.deviceName[0] != 0);

		float priority = 1.0f;
		DeviceQueueCreateInfo queue_info = {
			.sType = DEVICE_QUEUE_CREATE_INFO,
			.queueFamilyIndex = 0,
			.queueCount = 1,
			.pQueuePriorities = &priority,
		};
		DeviceCreateInfo device_info = {
			.sType = DEVICE_CREATE_INFO,
			.queueCreateInfoCount = 1,
			.pQueueCreateInfos = &queue_info,
		};
		Device device;
		test::eq(createDevice(physical_device, &device_info, null, &device), Result.SUCCESS);
		DeviceVTable vtable;
		load_proc_addresses_device_vtable(device, &vtable);
		defer vtable.destroyDevice(device, null);
		test::@check(vtable.cmdDraw != null);

		Queue queue;
		vtable.getDeviceQueue(device, 0, 0, &queue);
		test::@check(queue != null);

		BufferCreateInfo buffer_info = {
			.sType = BUFFER_CREATE_INFO,
			.size = 4096,
			.usage = BUFFER_USAGE_TRANSFER_SRC_BIT | BUFFER_USAGE_STORAGE_BUFFER_BIT,
			.sharingMode = EXCLUSIVE,
		};
		Buffer buffer;
		test::eq(vtable.createBuffer(device, &buffer_info, null, &buffer), Result.SUCCESS);
		test::@check(buffer != NULL_HANDLE);
		MemoryRequirements reqs;
		vtable.getBufferMemoryRequirements(device, buffer, &reqs);
		test::@check(reqs.size >= 4096);
		test::@check(reqs.memoryTypeBits != 0);
		vtable.destroyBuffer(device, buffer, null);
		test::eq(vtable.deviceWaitIdle(device), Result.SUCCESS);
	$endif
}

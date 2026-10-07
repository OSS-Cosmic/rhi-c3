// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

// C3 bindings for AMD's Vulkan Memory Allocator (VMA) v3.3.0, ported from
// the VMA C API. The matching header and implementation are vendored
// locally in c3/vendor/vma/include/vk_mem_alloc.h and
// c3/vendor/vma/vma_impl.cpp.
//
// The struct layouts below must match the C header byte-for-byte: every
// field the C++ side reads or writes has to line up, in order, with no gaps
// beyond natural alignment padding. Struct sizes are pinned down by
// c3/test/vendor/vma/vma_test.c3, which checks them against values obtained
// by compiling the real header (see that file for how).
//
// Conventions follow c3/src/vendor/vulkan/core.c3: handles are
// `typedef X @constinit = inline void*;`, enums are `constdef X : int`, and
// flags are `typedef XFlags @constinit = uint;` with one module constant per
// bit (the C name minus VMA_).
module vma;
import vk;

typedef Allocator @constinit = inline void*;
typedef Allocation @constinit = inline void*;
typedef Pool @constinit = inline void*;

// VmaMemoryUsage; sized to match the C enum (forced to `int` by
// VMA_MEMORY_USAGE_MAX_ENUM = 0x7FFFFFFF).
constdef MemoryUsage : int
{
	UNKNOWN              = 0,
	GPU_ONLY             = 1, // deprecated
	CPU_ONLY             = 2, // deprecated
	CPU_TO_GPU           = 3, // deprecated
	GPU_TO_CPU           = 4, // deprecated
	CPU_COPY             = 5, // deprecated
	GPU_LAZILY_ALLOCATED = 6,
	AUTO                 = 7,
	AUTO_PREFER_DEVICE   = 8,
	AUTO_PREFER_HOST     = 9,
}

// VmaAllocatorCreateFlagBits. The constants are the C bit masks.
typedef AllocatorCreateFlags @constinit = uint;
alias AllocatorCreateFlagBits = AllocatorCreateFlags;
const AllocatorCreateFlags ALLOCATOR_CREATE_AMD_DEVICE_COHERENT_MEMORY_BIT = 0x00000010;
const AllocatorCreateFlags ALLOCATOR_CREATE_BUFFER_DEVICE_ADDRESS_BIT      = 0x00000020;

// VmaAllocationCreateFlagBits (C bit masks, as above).
typedef AllocationCreateFlags @constinit = uint;
alias AllocationCreateFlagBits = AllocationCreateFlags;
const AllocationCreateFlags ALLOCATION_CREATE_MAPPED_BIT                             = 0x00000004;
const AllocationCreateFlags ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT       = 0x00000400;
const AllocationCreateFlags ALLOCATION_CREATE_HOST_ACCESS_RANDOM_BIT                 = 0x00000800;
const AllocationCreateFlags ALLOCATION_CREATE_HOST_ACCESS_ALLOW_TRANSFER_INSTEAD_BIT = 0x00001000;

// VmaVulkanFunctions, full field set and order for v3.3.0 built against a
// Vulkan >= 1.3 SDK (VK_KHR_dedicated_allocation, VK_KHR_bind_memory2,
// VK_EXT_memory_budget and VK_KHR_maintenance4 are all promoted to core by
// then, so every conditional field in the header is compiled in).
struct VulkanFunctions
{
	vk::ProcGetInstanceProcAddr get_instance_proc_addr;
	vk::ProcGetDeviceProcAddr get_device_proc_addr;
	vk::ProcGetPhysicalDeviceProperties get_physical_device_properties;
	vk::ProcGetPhysicalDeviceMemoryProperties get_physical_device_memory_properties;
	vk::ProcAllocateMemory allocate_memory;
	vk::ProcFreeMemory free_memory;
	vk::ProcMapMemory map_memory;
	vk::ProcUnmapMemory unmap_memory;
	vk::ProcFlushMappedMemoryRanges flush_mapped_memory_ranges;
	vk::ProcInvalidateMappedMemoryRanges invalidate_mapped_memory_ranges;
	vk::ProcBindBufferMemory bind_buffer_memory;
	vk::ProcBindImageMemory bind_image_memory;
	vk::ProcGetBufferMemoryRequirements get_buffer_memory_requirements;
	vk::ProcGetImageMemoryRequirements get_image_memory_requirements;
	vk::ProcCreateBuffer create_buffer;
	vk::ProcDestroyBuffer destroy_buffer;
	vk::ProcCreateImage create_image;
	vk::ProcDestroyImage destroy_image;
	vk::ProcCmdCopyBuffer cmd_copy_buffer;
	vk::ProcGetBufferMemoryRequirements2KHR get_buffer_memory_requirements2_khr;
	vk::ProcGetImageMemoryRequirements2KHR get_image_memory_requirements2_khr;
	vk::ProcBindBufferMemory2KHR bind_buffer_memory2_khr;
	vk::ProcBindImageMemory2KHR bind_image_memory2_khr;
	vk::ProcGetPhysicalDeviceMemoryProperties2KHR get_physical_device_memory_properties2_khr;
	vk::ProcGetDeviceBufferMemoryRequirementsKHR get_device_buffer_memory_requirements;
	vk::ProcGetDeviceImageMemoryRequirementsKHR get_device_image_memory_requirements;
	// VK_KHR_external_memory_win32 is not used by this port; kept only to
	// preserve the field's slot in the C struct layout (a `void*` in C unless
	// VMA_EXTERNAL_MEMORY_WIN32, pointer-sized either way).
	vk::ProcGetMemoryWin32HandleKHR get_memory_win32_handle_khr;
}

// VmaAllocatorCreateInfo.
struct AllocatorCreateInfo
{
	AllocatorCreateFlags flags;
	vk::PhysicalDevice physical_device;
	vk::Device device;
	vk::DeviceSize preferred_large_heap_block_size;
	void* allocation_callbacks;              // const VkAllocationCallbacks*
	void* device_memory_callbacks;           // const VmaDeviceMemoryCallbacks*
	vk::DeviceSize* heap_size_limit;         // const VkDeviceSize*
	VulkanFunctions* vulkan_functions;
	vk::Instance instance;
	uint vulkan_api_version;
	vk::ExternalMemoryHandleTypeFlagsKHR* type_external_memory_handle_types; // const, VMA_EXTERNAL_MEMORY
}

// VmaAllocationCreateInfo.
struct AllocationCreateInfo
{
	AllocationCreateFlags flags;
	MemoryUsage usage;
	vk::MemoryPropertyFlags required_flags;
	vk::MemoryPropertyFlags preferred_flags;
	uint memory_type_bits;
	Pool pool;
	void* user_data;
	float priority;
}

// VmaAllocationInfo.
struct AllocationInfo
{
	uint memory_type;
	vk::DeviceMemory device_memory;
	vk::DeviceSize offset;
	vk::DeviceSize size;
	void* mapped_data;
	void* user_data;
	ZString name;
}

// Build it locally with `meson compile -C build-meson` from the repository root.
// Then `c3c test -z -lSDL3` links libvma.a and the C++ runtime.
extern fn vk::Result create_allocator(AllocatorCreateInfo* create_info, Allocator* allocator) @cname("vmaCreateAllocator");
extern fn void destroy_allocator(Allocator allocator) @cname("vmaDestroyAllocator");
extern fn vk::Result create_buffer(Allocator allocator, vk::BufferCreateInfo* buffer_create_info, AllocationCreateInfo* allocation_create_info, vk::Buffer* buffer, Allocation* allocation, AllocationInfo* allocation_info) @cname("vmaCreateBuffer");
extern fn void destroy_buffer(Allocator allocator, vk::Buffer buffer, Allocation allocation) @cname("vmaDestroyBuffer");
extern fn vk::Result create_image(Allocator allocator, vk::ImageCreateInfo* image_create_info, AllocationCreateInfo* allocation_create_info, vk::Image* image, Allocation* allocation, AllocationInfo* allocation_info) @cname("vmaCreateImage");
extern fn void destroy_image(Allocator allocator, vk::Image image, Allocation allocation) @cname("vmaDestroyImage");
extern fn vk::Result flush_allocation(Allocator allocator, Allocation allocation, vk::DeviceSize offset, vk::DeviceSize size) @cname("vmaFlushAllocation");
extern fn vk::Result map_memory(Allocator allocator, Allocation allocation, void** data) @cname("vmaMapMemory");
extern fn void unmap_memory(Allocator allocator, Allocation allocation) @cname("vmaUnmapMemory");
extern fn void get_allocation_info(Allocator allocator, Allocation allocation, AllocationInfo* allocation_info) @cname("vmaGetAllocationInfo");

// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module vma;
import std::core::test;

// Sizes below were obtained by compiling this program against the VMA
// submodule header, with the same defines as vendor/vma_impl.cpp. Save the
// uncommented lines below as /tmp/vma_sizes.cpp and, from the repository root, run:
//
//   c++ -std=c++17 -DVMA_STATIC_VULKAN_FUNCTIONS=0 -DVMA_DYNAMIC_VULKAN_FUNCTIONS=1 \
//       -I vendor/rhi-c3/vendor/VulkanMemoryAllocator/include /tmp/vma_sizes.cpp -o /tmp/vma_sizes
//   /tmp/vma_sizes
//
// Output:
//   VmaAllocationCreateInfo 56
//   VmaAllocationInfo 56
//   VmaVulkanFunctions 224
//   VmaAllocatorCreateInfo 88
//
//   #include "vk_mem_alloc.h"
//   #include <cstdio>
//   int main() {
//       std::printf("VmaAllocationCreateInfo %zu\n", sizeof(VmaAllocationCreateInfo));
//       std::printf("VmaAllocationInfo %zu\n", sizeof(VmaAllocationInfo));
//       std::printf("VmaVulkanFunctions %zu\n", sizeof(VmaVulkanFunctions));
//       std::printf("VmaAllocatorCreateInfo %zu\n", sizeof(VmaAllocatorCreateInfo));
//   }
//
// Measured with Ubuntu g++ 15.2.0 on x86_64 Linux, where the header resolved
// VMA_VULKAN_VERSION = 1004000,
// VMA_EXTERNAL_MEMORY = 1 and VMA_EXTERNAL_MEMORY_WIN32 = 0. All four
// structs hold only pointers and 32/64-bit scalars, so the sizes are the
// same on every 64-bit target.
// `Type::size` is bound to a local first: passed straight to test::eq it
// fails eq's `values must be equatable` contract in c3c 0.8.4.
fn void struct_size() @test
{
	@check_size(AllocationCreateInfo, 56);
	@check_size(AllocationInfo, 56);
	@check_size(VulkanFunctions, 224);
	@check_size(AllocatorCreateInfo, 88);
}

macro void @check_size($Type, usz size)
{
	usz actual = $Type::size;
	test::eq(actual, size);
}

module vma @feat(LINUX);
import std::core::test;

// Link smoke test: after building the local archive with Meson, taking the
// address of an extern fn forces the linker to resolve it against
// vendor/lib/libvma.a (and,
// transitively, libstdc++). If either is missing, this fails to link rather
// than failing the assertion below.
fn void link() @test
{
	void* create_allocator_fn = (void*)&create_allocator;
	void* create_buffer_fn = (void*)&create_buffer;
	test::eq(create_allocator_fn != null, true);
	test::eq(create_buffer_fn != null, true);
}

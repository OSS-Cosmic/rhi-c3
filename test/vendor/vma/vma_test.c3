// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

module vma;
import std::core::test;

// Sizes below were obtained by compiling this program against the locally
// vendored c3/vendor/vma/include/vk_mem_alloc.h, with the same defines as
// c3/vendor/vma/vma_impl.cpp:
//
//   #define VMA_STATIC_VULKAN_FUNCTIONS 0
//   #define VMA_DYNAMIC_VULKAN_FUNCTIONS 1
//   #include "vk_mem_alloc.h"
//   #include <cstdio>
//   int main() {
//       printf("%zu\n", sizeof(VmaAllocationCreateInfo)); // 48
//       printf("%zu\n", sizeof(VmaAllocationInfo));       // 56
//       printf("%zu\n", sizeof(VmaVulkanFunctions));      // 216
//       printf("%zu\n", sizeof(VmaAllocatorCreateInfo));  // 88
//   }
//
// From c3/, this can be checked with `c++ -std=c++17 -I vendor/vma/include`
// (Ubuntu g++ 15.2.0) on x86_64 Linux, where the header resolved
// VMA_VULKAN_VERSION = 1004000,
// VMA_EXTERNAL_MEMORY = 1 and VMA_EXTERNAL_MEMORY_WIN32 = 0. All four
// structs hold only pointers and 32/64-bit scalars, so the sizes are the
// same on every 64-bit target.
// `Type::size` is bound to a local first: passed straight to test::eq it
// fails eq's `values must be equatable` contract in c3c 0.8.4.
fn void struct_size() @test
{
	@check_size(AllocationCreateInfo, 48);
	@check_size(AllocationInfo, 56);
	@check_size(VulkanFunctions, 216);
	@check_size(AllocatorCreateInfo, 88);
}

macro void @check_size($Type, usz size)
{
	usz actual = $Type::size;
	test::eq(actual, size);
}

module vma @feat(LINUX);
import std::core::test;

// Link smoke test: after building the local archive with the c3/ command in
// c3/src/vendor/vma/vma.c3, taking the address of an extern fn forces the
// linker to resolve it against c3/vendor/vma/lib/libvma.a (and,
// transitively, libstdc++). If either is missing, this fails to link rather
// than failing the assertion below.
fn void link() @test
{
	void* create_allocator_fn = (void*)&create_allocator;
	void* create_buffer_fn = (void*)&create_buffer;
	test::eq(create_allocator_fn != null, true);
	test::eq(create_buffer_fn != null, true);
}

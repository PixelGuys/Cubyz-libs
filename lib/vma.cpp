#ifdef __MACH__
#include <vulkan/vulkan.h>
#include <vulkan/vulkan_beta.h>
#else
#include <glad/vulkan.h>
#endif

#define VMA_VULKAN_HEADERS_ALREADY_INCLUDED
#define VMA_IMPLEMENTATION

#include <vk_mem_alloc_extended.h>

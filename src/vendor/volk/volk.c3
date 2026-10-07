// C3 binding for zeux/volk (vendor/volk), used only as the Vulkan loader.
// volkInitialize opens the platform's Vulkan loader library and resolves
// vkGetInstanceProcAddr, which vk::load_proc_addresses_global then uses to
// fill the generated procedure tables. volk's own per-command pointers and
// VolkDeviceTable are not bound.
module volk;
import vk;

extern fn vk::Result initialize() @cname("volkInitialize");
extern fn void finalize() @cname("volkFinalize");
extern fn uint get_instance_version() @cname("volkGetInstanceVersion");

// volk's global `vkGetInstanceProcAddr`; valid after `initialize` succeeds.
extern void* vk_get_instance_proc_addr @cname("vkGetInstanceProcAddr");

fn void* get_instance_proc_addr() => vk_get_instance_proc_addr;

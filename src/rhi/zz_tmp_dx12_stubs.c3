module rhi @feat(RHI_DX12 & !RHI_HEADLESS & !WASM & WIN32);
struct QueryPoolDx12 { char _unused; }

// Temporary: no D3D12 query backend yet.
fn QueryPool? query_pool_init_dx12(Device* device, QueryPoolDesc desc) => UNSUPPORTED_BACKEND~;
fn void query_pool_deinit_dx12(QueryPool* p, Device* device) {}
fn bool query_pool_get_results_dx12(QueryPool* p, Device* device, uint first, uint count, ulong* results) => false;
fn void cmd_reset_query_pool_dx12(Cmd* c, Device* device, QueryPool* p, uint first, uint count) {}
fn void cmd_resolve_query_pool_dx12(Cmd* c, Device* device, QueryPool* p, uint first, uint count) {}

// out[i] = i * 3 + push.bias, one thread per element.
struct Push { uint bias; uint count; };
[[vk::push_constant]] ConstantBuffer<Push> pc;
[[vk::binding(0, 0)]] RWStructuredBuffer<uint> outBuf;

[shader("compute")]
[numthreads(64, 1, 1)]
void csMain(uint3 id : SV_DispatchThreadID)
{
    if (id.x < pc.count) outBuf[id.x] = id.x * 3 + pc.bias;
}

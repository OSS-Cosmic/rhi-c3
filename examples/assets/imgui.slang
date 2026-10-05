// Dear ImGui shader used by the RHI ImGui layer.
// The texture and sampler are separate bindings to match rhi::Program.

struct VSInput {
    [[vk::location(0)]] float2 position : POSITION;
    [[vk::location(1)]] float2 uv : TEXCOORD0;
    [[vk::location(2)]] float4 color : COLOR0;
};

struct VSOutput {
    float4 position : SV_Position;
    float2 uv : TEXCOORD0;
    float4 color : COLOR0;
};

struct PushConsts {
    float2 scale;
    float2 translate;
};

#ifdef RHI_WGSL
[[vk::binding(2, 0)]] ConstantBuffer<PushConsts> pc;
#else
[[vk::push_constant]] PushConsts pc;
#endif

[[vk::binding(0, 0)]] Texture2D uTexture;
[[vk::binding(1, 0)]] SamplerState uSampler;

[shader("vertex")]
VSOutput vertexMain(VSInput input) {
    VSOutput output;
    output.uv = input.uv;
    output.color = input.color;
    output.position = float4(input.position * pc.scale + pc.translate, 0.0, 1.0);
    return output;
}

[shader("fragment")]
float4 fragmentMain(VSOutput input) : SV_Target {
    return input.color * uTexture.Sample(uSampler, input.uv);
}

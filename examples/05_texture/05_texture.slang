// Copyright 2026 Michael Pollind
// SPDX-License-Identifier: GPL-2.0-only

struct VSIn {
    float2 position : POSITION;
    float2 uv       : TEXCOORD0;
};

struct VSOut {
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
};

[shader("vertex")]
VSOut vertexMain(VSIn input) {
    VSOut output;
    output.position = float4(input.position, 0.0, 1.0);
    output.uv = input.uv;
    return output;
}

// WebGPU reserves group 0 for the uniform-buffer slot used by push constants,
// so the texture pair lives in group 1 there. GLSL combines the pair into a
// sampler2D when SPIRV-Cross emits the ES shader.
#ifdef RHI_WGSL
[[vk::binding(0, 1)]] Texture2D<float4> tex;
[[vk::binding(1, 1)]] SamplerState smp;
#else
[[vk::binding(0, 0)]] Texture2D<float4> tex;
[[vk::binding(1, 0)]] SamplerState smp;
#endif

[shader("fragment")]
float4 fragmentMain(VSOut input) : SV_Target {
    return tex.Sample(smp, input.uv);
}

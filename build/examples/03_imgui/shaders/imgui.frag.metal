#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 90 "core"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 90
struct pixelInput_0
{
    float2 uv_0 [[user(TEXCOORD)]];
    float4 color_0 [[user(COLOR)]];
};


#line 90
struct KernelContext_0
{
    texture2d<float, access::sample> uTexture_0;
    sampler uSampler_0;
};


#line 40 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/imgui.slang"
[[fragment]] pixelOutput_0 fragmentMain(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texture2d<float, access::sample> uTexture_1 [[texture(0)]], sampler uSampler_1 [[sampler(0)]])
{

#line 40
    thread KernelContext_0 kernelContext_0;

#line 40
    (&kernelContext_0)->uTexture_0 = uTexture_1;

#line 40
    (&kernelContext_0)->uSampler_0 = uSampler_1;

#line 40
    pixelOutput_0 _S2 = { _S1.color_0 * ((uTexture_1).sample((uSampler_1), (_S1.uv_0))) };
    return _S2;
}


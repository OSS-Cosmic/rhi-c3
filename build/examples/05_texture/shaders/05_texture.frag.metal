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
};


#line 90
struct KernelContext_0
{
    texture2d<float, access::sample> tex_0;
    sampler smp_0;
};


#line 34 "/home/michaelpollind/projects/rhi-odin/c3/examples/05_texture/05_texture.slang"
[[fragment]] pixelOutput_0 fragmentMain(pixelInput_0 _S1 [[stage_in]], float4 position_0 [[position]], texture2d<float, access::sample> tex_1 [[texture(0)]], sampler smp_1 [[sampler(0)]])
{

#line 34
    thread KernelContext_0 kernelContext_0;

#line 34
    (&kernelContext_0)->tex_0 = tex_1;

#line 34
    (&kernelContext_0)->smp_0 = smp_1;

#line 34
    pixelOutput_0 _S2 = { ((tex_1).sample((smp_1), (_S1.uv_0))) };
    return _S2;
}


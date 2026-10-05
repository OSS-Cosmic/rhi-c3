#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 5 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/01_mandelbrot.slang"
struct vertexMain_Result_0
{
    float4 position_0 [[position]];
    float2 uv_0 [[user(TEXCOORD)]];
};


#line 5
struct VSOutput_0
{
    float4 position_1;
    float2 uv_1;
};


#line 453 "core"
[[vertex]] vertexMain_Result_0 vertexMain(uint vid_0 [[vertex_id]])
{

#line 12 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/01_mandelbrot.slang"
    thread VSOutput_0 o_0;
    float2 _S1 = float2(float((vid_0 << 1U) & 2U), float(vid_0 & 2U));

#line 13
    (&o_0)->uv_1 = _S1;
    (&o_0)->position_1 = float4(_S1 * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

#line 14
    thread vertexMain_Result_0 _S2;

#line 14
    (&_S2)->position_0 = o_0.position_1;

#line 14
    (&_S2)->uv_0 = o_0.uv_1;

#line 14
    return _S2;
}


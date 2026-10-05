#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 4 "/home/michaelpollind/projects/rhi-odin/c3/examples/05_texture/05_texture.slang"
struct vertexMain_Result_0
{
    float4 position_0 [[position]];
    float2 uv_0 [[user(TEXCOORD)]];
};


#line 4
struct vertexInput_0
{
    float2 position_1 [[attribute(0)]];
    float2 uv_1 [[attribute(1)]];
};


#line 9
struct VSOut_0
{
    float4 position_2;
    float2 uv_2;
};


#line 9
[[vertex]] vertexMain_Result_0 vertexMain(vertexInput_0 _S1 [[stage_in]])
{

#line 16
    thread VSOut_0 output_0;
    (&output_0)->position_2 = float4(_S1.position_1, 0.0, 1.0);
    (&output_0)->uv_2 = _S1.uv_1;

#line 18
    thread vertexMain_Result_0 _S2;

#line 18
    (&_S2)->position_0 = output_0.position_2;

#line 18
    (&_S2)->uv_0 = output_0.uv_2;

#line 18
    return _S2;
}


#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 4 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/imgui.slang"
struct vertexMain_Result_0
{
    float4 position_0 [[position]];
    float2 uv_0 [[user(TEXCOORD)]];
    float4 color_0 [[user(COLOR)]];
};


#line 4
struct vertexInput_0
{
    float2 position_1 [[attribute(0)]];
    float2 uv_1 [[attribute(1)]];
    float4 color_1 [[attribute(2)]];
};


#line 16
struct PushConsts_0
{
    float2 scale_0;
    float2 translate_0;
};


#line 10
struct VSOutput_0
{
    float4 position_2;
    float2 uv_2;
    float4 color_2;
};


#line 10
[[vertex]] vertexMain_Result_0 vertexMain(vertexInput_0 _S1 [[stage_in]], PushConsts_0 constant* pc_0 [[buffer(0)]])
{

#line 32
    thread VSOutput_0 output_0;
    (&output_0)->uv_2 = _S1.uv_1;
    (&output_0)->color_2 = _S1.color_1;
    (&output_0)->position_2 = float4(_S1.position_1 * pc_0->scale_0 + pc_0->translate_0, 0.0, 1.0);

#line 35
    thread vertexMain_Result_0 _S2;

#line 35
    (&_S2)->position_0 = output_0.position_2;

#line 35
    (&_S2)->uv_0 = output_0.uv_2;

#line 35
    (&_S2)->color_0 = output_0.color_2;

#line 35
    return _S2;
}


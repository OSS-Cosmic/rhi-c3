#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 29 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/04_svt.slang"
struct vertexMain_Result_0
{
    float4 position_0 [[position]];
    float2 uv_0 [[user(TEXCOORD)]];
};


#line 29
struct vertexInput_0
{
    float3 position_1 [[attribute(0)]];
    float2 uv_1 [[attribute(1)]];
};


#line 29
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 29
struct PushConsts_natural_0
{
    _MatrixStorage_float4x4_ColMajornatural_0 mvp_0;
    float pageTableSize_0;
    float virtualTextureSize_0;
    float mipCount_0;
    float mipBias_0;
    float atlasCount_0;
    float borderScale_0;
    float borderOffset_0;
    float _pad_0;
};


#line 34
struct VSOutput_0
{
    float4 position_2;
    float2 uv_2;
};


#line 34
[[vertex]] vertexMain_Result_0 vertexMain(vertexInput_0 _S1 [[stage_in]], PushConsts_natural_0 constant* pc_0 [[buffer(0)]])
{

#line 42
    float4 _S2 = (((float4(_S1.position_1, 1.0)) * (matrix<float,int(4),int(4)> (pc_0->mvp_0.data_0[int(0)][int(0)], pc_0->mvp_0.data_0[int(1)][int(0)], pc_0->mvp_0.data_0[int(2)][int(0)], pc_0->mvp_0.data_0[int(3)][int(0)], pc_0->mvp_0.data_0[int(0)][int(1)], pc_0->mvp_0.data_0[int(1)][int(1)], pc_0->mvp_0.data_0[int(2)][int(1)], pc_0->mvp_0.data_0[int(3)][int(1)], pc_0->mvp_0.data_0[int(0)][int(2)], pc_0->mvp_0.data_0[int(1)][int(2)], pc_0->mvp_0.data_0[int(2)][int(2)], pc_0->mvp_0.data_0[int(3)][int(2)], pc_0->mvp_0.data_0[int(0)][int(3)], pc_0->mvp_0.data_0[int(1)][int(3)], pc_0->mvp_0.data_0[int(2)][int(3)], pc_0->mvp_0.data_0[int(3)][int(3)]))));

#line 42
    thread float4 clip_0 = _S2;
    clip_0.y = - _S2.y;

#line 41
    thread VSOutput_0 o_0;


    (&o_0)->position_2 = clip_0;
    (&o_0)->uv_2 = _S1.uv_1;

#line 45
    thread vertexMain_Result_0 _S3;

#line 45
    (&_S3)->position_0 = o_0.position_2;

#line 45
    (&_S3)->uv_0 = o_0.uv_2;

#line 45
    return _S3;
}


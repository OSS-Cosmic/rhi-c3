#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 51 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/04_svt.slang"
float mipLevel_0(float2 uv_0, float texSize_0)
{

#line 52
    float2 _S1 = uv_0 * float2(texSize_0) ;

#line 52
    float2 dx_0 = dfdx(_S1);
    float2 dy_0 = dfdy(_S1);

    return max(0.5 * log2(max(dot(dx_0, dx_0), dot(dy_0, dy_0))), 0.0);
}


#line 90 "core"
struct pixelOutput_0
{
    float4 output_0 [[color(0)]];
};


#line 90
struct pixelInput_0
{
    float2 uv_1 [[user(TEXCOORD)]];
};


#line 90
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 90
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


#line 5328 "core.meta.slang"
struct KernelContext_0
{
    PushConsts_natural_0 constant* pc_0;
    texture2d<float, access::sample> pageTable_0;
    sampler pageSampler_0;
    texture2d<float, access::sample> atlas_0;
    sampler atlasSampler_0;
};


#line 59 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/04_svt.slang"
[[fragment]] pixelOutput_0 compositeMain(pixelInput_0 _S2 [[stage_in]], float4 position_0 [[position]], PushConsts_natural_0 constant* pc_1 [[buffer(0)]], texture2d<float, access::sample> pageTable_1 [[texture(0)]], sampler pageSampler_1 [[sampler(0)]], texture2d<float, access::sample> atlas_1 [[texture(1)]], sampler atlasSampler_1 [[sampler(1)]])
{

#line 59
    thread KernelContext_0 kernelContext_0;

#line 59
    (&kernelContext_0)->pc_0 = pc_1;

#line 59
    (&kernelContext_0)->pageTable_0 = pageTable_1;

#line 59
    (&kernelContext_0)->pageSampler_0 = pageSampler_1;

#line 59
    (&kernelContext_0)->atlas_0 = atlas_1;

#line 59
    (&kernelContext_0)->atlasSampler_0 = atlasSampler_1;
    float2 uv_2 = fract(_S2.uv_1);

#line 70
    float4 entry_0 = ((pageTable_1).sample((pageSampler_1), (uv_2), level((clamp(floor(mipLevel_0(uv_2, pc_1->virtualTextureSize_0) - pc_1->mipBias_0), 0.0, pc_1->mipCount_0 - 1.0)))));
    if((entry_0.w) < 0.5)
    {

#line 71
        pixelOutput_0 _S3 = { float4(0.01999999955296516, 0.01999999955296516, 0.07999999821186066, 1.0) };
        return _S3;
    }

#line 72
    pixelOutput_0 _S4 = { (((&kernelContext_0)->atlas_0).sample(((&kernelContext_0)->atlasSampler_0), ((float2(floor(entry_0.x * 255.0 + 0.5), floor(entry_0.y * 255.0 + 0.5)) + (fract(uv_2 * float2(((&kernelContext_0)->pc_0->pageTableSize_0 / exp2(floor(entry_0.z * 255.0 + 0.5)))) ) * float2((&kernelContext_0)->pc_0->borderScale_0)  + float2((&kernelContext_0)->pc_0->borderOffset_0) )) / float2((&kernelContext_0)->pc_0->atlasCount_0) ), level((0.0)))) };

#line 86
    return _S4;
}


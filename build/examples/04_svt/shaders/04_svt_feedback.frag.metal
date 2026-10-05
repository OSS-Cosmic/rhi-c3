#include <metal_stdlib>
#include <metal_math>
#include <metal_texture>
using namespace metal;

#line 43 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/04_svt_feedback.slang"
float mipLevel_0(float2 uv_0, float texSize_0)
{

#line 44
    float2 _S1 = uv_0 * float2(texSize_0) ;

#line 44
    float2 dx_0 = dfdx(_S1);
    float2 dy_0 = dfdy(_S1);

    return max(0.5 * log2(max(dot(dx_0, dx_0), dot(dy_0, dy_0))), 0.0);
}


#line 33
uint pageOffset_0(uint mip_0, uint pts_0)
{

#line 33
    uint i_0 = 0U;

#line 33
    uint off_0 = 0U;

    for(;;)
    {

#line 35
        if(i_0 < mip_0)
        {
        }
        else
        {

#line 35
            break;
        }

#line 36
        uint s_0 = pts_0 >> i_0;
        uint off_1 = off_0 + s_0 * s_0;

#line 35
        i_0 = i_0 + 1U;

#line 35
        off_0 = off_1;

#line 35
    }



    return off_0;
}


#line 90 "core"
struct pixelInput_0
{
    float2 uv_1 [[user(TEXCOORD)]];
};


#line 26 "/home/michaelpollind/projects/rhi-odin/c3/examples/assets/04_svt_feedback.slang"
struct _MatrixStorage_float4x4_ColMajornatural_0
{
    array<float4, int(4)> data_0;
};


#line 26
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


#line 64
struct KernelContext_0
{
    PushConsts_natural_0 constant* pc_0;
    uint device* feedback_0;
};


#line 51
[[fragment]] void feedbackMain(pixelInput_0 _S2 [[stage_in]], float4 position_0 [[position]], PushConsts_natural_0 constant* pc_1 [[buffer(1)]], uint device* feedback_1 [[buffer(0)]])
{

#line 51
    thread KernelContext_0 kernelContext_0;

#line 51
    (&kernelContext_0)->pc_0 = pc_1;

#line 51
    (&kernelContext_0)->feedback_0 = feedback_1;
    float2 uv_2 = fract(_S2.uv_1);
    uint pts_1 = uint(pc_1->pageTableSize_0);



    uint mip_1 = uint(clamp(floor(mipLevel_0(uv_2, pc_1->virtualTextureSize_0) - pc_1->mipBias_0), 0.0, pc_1->mipCount_0 - 1.0));

    uint sizeAtMip_0 = pts_1 >> mip_1;
    float _S3 = float(sizeAtMip_0);

#line 60
    uint _S4 = sizeAtMip_0 - 1U;



    *(feedback_1+(pageOffset_0(mip_1, pts_1) + min(uint(uv_2.y * _S3), _S4) * sizeAtMip_0 + min(uint(uv_2.x * _S3), _S4))) = 1U;
    return;
}


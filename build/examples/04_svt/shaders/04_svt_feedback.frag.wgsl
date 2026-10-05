struct _MatrixStorage_float4x4_ColMajorstd140_0
{
    @align(16) data_0 : array<vec4<f32>, i32(4)>,
};

struct PushConsts_std140_0
{
    @align(16) mvp_0 : _MatrixStorage_float4x4_ColMajorstd140_0,
    @align(16) pageTableSize_0 : f32,
    @align(4) virtualTextureSize_0 : f32,
    @align(8) mipCount_0 : f32,
    @align(4) mipBias_0 : f32,
    @align(16) atlasCount_0 : f32,
    @align(4) borderScale_0 : f32,
    @align(8) borderOffset_0 : f32,
    @align(4) _pad_0 : f32,
};

@binding(1) @group(0) var<uniform> pc_0 : PushConsts_std140_0;
@binding(0) @group(0) var<storage, read_write> feedback_0 : array<u32>;

fn mipLevel_0( uv_0 : vec2<f32>,  texSize_0 : f32) -> f32
{
    var _S1 : vec2<f32> = uv_0 * vec2<f32>(texSize_0);
    var dx_0 : vec2<f32> = dpdx(_S1);
    var dy_0 : vec2<f32> = dpdy(_S1);
    return max(0.5f * log2(max(dot(dx_0, dx_0), dot(dy_0, dy_0))), 0.0f);
}

fn pageOffset_0( mip_0 : u32,  pts_0 : u32) -> u32
{
    var i_0 : u32 = u32(0);
    var off_0 : u32 = u32(0);
    for(;;)
    {
        if(i_0 < mip_0)
        {
        }
        else
        {
            break;
        }
        var s_0 : u32 = (pts_0 >> (i_0));
        var off_1 : u32 = off_0 + s_0 * s_0;
        i_0 = i_0 + u32(1);
        off_0 = off_1;
    }
    return off_0;
}

struct pixelInput_0
{
    @location(0) uv_1 : vec2<f32>,
};

@fragment
fn feedbackMain( _S2 : pixelInput_0, @builtin(position) position_0 : vec4<f32>)
{
    var uv_2 : vec2<f32> = fract(_S2.uv_1);
    var pts_1 : u32 = u32(pc_0.pageTableSize_0);
    var mip_1 : u32 = u32(clamp(floor(mipLevel_0(uv_2, pc_0.virtualTextureSize_0) - pc_0.mipBias_0), 0.0f, pc_0.mipCount_0 - 1.0f));
    var sizeAtMip_0 : u32 = (pts_1 >> (mip_1));
    var _S3 : f32 = f32(sizeAtMip_0);
    var _S4 : u32 = sizeAtMip_0 - u32(1);
    feedback_0[pageOffset_0(mip_1, pts_1) + min(u32(uv_2.y * _S3), _S4) * sizeAtMip_0 + min(u32(uv_2.x * _S3), _S4)] = u32(1);
    return;
}


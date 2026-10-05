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

@binding(0) @group(0) var<uniform> pc_0 : PushConsts_std140_0;
@binding(1) @group(0) var pageTable_0 : texture_2d<f32>;

@binding(3) @group(0) var pageSampler_0 : sampler;

@binding(2) @group(0) var atlas_0 : texture_2d<f32>;

@binding(4) @group(0) var atlasSampler_0 : sampler;

fn mipLevel_0( uv_0 : vec2<f32>,  texSize_0 : f32) -> f32
{
    var _S1 : vec2<f32> = uv_0 * vec2<f32>(texSize_0);
    var dx_0 : vec2<f32> = dpdx(_S1);
    var dy_0 : vec2<f32> = dpdy(_S1);
    return max(0.5f * log2(max(dot(dx_0, dx_0), dot(dy_0, dy_0))), 0.0f);
}

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) uv_1 : vec2<f32>,
};

@fragment
fn compositeMain( _S2 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var uv_2 : vec2<f32> = fract(_S2.uv_1);
    var entry_0 : vec4<f32> = (textureSampleLevel((pageTable_0), (pageSampler_0), (uv_2), (clamp(floor(mipLevel_0(uv_2, pc_0.virtualTextureSize_0) - pc_0.mipBias_0), 0.0f, pc_0.mipCount_0 - 1.0f))));
    if((entry_0.w) < 0.5f)
    {
        var _S3 : pixelOutput_0 = pixelOutput_0( vec4<f32>(0.01999999955296516f, 0.01999999955296516f, 0.07999999821186066f, 1.0f) );
        return _S3;
    }
    var _S4 : pixelOutput_0 = pixelOutput_0( (textureSampleLevel((atlas_0), (atlasSampler_0), ((vec2<f32>(floor(entry_0.x * 255.0f + 0.5f), floor(entry_0.y * 255.0f + 0.5f)) + (fract(uv_2 * vec2<f32>((pc_0.pageTableSize_0 / exp2(floor(entry_0.z * 255.0f + 0.5f))))) * vec2<f32>(pc_0.borderScale_0) + vec2<f32>(pc_0.borderOffset_0))) / vec2<f32>(pc_0.atlasCount_0)), (0.0f))) );
    return _S4;
}


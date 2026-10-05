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
struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
    @location(1) uv_1 : vec2<f32>,
};

@vertex
fn vertexMain( _S1 : vertexInput_0) -> VSOutput_0
{
    var _S2 : vec4<f32> = (((vec4<f32>(_S1.position_1, 1.0f)) * (mat4x4<f32>(pc_0.mvp_0.data_0[i32(0)][i32(0)], pc_0.mvp_0.data_0[i32(1)][i32(0)], pc_0.mvp_0.data_0[i32(2)][i32(0)], pc_0.mvp_0.data_0[i32(3)][i32(0)], pc_0.mvp_0.data_0[i32(0)][i32(1)], pc_0.mvp_0.data_0[i32(1)][i32(1)], pc_0.mvp_0.data_0[i32(2)][i32(1)], pc_0.mvp_0.data_0[i32(3)][i32(1)], pc_0.mvp_0.data_0[i32(0)][i32(2)], pc_0.mvp_0.data_0[i32(1)][i32(2)], pc_0.mvp_0.data_0[i32(2)][i32(2)], pc_0.mvp_0.data_0[i32(3)][i32(2)], pc_0.mvp_0.data_0[i32(0)][i32(3)], pc_0.mvp_0.data_0[i32(1)][i32(3)], pc_0.mvp_0.data_0[i32(2)][i32(3)], pc_0.mvp_0.data_0[i32(3)][i32(3)]))));
    var clip_0 : vec4<f32> = _S2;
    clip_0[i32(1)] = - _S2.y;
    var o_0 : VSOutput_0;
    o_0.position_0 = clip_0;
    o_0.uv_0 = _S1.uv_1;
    return o_0;
}


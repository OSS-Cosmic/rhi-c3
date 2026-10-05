struct PushConsts_std140_0
{
    @align(16) scale_0 : vec2<f32>,
    @align(8) translate_0 : vec2<f32>,
};

@binding(2) @group(0) var<uniform> pc_0 : PushConsts_std140_0;
struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
    @location(1) color_0 : vec4<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec2<f32>,
    @location(1) uv_1 : vec2<f32>,
    @location(2) color_1 : vec4<f32>,
};

@vertex
fn vertexMain( _S1 : vertexInput_0) -> VSOutput_0
{
    var output_0 : VSOutput_0;
    output_0.uv_0 = _S1.uv_1;
    output_0.color_0 = _S1.color_1;
    output_0.position_0 = vec4<f32>(_S1.position_1 * pc_0.scale_0 + pc_0.translate_0, 0.0f, 1.0f);
    return output_0;
}


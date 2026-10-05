struct VSOut_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) uv_0 : vec2<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec2<f32>,
    @location(1) uv_1 : vec2<f32>,
};

@vertex
fn vertexMain( _S1 : vertexInput_0) -> VSOut_0
{
    var output_0 : VSOut_0;
    output_0.position_0 = vec4<f32>(_S1.position_1, 0.0f, 1.0f);
    output_0.uv_0 = _S1.uv_1;
    return output_0;
}


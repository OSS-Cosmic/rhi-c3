@binding(0) @group(1) var tex_0 : texture_2d<f32>;

@binding(1) @group(1) var smp_0 : sampler;

struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) uv_0 : vec2<f32>,
};

@fragment
fn fragmentMain( _S1 : pixelInput_0, @builtin(position) position_0 : vec4<f32>) -> pixelOutput_0
{
    var _S2 : pixelOutput_0 = pixelOutput_0( (textureSample((tex_0), (smp_0), (_S1.uv_0))) );
    return _S2;
}


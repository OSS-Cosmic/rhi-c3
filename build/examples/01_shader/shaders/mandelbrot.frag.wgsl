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
    var _S2 : vec2<f32> = vec2<f32>(_S1.uv_0.x * 3.0f - 2.09999990463256836f, _S1.uv_0.y * 2.59999990463256836f - 1.29999995231628418f);
    var z_0 : vec2<f32> = vec2<f32>(0.0f, 0.0f);
    var i_0 : i32 = i32(0);
    for(;;)
    {
        if(i_0 < i32(256))
        {
        }
        else
        {
            break;
        }
        var _S3 : f32 = z_0.x;
        var _S4 : f32 = z_0.y;
        var z_1 : vec2<f32> = vec2<f32>(_S3 * _S3 - _S4 * _S4, 2.0f * _S3 * _S4) + _S2;
        if((dot(z_1, z_1)) > 4.0f)
        {
            break;
        }
        var _S5 : i32 = i_0 + i32(1);
        z_0 = z_1;
        i_0 = _S5;
    }
    if(i_0 == i32(256))
    {
        var _S6 : pixelOutput_0 = pixelOutput_0( vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f) );
        return _S6;
    }
    var _S7 : vec3<f32> = vec3<f32>(0.5f);
    var _S8 : pixelOutput_0 = pixelOutput_0( vec4<f32>(_S7 + _S7 * cos(vec3<f32>(6.28318023681640625f) * (vec3<f32>((f32(i_0) / 256.0f)) + vec3<f32>(0.0f, 0.33000001311302185f, 0.67000001668930054f))), 1.0f) );
    return _S8;
}


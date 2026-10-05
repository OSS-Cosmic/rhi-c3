struct PushConsts_std140_0
{
    @align(16) time_0 : f32,
    @align(4) aspect_0 : f32,
    @align(8) y_sign_0 : f32,
};

@binding(0) @group(0) var<uniform> pc_0 : PushConsts_std140_0;
fn rotateY_0( a_0 : f32) -> mat4x4<f32>
{
    var c_0 : f32 = cos(a_0);
    var s_0 : f32 = sin(a_0);
    return mat4x4<f32>(c_0, 0.0f, s_0, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, - s_0, 0.0f, c_0, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
}

fn rotateX_0( a_1 : f32) -> mat4x4<f32>
{
    var c_1 : f32 = cos(a_1);
    var s_1 : f32 = sin(a_1);
    return mat4x4<f32>(1.0f, 0.0f, 0.0f, 0.0f, 0.0f, c_1, - s_1, 0.0f, 0.0f, s_1, c_1, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
}

fn translate_0( t_0 : vec3<f32>) -> mat4x4<f32>
{
    return mat4x4<f32>(1.0f, 0.0f, 0.0f, t_0.x, 0.0f, 1.0f, 0.0f, t_0.y, 0.0f, 0.0f, 1.0f, t_0.z, 0.0f, 0.0f, 0.0f, 1.0f);
}

fn perspective_0( fovy_0 : f32,  aspect_1 : f32,  near_0 : f32,  far_0 : f32) -> mat4x4<f32>
{
    var f_0 : f32 = 1.0f / tan(fovy_0 * 0.5f);
    var _S1 : f32 = near_0 - far_0;
    return mat4x4<f32>(f_0 / aspect_1, 0.0f, 0.0f, 0.0f, 0.0f, f_0, 0.0f, 0.0f, 0.0f, 0.0f, far_0 / _S1, near_0 * far_0 / _S1, 0.0f, 0.0f, -1.0f, 0.0f);
}

struct VSOutput_0
{
    @builtin(position) position_0 : vec4<f32>,
    @location(0) color_0 : vec3<f32>,
};

struct vertexInput_0
{
    @location(0) position_1 : vec3<f32>,
};

@vertex
fn vertexMain( _S2 : vertexInput_0) -> VSOutput_0
{
    var o_0 : VSOutput_0;
    o_0.color_0 = _S2.position_1 + vec3<f32>(0.5f, 0.5f, 0.5f);
    var clip_0 : vec4<f32> = (((((((((vec4<f32>(_S2.position_1, 1.0f)) * ((((rotateX_0(pc_0.time_0 * 0.69999998807907104f)) * (rotateY_0(pc_0.time_0)))))))) * (translate_0(vec3<f32>(0.0f, 0.0f, -2.5f)))))) * (perspective_0(radians(60.0f), pc_0.aspect_0, 0.10000000149011612f, 100.0f))));
    clip_0[i32(1)] = clip_0[i32(1)] * pc_0.y_sign_0;
    o_0.position_0 = clip_0;
    return o_0;
}


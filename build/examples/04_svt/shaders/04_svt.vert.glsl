#version 300 es

struct PushConsts_std430
{
    mat4 mvp;
    float pageTableSize;
    float virtualTextureSize;
    float mipCount;
    float mipBias;
    float atlasCount;
    float borderScale;
    float borderOffset;
    float _pad;
};

uniform PushConsts_std430 pc;

layout(location = 0) in vec3 input_position;
layout(location = 1) in vec2 input_uv;
out vec2 rhi_varying_0;

void main()
{
    vec4 _28 = vec4(input_position, 1.0) * pc.mvp;
    _28.y = -_28.y;
    gl_Position = _28;
    rhi_varying_0 = input_uv;
    gl_Position.z = 2.0 * gl_Position.z - gl_Position.w;
    gl_Position.y = -gl_Position.y;
}


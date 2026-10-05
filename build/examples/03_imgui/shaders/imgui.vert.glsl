#version 300 es

struct PushConsts_std430
{
    vec2 scale;
    vec2 translate;
};

uniform PushConsts_std430 pc;

layout(location = 1) in vec2 input_uv;
layout(location = 2) in vec4 input_color;
layout(location = 0) in vec2 input_position;
out vec2 rhi_varying_0;
out vec4 rhi_varying_1;

void main()
{
    gl_Position = vec4((input_position * pc.scale) + pc.translate, 0.0, 1.0);
    rhi_varying_0 = input_uv;
    rhi_varying_1 = input_color;
    gl_Position.z = 2.0 * gl_Position.z - gl_Position.w;
    gl_Position.y = -gl_Position.y;
}


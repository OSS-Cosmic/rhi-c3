#version 300 es

layout(location = 0) in vec2 input_position;
layout(location = 1) in vec2 input_uv;
out vec2 rhi_varying_0;

void main()
{
    gl_Position = vec4(input_position, 0.0, 1.0);
    rhi_varying_0 = input_uv;
    gl_Position.z = 2.0 * gl_Position.z - gl_Position.w;
    gl_Position.y = -gl_Position.y;
}


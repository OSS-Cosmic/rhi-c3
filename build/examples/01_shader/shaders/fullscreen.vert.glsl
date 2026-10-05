#version 300 es

#ifdef GL_ARB_shader_draw_parameters
#define SPIRV_Cross_BaseVertex gl_BaseVertexARB
#else
uniform int SPIRV_Cross_BaseVertex;
#endif
out vec2 rhi_varying_0;

void main()
{
    vec2 _33 = vec2(float((uint(gl_VertexID - 0) << uint(1)) & 2u), float(uint(gl_VertexID - 0) & 2u));
    gl_Position = vec4((_33 * vec2(2.0, -2.0)) + vec2(-1.0, 1.0), 0.0, 1.0);
    rhi_varying_0 = _33;
    gl_Position.z = 2.0 * gl_Position.z - gl_Position.w;
    gl_Position.y = -gl_Position.y;
}


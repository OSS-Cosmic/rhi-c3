#version 300 es

struct PushConsts_std430
{
    float time;
    float aspect;
    float y_sign;
};

uniform PushConsts_std430 pc;

layout(location = 0) in vec3 input_position;
out vec3 rhi_varying_0;

void main()
{
    float _141 = cos(pc.time);
    float _142 = sin(pc.time);
    float _50 = pc.time * 0.699999988079071044921875;
    float _151 = cos(_50);
    float _152 = sin(_50);
    float _82 = radians(60.0);
    float _173 = 1.0 / tan(_82 * 0.5);
    vec4 _115 = ((vec4(input_position, 1.0) * (mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, _151, -_152, 0.0), vec4(0.0, _152, _151, 0.0), vec4(0.0, 0.0, 0.0, 1.0)) * mat4(vec4(_141, 0.0, _142, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(-_142, 0.0, _141, 0.0), vec4(0.0, 0.0, 0.0, 1.0)))) * mat4(vec4(1.0, 0.0, 0.0, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(0.0, 0.0, 1.0, -2.5), vec4(0.0, 0.0, 0.0, 1.0))) * mat4(vec4(_173 / pc.aspect, 0.0, 0.0, 0.0), vec4(0.0, _173, 0.0, 0.0), vec4(0.0, 0.0, -1.00100100040435791015625, -0.100100100040435791015625), vec4(0.0, 0.0, -1.0, 0.0));
    _115.y = _115.y * pc.y_sign;
    gl_Position = _115;
    rhi_varying_0 = input_position + vec3(0.5);
    gl_Position.z = 2.0 * gl_Position.z - gl_Position.w;
    gl_Position.y = -gl_Position.y;
}


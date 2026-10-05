#version 300 es
precision mediump float;
precision highp int;

uniform highp sampler2D tex;

in highp vec2 rhi_varying_0;
layout(location = 0) out highp vec4 entryPointParam_fragmentMain;

void main()
{
    entryPointParam_fragmentMain = texture(tex, rhi_varying_0);
}


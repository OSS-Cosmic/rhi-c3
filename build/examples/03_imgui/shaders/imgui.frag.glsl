#version 300 es
precision mediump float;
precision highp int;

uniform highp sampler2D uTexture;

in highp vec4 rhi_varying_1;
in highp vec2 rhi_varying_0;
layout(location = 0) out highp vec4 entryPointParam_fragmentMain;

void main()
{
    entryPointParam_fragmentMain = rhi_varying_1 * texture(uTexture, rhi_varying_0);
}


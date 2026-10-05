#version 300 es
precision mediump float;
precision highp int;

in highp vec3 rhi_varying_0;
layout(location = 0) out highp vec4 entryPointParam_fragmentMain;

void main()
{
    entryPointParam_fragmentMain = vec4(rhi_varying_0, 1.0);
}


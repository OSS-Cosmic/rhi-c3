#version 300 es
precision mediump float;
precision highp int;

struct PushConsts_std430
{
    highp mat4 mvp;
    highp float pageTableSize;
    highp float virtualTextureSize;
    highp float mipCount;
    highp float mipBias;
    highp float atlasCount;
    highp float borderScale;
    highp float borderOffset;
    highp float _pad;
};

uniform PushConsts_std430 pc;

uniform highp sampler2D pageTable;
uniform highp sampler2D atlas;

in highp vec2 rhi_varying_0;
layout(location = 0) out highp vec4 entryPointParam_compositeMain;

void main()
{
    do
    {
        highp vec2 _12 = fract(rhi_varying_0);
        highp vec2 _143 = _12 * pc.virtualTextureSize;
        highp vec2 _155 = dFdx(_143);
        highp vec2 _158 = dFdy(_143);
        highp vec4 sampled = textureLod(pageTable, _12, clamp(floor(max(0.5 * log2(max(dot(_155, _155), dot(_158, _158))), 0.0) - pc.mipBias), 0.0, pc.mipCount - 1.0));
        if (sampled.w < 0.5)
        {
            entryPointParam_compositeMain = vec4(0.0199999995529651641845703125, 0.0199999995529651641845703125, 0.07999999821186065673828125, 1.0);
            break;
        }
        entryPointParam_compositeMain = textureLod(atlas, (vec2(floor((sampled.x * 255.0) + 0.5), floor((sampled.y * 255.0) + 0.5)) + ((fract(_12 * (pc.pageTableSize / exp2(floor((sampled.z * 255.0) + 0.5)))) * pc.borderScale) + vec2(pc.borderOffset))) / vec2(pc.atlasCount), 0.0);
        break;
    } while(false);
}


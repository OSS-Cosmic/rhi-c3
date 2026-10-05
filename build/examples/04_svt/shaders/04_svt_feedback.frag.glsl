#version 300 es
precision mediump float;
precision highp int;

layout(std430) buffer RWStructuredBuffer
{
    uint _member0[];
} feedback;

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

in highp vec2 rhi_varying_0;

void main()
{
    highp vec2 _10 = fract(rhi_varying_0);
    uint pts = uint(pc.pageTableSize);
    highp vec2 _136 = _10 * pc.virtualTextureSize;
    highp vec2 _148 = dFdx(_136);
    highp vec2 _151 = dFdy(_136);
    uint mip = uint(clamp(floor(max(0.5 * log2(max(dot(_148, _148), dot(_151, _151))), 0.0) - pc.mipBias), 0.0, pc.mipCount - 1.0));
    uint sizeAtMip = pts >> mip;
    highp float _70 = float(sizeAtMip);
    uint _73 = sizeAtMip - 1u;
    uint _152 = 0u;
    uint _153 = 0u;
    for (;;)
    {
        if (!(_152 < mip))
        {
            break;
        }
        uint _164 = _152;
        uint _165 = pts >> _164;
        _152++;
        _153 += (_165 * _165);
        continue;
    }
    feedback._member0[(_153 + (min(uint(_10.y * _70), _73) * sizeAtMip)) + min(uint(_10.x * _70), _73)] = 1u;
}


#version 300 es
precision mediump float;
precision highp int;

in highp vec2 rhi_varying_0;
layout(location = 0) out highp vec4 entryPointParam_fragmentMain;

void main()
{
    do
    {
        highp vec2 _39 = vec2((rhi_varying_0.x * 3.0) - 2.099999904632568359375, (rhi_varying_0.y * 2.599999904632568359375) - 1.2999999523162841796875);
        highp vec2 z = vec2(0.0);
        int i = 0;
        for (;;)
        {
            if (!(i < 256))
            {
                break;
            }
            highp vec2 z_1 = vec2((z.x * z.x) - (z.y * z.y), (2.0 * z.x) * z.y) + _39;
            if (dot(z_1, z_1) > 4.0)
            {
                break;
            }
            z = z_1;
            i++;
            continue;
        }
        if (i == 256)
        {
            entryPointParam_fragmentMain = vec4(0.0, 0.0, 0.0, 1.0);
            break;
        }
        entryPointParam_fragmentMain = vec4(vec3(0.5) + (cos((vec3(float(i) * 0.00390625) + vec3(0.0, 0.3300000131130218505859375, 0.670000016689300537109375)) * 6.28318023681640625) * 0.5), 1.0);
        break;
    } while(false);
}


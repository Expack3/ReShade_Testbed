#include "ReShade.fxh"

/*
1-bit Hue-Based Palette Shader
Based upon Alex Charlton's Hue-Based Palette Shader: alex-charlton.com/posts/Dithering_on_the_GPU
Adapted by Expack3
*/

#define Epsilon = 0.0000000001;
#define lightnessSteps = 4.0;

sampler2D SourcePointSampler
{
	Texture = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

float3 palette[8];
int paletteSize;


float3 RGBtoHCV(float3 RGB)
  {
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6.0 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
  }

float3 HUEtoRGB(float H)
  {
    float R = abs(H * 6.0 - 3.0) - 1.0;
    float G = 2 - abs(H * 6.0 - 2.0);
    float B = 2 - abs(H * 6.0 - 4.0);
    return clamp(float3(R,G,B),0.0,1.0);
  }

float3 HSLtoRGB(float3 HSL)
  {
    float3 RGB = HUEtoRGB(HSL.x);
    float C = (1.0 - abs(2.0 * HSL.z - 1.0)) * HSL.y;
    return (RGB - 0.5) * C + HSL.z;
  }

float3 RGBtoHSV(float3 RGB)
  {
    float3 HCV = RGBtoHCV(RGB);
    float S = HCV.y / (HCV.z + Epsilon);
    return float3(HCV.x, S, HCV.z);
  }

float3 RGBtoHSL(float3 RGB)
  {
    float3 HCV = RGBtoHCV(RGB);
    float L = HCV.z - HCV.y * 0.5;
    float S = HCV.y / (1.0 - abs(L * 2.0 - 1.0) + Epsilon);
    return float3(HCV.x, S, L);
  }

float lightnessStep(float l) {
    /* Quantize the lightness to one of `lightnessSteps` values */
    return floor((0.5 + l * lightnessSteps)) / lightnessSteps;
}

const int4x4 indexMatrix4x4 =       (0,  8,  2,  10,
                                     12, 4,  14, 6,
                                     3,  11, 1,  9,
                                     15, 7,  13, 5);

float indexValue(float4 vpos : SV_Position) {
    int x = int(vpos.x % 4);
    int y = int(vpos.y % 4);
    return indexMatrix4x4[(x + y * 4.0)] / 16.0;
}

float hueDistance(float h1, float h2) {
    float diff = abs((h1 - h2));
    return min(abs((1.0 - diff)), diff);
}

float3x2 closestColors(float hue) {
    float3 ret[2];
    float3 closest = float3(-2, 0, 0);
    float3 secondClosest = float3(-2, 0, 0);
    float3 temp;
    for (int i = 0; i < paletteSize; ++i) {
        temp = palette[i];
        float tempDistance = hueDistance(temp.x, hue);
        if (tempDistance < hueDistance(closest.x, hue)) {
            secondClosest = closest;
            closest = temp;
        } else {
            if (tempDistance < hueDistance(secondClosest.x, hue)) {
                secondClosest = temp;
            }
        }
    }
    ret[0] = closest;
    ret[1] = secondClosest;
    return ret;
}

float3 dither(float3 color) {
    float3 hsl = RGBtoHSL(color);

    float3 cs[2] = closestColors(hsl.x);
    float3 c1 = cs[0];
    float3 c2 = cs[1];
    float d = indexValue();
    float hueDiff = hueDistance(hsl.x, c1.x) / hueDistance(c2.x, c1.x);

    float l1 = lightnessStep(max((hsl.z - 0.125), 0.0));
    float l2 = lightnessStep(min((hsl.z + 0.124), 1.0));
    float lightnessDiff = (hsl.z - l1) / (l2 - l1);

    float3 resultColor = (hueDiff < d) ? c1 : c2;
    resultColor.z = (lightnessDiff < d) ? l1 : l2;
    return hslToRgb(resultColor);
}

float4 PS_HPBS(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float3 fragcolor = tex2D(SourcePointSampler, texcoord).rgb;
	return float4(dither(fragcolor), 1.0);
}


technique HPBG

{

	pass PAL

	{

		VertexShader = PostProcessVS;

		PixelShader = PS_HPBS;

	}

}

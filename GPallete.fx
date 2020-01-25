//Generic Palletizer
//Created by abelcamarena https://www.shadertoy.com/view/tsKGDm
//Adapted by The MacGovern with assistance from Matsilagi

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

uniform float PIXEL_FACTOR < 
    ui_type = "drag";
    ui_min = 320; ui_max=ReShade::ScreenSize.x; ui_step = 1;
    ui_label = "Screen Width";
	ui_tooltip = "Determines what screen width to emulate (lower number = bigger pixels).";
> = 320; // Lower num - bigger pixels (this will be the screen width)

uniform float COLOR_FACTOR < 
    ui_type = "slider";
    ui_min = 1; ui_max=24; ui_step = 1;
    ui_label = "Color Depth";
	ui_tooltip = "Determines the color reproduction quality (higher number = better quality).";
> = 4; // Higher num - higher colors quality

uniform float DITHER_AMOUNT < 
    ui_type = "drag";
    ui_min = 0.005; ui_max=1; ui_step = 0.001;
    ui_label = "Dither Amount";
	ui_tooltip = "Determines how much the image is dithered.";
> = 0.005; // Higher num - higher colors quality

static const float4x4 ditherTable = float4x4(
    float4(-4.0, 0.0, -3.0, 1.0),
    float4(2.0, -2.0, 3.0, -1.0),
    float4(-3.0, 1.0, -4.0, 0.0),
    float4(3.0, -1.0, 2.0, -2.0)
);

sampler2D SourcePointSampler
{
    Texture = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

float4 PS_GPallete(float4 vpos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{                  
    // Reduce pixels            
    float2 size = PIXEL_FACTOR * ReShade::ScreenSize.xy/ReShade::ScreenSize.x;
    float2 coor = floor(vpos.xy/ReShade::ScreenSize.xy * size) ;
    float2 uv = coor / size;
    #if (__RENDERER__ >= 0x10000)
    {
	    uv.y = 1 - uv.y;
    }
    #endif   
                
   	// Get source color
    float3 col = tex2D(SourcePointSampler, uv).xyz;

    // Dither
    col += ditherTable[uint( coor.x ) % 4][uint( coor.y ) % 4] * DITHER_AMOUNT; // last number is dithering strength

    // Reduce colors    
    col = floor(col * COLOR_FACTOR) / COLOR_FACTOR;    
   
    // Output to screen
    return float4(col,1);
}

technique GenericPalettizer
{
	pass LinearizeDepthPass
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_GPallete;
	}
}
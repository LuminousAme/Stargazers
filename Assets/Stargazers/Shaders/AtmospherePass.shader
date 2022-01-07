Shader "FullScreen/AtmospherePass"
{

		HLSLINCLUDE

#pragma vertex Vert

#pragma target 4.5
#pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"

			// The PositionInputs struct allow you to retrieve a lot of useful information for your fullScreenShader:
			// struct PositionInputs
			// {
			//     float3 positionWS;  // World space position (could be camera-relative)
			//     float2 positionNDC; // Normalized screen coordinates within the viewport    : [0, 1) (with the half-pixel offset)
			//     uint2  positionSS;  // Screen space pixel coordinates                       : [0, NumPixels)
			//     uint2  tileCoord;   // Screen tile coordinates                              : [0, NumTiles)
			//     float  deviceDepth; // Depth from the depth buffer                          : [0, 1] (typically reversed)
			//     float  linearDepth; // View space Z coordinate                              : [Near, Far]
			// };

			// To sample custom buffers, you have access to these functions:
			// But be careful, on most platforms you can't sample to the bound color buffer. It means that you
			// can't use the SampleCustomColor when the pass color buffer is set to custom (and same for camera the buffer).
			// float4 SampleCustomColor(float2 uv);
			// float4 LoadCustomColor(uint2 pixelCoords);
			// float LoadCustomDepth(uint2 pixelCoords);
			// float SampleCustomDepth(float2 uv);

			// There are also a lot of utility function you can use inside Common.hlsl and Color.hlsl,
			// you can check them out in the source code of the core SRP package.

	sampler2D _SkyViewLut;
	float4 _ViewPosition; //w unused
	float4 _SunDirection; //w unused
	float _GroundRadiusMM;
	float _AtmoRadiusReal;
	float4 _PlanetPos;

	//gets the sign of a float
	float GetSign(float num) {
		return lerp(-1.0, 1.0, int(num >= 0));
	}

	//gets a value from the sky view lut
	float3 SampleSkyViewLUT(float3 rayOrigin, float3 rayDir, float3 spherePosition) {
		float3 offset = rayOrigin - spherePosition;

		float3 sunDir = _SunDirection.xyz;
		float height = length(rayOrigin);
		float3 up = rayOrigin / height;

		float horizonAngle = acos(clamp(sqrt(height * height - _GroundRadiusMM * _GroundRadiusMM) / height, 0.0, 1.0));
		float altitudeAngle = horizonAngle - acos(dot(rayDir, up));
		
		float3 right = cross(sunDir, up);
		float3 forward = cross(up, right);
		float3 projectedDir = normalize(rayDir - up * dot(rayDir, up));
		float sinTheta = dot(projectedDir, right);
		float cosTheta = dot(projectedDir, forward);
		
		float azimuthAngle = atan2(sinTheta, cosTheta) + 3.14159265358;
		azimuthAngle = lerp(azimuthAngle, 0.0, int(abs(altitudeAngle) > (0.5 * 3.14159265358 + 0.0001)));

		//non linear mapping of the sky view lut
		float u = azimuthAngle / (2.0 * 3.14159265358);
		float v = 0.5 + 0.5 * GetSign(altitudeAngle) * sqrt(abs(altitudeAngle) / (0.5 * 3.14159265358));
		float2 uvs = float2(u, v);

		//return float3(u, v, 1.0);
		return tex2D(_SkyViewLut, uvs).rgb;
	}

	//code derived heavily from Sebastian Lague's atmosphere video: https://youtu.be/DxfEbulyFcY?t=64
	float2 raySphereIntsect(float3 rayOrigin, float3 rayDir, float3 spherePosition, float rad) {
		float3 offset = rayOrigin - spherePosition;

		float a = dot(rayDir, rayDir);
		float b = 2 * dot(offset, rayDir);
		float c = dot(offset, offset) - (rad * rad);
		float discrim = b * b - 4 * a * c;

		float s = sqrt(discrim);
		float nearDist = max(0, (-b - s) / (2.0 * a));
		float farDist = (-b + s) / (2.0 * a);

		int failed = int(discrim <= 0.0 || farDist < 0.0);
		float2 result = lerp(float2(nearDist, farDist - nearDist), float2(1e36, 0), failed);
		return result;

		return float2(1e36, 0);
	}


    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
        float depth = LoadCameraDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);
        float3 viewDirection = GetWorldSpaceNormalizeViewDir(posInput.positionWS);
        float4 color = float4(0.0, 0.0, 0.0, 0.0);

        // Load the camera color buffer at the mip 0 if we're not at the before rendering injection point
        if (_CustomPassInjectionPoint != CUSTOMPASSINJECTIONPOINT_BEFORE_RENDERING)
            color = float4(CustomPassLoadCameraColor(varyings.positionCS.xy, 0), 1);

        // Add your custom pass code here
		float3 rayOrigin = _ViewPosition.xyz;
		float3 viewDir = -viewDirection;
		float3 rayDir = normalize(viewDir);

		float SceneDepth = posInput.linearDepth;
		float3 planetOrigin = _PlanetPos.xyz;

		float2 hitInfo = raySphereIntsect(rayOrigin, rayDir, planetOrigin, _AtmoRadiusReal);
		float nearAtmo = hitInfo.x;
		float farAtmo = min(hitInfo.y, SceneDepth - nearAtmo);

		float3 pointInAtmo = rayOrigin + rayDir * nearAtmo;
		float3 skyViewColor = SampleSkyViewLUT(pointInAtmo, rayDir, planetOrigin);

		float3 blend = color.rgb * (1 - skyViewColor) + skyViewColor;
		float3 farAtmoVec = farAtmo / (_AtmoRadiusReal * 2);
		float3 result = lerp(float3(1.0 , 0.0 , 0.0), skyViewColor, int(farAtmo > 0.0));
		result = (farAtmo > 0.0) ? skyViewColor : color.rgb;
		
		return float4(farAtmoVec, 1.0);

		/*
		float2 hitInfo = raySphereIntsect(_ViewPosition.xyz, rayDir, planetOrigin, _AtmoRadiusReal);
		float nearAtmo = hitInfo.x;
		float farAtmo = min(hitInfo.y, SceneDepth - nearAtmo);*/
		
		//float3 rayOrigin = _ViewPosition.xyz - _PlanetPos.xyz;
		//float3 pointInAtmo = rayOrigin + rayDir * (nearAtmo + 0.0001);
		
		//float3 skyViewColor = SampleSkyViewLUT(pointInAtmo, rayDir, planetOrigin);

		//float4 result = lerp(color, float4(skyViewColor, 1.0), int(farAtmo > 0.0));

		//this isn't working, it seems like I'm not getting the near and far correctly
		//return result;
		//return color;
		//return farAtmo / (_AtmoRadiusReal * 2);
		//float3 test = hitInfo.y;
		//return float4(test, 1.0);
		//return float4(1.0 - color.rgb, 1.0);
		
		//return float4(hitInfo.x, hitInfo.x, hitInfo.x, 1.0);
		//return color;
    }

    ENDHLSL

    SubShader
    {
        Pass
        {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
                #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}

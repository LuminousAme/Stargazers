Shader "FullScreen/LuminanceAtmosphere"
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

	float4 _ViewPosition; //w unused
	float4 _AdjustViewPosition; //w unused
	float4 _SunDirection; //w unused
	sampler2D _transLut;
	sampler2D _multiScatLut;
	float _GroundRadiusReal;
	float _AtmoRadiusReal;
	float4 _PlanetPos;

	//planet data
	float groundRadius;
	float atmosphereRadius;
	float g;
	float scale;

	// Scattering data
	//w or a component is used for height falloff and scale
	float4 rayleighScattering;
	float4 rayleighAbsorb;
	float4 mieScattering;
	float4 mieAbsorb;
	float4 ozoneAbsorb;

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

	//function to sample the transmittance lut 
	float3 sampleLUT(sampler2D lut, float3 pos, float3 sunDir)
	{
		float height = length(pos);
		float3 up = pos / height;

		float sunCosZenithAngle = dot(sunDir, up);

		float2 uvs = float2(
			clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
			max(0.0, min(1.0, (height - groundRadius) / (atmosphereRadius - groundRadius)))
			);

		return tex2Dlod(lut, float4(uvs, 0, 0)).rgb;
	}

	//function that calculates the ammount of light that is being either absorbed or scattered away at a given point
	float3 computeExtinction(float3 pos)
	{
		float altitude = (length(pos) - groundRadius) * 1000.0;

		float rayleighDensity = exp(-altitude / rayleighScattering.w);
		float mieDensity = exp(-altitude / mieScattering.w);

		float3 rayleighScat = rayleighScattering.rgb * rayleighDensity;
		float3 mieScat = mieScattering.rgb * mieDensity;

		float3 rayAbsorbtion = rayleighAbsorb.rgb * rayleighDensity;
		float3 mieAbsorbtion = mieAbsorb.rgb * mieDensity;
		float3 ozoneAbsorbtion = ozoneAbsorb.rgb * ozoneAbsorb.w * max(0.0, 1.0 - abs(altitude - 25.0) / 15.0);

		return rayleighScat + rayAbsorbtion + mieScat + mieAbsorbtion + ozoneAbsorbtion;
	}

	float3 computeRayleightScat(float3 pos)
	{
		float altitude = (length(pos) - groundRadius) * 1000.0;
		float rayleighDensity = exp(-altitude / rayleighScattering.w);
		return rayleighScattering.rgb * rayleighDensity;
	}

	float3 computeMieScat(float3 pos)
	{
		float altitude = (length(pos) - groundRadius) * 1000.0;
		float mieDensity = exp(-altitude / mieScattering.w);
		return mieScattering.rgb * mieDensity;
	}

	//get the mie particle phase value
	float calcMiePhase(float cosTheta)
	{
		float numerator = (1.0 - g * g) * (1.0 + cosTheta * cosTheta);
		float denominator = (2.0 + g * g) * pow(abs((1.0 + g * g - 2.0 * g * cosTheta)), 1.5);

		return scale * numerator / denominator;
	}

	//get the rayleigh particle phase value
	float calcRayleighPhase(float cosTheta)
	{
		//float PI = 3.141592654;
		float K = 3.0 / (16.0 * PI);
		return K * (1.0 + cosTheta * cosTheta);
	}

	//do a single instance of the scattering integral
	float3 raymarchScatter(float3 pos, float3 rayDir, float3 sunDir, float maxDistance)
	{
		float cosTheta = dot(rayDir, sunDir);
		float miePhaseValue = calcMiePhase(cosTheta);
		float raylieghtPhaseValue = calcRayleighPhase(-cosTheta);

		//raymarching
		float3 lum = float3(0.0, 0.0, 0.0);
		float3 transmittance = float3(1.0, 1.0, 1.0);
		float t = 0.0;
		for (float i = 0.0; i < 32.0; i += 1.0)
		{
			float newT = ((i + 0.3) / 32.0) * maxDistance;
			float dt = newT - t;
			t = newT;

			float3 newPos = pos + rayDir * t; //seems something is going wrong with this value

			float3 rayleighScat = computeRayleightScat(newPos);
			float3 mieScat = computeMieScat(newPos);

			float3 extinction = computeExtinction(newPos);

			float3 sampleTransmittance = exp(-dt * extinction);

			float3 sunTransmittance = sampleLUT(_transLut, newPos, sunDir);
			float3 psi = sampleLUT(_multiScatLut, newPos, sunDir);

			float3 rayleighInScattering = rayleighScat * (raylieghtPhaseValue * sunTransmittance + psi);
			float3 mieInScattering = mieScat * (miePhaseValue * sunTransmittance + psi);
			float3 inScattering = rayleighInScattering + mieInScattering;

			//integrate
			float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;
			lum += scatteringIntegral * transmittance;
			transmittance *= sampleTransmittance;
		}

		return lum;
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
		float3 viewDir = -viewDirection; //this is negative because unity has this vector inverted (pointed towards the camera not away from it) for some reason
		float3 rayDir = normalize(viewDir);

		float SceneDepth = posInput.linearDepth;
		float3 planetOrigin = _PlanetPos.xyz;
		float3 sunDir = _SunDirection.xyz;

		float2 hitInfo = raySphereIntsect(rayOrigin, rayDir, planetOrigin, _AtmoRadiusReal);
		float nearAtmo = hitInfo.x;
		float farAtmo = min(hitInfo.y, SceneDepth - nearAtmo);

		if (farAtmo > 0) {
			float3 adjustedRayOrigin = _AdjustViewPosition.xyz;
			float atmoEdge = raySphereIntsect(adjustedRayOrigin, rayDir, float3(0.0, 0.0, 0.0), atmosphereRadius).x;
			float upOffset = -1e-3;
			float3 newViewPos = adjustedRayOrigin + atmoEdge * rayDir + upOffset;

			float atmoDist = raySphereIntsect(newViewPos, rayDir, float3(0.0, 0.0, 0.0), atmosphereRadius).x;
			float groundDist = raySphereIntsect(newViewPos, rayDir, float3(0.0, 0.0, 0.0), groundRadius).x;
			float maxDist = (groundDist < 0.0) ? atmoDist : groundDist;

			float3 lum = raymarchScatter(newViewPos, rayDir, sunDir, maxDist);
			return float4(lum, 1.0);
		}
		return float4(0.0, 0.0, 0.0, 1.0);
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

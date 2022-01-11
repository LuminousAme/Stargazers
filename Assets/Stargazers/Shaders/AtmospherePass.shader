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
	sampler2D _TransLut;
	sampler2D _MultiscatLut;
	float4 _ViewPosition; //w unused
	float4 _SunDirection; //w unused
	float _GroundRadiusMM;
	float _AtmoRadiusMM;
	float _GroundRadiusReal;
	float _AtmoRadiusReal;
	float4 _PlanetPos;
	float _intensity;
	float g;
	float scale;

	// Scattering data
	//w or a component is used for height falloff and scale
	float4 rayleighScattering;
	float4 rayleighAbsorb;
	float4 mieScattering;
	float4 mieAbsorb;
	float4 ozoneAbsorb;

	//gets the sign of a float
	float GetSign(float num) {
		return lerp(-1.0, 1.0, int(num >= 0));
	}

	//inverse lerp function
	float InverseLerp(float a, float b, float value) {
		return (value - a) / (b - a);
	}

	//remap function
	float ReMap(float oldMin, float oldMax, float newMin, float newMax, float value) {
		float t = InverseLerp(oldMin, oldMax, value);
		return lerp(newMin, newMax, t);
	}

	//gets a value from the sky view lut
	float3 SampleSkyViewLUT(float3 rayOrigin, float3 rayDir, float3 spherePosition) {
		//get the position relative to the planet
		float3 offset = rayOrigin - spherePosition; 

		//convert the offset to be in the correct units
		float3 offSetDir = normalize(offset);
		float dist = ReMap(_GroundRadiusReal, _AtmoRadiusReal, _GroundRadiusMM, _AtmoRadiusMM, length(offset));
		offset = offSetDir * dist;

		//do the rest of the lookup 
		float3 sunDir = _SunDirection.xyz;
		float height = length(offset);
		float3 up = offset / height;

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

	//check if a ray is intersecting a sphere and by how much
	float raySphereIntersect(float3 rayOrigin, float3 rayDirection, float rad)
	{
		float b = dot(rayOrigin, rayDirection);
		float c = dot(rayOrigin, rayOrigin) - rad * rad;

		float result = 0.0;

		float discrimnate = b * b - c;

		//if it's the special case, set result to the special case, otherwise set it to the normal case
		result = (discrimnate > b* b) ? (-b + sqrt(discrimnate)) : (-b - sqrt(discrimnate));
		//check if it should be negative one, if it is, set result to that, otherwise keep the value from the above
		result = ((c > 0.0 && b > 0.0) || discrimnate < 0.0) ? -1.0 : result;

		//return the result
		return result;
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
		//float2 result = lerp(float2(nearDist, farDist - nearDist), float2(1e36, 0), failed);
		float2 result = (failed) ? float2(1e36, 0) : float2(nearDist, farDist - nearDist);
		return result;
	}

	//based on the following video by Martin Donald https://youtu.be/OCZTVpfMSys
	float2 altRaySphere(float3 rayOrigin, float3 rayDir, float3 spherePosition, float rad, float maxDistance) {
		float t = dot(spherePosition - rayOrigin, rayDir);
		float3 P = rayOrigin + rayDir * t;
		float y = length(spherePosition - P);

		if (y > rad) {
			return float2(-1.0, -1.0);
		}

		float x = sqrt(rad * rad - y * y);
		float t1 = max(t - x, 0.0);
		float t2 = min(t + x, maxDistance);

		return float2(t1, t2);
	}

	//function that calculates the ammount of light that is being either absorbed or scattered away at a given point
	float3 computeExtinction(float3 pos)
	{
		float altitude = (length(pos) - _GroundRadiusMM) * 1000.0;

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
		float altitude = (length(pos) - _GroundRadiusMM) * 1000.0;
		float rayleighDensity = exp(-altitude / rayleighScattering.w);
		return rayleighScattering.rgb * rayleighDensity;
	}

	float3 computeMieScat(float3 pos)
	{
		float altitude = (length(pos) - _GroundRadiusMM) * 1000.0;
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

	//function to sample the transmittance or multiscat lut 
	float3 sampleLUT(sampler2D lut, float3 pos, float3 sunDir)
	{
		float height = length(pos);
		float3 up = pos / height;

		float sunCosZenithAngle = dot(sunDir, up);

		float2 uvs = float2(
			clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
			max(0.0, min(1.0, (height - _GroundRadiusMM) / (_AtmoRadiusMM - _GroundRadiusMM)))
			);

		return tex2Dlod(lut, float4(uvs, 0.0, 0.0)).rgb;
	}

	//do a single instance of the scattering integral
	float3 raymarchScatter(float3 pos, float3 rayDir, float3 sunDir, float maxDistance)
	{
		float cosTheta = dot(rayDir, sunDir);
		float miePhaseValue = calcMiePhase(cosTheta);
		float raylieghtPhaseValue = calcRayleighPhase(-cosTheta);
		float STEPS = 32;

		//raymarching
		float3 lum = float3(0.0, 0.0, 0.0);
		float3 transmittance = float3(1.0, 1.0, 1.0);
		float t = 0.0;
		for (float i = 0.0; i < STEPS; i += 1.0)
		{
			float newT = ((i + 0.3) / STEPS) * maxDistance;
			float dt = newT - t;
			t = newT;

			float3 newPos = pos + rayDir * t; //seems something is going wrong with this value

			float3 rayleighScat = computeRayleightScat(newPos);
			float3 mieScat = computeMieScat(newPos);

			float3 extinction = computeExtinction(newPos);

			float3 sampleTransmittance = exp(-dt * extinction);

			float3 sunTransmittance = sampleLUT(_TransLut, newPos, sunDir);
			float3 psi = sampleLUT(_MultiscatLut, newPos, sunDir);

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
		float3 rayOrigin = _WorldSpaceCameraPos;
		float3 viewDir = -viewDirection; //this is negative because unity has this vector inverted (pointed towards the camera not away from it) for some reason
		float3 rayDir = normalize(viewDir);

		float SceneDepth = LinearEyeDepth(depth, _ZBufferParams);
		float3 planetOrigin = _PlanetPos.xyz;

		float2 hitInfo = altRaySphere(rayOrigin, rayDir, planetOrigin, _AtmoRadiusReal, SceneDepth);
		float nearAtmo = hitInfo.x;
		float farAtmo = hitInfo.y;

		float3 relativeRayOrigin = rayOrigin - planetOrigin;
		float3 relativeRayOriginDir = normalize(relativeRayOrigin);
		float relativeDistance = ReMap(_GroundRadiusReal, _AtmoRadiusReal, _GroundRadiusMM, _AtmoRadiusMM, length(relativeRayOrigin));
		relativeRayOrigin = relativeRayOriginDir * relativeDistance;
		
		float atmoEdge = altRaySphere(relativeRayOrigin, rayDir, float3(0.0, 0.0, 0.0), _AtmoRadiusMM, 1e36);
		bool outOfAtmo = length(relativeRayOrigin) >= _AtmoRadiusMM;
		float3 upOffset = relativeRayOriginDir * -1e-3;
		float3 pointInAtmo = (outOfAtmo && atmoEdge >= 0.0) ? relativeRayOrigin + atmoEdge * rayDir + upOffset : relativeRayOrigin;

		float groundDist = raySphereIntersect(pointInAtmo, rayDir, _GroundRadiusMM);
		float atmoDist = raySphereIntersect(pointInAtmo, rayDir, _AtmoRadiusMM);
		float maxDist = (groundDist < 0.0) ? atmoDist : groundDist;

		float3 sunDir = normalize(_SunDirection.xyz);
		
		float3 lumColor = float3(0.0, 0.0, 0.0);

		if (farAtmo > 0.0) {
			lumColor = raymarchScatter(pointInAtmo, rayDir, sunDir, maxDist) * _intensity;
		}
		float3 result = color.rgb + lumColor * _intensity;
		result = color.rgb * (1 - lumColor) + lumColor;

		float3 farAtmoVec = farAtmo / (_AtmoRadiusReal * 2);

		float3 depthVec = Linear01Depth(depth, _ZBufferParams) * length(viewDirection);
		
		float3 blep = (nearAtmo < SceneDepth) ? float3(1.0, 1.0, 1.0) : float3(0.0, 0.0, 0.0);
		return float4(result, 1.0);
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

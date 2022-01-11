Shader "Hidden/Shader/LumienceAtmosphere"
{
    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"
	//#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShadersVariablesFunctions.hlsl"

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    // List of properties to control your post process effect
	float4 _SunDirection; //w unused
	TEXTURE2D_X(_transLut);
	TEXTURE2D_X(_multiScatLut);
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

	float LinearEyeDepth(float z)
	{
		return 1.0 / (_ZBufferParams.z * z + _ZBufferParams.w);
	}

	float InverseLerp(float a, float b, float value) {
		return (value - a) / (b - a);
	}

	float Lerp(float a, float b, float t) {
		return (1.0f - t) * a + b * t;
	}

	float ReMap(float oldMin, float oldMax, float newMin, float newMax, float value) {
		float t = InverseLerp(oldMin, oldMax, value);
		return Lerp(newMin, newMax, t);
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

	//function to sample the transmittance lut 
	float3 sampleTLUT(float3 pos, float3 sunDir)
	{
		float height = length(pos);
		float3 up = pos / height;

		float sunCosZenithAngle = dot(sunDir, up);

		float2 uvs = float2(
			clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
			max(0.0, min(1.0, (height - groundRadius) / (atmosphereRadius - groundRadius)))
			);

		float2 TLutSize = float2(256.0, 64.0);
		uint2 samplePos = uint2(uvs * TLutSize);

		return LOAD_TEXTURE2D_X(_multiScatLut, samplePos).rgb;
	}

	float3 sampleMLUT(float3 pos, float3 sunDir)
	{
		float height = length(pos);
		float3 up = pos / height;

		float sunCosZenithAngle = dot(sunDir, up);

		float2 uvs = float2(
			clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
			max(0.0, min(1.0, (height - groundRadius) / (atmosphereRadius - groundRadius)))
			);

		float2 MLutSize = float2(32.0, 32.0);
		uint2 samplePos = uint2(uvs * MLutSize);

		return LOAD_TEXTURE2D_X(_multiScatLut, samplePos).rgb;
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

			//float3 sunTransmittance = sampleLUT(_transLut, newPos, sunDir);
			float3 sunTransmittance = sampleTLUT(newPos, sunDir);
			//float3 psi = sampleLUT(_multiScatLut, newPos, sunDir);
			float3 psi = sampleMLUT(newPos, sunDir);

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

	float GetLogDepth(uint2 samplePosition) {
		return LOAD_TEXTURE2D_X(_CameraDepthTexture, samplePosition).r;
	}


	float GetDepth(uint2 samplePosition) {
		return LinearEyeDepth(GetLogDepth(samplePosition));
	}

    float4 CustomPostProcess(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

        uint2 positionSS = input.texcoord * _ScreenSize.xy;

		float3 rayOrigin = GetPrimaryCameraPosition();
		PositionInputs posInput = GetPositionInput(positionSS, _ScreenSize.zw, GetLogDepth(positionSS), UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

		float3 viewDir = -GetWorldSpaceNormalizeViewDir(posInput.positionWS); //taking the negative here because 
		float3 rayDir = normalize(viewDir);

		float SceneDepth = GetDepth(positionSS);
		float3 planetOrigin = _PlanetPos.xyz;
		float3 sunDir = _SunDirection.xyz;

		float2 hitInfo = raySphereIntsect(rayOrigin, rayDir, planetOrigin, _AtmoRadiusReal);
		float nearAtmo = hitInfo.x;
		float farAtmo = min(hitInfo.y, SceneDepth - nearAtmo);

		if (farAtmo > 0) {

			float3 adjustedRayOrigin = rayOrigin - planetOrigin;
			float3 adjustedOriginDir = normalize(adjustedRayOrigin);
			float adjustingDistance = ReMap(_GroundRadiusReal, _AtmoRadiusReal, groundRadius, atmosphereRadius, length(adjustedRayOrigin));
			adjustedRayOrigin = adjustedOriginDir * adjustingDistance;

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
            Name "LumienceAtmosphere"

            ZWrite Off
            ZTest Always
            Blend Off
            Cull Off

            HLSLPROGRAM
                #pragma fragment CustomPostProcess
                #pragma vertex Vert
            ENDHLSL
        }
    }
    Fallback Off
}

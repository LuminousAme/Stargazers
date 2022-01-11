using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using System;

/*
[Serializable, VolumeComponentMenu("Post-processing/Custom/AtmospherePostProcess")]
public sealed class AtmospherePostProcess : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    //[Tooltip("Controls the intensity of the effect.")]
    //public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);
    public ClampedIntParameter TextureWidth = new ClampedIntParameter(213, 32, 1920);
    public ClampedIntParameter TextureHeight = new ClampedIntParameter(120, 32, 1080);
    

    [HideInInspector] public Vector4Parameter sunDirection = new Vector4Parameter(new Vector4());
    [HideInInspector] public RenderTextureParameter transLUT = new RenderTextureParameter(new RenderTexture(2, 2, 0));
    [HideInInspector] public RenderTextureParameter multiScatLUT = new RenderTextureParameter(new RenderTexture(2,2,0));
    [HideInInspector] public FloatParameter GroundRadiusReal = new FloatParameter(0f);
    [HideInInspector] public FloatParameter AtmoRadiusReal = new FloatParameter(0f);
    [HideInInspector] public Vector4Parameter PlanetPos = new Vector4Parameter(new Vector4());
    [HideInInspector] public FloatParameter groundRadiusMM = new FloatParameter(0f);
    [HideInInspector] public FloatParameter AtmoRadiusMM = new FloatParameter(0f);
    [HideInInspector] public FloatParameter g = new FloatParameter(0f);
    [HideInInspector] public FloatParameter scale = new FloatParameter(0f);
    [HideInInspector] public Vector4Parameter rayleighScattering = new Vector4Parameter(new Vector4());
    [HideInInspector] public Vector4Parameter rayleighAbsorb = new Vector4Parameter(new Vector4());
    [HideInInspector] public Vector4Parameter mieScattering = new Vector4Parameter(new Vector4());
    [HideInInspector] public Vector4Parameter mieAbsorb = new Vector4Parameter(new Vector4());
    [HideInInspector] public Vector4Parameter ozoneAbsorb = new Vector4Parameter(new Vector4());
    [HideInInspector] public FloatParameter lumienceFactor = new FloatParameter(0f);

    Material m_firstMat, m_SecondMat;
    RTHandleSystem RTS = new RTHandleSystem();
    RenderTexture LumeTexture;
    RTHandle lumeTextureHandle;

    public bool IsActive() => m_firstMat != null && m_SecondMat != null && LumeTexture != null && lumeTextureHandle != null && transLUT != null && multiScatLUT != null;

    // Do not forget to add this post process in the Custom Post Process Orders list (Project Settings > HDRP Default Settings).
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.BeforePostProcess;

    const string firstShaderName = "Hidden/Shader/LumienceAtmosphere";
    const string secondShaderName = "Hidden/Shader/ApplyAtmosphere";

    public override void Setup()
    {
        if (Shader.Find(firstShaderName) != null)
            m_firstMat = new Material(Shader.Find(firstShaderName));
        else
            Debug.LogError($"Unable to find shader '{firstShaderName}'. Post Process Volume AtmospherePostProcess is unable to load.");
        if (Shader.Find(secondShaderName) != null)
            m_SecondMat = new Material(Shader.Find(secondShaderName));
        else
            Debug.LogError($"Unable to find shader '{secondShaderName}'. Post Process Volume AtmospherePostProcess is unable to load.");

        LumeTexture = new RenderTexture(TextureWidth.value, TextureHeight.value, 0);
        LumeTexture.enableRandomWrite = true;
        LumeTexture.Create();
        lumeTextureHandle = RTS.Alloc(LumeTexture);
    }

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        if (m_firstMat == null) Debug.Log("First mat null");
        if (m_SecondMat == null) Debug.Log("Second mat null");
        if (LumeTexture == null) Debug.Log("Texture null");
        if (lumeTextureHandle == null) Debug.Log("Handle null");
        if (transLUT.value == null) Debug.Log("trans lut null");
        if (multiScatLUT.value == null) Debug.Log("Multiscat lut null");

        Debug.Log($"Sun dir in post effect: {sunDirection.value}");

        if (m_firstMat == null || m_SecondMat == null || LumeTexture == null || lumeTextureHandle == null || transLUT == null || multiScatLUT == null)
        {
            return;
        }
        
            
        m_firstMat.SetVector("_SunDirection", sunDirection.value);
        m_firstMat.SetTexture("_transLut", transLUT.value);
        m_firstMat.SetTexture("_multiScatLut", multiScatLUT.value);
        m_firstMat.SetFloat("_GroundRadiusReal", GroundRadiusReal.value);
        m_firstMat.SetFloat("_AtmoRadiusReal", AtmoRadiusReal.value);
        m_firstMat.SetVector("_PlanetPos", PlanetPos.value);
        m_firstMat.SetFloat("groundRadius", groundRadiusMM.value);
        m_firstMat.SetFloat("atmosphereRadius", AtmoRadiusMM.value);
        m_firstMat.SetFloat("g", g.value);
        m_firstMat.SetFloat("scale", scale.value);
        m_firstMat.SetVector("rayleighScattering", rayleighScattering.value);
        m_firstMat.SetVector("rayleighAbsorb", rayleighAbsorb.value);
        m_firstMat.SetVector("mieScattering", mieScattering.value);
        m_firstMat.SetVector("mieAbsorb", mieAbsorb.value);
        m_firstMat.SetVector("ozoneAbsorb", ozoneAbsorb.value);

        //HDUtils.DrawFullScreen(cmd, m_firstMat, lumeTextureHandle);
        Debug.Log("executing");

        m_SecondMat.SetFloat("_Intensity", lumienceFactor.value);
        m_SecondMat.SetInt("_LumienceTextureWidth", lumeTextureHandle.rt.width);
        m_SecondMat.SetInt("_LumienceTextureHeight", lumeTextureHandle.rt.height);
        m_SecondMat.SetTexture("_InputTexture", source);
        m_SecondMat.SetTexture("_LuminenceTexture", lumeTextureHandle);
        
        HDUtils.DrawFullScreen(cmd, m_SecondMat, destination);
    }

    public override void Cleanup()
    {
        CoreUtils.Destroy(m_firstMat);
        CoreUtils.Destroy(m_SecondMat);
        if(LumeTexture != null) LumeTexture.Release();
    }
}*/
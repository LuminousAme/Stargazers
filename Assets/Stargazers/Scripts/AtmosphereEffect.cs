using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(menuName = "Atlas X Games/Atmosphere Effect")]
public class AtmosphereEffect : ScriptableObject
{
    //shaders
    [SerializeField] private ComputeShader transmittanceShader;
    [SerializeField] private ComputeShader multiScatShader;
    [SerializeField] private ComputeShader aerialViewShader;
    [SerializeField] private ComputeShader skyViewShader;

    //textures
    public RenderTexture transLUT;
    public RenderTexture multiScatLUT;
    public RenderTexture aerialViewLUT;
    public RenderTexture skyViewLUT;

    //flags
    private bool transLUTDirty = true;
    private bool multiScatLUTDirty = true;
    private bool aerialViewLUTDirty = true;
    private bool skyViewLUTDirty = true;

    //settings for the various textures
    [Space]
    [Header("Transmittance Settings")]
    public float groundRadiusMM;
    public float atmosphereRadiusMM;
    [SerializeField] private Vector4 rayleighScattering;
    [SerializeField] private Vector4 rayleighAbsorb;
    [SerializeField] private Vector4 mieScattering;
    [SerializeField] private Vector4 mieAbsorb;
    [SerializeField] private Vector4 ozoneAbsorb;

    [Space]
    [Header("Multiple Scattering Settings")]
    [SerializeField] private float g;
    [SerializeField] private float scale;
    [SerializeField] private Vector3 albedo;

    //Aerial View settings, will be updated automatically by other scripts using setters
    private Vector3 cameraPos;
    private Vector3 viewPos; //seriously what is the difference between these???
    private Vector3 SunDirection;
    private float nearPlane;
    private float farPlane;
    private Matrix4x4 inverseVP;

    //skyview doesn't need any data that the others don't already have

    private void OnEnable() => Init();
    private void OnDisable() => Shutdown();

    public void Init()
    {
        if(transLUT == null)
        {
            transLUT = new RenderTexture(256, 64, 0);
            transLUT.enableRandomWrite = true;
            transLUT.Create();
        }

        if(multiScatLUT == null)
        {

            multiScatLUT = new RenderTexture(32, 32, 0);
            multiScatLUT.enableRandomWrite = true;
            multiScatLUT.Create();
        }

        if(aerialViewLUT == null)
        {
            //3D render texture
            RenderTextureDescriptor aerialDescriptor = new RenderTextureDescriptor(32, 32);
            aerialDescriptor.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
            aerialDescriptor.volumeDepth = 32;
            aerialViewLUT = new RenderTexture(aerialDescriptor);
            aerialViewLUT.enableRandomWrite = true;
            aerialViewLUT.Create();
        }

        if(skyViewLUT == null)
        {
            skyViewLUT = new RenderTexture(256, 128, 0);
            skyViewLUT.enableRandomWrite = true;
            skyViewLUT.Create();
        }

        SetAllDirty();
    }

    public void Shutdown()
    {
        Debug.Log("Hit");
      
        if(transLUT != null) transLUT.Release();
        if (multiScatLUT != null) multiScatLUT.Release();
        if(aerialViewLUT != null) aerialViewLUT.Release();
        if(skyViewLUT != null) skyViewLUT.Release();
    }

    public void Render()
    {
        Init();

        //only render if the textures exist 
        if(transLUT != null && aerialViewLUT != null && multiScatLUT != null && skyViewLUT != null)
        {
            //if the transmittance lut is dirty then render it
            if(transmittanceShader != null && transLUTDirty)
            {
                transmittanceShader.SetTexture(0, "Result", transLUT);
                transmittanceShader.SetVector2("textureResolution", new Vector2(transLUT.width, transLUT.height));
                transmittanceShader.SetFloat("groundRadius", groundRadiusMM);
                transmittanceShader.SetFloat("atmosphereRadius", atmosphereRadiusMM);
                transmittanceShader.SetVector("rayleighScattering", rayleighScattering);
                transmittanceShader.SetVector("rayleighAbsorb", rayleighAbsorb);
                transmittanceShader.SetVector("mieScattering", mieScattering);
                transmittanceShader.SetVector("mieAbsorb", mieAbsorb);
                transmittanceShader.SetVector("ozoneAbsorb", ozoneAbsorb);

                transmittanceShader.Dispatch(0, transLUT.width / 8, transLUT.height / 8, 1);

                transLUTDirty = false;
            }

            //if the multsicat lut is dirty then render it
            if(multiScatShader != null && multiScatLUTDirty)
            {
                multiScatShader.SetTexture(0, "Result", multiScatLUT);
                multiScatShader.SetTexture(0, "transLut", transLUT);
                multiScatShader.SetVector2("TextureResolution", new Vector2(multiScatLUT.width, multiScatLUT.height));
                multiScatShader.SetFloat("groundRadius", groundRadiusMM);
                multiScatShader.SetFloat("atmosphereRadius", atmosphereRadiusMM);
                multiScatShader.SetFloat("g", g);
                multiScatShader.SetFloat("scale", scale);
                multiScatShader.SetVector3("albedo", albedo);
                multiScatShader.SetVector("rayleighScattering", rayleighScattering);
                multiScatShader.SetVector("rayleighAbsorb", rayleighAbsorb);
                multiScatShader.SetVector("mieScattering", mieScattering);
                multiScatShader.SetVector("mieAbsorb", mieAbsorb);
                multiScatShader.SetVector("ozoneAbsorb", ozoneAbsorb);

                //best guess on this
                multiScatShader.Dispatch(0, multiScatLUT.width / 8, multiScatLUT.height / 8, 1);
                multiScatLUTDirty = false;
            }

            //if the aerialview lut is dirty then render it
            if(aerialViewShader != null && aerialViewLUTDirty)
            {
                aerialViewShader.SetTexture(0, "Result", aerialViewLUT);
                aerialViewShader.SetTexture(0, "transLut", transLUT);
                aerialViewShader.SetTexture(0, "multiscatLut", multiScatLUT);
                aerialViewShader.SetVector3("TextureResolution", new Vector3(aerialViewLUT.width, aerialViewLUT.height, aerialViewLUT.volumeDepth));
                aerialViewShader.SetFloat("groundRadius", groundRadiusMM);
                aerialViewShader.SetFloat("atmosphereRadius", atmosphereRadiusMM);
                aerialViewShader.SetFloat("g", g);
                aerialViewShader.SetFloat("scale", scale);
                aerialViewShader.SetVector3("albedo", albedo);
                aerialViewShader.SetVector3("sunDirection", SunDirection);
                aerialViewShader.SetVector3("viewPos", viewPos);
                aerialViewShader.SetVector3("cameraPos", cameraPos);
                aerialViewShader.SetMatrix("inverseVP", inverseVP);
                aerialViewShader.SetFloat("near", nearPlane);
                aerialViewShader.SetFloat("far", farPlane);
                aerialViewShader.SetVector("rayleighScattering", rayleighScattering);
                aerialViewShader.SetVector("rayleighAbsorb", rayleighAbsorb);
                aerialViewShader.SetVector("mieScattering", mieScattering);
                aerialViewShader.SetVector("mieAbsorb", mieAbsorb);
                aerialViewShader.SetVector("ozoneAbsorb", ozoneAbsorb);

                aerialViewShader.Dispatch(0, aerialViewLUT.width / 8, aerialViewLUT.height / 8, aerialViewLUT.volumeDepth / 8);
                aerialViewLUTDirty = false;
            }

            //if the skyview lut is dirty then render it
            if(skyViewShader != null && skyViewLUTDirty)
            {
                skyViewShader.SetTexture(0, "Result", skyViewLUT);
                skyViewShader.SetTexture(0, "transLut", transLUT);
                skyViewShader.SetTexture(0, "multiscatLut", multiScatLUT);
                skyViewShader.SetVector2("TextureResolution", new Vector2(skyViewLUT.width, skyViewLUT.height));
                skyViewShader.SetFloat("groundRadius", groundRadiusMM);
                skyViewShader.SetFloat("atmosphereRadius", atmosphereRadiusMM);
                skyViewShader.SetFloat("g", g);
                skyViewShader.SetFloat("scale", scale);
                skyViewShader.SetVector3("albedo", albedo);
                skyViewShader.SetVector3("sunDirection", SunDirection);
                skyViewShader.SetVector3("viewPos", viewPos);
                skyViewShader.SetVector("rayleighScattering", rayleighScattering);
                skyViewShader.SetVector("rayleighAbsorb", rayleighAbsorb);
                skyViewShader.SetVector("mieScattering", mieScattering);
                skyViewShader.SetVector("mieAbsorb", mieAbsorb);
                skyViewShader.SetVector("ozoneAbsorb", ozoneAbsorb);

                skyViewShader.Dispatch(0, skyViewLUT.width / 8, skyViewLUT.height / 8, 1);

                skyViewLUTDirty = false;
            }

        }
    }

    public void ForceRender()
    {
        SetAllDirty();
        Render();
    }

    private void SetAllDirty()
    {
        transLUTDirty = true;
        multiScatLUTDirty = true;
        aerialViewLUTDirty = true;
        skyViewLUTDirty = true;
    }

    public void SetCamPos(Vector3 newCamPos)
    {
        if (newCamPos != cameraPos)
        {
            cameraPos = newCamPos;
            aerialViewLUTDirty = true;
        }
    }

    public void SetViewPos(Vector3 newViewPos)
    {
        if (newViewPos != viewPos)
        {
            viewPos = newViewPos;
            aerialViewLUTDirty = true;
            skyViewLUTDirty = true;
        }
    }

    public void SetSunDir(Vector3 newSunDir)
    {
        if (newSunDir != SunDirection)
        {
            SunDirection = newSunDir;
            aerialViewLUTDirty = true;
            skyViewLUTDirty = true;
        }
    }

    public void SetNearPlane(float newNearPlane)
    {
        if (newNearPlane != nearPlane)
        {
            nearPlane = newNearPlane;
            aerialViewLUTDirty = true;
        }
    }

    public void SetFarPlane(float newFarPlane)
    {
        if (newFarPlane != farPlane)
        {
            farPlane = newFarPlane;
            aerialViewLUTDirty = true;
        } 
    }

    public void SetInverseVP(Matrix4x4 newInverseVP)
    {
        if (newInverseVP != inverseVP)
        {
            inverseVP = newInverseVP;
            aerialViewLUTDirty = true;
        }
    }
}
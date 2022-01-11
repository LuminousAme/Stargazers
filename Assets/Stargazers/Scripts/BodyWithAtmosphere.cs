using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

[ExecuteAlways]
public class BodyWithAtmosphere : MonoBehaviour
{
    public AtmosphereEffect effect;
    public Material skyviewMat;
    //public Material luminenceMat;
    //[SerializeField] private Volume postProcessingVolume;
    //private AtmospherePostProcess atmoRenderer;

    [SerializeField] private Transform sun;
    [SerializeField] private float PlanetRadiusReal = 750;
    [SerializeField] private float AtmoRadiusReal = 1000f;


    // Update is called once per frame
    void Update()
    {
        // if(postProcessingVolume != null)
        {
            //AtmospherePostProcess temp;
            // if (postProcessingVolume.profile.TryGet(out temp)) atmoRenderer = temp;
            //  }

            if (sun != null && effect != null && skyviewMat != null)
            {
                //direction of the sun
                Vector3 sunDir = Vector3.Normalize(transform.position - sun.position);

                //calculating the view pos for the atmosphere effect
                Vector3 relativeCamPos = Camera.main.transform.position - transform.position;
                Vector3 relativeCamDir = relativeCamPos.normalized;
                float dist = MathAlt.ReMap(PlanetRadiusReal, AtmoRadiusReal, effect.groundRadiusMM, effect.atmosphereRadiusMM, relativeCamPos.magnitude);
                Vector3 atmoViewPos = relativeCamDir * dist; //gets the view position relative to the planet in the units that the sky view and aerial luts like

                //update the data for the effect
                effect.SetCamPos(atmoViewPos); //need to adjust this to be relative to the planet
                effect.SetViewPos(atmoViewPos);
                effect.SetSunDir(sunDir); //vectoring pointing from the sun to the planet
                effect.SetNearPlane(Camera.main.nearClipPlane);
                effect.SetFarPlane(Camera.main.farClipPlane);
                Matrix4x4 vp = Camera.main.projectionMatrix * Camera.main.worldToCameraMatrix;
                effect.SetInverseVP(vp.inverse);

                //render the effect so the look up tables exist and can be applied as a post processing effect later
                effect.Render();

                /*
                atmoRenderer.sunDirection.value = sunDir.Vec3ToVec4();
                atmoRenderer.transLUT.value = effect.transLUT;
                atmoRenderer.multiScatLUT.value = effect.multiScatLUT;
                atmoRenderer.GroundRadiusReal.value = PlanetRadiusReal;
                atmoRenderer.AtmoRadiusReal.value = AtmoRadiusReal;
                atmoRenderer.PlanetPos.value = transform.position.Vec3ToVec4();
                atmoRenderer.groundRadiusMM.value = effect.groundRadiusMM;
                atmoRenderer.AtmoRadiusMM.value = effect.atmosphereRadiusMM;
                atmoRenderer.g.value = effect.g;
                atmoRenderer.scale.value = effect.scale;
                atmoRenderer.rayleighScattering.value = effect.rayleighScattering;
                atmoRenderer.rayleighAbsorb.value = effect.rayleighAbsorb;
                atmoRenderer.mieScattering.value = effect.mieScattering;
                atmoRenderer.mieAbsorb.value = effect.mieAbsorb;
                atmoRenderer.ozoneAbsorb.value = effect.ozoneAbsorb;
                atmoRenderer.lumienceFactor.value = effect.intensity;*/

                //set the materials settings
                
                skyviewMat.SetTexture("_SkyViewLut", effect.skyViewLUT);
                skyviewMat.SetTexture("_transLut", effect.transLUT);
                skyviewMat.SetTexture("_multiScatLut", effect.multiScatLUT);
                skyviewMat.SetVector("_ViewPosition", Camera.main.transform.position.Vec3ToVec4());
                skyviewMat.SetVector("_SunDirection", sunDir.Vec3ToVec4());
                skyviewMat.SetFloat("_GroundRadiusMM", effect.groundRadiusMM);
                skyviewMat.SetFloat("_AtmoRadiusMM", effect.atmosphereRadiusMM);
                skyviewMat.SetFloat("_GroundRadiusReal", PlanetRadiusReal);
                skyviewMat.SetFloat("_AtmoRadiusReal", AtmoRadiusReal);
                skyviewMat.SetVector("_PlanetPos", transform.position.Vec3ToVec4());
                skyviewMat.SetFloat("_intensity", effect.intensity);
                skyviewMat.SetFloat("g", effect.g);
                skyviewMat.SetFloat("scale", effect.scale);
                skyviewMat.SetVector("rayleighScattering", effect.rayleighScattering);
                skyviewMat.SetVector("rayleighAbsorb", effect.rayleighAbsorb);
                skyviewMat.SetVector("mieScattering", effect.mieScattering);
                skyviewMat.SetVector("mieAbsorb", effect.mieAbsorb);
                skyviewMat.SetVector("ozoneAbsorb", effect.ozoneAbsorb);
                /*
                luminenceMat.SetTexture("_transLut", effect.transLUT);
                luminenceMat.SetTexture("_multiScatLut", effect.multiScatLUT);
                luminenceMat.SetVector("_ViewPosition", Camera.main.transform.position.Vec3ToVec4());
                luminenceMat.SetVector("_AdjustViewPosition", atmoViewPos.Vec3ToVec4());
                luminenceMat.SetFloat("_GroundRadiusReal", PlanetRadiusReal);
                luminenceMat.SetFloat("_AtmoRadiusReal", AtmoRadiusReal);
                luminenceMat.SetVector("_PlanetPos", transform.position.Vec3ToVec4());
                luminenceMat.SetFloat("groundRadius", effect.groundRadiusMM);
                luminenceMat.SetFloat("atmosphereRadius", effect.atmosphereRadiusMM);
                luminenceMat.SetFloat("g", effect.g);
                luminenceMat.SetFloat("scale", effect.scale);
                luminenceMat.SetVector("rayleighScattering", effect.rayleighScattering);
                luminenceMat.SetVector("rayleighAbsorb", effect.rayleighAbsorb);
                luminenceMat.SetVector("mieScattering", effect.mieScattering);
                luminenceMat.SetVector("mieAbsorb", effect.mieAbsorb);
                luminenceMat.SetVector("ozoneAbsorb", effect.ozoneAbsorb);*/
            }
        }
    }
};

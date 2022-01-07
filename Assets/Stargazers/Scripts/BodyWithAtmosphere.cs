using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class BodyWithAtmosphere : MonoBehaviour
{
    public AtmosphereEffect effect;
    public Material skyviewMat;
    [SerializeField] private Transform sun;
    [SerializeField] private float PlanetRadiusReal = 750;
    [SerializeField] private float AtmoRadiusReal = 1000f;

    // Update is called once per frame
    void Update()
    {
        if(sun != null && effect != null && skyviewMat != null)
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

            //set the materials settings
            skyviewMat.SetTexture("_SkyViewLut", effect.skyViewLUT);
            skyviewMat.SetVector("_ViewPosition", Camera.main.transform.position.Vec3ToVec4());
            skyviewMat.SetVector("_SunDirection", sunDir.Vec3ToVec4());
            skyviewMat.SetFloat("_GroundRadiusMM", effect.groundRadiusMM);
            skyviewMat.SetFloat("_AtmoRadiusReal", AtmoRadiusReal);
            skyviewMat.SetVector("_PlanetPos", transform.position.Vec3ToVec4());
        }
    }
}

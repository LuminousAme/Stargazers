using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteAlways]
public class BodyWithAtmosphere : MonoBehaviour
{
    public AtmosphereEffect effect;
    public Material skyviewMat;
    [SerializeField] private Transform sun;
    [SerializeField] private float AtmosphereSizeReal = 3000f;

    // Update is called once per frame
    void Update()
    {
        if(sun != null && effect != null && skyviewMat != null)
        {
            Vector3 sunDir = Vector3.Normalize(transform.position - sun.position);
            Vector3 relativeCamPos = Camera.main.transform.position - transform.position;

            //update the data for the effect
            effect.SetCamPos(relativeCamPos); //need to adjust this to be relative to the planet
            effect.SetViewPos(relativeCamPos);
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
            skyviewMat.SetFloat("_AtmoRadiusReal", AtmosphereSizeReal);
            skyviewMat.SetVector("_PlanetPos", transform.position.Vec3ToVec4());
        }
    }
}

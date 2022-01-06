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
            skyviewMat.SetTexture("Texture", effect.skyViewLUT);
            skyviewMat.SetVector("ViewPos", relativeCamPos);
            skyviewMat.SetVector("SunDir", sunDir);
            skyviewMat.SetFloat("GroundRadiusMM", effect.groundRadiusMM);
            skyviewMat.SetFloat("AtmoRadiusReal", AtmosphereSizeReal);
        }
    }
}

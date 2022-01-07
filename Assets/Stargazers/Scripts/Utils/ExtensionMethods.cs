using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class ExtensionMethods
{
    public static void SetVector2(this ComputeShader c, string name, Vector2 v)
    {
        float[] arr = { v.x, v.y };
        c.SetFloats(name, arr);
    }

    public static void SetVector3(this ComputeShader c, string name, Vector3 v)
    {
        float[] arr = { v.x, v.y, v.z };
        c.SetFloats(name, arr);
    }

    public static Vector4 Vec3ToVec4(this Vector3 v)
    {
        Vector4 v4 = new Vector4(v.x, v.y, v.z, 0f);
        return v4;
    }
}

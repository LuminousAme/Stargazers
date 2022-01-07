using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public static class MathAlt
{
    public static float InverseLerp(float a, float b, float value)
    {
        return (value - a) / (b - a);
    }

    public static float Lerp(float a, float b, float t)
    {
        return (1.0f - t) * a + b * t;
    }

    public static float ReMap(float oldMin, float oldMax, float newMin, float newMax, float value)
    {
        float t = InverseLerp(oldMin, oldMax, value);
        return Lerp(newMin, newMax, t);
    }
}

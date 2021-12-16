using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

//using math from this video: https://youtu.be/Ie5L8Nz1Ns0
public class CelestialBodyDeterministic : MonoBehaviour
{
    static public float gravitationStrenght = 0.02f;
    const float TAU = 6.28318530718f;
    [SerializeField] public float semiMajorAxis = 200; //size of the orbit
    [SerializeField] [Range(0f, 0.99f)] private float eccentricity; //how ellipitical the orbit is
    [SerializeField] [Range(0f, TAU)]  private float inclination; //how much the orbit is titled
    [SerializeField] [Range(0f, TAU)] private float LoAN; //the orbit's swivel 
    [SerializeField] [Range(0f, TAU)] private float AoP; //orbit's rotation
    [SerializeField] private float meanLongitude; //starting offset around the oribt
    [SerializeField] CelestialBodyDeterministic referenceFrame; //what it's orbiting around

    [Space]

    //other assisstance numbers calculated on awake
    [SerializeField] public float mass = 100f;
    [HideInInspector] public float radius;
    private float mu;
    private float n;
    private float tAC;

    [Space]

    //some variables to help figure out values
    [SerializeField] private int maxNewtonIntegrations;
    [SerializeField] private float accurarcyTolerance;

    void Awake()
    {
        radius = 0.5f * transform.localScale.x;
        mu = (referenceFrame != null) ? gravitationStrenght * referenceFrame.mass : gravitationStrenght;
        n = Mathf.Sqrt(mu / Mathf.Pow(semiMajorAxis, 3));
        tAC = Mathf.Sqrt((1 + eccentricity)/(1 - eccentricity));
    }

    // Update is called once per frame
    void Update()
    {
        if (referenceFrame != null)
        {
            //find the mean anomoly
            float meanAnomaly = n * (Time.time - meanLongitude);

            //find the eccentric anomoly (this takes some netwon's method integration
            float E1 = meanAnomaly;
            float difference = 1f;
            //loop over until we either pass the max interations or has an acceptable tolerance
            for(int i = 0; i < maxNewtonIntegrations && difference > accurarcyTolerance; i++)
            {
                float E0 = E1;
                E1 = E0 - (meanAnomaly - E0 + eccentricity * Mathf.Sin(E0)) / (-1f + eccentricity * Mathf.Cos(E0)); //F(x)/F^1(x)
                difference = Mathf.Abs(E1 - E0);
            }
            //a pretty close approximation of the eccentric anomoly
            float eccentricAnomaly = E1;

            //now we can get the true anomly and the distance from the object being orbited
            float trueAnomaly = 2 * Mathf.Atan(tAC * Mathf.Tan(eccentricAnomaly / 2));
            float distanceFromROF = semiMajorAxis * (1 - eccentricity * Mathf.Cos(eccentricAnomaly));

            //update to the new position
            transform.position = get3DPosition(trueAnomaly, distanceFromROF) + referenceFrame.transform.position;
        }
    }

    //I do not understand this math but it supposedly works
    private Vector3 get3DPosition(float ta, float magnitude)
    {
        float firstCos = Mathf.Cos(AoP + ta);
        float firstSin = Mathf.Sin(AoP + ta);

        float secondCos = Mathf.Cos(LoAN);
        float secondSin = Mathf.Sin(LoAN);

        float thirdCos = Mathf.Cos(inclination);
        float thirdSin = Mathf.Sin(inclination);

        float x = magnitude * ((secondCos * firstCos) - (secondSin * firstSin * thirdCos)); // ((2c * 1c) - (2s * 1s * 3c)
        float y = magnitude * (thirdSin * firstSin); // (3s * 1s)
        float z = magnitude * ((secondSin * firstCos) + (secondCos * firstSin * thirdCos)); // (2s * 1c) + (2c * 1s * 3c)

        return new Vector3(x, y, z);
    }

    [Space]

    [SerializeField] int orbitResolution = 50;
    List<Vector3> orbitalPoints = new List<Vector3>();


    public void OnDrawGizmosSelected()
    {
        if(referenceFrame != null)
        {
            if (orbitalPoints.Count == 0)
            {
                Vector3 pos = referenceFrame.transform.position;
                float orbitFraction = 1f / orbitResolution;

                for (int i = 0; i < orbitResolution + 1; i++)
                {
                    float EccentricAnomaly = i * orbitFraction * TAU;

                    float t = Mathf.Sqrt((1 + eccentricity) / (1 - eccentricity));
                    float trueAnomaly = 2 * Mathf.Atan(t * Mathf.Tan(EccentricAnomaly / 2));
                    float distance = semiMajorAxis * (1 - eccentricity * Mathf.Cos(EccentricAnomaly));

                    float cosAOPPlusTA = Mathf.Cos(AoP + trueAnomaly);
                    float sinAOPPlusTA = Mathf.Sin(AoP + trueAnomaly);

                    float secondCos = Mathf.Cos(LoAN);
                    float secondSin = Mathf.Sin(LoAN);

                    float thirdCos = Mathf.Cos(inclination);
                    float thirdSin = Mathf.Sin(inclination);

                    float x = distance * ((secondCos * cosAOPPlusTA) - (secondSin * sinAOPPlusTA * thirdCos));
                    float y = distance * (thirdSin * sinAOPPlusTA);
                    float z = distance * ((secondSin * cosAOPPlusTA) + (secondCos * sinAOPPlusTA * thirdCos));

                    float meanAnomaly = EccentricAnomaly - eccentricity * Mathf.Sin(EccentricAnomaly);

                    orbitalPoints.Add(pos + new Vector3(x, y, z));
                }
            }

            for (int i = 0; i+1 < orbitalPoints.Count; i++)
                Gizmos.DrawLine(orbitalPoints[i], orbitalPoints[i+1]);

            Gizmos.DrawLine(transform.position, referenceFrame.transform.position);

            orbitalPoints.Clear();
        }
    }
}

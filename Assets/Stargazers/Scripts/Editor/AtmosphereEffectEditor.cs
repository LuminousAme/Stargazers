using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(AtmosphereEffect))]
public class AtmosphereEffectEditor : Editor   
{
    public override void OnInspectorGUI()
    {
        GUILayout.Label("Specify fields ending with \"MM\" in megameters");
        GUILayout.Space(10);

        //gives the basic fields that would appear even if there was no custom editor
        base.OnInspectorGUI();

        GUILayout.Space(40);

        GUILayout.Label("Texture Controls", EditorStyles.boldLabel ); 
        //buttons to force texture initlization, generation, and destruction
        if(GUILayout.Button("Init Textures"))
        {
            (target as AtmosphereEffect).Init();
        }
        if(GUILayout.Button("Force Generate Textures"))
        {
            (target as AtmosphereEffect).ForceRender();
        }
        if (GUILayout.Button("Destroy Textures"))
        {
            (target as AtmosphereEffect).Shutdown();
        }
    }
}

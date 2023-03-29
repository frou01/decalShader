
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ProjectorInputUdon : UdonSharpBehaviour
{
    [System.NonSerialized]public Matrix4x4 viewMatrix;
    [System.NonSerialized]public Matrix4x4 projectionMatrix;
    [System.NonSerialized]public Vector4 projectorPos;


    [System.NonSerialized] public Material material;

    public void Update()
    {
        material.SetMatrix("_ProjectorMatrixVP", projectionMatrix * viewMatrix);
        material.SetVector("_ProjectorPos", projectorPos);
        this.enabled = false;
    }
}

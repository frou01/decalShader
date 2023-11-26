
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ProjectorInputUdon : UdonSharpBehaviour
{
    [System.NonSerialized]public Matrix4x4 viewMatrix;
    [System.NonSerialized]public Matrix4x4 projectionMatrix;
    [System.NonSerialized]public Vector4 projectorPos;
    [System.NonSerialized] public Vector4 color;
    [System.NonSerialized] public Vector4 scaleOffset;


    [System.NonSerialized] public Material Presetted_material;
    [System.NonSerialized] public Material material;

    public void Update()
    {
        if(Presetted_material != null)
        {
            MeshRenderer target = transform.parent.gameObject.GetComponent<MeshRenderer>();
            int index = 0;
            foreach (Material mat in target.sharedMaterials)
            {
                if(mat == Presetted_material)
                {
                    target.sharedMaterial = material;
                    MaterialPropertyBlock properties = new MaterialPropertyBlock();
                    properties.SetMatrix("_ProjectorMatrixVP", projectionMatrix * viewMatrix);
                    properties.SetVector("_ProjectorPos", projectorPos);
                    //properties.SetVector("_Color", color);
                    properties.SetVector("_InstancedMainScaleOffset", scaleOffset);
                    target.SetPropertyBlock(properties, index);
                }
                index++;
            }
        }
        else
        {
            material.SetMatrix("_ProjectorMatrixVP", projectionMatrix * viewMatrix);
            material.SetVector("_ProjectorPos", projectorPos);
            //material.SetVector("_Color", color);
            material.SetVector("_InstancedMainScaleOffset", scaleOffset);
        }
        this.enabled = false;
    }
}

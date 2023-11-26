using System.Collections;
using System.Collections.Generic;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.SceneManagement;

public class projectorEditor : IProcessSceneWithReport
{
    public int callbackOrder => 0;

    //Add Material Batcher


    public void OnProcessScene(Scene scene, BuildReport report)
    {
        List<Material> decalMaterials = new List<Material>();
        List<ProjectorInput> DecalInputter = new List<ProjectorInput>();
        foreach (GameObject go in scene.GetRootGameObjects())
        {
            foreach (ProjectorInput projectorC in go.GetComponentsInChildren<ProjectorInput>(true))
            {
                Debug.Log("updateProjector " + projectorC.gameObject.name);
                projectorC.Update();
                ProjectorInputUdon projectorInputUdon = projectorC.gameObject.GetComponent<ProjectorInputUdon>();
                projectorInputUdon.viewMatrix = projectorC.viewMatrix;
                projectorInputUdon.projectionMatrix = projectorC.projectionMatrix;
                projectorInputUdon.projectorPos = projectorC.projectorPos;
                projectorInputUdon.color = projectorC.material.GetVector("_Color");
                projectorInputUdon.scaleOffset = projectorC.material.GetVector("_InstancedMainScaleOffset");
                if (projectorC.GPUInstancing)
                {
                    DecalInputter.Add(projectorC);
                    decalMaterials.Add(projectorC.material);
                }
                projectorInputUdon.material = projectorC.material;
            }
                
        }
        while (decalMaterials.Count > 0)
        {
            foreach (ProjectorInput projectorC in DecalInputter)
            {
                if(decalMaterials[0].GetTexture("_MainTex") == projectorC.material.GetTexture("_MainTex"))
                {
                    ProjectorInputUdon projectorInputUdon = projectorC.gameObject.GetComponent<ProjectorInputUdon>();
                    projectorInputUdon.Presetted_material = projectorC.material;
                    projectorInputUdon.material = decalMaterials[0];
                }
            }

            decalMaterials.Remove(decalMaterials[0]);
        }

    }
}

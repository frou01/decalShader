using System.Collections;
using System.Collections.Generic;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.SceneManagement;

public class projectorEditor : IProcessSceneWithReport
{
    public int callbackOrder => 0;

    public void OnProcessScene(Scene scene, BuildReport report)
    {
        foreach(GameObject go in scene.GetRootGameObjects())
        {
            foreach (ProjectorInput projectorC in go.GetComponentsInChildren<ProjectorInput>())
            {
                Debug.Log("updateProjector " + projectorC.gameObject.name);
                projectorC.Update();
                ProjectorInputUdon projectorInputUdon = projectorC.gameObject.GetComponent<ProjectorInputUdon>();
                projectorInputUdon.viewMatrix = projectorC.viewMatrix;
                projectorInputUdon.projectionMatrix = projectorC.projectionMatrix;
                projectorInputUdon.projectorPos = projectorC.projectorPos;
                projectorInputUdon.material = projectorC.material;
            }
                
        }
    }
}

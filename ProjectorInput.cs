using UnityEngine;

[ExecuteInEditMode]
public class ProjectorInput : MonoBehaviour
{
    [SerializeField, Range(0.0001f, 179)]
    private float _fieldOfView = 60;
    [SerializeField, Range(0.2f, 5.0f)]
    private float _aspect = 1.0f;
    [SerializeField, Range(0.0001f, 1000.0f)]
    private float _nearClipPlane = 0.01f;
    [SerializeField, Range(0.0001f, 1000.0f)]
    private float _farClipPlane = 100.0f;
    [SerializeField]
    private bool _orthographic = false;
    [SerializeField]
    private float _orthographicSize = 1.0f;

    [SerializeField] public Material material;

    [System.NonSerialized] public Matrix4x4 viewMatrix;
    [System.NonSerialized] public Matrix4x4 projectionMatrix;
    [System.NonSerialized] public Vector4 projectorPos;
    public void Update()
    {
        viewMatrix = Matrix4x4.Scale(new Vector3(1, 1, -1)) * transform.worldToLocalMatrix * transform.parent.worldToLocalMatrix.inverse;
        if (_orthographic)
        {
            var orthographicWidth = _orthographicSize * _aspect;
            projectionMatrix = Matrix4x4.Ortho(-orthographicWidth, orthographicWidth, -_orthographicSize, _orthographicSize, _nearClipPlane, _farClipPlane);
        }
        else
        {
            projectionMatrix = Matrix4x4.Perspective(_fieldOfView, _aspect, _nearClipPlane, _farClipPlane);
        }
        projectionMatrix = GL.GetGPUProjectionMatrix(projectionMatrix, true);


        projectorPos = _orthographic ? transform.parent.InverseTransformVector(transform.forward) : transform.localPosition;
        projectorPos.w = _orthographic ? 0 : 1;
        material.SetMatrix("_ProjectorMatrixVP", projectionMatrix * viewMatrix);
        material.SetVector("_ProjectorPos", projectorPos);
    }

    private void OnDrawGizmos()
    {
        var gizmosMatrix = Gizmos.matrix;
        Gizmos.matrix = Matrix4x4.TRS(transform.position, transform.rotation, Vector3.one);

        if (_orthographic)
        {
            var orthographicWidth = _orthographicSize * _aspect;
            var length = _farClipPlane - _nearClipPlane;
            var start = _nearClipPlane + length / 2;
            Gizmos.DrawWireCube(Vector3.forward * start, new Vector3(orthographicWidth * 2, _orthographicSize * 2, length));
        }
        else
        {
            Gizmos.DrawFrustum(Vector3.zero, _fieldOfView, _farClipPlane, _nearClipPlane, _aspect);
        }

        Gizmos.matrix = gizmosMatrix;
    }
}

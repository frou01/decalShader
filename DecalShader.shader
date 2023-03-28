Shader "Custom/DecalShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _ProjectorPos ("ProjectorPos",Vector) = (0,0,0,0)
        _Cutoff ("Cutoff", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Offset -1, -1
        Tags { "RenderType"="TransparentCutout" }

        CGPROGRAM

        #pragma target 3.0
        #pragma surface surf Standard fullforwardshadows addshadow vertex:vert


        sampler2D _ProjectorTexture;
        float _Metallic;
        float _Glossiness;
        float _Cutoff;
        float4x4 _ProjectorMatrixVP;
        float4 _ProjectorPos;
        
        struct appdata
        {
            float4 vertex : POSITION;
            float3 normal : NORMAL;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Input
        {
            float4 vertex;
            float4 projectorSpacePos;
            float3 localPos;
            float3 localNormal;
        };
        

        void vert (inout appdata v , out Input o)
        {
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.projectorSpacePos = mul(_ProjectorMatrixVP, v.vertex);
            o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
            o.localNormal = v.normal.xyz;
            o.localPos = v.vertex.xyz;
        }

        // fixed4 frag (v2f i) : SV_Target
        // {
        //     half4 color = 1;
        //     i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
        //     float2 uv = i.projectorSpacePos.xy;
        //     float4 projectorTex = tex2D(_ProjectorTexture, uv);
        //     // カメラの範囲外には適用しない
        //     fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
        //     float alpha = isOut.x * isOut.y * isOut.z;
        //     // プロジェクターから見て裏側の面には適用しない
        //     alpha *= step(-dot(lerp(-_ProjectorPos.xyz, _ProjectorPos.xyz - i.worldPos, _ProjectorPos.w), i.worldNormal), 0);
        //     return projectorTex * alpha;
        // }

        

        void surf(Input i, inout SurfaceOutputStandard o)
        {
            i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
            fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
            clip(isOut.x * isOut.y * isOut.z - 1);
            clip(step(-dot(lerp(-_ProjectorPos.xyz, _ProjectorPos.xyz - i.localPos, _ProjectorPos.w), i.localNormal), 0) - 1);
            float2 uv = i.projectorSpacePos.xy;
            float4 projectorTex = tex2D(_ProjectorTexture, uv);
            float alpha = projectorTex.a * step(-dot(lerp(-_ProjectorPos.xyz, _ProjectorPos.xyz - i.localPos, _ProjectorPos.w), i.localNormal), 0);

            clip(projectorTex - _Cutoff);
            o.Albedo = projectorTex;
            o.Alpha = alpha;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Emission = 0;
        }
        ENDCG
    }
    Fallback "Standard"
}

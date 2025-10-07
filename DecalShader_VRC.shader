Shader "Custom/DecalShader_VRC"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        [NoScaleOffset]_MainTex("Albedo", 2D) = "white" {}
        _InstancedMainScaleOffset ("Scale (XY) Offset (ZW)", Vector) = (1,1,0,0)

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0
        _MetallicGlossMap("Metallic", 2D) = "white" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {}

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02
        _ParallaxMap ("Height Map", 2D) = "black" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
        _OcclusionMap("Occlusion", 2D) = "white" {}

        _EmissionColor("Color", Color) = (0,0,0)
        _EmissionMap("Emission", 2D) = "white" {}

        _DetailMask("Detail Mask", 2D) = "white" {}

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}
        _DetailNormalMapScale("Scale", Float) = 1.0
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {}

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0
        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup
    ENDCG

    SubShader
    {
        Offset -0.1, -0.1
        Tags { "RenderType"="Cutout" "PerformanceChecks"="False" "IgnoreProjector"="True" }


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertCustom
            #pragma fragment fragCustom
            #include "UnityStandardCoreForward.cginc"



            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct v2f
            {
			    UNITY_POSITION(pos);
			    float4 tex                            : TEXCOORD0;
				float4 ao                             : TEXCOORD1;
			    float4 eyeVec                         : TEXCOORD2;    // eyeVec.xyz | fogCoord
			    float4 tangentToWorldAndPackedData[3] : TEXCOORD3;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or localPos]
			    half4 ambientOrLightmapUV             : TEXCOORD6;    // SH or Lightmap UV
			    UNITY_LIGHTING_COORDS(7,8)
			    // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
			    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
			        float3 posWorld                     : TEXCOORD9;
			    #endif
                float4 projectorSpacePos : TEXCOORD10;
                float3 localPos : TEXCOORD11;
                float3 localNormal : TEXCOORD12;

			    UNITY_VERTEX_INPUT_INSTANCE_ID
			    UNITY_VERTEX_OUTPUT_STEREO
            };
            

            v2f vertCustom (VertexInput v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
			    v2f o;
			    UNITY_INITIALIZE_OUTPUT(v2f, o);
			    UNITY_TRANSFER_INSTANCE_ID(v, o);
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

			    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
			    #if UNITY_REQUIRE_FRAG_WORLDPOS
			        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
			            o.tangentToWorldAndPackedData[0].w = posWorld.x;
			            o.tangentToWorldAndPackedData[1].w = posWorld.y;
			            o.tangentToWorldAndPackedData[2].w = posWorld.z;
			        #else
			            o.posWorld = posWorld.xyz;
			        #endif
			    #endif
			    o.pos = UnityObjectToClipPos(v.vertex);

			    o.tex = TexCoords(v);
			    o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
			    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
			    #ifdef _TANGENT_TO_WORLD
			        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

			        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
			        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
			        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
			        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
			    #else
			        o.tangentToWorldAndPackedData[0].xyz = 0;
			        o.tangentToWorldAndPackedData[1].xyz = 0;
			        o.tangentToWorldAndPackedData[2].xyz = normalWorld;
			    #endif

			    //We need this for shadow receving
			    UNITY_TRANSFER_LIGHTING(o, v.uv1);

			    o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);

			    #ifdef _PARALLAXMAP
			        TANGENT_SPACE_ROTATION;
			        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
			        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
			        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
			        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
			    #endif

			    UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,o.pos);
                
                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localNormal = v.normal;
                o.localPos = v.vertex;
                
                return o;
            }

            fixed4 fragCustom (v2f i) : SV_Target
            {
				UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                
                UNITY_SETUP_INSTANCE_ID(i);


                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                i.tex = i.projectorSpacePos;
				FRAGMENT_SETUP(s)
                
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                
				UnityLight mainLight = MainLight ();
				UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);

                half4 color = 1;
				half occlusion = Occlusion(i.tex);
				UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight);
				half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
				c.rgb += Emission(i.tex.xy);
                
                
				UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
				UNITY_APPLY_FOG(_unity_fogCoord, c.rgb);
				return OutputForward (c, s.alpha);
            }

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAdd_c
            #pragma fragment fragAdd_c
            #include "UnityStandardCoreForward.cginc"
            
            
            #include "UnityCG.cginc"
            #include "UnityShaderVariables.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityStandardInput.cginc"
            #include "UnityPBSLighting.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityGBuffer.cginc"
            #include "UnityStandardBRDF.cginc"

            #include "AutoLight.cginc"
            #include "UnityStandardCore.cginc"

            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)
            struct VertexOutputForwardAdd_C
            {
                UNITY_POSITION(pos);
                float4 tex                          : TEXCOORD0;
                float4 eyeVec                       : TEXCOORD1;    // eyeVec.xyz | fogCoord
                float4 tangentToWorldAndLightDir[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:lightDir]
                float3 posWorld                     : TEXCOORD5;
                UNITY_LIGHTING_COORDS(6, 7)

                float4 projectorSpacePos: TEXCOORD8;
                float3 localPos: TEXCOORD9;
                float3 localNormal: TEXCOORD10;
                // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
            #if defined(_PARALLAXMAP)
                half3 viewDirForParallax            : TEXCOORD11;
            #endif

                UNITY_VERTEX_OUTPUT_STEREO
            };

            VertexOutputForwardAdd_C vertAdd_c(VertexInput v) { 
                UNITY_SETUP_INSTANCE_ID(v);
                VertexOutputForwardAdd_C o;
                UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd_C, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);

                o.tex = TexCoords(v);
                o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
                o.posWorld = posWorld.xyz;
                float3 normalWorld = UnityObjectToWorldNormal(v.normal);
                #ifdef _TANGENT_TO_WORLD
                    float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

                    float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
                    o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0];
                    o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1];
                    o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2];
                #else
                    o.tangentToWorldAndLightDir[0].xyz = 0;
                    o.tangentToWorldAndLightDir[1].xyz = 0;
                    o.tangentToWorldAndLightDir[2].xyz = normalWorld;
                #endif
                //We need this for shadow receiving and lighting
                UNITY_TRANSFER_LIGHTING(o, v.uv1);

                float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;
                #ifndef USING_DIRECTIONAL_LIGHT
                    lightDir = NormalizePerVertexNormal(lightDir);
                #endif
                o.tangentToWorldAndLightDir[0].w = lightDir.x;
                o.tangentToWorldAndLightDir[1].w = lightDir.y;
                o.tangentToWorldAndLightDir[2].w = lightDir.z;

                #ifdef _PARALLAXMAP
                    TANGENT_SPACE_ROTATION;
                    o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
                #endif

                UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o, o.pos);

                
                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localNormal = v.normal.xyz;
                o.localPos = v.vertex.xyz;

                return o;
            }
            half4 fragAdd_c (VertexOutputForwardAdd_C i) : SV_Target {
                
                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                i.tex.xy = i.projectorSpacePos.xy;

                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                FRAGMENT_SETUP_FWDADD(s)

                UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)
                UnityLight light = AdditiveLight (IN_LIGHTDIR_FWDADD(i), atten);
                UnityIndirect noIndirect = ZeroIndirect ();

                half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

                UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);
                UNITY_APPLY_FOG_COLOR(_unity_fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
                return OutputForward (c, s.alpha);
            }

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _PARALLAXMAP
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster_custom
            #pragma fragment fragShadowCaster_custom

            #include "UnityStandardShadow.cginc"

            
            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)
            //#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
            struct VertexOutputShadowCaster_custom
            {
                V2F_SHADOW_CASTER_NOPOS
                //#if defined(UNITY_STANDARD_USE_SHADOW_UVS)
                    float2 tex : TEXCOORD1;

                    #if defined(_PARALLAXMAP)
                        half3 viewDirForParallax : TEXCOORD2;
                    #endif
                //#endif

                
                float4 projectorSpacePos : TEXCOORD3;
                float3 localPos : TEXCOORD4;
                float3 localNormal : TEXCOORD5;
            };
            //#endif

            //#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
            struct VertexOutputStereoShadowCaster_custom
            {
                UNITY_VERTEX_OUTPUT_STEREO
            };
            //#endif


            void vertShadowCaster_custom (VertexInput v, out float4 opos : SV_POSITION
                //#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
                , out VertexOutputShadowCaster_custom o
                //#endif
                #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
                , out VertexOutputStereoShadowCaster_custom os
                #endif
            )
            {
                UNITY_SETUP_INSTANCE_ID(v);
                #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
                    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);
                #endif
                TRANSFER_SHADOW_CASTER_NOPOS(o,opos)
                //#if defined(UNITY_STANDARD_USE_SHADOW_UVS)
                    float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                    o.tex.xy *= _MainScaleOffset.xy;
                    o.tex.xy += _MainScaleOffset.zw;

                    #ifdef _PARALLAXMAP
                        TANGENT_SPACE_ROTATION;
                        o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
                    #endif

                        
                    o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                    o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                    o.localNormal = v.normal;
                    o.localPos = v.vertex;
                    o.tex.xy = o.projectorSpacePos.xy;
                //#endif

                
            }

            half4 fragShadowCaster_custom (UNITY_POSITION(vpos)
            //#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
                , VertexOutputShadowCaster_custom i
            //#endif
            ) : SV_Target
            {
                //#if defined(UNITY_STANDARD_USE_SHADOW_UVS)
                    i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                    fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                    clip(isOut.x * isOut.y * isOut.z - 1);
                    float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                    clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                    i.tex.xy = i.projectorSpacePos.xy;
                    float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                    i.tex.xy *= _MainScaleOffset.xy;
                    i.tex.xy += _MainScaleOffset.zw;
                    float4 projectorTex = tex2D(_MainTex, i.tex.xy);
                    clip(projectorTex.a - _Cutoff);
                    #if defined(_PARALLAXMAP) && (SHADER_TARGET >= 30)
                        half3 viewDirForParallax = normalize(i.viewDirForParallax);
                        fixed h = tex2D (_ParallaxMap, i.tex.xy).g;
                        half2 offset = ParallaxOffset1Step (h, _Parallax, viewDirForParallax);
                        i.tex.xy += offset;
                    #endif
                //#endif // #if defined(UNITY_STANDARD_USE_SHADOW_UVS)

                #ifdef LOD_FADE_CROSSFADE
                    #ifdef _LOD_FADE_ON_ALPHA
                        #undef _LOD_FADE_ON_ALPHA
                    #else
                        i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                        fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                        clip(isOut.x * isOut.y * isOut.z - 1);
                        float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                        clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                        vpos.xy = projectorSpacePos.xy;
                        UnityApplyDitherCrossFade(vpos.xy);
                    #endif
                #endif

                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
        Pass {
            Name "SceneSelectionPass"
            Tags { "LightMode" = "SceneSelectionPass" }


            CGPROGRAM
            #pragma target 3.0



            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _REQUIRE_UV2
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:vertInstancingSetup

            #pragma vertex vertEditorPass
            #pragma fragment fragSceneHighlightPass
            
            #ifndef UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED
            #define UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED

            #if _REQUIRE_UV2
            #define _FLIPBOOK_BLENDING 1
            #endif

            #include "UnityCG.cginc"
            #include "UnityShaderVariables.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityStandardParticleInstancing.cginc"

            half        _Cutoff;
            sampler2D   _MainTex;

            float _ObjectId;
            float _PassValue;
            float4 _SelectionID;
            uniform float _SelectionAlphaCutoff;

            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct VertexInput
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                fixed4 color    : COLOR;
                #if defined(_FLIPBOOK_BLENDING) && !defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                    float4 texcoords : TEXCOORD0;
                    float texcoordBlend : TEXCOORD1;
                #else
                    float2 texcoords : TEXCOORD0;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float2 texcoord : TEXCOORD0;
                #ifdef _FLIPBOOK_BLENDING
                    float3 texcoord2AndBlend : TEXCOORD1;
                #endif
                fixed4 color : TEXCOORD2;
                float4 projectorSpacePos : TEXCOORD3;
                float3 localPos : TEXCOORD4;
                float3 localNormal : TEXCOORD5;
            };

            void vertEditorPass(VertexInput v, out VertexOutput o, out float4 opos : SV_POSITION)
            {
                UNITY_SETUP_INSTANCE_ID(v);

                opos = UnityObjectToClipPos(v.vertex);

                #ifdef _FLIPBOOK_BLENDING
                    #ifdef UNITY_PARTICLE_INSTANCING_ENABLED
                        vertInstancingUVs(v.texcoords.xy, o.texcoord, o.texcoord2AndBlend);
                    #else
                        o.texcoord = v.texcoords.xy;
                        o.texcoord2AndBlend.xy = v.texcoords.zw;
                        o.texcoord2AndBlend.z = v.texcoordBlend;
                    #endif
                #else
                    float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                    #ifdef UNITY_PARTICLE_INSTANCING_ENABLED
                        vertInstancingUVs(v.texcoords.xy, o.texcoord);
                        o.texcoord.xy = o.texcoord.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                    #else
                        o.texcoord.xy = v.texcoords.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                    #endif
                #endif
                o.color = v.color;
                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localNormal = v.normal.xyz;
                o.localPos = v.vertex.xyz;
            }

            void fragSceneClip(VertexOutput i)
            {
                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                float4 projectorTex = tex2D(_MainTex, i.projectorSpacePos.xy);
                float alpha = projectorTex.a * step(-dot(lerp(-_ProjectorPos.xyz, _ProjectorPos.xyz - i.localPos, _ProjectorPos.w), i.localNormal), 0);

                clip(projectorTex.a - _Cutoff);
            }

            half4 fragSceneHighlightPass(VertexOutput i) : SV_Target
            {
                fragSceneClip(i);
                return float4(_ObjectId, _PassValue, 1, 1);
            }

            half4 fragScenePickingPass(VertexOutput i) : SV_Target
            {
                fragSceneClip(i);
                return _SelectionID;
            }

            #endif // UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED
            ENDCG
        }
        
        Pass
        {
            Name "ScenePickingPass"
            Tags{ "LightMode" = "Picking" }

            BlendOp Add
            Blend One Zero
            ZWrite On
            Cull Off

            CGPROGRAM
            #pragma target 3.0

            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local _REQUIRE_UV2
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:vertInstancingSetup

            #pragma vertex vertEditorPass
            #pragma fragment fragScenePickingPass
            // Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

            #ifndef UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED
            #define UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED

            #if _REQUIRE_UV2
            #define _FLIPBOOK_BLENDING 1
            #endif

            #include "UnityCG.cginc"
            #include "UnityShaderVariables.cginc"
            #include "UnityStandardConfig.cginc"
            #include "UnityStandardUtils.cginc"
            #include "UnityStandardParticleInstancing.cginc"

            half        _Cutoff;
            sampler2D   _MainTex;

            float _ObjectId;
            float _PassValue;
            float4 _SelectionID;
            uniform float _SelectionAlphaCutoff;
            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct VertexInput
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                fixed4 color    : COLOR;
                #if defined(_FLIPBOOK_BLENDING) && !defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                    float4 texcoords : TEXCOORD0;
                    float texcoordBlend : TEXCOORD1;
                #else
                    float2 texcoords : TEXCOORD0;
                #endif
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertexOutput
            {
                float2 texcoord : TEXCOORD0;
                #ifdef _FLIPBOOK_BLENDING
                    float3 texcoord2AndBlend : TEXCOORD1;
                #endif
                fixed4 color : TEXCOORD2;
                float4 projectorSpacePos : TEXCOORD3;
                float3 localPos : TEXCOORD4;
                float3 localNormal : TEXCOORD5;
            };

            void vertEditorPass(VertexInput v, out VertexOutput o, out float4 opos : SV_POSITION)
            {
                UNITY_SETUP_INSTANCE_ID(v);

                opos = UnityObjectToClipPos(v.vertex);

                #ifdef _FLIPBOOK_BLENDING
                    #ifdef UNITY_PARTICLE_INSTANCING_ENABLED
                        vertInstancingUVs(v.texcoords.xy, o.texcoord, o.texcoord2AndBlend);
                    #else
                        o.texcoord = v.texcoords.xy;
                        o.texcoord2AndBlend.xy = v.texcoords.zw;
                        o.texcoord2AndBlend.z = v.texcoordBlend;
                    #endif
                #else
                    float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                    #ifdef UNITY_PARTICLE_INSTANCING_ENABLED
                        vertInstancingUVs(v.texcoords.xy, o.texcoord);
                        o.texcoord.xy = o.texcoord.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                    #else
                        o.texcoord.xy = v.texcoords.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                    #endif
                #endif
                o.color = v.color;
                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localNormal = v.normal.xyz;
                o.localPos = v.vertex.xyz;
            }

            void fragSceneClip(VertexOutput i)
            {
                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                float4 projectorTex = tex2D(_MainTex, i.projectorSpacePos.xy);
                float alpha = projectorTex.a * step(-dot(lerp(-_ProjectorPos.xyz, _ProjectorPos.xyz - i.localPos, _ProjectorPos.w), i.localNormal), 0);

                clip(projectorTex.a - _Cutoff);
            }

            half4 fragSceneHighlightPass(VertexOutput i) : SV_Target
            {
                fragSceneClip(i);
                return float4(_ObjectId, _PassValue, 1, 1);
            }

            half4 fragScenePickingPass(VertexOutput i) : SV_Target
            {
                fragSceneClip(i);
                return _SelectionID;
            }

            #endif // UNITY_STANDARD_PARTICLE_EDITOR_INCLUDED
            ENDCG
        }
        // ------------------------------------------------------------------
        //  Deferred pass
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertDeferred_C
            #pragma fragment fragDeferred_C

            #include "UnityStandardCore.cginc"

            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)
            struct VertexOutputDeferred_C
            {
                UNITY_POSITION(pos);
                float4 tex                            : TEXCOORD0;
                float3 eyeVec                         : TEXCOORD1;
                float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or localPos]
                half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs

                #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
                    float3 posWorld                     : TEXCOORD6;
                #endif

                float4 projectorSpacePos : TEXCOORD9;
                float3 localPos : TEXCOORD10;
                float3 localNormal : TEXCOORD11;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            VertexOutputDeferred_C vertDeferred_C (VertexInput v)
            {
                UNITY_SETUP_INSTANCE_ID(v);
                VertexOutputDeferred_C o;
                UNITY_INITIALIZE_OUTPUT(VertexOutputDeferred_C, o);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
                #if UNITY_REQUIRE_FRAG_WORLDPOS
                    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
                        o.tangentToWorldAndPackedData[0].w = posWorld.x;
                        o.tangentToWorldAndPackedData[1].w = posWorld.y;
                        o.tangentToWorldAndPackedData[2].w = posWorld.z;
                    #else
                        o.posWorld = posWorld.xyz;
                    #endif
                #endif
                o.pos = UnityObjectToClipPos(v.vertex);

                o.tex = TexCoords(v);
                o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);
                float3 normalWorld = UnityObjectToWorldNormal(v.normal);
                #ifdef _TANGENT_TO_WORLD
                    float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);

                    float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
                    o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
                    o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
                    o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
                #else
                    o.tangentToWorldAndPackedData[0].xyz = 0;
                    o.tangentToWorldAndPackedData[1].xyz = 0;
                    o.tangentToWorldAndPackedData[2].xyz = normalWorld;
                #endif

                o.ambientOrLightmapUV = 0;
                #ifdef LIGHTMAP_ON
                    o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                #elif UNITY_SHOULD_SAMPLE_SH
                    o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);
                #endif
                #ifdef DYNAMICLIGHTMAP_ON
                    o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
                #endif

                #ifdef _PARALLAXMAP
                    TANGENT_SPACE_ROTATION;
                    half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
                    o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
                    o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
                    o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
                #endif

                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localPos = v.vertex.xyz;
                o.localNormal = v.normal.xyz;
                return o;
            }

            void fragDeferred_C (
                VertexOutputDeferred_C i,
                out half4 outGBuffer0 : SV_Target0,
                out half4 outGBuffer1 : SV_Target1,
                out half4 outGBuffer2 : SV_Target2,
                out half4 outEmission : SV_Target3          // RT3: emission (rgb), --unused-- (a)
            #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                ,out half4 outShadowMask : SV_Target4       // RT4: shadowmask (rgba)
            #endif
            )
            {
                
                #if (SHADER_TARGET < 30)
                    outGBuffer0 = 1;
                    outGBuffer1 = 1;
                    outGBuffer2 = 0;
                    outEmission = 0;
                    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                        outShadowMask = 1;
                    #endif
                    return;
                #endif

                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                i.tex.xy = i.projectorSpacePos.xy;

                FRAGMENT_SETUP(s)
                UNITY_SETUP_INSTANCE_ID(i);


                // no analytic lights in this pass
                UnityLight dummyLight = DummyLight ();
                half atten = 1;

                // only GI
                half occlusion = Occlusion(i.tex.xy);
            #if UNITY_ENABLE_REFLECTION_BUFFERS
                bool sampleReflectionsInDeferred = false;
            #else
                bool sampleReflectionsInDeferred = true;
            #endif

                UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);

                half3 emissiveColor = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

                #ifdef _EMISSION
                    emissiveColor += Emission (i.tex.xy);
                #endif

                #ifndef UNITY_HDR_ON
                    emissiveColor.rgb = exp2(-emissiveColor.rgb);
                #endif

                UnityStandardData data;
                data.diffuseColor   = s.diffColor;
                data.occlusion      = occlusion;
                data.specularColor  = s.specColor;
                data.smoothness     = s.smoothness;
                data.normalWorld    = s.normalWorld;

                UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

                // Emissive lighting buffer
                outEmission = half4(emissiveColor, 1);

                // Baked direct lighting occlusion if any
                #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
                    outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
                #endif
            }

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11; has structs without semantics (struct v2f_meta_c members projectorSpacePos,localPos,localNormal)
#pragma exclude_renderers d3d11
            #pragma vertex vert_meta_c
            #pragma fragment frag_meta_c

            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"


            
            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ProjectorMatrixVP)
                UNITY_DEFINE_INSTANCED_PROP(float4, _ProjectorPos)
                UNITY_DEFINE_INSTANCED_PROP(float4, _InstancedMainScaleOffset)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct v2f_meta_c
            {
                float4 pos      : SV_POSITION;
                float4 uv       : TEXCOORD0;
            #ifdef EDITOR_VISUALIZATION
                float2 vizUV        : TEXCOORD1;
                float4 lightCoord   : TEXCOORD2;
            #endif
                float4 projectorSpacePos;
                float3 localPos;
                float3 localNormal;
            };

            v2f_meta_c vert_meta_c (VertexInput v)
            {
                v2f_meta_c o;
                o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
                o.uv = TexCoords(v);
            #ifdef EDITOR_VISUALIZATION
                o.vizUV = 0;
                o.lightCoord = 0;
                if (unity_VisualizationMode == EDITORVIZ_TEXTURE)
                    o.vizUV = UnityMetaVizUV(unity_EditorViz_UVIndex, v.uv0.xy, v.uv1.xy, v.uv2.xy, unity_EditorViz_Texture_ST);
                else if (unity_VisualizationMode == EDITORVIZ_SHOWLIGHTMASK)
                {
                    o.vizUV = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
                    o.lightCoord = mul(unity_EditorViz_WorldToLight, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)));
                }
            #endif
                o.projectorSpacePos = mul(UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorMatrixVP), v.vertex);
                o.projectorSpacePos = ComputeNonStereoScreenPos(o.projectorSpacePos);
                o.localNormal = v.normal.xyz;
                o.localPos = v.vertex.xyz;
                return o;
            }

            float4 frag_meta_c (v2f_meta_c i) : SV_Target
            {
                // we're interested in diffuse & specular colors,
                // and surface roughness to produce final albedo.
                FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);

                UnityMetaInput o;
                UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);

                i.projectorSpacePos.xyz /= i.projectorSpacePos.w;
                fixed3 isOut = step((i.projectorSpacePos - 0.5) * sign(i.projectorSpacePos), 0.5);
                clip(isOut.x * isOut.y * isOut.z - 1);
                float4 i_ProjectorPos = UNITY_ACCESS_INSTANCED_PROP(Props, _ProjectorPos);
                clip(dot(lerp(-i_ProjectorPos.xyz, i_ProjectorPos.xyz - i.localPos, i_ProjectorPos.w), i.localNormal) + 0.00001);
                float4 _MainScaleOffset = UNITY_ACCESS_INSTANCED_PROP(Props, _InstancedMainScaleOffset);
                i.projectorSpacePos.xy = i.projectorSpacePos.xy * _MainScaleOffset.xy + _MainScaleOffset.zw;
                i.uv.xy = i.projectorSpacePos.xy;

            #ifdef EDITOR_VISUALIZATION
                o.Albedo = data.diffColor;
                o.VizUV = i.vizUV;
                o.LightCoord = i.lightCoord;
            #else
                o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);
            #endif
                o.SpecularColor = data.specColor;
                o.Emission = Emission(i.uv.xy);

                return UnityMetaFragment(o);
            }


            ENDCG
        }
        
    }
    FallBack "Custom/DecalShader_VRC_VertexLit"
    CustomEditor "ModdedStandardShaderGUI"
}
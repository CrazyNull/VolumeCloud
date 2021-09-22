Shader "Hidden/PostProcessing/VolumeCloud"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
            TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
            TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

            float _Density;
            float4 _Color;
            float _Step;
            float _StepDistance;
            float3 _Center;
            float3 _Size;


            float4x4 _InverseProjectionMatrix;
            float4x4 _InverseViewMatrix;

            float cloudRayMarching(float3 startPoint, float3 direction) 
            {
                float3 testPoint = startPoint + _Center;
                float sum = 0.0;
                direction *= _StepDistance;//每次步进间隔
                for (int i = 0; i < _Step; i++)//步进总长度
                {
                    testPoint += direction;
                    if (testPoint.x < _Size.x && testPoint.x > -_Size.x &&
                        testPoint.z < _Size.z && testPoint.z > -_Size.z &&
                        testPoint.y < _Size.y && testPoint.y > -_Size.y)
                        sum += 0.01;
                }
                return sum;
            }


            float4 GetWorldSpacePosition(float depth, float2 uv)
            {
                // 屏幕空间 --> 视锥空间
                float4 view_vector = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
                view_vector.xyz /= view_vector.w;
                //视锥空间 --> 世界空间
                float4x4 l_matViewInv = _InverseViewMatrix;
                float4 world_vector = mul(l_matViewInv, float4(view_vector.xyz, 1));
                return world_vector;
            }

            float4 Frag(VaryingsDefault i) : SV_Target
            {
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo);
                float4 worldPos = GetWorldSpacePosition(depth, i.texcoord);
                float3 rayPos = _WorldSpaceCameraPos;
                float3 worldViewDir = normalize(worldPos.xyz - rayPos.xyz);
                float cloud = cloudRayMarching(_WorldSpaceCameraPos.xyz, worldViewDir);
                color = color + _Color * cloud * _Density;
                return color;
            }


            ENDHLSL
        }
    }
}
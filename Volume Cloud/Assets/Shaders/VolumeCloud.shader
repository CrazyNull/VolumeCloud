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

            float3 _boundsMin;
            float3 _boundsMax;

            float4x4 _InverseProjectionMatrix;
            float4x4 _InverseViewMatrix;

            float cloudRayMarching(float dstLimit) 
            {
                float sumDensity  = 0.0;
                float dstTravelled = 0;
                for (int i = 0; i < _Step; i++)//步进总长度
                {
                    if ( dstLimit > 0) //被遮住时步进跳过
                    {
	                    sumDensity += _StepDistance;
                        if (sumDensity > 1)
                            break;
                    }
                   dstTravelled += _StepDistance; //每次步进长度
                }
                return sumDensity;
            }


            //不要问为什么，问就是老黄牛逼 , 论文在此  http://jcgt.org/published/0007/03/04/
            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir)
            {
                float3 t0 = (boundsMin - rayOrigin) * invRaydir;
                float3 t1 = (boundsMax - rayOrigin) * invRaydir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);

                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }


            float4 GetWorldSpacePosition(float depth, float2 uv)
            {
                float4 view_vector = mul(_InverseProjectionMatrix, float4(2.0 * uv - 1.0, depth, 1.0));
                view_vector.xyz /= view_vector.w;
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

                float depthEyeLinear = length(worldPos.xyz - _WorldSpaceCameraPos);              
                float2 rayToContainerInfo = rayBoxDst(_boundsMin, _boundsMax, rayPos, (1 / worldViewDir));
                float dstToBox = rayToContainerInfo.x;
                float dstInsideBox = rayToContainerInfo.y;
                float dstLimit = min(depthEyeLinear - dstToBox, dstInsideBox);

                float cloud = cloudRayMarching(dstLimit);

                color = color + _Color * cloud * _Density;
                return color;
            }


            ENDHLSL
        }
    }
}
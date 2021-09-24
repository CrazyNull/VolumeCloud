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

            float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
            float4 mod289(float4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
            float4 perm(float4 x){return mod289(((x * 34.0) + 1.0) * x);}

            float noise(float3 p)
            {
                float3 a = floor(p);
                float3 d = p - a;
                d = d * d * (3.0 - 2.0 * d);

                float4 b = a.xxyy + float4(0.0, 1.0, 0.0, 1.0);
                float4 k1 = perm(b.xyxy);
                float4 k2 = perm(k1.xyxy + b.zzww);

                float4 c = k2 + a.zzzz;
                float4 k3 = perm(c);
                float4 k4 = perm(c + 1.0);

                float4 o1 = frac(k3 * (1.0 / 41.0));
                float4 o2 = frac(k4 * (1.0 / 41.0));

                float4 o3 = o2 * d.z + o1 * (1.0 - d.z);
                float2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

                return o4.y * d.y + o4.x * (1.0 - d.y);
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

                float cloud = 0;
                if(dstLimit > 0)
                {
                    float dstTravelled = 0;
                    float maxLimit = dstInsideBox + dstToBox;
                    worldPos.x += _Time.y;
                    float3 pos = worldPos;
                    float3 dir = worldViewDir * _StepDistance;
                    float sumDensity = 0;
                    for (int i = 0; i < _Step; i++)
                    {
                        if(dstTravelled > dstToBox)
                        {
                            cloud += noise(pos) * _Density;
                            sumDensity = exp(-density * stepSize );
                            pos += dir;
                        }
                        if (cloud > 1)
                            break;
                        dstTravelled += _StepDistance;
                        if(dstTravelled > maxLimit)
                        {
                            break;
                        }
                    }
                }
                color = lerp(color,_Color,cloud);
                return color;
            }


            ENDHLSL
        }
    }
}
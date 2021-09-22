using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using System;


[Serializable]
[PostProcess(typeof(VolumeCloudRenderer), PostProcessEvent.AfterStack, "Unity/Volume Cloud")]
public class VolumeCloud : PostProcessEffectSettings
{
    [Tooltip("Volume Cloud")]
    public ColorParameter color = new ColorParameter { value = new Color(1f, 1f, 1f, 1f) };

    [Range(0f, 1f),Tooltip("Volume Cloud intensity")]
    public FloatParameter density = new FloatParameter { value = 0.5f };

    [Range(0, 1024), Tooltip("Volume Cloud Matching Step")]
    public IntParameter step = new IntParameter { value = 256 };

    [Tooltip("Volume Cloud Matching Step Distance")]
    public FloatParameter stepDistance = new FloatParameter { value = 0.05f };

    [Tooltip("Cloud Center Position")]
    public Vector3Parameter center = new Vector3Parameter() { value = Vector3.zero };

    [Tooltip("Cloud Size")]
    public Vector3Parameter size = new Vector3Parameter() { value =  Vector3.one * 5 };

}

public sealed class VolumeCloudRenderer : PostProcessEffectRenderer<VolumeCloud>
{
    public override void Render(PostProcessRenderContext context)
    {
        var cmd = context.command;
        cmd.BeginSample("ScreenVolumeCloud");

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/PostProcessing/VolumeCloud"));
        sheet.properties.SetColor("_Color", settings.color);
        sheet.properties.SetFloat("_Density", settings.density);
        sheet.properties.SetFloat("_Step", settings.step);
        sheet.properties.SetFloat("_StepDistance", settings.stepDistance);
        sheet.properties.SetVector("_Center", settings.center);
        sheet.properties.SetVector("_Size", settings.size);


        Matrix4x4 projectionMatrix = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, false);
        sheet.properties.SetMatrix(Shader.PropertyToID("_InverseProjectionMatrix"), projectionMatrix.inverse);
        sheet.properties.SetMatrix(Shader.PropertyToID("_InverseViewMatrix"), context.camera.cameraToWorldMatrix);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);

        cmd.EndSample("ScreenVolumeCloud");
    }
}
static const float PI = 3.14159265359;
// --- UV ---
float2 CenteredUV = UV - 0.5;

// --- Rotation ---
float RotationAngle = 0.0f;
if (EnableRotation)
{
    float3 CameraForward = normalize(CameraForwardWS);
    float2 CameraForwardXZ = normalize(float2(-CameraForward.x, CameraForward.z));
    RotationAngle = -atan2(CameraForwardXZ.y, CameraForwardXZ.x);
}
float sinAngle = sin(RotationAngle);    
float cosAngle = cos(RotationAngle);
float2 RotatedUV = float2(
    CenteredUV.x * cosAngle - CenteredUV.y * sinAngle,
    CenteredUV.x * sinAngle + CenteredUV.y * cosAngle
);

float DynamicSize = Size;

// --- Angle Fade ---
float ViewAngleFade = 1.0f;
if (EnableViewAngleFade)
{
    float3 NormalizedLightDir = normalize(-LightSourceDirection);
    float3 DirectionToFlare = normalize(WorldPosition - CameraPosition);
    float viewDotProduct = dot(CameraForwardWS, DirectionToFlare);
    float viewHalfAngleRad = (viewAngleDegrees * PI / 180.0) / 2.0;
    float minViewDot = cos(viewHalfAngleRad);
    ViewAngleFade = smoothstep(minViewDot - viewFadeWidth, minViewDot, viewDotProduct);
    
    float lightViewAngle = acos(dot(CameraForwardWS, NormalizedLightDir));
    float normalizedAngle = lightViewAngle / (PI * 0.5);
    DynamicSize += normalizedAngle * 0.32; 
}

// --- Distance-based Size Scaling ---
float DistanceToCamera = distance(CameraPosition, WorldPosition);
float DistanceScale = lerp(1.0, MaxDistanceScale, saturate((DistanceToCamera - MinScaleDistance) / (MaxScaleDistance - MinScaleDistance)));
DynamicSize *= DistanceScale;

float2 ScaledCenteredUV = RotatedUV / DynamicSize;
float BoundsMask = (abs(ScaledCenteredUV.x) <= 0.5 && abs(ScaledCenteredUV.y) <= 0.5) ? 1.0f : 0.0f;
float2 FinalUV = ScaledCenteredUV + 0.5; 

// --- Chromatic Aberration ---
float2 RedUV  = FinalUV + float2(ChromaticAberration, 0);
float2 BlueUV = FinalUV - float2(ChromaticAberration, 0);

float r_c = Texture2DSample(Tex, TexSampler, RedUV).r;
float g_c = Texture2DSample(Tex, TexSampler, FinalUV).g;
float b_c = Texture2DSample(Tex, TexSampler, BlueUV).b;
float a_c = Texture2DSample(Tex, TexSampler, FinalUV).a;
float4 Texture = float4(r_c, g_c, b_c, a_c);
Texture *= BoundsMask;

// --- Vignette Effect ---
float VignetteEffect = 1.0f - dot(CenteredUV, CenteredUV) * VignetteStrength;
VignetteEffect = saturate(VignetteEffect);

// --- Cone Fade ---
float ConeFade = 1.0f;
if (EnableConeFade)
{
    float3 LightToCameraDir = normalize(CameraPosition - WorldPosition);
    float3 NormalizedLightDir = normalize(LightSourceDirection);
    float angleDegrees = acos(dot(NormalizedLightDir, LightToCameraDir)) * 180.0 / PI;
    float fadeRatio = saturate(angleDegrees / ConeAngle);
    float fadeExponent = 8.0;
    ConeFade = exp(-fadeExponent * fadeRatio);
    
    if (angleDegrees >= ConeAngle * 1.1)
    {
        ConeFade = 0.0;
    }
}

// --- Distance Fade ---
float DistanceFade = 1.0f;
if (EnableDistanceFade)
{
    DistanceFade = saturate(1.0f - smoothstep(FadeDistanceMin, FadeDistanceMax, DistanceToCamera));
}

// --- Emissive Reuslt ---
float3 Emissive = Texture.rgb * Color.rgb * Intensity * VignetteEffect;

// --- Alpha Result ---
Opacity = Texture.a * VignetteEffect * ViewAngleFade * ConeFade * DistanceFade;

return float3(Emissive);

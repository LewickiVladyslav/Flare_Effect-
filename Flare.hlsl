static const float PI = 3.14159265359;

// --- UV ---
float2 CenteredUV = UV - 0.5;
float2 ScaledUV = CenteredUV / Size;

// --- Texture Rotation ---
float RotationRad = RotationAngle * PI / 180.0;
float cosRot = cos(RotationRad);
float sinRot = sin(RotationRad);
float2x2 RotationMatrix = float2x2(cosRot, -sinRot, sinRot, cosRot);
float2 RotatedUV = mul(RotationMatrix, ScaledUV);

float BoundsMask = (abs(RotatedUV.x) <= 0.5 && abs(RotatedUV.y) <= 0.5) ? 1.0f : 0.0f;
float2 FinalUV = RotatedUV + 0.5;

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
float VignetteEffect = 1 - dot(CenteredUV, CenteredUV) * VignetteStrength;
VignetteEffect = saturate(VignetteEffect);

// --- View Angle Fade ---
float ViewAngleFade = 1;
if (EnableViewAngleFade)
{
    float3 NormalizedLightDir = normalize(-LightSourceDirection);
    float3 DirectionToFlare = normalize(WorldPosition - CameraPosition);
    float viewDotProduct = dot(CameraForwardWS, DirectionToFlare);
    float viewHalfAngleRad = (viewAngleDegrees * PI / 180.0) / 2.0;
    float minViewDot = cos(viewHalfAngleRad);
    ViewAngleFade = smoothstep(minViewDot - viewFadeWidth, minViewDot, viewDotProduct);
}

// --- Cone Fade ---
float ConeFade = 1;
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
float DistanceFade = 1;
if (EnableDistanceFade)
{
    float DistanceToCamera = distance(CameraPosition, WorldPosition);
    DistanceFade = saturate(1 - smoothstep(FadeDistanceMin, FadeDistanceMax, DistanceToCamera));
}

float3 Emissive = Texture.rgb * Color.rgb * Intensity * VignetteEffect;
// --- Output ---
Opacity = Texture.a * VignetteEffect * ViewAngleFade * ConeFade * DistanceFade;

return Emissive;

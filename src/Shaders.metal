#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float2 texCoord;
    float3 worldPosition;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 cameraPosition;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPosition.xyz;
    
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
    out.normal = (uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    out.texCoord = in.texCoord;
    
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                             texture2d<float> baseColorTexture [[texture(0)]],
                             sampler textureSampler [[sampler(0)]]) {
    float3 normal = normalize(in.normal);
    float3 lightDirection = normalize(float3(1.0, 1.0, 1.0));
    float diffuseIntensity = max(0.0, dot(normal, lightDirection));
    float ambientIntensity = 0.3;
    
    float4 baseColor = baseColorTexture.sample(textureSampler, in.texCoord);
    return float4(baseColor.rgb * (diffuseIntensity + ambientIntensity), baseColor.a);
}

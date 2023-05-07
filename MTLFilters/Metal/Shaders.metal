//
//  Shaders.metal
//  MTLFilters
//
//  Created by Alexander Pelevinov on 05.05.2023.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct VertexIn {
    simd_float2 position;
    simd_float2 texCoord;
};

vertex VertexOut texturedQuadVertex(          uint         vertexID  [[ vertex_id ]],
                                      const device VertexIn * vertices  [[ buffer(0) ]],
                                      constant     float2     & quadScale [[ buffer(1) ]])
{
    VertexOut out;

    float2 position = vertices[vertexID].position * quadScale;

    out.position.xy = position;
    out.position.z  = 0.0;
    out.position.w  = 1.0;

    out.texCoord = vertices[vertexID].texCoord;

    return out;
}

fragment half4 texturedQuadFragment(VertexOut   in         [[ stage_in ]],
                                    texture2d<half>  texture    [[ texture(0) ]],
                                    constant float & mipmapBias [[ buffer(0) ]])
{
    constexpr sampler sampler(min_filter::linear,
                              mag_filter::linear,
                              mip_filter::linear);

    half4 color = texture.sample(sampler, in.texCoord, level(mipmapBias));

    return color;
}

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

struct ImageVertexOutput {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex ImageVertexOutput imageVertexShader(
    uint vertexID [[vertex_id]],
    constant ImageCropUniforms &cropUniforms [[buffer(BufferIndexImageCrop)]]
) {
    // Two triangles forming one rectangle that always fills the full
    // clip-space viewport; which part of the source image ends up on
    // screen is controlled entirely by the cropped texture coordinates.
    constexpr float2 positions[6] = {
        float2(-1.0,  1.0),  // Top-left
        float2(-1.0, -1.0),  // Bottom-left
        float2( 1.0, -1.0),  // Bottom-right

        float2(-1.0,  1.0),  // Top-left
        float2( 1.0, -1.0),  // Bottom-right
        float2( 1.0,  1.0)   // Top-right
    };

    // Corner fractions (0 = top/left edge of the crop rect, 1 = bottom/
    // right edge), matching the positions above.
    constexpr float2 corners[6] = {
        float2(0.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 1.0),

        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0)
    };

    float2 uvOrigin = cropUniforms.sourceUVRect.xy;
    float2 uvEnd = cropUniforms.sourceUVRect.zw;
    float2 corner = corners[vertexID];

    // Rotate the sampled corner 90° so a portrait-shaped drawable still
    // displays the (landscape-cropped) image in a landscape orientation,
    // rather than a tall sliver of it.
    if (cropUniforms.rotateToLandscape != 0) {
        corner = float2(corner.y, 1.0 - corner.x);
    }

    ImageVertexOutput output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.textureCoordinate = mix(uvOrigin, uvEnd, corner);

    return output;
}

fragment half4 imageFragmentShader(
    ImageVertexOutput input [[stage_in]],
    texture2d<half, access::sample> imageTexture [[texture(TextureIndexColor)]]
) {
    constexpr sampler imageSampler(
        coord::normalized,
        address::clamp_to_edge,
        filter::linear
    );

    return imageTexture.sample(
        imageSampler,
        input.textureCoordinate
    );
}

vertex ImageVertexOutput tileVertexShader(
    uint vertexID [[vertex_id]],
    constant TileUniforms &tile [[buffer(BufferIndexImageCrop)]]
) {
    constexpr float2 positions[6] = {
        float2(-1.0,  1.0), float2(-1.0, -1.0), float2( 1.0, -1.0),
        float2(-1.0,  1.0), float2( 1.0, -1.0), float2( 1.0,  1.0)
    };
    constexpr float2 corners[6] = {
        float2(0.0, 0.0), float2(0.0, 1.0), float2(1.0, 1.0),
        float2(0.0, 0.0), float2(1.0, 1.0), float2(1.0, 0.0)
    };

    ImageVertexOutput output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.textureCoordinate = corners[vertexID] * tile.uvScale;
    return output;
}

fragment half4 tileFragmentShader(
    ImageVertexOutput input [[stage_in]],
    texture2d<half, access::sample> tileTexture [[texture(TextureIndexColor)]]
) {
    constexpr sampler tileSampler(
        coord::normalized,
        address::repeat,
        filter::linear
    );

    return tileTexture.sample(tileSampler, input.textureCoordinate);
}

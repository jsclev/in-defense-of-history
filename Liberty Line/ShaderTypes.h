//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2,
    BufferIndexImageCrop     = 3
};

typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

typedef struct
{
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

/// The sub-rectangle of the source texture to sample, in normalized
/// (0...1) texture coordinates: (u0, v0, u1, v1).
///
/// This lets the vertex shader crop the full-screen quad's texture
/// coordinates to whatever region of the source image should fill the
/// current device's screen.
typedef struct
{
    vector_float4 sourceUVRect;

    /// 1 if the drawable is taller than it is wide (a portrait-shaped
    /// window or device orientation), in which case the vertex shader
    /// rotates the sampled image 90° so it still renders in a landscape
    /// orientation, filling the portrait-shaped window edge to edge.
    /// 0 otherwise.
    int32_t rotateToLandscape;
} ImageCropUniforms;

typedef struct
{
    /// drawable size / texture size: UVs above 1 wrap via a repeat sampler.
    vector_float2 uvScale;
} TileUniforms;

#endif /* ShaderTypes_h */


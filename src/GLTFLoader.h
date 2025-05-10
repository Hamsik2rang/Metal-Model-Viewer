#ifndef __GLTF_LOADER_H__
#define __GLTF_LOADER_H__

#include <vector>

#import <Metal/Metal.h>
#import "MathBase.h"

struct Vertex
{
    float3 position;
    float3 normal;
    float2 texCoord;
};

struct Mesh
{
    id<MTLBuffer>    vertexBuffer;
    id<MTLBuffer>    indexBuffer;
    NSUInteger       indexCount;
    MTLPrimitiveType primitiveType;
    id<MTLTexture>   baseColorTexture;
};

@interface GLTFLoader : NSObject

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic) std::vector<Mesh>     meshes;

- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (BOOL)loadModel:(NSString*)path;
@end

#endif

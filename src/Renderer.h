#ifndef __RENDERER_H__
#define __RENDERER_H__

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

#import "MathBase.h"
#import "GLTFLoader.h"

@interface Renderer : NSObject <MTKViewDelegate>

@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, strong) GLTFLoader*     gltfLoader;
@property (nonatomic) float4x4         modelMatrix;
@property (nonatomic) float4x4         viewMatrix;
@property (nonatomic) float4x4         projectionMatrix;
@property (nonatomic) float3             cameraPosition;

- (instancetype)initWithMetalKitView:(MTKView*)mtkView;

@end

#endif

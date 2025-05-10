#include "Renderer.h"

struct Uniforms
{
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3   cameraPosition;
    float    padding; // for 16byte align
};

@implementation Renderer
{
    id<MTLDevice>              _device;
    id<MTLCommandQueue>        _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLDepthStencilState>   _depthStencilState;
    id<MTLSamplerState>        _samplerState;

    MTKView* _view;
    float    _aspectRatio;
}

- (instancetype)initWithMetalKitView:(nonnull MTKView*)mtkView
{
    self = [super init];
    if (self)
    {
        mtkView.delegate = self;
        _view            = mtkView;
        _device          = _view.device;
        _commandQueue    = [_device newCommandQueue];

        mtkView.enableSetNeedsDisplay   = NO; // 자동 렌더링 활성화(기본값)
        mtkView.paused                  = NO; // 렌더링 루프 활성화(기본값)
        mtkView.clearColor              = MTLClearColorMake(1.0, 0.5, 0.2, 1.0);
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
        mtkView.sampleCount             = 1;

        _gltfLoader = [[GLTFLoader alloc] initWithDevice:_device];

        _modelMatrix      = matrix_identity_float4x4;
        _viewMatrix       = matrix_identity_float4x4;
        _cameraPosition   = simd_make_float3(0.0, 0.0, -5.0);
        _aspectRatio      = static_cast<float>(_view.drawableSize.width) / static_cast<float>(_view.drawableSize.height);
        _projectionMatrix = [self perspectiveMatrixLHWithAspect:_aspectRatio fov:65.0 near:0.1 far:1000.0];

        // 카메라 위치 설정
        _viewMatrix = [self lookAtMatrixLHWithEye:_cameraPosition
                                         center:simd_make_float3(0.0, 0.0, 0.0)
                                             up:simd_make_float3(0.0, 1.0, 0.0)];

        // 파이프라인 상태 설정
        [self setupPipeline];
    }

    return self;
}

- (void)setupPipeline
{
    @autoreleasepool
    {
        // 라이브러리 로드
        NSError*       error   = nil;
        id<MTLLibrary> library = [_device newDefaultLibrary];
        if (!library)
        {
            NSLog(@"Failed to load default library: %@", error);
            return;
        }

        // 2. 사용 가능한 모든 함수 나열 (디버깅용)
        NSArray<NSString*>* allFunctions = [library functionNames];
        NSLog(@"사용 가능한 Metal 함수들: %@", allFunctions);

        // 버텍스 & 프래그먼트 함수 가져오기
        id<MTLFunction> vertexFunction   = [library newFunctionWithName:@"vertex_main"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];

        // 버텍스 서술자 설정
        MTLVertexDescriptor* vertexDescriptor = [MTLVertexDescriptor new];

        // 위치 속성
        vertexDescriptor.attributes[0].format      = MTLVertexFormatFloat3;
        vertexDescriptor.attributes[0].offset      = offsetof(Vertex, position);
        vertexDescriptor.attributes[0].bufferIndex = 0;

        // 노멀 속성
        vertexDescriptor.attributes[1].format      = MTLVertexFormatFloat3;
        vertexDescriptor.attributes[1].offset      = offsetof(Vertex, normal);
        vertexDescriptor.attributes[1].bufferIndex = 0;

        // 텍스처 좌표 속성
        vertexDescriptor.attributes[2].format      = MTLVertexFormatFloat2;
        vertexDescriptor.attributes[2].offset      = offsetof(Vertex, texCoord);
        vertexDescriptor.attributes[2].bufferIndex = 0;

        // 레이아웃 설정
        vertexDescriptor.layouts[0].stride       = sizeof(Vertex);
        vertexDescriptor.layouts[0].stepRate     = 1;
        vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

        // 파이프라인 서술자 설정
        MTLRenderPipelineDescriptor* pipelineStateDescriptor    = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineStateDescriptor.label                           = @"GLTF Pipeline";
        pipelineStateDescriptor.vertexFunction                  = vertexFunction;
        pipelineStateDescriptor.fragmentFunction                = fragmentFunction;
        pipelineStateDescriptor.vertexDescriptor                = vertexDescriptor;
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
        pipelineStateDescriptor.depthAttachmentPixelFormat      = _view.depthStencilPixelFormat;

        // 파이프라인 상태 생성
        _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
        if (!_pipelineState)
        {
            NSLog(@"Failed to create pipeline state: %@", error);
            return;
        }

        // 깊이 스텐실 상태 생성
        MTLDepthStencilDescriptor* depthDescriptor = [[MTLDepthStencilDescriptor alloc] init];
        depthDescriptor.depthCompareFunction       = MTLCompareFunctionLess;
        depthDescriptor.depthWriteEnabled          = YES;
        _depthStencilState                         = [_device newDepthStencilStateWithDescriptor:depthDescriptor];

        // 샘플러 상태 생성
        MTLSamplerDescriptor* samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
        samplerDescriptor.minFilter             = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.magFilter             = MTLSamplerMinMagFilterLinear;
        samplerDescriptor.mipFilter             = MTLSamplerMipFilterLinear;
        samplerDescriptor.sAddressMode          = MTLSamplerAddressModeRepeat;
        samplerDescriptor.tAddressMode          = MTLSamplerAddressModeRepeat;
        _samplerState                           = [_device newSamplerStateWithDescriptor:samplerDescriptor];
    }
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(nonnull MTKView*)view
{
    @autoreleasepool
    {

        // 커맨드 버퍼 생성
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

        // 렌더 패스 서술자 생성
        MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
        if (!renderPassDescriptor)
        {
            return;
        }

        // 렌더 인코더 생성
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [encoder setLabel:@"GLTF Render Encoder"];

        // 파이프라인 상태 설정
        [encoder setRenderPipelineState:_pipelineState];
        [encoder setDepthStencilState:_depthStencilState];

        // 유니폼 버퍼 설정
        Uniforms uniforms;
        uniforms.modelMatrix      = _modelMatrix;
        uniforms.viewMatrix       = _viewMatrix;
        uniforms.projectionMatrix = _projectionMatrix;
        uniforms.cameraPosition   = _cameraPosition;
        [encoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:1];

        // 샘플러 설정
        [encoder setFragmentSamplerState:_samplerState atIndex:0];

        // 메시 렌더링
        for (const auto& mesh : _gltfLoader.meshes)
        {
            // 버텍스 버퍼 설정
            [encoder setVertexBuffer:mesh.vertexBuffer offset:0 atIndex:0];

            // 텍스처 설정
            if (mesh.baseColorTexture)
            {
                [encoder setFragmentTexture:mesh.baseColorTexture atIndex:0];
            }

            // 인덱스 버퍼가 있으면 인덱스로 그리기
            if (mesh.indexBuffer && mesh.indexCount > 0)
            {
                [encoder drawIndexedPrimitives:mesh.primitiveType
                                    indexCount:mesh.indexCount
                                     indexType:MTLIndexTypeUInt32
                                   indexBuffer:mesh.indexBuffer
                             indexBufferOffset:0];
            }
            else
            {
                // 인덱스 버퍼가 없으면 정점으로 그리기
                NSUInteger vertexCount = mesh.vertexBuffer.length / sizeof(Vertex);
                [encoder drawPrimitives:mesh.primitiveType
                            vertexStart:0
                            vertexCount:vertexCount];
            }
        }

        // 렌더 인코더 종료
        [encoder endEncoding];

        // 커맨드 버퍼 커밋
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

- (void)mtkView:(nonnull MTKView*)view drawableSizeWillChange:(CGSize)size
{
    _aspectRatio      = (float)size.width / (float)size.height;
    _projectionMatrix = [self perspectiveMatrixLHWithAspect:_aspectRatio fov:65.0 near:0.1 far:1000.0];
}

#pragma mark - Matrix Utilities

- (float4x4)perspectiveMatrixLHWithAspect:(float)aspect fov:(float)fov near:(float)near far:(float)far
{
    float fovRadians = fov * (M_PI / 180.0);
    float ys = 1.0 / tanf(fovRadians * 0.5);
    float xs = ys / aspect;
    float zs = far / (far - near);
    
    // 왼손좌표계용 투영 행렬 구성
    return (float4x4){
        .columns[0] = {xs, 0, 0, 0},
        .columns[1] = {0, ys, 0, 0},
        .columns[2] = {0, 0, zs, 1},
        .columns[3] = {0, 0, -near * zs, 0}
    };
}

- (float4x4)lookAtMatrixLHWithEye:(float3)eye center:(float3)center up:(float3)up
{
    // 왼손좌표계에서는 시선 방향이 z의 양의 방향
    float3 z = simd_normalize(center - eye);
    // x축은 위 벡터와 z축의 외적
    float3 x = simd_normalize(simd_cross(up, -z));
    // y축은 z축과 x축의 외적으로 계산
    float3 y = simd_cross(-z, x);
    
    // 행렬 구성
    return (float4x4) {
        .columns[0] = { x.x, y.x, z.x, 0 },
        .columns[1] = { x.y, y.y, z.y, 0 },
        .columns[2] = { x.z, y.z, z.z, 0 },
        .columns[3] = { -simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1 }
    };
}

@end

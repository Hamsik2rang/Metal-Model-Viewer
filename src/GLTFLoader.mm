#define TINYGLTF_IMPLEMENTATION
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATIION
#define TINYGLTF_NO_STB_IMAGE_WRITE
#include "tiny_gltf.h"

#include <string>

#import "GLTFLoader.h"
#import "MetalKit/MetalKit.h"

@implementation GLTFLoader
{
    tinygltf::Model _model;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
{
    self = [super init];
    if (self)
    {
        _device = device;
    }
    return self;
}

- (BOOL)loadModel:(NSString*)path
{
    tinygltf::TinyGLTF loader;
    std::string        error;
    std::string        warning;

    bool result = loader.LoadASCIIFromFile(&_model, &error, &warning, [path UTF8String]);

    if (!warning.empty())
    {
        NSLog(@"glTF warning: %s", warning.c_str());
    }

    if (!error.empty())
    {
        NSLog(@"glTF error: %s", error.c_str());
    }

    if (!result)
    {
        NSLog(@"Failed to load glTF model");
        return NO;
    }

    
    for (const auto& mesh : _model.meshes)
    {
        for (const auto& primitive : mesh.primitives)
        {
            Mesh newMesh{};
            if ([self processPrimitive:primitive outMesh:newMesh])
            {
                _meshes.push_back(newMesh);
            }
        }
    }

    return YES;
}

- (BOOL)processPrimitive:(const tinygltf::Primitive&)primitive outMesh:(Mesh&)mesh
{
    // 인덱스 버퍼 생성
    if (primitive.indices >= 0)
    {
        const tinygltf::Accessor&   accessor   = _model.accessors[primitive.indices];
        const tinygltf::BufferView& bufferView = _model.bufferViews[accessor.bufferView];
        const tinygltf::Buffer&     buffer     = _model.buffers[bufferView.buffer];

        const void* dataPtr    = &buffer.data[bufferView.byteOffset + accessor.byteOffset];
        NSUInteger  indexCount = accessor.count;
        mesh.indexCount        = indexCount;

        // 인덱스 타입에 따라 처리
        NSMutableData* indexData = [NSMutableData dataWithLength:indexCount * sizeof(uint32_t)];
        uint32_t*      indices   = (uint32_t*)indexData.mutableBytes;

        if (accessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_SHORT)
        {
            const uint16_t* src = (const uint16_t*)dataPtr;
            for (NSUInteger i = 0; i < indexCount; i++)
            {
                indices[i] = src[i];
            }
        }
        else if (accessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_INT)
        {
            memcpy(indices, dataPtr, indexCount * sizeof(uint32_t));
        }
        else if (accessor.componentType == TINYGLTF_COMPONENT_TYPE_UNSIGNED_BYTE)
        {
            const uint8_t* src = (const uint8_t*)dataPtr;
            for (NSUInteger i = 0; i < indexCount; i++)
            {
                indices[i] = src[i];
            }
        }

        mesh.indexBuffer = [_device newBufferWithBytes:indices
                                                length:indexCount * sizeof(uint32_t)
                                               options:MTLResourceStorageModeShared];
    }

    // 정점 버퍼 생성
    std::vector<Vertex> vertices;

    // 위치 속성
    auto positionIt = primitive.attributes.find("POSITION");
    if (positionIt == primitive.attributes.end())
    {
        NSLog(@"No POSITION attribute found");
        return NO;
    }

    const tinygltf::Accessor&   posAccessor   = _model.accessors[positionIt->second];
    const tinygltf::BufferView& posBufferView = _model.bufferViews[posAccessor.bufferView];
    const tinygltf::Buffer&     posBuffer     = _model.buffers[posBufferView.buffer];
    const float*                positions     = reinterpret_cast<const float*>(&posBuffer.data[posBufferView.byteOffset + posAccessor.byteOffset]);

    // 정점 개수
    NSUInteger vertexCount = posAccessor.count;
    vertices.resize(vertexCount);

    // 위치 데이터 복사
    for (NSUInteger i = 0; i < vertexCount; i++)
    {
        vertices[i].position = {
            positions[i * 3 + 0],
            positions[i * 3 + 1],
            positions[i * 3 + 2],
        };
    }

    // 노멀 속성 (있는 경우)
    auto normalIt = primitive.attributes.find("NORMAL");
    if (normalIt != primitive.attributes.end())
    {
        const tinygltf::Accessor&   normalAccessor   = _model.accessors[normalIt->second];
        const tinygltf::BufferView& normalBufferView = _model.bufferViews[normalAccessor.bufferView];
        const tinygltf::Buffer&     normalBuffer     = _model.buffers[normalBufferView.buffer];
        const float*                normals          = reinterpret_cast<const float*>(&normalBuffer.data[normalBufferView.byteOffset + normalAccessor.byteOffset]);

        for (NSUInteger i = 0; i < vertexCount; i++)
        {
            vertices[i].normal = {
                normals[i * 3 + 0],
                normals[i * 3 + 1],
                normals[i * 3 + 2]
            };
        }
    }

    // 텍스처 좌표 속성 (있는 경우)
    auto texcoordIt = primitive.attributes.find("TEXCOORD_0");
    if (texcoordIt != primitive.attributes.end())
    {
        const tinygltf::Accessor&   texcoordAccessor   = _model.accessors[texcoordIt->second];
        const tinygltf::BufferView& texcoordBufferView = _model.bufferViews[texcoordAccessor.bufferView];
        const tinygltf::Buffer&     texcoordBuffer     = _model.buffers[texcoordBufferView.buffer];
        const float*                texcoords          = reinterpret_cast<const float*>(&texcoordBuffer.data[texcoordBufferView.byteOffset + texcoordAccessor.byteOffset]);

        for (NSUInteger i = 0; i < vertexCount; i++)
        {
            vertices[i].texCoord = {
                texcoords[i * 2 + 0],
                texcoords[i * 2 + 1]
            };
        }
    }

    // 정점 버퍼 생성
    mesh.vertexBuffer = [_device newBufferWithBytes:vertices.data()
                                             length:vertices.size() * sizeof(Vertex)
                                            options:MTLResourceStorageModeShared];

    // Primitive 타입 설정
    switch (primitive.mode)
    {
        case TINYGLTF_MODE_TRIANGLES:
            mesh.primitiveType = MTLPrimitiveTypeTriangle;
            break;
        case TINYGLTF_MODE_TRIANGLE_STRIP:
            mesh.primitiveType = MTLPrimitiveTypeTriangleStrip;
            break;
        case TINYGLTF_MODE_TRIANGLE_FAN:
            // Metal은 Triangle Fan을 직접 지원하지 않으므로 삼각형으로 변환 필요
            mesh.primitiveType = MTLPrimitiveTypeTriangle;
            break;
        default:
            mesh.primitiveType = MTLPrimitiveTypeTriangle;
            break;
    }

    // 텍스처 로드 (있는 경우)
    if (primitive.material >= 0)
    {
        const tinygltf::Material& material = _model.materials[primitive.material];
        if (material.pbrMetallicRoughness.baseColorTexture.index >= 0)
        {
            int                      textureIndex = material.pbrMetallicRoughness.baseColorTexture.index;
            const tinygltf::Texture& texture      = _model.textures[textureIndex];
            const tinygltf::Image&   image        = _model.images[texture.source];

            MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor
                texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                             width:image.width
                                            height:image.height
                                         mipmapped:YES];

            mesh.baseColorTexture = [_device newTextureWithDescriptor:textureDescriptor];

            MTLRegion region = MTLRegionMake2D(0, 0, image.width, image.height);
            [mesh.baseColorTexture replaceRegion:region
                                     mipmapLevel:0
                                       withBytes:image.image.data()
                                     bytesPerRow:image.width * 4];
        }
        else
        {
            // 텍스처가 없는 경우 기본 흰색 텍스처 생성
            uint8_t               white[4]          = {255, 255, 255, 255};
            MTLTextureDescriptor* textureDescriptor = [MTLTextureDescriptor
                texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                             width:1
                                            height:1
                                         mipmapped:NO];

            mesh.baseColorTexture = [_device newTextureWithDescriptor:textureDescriptor];

            MTLRegion region = MTLRegionMake2D(0, 0, 1, 1);
            [mesh.baseColorTexture replaceRegion:region
                                     mipmapLevel:0
                                       withBytes:white
                                     bytesPerRow:4];
        }
    }

    return YES;
}

@end

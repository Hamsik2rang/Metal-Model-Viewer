#include "ViewController.h"
#include "Renderer.h"

@implementation ViewController
{
    Renderer* _renderer;
    NSString* _modelPath;

    NSPoint _lastMousePosition;
    float   _rotationX;
    float   _rotationY;
    float   _scale;
}

- (void)loadView
{
    self.view = [[MTKView alloc] initWithFrame: NSMakeRect(0,0,800,600) device:MTLCreateSystemDefaultDevice()];
    _mtkView = (MTKView*)self.view;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.window.delegate = self;
    
    _mtkView = (MTKView*)self.view;

    NSButton* loadButton  = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 100, 30)];
    loadButton.title      = @"Load Model";
    loadButton.bezelStyle = NSBezelStyleRounded;
    loadButton.target     = self;
    loadButton.action     = @selector(loadModelButtonPressed:);
    [self.view addSubview:loadButton];

    _mtkView        = (MTKView*)self.view;
    _mtkView.device = MTLCreateSystemDefaultDevice();
    if (nil == _mtkView.device)
    {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    _renderer = [[Renderer alloc] initWithMetalKitView:_mtkView];

    // 회전 및 스케일 초기화
    _rotationX = 0.0;
    _rotationY = 0.0;
    _scale     = 1.0;
}

// 마우스 이벤트 핸들러
- (void)mouseDown:(NSEvent*)event
{
    _lastMousePosition = [self.view convertPoint:event.locationInWindow fromView:nil];
}

- (void)mouseDragged:(NSEvent*)event
{
    NSPoint currentPosition = [self.view convertPoint:event.locationInWindow fromView:nil];
    float   deltaX          = currentPosition.x - _lastMousePosition.x;
    float   deltaY          = currentPosition.y - _lastMousePosition.y;

    if (event.modifierFlags & NSEventModifierFlagOption)
    {
        // Option 키를 누르고 드래그하면 확대/축소
        _scale += deltaY * 0.01;
        _scale = fmax(0.1, fmin(5.0, _scale));
    }
    else
    {
        // 일반 드래그는 회전
        _rotationY += deltaX * 0.01;
        _rotationX += deltaY * 0.01;
    }

    // 모델 매트릭스 업데이트
    [self updateModelMatrix];

    _lastMousePosition = currentPosition;
}

- (void)scrollWheel:(NSEvent*)event
{
    // 스크롤 휠로 확대/축소
    _scale -= event.deltaY * 0.01;
    _scale = fmax(0.1, fmin(5.0, _scale));

    // 모델 매트릭스 업데이트
    [self updateModelMatrix];
}

- (void)updateModelMatrix
{
    // 회전 및 스케일 매트릭스 생성
    float4x4 rotationMatrix = matrix_multiply(
        [self rotationMatrix4x4AboutY:_rotationY],
        [self rotationMatrix4x4AboutX:_rotationX]
    );

    float4x4 scaleMatrix = [self scaleMatrix4x4:_scale];

    // 모델 매트릭스 업데이트
    _renderer.modelMatrix = matrix_multiply(rotationMatrix, scaleMatrix);
}

// 매트릭스 유틸리티 함수
- (float4x4)rotationMatrix4x4AboutX:(float)angle
{
    float c = cosf(angle);
    float s = sinf(angle);

    return (float4x4){
        .columns[0] = {1, 0, 0, 0},
        .columns[1] = {0, c, s, 0},
        .columns[2] = {0, -s, c, 0},
        .columns[3] = {0, 0, 0, 1}
    };
}

- (float4x4)rotationMatrix4x4AboutY:(float)angle
{
    float c = cosf(angle);
    float s = sinf(angle);

    return (float4x4){
        .columns[0] = {c, 0, -s, 0},
        .columns[1] = {0, 1, 0, 0},
        .columns[2] = {s, 0, c, 0},
        .columns[3] = {0, 0, 0, 1}
    };
}

- (float4x4)scaleMatrix4x4:(float)scale
{
    return (float4x4){
        .columns[0] = {scale, 0, 0, 0},
        .columns[1] = {0, scale, 0, 0},
        .columns[2] = {0, 0, scale, 0},
        .columns[3] = {0, 0, 0, 1}
    };
}

- (void)loadModelButtonPressed:(id)sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    openPanel.title        = @"Select glTF Model";

    openPanel.allowsMultipleSelection = NO;

    [openPanel beginSheetModalForWindow:self.view.window
                      completionHandler:^(NSModalResponse result) {
                        if (result == NSModalResponseOK)
                        {
                            self->_modelPath = openPanel.URL.path;
                            [self loadModel];
                        }
                      }];
}

- (void)loadModel
{
    if (_modelPath)
    {
        // 모델 로드
        BOOL success = [_renderer.gltfLoader loadModel:_modelPath];
        if (success)
        {
            NSLog(@"Model loaded successfully: %@", _modelPath);
        }
        else
        {
            NSLog(@"Failed to load model: %@", _modelPath);
            // 오류 알림 표시
            NSAlert* alert        = [[NSAlert alloc] init];
            alert.messageText     = @"Error";
            alert.informativeText = [NSString stringWithFormat:@"Failed to load model: %@", _modelPath];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        }
    }
}
@end

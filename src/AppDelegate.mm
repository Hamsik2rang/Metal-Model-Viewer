#import "AppDelegate.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification
{
    // 메인 윈도우 생성
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    self.window  = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSWindowStyleMaskTitled |
                                                        NSWindowStyleMaskClosable |
                                                        NSWindowStyleMaskResizable |
                                                        NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Model Viewer"];
    [self.window center];

    _viewController = [[ViewController alloc] init];
    [self.window setContentViewController:_viewController];

    // Metal 장치 생성
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device)
    {
        NSLog(@"Metal is not supported on this device");
        return;
    }
    // 화면 크기 확인
    NSScreen *mainScreen = [NSScreen mainScreen];
    NSLog(@"메인 화면 크기: %@", NSStringFromRect(mainScreen.frame));
    
    // 윈도우 위치 확인
    NSLog(@"윈도우 프레임: %@", NSStringFromRect(self.window.frame));
    
    // 윈도우 위치를 화면 중앙으로 강제 조정
    [self.window center];
    NSLog(@"중앙 배치 후 윈도우 프레임: %@", NSStringFromRect(self.window.frame));
    
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    NSLog(@"윈도우 상태: isVisible=%d, isKeyWindow=%d", [self.window isVisible], [self.window isKeyWindow]);
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
    return YES;
}

@end

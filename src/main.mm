#include "AppDelegate.h"

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

NSWindow* createWindow()
{
    NSRect    frame  = NSMakeRect(0, 0, 800, 600);
    NSWindow* window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable | NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];

    [window setTitle:@"Model Viewer"];
    [window center];
    [window makeKeyAndOrderFront:nil];

    return window;
}

int main(int argc, const char* argv[])
{
    @autoreleasepool
    {
        // NSApplication 초기화
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        // AppDelegate 생성 및 설정
        AppDelegate* appDelegate = [[AppDelegate alloc] init];
        [NSApp setDelegate:appDelegate];

        // 메뉴바 생성
        NSMenu*     menubar     = [NSMenu new];
        NSMenuItem* appMenuItem = [NSMenuItem new];
        [menubar addItem:appMenuItem];
        [NSApp setMainMenu:menubar];

        NSMenu*     appMenu       = [NSMenu new];
        NSMenuItem* quitMenuItem  = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                              action:@selector(terminate:)
                                                       keyEquivalent:@"q"];
        NSMenuItem* loadModelItem = [[NSMenuItem alloc] initWithTitle:@"Load Model"
                                                               action:@selector(loadModel:)
                                                        keyEquivalent:@"m"];
        
        [appMenu addItem:quitMenuItem];
        [appMenu addItem:loadModelItem];
        [appMenuItem setSubmenu:appMenu];
        
//        ViewController* viewController = [[ViewController alloc] init];
//        NSWindow* window = createWindow();
//        [window setContentViewController:viewController];
//        
        [NSApp activateIgnoringOtherApps:YES];

        // NSApplication 실행
        [NSApp run];
    }

    return 0;
}

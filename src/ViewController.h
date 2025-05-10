#ifndef __VIEW_CONTROLLER_H__
#define __VIEW_CONTROLLER_H__

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>
#import <MetalKit/MetalKit.h>

@interface ViewController : NSViewController<NSWindowDelegate> 

@property (nonatomic, strong) MTKView* mtkView;


@end

#endif

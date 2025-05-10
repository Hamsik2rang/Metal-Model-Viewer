#ifndef __APP_DELEGATE_H__
#define __APP_DELEGATE_H__

#import <Cocoa/Cocoa.h>
#import "ViewController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong, nonatomic) NSWindow*       window;
@property (strong, nonatomic) ViewController* viewController;

@end

#endif

#include "ImGuiOverlay.h"
#include <objc/runtime.h>
#include <objc/message.h>
#include <UIKit/UIKit.h>
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>
#define HOOK_METHOD(cls_name, sel_name, new_imp, orig_ptr) \
    do { \
        Class _cls = objc_getClass(cls_name); \
        if (_cls) { \
            Method _m = class_getInstanceMethod(_cls, sel_name); \
            if (_m) { \
                orig_ptr = (__typeof__(orig_ptr))method_getImplementation(_m); \
                method_setImplementation(_m, (IMP)new_imp); \
            } \
        } \
    } while (0)
static void (*orig_presentDrawable)(id, SEL, id<MTLDrawable>) = nullptr;
static void hook_presentDrawable(id self, SEL _cmd, id<MTLDrawable> drawable) {
    if (drawable && [drawable conformsToProtocol:@protocol(CAMetalDrawable)]) {
        id<CAMetalDrawable> metalDrawable = (id<CAMetalDrawable>)drawable;
        id<MTLCommandBuffer> cmdBuf = (id<MTLCommandBuffer>)self;
        id<MTLDevice> device = cmdBuf.device;
        if (device && metalDrawable.texture) {
            static dispatch_once_t onceToken;
            static id<MTLCommandQueue> queue = nil;
            dispatch_once(&onceToken, ^{
                queue = [device newCommandQueue];
                [[ImGuiOverlay sharedInstance] setupWithDevice:device
                                                  commandQueue:queue
                                              colorPixelFormat:metalDrawable.texture.pixelFormat];
            });
            MTLRenderPassDescriptor *rpd = [MTLRenderPassDescriptor renderPassDescriptor];
            rpd.colorAttachments[0].texture = metalDrawable.texture;
            rpd.colorAttachments[0].loadAction = MTLLoadActionLoad;
            rpd.colorAttachments[0].storeAction = MTLStoreActionStore;
            [[ImGuiOverlay sharedInstance] beginFrameWithCommandBuffer:cmdBuf
                                                  renderPassDescriptor:rpd];
            id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
            if (enc) {
                [[ImGuiOverlay sharedInstance] endFrameWithCommandEncoder:enc];
                [enc endEncoding];
            }
        }
    }
    orig_presentDrawable(self, _cmd, drawable);
}
static void (*orig_sendEvent)(id, SEL, UIEvent *) = nullptr;
static void hook_sendEvent(id self, SEL _cmd, UIEvent *event) {
    if (event.type == UIEventTypeTouches) {
        NSSet<UITouch *> *touches = [event allTouches];
        UITouch *touch = [touches anyObject];
        if (touch) {
            if (touch.phase == UITouchPhaseBegan) {
                [[ImGuiOverlay sharedInstance] handleTouchesBegan:touches withEvent:event];
            } else if (touch.phase == UITouchPhaseMoved) {
                [[ImGuiOverlay sharedInstance] handleTouchesMoved:touches withEvent:event];
            } else if (touch.phase == UITouchPhaseEnded) {
                [[ImGuiOverlay sharedInstance] handleTouchesEnded:touches withEvent:event];
            } else if (touch.phase == UITouchPhaseCancelled) {
                [[ImGuiOverlay sharedInstance] handleTouchesCancelled:touches withEvent:event];
            }
        }
    }
    orig_sendEvent(self, _cmd, event);
}
__attribute__((constructor))
static void overlayConstructor() {
    @autoreleasepool {
        const char *classes[] = {
            "_MTLCommandBuffer",
            "MTLIOAccelCommandBuffer",
            "AGXG13XFamilyCommandBuffer",
            "AGXG14XFamilyCommandBuffer",
            "AGXG15XFamilyCommandBuffer"
        };
        for (const char *className : classes) {
            Class cls = objc_getClass(className);
            if (cls) {
                Method m = class_getInstanceMethod(cls, @selector(presentDrawable:));
                if (m && !orig_presentDrawable) {
                    orig_presentDrawable = (void (*)(id, SEL, id<MTLDrawable>))method_getImplementation(m);
                    method_setImplementation(m, (IMP)hook_presentDrawable);
                }
            }
        }
        HOOK_METHOD("UIWindow",
                    @selector(sendEvent:),
                    hook_sendEvent,
                    orig_sendEvent);
        NSLog(@"[ImGuiOverlay] Flicker-free presentDrawable hooks installed.");
    }
}

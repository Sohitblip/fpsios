#include "ImGuiOverlay.h"
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>
#include <UIKit/UIKit.h>
#include <objc/message.h>
#include <objc/runtime.h>

#define HOOK_METHOD(cls_name, sel_name, new_imp, orig_ptr)                     \
  do {                                                                         \
    Class _cls = objc_getClass(cls_name);                                      \
    if (_cls) {                                                                \
      Method _m = class_getInstanceMethod(_cls, sel_name);                     \
      if (_m) {                                                                \
        orig_ptr = (__typeof__(orig_ptr))method_getImplementation(_m);         \
        method_setImplementation(_m, (IMP)new_imp);                            \
      }                                                                        \
    }                                                                          \
  } while (0)

// ─────────────────────────────────────────────────────────────────────────────
// CAMetalLayer nextDrawable Hook (Unreal Engine Compatible)
// ─────────────────────────────────────────────────────────────────────────────
static id<CAMetalDrawable> (*orig_CAMetalLayer_nextDrawable)(
    id self, SEL _cmd) = nullptr;

static id<CAMetalDrawable> hook_CAMetalLayer_nextDrawable(id self, SEL _cmd) {
  id<CAMetalDrawable> drawable = orig_CAMetalLayer_nextDrawable(self, _cmd);
  if (!drawable)
    return drawable;

  CAMetalLayer *layer = (CAMetalLayer *)self;
  id<MTLDevice> device = layer.device;
  if (!device)
    return drawable;

  static dispatch_once_t once;
  static id<MTLCommandQueue> queue = nil;
  dispatch_once(&once, ^{
    queue = [device newCommandQueue];
    [[ImGuiOverlay sharedInstance] setupWithDevice:device
                                      commandQueue:queue
                                  colorPixelFormat:layer.pixelFormat];
  });

  if (!queue)
    return drawable;

  id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
  MTLRenderPassDescriptor *rpd = [MTLRenderPassDescriptor renderPassDescriptor];
  rpd.colorAttachments[0].texture = drawable.texture;
  rpd.colorAttachments[0].loadAction = MTLLoadActionLoad;
  rpd.colorAttachments[0].storeAction = MTLStoreActionStore;

  [[ImGuiOverlay sharedInstance] beginFrameWithCommandBuffer:cmdBuf
                                        renderPassDescriptor:rpd];

  id<MTLRenderCommandEncoder> enc =
      [cmdBuf renderCommandEncoderWithDescriptor:rpd];
  [[ImGuiOverlay sharedInstance] endFrameWithCommandEncoder:enc];
  [enc endEncoding];

  [cmdBuf presentDrawable:drawable];
  [cmdBuf commit];

  return drawable;
}

// ─────────────────────────────────────────────────────────────────────────────
// UIWindow Touch Event Hook
// ─────────────────────────────────────────────────────────────────────────────
static void (*orig_sendEvent)(id, SEL, UIEvent *) = nullptr;

static void hook_sendEvent(id self, SEL _cmd, UIEvent *event) {
  if (event.type == UIEventTypeTouches) {
    NSSet<UITouch *> *touches = [event allTouches];
    UITouch *touch = [touches anyObject];
    if (touch) {
      if (touch.phase == UITouchPhaseBegan) {
        [[ImGuiOverlay sharedInstance] handleTouchesBegan:touches
                                                withEvent:event];
      } else if (touch.phase == UITouchPhaseMoved) {
        [[ImGuiOverlay sharedInstance] handleTouchesMoved:touches
                                                withEvent:event];
      } else if (touch.phase == UITouchPhaseEnded) {
        [[ImGuiOverlay sharedInstance] handleTouchesEnded:touches
                                                withEvent:event];
      } else if (touch.phase == UITouchPhaseCancelled) {
        [[ImGuiOverlay sharedInstance] handleTouchesCancelled:touches
                                                    withEvent:event];
      }
    }
  }
  orig_sendEvent(self, _cmd, event);
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry Constructor
// ─────────────────────────────────────────────────────────────────────────────
__attribute__((constructor)) static void overlayConstructor() {
  @autoreleasepool {
    HOOK_METHOD("CAMetalLayer", @selector(nextDrawable),
                hook_CAMetalLayer_nextDrawable, orig_CAMetalLayer_nextDrawable);

    HOOK_METHOD("UIWindow", @selector(sendEvent:), hook_sendEvent,
                orig_sendEvent);

    NSLog(@"[ImGuiOverlay] CAMetalLayer hooks initialized.");
  }
}
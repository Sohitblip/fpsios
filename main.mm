// main.mm
// dylib constructor / hook entry point
// iOS 15+  |  Metal rendering pipeline  |  arm64 / arm64e

#include "ImGuiOverlay.h"
#include <objc/runtime.h>
#include <objc/message.h>
#include <UIKit/UIKit.h>
#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
#define HOOK_METHOD(cls, sel, imp, origPtr)                              \
    do {                                                                 \
        Method m = class_getInstanceMethod(objc_getClass(cls), sel);     \
        if (m) { origPtr = (typeof(origPtr))method_getImplementation(m); \
                 method_setImplementation(m, (IMP)imp); }                \
    } while(0)

// ─────────────────────────────────────────────────────────────────────────────
// MTKView draw hook
// Intercept -[MTKView draw] so we can inject ImGui after each game frame.
// ─────────────────────────────────────────────────────────────────────────────
static void (*orig_MTKView_draw)(id self, SEL _cmd) = nullptr;

static void hook_MTKView_draw(id self, SEL _cmd) {
    orig_MTKView_draw(self, _cmd); // let game render first

    MTKView *view = (MTKView *)self;
    id<MTLDevice> device = view.device;
    if (!device) return;

    // Lazy-init overlay on first real frame
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        id<MTLCommandQueue> queue = [device newCommandQueue];
        MTLPixelFormat fmt = view.colorPixelFormat;
        [[ImGuiOverlay sharedInstance] setupWithDevice:device
                                          commandQueue:queue
                                      colorPixelFormat:fmt];
    });

    // Build a command buffer for the overlay pass
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) return;

    // Begin ImGui frame (updates display size, delta time, FPS, builds UI)
    [[ImGuiOverlay sharedInstance] beginFrameWithCommandBuffer:cmdBuf
                                          renderPassDescriptor:rpd];

    // Encode ImGui draw calls
    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    [[ImGuiOverlay sharedInstance] endFrameWithCommandEncoder:enc];
    [enc endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}

// ─────────────────────────────────────────────────────────────────────────────
// UIView touch hooks – forward all window-level touches to ImGui;
// the overlay returns YES if it consumed the event (game won't see it).
// ─────────────────────────────────────────────────────────────────────────────
static void (*orig_UIView_touchesBegan)(id, SEL, NSSet *, UIEvent *) = nullptr;
static void (*orig_UIView_touchesMoved)(id, SEL, NSSet *, UIEvent *) = nullptr;
static void (*orig_UIView_touchesEnded)(id, SEL, NSSet *, UIEvent *) = nullptr;
static void (*orig_UIView_touchesCancelled)(id, SEL, NSSet *, UIEvent *) = nullptr;

static void hook_touchesBegan(id self, SEL _cmd, NSSet<UITouch*> *touches, UIEvent *ev) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesBegan:touches withEvent:ev];
    if (!consumed) orig_UIView_touchesBegan(self, _cmd, touches, ev);
}
static void hook_touchesMoved(id self, SEL _cmd, NSSet<UITouch*> *touches, UIEvent *ev) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesMoved:touches withEvent:ev];
    if (!consumed) orig_UIView_touchesMoved(self, _cmd, touches, ev);
}
static void hook_touchesEnded(id self, SEL _cmd, NSSet<UITouch*> *touches, UIEvent *ev) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesEnded:touches withEvent:ev];
    if (!consumed) orig_UIView_touchesEnded(self, _cmd, touches, ev);
}
static void hook_touchesCancelled(id self, SEL _cmd, NSSet<UITouch*> *touches, UIEvent *ev) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesCancelled:touches withEvent:ev];
    if (!consumed) orig_UIView_touchesCancelled(self, _cmd, touches, ev);
}

// ─────────────────────────────────────────────────────────────────────────────
// Constructor – called automatically when the dylib is loaded by the host app
// ─────────────────────────────────────────────────────────────────────────────
__attribute__((constructor))
static void overlayConstructor() {
    // Hook Metal view draw
    HOOK_METHOD("MTKView",
                @selector(draw),
                (IMP)hook_MTKView_draw,
                orig_MTKView_draw);

    // Hook UIView touch responder chain
    HOOK_METHOD("UIView",
                @selector(touchesBegan:withEvent:),
                (IMP)hook_touchesBegan,
                orig_UIView_touchesBegan);
    HOOK_METHOD("UIView",
                @selector(touchesMoved:withEvent:),
                (IMP)hook_touchesMoved,
                orig_UIView_touchesMoved);
    HOOK_METHOD("UIView",
                @selector(touchesEnded:withEvent:),
                (IMP)hook_touchesEnded,
                orig_UIView_touchesEnded);
    HOOK_METHOD("UIView",
                @selector(touchesCancelled:withEvent:),
                (IMP)hook_touchesCancelled,
                orig_UIView_touchesCancelled);

    NSLog(@"[ImGuiOverlay] Hooks installed.");
}

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
// HOOK_METHOD: swaps an Objective-C method implementation at runtime.
// Uses __typeof__ (Clang extension) instead of typeof — safe in C++17 mode.
// ─────────────────────────────────────────────────────────────────────────────
#define HOOK_METHOD(cls_name, sel_name, new_imp, orig_ptr)                \
    do {                                                                   \
        Class _cls = objc_getClass(cls_name);                             \
        if (_cls) {                                                        \
            Method _m = class_getInstanceMethod(_cls, sel_name);          \
            if (_m) {                                                      \
                orig_ptr = (__typeof__(orig_ptr))method_getImplementation(_m); \
                method_setImplementation(_m, (IMP)new_imp);               \
            }                                                              \
        }                                                                  \
    } while (0)

// ─────────────────────────────────────────────────────────────────────────────
// MTKView draw hook
// Intercept -[MTKView draw] to inject ImGui after each game frame.
// ─────────────────────────────────────────────────────────────────────────────
static void (*orig_MTKView_draw)(id self, SEL _cmd) = nullptr;

static void hook_MTKView_draw(id self, SEL _cmd) {
    // Let the game render first
    orig_MTKView_draw(self, _cmd);

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

    // Build command buffer for the overlay pass
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> cmdBuf = [queue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd || !view.currentDrawable) return;

    // Don't clear the framebuffer — just load existing content
    // MTLRenderPassColorAttachmentDescriptorArray doesn't support fast-enumeration; use index directly.
    rpd.colorAttachments[0].loadAction = MTLLoadActionLoad;

    [[ImGuiOverlay sharedInstance] beginFrameWithCommandBuffer:cmdBuf
                                          renderPassDescriptor:rpd];

    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    [[ImGuiOverlay sharedInstance] endFrameWithCommandEncoder:enc];
    [enc endEncoding];

    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}

// ─────────────────────────────────────────────────────────────────────────────
// UIView touch hooks
// ─────────────────────────────────────────────────────────────────────────────
static void (*orig_touchesBegan)(id, SEL, NSSet *, UIEvent *)     = nullptr;
static void (*orig_touchesMoved)(id, SEL, NSSet *, UIEvent *)     = nullptr;
static void (*orig_touchesEnded)(id, SEL, NSSet *, UIEvent *)     = nullptr;
static void (*orig_touchesCancelled)(id, SEL, NSSet *, UIEvent *) = nullptr;

static void hook_touchesBegan(id self, SEL cmd, NSSet<UITouch *> *t, UIEvent *e) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesBegan:t withEvent:e];
    if (!consumed && orig_touchesBegan) orig_touchesBegan(self, cmd, t, e);
}
static void hook_touchesMoved(id self, SEL cmd, NSSet<UITouch *> *t, UIEvent *e) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesMoved:t withEvent:e];
    if (!consumed && orig_touchesMoved) orig_touchesMoved(self, cmd, t, e);
}
static void hook_touchesEnded(id self, SEL cmd, NSSet<UITouch *> *t, UIEvent *e) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesEnded:t withEvent:e];
    if (!consumed && orig_touchesEnded) orig_touchesEnded(self, cmd, t, e);
}
static void hook_touchesCancelled(id self, SEL cmd, NSSet<UITouch *> *t, UIEvent *e) {
    BOOL consumed = [[ImGuiOverlay sharedInstance] handleTouchesCancelled:t withEvent:e];
    if (!consumed && orig_touchesCancelled) orig_touchesCancelled(self, cmd, t, e);
}

// ─────────────────────────────────────────────────────────────────────────────
// Constructor — runs automatically when the dylib is loaded
// ─────────────────────────────────────────────────────────────────────────────
__attribute__((constructor))
static void overlayConstructor() {
    @autoreleasepool {
        // Hook Metal view draw
        HOOK_METHOD("MTKView",
                    @selector(draw),
                    hook_MTKView_draw,
                    orig_MTKView_draw);

        // Hook UIView touch responder chain
        HOOK_METHOD("UIView",
                    @selector(touchesBegan:withEvent:),
                    hook_touchesBegan,
                    orig_touchesBegan);

        HOOK_METHOD("UIView",
                    @selector(touchesMoved:withEvent:),
                    hook_touchesMoved,
                    orig_touchesMoved);

        HOOK_METHOD("UIView",
                    @selector(touchesEnded:withEvent:),
                    hook_touchesEnded,
                    orig_touchesEnded);

        HOOK_METHOD("UIView",
                    @selector(touchesCancelled:withEvent:),
                    hook_touchesCancelled,
                    orig_touchesCancelled);

        NSLog(@"[ImGuiOverlay] Hooks installed successfully.");
    }
}
#pragma once

// ImGuiOverlay.h
// Dear ImGui performance/debug overlay for iOS 15+ dylib injection
// Supports Metal rendering backend (arm64/arm64e)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>

// Dear ImGui forward declarations
struct ImGuiContext;
struct ImDrawData;

NS_ASSUME_NONNULL_BEGIN

/**
 * ImGuiOverlay — Singleton wrapper for integrating Dear ImGui into an injected iOS dylib.
 *
 * Features:
 *  - Floating draggable toggle button (show/hide the debug window)
 *  - Real-time FPS / frame-time counter (updated once per second)
 *  - Touch-event passthrough: consumed only when ImGui wants input
 *  - Dark, retina-aware theme optimised for iPhone screens
 *
 * Lifecycle (call from your constructor hook):
 *   [[ImGuiOverlay sharedInstance] setupWithDevice:device
 *                                     commandQueue:queue
 *                                       colorPixelFormat:MTLPixelFormatBGRA8Unorm];
 *
 * Each frame (swizzle/hook the present call):
 *   [[ImGuiOverlay sharedInstance] beginFrameWithCommandBuffer:cmdBuf
 *                                           renderPassDescriptor:rpd];
 *   // --- add your own ImGui:: calls here ---
 *   [[ImGuiOverlay sharedInstance] endFrameWithCommandEncoder:encoder];
 */
@interface ImGuiOverlay : NSObject

// ─── Singleton ────────────────────────────────────────────────────────────────
+ (instancetype)sharedInstance;

// ─── Initialisation ───────────────────────────────────────────────────────────

/// One-time setup. Call after the Metal device is available.
/// colorPixelFormat should match the swap-chain pixel format (usually BGRA8Unorm).
- (void)setupWithDevice:(id<MTLDevice>)device
           commandQueue:(id<MTLCommandQueue>)commandQueue
       colorPixelFormat:(MTLPixelFormat)pixelFormat;

// ─── Per-frame API ────────────────────────────────────────────────────────────

/// Call at the beginning of each frame (before encoding game draw calls that you
/// want to appear BELOW the overlay).
- (void)beginFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               renderPassDescriptor:(MTLRenderPassDescriptor *)rpd;

/// Finalise ImGui rendering into the supplied encoder and close the overlay pass.
/// The encoder must target the same render pass descriptor passed to -beginFrame.
- (void)endFrameWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder;

// ─── Touch handling ───────────────────────────────────────────────────────────

/// Forward UIKit touch events; returns YES if ImGui consumed the event.
- (BOOL)handleTouchesBegan:(NSSet<UITouch *> *)touches  withEvent:(UIEvent *)event;
- (BOOL)handleTouchesMoved:(NSSet<UITouch *> *)touches  withEvent:(UIEvent *)event;
- (BOOL)handleTouchesEnded:(NSSet<UITouch *> *)touches  withEvent:(UIEvent *)event;
- (BOOL)handleTouchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;

// ─── Utilities ────────────────────────────────────────────────────────────────

/// Programmatically toggle the main overlay window.
- (void)toggleOverlay;

/// Current smoothed FPS value.
@property (nonatomic, readonly) float currentFPS;
/// Current smoothed frame time in milliseconds.
@property (nonatomic, readonly) float currentFrameTimeMs;
/// Whether the main overlay window is currently shown.
@property (nonatomic, assign)   BOOL  overlayVisible;

@end

NS_ASSUME_NONNULL_END

#pragma once

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImGuiOverlay : NSObject

@property(class, readonly, nonatomic) ImGuiOverlay *sharedInstance;
@property(nonatomic, assign) BOOL showMenu;
@property(nonatomic, assign) BOOL showFPS;

- (void)setupWithDevice:(id<MTLDevice>)device
           commandQueue:(id<MTLCommandQueue>)queue
       colorPixelFormat:(MTLPixelFormat)pixelFormat;

- (void)beginFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               renderPassDescriptor:(MTLRenderPassDescriptor *)rpd;

- (void)endFrameWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder;

- (BOOL)handleTouchesBegan:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event;
- (BOOL)handleTouchesMoved:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event;
- (BOOL)handleTouchesEnded:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event;
- (BOOL)handleTouchesCancelled:(NSSet<UITouch *> *)touches
                     withEvent:(nullable UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
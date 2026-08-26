// ImGuiOverlay.mm
// Dear ImGui overlay implementation for iOS 15+ dylib (Metal backend)

#include "ImGuiOverlay.h"
#include "imgui.h"
#include "imgui_impl_metal.h"
#include <chrono>
#include <objc/runtime.h>

// ─── Private category ────────────────────────────────────────────────────────
@interface ImGuiOverlay ()
{
    id<MTLDevice>           _device;
    id<MTLCommandQueue>     _commandQueue;
    MTLPixelFormat          _pixelFormat;
    BOOL                    _initialized;

    // Store current command buffer so endFrame can pass it to ImGui_ImplMetal_RenderDrawData
    id<MTLCommandBuffer>    _currentCommandBuffer;

    // FPS tracking
    std::chrono::steady_clock::time_point _lastFPSTime;
    int                     _framesSinceLastUpdate;
    float                   _fps;
    float                   _frameTimeMs;

    // Toggle button persistent position
    float                   _btnX;
    float                   _btnY;
    BOOL                    _btnDragging;
    float                   _btnDragOffsetX;
    float                   _btnDragOffsetY;

    // Current frame timing
    std::chrono::steady_clock::time_point _prevFrameTime;
}
@end

// ─── Implementation ──────────────────────────────────────────────────────────
@implementation ImGuiOverlay

+ (instancetype)sharedInstance {
    static ImGuiOverlay *s_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s_instance = [[ImGuiOverlay alloc] init]; });
    return s_instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _initialized = NO;
        _overlayVisible = YES;
        _fps = 0.f;
        _frameTimeMs = 0.f;
        _framesSinceLastUpdate = 0;
        _lastFPSTime = std::chrono::steady_clock::now();
        _prevFrameTime = std::chrono::steady_clock::now();
        _currentCommandBuffer = nil;
        _btnX = [UIScreen mainScreen].bounds.size.width - 70.f;
        _btnY = 60.f;
    }
    return self;
}

// ─── Setup ───────────────────────────────────────────────────────────────────
- (void)setupWithDevice:(id<MTLDevice>)device
           commandQueue:(id<MTLCommandQueue>)commandQueue
       colorPixelFormat:(MTLPixelFormat)pixelFormat {
    if (_initialized) return;
    _device       = device;
    _commandQueue = commandQueue;
    _pixelFormat  = pixelFormat;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    float scale = (float)[UIScreen mainScreen].scale;
    io.DisplayFramebufferScale = ImVec2(scale, scale);
    io.FontGlobalScale = 1.5f;

    [self _applyDarkTheme];

    ImGui_ImplMetal_Init(device);

    _initialized = YES;
}

// ─── Per-frame ───────────────────────────────────────────────────────────────
- (void)beginFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               renderPassDescriptor:(MTLRenderPassDescriptor *)rpd {
    if (!_initialized) return;

    // Cache command buffer so endFrame can forward it to ImGui_ImplMetal_RenderDrawData
    _currentCommandBuffer = commandBuffer;

    ImGuiIO &io = ImGui::GetIO();
    CGSize size = [UIScreen mainScreen].bounds.size;
    float scale = (float)[UIScreen mainScreen].scale;
    io.DisplaySize = ImVec2(size.width * scale, size.height * scale);

    auto now = std::chrono::steady_clock::now();
    float dt = std::chrono::duration<float>(now - _prevFrameTime).count();
    _prevFrameTime = now;
    io.DeltaTime = (dt > 0.f) ? dt : 1.f / 60.f;

    _framesSinceLastUpdate++;
    float elapsed = std::chrono::duration<float>(now - _lastFPSTime).count();
    if (elapsed >= 1.0f) {
        _fps = _framesSinceLastUpdate / elapsed;
        _frameTimeMs = (elapsed * 1000.f) / _framesSinceLastUpdate;
        _framesSinceLastUpdate = 0;
        _lastFPSTime = now;
    }

    ImGui_ImplMetal_NewFrame(rpd);
    ImGui::NewFrame();

    [self _buildUI];
}

- (void)endFrameWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder {
    if (!_initialized) return;
    ImGui::Render();
    // Correct 3-argument signature: drawData, commandBuffer, commandEncoder
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), _currentCommandBuffer, encoder);
    _currentCommandBuffer = nil;
}

// ─── Touch handling ──────────────────────────────────────────────────────────
- (BOOL)handleTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    return [self _processTouches:touches phase:UITouchPhaseBegan];
}
- (BOOL)handleTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    return [self _processTouches:touches phase:UITouchPhaseMoved];
}
- (BOOL)handleTouchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    return [self _processTouches:touches phase:UITouchPhaseEnded];
}
- (BOOL)handleTouchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    return [self _processTouches:touches phase:UITouchPhaseCancelled];
}

- (BOOL)_processTouches:(NSSet<UITouch *> *)touches phase:(UITouchPhase)phase {
    ImGuiIO &io = ImGui::GetIO();
    float scale = (float)[UIScreen mainScreen].scale;
    UITouch *t  = [touches anyObject];
    CGPoint pt  = [t locationInView:t.view];
    io.MousePos = ImVec2(pt.x * scale, pt.y * scale);
    if (phase == UITouchPhaseBegan)
        io.MouseDown[0] = true;
    else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled)
        io.MouseDown[0] = false;
    return io.WantCaptureMouse;
}

// ─── Toggle ──────────────────────────────────────────────────────────────────
- (void)toggleOverlay { _overlayVisible = !_overlayVisible; }

// ─── Internal UI builder ─────────────────────────────────────────────────────
- (void)_buildUI {
    ImGuiIO &io = ImGui::GetIO();
    float scale = (float)[UIScreen mainScreen].scale;
    ImVec2 btnSz = ImVec2(54.f * scale, 54.f * scale);

    // ── Floating toggle button ────────────────────────────────────────────────
    ImGui::SetNextWindowPos(ImVec2(_btnX * scale, _btnY * scale), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(btnSz.x + 16.f, btnSz.y + 16.f));
    ImGui::SetNextWindowBgAlpha(0.0f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0.0f);
    ImGui::Begin("##ToggleBtn", nullptr,
                 ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                 ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoSavedSettings |
                 ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoNav);

    if (ImGui::IsWindowHovered() && io.MouseDown[0] && !_btnDragging) {
        _btnDragging    = YES;
        _btnDragOffsetX = io.MousePos.x / scale - _btnX;
        _btnDragOffsetY = io.MousePos.y / scale - _btnY;
    }
    if (_btnDragging) {
        _btnX = io.MousePos.x / scale - _btnDragOffsetX;
        _btnY = io.MousePos.y / scale - _btnDragOffsetY;
        if (!io.MouseDown[0]) _btnDragging = NO;
    }

    ImGui::PushStyleColor(ImGuiCol_Button,        ImVec4(0.15f, 0.15f, 0.18f, 0.92f));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.28f, 0.28f, 0.90f, 0.95f));
    ImGui::PushStyleColor(ImGuiCol_ButtonActive,  ImVec4(0.18f, 0.18f, 0.70f, 1.00f));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, btnSz.x / 2.f);
    if (ImGui::Button((_overlayVisible ? "X" : "D"), btnSz)) {
        [self toggleOverlay];
    }
    ImGui::PopStyleVar();
    ImGui::PopStyleColor(3);
    ImGui::End();
    ImGui::PopStyleVar(2);

    if (!_overlayVisible) return;

    // ── Main debug window ─────────────────────────────────────────────────────
    float winW = io.DisplaySize.x * 0.55f;
    ImGui::SetNextWindowPos(ImVec2(10.f * scale, 120.f * scale), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(winW, 0.f), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowBgAlpha(0.88f);
    ImGui::Begin("Debug Overlay", &_overlayVisible,
                 ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoCollapse);

    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.45f, 0.85f, 0.45f, 1.0f));
    ImGui::Text("FPS   : %.1f", _fps);
    ImGui::PopStyleColor();
    ImGui::Text("Frame : %.2f ms", _frameTimeMs);
    ImGui::Separator();
    ImGui::TextDisabled("-- Add debug modules below --");

    ImGui::End();
}

// ─── Theme ───────────────────────────────────────────────────────────────────
- (void)_applyDarkTheme {
    ImGui::StyleColorsDark();
    ImGuiStyle &s    = ImGui::GetStyle();
    s.WindowRounding = 10.f;
    s.FrameRounding  = 6.f;
    s.GrabRounding   = 4.f;
    s.ScrollbarRounding = 6.f;
    s.WindowBorderSize  = 1.f;
    s.FrameBorderSize   = 0.f;
    s.WindowPadding  = ImVec2(12.f, 10.f);
    s.ItemSpacing    = ImVec2(8.f,  6.f);

    ImVec4 *c = s.Colors;
    c[ImGuiCol_WindowBg]         = ImVec4(0.08f, 0.08f, 0.10f, 0.95f);
    c[ImGuiCol_TitleBg]          = ImVec4(0.06f, 0.06f, 0.08f, 1.00f);
    c[ImGuiCol_TitleBgActive]    = ImVec4(0.12f, 0.12f, 0.50f, 1.00f);
    c[ImGuiCol_FrameBg]          = ImVec4(0.14f, 0.14f, 0.17f, 1.00f);
    c[ImGuiCol_FrameBgHovered]   = ImVec4(0.22f, 0.22f, 0.55f, 0.70f);
    c[ImGuiCol_CheckMark]        = ImVec4(0.40f, 0.80f, 0.40f, 1.00f);
    c[ImGuiCol_SliderGrab]       = ImVec4(0.40f, 0.40f, 0.90f, 0.78f);
    c[ImGuiCol_Separator]        = ImVec4(0.30f, 0.30f, 0.40f, 0.50f);
    c[ImGuiCol_Header]           = ImVec4(0.20f, 0.20f, 0.80f, 0.40f);
    c[ImGuiCol_HeaderHovered]    = ImVec4(0.26f, 0.26f, 0.90f, 0.80f);
    c[ImGuiCol_HeaderActive]     = ImVec4(0.26f, 0.26f, 0.90f, 1.00f);
}

// ─── Property synthesizers ───────────────────────────────────────────────────
- (float)currentFPS         { return _fps; }
- (float)currentFrameTimeMs { return _frameTimeMs; }

@end

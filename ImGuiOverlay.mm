#import "ImGuiOverlay.h"
#include "imgui.h"
#include "imgui_impl_metal.h"
#include <chrono>

@interface ImGuiOverlay () {
  id<MTLDevice> _device;
  id<MTLCommandQueue> _queue;
  id<MTLCommandBuffer> _currentCmdBuffer;

  // FPS tracking
  std::chrono::high_resolution_clock::time_point _lastTime;
  int _frameCount;
  float _fps;
  float _frameTime;
}
@end

@implementation ImGuiOverlay

+ (instancetype)sharedInstance {
  static ImGuiOverlay *shared = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    shared = [[self alloc] init];
  });
  return shared;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _showMenu = YES;
    _showFPS = YES;
    _fps = 0.0f;
    _frameTime = 0.0f;
    _frameCount = 0;
    _lastTime = std::chrono::high_resolution_clock::now();
  }
  return self;
}

- (void)setupWithDevice:(id<MTLDevice>)device
           commandQueue:(id<MTLCommandQueue>)queue
       colorPixelFormat:(MTLPixelFormat)pixelFormat {
  _device = device;
  _queue = queue;

  IMGUI_CHECKVERSION();
  ImGui::CreateContext();
  ImGuiIO &io = ImGui::GetIO();
  io.IniFilename = NULL; // Disable saving ini file

  // Modern Dark Theme Styling
  ImGui::StyleColorsDark();
  ImGuiStyle &style = ImGui::GetStyle();
  style.WindowRounding = 10.0f;
  style.FrameRounding = 6.0f;
  style.PopupRounding = 6.0f;
  style.ScrollbarRounding = 6.0f;
  style.GrabRounding = 6.0f;
  style.WindowBorderSize = 1.0f;

  ImGui_ImplMetal_Init(device);
}

- (void)updateTelemetry {
  _frameCount++;
  auto currentTime = std::chrono::high_resolution_clock::now();
  std::chrono::duration<float, std::chrono::milliseconds::period> elapsed = currentTime - _lastTime;
  if (elapsed.count() >= 500.0f) {
    _fps = (_frameCount * 1000.0f) / elapsed.count();
    _frameTime = elapsed.count() / _frameCount;
    _frameCount = 0;
    _lastTime = currentTime;
  }
}

- (void)beginFrameWithCommandBuffer:(id<MTLCommandBuffer>)commandBuffer
               renderPassDescriptor:(MTLRenderPassDescriptor *)rpd {
  _currentCmdBuffer = commandBuffer;
  [self updateTelemetry];

  CGSize screenSize = [UIScreen mainScreen].bounds.size;
  CGFloat scale = [UIScreen mainScreen].nativeScale;

  ImGuiIO &io = ImGui::GetIO();
  io.DisplaySize = ImVec2(screenSize.width, screenSize.height);
  io.DisplayFramebufferScale = ImVec2(scale, scale);

  ImGui_ImplMetal_NewFrame(rpd);
  ImGui::NewFrame();

  // 1. Floating Quick Toggle Button
  ImGui::SetNextWindowPos(ImVec2(20, 20), ImGuiCond_FirstUseEver);
  ImGui::Begin("ToggleHUD", NULL,
               ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                   ImGuiWindowFlags_AlwaysAutoResize);
  if (ImGui::Button(_showMenu ? "Close Menu" : "Open Menu")) {
    _showMenu = !_showMenu;
  }
  ImGui::End();

  // 2. Real-time Telemetry HUD (FPS & Frame Time)
  if (_showFPS) {
    ImGui::SetNextWindowPos(ImVec2(screenSize.width - 160, 20),
                            ImGuiCond_FirstUseEver);
    ImGui::Begin("Telemetry", NULL,
                 ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize |
                     ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::TextColored(ImVec4(0.2f, 1.0f, 0.4f, 1.0f), "FPS: %.1f", _fps);
    ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Frame: %.2f ms",
                       _frameTime);
    ImGui::End();
  }

  // 3. Main Configuration Menu
  if (_showMenu) {
    ImGui::SetNextWindowSize(ImVec2(320, 240), ImGuiCond_FirstUseEver);
    ImGui::Begin("Performance Overlay", &_showMenu,
                 ImGuiWindowFlags_NoCollapse);

    ImGui::Text("System Telemetry");
    ImGui::Separator();
    ImGui::Checkbox("Show FPS / Frame Time", &_showFPS);

    ImGui::Spacing();
    ImGui::Text("Overlay Controls");
    ImGui::Separator();
    if (ImGui::Button("Reset Window Positions", ImVec2(-1, 30))) {
      ImGui::SetWindowPos("ToggleHUD", ImVec2(20, 20));
      ImGui::SetWindowPos("Telemetry", ImVec2(screenSize.width - 160, 20));
    }

    ImGui::End();
  }

  ImGui::Render();
}

- (void)endFrameWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder {
  if (_currentCmdBuffer && encoder) {
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), _currentCmdBuffer,
                                   encoder);
  }
}

#pragma mark - Touch Handling

- (BOOL)handleTouchesBegan:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event {
  ImGuiIO &io = ImGui::GetIO();
  UITouch *touch = [touches anyObject];
  CGPoint loc = [touch locationInView:nil];
  io.MousePos = ImVec2(loc.x, loc.y);
  io.MouseDown[0] = true;
  return io.WantCaptureMouse;
}

- (BOOL)handleTouchesMoved:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event {
  ImGuiIO &io = ImGui::GetIO();
  UITouch *touch = [touches anyObject];
  CGPoint loc = [touch locationInView:nil];
  io.MousePos = ImVec2(loc.x, loc.y);
  return io.WantCaptureMouse;
}

- (BOOL)handleTouchesEnded:(NSSet<UITouch *> *)touches
                 withEvent:(nullable UIEvent *)event {
  ImGuiIO &io = ImGui::GetIO();
  io.MouseDown[0] = false;
  return io.WantCaptureMouse;
}

- (BOOL)handleTouchesCancelled:(NSSet<UITouch *> *)touches
                     withEvent:(nullable UIEvent *)event {
  ImGuiIO &io = ImGui::GetIO();
  io.MouseDown[0] = false;
  return io.WantCaptureMouse;
}

@end

TARGET := iphone:clang:latest:15.0
ARCHS := arm64
include $(THEOS)/makefiles/common.mk
LIBRARY_NAME = ImGuiOverlay
ImGuiOverlay_FILES = main.mm ImGuiOverlay.mm imgui.cpp imgui_draw.cpp imgui_tables.cpp imgui_widgets.cpp imgui_impl_metal.mm
ImGuiOverlay_FRAMEWORKS = UIKit Metal QuartzCore
ImGuiOverlay_CFLAGS = -fobjc-arc -std=c++17 -Wno-unused-variable -Wno-unused-function
ImGuiOverlay_LDFLAGS = -undefined dynamic_lookup
# Disable Cydia Substrate dependency
override THEOS_SUBSTRATE = 0
include $(THEOS_MAKE_PATH)/library.mk

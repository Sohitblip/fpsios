include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = ImGuiOverlay

ImGuiOverlay_FILES  = main.mm
ImGuiOverlay_FILES += ImGuiOverlay.mm
ImGuiOverlay_FILES += imgui.cpp
ImGuiOverlay_FILES += imgui_draw.cpp
ImGuiOverlay_FILES += imgui_tables.cpp
ImGuiOverlay_FILES += imgui_widgets.cpp
ImGuiOverlay_FILES += imgui_impl_metal.mm

ImGuiOverlay_CFLAGS  = -fobjc-arc
ImGuiOverlay_CFLAGS += -fmodules
ImGuiOverlay_CFLAGS += -I$(THEOS_PROJECT_DIR)
ImGuiOverlay_CFLAGS += -std=c++17

ImGuiOverlay_CCFLAGS = $(ImGuiOverlay_CFLAGS)

ImGuiOverlay_FRAMEWORKS  = UIKit
ImGuiOverlay_FRAMEWORKS += Metal
ImGuiOverlay_FRAMEWORKS += MetalKit
ImGuiOverlay_FRAMEWORKS += QuartzCore
ImGuiOverlay_FRAMEWORKS += Foundation

IPHONE_DEPLOYMENT_TARGET = 15.0
ARCHS = arm64 arm64e

DEBUG = 0
STRIP = 1

include $(THEOS_MAKE_PATH)/library.mk
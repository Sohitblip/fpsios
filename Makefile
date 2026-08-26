# Theos Makefile
# Target: iOS 15+  |  arm64 + arm64e  |  Metal + UIKit + QuartzCore
# Rootless / non-jailbreak sideload – produce a raw dylib (.dylib)

# ── Theos preamble ──────────────────────────────────────────────────────────
include $(THEOS)/makefiles/common.mk

# ── Tool name & output ──────────────────────────────────────────────────────
LIBRARY_NAME = ImGuiOverlay

# ── Source files ────────────────────────────────────────────────────────────
ImGuiOverlay_FILES  = main.mm
ImGuiOverlay_FILES += ImGuiOverlay.mm
# Dear ImGui core
ImGuiOverlay_FILES += imgui.cpp
ImGuiOverlay_FILES += imgui_draw.cpp
ImGuiOverlay_FILES += imgui_tables.cpp
ImGuiOverlay_FILES += imgui_widgets.cpp
# Metal backend
ImGuiOverlay_FILES += imgui_impl_metal.mm

# ── Compiler flags ──────────────────────────────────────────────────────────
ImGuiOverlay_CFLAGS  = -fobjc-arc
ImGuiOverlay_CFLAGS += -fmodules
ImGuiOverlay_CFLAGS += -DIMGUI_IMPL_METAL_CPP
ImGuiOverlay_CFLAGS += -I$(THEOS_PROJECT_DIR)
ImGuiOverlay_CFLAGS += -std=c++17

ImGuiOverlay_CCFLAGS = $(ImGuiOverlay_CFLAGS)

# ── Linker / framework flags ─────────────────────────────────────────────────
ImGuiOverlay_FRAMEWORKS  = UIKit
ImGuiOverlay_FRAMEWORKS += Metal
ImGuiOverlay_FRAMEWORKS += MetalKit
ImGuiOverlay_FRAMEWORKS += QuartzCore
ImGuiOverlay_FRAMEWORKS += Foundation

# ── Deployment target & architectures ───────────────────────────────────────
IPHONE_DEPLOYMENT_TARGET = 15.0
ARCHS                     = arm64 arm64e

# ── Build type (release) ─────────────────────────────────────────────────────
DEBUG = 0
STRIP = 1

include $(THEOS_MAKE_PATH)/library.mk

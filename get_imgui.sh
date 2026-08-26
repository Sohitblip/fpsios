#!/usr/bin/env bash
# get_imgui.sh
# Downloads the matching Dear ImGui core + Metal backend source files
# into the current directory (your project root).
# Usage (macOS/Linux):  chmod +x get_imgui.sh && ./get_imgui.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

IMGUI_TAG="v1.90.8"   # Change to latest tag if needed
BASE="https://raw.githubusercontent.com/ocornut/imgui/${IMGUI_TAG}"

echo "[+] Downloading Dear ImGui ${IMGUI_TAG} core files..."

# Core headers
curl -fsSL "${BASE}/imgui.h"            -o imgui.h
curl -fsSL "${BASE}/imgui_internal.h"   -o imgui_internal.h
curl -fsSL "${BASE}/imconfig.h"         -o imconfig.h
curl -fsSL "${BASE}/imstb_rectpack.h"   -o imstb_rectpack.h
curl -fsSL "${BASE}/imstb_textedit.h"   -o imstb_textedit.h
curl -fsSL "${BASE}/imstb_truetype.h"   -o imstb_truetype.h

# Core implementation
curl -fsSL "${BASE}/imgui.cpp"          -o imgui.cpp
curl -fsSL "${BASE}/imgui_draw.cpp"     -o imgui_draw.cpp
curl -fsSL "${BASE}/imgui_tables.cpp"   -o imgui_tables.cpp
curl -fsSL "${BASE}/imgui_widgets.cpp"  -o imgui_widgets.cpp
curl -fsSL "${BASE}/imgui_demo.cpp"     -o imgui_demo.cpp   # optional; safe to remove

echo "[+] Downloading Metal backend..."
curl -fsSL "${BASE}/backends/imgui_impl_metal.h"   -o imgui_impl_metal.h
curl -fsSL "${BASE}/backends/imgui_impl_metal.mm"  -o imgui_impl_metal.mm

echo ""
echo "[✓] All ImGui files downloaded successfully."
echo "    Files in this directory:"
ls -1 imgui*.{h,cpp,mm} 2>/dev/null || true
echo ""
echo "Next steps:"
echo "  1. Edit Makefile to confirm THEOS path."
echo "  2. Run:  make package   (from a Theos-enabled shell on macOS/Linux)"

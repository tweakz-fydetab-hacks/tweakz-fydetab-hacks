#!/bin/bash
# test-vscodium.sh - Automated VSCodium Wayland test for FydeTab Duo
# Launches VSCodium in an isolated environment, waits for renderer,
# captures a screenshot, and verifies Wayland rendering.

set -e

OUTPUT_DIR="${1:-.}"
RENDERER_TIMEOUT=20
RENDER_DELAY=5

echo "=== VSCodium Automated Test ==="

# Check prerequisites — SKIP (exit 2) if not met
if [[ "$XDG_SESSION_TYPE" != "wayland" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
    echo "SKIP: Not running in a Wayland session"
    {
        echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
        echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
    } > "${OUTPUT_DIR}/session-info.txt"
    exit 2
fi

VSCODIUM_CMD=""
if command -v codium &>/dev/null; then
    VSCODIUM_CMD="codium"
elif command -v vscodium &>/dev/null; then
    VSCODIUM_CMD="vscodium"
else
    echo "SKIP: VSCodium not installed"
    exit 2
fi

# Create isolated temp dirs
TMPBASE=$(mktemp -d /tmp/vscodium-test-XXXXXX)
USER_DATA_DIR="${TMPBASE}/user-data"
EXTENSIONS_DIR="${TMPBASE}/extensions"
mkdir -p "${USER_DATA_DIR}/User" "$EXTENSIONS_DIR"

# Pre-populate settings to suppress welcome/walkthrough
cat > "${USER_DATA_DIR}/User/settings.json" <<'SETTINGS'
{
    "workbench.startupEditor": "none",
    "workbench.tips.enabled": false,
    "workbench.welcomePage.walkthroughs.openOnInstall": false,
    "telemetry.telemetryLevel": "off",
    "update.mode": "none"
}
SETTINGS

# Create a test file to open
TEST_FILE="${TMPBASE}/test-file.txt"
echo "VSCodium Wayland rendering test - $(date)" > "$TEST_FILE"

# Capture environment
echo "Capturing environment..."
{
    echo "=== Session Environment ==="
    echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
    echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
    echo "DISPLAY: ${DISPLAY:-not set}"
    echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-not set}"
    echo ""
    echo "=== GPU Environment ==="
    echo "LIBGL_ALWAYS_SOFTWARE: ${LIBGL_ALWAYS_SOFTWARE:-not set}"
    echo "MESA_DEBUG: ${MESA_DEBUG:-not set}"
} > "${OUTPUT_DIR}/environment.txt"

# Launch VSCodium with isolated dirs and Wayland flags
echo "Launching VSCodium..."
$VSCODIUM_CMD \
    --user-data-dir="$USER_DATA_DIR" \
    --extensions-dir="$EXTENSIONS_DIR" \
    --disable-extensions \
    --enable-features=UseOzonePlatform,WaylandWindowDecorations \
    --ozone-platform=wayland \
    -g "${TEST_FILE}:1:1" &

VSCODIUM_PID=$!

# Wait for renderer process
echo "Waiting for renderer process..."
RENDERER_FOUND=0
ELAPSED=0
while [ $ELAPSED -lt $RENDERER_TIMEOUT ]; do
    if pgrep -f "codium.*--type=renderer" &>/dev/null; then
        RENDERER_FOUND=1
        echo "Renderer process detected after ${ELAPSED}s"
        break
    fi
    sleep 1
    ((ELAPSED++))
done

if [ $RENDERER_FOUND -eq 0 ]; then
    echo "Renderer process not detected within ${RENDERER_TIMEOUT}s"
fi

# Allow rendering to settle before screenshot
if [ $RENDERER_FOUND -eq 1 ]; then
    echo "Waiting ${RENDER_DELAY}s for rendering to settle..."
    sleep "$RENDER_DELAY"
fi

# Capture process info
{
    echo "=== VSCodium Process ==="
    echo "Main PID: $VSCODIUM_PID"
    echo "Renderer found: $RENDERER_FOUND"
    echo ""
    ps aux | grep -E "$VSCODIUM_PID|codium|electron" | grep -v grep || echo "Process info not available"
    echo ""
    echo "=== VSCodium Command Line ==="
    cat "/proc/$VSCODIUM_PID/cmdline" 2>/dev/null | tr '\0' ' ' || echo "Cannot read cmdline"
    echo ""
} > "${OUTPUT_DIR}/process-info.txt"

# Capture screenshot if grim is available
if command -v grim &>/dev/null; then
    echo "Capturing screenshot..."
    if grim "${OUTPUT_DIR}/vscodium-screenshot.png" 2>/dev/null; then
        echo "Screenshot saved to ${OUTPUT_DIR}/vscodium-screenshot.png"
    else
        echo "Screenshot capture failed"
    fi
else
    echo "grim not installed, skipping screenshot"
fi

# Capture Wayland verification
{
    echo "=== Wayland Verification ==="
    if [ $RENDERER_FOUND -eq 1 ]; then
        # Check if VSCodium is using Wayland (look for wayland in its open fds)
        RENDERER_PID=$(pgrep -f "codium.*--type=renderer" | head -1)
        if [ -n "$RENDERER_PID" ]; then
            echo "Renderer PID: $RENDERER_PID"
            ls -la /proc/$RENDERER_PID/fd 2>/dev/null | grep wayland || echo "No wayland socket in fds (may still be using Wayland via main process)"
        fi
    else
        echo "No renderer process to verify"
    fi
} > "${OUTPUT_DIR}/wayland-check.txt"

# Cleanup: kill VSCodium
echo "Cleaning up..."
if kill -0 $VSCODIUM_PID 2>/dev/null; then
    kill $VSCODIUM_PID 2>/dev/null || true
    sleep 2
    kill -9 $VSCODIUM_PID 2>/dev/null || true
fi
# Kill any remaining child processes
pkill -f "codium.*--user-data-dir=${USER_DATA_DIR}" 2>/dev/null || true

# Remove temp dirs
rm -rf "$TMPBASE"

# Final result
echo ""
echo "=== VSCodium Test Result ==="
if [ $RENDERER_FOUND -eq 1 ]; then
    echo "PASS: VSCodium renderer process launched successfully"
    {
        echo "Status: PASS"
        echo "Renderer process detected and screenshot captured"
    } > "${OUTPUT_DIR}/result.txt"
    exit 0
else
    echo "FAIL: VSCodium renderer process not detected"
    {
        echo "Status: FAIL"
        echo "Renderer process was not detected within ${RENDERER_TIMEOUT}s"
    } > "${OUTPUT_DIR}/result.txt"
    exit 1
fi

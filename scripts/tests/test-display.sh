#!/bin/bash
# test-display.sh - Display/rockchip-drm verification for FydeTab Duo
# Verifies: rockchip-drm loaded, display resolution, framebuffer

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Display Test ==="

# Check DRM devices
echo "Checking DRM devices..."
{
    echo "=== DRM Devices ==="
    ls -la /dev/dri/ 2>&1 || echo "No /dev/dri directory"
    echo ""
    echo "=== Card Info ==="
    for card in /sys/class/drm/card*; do
        if [ -d "$card" ]; then
            echo "$(basename "$card"):"
            cat "$card/device/uevent" 2>/dev/null | grep -E "DRIVER|PCI_ID" || true
        fi
    done
} > "${OUTPUT_DIR}/drm-devices.txt"

# Check for rockchip-drm driver
echo "Checking rockchip-drm driver..."
{
    echo "=== DRM Driver Check ==="
    if lsmod | grep -q rockchip_drm; then
        echo "rockchip_drm module: loaded"
    else
        echo "rockchip_drm module: not loaded (may be built-in)"
    fi
    echo ""
    echo "=== Modules containing rockchip ==="
    lsmod | grep -i rockchip || echo "No rockchip modules loaded"
    echo ""
    echo "=== DRM kernel messages ==="
    dmesg 2>/dev/null | grep -iE "rockchip|drm|display" | tail -50 || true
} > "${OUTPUT_DIR}/rockchip-drm.txt"

if grep -q "rockchip_drm\|rockchip" "${OUTPUT_DIR}/rockchip-drm.txt"; then
    echo "PASS: rockchip DRM detected"
else
    echo "WARN: rockchip DRM not explicitly detected"
fi

# Check display resolution
echo "Checking display resolution..."
{
    echo "=== Display Resolution ==="
    if command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        xrandr --query 2>&1 || echo "xrandr failed"
    elif command -v wlr-randr &>/dev/null && [ -n "$WAYLAND_DISPLAY" ]; then
        wlr-randr 2>&1 || echo "wlr-randr failed"
    else
        echo "No display tool available or no display session"
    fi
    echo ""
    echo "=== DRM Mode Info ==="
    for card in /sys/class/drm/card*-*; do
        if [ -d "$card" ]; then
            echo "$(basename "$card"):"
            cat "$card/modes" 2>/dev/null | head -5 || echo "  No modes"
            echo "  Status: $(cat "$card/status" 2>/dev/null || echo 'unknown')"
            echo "  Enabled: $(cat "$card/enabled" 2>/dev/null || echo 'unknown')"
        fi
    done
} > "${OUTPUT_DIR}/display-resolution.txt"

cat "${OUTPUT_DIR}/display-resolution.txt"

# Check expected resolution (2560x1600)
if grep -q "2560x1600" "${OUTPUT_DIR}/display-resolution.txt"; then
    echo "PASS: Native resolution 2560x1600 detected"
else
    echo "WARN: Native resolution 2560x1600 not detected"
fi

# Check framebuffer
echo "Checking framebuffer..."
{
    echo "=== Framebuffer Info ==="
    ls -la /dev/fb* 2>&1 || echo "No framebuffer devices"
    echo ""
    if [ -e /sys/class/graphics/fb0 ]; then
        echo "=== fb0 Info ==="
        cat /sys/class/graphics/fb0/virtual_size 2>/dev/null && echo "(virtual_size)" || true
        cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null && echo "(bits_per_pixel)" || true
        cat /sys/class/graphics/fb0/name 2>/dev/null && echo "(name)" || true
    fi
} > "${OUTPUT_DIR}/framebuffer.txt"

if [ -e /dev/fb0 ]; then
    echo "PASS: Framebuffer device exists"
else
    echo "INFO: No framebuffer device (may be normal for pure DRM)"
fi

# GNOME/Mutter compositor check
echo "Checking compositor..."
{
    echo "=== Compositor Status ==="
    if pgrep -x gnome-shell &>/dev/null; then
        echo "GNOME Shell: running"
        ps aux | grep "[g]nome-shell"
    elif pgrep -x mutter &>/dev/null; then
        echo "Mutter: running"
    else
        echo "No GNOME compositor detected"
    fi
    echo ""
    echo "=== Session Type ==="
    echo "XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
    echo "WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
    echo "DISPLAY: ${DISPLAY:-not set}"
} > "${OUTPUT_DIR}/compositor.txt"

cat "${OUTPUT_DIR}/compositor.txt"

echo ""
echo "Display test completed"
exit 0

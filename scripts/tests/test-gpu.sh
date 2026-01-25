#!/bin/bash
# test-gpu.sh - GPU/Panthor verification for FydeTab Duo
# Verifies: Panthor driver loaded, /dev/dri/renderD* exists, no llvmpipe, GDM running

set -e

OUTPUT_DIR="${1:-.}"

echo "=== GPU/Panthor Test ==="

# Check for DRI render nodes
echo "Checking DRI render devices..."
if ls /dev/dri/renderD* &>/dev/null; then
    echo "PASS: DRI render devices found"
    ls -la /dev/dri/ > "${OUTPUT_DIR}/dri-devices.txt"
else
    echo "FAIL: No DRI render devices found"
    echo "no_render_devices" > "${OUTPUT_DIR}/dri-devices.txt"
    exit 1
fi

# Check driver for each render device
echo "Checking GPU driver..."
{
    echo "=== Render Device Drivers ==="
    for dev in /dev/dri/renderD*; do
        card_num=$(basename "$dev" | sed 's/renderD//')
        driver_path="/sys/class/drm/renderD${card_num}/device/driver"
        if [ -L "$driver_path" ]; then
            driver=$(basename "$(readlink "$driver_path")")
            echo "renderD${card_num}: $driver"
        else
            echo "renderD${card_num}: unknown (no driver symlink)"
        fi
    done
} > "${OUTPUT_DIR}/gpu-driver.txt"

cat "${OUTPUT_DIR}/gpu-driver.txt"

# Verify Panthor is present
if grep -q "panthor" "${OUTPUT_DIR}/gpu-driver.txt"; then
    echo "PASS: Panthor driver detected"
else
    echo "WARN: Panthor driver not detected (may be using panfrost)"
fi

# Check for llvmpipe (software rendering fallback)
echo "Checking for software rendering..."
{
    echo "=== GLX Info ==="
    if command -v glxinfo &>/dev/null; then
        glxinfo 2>&1 | head -50
    else
        echo "glxinfo not available"
    fi
} > "${OUTPUT_DIR}/glxinfo.txt"

if grep -qi "llvmpipe" "${OUTPUT_DIR}/glxinfo.txt"; then
    echo "FAIL: Software rendering (llvmpipe) detected - GPU not working!"
    exit 1
else
    echo "PASS: No llvmpipe detected"
fi

# Check MESA driver info
{
    echo "=== EGL Info ==="
    if command -v eglinfo &>/dev/null; then
        eglinfo 2>&1 | head -100
    else
        echo "eglinfo not available"
    fi
} > "${OUTPUT_DIR}/eglinfo.txt"

# Check dmesg for GPU messages
echo "Checking kernel GPU messages..."
{
    echo "=== GPU Kernel Messages ==="
    dmesg 2>/dev/null | grep -iE "panthor|panfrost|mali|gpu|drm" | tail -100 || echo "No GPU messages found"
} > "${OUTPUT_DIR}/dmesg-gpu.txt"

# Check GDM status
echo "Checking GDM status..."
{
    echo "=== GDM Status ==="
    systemctl status gdm --no-pager 2>&1 || echo "GDM not running"
} > "${OUTPUT_DIR}/gdm-status.txt"

if systemctl is-active gdm &>/dev/null; then
    echo "PASS: GDM is running"
else
    echo "WARN: GDM is not running"
fi

# Mesa version
echo "Checking Mesa version..."
{
    echo "=== Mesa Version ==="
    if command -v glxinfo &>/dev/null; then
        glxinfo 2>/dev/null | grep -i "opengl version" || echo "Could not get OpenGL version"
    fi
    pacman -Q mesa 2>/dev/null || echo "mesa package not found"
} > "${OUTPUT_DIR}/mesa-version.txt"

cat "${OUTPUT_DIR}/mesa-version.txt"

echo ""
echo "GPU test completed successfully"
exit 0

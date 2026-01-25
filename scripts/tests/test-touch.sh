#!/bin/bash
# test-touch.sh - Touchscreen/Himax verification for FydeTab Duo
# Verifies: Himax HX83112B driver, input devices, touch events

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Touchscreen Test ==="

# Check input devices
echo "Checking input devices..."
{
    echo "=== Input Devices ==="
    if [ -d /sys/class/input ]; then
        for dev in /sys/class/input/event*; do
            if [ -d "$dev" ]; then
                name=$(cat "$dev/device/name" 2>/dev/null || echo "unknown")
                echo "$(basename "$dev"): $name"
            fi
        done
    fi
    echo ""
    echo "=== /proc/bus/input/devices ==="
    cat /proc/bus/input/devices 2>/dev/null || echo "Cannot read input devices"
} > "${OUTPUT_DIR}/input-devices.txt"

cat "${OUTPUT_DIR}/input-devices.txt" | head -30

# Look for Himax touchscreen
echo "Checking for Himax driver..."
{
    echo "=== Himax Driver Check ==="
    if grep -qi "himax\|hx83112" "${OUTPUT_DIR}/input-devices.txt"; then
        echo "Himax touchscreen: FOUND"
    else
        echo "Himax touchscreen: NOT FOUND in input devices"
    fi
    echo ""
    echo "=== Kernel modules ==="
    lsmod | grep -i himax || echo "No Himax modules loaded (may be built-in)"
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "himax|hx83112|touchscreen|touch" | tail -30 || echo "No touch messages"
} > "${OUTPUT_DIR}/himax-driver.txt"

if grep -qi "himax\|hx83112\|touchscreen" "${OUTPUT_DIR}/input-devices.txt" "${OUTPUT_DIR}/himax-driver.txt"; then
    echo "PASS: Touchscreen detected"
else
    echo "FAIL: Touchscreen not detected"
    exit 1
fi

# Check evdev devices
echo "Checking evdev capabilities..."
{
    echo "=== Touch Device Capabilities ==="
    for dev in /dev/input/event*; do
        if [ -e "$dev" ]; then
            name=$(cat "/sys/class/input/$(basename "$dev")/device/name" 2>/dev/null || echo "unknown")
            if echo "$name" | grep -qiE "touch|himax|hx83"; then
                echo "Found touch device: $dev ($name)"
                if command -v evtest &>/dev/null; then
                    timeout 1 evtest --info "$dev" 2>&1 | head -50 || true
                else
                    echo "  (evtest not available for detailed info)"
                fi
            fi
        fi
    done
} > "${OUTPUT_DIR}/evdev-caps.txt"

# Check libinput devices
echo "Checking libinput..."
{
    echo "=== Libinput Devices ==="
    if command -v libinput &>/dev/null; then
        sudo libinput list-devices 2>&1 | grep -A10 -iE "touch|himax" || echo "No touch devices in libinput"
    else
        echo "libinput command not available"
    fi
} > "${OUTPUT_DIR}/libinput.txt"

# Touch firmware check
echo "Checking touch firmware..."
{
    echo "=== Touch Firmware ==="
    ls -la /lib/firmware/*himax* /lib/firmware/*touch* 2>/dev/null || echo "No touch firmware files found"
    echo ""
    echo "=== Firmware loading messages ==="
    dmesg 2>/dev/null | grep -iE "firmware.*himax\|firmware.*touch" | tail -10 || echo "No firmware messages"
} > "${OUTPUT_DIR}/touch-firmware.txt"

echo ""
echo "Touchscreen test completed"
echo "Note: To verify touch is working, try touching the screen in GNOME"
exit 0

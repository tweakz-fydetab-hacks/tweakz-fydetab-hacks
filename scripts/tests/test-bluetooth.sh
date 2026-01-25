#!/bin/bash
# test-bluetooth.sh - Bluetooth/btusb verification for FydeTab Duo
# Verifies: btusb loaded, bluetooth controller, hci0 device

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Bluetooth Test ==="

# Check Bluetooth controller
echo "Checking Bluetooth controller..."
{
    echo "=== Bluetooth Devices ==="
    if command -v bluetoothctl &>/dev/null; then
        echo "show" | bluetoothctl 2>&1 | head -30 || echo "bluetoothctl failed"
    else
        echo "bluetoothctl not available"
    fi
    echo ""
    echo "=== HCI Devices ==="
    if command -v hciconfig &>/dev/null; then
        hciconfig -a 2>&1 || echo "hciconfig failed"
    else
        echo "hciconfig not available"
        ls /sys/class/bluetooth/ 2>/dev/null || echo "No bluetooth devices in sysfs"
    fi
} > "${OUTPUT_DIR}/bluetooth-devices.txt"

cat "${OUTPUT_DIR}/bluetooth-devices.txt" | head -30

# Check for hci0
if [ -d /sys/class/bluetooth/hci0 ]; then
    echo "PASS: hci0 device found"
else
    echo "FAIL: hci0 device not found"
fi

# Check btusb driver
echo "Checking btusb driver..."
{
    echo "=== Btusb Driver ==="
    if lsmod | grep -q btusb; then
        echo "btusb module: loaded"
        lsmod | grep -E "^bt"
    else
        echo "btusb module: not loaded"
        lsmod | grep -E "^bt" || echo "No bt modules"
    fi
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "bluetooth|btusb|hci" | tail -30 || echo "No Bluetooth messages"
} > "${OUTPUT_DIR}/btusb.txt"

# Check Bluetooth service
echo "Checking Bluetooth service..."
{
    echo "=== Bluetooth Service ==="
    systemctl status bluetooth --no-pager 2>&1 || echo "Bluetooth service not running"
} > "${OUTPUT_DIR}/bluetooth-service.txt"

if systemctl is-active bluetooth &>/dev/null; then
    echo "PASS: Bluetooth service is running"
else
    echo "WARN: Bluetooth service is not running"
fi

# Check rfkill status
echo "Checking rfkill..."
{
    echo "=== Rfkill Status ==="
    rfkill list 2>&1 || echo "rfkill not available"
} > "${OUTPUT_DIR}/rfkill.txt"

if rfkill list 2>/dev/null | grep -q "Bluetooth"; then
    if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
        echo "WARN: Bluetooth is blocked by rfkill"
    else
        echo "PASS: Bluetooth is not blocked"
    fi
fi

# Bluetooth firmware
echo "Checking Bluetooth firmware..."
{
    echo "=== Bluetooth Firmware ==="
    ls -la /lib/firmware/*bluetooth* /lib/firmware/brcm/*bt* 2>/dev/null | head -20 || echo "No bluetooth firmware files"
    echo ""
    echo "=== Firmware messages ==="
    dmesg 2>/dev/null | grep -iE "firmware.*bt\|bluetooth.*firmware" | tail -10 || echo "No firmware messages"
} > "${OUTPUT_DIR}/bt-firmware.txt"

echo ""
echo "Bluetooth test completed"
exit 0

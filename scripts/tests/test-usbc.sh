#!/bin/bash
# test-usbc.sh - USB-C/fusb302 verification for FydeTab Duo
# Verifies: fusb302 loaded, typec port0, power delivery

set -e

OUTPUT_DIR="${1:-.}"

echo "=== USB-C Test ==="

# Check USB Type-C ports
echo "Checking USB Type-C ports..."
{
    echo "=== Type-C Ports ==="
    if [ -d /sys/class/typec ]; then
        ls -la /sys/class/typec/ 2>&1
        echo ""
        for port in /sys/class/typec/port*; do
            if [ -d "$port" ]; then
                echo "$(basename "$port"):"
                echo "  Data role: $(cat "$port/data_role" 2>/dev/null || echo 'unknown')"
                echo "  Power role: $(cat "$port/power_role" 2>/dev/null || echo 'unknown')"
                echo "  Port type: $(cat "$port/port_type" 2>/dev/null || echo 'unknown')"
                echo "  USB Type-C revision: $(cat "$port/usb_typec_revision" 2>/dev/null || echo 'unknown')"
            fi
        done
    else
        echo "No /sys/class/typec directory"
    fi
} > "${OUTPUT_DIR}/typec-ports.txt"

cat "${OUTPUT_DIR}/typec-ports.txt"

if [ -d /sys/class/typec/port0 ]; then
    echo "PASS: Type-C port0 detected"
else
    echo "WARN: Type-C port0 not found in sysfs"
fi

# Check fusb302 driver
echo "Checking fusb302 driver..."
{
    echo "=== FUSB302 Driver ==="
    if lsmod | grep -q fusb302; then
        echo "fusb302 module: loaded"
        lsmod | grep fusb
    else
        echo "fusb302 module: not loaded (may be built-in)"
    fi
    echo ""
    echo "=== I2C Devices ==="
    ls /sys/bus/i2c/devices/ 2>/dev/null | head -20 || echo "No I2C devices"
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "fusb302|typec|usb.*pd\|tcpm" | tail -30 || echo "No USB-C messages"
} > "${OUTPUT_DIR}/fusb302.txt"

# Check power delivery
echo "Checking power delivery..."
{
    echo "=== USB Power Delivery ==="
    if [ -d /sys/class/usb_power_delivery ]; then
        ls -la /sys/class/usb_power_delivery/ 2>&1
        for pd in /sys/class/usb_power_delivery/pd*; do
            if [ -d "$pd" ]; then
                echo "$(basename "$pd"):"
                cat "$pd/type" 2>/dev/null || true
            fi
        done
    else
        echo "No /sys/class/usb_power_delivery directory"
    fi
    echo ""
    echo "=== TCPM messages ==="
    dmesg 2>/dev/null | grep -i tcpm | tail -20 || echo "No TCPM messages"
} > "${OUTPUT_DIR}/power-delivery.txt"

# Check USB devices
echo "Checking USB devices..."
{
    echo "=== USB Devices ==="
    lsusb 2>&1 || echo "lsusb failed"
    echo ""
    echo "=== USB Host Controllers ==="
    ls -la /sys/bus/usb/devices/usb* 2>/dev/null | head -10 || echo "No USB host controllers"
} > "${OUTPUT_DIR}/usb-devices.txt"

# Check USB-C mode (host/device)
echo "Checking USB mode..."
{
    echo "=== USB OTG/DRD Status ==="
    if [ -d /sys/class/udc ]; then
        echo "UDC (device mode) controllers:"
        ls /sys/class/udc/ 2>/dev/null || echo "None"
    fi
    echo ""
    dmesg 2>/dev/null | grep -iE "otg|dual.role\|drd" | tail -20 || echo "No OTG/DRD messages"
} > "${OUTPUT_DIR}/usb-mode.txt"

echo ""
echo "USB-C test completed"
exit 0

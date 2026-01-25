#!/bin/bash
# test-wifi.sh - WiFi/brcmfmac verification for FydeTab Duo
# Verifies: brcmfmac loaded, AP6275P firmware, NetworkManager, wifi scan

set -e

OUTPUT_DIR="${1:-.}"

echo "=== WiFi Test ==="

# Check wireless interfaces
echo "Checking wireless interfaces..."
{
    echo "=== Wireless Interfaces ==="
    if command -v iw &>/dev/null; then
        iw dev 2>&1 || echo "No wireless interfaces"
    else
        ls /sys/class/net/wl* 2>/dev/null || echo "No wl* interfaces"
    fi
    echo ""
    echo "=== Network Interfaces ==="
    ip link show 2>&1
} > "${OUTPUT_DIR}/wifi-interfaces.txt"

cat "${OUTPUT_DIR}/wifi-interfaces.txt" | head -20

# Check for WiFi interface
WIFI_IF=""
for iface in wlan0 wlp1s0; do
    if [ -e "/sys/class/net/$iface" ]; then
        WIFI_IF="$iface"
        break
    fi
done

if [ -z "$WIFI_IF" ]; then
    # Try to find any wireless interface
    WIFI_IF=$(ls /sys/class/net/ 2>/dev/null | grep -E "^wl" | head -1)
fi

if [ -n "$WIFI_IF" ]; then
    echo "PASS: WiFi interface found: $WIFI_IF"
else
    echo "FAIL: No WiFi interface found"
fi

# Check brcmfmac driver
echo "Checking brcmfmac driver..."
{
    echo "=== Brcmfmac Driver ==="
    if lsmod | grep -q brcmfmac; then
        echo "brcmfmac module: loaded"
        lsmod | grep brcm
    else
        echo "brcmfmac module: not loaded"
    fi
    echo ""
    echo "=== Driver binding ==="
    for iface in /sys/class/net/wl*; do
        if [ -d "$iface" ]; then
            echo "$(basename "$iface"):"
            readlink "$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "  No driver info"
        fi
    done
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "brcmfmac|brcm|wifi|wlan|80211" | tail -50 || echo "No WiFi messages"
} > "${OUTPUT_DIR}/brcmfmac.txt"

if grep -q "brcmfmac.*loaded" "${OUTPUT_DIR}/brcmfmac.txt"; then
    echo "PASS: brcmfmac driver loaded"
else
    echo "WARN: brcmfmac driver not loaded"
fi

# Check AP6275P firmware
echo "Checking firmware..."
{
    echo "=== AP6275P Firmware ==="
    ls -la /lib/firmware/brcm/*6275* /lib/firmware/brcm/brcmfmac* 2>/dev/null | head -20 || echo "No brcm firmware files"
    echo ""
    echo "=== Firmware load messages ==="
    dmesg 2>/dev/null | grep -iE "firmware.*brcm\|brcmfmac.*firmware" | tail -20 || echo "No firmware messages"
} > "${OUTPUT_DIR}/wifi-firmware.txt"

# Check NetworkManager
echo "Checking NetworkManager..."
{
    echo "=== NetworkManager Status ==="
    systemctl status NetworkManager --no-pager 2>&1 || echo "NetworkManager not running"
    echo ""
    echo "=== nmcli general ==="
    nmcli general 2>&1 || echo "nmcli failed"
    echo ""
    echo "=== nmcli device ==="
    nmcli device 2>&1 || echo "nmcli device failed"
} > "${OUTPUT_DIR}/networkmanager.txt"

if systemctl is-active NetworkManager &>/dev/null; then
    echo "PASS: NetworkManager is running"
else
    echo "WARN: NetworkManager is not running"
fi

# Try WiFi scan (if interface exists and we have permissions)
echo "Attempting WiFi scan..."
{
    echo "=== WiFi Scan ==="
    if [ -n "$WIFI_IF" ]; then
        nmcli device wifi list 2>&1 | head -20 || echo "WiFi scan failed or no networks found"
    else
        echo "No WiFi interface for scanning"
    fi
} > "${OUTPUT_DIR}/wifi-scan.txt"

if grep -qE "SSID|Infra" "${OUTPUT_DIR}/wifi-scan.txt"; then
    echo "PASS: WiFi scan successful - networks found"
else
    echo "INFO: WiFi scan may have failed or no networks in range"
fi

# Connection status
{
    echo "=== Connection Status ==="
    nmcli connection show --active 2>&1 || echo "No active connections"
    echo ""
    echo "=== IP Addresses ==="
    ip addr show 2>&1
} > "${OUTPUT_DIR}/wifi-connection.txt"

echo ""
echo "WiFi test completed"
exit 0

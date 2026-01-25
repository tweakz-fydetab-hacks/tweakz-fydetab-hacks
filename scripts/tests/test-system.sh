#!/bin/bash
# test-system.sh - General system health checks for FydeTab Duo
# Verifies: Failed services, boot media, kernel version, systemd-analyze

set -e

OUTPUT_DIR="${1:-.}"

echo "=== System Health Test ==="

# System info
echo "Collecting system information..."
{
    echo "=== System Overview ==="
    echo "Hostname: $(hostnamectl hostname 2>/dev/null || echo 'unknown')"
    echo "Date: $(date)"
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""
    echo "=== OS Release ==="
    cat /etc/os-release 2>/dev/null || echo "Cannot read /etc/os-release"
} > "${OUTPUT_DIR}/system-info.txt"

cat "${OUTPUT_DIR}/system-info.txt"

# Boot media detection
echo "Checking boot media..."
{
    echo "=== Boot Media ==="
    CMDLINE=$(cat /proc/cmdline)
    echo "Kernel cmdline: $CMDLINE"
    echo ""
    BOOT_DEV=""
    if echo "$CMDLINE" | grep -q "/dev/mmcblk1"; then
        BOOT_DEV="/dev/mmcblk1"
    elif echo "$CMDLINE" | grep -q "/dev/mmcblk0"; then
        BOOT_DEV="/dev/mmcblk0"
    elif echo "$CMDLINE" | grep -oP 'root=UUID=\K[^ ]+' &>/dev/null; then
        ROOT_UUID=$(echo "$CMDLINE" | grep -oP 'root=UUID=\K[^ ]+')
        if [ -L "/dev/disk/by-uuid/${ROOT_UUID}" ]; then
            BOOT_DEV=$(readlink -f "/dev/disk/by-uuid/${ROOT_UUID}")
        fi
    fi
    if [ -z "$BOOT_DEV" ]; then
        BOOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null || echo "")
    fi
    case "$BOOT_DEV" in
        *mmcblk1*)
            echo "Boot device: SD Card ($BOOT_DEV)"
            echo "Boot type: EXTERNAL (safe for testing)"
            ;;
        *mmcblk0*)
            echo "Boot device: eMMC ($BOOT_DEV)"
            echo "Boot type: INTERNAL"
            ;;
        "")
            echo "Boot device: Unknown"
            ;;
        *)
            echo "Boot device: $BOOT_DEV"
            ;;
    esac
    echo ""
    echo "=== Block Devices ==="
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL 2>&1
} > "${OUTPUT_DIR}/boot-media.txt"

cat "${OUTPUT_DIR}/boot-media.txt" | head -15

# Failed services
echo "Checking for failed services..."
{
    echo "=== Failed Services ==="
    systemctl --failed --no-pager 2>&1
    echo ""
    echo "=== Service Summary ==="
    systemctl list-units --type=service --state=failed --no-pager 2>&1 || echo "No failed services"
} > "${OUTPUT_DIR}/failed-services.txt"

FAILED_COUNT=$(systemctl --failed --no-pager 2>/dev/null | grep -c "failed" || true)
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "WARN: $FAILED_COUNT failed service(s) detected"
    systemctl --failed --no-pager | grep failed
else
    echo "PASS: No failed services"
fi

# Systemd boot analysis
echo "Analyzing boot time..."
{
    echo "=== Boot Analysis ==="
    systemd-analyze 2>&1 || echo "systemd-analyze failed"
    echo ""
    echo "=== Critical Chain ==="
    systemd-analyze critical-chain 2>&1 || true
    echo ""
    echo "=== Blame (top 20) ==="
    systemd-analyze blame 2>&1 | head -20 || true
} > "${OUTPUT_DIR}/boot-analysis.txt"

# Memory and storage
echo "Checking memory and storage..."
{
    echo "=== Memory ==="
    free -h 2>&1
    echo ""
    echo "=== Swap ==="
    swapon --show 2>&1 || echo "No swap"
    echo ""
    echo "=== Disk Usage ==="
    df -h 2>&1
    echo ""
    echo "=== Btrfs Subvolumes ==="
    btrfs subvolume list / 2>&1 | head -20 || echo "Not a btrfs filesystem or cannot list"
} > "${OUTPUT_DIR}/memory-storage.txt"

# CPU and thermals
echo "Checking CPU and thermals..."
{
    echo "=== CPU Info ==="
    lscpu 2>&1 | head -30 || cat /proc/cpuinfo | head -30
    echo ""
    echo "=== CPU Frequency ==="
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [ -f "$cpu" ]; then
            freq=$(cat "$cpu")
            cpunum=$(echo "$cpu" | grep -oE "cpu[0-9]+")
            echo "$cpunum: $((freq / 1000)) MHz"
        fi
    done 2>/dev/null || echo "Cannot read CPU frequency"
    echo ""
    echo "=== Thermal ==="
    if command -v sensors &>/dev/null; then
        sensors 2>&1 || echo "sensors command failed"
    else
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -f "$zone" ]; then
                temp=$(cat "$zone")
                name=$(cat "$(dirname "$zone")/type" 2>/dev/null || echo "unknown")
                echo "$name: $((temp / 1000))°C"
            fi
        done 2>/dev/null || echo "Cannot read thermal zones"
    fi
} > "${OUTPUT_DIR}/cpu-thermals.txt"

cat "${OUTPUT_DIR}/cpu-thermals.txt" | grep -E "MHz|°C" | head -15

# Journal errors
echo "Checking journal for errors..."
{
    echo "=== Recent Errors (last boot) ==="
    journalctl -b 0 -p err --no-pager 2>&1 | tail -50 || echo "Cannot read journal"
    echo ""
    echo "=== Recent Warnings (last 20) ==="
    journalctl -b 0 -p warning --no-pager 2>&1 | tail -20 || true
} > "${OUTPUT_DIR}/journal-errors.txt"

ERROR_COUNT=$(journalctl -b 0 -p err --no-pager 2>/dev/null | wc -l || echo "0")
echo "Journal errors this boot: $ERROR_COUNT lines"

# Installed packages summary
echo "Checking installed packages..."
{
    echo "=== Package Summary ==="
    echo "Total packages: $(pacman -Q 2>/dev/null | wc -l)"
    echo ""
    echo "=== Key Packages ==="
    for pkg in linux-fydetab-itztweak mesa waydroid gnome-shell gdm networkmanager bluez; do
        version=$(pacman -Q "$pkg" 2>/dev/null | cut -d' ' -f2 || echo "not installed")
        echo "$pkg: $version"
    done
    echo ""
    echo "=== Explicitly Installed ==="
    pacman -Qe 2>/dev/null | head -30 || echo "Cannot list packages"
} > "${OUTPUT_DIR}/packages.txt"

# Network status
echo "Checking network..."
{
    echo "=== Network Interfaces ==="
    ip addr show 2>&1
    echo ""
    echo "=== Default Route ==="
    ip route show default 2>&1 || echo "No default route"
    echo ""
    echo "=== DNS ==="
    cat /etc/resolv.conf 2>&1 || echo "Cannot read resolv.conf"
    echo ""
    echo "=== Connectivity Test ==="
    if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        echo "Internet: REACHABLE"
    else
        echo "Internet: NOT REACHABLE"
    fi
} > "${OUTPUT_DIR}/network.txt"

echo ""
echo "System health test completed"
exit 0

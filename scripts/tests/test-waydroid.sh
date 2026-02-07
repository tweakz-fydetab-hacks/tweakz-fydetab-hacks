#!/bin/bash
# test-waydroid.sh - Binder/waydroid diagnostics for FydeTab Duo
# Collects detailed diagnostics for binder and waydroid troubleshooting

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Waydroid Test ==="

# Check binder module
echo "Checking binder module..."
{
    echo "=== Binder Module ==="
    BINDER_BUILTIN=0
    if [ -f /proc/config.gz ] && zcat /proc/config.gz | grep -q 'CONFIG_ANDROID_BINDER_IPC=y'; then
        BINDER_BUILTIN=1
        echo "binder_linux: BUILT-IN (CONFIG_ANDROID_BINDER_IPC=y)"
    elif lsmod | grep -q binder_linux; then
        echo "binder_linux module: LOADED"
        lsmod | grep binder
    else
        echo "binder_linux module: NOT LOADED"
        echo ""
        echo "Attempting to load binder_linux..."
        if sudo modprobe binder_linux 2>&1; then
            echo "Module loaded successfully"
        else
            echo "Failed to load module"
        fi
    fi
    echo ""
    echo "=== /sys/fs/binder check ==="
    if [ -d /sys/fs/binder ]; then
        echo "/sys/fs/binder: EXISTS"
        ls -la /sys/fs/binder/ 2>&1 || true
    else
        echo "/sys/fs/binder: DOES NOT EXIST"
        echo "This means binder_linux module is not loaded or not working"
    fi
    echo ""
    echo "=== Kernel config ==="
    if [ -f /proc/config.gz ]; then
        zcat /proc/config.gz | grep -iE "CONFIG_ANDROID|CONFIG_BINDER" || echo "No BINDER/ANDROID configs"
    else
        echo "/proc/config.gz not available"
    fi
} > "${OUTPUT_DIR}/binder-module.txt"

cat "${OUTPUT_DIR}/binder-module.txt" | head -30

# Check binderfs mount
echo "Checking binderfs mount..."
{
    echo "=== dev-binderfs.mount ==="
    systemctl status dev-binderfs.mount --no-pager 2>&1 || echo "Mount unit not found"
    echo ""
    echo "=== Mount journal ==="
    journalctl -u dev-binderfs.mount --no-pager -n 30 2>&1 || true
    echo ""
    echo "=== /dev/binderfs ==="
    if [ -d /dev/binderfs ]; then
        echo "/dev/binderfs: MOUNTED"
        ls -la /dev/binderfs/ 2>&1
    else
        echo "/dev/binderfs: NOT MOUNTED"
    fi
    echo ""
    echo "=== Mount points ==="
    mount | grep -i binder || echo "No binder mounts"
} > "${OUTPUT_DIR}/binderfs-mount.txt"

if [ -d /dev/binderfs ]; then
    echo "PASS: binderfs is mounted"
else
    echo "FAIL: binderfs is not mounted"
fi

# Check binder setup service
echo "Checking binder setup..."
{
    echo "=== waydroid-binder-setup.service ==="
    systemctl status waydroid-binder-setup.service --no-pager 2>&1 || echo "Service not found"
    echo ""
    echo "=== Service journal ==="
    journalctl -u waydroid-binder-setup.service --no-pager -n 30 2>&1 || true
    echo ""
    echo "=== Binder devices ==="
    for dev in /dev/binder /dev/hwbinder /dev/vndbinder; do
        if [ -e "$dev" ]; then
            echo "$dev: EXISTS ($(readlink -f "$dev" 2>/dev/null || echo 'not a symlink'))"
        else
            echo "$dev: MISSING"
        fi
    done
} > "${OUTPUT_DIR}/binder-setup.txt"

# Check kernel config for Android features
echo "Checking kernel Android config..."
{
    echo "=== Kernel Android/Binder Config ==="
    if [ -f /proc/config.gz ]; then
        zcat /proc/config.gz | grep -iE "CONFIG_ANDROID|CONFIG_BINDER|CONFIG_ASHMEM" | sort
    else
        echo "/proc/config.gz not available"
        # Try to find config in /boot
        for cfg in /boot/config-$(uname -r) /boot/config; do
            if [ -f "$cfg" ]; then
                grep -iE "CONFIG_ANDROID|CONFIG_BINDER|CONFIG_ASHMEM" "$cfg" | sort
                break
            fi
        done
    fi
} > "${OUTPUT_DIR}/kernel-config.txt"

# Check dmesg for binder
echo "Checking dmesg for binder..."
{
    echo "=== Binder Kernel Messages ==="
    dmesg 2>/dev/null | grep -iE "binder|android" | tail -50 || echo "No binder messages"
} > "${OUTPUT_DIR}/dmesg-binder.txt"

# Check waydroid initialization
echo "Checking waydroid initialization..."
{
    echo "=== Waydroid Init Status ==="
    if [ -f /var/lib/waydroid/.panthor-initialized ]; then
        echo "Panthor init flag: EXISTS"
        ls -la /var/lib/waydroid/.panthor-initialized
    else
        echo "Panthor init flag: MISSING (init may not have run)"
    fi
    echo ""
    echo "=== Waydroid Config ==="
    if [ -f /var/lib/waydroid/waydroid.cfg ]; then
        echo "waydroid.cfg: EXISTS"
        cat /var/lib/waydroid/waydroid.cfg
    else
        echo "waydroid.cfg: MISSING"
    fi
    echo ""
    echo "=== Waydroid Images ==="
    ls -la /var/lib/waydroid/images/ 2>&1 || echo "No images directory"
    echo ""
    echo "=== LXC Container ==="
    ls -la /var/lib/waydroid/lxc/ 2>&1 || echo "No LXC container"
} > "${OUTPUT_DIR}/waydroid-init.txt"

# Check waydroid-panthor-init service
echo "Checking waydroid-panthor-init service..."
{
    echo "=== waydroid-panthor-init.service ==="
    systemctl status waydroid-panthor-init.service --no-pager 2>&1 || echo "Service not found"
    echo ""
    echo "=== Service journal ==="
    journalctl -u waydroid-panthor-init --no-pager -n 50 2>&1 || true
} > "${OUTPUT_DIR}/waydroid-panthor-init.txt"

# Check waydroid-container service (required for session start)
echo "Checking waydroid-container service..."
{
    echo "=== waydroid-container.service ==="
    systemctl status waydroid-container.service --no-pager 2>&1 || echo "Service not found"
    echo ""
    echo "=== Enabled state ==="
    systemctl is-enabled waydroid-container.service 2>&1 || echo "Not installed"
    echo ""
    echo "=== Service journal ==="
    journalctl -u waydroid-container.service --no-pager -n 50 2>&1 || true
} > "${OUTPUT_DIR}/waydroid-container.txt"

CONTAINER_ENABLED=$(systemctl is-enabled waydroid-container.service 2>/dev/null || echo "not-found")
CONTAINER_ACTIVE=$(systemctl is-active waydroid-container.service 2>/dev/null || echo "inactive")
if [ "$CONTAINER_ACTIVE" = "active" ]; then
    echo "PASS: waydroid-container.service is running"
elif [ "$CONTAINER_ENABLED" = "enabled" ]; then
    echo "WARN: waydroid-container.service is enabled but not running"
else
    echo "FAIL: waydroid-container.service is not enabled (sessions cannot start)"
fi

# Check actual waydroid status (catches runtime failures missed by service checks)
echo "Checking waydroid session status..."
{
    echo "=== Waydroid Status ==="
    waydroid status 2>&1 || echo "waydroid status command failed"
} > "${OUTPUT_DIR}/waydroid-status.txt"

cat "${OUTPUT_DIR}/waydroid-status.txt"

WAYDROID_CONTAINER_RUNNING=0
if grep -qi "Container.*RUNNING" "${OUTPUT_DIR}/waydroid-status.txt" 2>/dev/null; then
    echo "PASS: Waydroid container is RUNNING"
    WAYDROID_CONTAINER_RUNNING=1
elif grep -qi "Container.*FROZEN" "${OUTPUT_DIR}/waydroid-status.txt" 2>/dev/null; then
    echo "WARN: Waydroid container is FROZEN"
else
    echo "FAIL: Waydroid container is NOT running"
fi

# Try remediation if binder is not working
echo "Attempting remediation if needed..."
{
    echo "=== Remediation Attempts ==="
    NEEDS_FIX=0

    # Check if binder module needs loading (skip if built-in)
    if [ "${BINDER_BUILTIN:-0}" -eq 1 ]; then
        echo "binder_linux is built-in, skipping modprobe"
    elif ! lsmod | grep -q binder_linux; then
        echo "Attempting to load binder_linux module..."
        if sudo modprobe binder_linux 2>&1; then
            echo "SUCCESS: binder_linux loaded"
        else
            echo "FAILED: Could not load binder_linux"
            NEEDS_FIX=1
        fi
    fi

    # Check if binderfs needs mounting
    if [ ! -d /dev/binderfs ]; then
        echo "Attempting to start dev-binderfs.mount..."
        if sudo systemctl start dev-binderfs.mount 2>&1; then
            echo "SUCCESS: binderfs mounted"
        else
            echo "FAILED: Could not mount binderfs"
            NEEDS_FIX=1
        fi
    fi

    # Check if binder setup needs running
    if [ ! -e /dev/binder ]; then
        echo "Attempting to start waydroid-binder-setup.service..."
        if sudo systemctl start waydroid-binder-setup.service 2>&1; then
            echo "SUCCESS: binder setup completed"
        else
            echo "FAILED: Binder setup failed"
            NEEDS_FIX=1
        fi
    fi

    if [ $NEEDS_FIX -eq 0 ]; then
        echo "All binder components appear functional"
    else
        echo "Some binder components need attention"
    fi
} > "${OUTPUT_DIR}/remediation.txt"

cat "${OUTPUT_DIR}/remediation.txt"

# Final status
echo ""
echo "=== Waydroid Test Summary ==="
CONTAINER_OK=$(systemctl is-enabled waydroid-container.service 2>/dev/null || echo "not-found")
if [ -d /dev/binderfs ] && [ -e /dev/binder ] && [ -f /var/lib/waydroid/waydroid.cfg ] && [ "$CONTAINER_OK" = "enabled" ] && [ "$WAYDROID_CONTAINER_RUNNING" -eq 1 ]; then
    echo "PASS: Waydroid is running"
    echo "  binderfs: mounted"
    echo "  binder devices: present"
    echo "  waydroid: initialized"
    echo "  container service: enabled"
    echo "  container status: RUNNING"
    echo ""
    echo "Waydroid test completed"
    exit 0
else
    echo "FAIL: Waydroid needs attention"
    [ ! -d /dev/binderfs ] && echo "  - binderfs not mounted"
    [ ! -e /dev/binder ] && echo "  - /dev/binder missing"
    [ ! -f /var/lib/waydroid/waydroid.cfg ] && echo "  - waydroid not initialized"
    [ "$CONTAINER_OK" != "enabled" ] && echo "  - waydroid-container.service not enabled"
    [ "$WAYDROID_CONTAINER_RUNNING" -ne 1 ] && echo "  - waydroid container not running (check 'waydroid status')"
    echo ""
    echo "Waydroid test completed"
    exit 1
fi

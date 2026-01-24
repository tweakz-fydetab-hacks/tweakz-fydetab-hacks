#!/bin/bash
# waydroid-diag-collect.sh - Collect static Waydroid diagnostics
# Run as: sudo ./waydroid-diag-collect.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

mkdir -p "$LOG_DIR"
info "Collecting diagnostics to: $LOG_DIR"

# Helper to check and optionally install packages
check_install_pkg() {
    local pkg="$1"
    local aur="${2:-false}"

    if ! command -v "$pkg" &>/dev/null && ! pacman -Qi "$pkg" &>/dev/null 2>&1; then
        warn "$pkg not found"
        read -p "Install $pkg? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [[ "$aur" == "true" ]]; then
                if command -v paru &>/dev/null; then
                    sudo -u arch paru -S --noconfirm "$pkg" || warn "Failed to install $pkg"
                else
                    warn "paru not available. Install paru first for AUR packages."
                    return 1
                fi
            else
                pacman -S --noconfirm "$pkg" || warn "Failed to install $pkg"
            fi
        else
            return 1
        fi
    fi
    return 0
}

# 01 - System info
info "01 - Collecting system info..."
{
    echo "=== System Info ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Arch: $(uname -m)"
    echo
    echo "=== /etc/os-release ==="
    cat /etc/os-release 2>/dev/null || echo "Not found"
} > "$LOG_DIR/01-system-info.txt"

# 02 - Kernel config (binder, PSI, memcg)
info "02 - Checking kernel config..."
{
    echo "=== Kernel Config (from /proc/config.gz) ==="
    if [[ -f /proc/config.gz ]]; then
        echo "--- Binder related ---"
        zcat /proc/config.gz | grep -i binder || echo "No binder config found"
        echo
        echo "--- PSI related ---"
        zcat /proc/config.gz | grep -i "CONFIG_PSI" || echo "No PSI config found"
        echo
        echo "--- Memcg related ---"
        zcat /proc/config.gz | grep -i "CONFIG_MEMCG" || echo "No memcg config found"
        echo
        echo "--- ASHMEM related ---"
        zcat /proc/config.gz | grep -i ashmem || echo "No ashmem config found"
        echo
        echo "--- LXC/Container related ---"
        zcat /proc/config.gz | grep -E "CONFIG_(NAMESPACES|USER_NS|NET_NS|CGROUPS)" || echo "No namespace config found"
    else
        echo "/proc/config.gz not available"
        echo "Checking /boot configs..."
        for cfg in /boot/config-* /boot/config; do
            if [[ -f "$cfg" ]]; then
                echo "--- Found: $cfg ---"
                grep -E "(BINDER|PSI|MEMCG|ASHMEM|NAMESPACES)" "$cfg" | head -50
            fi
        done
    fi
} > "$LOG_DIR/02-kernel-config.txt"

# 03 - Binder devices
info "03 - Checking binder devices..."
{
    echo "=== /dev/binder* ==="
    ls -la /dev/binder* 2>/dev/null || echo "No /dev/binder* devices found"
    echo
    echo "=== /dev/binderfs/ ==="
    ls -la /dev/binderfs/ 2>/dev/null || echo "/dev/binderfs/ not found or empty"
    echo
    echo "=== /dev/anbox-* ==="
    ls -la /dev/anbox-* 2>/dev/null || echo "No /dev/anbox-* devices found"
    echo
    echo "=== Binder in dmesg ==="
    dmesg | grep -i binder | tail -50 || echo "No binder messages in dmesg"
} > "$LOG_DIR/03-binder-devices.txt"

# 04 - GPU info
info "04 - Collecting GPU info..."
{
    echo "=== GPU in dmesg ==="
    dmesg | grep -iE "(panthor|panfrost|mali|gpu|drm)" | tail -100
    echo
    echo "=== DRM devices ==="
    ls -la /dev/dri/ 2>/dev/null || echo "/dev/dri/ not found"
    echo
    echo "=== GPU Renderer (glxinfo) ==="
    if check_install_pkg mesa-utils false 2>/dev/null; then
        glxinfo 2>/dev/null | grep -iE "(vendor|renderer|version|string)" | head -20 || echo "glxinfo failed"
    else
        echo "glxinfo not available (mesa-utils not installed)"
    fi
    echo
    echo "=== EGL Info ==="
    if command -v eglinfo &>/dev/null; then
        eglinfo 2>/dev/null | head -100 || echo "eglinfo failed"
    else
        echo "eglinfo not available"
    fi
    echo
    echo "=== Vulkan Info ==="
    if check_install_pkg vulkan-tools false 2>/dev/null; then
        vulkaninfo --summary 2>/dev/null || echo "vulkaninfo failed or no Vulkan support"
    else
        echo "vulkaninfo not available (vulkan-tools not installed)"
    fi
    echo
    echo "=== GPU sysfs ==="
    for gpu in /sys/class/drm/card*/device; do
        if [[ -d "$gpu" ]]; then
            echo "--- $gpu ---"
            cat "$gpu/uevent" 2>/dev/null || true
        fi
    done
} > "$LOG_DIR/04-gpu-info.txt"

# 05 - Waydroid config
info "05 - Collecting Waydroid config..."
{
    echo "=== /var/lib/waydroid/ ==="
    ls -laR /var/lib/waydroid/ 2>/dev/null || echo "Directory not found"
    echo
    echo "=== waydroid.cfg ==="
    cat /var/lib/waydroid/waydroid.cfg 2>/dev/null || echo "Not found"
    echo
    echo "=== waydroid_base.prop ==="
    cat /var/lib/waydroid/waydroid_base.prop 2>/dev/null || echo "Not found"
    echo
    echo "=== waydroid.prop (user overrides) ==="
    cat /var/lib/waydroid/waydroid.prop 2>/dev/null || echo "Not found"
    echo
    echo "=== ~/.local/share/waydroid/ ==="
    ls -laR /home/arch/.local/share/waydroid/ 2>/dev/null || echo "Directory not found"
} > "$LOG_DIR/05-waydroid-config.txt"

# 06 - Systemd services
info "06 - Checking systemd services..."
{
    echo "=== waydroid-container.service ==="
    systemctl status waydroid-container.service 2>&1 || true
    echo
    echo "=== waydroid-container.service (cat) ==="
    systemctl cat waydroid-container.service 2>&1 || true
    echo
    echo "=== All waydroid related services ==="
    systemctl list-units --all '*waydroid*' 2>&1 || true
    echo
    echo "=== LXC service ==="
    systemctl status lxc.service 2>&1 || true
} > "$LOG_DIR/06-systemd-services.txt"

# 07 - Journal logs
info "07 - Collecting journal logs..."
{
    echo "=== Waydroid journal (last 200 lines) ==="
    journalctl -u waydroid-container.service -n 200 --no-pager 2>&1 || true
    echo
    echo "=== Recent boots ==="
    journalctl --list-boots | head -10 2>&1 || true
} > "$LOG_DIR/07-journal-logs.txt"

# 08 - LXC info
info "08 - Collecting LXC info..."
{
    echo "=== LXC version ==="
    lxc-info --version 2>&1 || echo "lxc-info not found"
    echo
    echo "=== LXC containers ==="
    lxc-ls -f 2>&1 || echo "No containers or lxc-ls failed"
    echo
    echo "=== Waydroid LXC config ==="
    cat /var/lib/waydroid/lxc/waydroid/config 2>/dev/null || echo "Not found"
} > "$LOG_DIR/08-lxc-info.txt"

# 09 - Cgroups
info "09 - Checking cgroups..."
{
    echo "=== Cgroup mount points ==="
    mount | grep cgroup
    echo
    echo "=== /sys/fs/cgroup/ structure ==="
    ls -la /sys/fs/cgroup/ 2>/dev/null || echo "Not found"
    echo
    echo "=== Cgroup v2 check ==="
    if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
        echo "Cgroup v2 (unified) detected"
        cat /sys/fs/cgroup/cgroup.controllers
    else
        echo "Cgroup v1 or mixed mode"
    fi
} > "$LOG_DIR/09-cgroups.txt"

# 10 - Kernel modules
info "10 - Checking kernel modules..."
{
    echo "=== Loaded modules (binder/ashmem related) ==="
    lsmod | grep -iE "(binder|ashmem)" || echo "No binder/ashmem modules loaded"
    echo
    echo "=== All loaded modules ==="
    lsmod
} > "$LOG_DIR/10-modules.txt"

# 11 - PSI status
info "11 - Checking PSI (Pressure Stall Information)..."
{
    echo "=== /proc/pressure/ ==="
    if [[ -d /proc/pressure ]]; then
        echo "PSI is enabled"
        for f in /proc/pressure/*; do
            echo "--- $(basename "$f") ---"
            cat "$f"
        done
    else
        echo "PSI is NOT enabled (/proc/pressure/ does not exist)"
        echo
        echo "Check kernel cmdline for psi=1:"
        cat /proc/cmdline
    fi
} > "$LOG_DIR/11-psi-status.txt"

# 12 - Boot cmdline
info "12 - Kernel command line..."
{
    echo "=== /proc/cmdline ==="
    cat /proc/cmdline
    echo
    echo "=== GRUB default cmdline ==="
    grep CMDLINE /etc/default/grub 2>/dev/null || echo "GRUB config not found"
} > "$LOG_DIR/12-cmdline.txt"

# 13 - dmesg full (useful for complete picture)
info "13 - Full dmesg..."
dmesg > "$LOG_DIR/13-dmesg-full.txt"

# Summary
info "Collection complete!"
echo
echo "=== Quick Summary ==="

# Check critical items
echo -n "Binder devices: "
if ls /dev/binder* &>/dev/null || ls /dev/binderfs/binder* &>/dev/null; then
    echo -e "${GREEN}FOUND${NC}"
else
    echo -e "${RED}MISSING${NC}"
fi

echo -n "PSI enabled: "
if [[ -d /proc/pressure ]]; then
    echo -e "${GREEN}YES${NC}"
else
    echo -e "${RED}NO${NC}"
fi

echo -n "Waydroid initialized: "
if [[ -f /var/lib/waydroid/waydroid.cfg ]]; then
    echo -e "${GREEN}YES${NC}"
else
    echo -e "${YELLOW}NO (run: waydroid init)${NC}"
fi

echo -n "GPU driver: "
if dmesg | grep -qi panthor; then
    echo -e "${GREEN}Panthor${NC}"
elif dmesg | grep -qi panfrost; then
    echo -e "${YELLOW}Panfrost (older driver)${NC}"
else
    echo -e "${RED}Unknown/Not loaded${NC}"
fi

echo
echo "Logs saved to: $LOG_DIR"
echo "Run waydroid-diag-runtime.sh next to capture startup logs"

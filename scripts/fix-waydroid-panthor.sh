#!/bin/bash
# fix-waydroid-panthor.sh
# Fixes Waydroid on FydeTab Duo to use Panthor GPU
# Run this script ON the SD card system (not from the host)

set -e

PANTHOR_IMAGE_URL="https://github.com/WillzenZou/armbian_fork_build/releases/download/willzen-armbian-24.5.0/2.waydroid-panthorv10-240416-v1.img.tar.gz"
WAYDROID_IMAGES_DIR="/var/lib/waydroid/images"
WAYDROID_BASE_PROP="/var/lib/waydroid/waydroid_base.prop"
WAYDROID_PROP="/var/lib/waydroid/waydroid.prop"
TMP_DIR="/tmp/waydroid-panthor-fix"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (sudo)"
    exit 1
fi

# Detect the correct render device for Panthor
detect_panthor_render_device() {
    log_step "Detecting Panthor render device..."

    # Method 1: Check /sys/class/drm for panthor
    for card in /sys/class/drm/card*; do
        if [[ -d "$card" ]]; then
            driver=$(basename "$(readlink -f "$card/device/driver")" 2>/dev/null || true)
            if [[ "$driver" == "panthor" ]]; then
                card_num=$(basename "$card" | sed 's/card//')
                render_dev="renderD$((128 + card_num))"
                if [[ -e "/dev/dri/$render_dev" ]]; then
                    log_info "Found Panthor at /dev/dri/$render_dev (via sysfs)"
                    echo "$render_dev"
                    return 0
                fi
            fi
        fi
    done

    # Method 2: Check dmesg for panthor minor number
    panthor_minor=$(dmesg 2>/dev/null | grep -i "Initialized panthor" | grep -oP "minor \K\d+" | tail -1 || true)
    if [[ -n "$panthor_minor" ]]; then
        render_dev="renderD$((128 + panthor_minor))"
        if [[ -e "/dev/dri/$render_dev" ]]; then
            log_info "Found Panthor at /dev/dri/$render_dev (via dmesg)"
            echo "$render_dev"
            return 0
        fi
    fi

    # Method 3: Check journalctl for panthor minor number
    panthor_minor=$(journalctl -k --no-pager 2>/dev/null | grep -i "Initialized panthor" | grep -oP "minor \K\d+" | tail -1 || true)
    if [[ -n "$panthor_minor" ]]; then
        render_dev="renderD$((128 + panthor_minor))"
        if [[ -e "/dev/dri/$render_dev" ]]; then
            log_info "Found Panthor at /dev/dri/$render_dev (via journal)"
            echo "$render_dev"
            return 0
        fi
    fi

    # Method 4: Default for RK3588 (typical: rknpu=0, rockchip=1, panthor=2)
    if [[ -e "/dev/dri/renderD130" ]]; then
        log_warn "Using default /dev/dri/renderD130 (RK3588 typical layout)"
        echo "renderD130"
        return 0
    fi

    # Fallback to highest numbered render device
    highest=$(ls /dev/dri/renderD* 2>/dev/null | sort -V | tail -1 | xargs basename)
    if [[ -n "$highest" ]]; then
        log_warn "Using fallback $highest"
        echo "$highest"
        return 0
    fi

    log_error "No render device found!"
    exit 1
}

# Stop Waydroid
stop_waydroid() {
    log_step "Stopping Waydroid..."
    waydroid session stop 2>/dev/null || true
    systemctl stop waydroid-container.service 2>/dev/null || true
    sleep 2
}

# Download Panthor image
download_panthor_image() {
    log_step "Downloading Panthor-enabled Waydroid image..."
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    if [[ -f "2.waydroid-panthorv10-240416-v1.img.tar.gz" ]]; then
        log_info "Image already downloaded, verifying..."
    else
        wget --progress=bar:force:noscroll -O "2.waydroid-panthorv10-240416-v1.img.tar.gz" "$PANTHOR_IMAGE_URL"
    fi

    log_step "Extracting image..."
    tar xzf "2.waydroid-panthorv10-240416-v1.img.tar.gz"

    if [[ ! -f "system.img" ]] || [[ ! -f "vendor.img" ]]; then
        # Check if they're in a subdirectory
        if [[ -f */system.img ]]; then
            mv */system.img */vendor.img . 2>/dev/null || true
        fi
    fi

    if [[ ! -f "system.img" ]] || [[ ! -f "vendor.img" ]]; then
        log_error "Failed to extract system.img and vendor.img"
        ls -la "$TMP_DIR"
        exit 1
    fi

    log_info "Download and extraction complete"
}

# Install new images
install_images() {
    log_step "Installing Panthor Waydroid images..."

    mkdir -p "$WAYDROID_IMAGES_DIR"
    rm -f "$WAYDROID_IMAGES_DIR/system.img" "$WAYDROID_IMAGES_DIR/vendor.img"

    cp "$TMP_DIR/system.img" "$WAYDROID_IMAGES_DIR/"
    cp "$TMP_DIR/vendor.img" "$WAYDROID_IMAGES_DIR/"

    log_info "Images installed"
}

# Fix render device in config
fix_render_device() {
    local render_dev="$1"

    log_step "Configuring render device to /dev/dri/$render_dev..."

    # Update waydroid_base.prop
    if [[ -f "$WAYDROID_BASE_PROP" ]]; then
        sed -i "s|gralloc.gbm.device=/dev/dri/renderD[0-9]*|gralloc.gbm.device=/dev/dri/$render_dev|g" "$WAYDROID_BASE_PROP"
        log_info "Updated $WAYDROID_BASE_PROP"
    fi

    # Update waydroid.prop
    if [[ -f "$WAYDROID_PROP" ]]; then
        sed -i "s|gralloc.gbm.device=/dev/dri/renderD[0-9]*|gralloc.gbm.device=/dev/dri/$render_dev|g" "$WAYDROID_PROP"
        log_info "Updated $WAYDROID_PROP"
    fi
}

# Update LXC config for correct render device
fix_lxc_config() {
    local render_dev="$1"
    local lxc_config="/var/lib/waydroid/lxc/waydroid/config_nodes"

    if [[ -f "$lxc_config" ]]; then
        log_step "Updating LXC config for $render_dev..."
        sed -i "s|/dev/dri/renderD[0-9]* dev/dri/renderD[0-9]*|/dev/dri/$render_dev dev/dri/$render_dev|g" "$lxc_config"
        log_info "Updated LXC config"
    fi
}

# Reinitialize Waydroid
reinit_waydroid() {
    log_step "Reinitializing Waydroid..."

    # Remove old rootfs to force reinit
    rm -rf /var/lib/waydroid/rootfs
    rm -rf /var/lib/waydroid/overlay
    rm -rf /var/lib/waydroid/overlay_rw

    # Reinit with local images
    waydroid init -f

    log_info "Waydroid reinitialized"
}

# Clean up
cleanup() {
    log_step "Cleaning up..."
    rm -rf "$TMP_DIR"
    log_info "Cleanup complete"
}

# Main
main() {
    echo "=========================================="
    echo "  Waydroid Panthor Fix for FydeTab Duo"
    echo "=========================================="
    echo ""

    # Detect render device first
    RENDER_DEV=$(detect_panthor_render_device)
    echo ""

    stop_waydroid
    download_panthor_image
    install_images
    fix_render_device "$RENDER_DEV"
    reinit_waydroid
    fix_lxc_config "$RENDER_DEV"
    cleanup

    echo ""
    echo "=========================================="
    log_info "Installation complete!"
    echo "=========================================="
    echo ""
    echo "To test Waydroid:"
    echo "  1. Start the container: sudo systemctl start waydroid-container"
    echo "  2. Launch the UI: waydroid show-full-ui"
    echo ""
    echo "If it still doesn't work, check:"
    echo "  - /dev/dri/$RENDER_DEV exists and is accessible"
    echo "  - journalctl -u waydroid-container -f"
    echo "  - waydroid logcat"
}

main "$@"

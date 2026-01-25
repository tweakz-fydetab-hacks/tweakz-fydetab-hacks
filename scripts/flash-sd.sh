#!/bin/bash
# Flash FydeTab image to SD card

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$ROOT_DIR/images"
OUT_DIR="$IMAGES_DIR/out"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
SD_DEVICE=""
CONFIRM=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --device|-d)
            SD_DEVICE="$2"
            shift 2
            ;;
        --yes|-y)
            CONFIRM=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--device /dev/sdX] [--yes]"
            echo ""
            echo "Options:"
            echo "  --device, -d DEV  Target block device (skip interactive selection)"
            echo "  --yes, -y         Skip confirmation prompt"
            echo "  --help, -h        Show this help"
            echo ""
            echo "Without arguments, prompts interactively for device and confirmation."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--device /dev/sdX] [--yes]"
            exit 1
            ;;
    esac
done

# Find SD card device
find_sd_card() {
    # If device was passed via CLI, validate it
    if [ -n "$SD_DEVICE" ]; then
        if [ ! -b "$SD_DEVICE" ]; then
            log_error "Device not found: $SD_DEVICE"
            exit 1
        fi
        local model=$(cat /sys/block/$(basename "$SD_DEVICE")/device/model 2>/dev/null || echo "unknown")
        local size=$(lsblk -bno SIZE "$SD_DEVICE" 2>/dev/null | head -1)
        local size_gb=$((size / 1024 / 1024 / 1024))
        log_info "Using device: $SD_DEVICE ($model, ${size_gb}GB)"
        return
    fi

    # Interactive: scan and prompt for selection
    local devices=()

    for dev in /dev/sd[a-z] /dev/mmcblk[0-9]; do
        if [ -b "$dev" ]; then
            # Check if removable (for SD cards in USB readers)
            local removable=$(cat /sys/block/$(basename "$dev")/removable 2>/dev/null || echo "0")
            local model=$(cat /sys/block/$(basename "$dev")/device/model 2>/dev/null || echo "unknown")
            local size=$(lsblk -bno SIZE "$dev" 2>/dev/null | head -1)
            local size_gb=$((size / 1024 / 1024 / 1024))

            # Skip very large devices (likely system drives)
            if [ "$size_gb" -lt 256 ] && [ "$size_gb" -gt 4 ]; then
                devices+=("$dev|$model|${size_gb}GB")
            fi
        fi
    done

    if [ ${#devices[@]} -eq 0 ]; then
        log_error "No suitable SD card found"
        log_info "Insert an SD card (8GB-256GB) and try again"
        exit 1
    fi

    echo ""
    log_info "Found potential SD card devices:"
    echo ""

    local i=1
    for dev_info in "${devices[@]}"; do
        IFS='|' read -r dev model size <<< "$dev_info"
        echo "  $i) $dev - $model ($size)"
        ((i++))
    done

    echo ""
    read -p "Select device number (or 'q' to quit): " selection

    if [ "$selection" = "q" ]; then
        exit 0
    fi

    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#devices[@]} ]; then
        log_error "Invalid selection"
        exit 1
    fi

    IFS='|' read -r SD_DEVICE model size <<< "${devices[$((selection-1))]}"
    echo ""
    log_warn "Selected: $SD_DEVICE ($model, $size)"
}

# Find latest image
find_image() {
    if [ ! -d "$OUT_DIR" ]; then
        log_error "Output directory not found: $OUT_DIR"
        log_info "Run build-image.sh first"
        exit 1
    fi

    # Find most recent .img.xz file
    IMAGE_FILE=$(ls -t "$OUT_DIR"/*.img.xz 2>/dev/null | head -1)

    if [ -z "$IMAGE_FILE" ]; then
        log_error "No image file found in $OUT_DIR"
        log_info "Run build-image.sh first"
        exit 1
    fi

    log_info "Found image: $IMAGE_FILE"
    ls -lh "$IMAGE_FILE"
}

# Flash the image
flash_image() {
    echo ""
    log_warn "WARNING: This will ERASE ALL DATA on $SD_DEVICE"

    if [ "$CONFIRM" = true ]; then
        log_info "Auto-confirmed via --yes flag"
    else
        echo ""
        read -p "Type 'yes' to confirm: " confirm
        if [ "$confirm" != "yes" ]; then
            log_info "Aborted"
            exit 0
        fi
    fi

    # Unmount any mounted partitions
    log_info "Unmounting partitions on $SD_DEVICE..."
    for part in ${SD_DEVICE}*; do
        if mountpoint -q "$part" 2>/dev/null || mount | grep -q "^$part "; then
            sudo umount "$part" 2>/dev/null || true
        fi
    done

    log_info "Flashing image to $SD_DEVICE..."
    log_info "This may take several minutes..."
    echo ""

    # Flash with progress
    xzcat "$IMAGE_FILE" | sudo dd of="$SD_DEVICE" bs=4M status=progress conv=fsync

    # Sync to ensure all data is written
    log_info "Syncing..."
    sync

    echo ""
    log_info "Flash complete!"
    log_info ""
    log_info "You can now:"
    log_info "  1. Remove the SD card"
    log_info "  2. Insert into FydeTab Duo"
    log_info "  3. Boot from SD card"
}

# Main
log_info "FydeTab SD Card Flasher"
echo ""

# Check for root (needed for dd)
if [ "$EUID" -ne 0 ]; then
    log_warn "This script needs root for dd. Will use sudo."
fi

find_image
find_sd_card
flash_image

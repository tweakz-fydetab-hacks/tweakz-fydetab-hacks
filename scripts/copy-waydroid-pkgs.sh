#!/bin/bash
# copy-waydroid-pkgs.sh - Copy waydroid packages to SD card
# This copies pre-built waydroid packages for installation after boot

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# SD card mount point
SD_MOUNT="${SD_MOUNT:-/run/media/${USER}/ROOTFS}"
SD_HOME="${SD_MOUNT}/@home/arch"

# Package source directories
PKGBUILDS_DIR="$REPO_DIR/pkgbuilds"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Copy Waydroid Packages to SD Card ==="

# Check SD card is mounted
if [ ! -d "$SD_MOUNT" ]; then
    echo -e "${RED}ERROR: SD card not mounted at $SD_MOUNT${NC}"
    echo "Mount the SD card first, or set SD_MOUNT environment variable"
    exit 1
fi

# Check for btrfs subvolume structure
if [ ! -d "$SD_HOME" ]; then
    # Maybe it's not a btrfs layout
    if [ -d "${SD_MOUNT}/home/arch" ]; then
        SD_HOME="${SD_MOUNT}/home/arch"
        echo -e "${YELLOW}Using non-btrfs layout: $SD_HOME${NC}"
    else
        echo -e "${RED}ERROR: Cannot find home directory${NC}"
        exit 1
    fi
fi

# Create packages directory
PKGS_DEST="$SD_HOME/pkgs"
echo "Creating packages directory: $PKGS_DEST"
sudo mkdir -p "$PKGS_DEST"

# Find and copy waydroid packages
echo "Looking for waydroid packages..."
FOUND_PKGS=0

# Check waydroid-panthor-images
IMAGES_PKG=$(ls -t "$PKGBUILDS_DIR/waydroid-panthor-images/"*.pkg.tar.zst 2>/dev/null | head -1)
if [ -n "$IMAGES_PKG" ]; then
    echo "Found: $(basename "$IMAGES_PKG")"
    sudo cp -v "$IMAGES_PKG" "$PKGS_DEST/"
    FOUND_PKGS=$((FOUND_PKGS + 1))
else
    echo -e "${YELLOW}WARN: waydroid-panthor-images package not found${NC}"
    echo "Build it first: cd pkgbuilds/waydroid-panthor-images && makepkg -s"
fi

# Check waydroid-panthor-config
CONFIG_PKG=$(ls -t "$PKGBUILDS_DIR/waydroid-panthor-config/"*.pkg.tar.zst 2>/dev/null | head -1)
if [ -n "$CONFIG_PKG" ]; then
    echo "Found: $(basename "$CONFIG_PKG")"
    sudo cp -v "$CONFIG_PKG" "$PKGS_DEST/"
    FOUND_PKGS=$((FOUND_PKGS + 1))
else
    echo -e "${YELLOW}WARN: waydroid-panthor-config package not found${NC}"
    echo "Build it first: cd pkgbuilds/waydroid-panthor-config && makepkg -s"
fi

# Set ownership
sudo chown -R 1000:1000 "$PKGS_DEST"

echo ""
if [ $FOUND_PKGS -gt 0 ]; then
    echo -e "${GREEN}Copied $FOUND_PKGS package(s) to SD card${NC}"
    echo ""
    echo "Packages copied to: $PKGS_DEST/"
    ls -la "$PKGS_DEST/"*.pkg.tar.zst 2>/dev/null || true
    echo ""
    echo "On the FydeTab, install with:"
    echo "  sudo pacman -U ~/pkgs/*.pkg.tar.zst"
else
    echo -e "${RED}No packages found to copy${NC}"
    echo ""
    echo "Build waydroid packages first:"
    echo "  cd pkgbuilds/waydroid-panthor-images && makepkg -s"
    echo "  cd pkgbuilds/waydroid-panthor-config && makepkg -s"
    exit 1
fi

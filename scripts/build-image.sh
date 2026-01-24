#!/bin/bash
# Build FydeTab bootable image using local packages

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
IMAGES_DIR="$ROOT_DIR/images"
PKGBUILDS_DIR="$ROOT_DIR/pkgbuilds"
LOCAL_PKGS_DIR="$IMAGES_DIR/fydetab-arch/local-pkgs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if images submodule is initialized
if [ ! -d "$IMAGES_DIR/fydetab-arch" ]; then
    log_error "images submodule not initialized"
    log_info "Run: git submodule update --init --recursive"
    exit 1
fi

# Create local packages directory
mkdir -p "$LOCAL_PKGS_DIR"

# Copy built packages to local cache
copy_local_packages() {
    log_info "Copying built packages to local cache..."

    # Kernel packages
    if ls "$PKGBUILDS_DIR/linux-fydetab/"*.pkg.tar.zst 1>/dev/null 2>&1; then
        cp -v "$PKGBUILDS_DIR/linux-fydetab/"*.pkg.tar.zst "$LOCAL_PKGS_DIR/"
    else
        log_warn "No kernel packages found. Run build-packages.sh first?"
    fi

    # Other packages (if built locally)
    for pkg_dir in mutter fydetabduo-post-install; do
        if ls "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar.zst 1>/dev/null 2>&1; then
            cp -v "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar.zst "$LOCAL_PKGS_DIR/"
        fi
    done

    # Create package database for local repo
    log_info "Creating local package database..."
    cd "$LOCAL_PKGS_DIR"
    repo-add -n local.db.tar.gz *.pkg.tar.zst 2>/dev/null || true
}

# Update pacman.conf with correct local repo path
update_pacman_conf() {
    local pacman_conf="$IMAGES_DIR/fydetab-arch/pacman.conf.aarch64"
    local abs_local_dir="$(cd "$LOCAL_PKGS_DIR" && pwd)"

    if grep -q "__LOCAL_PKGS_DIR__" "$pacman_conf"; then
        log_info "Updating local repo path in pacman.conf..."
        sed -i "s|__LOCAL_PKGS_DIR__|$abs_local_dir|" "$pacman_conf"
        log_info "Local repo path set to: $abs_local_dir"
    elif grep -q "\[fydetab-local\]" "$pacman_conf"; then
        log_info "Updating local repo path in pacman.conf..."
        sed -i "s|Server = file://.*local-pkgs|Server = file://$abs_local_dir|" "$pacman_conf"
        log_info "Local repo path updated to: $abs_local_dir"
    else
        log_warn "[fydetab-local] section not found in pacman.conf"
    fi
}

# Build the image
build_image() {
    log_info "Building FydeTab image..."
    cd "$IMAGES_DIR"

    # ImageForge needs root for loop devices and chroot
    if [ "$EUID" -ne 0 ]; then
        log_info "ImageForge requires root. Running with sudo..."
        sudo ./fydetab-arch/profiledef -c fydetab-arch -w ./work -o ./out
    else
        ./fydetab-arch/profiledef -c fydetab-arch -w ./work -o ./out
    fi

    log_info "Image build complete!"
    log_info "Output directory: $IMAGES_DIR/out/"
    ls -lh "$IMAGES_DIR/out/"
}

# Main
log_info "Starting image build..."
log_info "Root directory: $ROOT_DIR"
log_info "Images directory: $IMAGES_DIR"

# Copy packages and update config
copy_local_packages
update_pacman_conf

# Build
build_image

log_info "Done! Flash the image to SD card with:"
echo "  sudo dd if=$IMAGES_DIR/out/ArchLinux-ARM-FydeTab-Duo-*.img.xz of=/dev/sdX bs=4M status=progress"
echo "  # Or use: xzcat ... | sudo dd of=/dev/sdX bs=4M status=progress"

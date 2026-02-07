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

# Parse arguments
CLEAN_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        clean)
            CLEAN_BUILD=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [clean]"
            exit 1
            ;;
    esac
done

# Check if images submodule is initialized
if [ ! -d "$IMAGES_DIR/fydetab-arch" ]; then
    log_error "images submodule not initialized"
    log_info "Run: git submodule update --init --recursive"
    exit 1
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    log_info "Clean build requested, removing local-pkgs, work, and out..."
    rm -rf "$LOCAL_PKGS_DIR"
    # work/ and out/ contain root-owned files from ImageForge chroot
    sudo rm -rf "$IMAGES_DIR/work" "$IMAGES_DIR/out"
fi

# Create local packages directory
mkdir -p "$LOCAL_PKGS_DIR"

# Copy built packages to local cache
copy_local_packages() {
    log_info "Copying built packages to local cache..."

    # Kernel packages
    if ls "$PKGBUILDS_DIR/linux-fydetab-itztweak/"*.pkg.tar.zst 1>/dev/null 2>&1; then
        cp -v "$PKGBUILDS_DIR/linux-fydetab-itztweak/"*.pkg.tar.zst "$LOCAL_PKGS_DIR/"
    else
        log_warn "No kernel packages found. Run build-packages.sh first?"
    fi

    # Other packages (if built locally) - check both .zst and uncompressed .tar
    for pkg_dir in paru-bin waydroid-panthor-config waydroid-panthor-images mutter fydetabduo-post-install; do
        if ls "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar.zst 1>/dev/null 2>&1; then
            cp -v "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar.zst "$LOCAL_PKGS_DIR/"
        elif ls "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar 1>/dev/null 2>&1; then
            cp -v "$PKGBUILDS_DIR/$pkg_dir/"*.pkg.tar "$LOCAL_PKGS_DIR/"
        fi
    done

    # AUR cache packages (pre-built AUR packages not in standard repos)
    if [ -d "$PKGBUILDS_DIR/aur-cache" ]; then
        for pkg_dir in "$PKGBUILDS_DIR/aur-cache"/*/; do
            if ls "$pkg_dir"*.pkg.tar.zst 1>/dev/null 2>&1; then
                cp -v "$pkg_dir"*.pkg.tar.zst "$LOCAL_PKGS_DIR/"
            elif ls "$pkg_dir"*.pkg.tar 1>/dev/null 2>&1; then
                cp -v "$pkg_dir"*.pkg.tar "$LOCAL_PKGS_DIR/"
            fi
        done
    fi

    # Rebuild package database from scratch to avoid stale entries
    log_info "Rebuilding local package database..."
    cd "$LOCAL_PKGS_DIR"

    # Remove old database files to ensure clean state
    rm -f fydetab-local.db* fydetab-local.files*

    # Add all packages (handle case where one pattern doesn't match)
    local pkgs=()
    for pkg in *.pkg.tar.zst *.pkg.tar; do
        [ -f "$pkg" ] && pkgs+=("$pkg")
    done

    if [ ${#pkgs[@]} -gt 0 ]; then
        repo-add fydetab-local.db.tar.gz "${pkgs[@]}"
    else
        log_warn "No packages found in local-pkgs!"
    fi
}

# Update pacman.conf with correct local repo path (placeholder -> absolute path)
PACMAN_CONF="$IMAGES_DIR/fydetab-arch/pacman.conf.aarch64"

update_pacman_conf() {
    local abs_local_dir="$(cd "$LOCAL_PKGS_DIR" && pwd)"

    if grep -q "__LOCAL_PKGS_DIR__" "$PACMAN_CONF"; then
        log_info "Setting local repo path in pacman.conf to: $abs_local_dir"
        sed -i "s|__LOCAL_PKGS_DIR__|$abs_local_dir|" "$PACMAN_CONF"
    else
        log_warn "__LOCAL_PKGS_DIR__ placeholder not found in pacman.conf"
    fi
}

# Restore placeholder so the tracked file stays clean
restore_pacman_conf() {
    local abs_local_dir="$(cd "$LOCAL_PKGS_DIR" && pwd)"
    sed -i "s|$abs_local_dir|__LOCAL_PKGS_DIR__|" "$PACMAN_CONF"
    log_info "Restored __LOCAL_PKGS_DIR__ placeholder in pacman.conf"
}

trap restore_pacman_conf EXIT

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

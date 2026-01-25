#!/bin/bash
# Build all FydeTab packages in dependency order

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PKGBUILDS_DIR="$ROOT_DIR/pkgbuilds"

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

# Check if pkgbuilds submodule is initialized
if [ ! -d "$PKGBUILDS_DIR/linux-fydetab-itztweak" ]; then
    log_error "pkgbuilds submodule not initialized"
    log_info "Run: git submodule update --init --recursive"
    exit 1
fi

# Parse arguments
CLEAN_BUILD=false
KERNEL_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        clean)
            CLEAN_BUILD=true
            shift
            ;;
        kernel-only)
            KERNEL_ONLY=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [clean] [kernel-only]"
            exit 1
            ;;
    esac
done

# Build the kernel (most important, takes longest)
build_kernel() {
    log_info "Building linux-fydetab-itztweak kernel..."
    cd "$PKGBUILDS_DIR/linux-fydetab-itztweak"

    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Clean build requested, removing src/ and pkg/"
        ./build.sh clean
    else
        ./build.sh
    fi

    # Check for built packages
    if ls linux-fydetab-itztweak-*.pkg.tar.zst 1>/dev/null 2>&1; then
        log_info "Kernel packages built successfully:"
        ls -la linux-fydetab-itztweak-*.pkg.tar.zst
    else
        log_error "Kernel build failed - no packages found"
        exit 1
    fi
}

# Build other packages (optional, only if needed)
build_package() {
    local pkg_name="$1"
    local pkg_dir="$PKGBUILDS_DIR/$pkg_name"

    if [ ! -d "$pkg_dir" ]; then
        log_warn "Package directory not found: $pkg_dir"
        return 1
    fi

    log_info "Building $pkg_name..."
    cd "$pkg_dir"

    if [ "$CLEAN_BUILD" = true ]; then
        rm -rf src pkg
    fi

    makepkg -sf --noconfirm

    if ls *.pkg.tar.zst 1>/dev/null 2>&1; then
        log_info "$pkg_name built successfully"
    else
        log_warn "$pkg_name build may have failed"
    fi
}

# Main build sequence
log_info "Starting package build..."
log_info "Root directory: $ROOT_DIR"
log_info "PKGBUILDs directory: $PKGBUILDS_DIR"

# Always build kernel
build_kernel

if [ "$KERNEL_ONLY" = false ]; then
    # Build waydroid-panthor-images (Android system/vendor images)
    build_package "waydroid-panthor-images"

    # Build waydroid-panthor-config (binder services, init scripts)
    build_package "waydroid-panthor-config"

    # Uncomment to build additional packages:
    # build_package "mutter"
    # build_package "fydetabduo-post-install"
fi

log_info "Package build complete!"
echo ""
log_info "Built packages:"
find "$PKGBUILDS_DIR" -name "*.pkg.tar.zst" -mmin -60 -exec ls -lh {} \;

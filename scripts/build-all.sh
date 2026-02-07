#!/bin/bash
# Full build pipeline: packages -> image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_step() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
CLEAN_BUILD=false
SKIP_KERNEL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        clean)
            CLEAN_BUILD=true
            shift
            ;;
        skip-kernel)
            SKIP_KERNEL=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [clean] [skip-kernel]"
            echo ""
            echo "Options:"
            echo "  clean        Clean build (removes src/pkg directories)"
            echo "  skip-kernel  Skip kernel build (uses existing kernel packages)"
            echo ""
            echo "This script builds:"
            echo "  1. Kernel packages (linux-fydetab-itztweak)"
            echo "  2. Bootable image with local packages"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Track timing
START_TIME=$(date +%s)

# Step 1: Build packages
log_step "Step 1: Building Packages"

BUILD_PKG_ARGS=""
[ "$CLEAN_BUILD" = true ] && BUILD_PKG_ARGS="$BUILD_PKG_ARGS clean"
[ "$SKIP_KERNEL" = true ] && BUILD_PKG_ARGS="$BUILD_PKG_ARGS skip-kernel"

"$SCRIPT_DIR/build-packages.sh" $BUILD_PKG_ARGS

# Step 2: Build image
log_step "Step 2: Building Image"

if [ "$CLEAN_BUILD" = true ]; then
    "$SCRIPT_DIR/build-image.sh" clean
else
    "$SCRIPT_DIR/build-image.sh"
fi

# Done
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

log_step "Build Complete!"

log_info "Total build time: ${MINUTES}m ${SECONDS}s"
log_info ""
log_info "Next steps:"
log_info "  1. Flash image to SD card"
log_info "  2. Boot FydeTab from SD"
log_info "  3. Test GPU, WiFi, touch"
log_info "  4. If working, install to eMMC"

#!/bin/bash
# copy-test-scripts.sh - Copy test scripts to SD card after flashing
# This copies the test framework to the SD card for on-device testing

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# SD card mount point
SD_MOUNT="${SD_MOUNT:-/run/media/${USER}/ROOTFS}"
SD_HOME="${SD_MOUNT}/@home/arch"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Copy Test Scripts to SD Card ==="

# Check SD card is mounted
if [ ! -d "$SD_MOUNT" ]; then
    echo -e "${RED}ERROR: SD card not mounted at $SD_MOUNT${NC}"
    echo "Mount the SD card first, or set SD_MOUNT environment variable"
    exit 1
fi

# Check for btrfs subvolume structure
if [ ! -d "$SD_HOME" ]; then
    # Maybe it's not a btrfs layout, try direct path
    if [ -d "${SD_MOUNT}/home/arch" ]; then
        SD_HOME="${SD_MOUNT}/home/arch"
        echo -e "${YELLOW}Using non-btrfs layout: $SD_HOME${NC}"
    else
        echo -e "${RED}ERROR: Cannot find home directory at $SD_HOME${NC}"
        echo "Expected btrfs layout with @home subvolume"
        exit 1
    fi
fi

echo "SD home directory: $SD_HOME"

# Create directories
TESTS_DEST="$SD_HOME/tests"
echo "Creating test directories..."
sudo mkdir -p "$TESTS_DEST"

# Copy test scripts
echo "Copying test scripts..."
sudo cp -rv "$SCRIPT_DIR/tests/"* "$TESTS_DEST/"

# Ensure scripts are executable
sudo find "$TESTS_DEST" -name "*.sh" -exec chmod +x {} +

# Create results directory
RESULTS_DEST="$SD_HOME/test-results"
sudo mkdir -p "$RESULTS_DEST"

# Set ownership to arch user (uid 1001)
echo "Setting ownership..."
sudo chown -R 1001:1001 "$TESTS_DEST"
sudo chown -R 1001:1001 "$RESULTS_DEST"

# Create symlink for convenience
if [ ! -e "$SD_HOME/run-tests" ]; then
    sudo ln -sf tests/run-all-tests.sh "$SD_HOME/run-tests"
    sudo chown -h 1001:1001 "$SD_HOME/run-tests"
fi

echo ""
echo -e "${GREEN}Test scripts copied successfully!${NC}"
echo ""
echo "On the FydeTab:"
echo "  ~/tests/          - Test scripts"
echo "  ~/test-results/   - Results directory"
echo "  ~/run-tests       - Quick symlink to run all tests"
echo ""
echo "To run tests on the FydeTab:"
echo "  1. Boot from SD card"
echo "  2. Open GNOME Terminal (for Wayland tests)"
echo "  3. Run: ~/tests/run-all-tests.sh"
echo "  4. Or click 'FydeTab Tests' in app menu"

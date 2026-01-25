#!/bin/bash
# get-sd-results.sh - Retrieve test results from SD card
# Run this after booting back to eMMC to get test results from SD card

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# SD card mount point
SD_MOUNT="${SD_MOUNT:-/run/media/${USER}/ROOTFS}"
SD_HOME="${SD_MOUNT}/@home/arch"
SD_RESULTS="$SD_HOME/test-results"

# Local destination
LOCAL_RESULTS="${LOCAL_RESULTS:-$REPO_DIR/test-results}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "=== Retrieve Test Results from SD Card ==="

# Check SD card is mounted
if [ ! -d "$SD_MOUNT" ]; then
    echo -e "${RED}ERROR: SD card not mounted at $SD_MOUNT${NC}"
    echo ""
    echo "Insert the SD card and mount it, or set SD_MOUNT:"
    echo "  export SD_MOUNT=/path/to/mount"
    exit 1
fi

# Check for btrfs subvolume structure
if [ ! -d "$SD_HOME" ]; then
    if [ -d "${SD_MOUNT}/home/arch" ]; then
        SD_HOME="${SD_MOUNT}/home/arch"
        SD_RESULTS="$SD_HOME/test-results"
    fi
fi

# Check for results
if [ ! -d "$SD_RESULTS" ]; then
    echo -e "${RED}ERROR: No test-results directory found at $SD_RESULTS${NC}"
    echo ""
    echo "Tests may not have been run on the SD card yet."
    echo "Expected location: $SD_RESULTS"
    exit 1
fi

# List available results
echo "Found test results on SD card:"
echo ""
ls -la "$SD_RESULTS/"
echo ""

# Find the most recent result
LATEST=$(ls -1t "$SD_RESULTS" 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
    echo -e "${YELLOW}No result directories found${NC}"
    exit 1
fi

echo -e "Most recent: ${CYAN}$LATEST${NC}"
echo ""

# Ask which to retrieve
read -r -p "Retrieve all results or just latest? [all/LATEST] " choice
choice="${choice:-latest}"

# Create local destination
mkdir -p "$LOCAL_RESULTS"

if [[ "$choice" == "all" ]]; then
    echo "Copying all results..."
    cp -rv "$SD_RESULTS/"* "$LOCAL_RESULTS/"
else
    echo "Copying latest results..."
    cp -rv "$SD_RESULTS/$LATEST" "$LOCAL_RESULTS/"
fi

echo ""
echo -e "${GREEN}Results copied to: $LOCAL_RESULTS/${NC}"
echo ""

# Show summary if available
SUMMARY="$LOCAL_RESULTS/$LATEST/test-summary.txt"
if [ -f "$SUMMARY" ]; then
    echo "=== Test Summary ==="
    cat "$SUMMARY"
    echo ""
fi

# Show manifest
MANIFEST="$LOCAL_RESULTS/$LATEST/test-manifest.txt"
if [ -f "$MANIFEST" ]; then
    echo "=== Test Manifest ==="
    cat "$MANIFEST"
    echo ""
fi

echo ""
echo "To analyze results, examine files in:"
echo "  $LOCAL_RESULTS/$LATEST/"
echo ""
echo "Key files:"
echo "  test-summary.txt    - Overall summary"
echo "  test-manifest.txt   - Individual test results"
echo "  system-info.txt     - System information"
echo "  <test-name>/        - Detailed output per test"

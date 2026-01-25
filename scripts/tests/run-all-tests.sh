#!/bin/bash
# run-all-tests.sh - Master test runner for FydeTab Duo
# Runs all hardware and system tests, with auto-install for optional packages

set -e

# Configuration
TESTS_DIR="${TESTS_DIR:-$(dirname "$(readlink -f "$0")")}"
RESULTS_BASE="${RESULTS_BASE:-${HOME}/test-results}"
PKGS_DIR="${PKGS_DIR:-${HOME}/pkgs}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="${RESULTS_BASE}/${TIMESTAMP}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${CYAN}[TEST]${NC} $*"; }

# Test manifest tracking
MANIFEST="${RESULTS_DIR}/test-manifest.txt"
SUMMARY="${RESULTS_DIR}/test-summary.txt"

log_manifest() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2" >> "$MANIFEST"
}

# Package checking helpers
is_installed() {
    pacman -Q "$1" &>/dev/null
}

ensure_installed() {
    local pkg_name="$1"
    local pkg_pattern="${2:-$1}"

    # Already installed (by ImageForge or previous run)
    if is_installed "$pkg_name"; then
        return 0
    fi

    # Try to install from pkgs directory
    if [ -d "$PKGS_DIR" ]; then
        local pkg_file
        pkg_file=$(ls "$PKGS_DIR/${pkg_pattern}"*.pkg.tar.zst 2>/dev/null | head -1)
        if [ -n "$pkg_file" ]; then
            log_info "Installing $pkg_name from local package..."
            sudo pacman -U --noconfirm "$pkg_file" && return 0
        fi
    fi

    return 1
}

# Run a single test and capture results
# Exit code convention: 0=PASS, 1=FAIL, 2=SKIP
run_test() {
    local test_script="$1"
    local test_name
    test_name=$(basename "$test_script" .sh)
    local test_output="${RESULTS_DIR}/${test_name}"

    if [ ! -x "$test_script" ]; then
        log_warn "Test script not executable: $test_script"
        log_manifest "$test_name" "SKIPPED (not executable)"
        return 1
    fi

    log_step "Running $test_name..."
    mkdir -p "$test_output"

    local exit_code=0
    "$test_script" "$test_output" > >(tee "${test_output}/output.log") 2>&1 || exit_code=$?

    case $exit_code in
        0)
            log_info "$test_name: PASSED"
            log_manifest "$test_name" "PASSED"
            ;;
        2)
            log_warn "$test_name: SKIPPED"
            log_manifest "$test_name" "SKIPPED"
            ;;
        *)
            log_error "$test_name: FAILED (exit $exit_code)"
            log_manifest "$test_name" "FAILED (exit $exit_code)"
            ;;
    esac

    return $exit_code
}

# Generate summary
generate_summary() {
    echo "=== FydeTab Test Summary ===" > "$SUMMARY"
    echo "Date: $(date)" >> "$SUMMARY"
    echo "Hostname: $(hostnamectl hostname 2>/dev/null || echo 'unknown')" >> "$SUMMARY"
    echo "Kernel: $(uname -r)" >> "$SUMMARY"
    echo "" >> "$SUMMARY"

    local passed=0 failed=0 skipped=0
    while IFS= read -r line; do
        if [[ "$line" == *"PASSED"* ]]; then
            ((passed++))
        elif [[ "$line" == *"FAILED"* ]]; then
            ((failed++))
        elif [[ "$line" == *"SKIPPED"* ]]; then
            ((skipped++))
        fi
    done < "$MANIFEST"

    echo "Results: $passed passed, $failed failed, $skipped skipped" >> "$SUMMARY"
    echo "" >> "$SUMMARY"
    echo "=== Test Details ===" >> "$SUMMARY"
    cat "$MANIFEST" >> "$SUMMARY"

    cat "$SUMMARY"
}

# Main
main() {
    echo -e "${BOLD}=== FydeTab Duo Test Suite ===${NC}"
    echo "Timestamp: $TIMESTAMP"
    echo ""

    # Create results directory
    mkdir -p "$RESULTS_DIR"
    echo "FydeTab Test Run" > "$MANIFEST"
    echo "Started: $(date)" >> "$MANIFEST"
    echo "---" >> "$MANIFEST"

    # Collect system info
    log_step "Collecting system information..."
    {
        echo "=== System Information ==="
        echo "Date: $(date)"
        echo "Hostname: $(hostnamectl hostname 2>/dev/null || echo 'unknown')"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo ""
        echo "=== Boot Media ==="
        BOOT_DEV=""
        if grep -q "/dev/mmcblk1" /proc/cmdline 2>/dev/null; then
            BOOT_DEV="/dev/mmcblk1"
        elif grep -q "/dev/mmcblk0" /proc/cmdline 2>/dev/null; then
            BOOT_DEV="/dev/mmcblk0"
        elif grep -oP 'root=UUID=\K[^ ]+' /proc/cmdline &>/dev/null; then
            ROOT_UUID=$(grep -oP 'root=UUID=\K[^ ]+' /proc/cmdline)
            if [ -L "/dev/disk/by-uuid/${ROOT_UUID}" ]; then
                BOOT_DEV=$(readlink -f "/dev/disk/by-uuid/${ROOT_UUID}")
            fi
        fi
        if [ -z "$BOOT_DEV" ]; then
            BOOT_DEV=$(findmnt -n -o SOURCE / 2>/dev/null || echo "")
        fi
        case "$BOOT_DEV" in
            *mmcblk1*) echo "Booted from: SD Card ($BOOT_DEV)" ;;
            *mmcblk0*) echo "Booted from: eMMC ($BOOT_DEV)" ;;
            "")        echo "Boot device: Unknown"; cat /proc/cmdline ;;
            *)         echo "Boot device: $BOOT_DEV"; cat /proc/cmdline ;;
        esac
        echo ""
        echo "=== Block Devices ==="
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
    } > "${RESULTS_DIR}/system-info.txt"

    # GPU test (mesa installed by ImageForge)
    if is_installed "mesa"; then
        run_test "${TESTS_DIR}/test-gpu.sh" || true
    else
        log_warn "Skipping GPU test - mesa not installed"
        log_manifest "test-gpu" "SKIPPED (mesa not installed)"
    fi

    # Display test
    run_test "${TESTS_DIR}/test-display.sh" || true

    # Touch test
    run_test "${TESTS_DIR}/test-touch.sh" || true

    # WiFi test
    run_test "${TESTS_DIR}/test-wifi.sh" || true

    # Bluetooth test
    if is_installed "bluez"; then
        run_test "${TESTS_DIR}/test-bluetooth.sh" || true
    else
        log_warn "Skipping Bluetooth test - bluez not installed"
        log_manifest "test-bluetooth" "SKIPPED (bluez not installed)"
    fi

    # Audio test
    run_test "${TESTS_DIR}/test-audio.sh" || true

    # USB-C test
    run_test "${TESTS_DIR}/test-usbc.sh" || true

    # Battery test
    run_test "${TESTS_DIR}/test-battery.sh" || true

    # Waydroid test (may need install from pkgs/)
    if ensure_installed "waydroid-panthor-config"; then
        run_test "${TESTS_DIR}/test-waydroid.sh" || true
    elif is_installed "waydroid" && is_installed "waydroid-panthor-images"; then
        # Old combined package
        run_test "${TESTS_DIR}/test-waydroid.sh" || true
    else
        log_warn "Skipping Waydroid test - packages not available"
        log_manifest "test-waydroid" "SKIPPED (waydroid packages not available)"
    fi

    # System health test
    run_test "${TESTS_DIR}/test-system.sh" || true

    # VSCodium test (automated — skips itself if not in Wayland or not installed)
    run_test "${TESTS_DIR}/test-vscodium.sh" || true

    echo "---" >> "$MANIFEST"
    echo "Completed: $(date)" >> "$MANIFEST"

    echo ""
    generate_summary

    echo ""
    echo -e "${BOLD}Results saved to: ${RESULTS_DIR}${NC}"
    echo ""
    echo "To analyze results on your development machine:"
    echo "  ./scripts/get-sd-results.sh"
}

main "$@"

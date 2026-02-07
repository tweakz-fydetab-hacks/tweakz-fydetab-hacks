#!/bin/bash
# test-waydroid-ui.sh - Interactive Waydroid UI test for FydeTab Duo
# Must be run as regular user (not root) from GNOME Terminal or similar Wayland session
# This test launches the Android UI - use test-waydroid.sh for headless diagnostics

set -e

OUTPUT_DIR="${1:-.}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${OUTPUT_DIR}/waydroid-ui-${TIMESTAMP}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; }
step() { echo -e "${CYAN}[STEP]${NC} $*" | tee -a "$LOG_FILE"; }

echo "=== Waydroid UI Test ===" | tee "$LOG_FILE"

# Pre-flight checks
preflight() {
    local failed=0

    echo "Time: $(date)" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    # Check not root
    if [[ $EUID -eq 0 ]]; then
        error "Do not run as root. Run as regular user from GNOME Terminal."
        exit 1
    fi

    # Check Wayland session
    step "Checking display session..."
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        info "Wayland session: YES"
    elif [[ -n "$WAYLAND_DISPLAY" ]]; then
        info "Wayland display: $WAYLAND_DISPLAY"
    else
        error "Not running in Wayland session (XDG_SESSION_TYPE=$XDG_SESSION_TYPE)"
        error "Run this from GNOME Terminal, not SSH or console"
        failed=1
    fi

    # Check DBus session
    step "Checking DBus session..."
    if [[ -n "$DBUS_SESSION_BUS_ADDRESS" ]]; then
        info "DBus session: $DBUS_SESSION_BUS_ADDRESS"
    else
        error "DBUS_SESSION_BUS_ADDRESS not set"
        failed=1
    fi

    # Check binder devices
    step "Checking binder devices..."
    if [[ -d /dev/binderfs ]] && ls /dev/binderfs/* &>/dev/null; then
        info "Binderfs: mounted with devices"
        ls -la /dev/binderfs/ | tee -a "$LOG_FILE"
    elif [[ -e /dev/binder ]]; then
        info "Binder device: /dev/binder exists"
    else
        warn "No binder devices found - waydroid may fail"
        warn "Check if dev-binderfs.mount and waydroid-binder-setup.service are running"
    fi

    # Check waydroid installed
    step "Checking waydroid..."
    if command -v waydroid &>/dev/null; then
        info "Waydroid: installed"
    else
        error "Waydroid not installed"
        failed=1
    fi

    # Check waydroid initialized
    if [[ -f /var/lib/waydroid/waydroid.cfg ]]; then
        info "Waydroid: initialized"
    else
        warn "Waydroid not initialized - will run 'waydroid init' first"
    fi

    # Check GPU
    step "Checking GPU..."
    if dmesg 2>/dev/null | grep -qi panthor; then
        info "GPU: Panthor driver loaded"
    elif dmesg 2>/dev/null | grep -qi panfrost; then
        warn "GPU: Panfrost driver (may not work well with Mali G610)"
    else
        warn "GPU: Could not detect GPU driver from dmesg"
    fi

    echo "" | tee -a "$LOG_FILE"
    if [[ $failed -eq 1 ]]; then
        error "Preflight checks failed. Fix issues above and retry."
        exit 1
    fi
    info "Preflight checks passed!"
}

# Initialize waydroid if needed
init_waydroid() {
    if [[ ! -f /var/lib/waydroid/waydroid.cfg ]]; then
        step "Initializing Waydroid (first time setup)..."
        # Use pre-installed Panthor images instead of downloading stock ones
        sudo waydroid init -i /var/lib/waydroid/images -s VANILLA 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Start container service
start_container() {
    step "Starting waydroid-container.service..."
    sudo systemctl start waydroid-container.service 2>&1 | tee -a "$LOG_FILE"
    sleep 2
    systemctl status waydroid-container.service --no-pager 2>&1 | tee -a "$LOG_FILE" || true
}

# Start UI and capture logs
start_ui() {
    step "Starting Waydroid UI..."
    info "A window should appear. Close it or press Ctrl+C when done testing."
    echo "" | tee -a "$LOG_FILE"

    # Start waydroid UI in foreground
    waydroid show-full-ui 2>&1 | tee -a "$LOG_FILE" &
    UI_PID=$!

    # Give it time to start
    sleep 5

    # Capture logcat in background
    step "Capturing Android logcat..."
    timeout 30 waydroid logcat >> "${OUTPUT_DIR}/logcat-${TIMESTAMP}.txt" 2>&1 &

    # Wait for UI process
    wait $UI_PID 2>/dev/null || true
}

# Cleanup and summary
cleanup() {
    step "Stopping Waydroid..."
    waydroid session stop 2>&1 | tee -a "$LOG_FILE" || true

    echo "" | tee -a "$LOG_FILE"
    info "Test complete. Logs saved to: $OUTPUT_DIR"
    echo "Files:" | tee -a "$LOG_FILE"
    ls -la "$OUTPUT_DIR"/*${TIMESTAMP}* 2>/dev/null | tee -a "$LOG_FILE" || true
}

# Main
main() {
    mkdir -p "$OUTPUT_DIR"

    trap cleanup EXIT

    preflight
    init_waydroid
    start_container
    start_ui
}

# Run
main "$@"

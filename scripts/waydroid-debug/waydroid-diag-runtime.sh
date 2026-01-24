#!/bin/bash
# waydroid-diag-runtime.sh - Capture Waydroid runtime/startup logs
# Run as: sudo ./waydroid-diag-runtime.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
step() { echo -e "${CYAN}[STEP]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

mkdir -p "$LOG_DIR"

info "Runtime diagnostic capture starting..."
info "Logs will be saved to: $LOG_DIR"
echo

# Stop any existing waydroid
step "Stopping any existing Waydroid sessions..."
waydroid session stop 2>/dev/null || true
systemctl stop waydroid-container.service 2>/dev/null || true
sleep 2

# Pre-start state
step "Capturing pre-start state..."
{
    echo "=== Pre-start dmesg tail ==="
    dmesg | tail -50
    echo
    echo "=== Pre-start processes ==="
    ps aux | grep -E "(waydroid|lxc|android)" | grep -v grep || echo "No waydroid processes"
} > "$LOG_DIR/01-pre-start.txt"

# Start container service
step "Starting waydroid-container.service..."
{
    echo "=== Starting container service ==="
    echo "Time: $(date)"
    systemctl start waydroid-container.service 2>&1
    echo "Exit code: $?"
    echo
    echo "=== Service status after start ==="
    systemctl status waydroid-container.service 2>&1 || true
} > "$LOG_DIR/02-container-start.txt"

sleep 3

# Start UI with verbose logging
step "Starting Waydroid UI (verbose mode, 30s timeout)..."
info "Watch for the black window / flashing behavior..."

# Run waydroid in background, capture output
{
    echo "=== Waydroid UI Start Attempt ==="
    echo "Time: $(date)"
    echo "Running: waydroid -v show-full-ui"
    echo
    # Use timeout to prevent hanging
    timeout 30 waydroid -v show-full-ui 2>&1 || echo "Exit/timeout code: $?"
} > "$LOG_DIR/02-ui-start.txt" 2>&1 &
WAYDROID_PID=$!

# Wait a bit then start capturing logs
sleep 5

step "Capturing logcat (Android logs)..."
{
    echo "=== Waydroid logcat ==="
    echo "Time: $(date)"
    echo
    timeout 20 waydroid logcat 2>&1 || echo "Logcat timeout/exit"
} > "$LOG_DIR/03-logcat.txt" &
LOGCAT_PID=$!

step "Capturing waydroid log..."
{
    echo "=== Waydroid log ==="
    echo "Time: $(date)"
    echo
    timeout 20 waydroid log 2>&1 || echo "Log timeout/exit"
} > "$LOG_DIR/04-waydroid-log.txt" &
LOG_PID=$!

# Wait for processes
info "Waiting for log capture (up to 25 seconds)..."
wait $LOGCAT_PID 2>/dev/null || true
wait $LOG_PID 2>/dev/null || true
wait $WAYDROID_PID 2>/dev/null || true

# Post-attempt capture
step "Capturing post-attempt state..."
{
    echo "=== Post-attempt dmesg (last 100 lines) ==="
    dmesg | tail -100
    echo
    echo "=== Waydroid processes ==="
    ps aux | grep -E "(waydroid|lxc|android)" | grep -v grep || echo "No waydroid processes"
    echo
    echo "=== Container status ==="
    systemctl status waydroid-container.service 2>&1 || true
} > "$LOG_DIR/05-post-attempt.txt"

# Journal logs during this session
step "Capturing journal logs from this session..."
{
    echo "=== Journal since script start ==="
    journalctl --since "-2min" --no-pager 2>&1
} > "$LOG_DIR/06-journal-recent.txt"

# LXC container status
step "Checking LXC container status..."
{
    echo "=== LXC list ==="
    lxc-ls -f 2>&1 || echo "lxc-ls failed"
    echo
    echo "=== LXC info waydroid ==="
    lxc-info -n waydroid 2>&1 || echo "Container info not available"
} > "$LOG_DIR/07-lxc-status.txt"

# Stop waydroid
step "Stopping Waydroid..."
waydroid session stop 2>/dev/null || true
systemctl stop waydroid-container.service 2>/dev/null || true

info "Runtime capture complete!"
echo
echo "=== Files created ==="
ls -la "$LOG_DIR"/*.txt 2>/dev/null | tail -20
echo
echo "=== Quick analysis ==="

# Check for common issues
echo -n "Container started: "
if grep -q "Started Waydroid Container" "$LOG_DIR/02-container-start.txt" 2>/dev/null; then
    echo -e "${GREEN}YES${NC}"
else
    echo -e "${RED}NO or FAILED${NC}"
fi

echo -n "Logcat captured: "
if [[ -s "$LOG_DIR/03-logcat.txt" ]] && ! grep -q "timeout" "$LOG_DIR/03-logcat.txt"; then
    echo -e "${GREEN}YES${NC}"

    # Check for specific errors in logcat
    echo -n "Graphics errors: "
    if grep -qiE "(gralloc|egl|opengl|surfaceflinger).*error" "$LOG_DIR/03-logcat.txt"; then
        echo -e "${RED}FOUND${NC}"
        echo "  >> Check 03-logcat.txt for graphics-related errors"
    else
        echo -e "${GREEN}None obvious${NC}"
    fi

    echo -n "Crash/Fatal: "
    if grep -qiE "(fatal|crash|died|killed)" "$LOG_DIR/03-logcat.txt"; then
        echo -e "${RED}FOUND${NC}"
        echo "  >> Check 03-logcat.txt for crash details"
    else
        echo -e "${GREEN}None obvious${NC}"
    fi
else
    echo -e "${YELLOW}EMPTY or FAILED${NC}"
fi

echo -n "Binder errors in dmesg: "
if grep -qi "binder.*error\|binder.*failed" "$LOG_DIR/05-post-attempt.txt" 2>/dev/null; then
    echo -e "${RED}YES${NC}"
else
    echo -e "${GREEN}NO${NC}"
fi

echo
echo "Review the logs in: $LOG_DIR"
echo "Key files to check:"
echo "  - 03-logcat.txt (Android system logs)"
echo "  - 04-waydroid-log.txt (Waydroid daemon logs)"
echo "  - 05-post-attempt.txt (dmesg after crash)"

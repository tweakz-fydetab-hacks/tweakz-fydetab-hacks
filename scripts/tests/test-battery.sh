#!/bin/bash
# test-battery.sh - Battery/charger sysfs verification for FydeTab Duo
# Verifies: sbs-battery sysfs, bq25700-charger, capacity, status

set -e

OUTPUT_DIR="${1:-.}"

echo "=== Battery Test ==="

# Find battery power supply
echo "Checking power supplies..."
{
    echo "=== Power Supplies ==="
    ls -la /sys/class/power_supply/ 2>&1 || echo "No power supplies"
    echo ""
    for ps in /sys/class/power_supply/*; do
        if [ -d "$ps" ]; then
            name=$(basename "$ps")
            type=$(cat "$ps/type" 2>/dev/null || echo "unknown")
            echo "$name (type: $type):"
            for attr in status capacity voltage_now current_now charge_now energy_now manufacturer model_name; do
                if [ -f "$ps/$attr" ]; then
                    val=$(cat "$ps/$attr" 2>/dev/null || echo "error")
                    echo "  $attr: $val"
                fi
            done
            echo ""
        fi
    done
} > "${OUTPUT_DIR}/power-supplies.txt"

cat "${OUTPUT_DIR}/power-supplies.txt"

# Check for battery
BATTERY=""
for ps in /sys/class/power_supply/*; do
    if [ -f "$ps/type" ] && grep -q "Battery" "$ps/type" 2>/dev/null; then
        BATTERY=$(basename "$ps")
        break
    fi
done

if [ -n "$BATTERY" ]; then
    echo "PASS: Battery detected: $BATTERY"
    BATTERY_PATH="/sys/class/power_supply/$BATTERY"
else
    echo "WARN: No battery power supply found"
    BATTERY_PATH=""
fi

# Check sbs-battery driver
echo "Checking sbs-battery driver..."
{
    echo "=== SBS Battery Driver ==="
    if lsmod | grep -q sbs_battery; then
        echo "sbs-battery module: loaded"
        lsmod | grep sbs
    else
        echo "sbs-battery module: not loaded (may be built-in)"
    fi
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "sbs|battery" | tail -30 || echo "No battery messages"
} > "${OUTPUT_DIR}/sbs-battery.txt"

# Check charger
echo "Checking charger..."
{
    echo "=== BQ25700 Charger ==="
    if lsmod | grep -q bq25700; then
        echo "bq25700 module: loaded"
        lsmod | grep bq
    else
        echo "bq25700 module: not loaded (may be built-in)"
    fi
    echo ""
    # Find charger power supply
    for ps in /sys/class/power_supply/*; do
        if [ -f "$ps/type" ]; then
            type=$(cat "$ps/type" 2>/dev/null)
            if [ "$type" = "Mains" ] || [ "$type" = "USB" ]; then
                name=$(basename "$ps")
                echo "Charger: $name (type: $type)"
                echo "  Online: $(cat "$ps/online" 2>/dev/null || echo 'unknown')"
                echo "  Status: $(cat "$ps/status" 2>/dev/null || echo 'unknown')"
            fi
        fi
    done
    echo ""
    echo "=== Kernel messages ==="
    dmesg 2>/dev/null | grep -iE "bq25\|charger" | tail -20 || echo "No charger messages"
} > "${OUTPUT_DIR}/charger.txt"

# Battery details
if [ -n "$BATTERY_PATH" ]; then
    echo "Checking battery details..."
    {
        echo "=== Battery Status ==="
        echo "Capacity: $(cat "$BATTERY_PATH/capacity" 2>/dev/null || echo 'unknown')%"
        echo "Status: $(cat "$BATTERY_PATH/status" 2>/dev/null || echo 'unknown')"
        echo "Health: $(cat "$BATTERY_PATH/health" 2>/dev/null || echo 'unknown')"
        echo ""
        echo "=== Battery Info ==="
        echo "Manufacturer: $(cat "$BATTERY_PATH/manufacturer" 2>/dev/null || echo 'unknown')"
        echo "Model: $(cat "$BATTERY_PATH/model_name" 2>/dev/null || echo 'unknown')"
        echo "Technology: $(cat "$BATTERY_PATH/technology" 2>/dev/null || echo 'unknown')"
        echo ""
        echo "=== Battery Measurements ==="
        voltage=$(cat "$BATTERY_PATH/voltage_now" 2>/dev/null || echo 0)
        current=$(cat "$BATTERY_PATH/current_now" 2>/dev/null || echo 0)
        echo "Voltage: $((voltage / 1000)) mV"
        echo "Current: $((current / 1000)) mA"
        if [ -f "$BATTERY_PATH/charge_now" ]; then
            charge=$(cat "$BATTERY_PATH/charge_now")
            charge_full=$(cat "$BATTERY_PATH/charge_full" 2>/dev/null || echo 0)
            echo "Charge: $((charge / 1000)) / $((charge_full / 1000)) mAh"
        fi
        if [ -f "$BATTERY_PATH/energy_now" ]; then
            energy=$(cat "$BATTERY_PATH/energy_now")
            energy_full=$(cat "$BATTERY_PATH/energy_full" 2>/dev/null || echo 0)
            echo "Energy: $((energy / 1000)) / $((energy_full / 1000)) mWh"
        fi
    } > "${OUTPUT_DIR}/battery-details.txt"

    cat "${OUTPUT_DIR}/battery-details.txt"
fi

echo ""
echo "Battery test completed"
exit 0

# Battery Management

Documentation and future enhancements for battery charge control on the FydeTab Duo.

## Current Status

The FydeTab Duo uses:
- **Battery**: Smart Battery System (SBS) at `/sys/class/power_supply/sbs-5-000b/`
- **Charger**: TI BQ25700 (or compatible SC8886) at `/sys/class/power_supply/bq25700-charger/`
- **USB-C Controller**: TCPM at `/sys/class/power_supply/tcpm-source-psy-6-004e/`

### Hardware Charge Control Limitations

As of kernel 6.1.x, the FydeTab Duo does **not** expose software-controllable charge limiting:

| Control Method | Status | Notes |
|----------------|--------|-------|
| `charge_control_end_threshold` | Not available | Standard Linux interface, not implemented in driver |
| USB-C `power_role` switching | Operation not supported | Kernel rejects writes to sysfs |
| Charger sysfs attributes | Read-only | No writable charge control files |
| Direct I2C access | Blocked | Kernel driver holds the bus |

## Future Enhancements

### 1. Kernel Driver Patch for BQ25700

The BQ25700 charger chip supports charge inhibit via I2C register control. A kernel patch could expose this through the standard `charge_control_end_threshold` sysfs interface.

**Technical Details:**
- Charger I2C address: `0x6b` on bus `i2c-6`
- ChargeOption0 register: `0x12` (16-bit word)
- Bit 0 (`CHRG_INHIBIT`): Setting to `1` disables charging

**Implementation approach:**
1. Add `charge_control_end_threshold` and `charge_control_start_threshold` sysfs attributes to `drivers/power/supply/bq25700_charger.c`
2. Store threshold values and monitor battery percentage via the power supply subsystem
3. When battery reaches end threshold, set CHRG_INHIBIT bit
4. When battery drops to start threshold, clear CHRG_INHIBIT bit

**Reference:**
- [TI BQ25700 Datasheet](https://www.ti.com/lit/ds/symlink/bq25700.pdf)
- [Kernel power supply class documentation](https://www.kernel.org/doc/html/latest/power/power_supply_class.html)

### 2. Investigate FydeOS Implementation

FydeOS (ChromeOS-based) may have working charge limiting. Investigation tasks:

- [ ] Check if FydeOS exposes charge control via `cros_ec` or similar
- [ ] Examine FydeOS kernel patches for power management
- [ ] Check for custom userspace daemons (powerd, etc.)
- [ ] Review ChromeOS charge_control documentation

**Useful commands on FydeOS:**
```bash
# Check for EC-based charge control
ls /sys/class/chromeos/cros_ec/

# Check ectool if available
ectool chargecontrol

# Dump kernel config
zcat /proc/config.gz | grep -i charge
```

### 3. Alternative: Userspace Polling Daemon

If kernel changes aren't feasible, a userspace daemon could:
1. Monitor battery percentage via UPower
2. When threshold reached, trigger USB-C disconnect via TCPM renegotiation
3. Use `ectool` if available on future kernels with EC support

## Related Projects

- [fydetab-battery-saver GNOME Extension](https://github.com/tweakz-fydetab-hacks/fydetab-arch-battery-saver) - Notification-based charge monitoring (current workaround)

## Testing Notes

### Sysfs Paths

```bash
# Battery status
cat /sys/class/power_supply/sbs-5-000b/capacity
cat /sys/class/power_supply/sbs-5-000b/status

# Charger info
cat /sys/class/power_supply/bq25700-charger/input_current_limit
cat /sys/class/power_supply/bq25700-charger/constant_charge_current

# USB-C power role (read-only in practice)
cat /sys/class/typec/port0/power_role
```

### I2C Investigation

```bash
# List I2C buses
sudo i2cdetect -l

# Charger is on bus 6, address 0x6b
# Note: Direct access blocked while kernel driver is loaded
sudo i2cget -y 6 0x6b 0x12 w  # Will fail with "Device busy"
```

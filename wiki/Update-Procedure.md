# System Update Procedure

This document outlines the correct order of operations for updating your system while maintaining a custom kernel.

## Why Order Matters

The `linux-fydetab-itztweak` package may depend on specific kernel headers or module versions. Updating system packages before rebuilding the kernel can cause mismatches.

## Quick Reference

```
1. Backup kernel
2. Rebuild kernel
3. Install kernel
4. Update system (paru -Syu)
5. Reboot
6. Verify
```

## Detailed Steps

### Step 1: Backup Current Kernel

Always backup before changes:

```bash
sudo cp /boot/vmlinuz-linux-fydetab-itztweak /boot/vmlinuz-linux-fydetab-itztweak.backup
sudo cp /boot/initramfs-linux-fydetab-itztweak.img /boot/initramfs-linux-fydetab-itztweak.img.backup
```

### Step 2: Check for Source Updates (Optional)

If updating kernel version:

```bash
cd ~/builds/tweakz-fydetab-hacks/pkgbuilds/linux-fydetab-itztweak
# Check PKGBUILD for source URL and update _commit or version
```

### Step 3: Rebuild Kernel

```bash
cd ~/builds/tweakz-fydetab-hacks/pkgbuilds/linux-fydetab-itztweak
./build.sh clean    # Fresh build
# OR
./build.sh          # Incremental build
```

Verify success:
```bash
ls -la *.pkg.tar.zst
```

### Step 4: Install New Kernel

```bash
cd ~/builds/tweakz-fydetab-hacks/pkgbuilds/linux-fydetab-itztweak
sudo pacman -U linux-fydetab-itztweak-*.pkg.tar.zst
```

For DKMS modules (nvidia, virtualbox, etc.):
```bash
sudo pacman -U linux-fydetab-itztweak-*.pkg.tar.zst linux-fydetab-itztweak-headers-*.pkg.tar.zst
```

### Step 5: Update System Packages

```bash
paru -Syu
```

If paru tries to replace `linux-fydetab-itztweak`:
```bash
paru -Syu --ignore linux-fydetab-itztweak,linux-fydetab-itztweak-headers
```

### Step 6: Reboot

```bash
sudo reboot
```

### Step 7: Verify

```bash
uname -r                    # Check kernel version
journalctl -b -p err        # Check for boot errors
dmesg | grep -i error       # Check kernel messages
```

## Troubleshooting

### System Won't Boot

See [[Recovery]] for U-Boot recovery procedures.

### Kernel Build Fails

1. Check build log: `logs/build-latest.log`
2. Common fixes:
   - Clean build: `./build.sh clean`
   - Check disk space: `df -h`
   - Check memory: `free -h`

### Package Conflicts

```bash
paru -Syu --ignore linux-fydetab-itztweak,linux-fydetab-itztweak-headers
```

## SD Card Testing Workflow

For safer kernel development:

1. Build kernel as above
2. Build SD card image:
   ```bash
   cd ~/builds/tweakz-fydetab-hacks
   ./scripts/build-all.sh
   ```
3. Flash to SD card
4. Test boot from SD
5. If working, install to eMMC

## Maintenance Schedule

- **System packages**: Weekly or as needed for security
- **Kernel rebuild**: Only when needed (security, features, deps)

## Notes

- Kernel build takes significant time on this device
- Build logs saved to `logs/`
- Always keep backup of last working kernel

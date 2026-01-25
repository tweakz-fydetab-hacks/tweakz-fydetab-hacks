# Boot Recovery

This page covers recovery procedures when the system fails to boot after a kernel update.

## Boot Process Overview

The FydeTab Duo uses U-Boot as its bootloader:

1. U-Boot initializes from SPI flash
2. U-Boot reads `/boot/boot.scr.uimg` (boot script)
3. Boot script loads kernel, initramfs, and device tree
4. Kernel boots

**Default paths:**
```
Kernel:    /boot/vmlinuz-linux-fydetab-itztweak
Initramfs: /boot/initramfs-linux-fydetab-itztweak.img
DTB:       /boot/dtbs/rockchip/rk3588s-fydetab-duo.dtb
```

## Prerequisites

You need ONE of:
- USB-C serial debug cable (3.3V TTL)
- Bootable SD card with working Linux
- Another computer to access eMMC via Maskrom

## Option 1: Serial Console (Recommended)

### Requirements
- USB-C serial debug cable
- Terminal program (picocom, screen, minicom)

### Procedure

1. Connect serial cable to debug USB-C port (not charging port)

2. Open terminal at 1500000 baud:
   ```bash
   picocom -b 1500000 /dev/ttyUSB0
   # or
   screen /dev/ttyUSB0 1500000
   ```

3. Power on device, quickly press key to interrupt U-Boot

4. At U-Boot prompt, boot from backup:
   ```
   setenv linux_image /boot/vmlinuz-linux-fydetab-itztweak.backup
   setenv initrd /boot/initramfs-linux-fydetab-itztweak.img.backup
   boot
   ```

5. Once booted, restore backup permanently:
   ```bash
   sudo cp /boot/vmlinuz-linux-fydetab-itztweak.backup /boot/vmlinuz-linux-fydetab-itztweak
   sudo cp /boot/initramfs-linux-fydetab-itztweak.img.backup /boot/initramfs-linux-fydetab-itztweak.img
   ```

## Option 2: Boot from SD Card

### Procedure

1. Insert SD card with bootable Arch Linux ARM

2. Power on (U-Boot tries SD before eMMC)

3. Once booted from SD, mount eMMC:
   ```bash
   lsblk
   # eMMC is usually /dev/mmcblk0, root is partition 2
   sudo mount /dev/mmcblk0p2 /mnt
   ```

4. Restore kernel backup:
   ```bash
   sudo cp /mnt/boot/vmlinuz-linux-fydetab-itztweak.backup /mnt/boot/vmlinuz-linux-fydetab-itztweak
   sudo cp /mnt/boot/initramfs-linux-fydetab-itztweak.img.backup /mnt/boot/initramfs-linux-fydetab-itztweak.img
   ```

5. Unmount and reboot:
   ```bash
   sudo umount /mnt
   sudo reboot
   ```

6. Remove SD card during reboot to boot from eMMC

## Option 3: Maskrom Mode (Last Resort)

If U-Boot itself is corrupted:

### Requirements
- Another computer with `rkdeveloptool`
- USB-C data cable
- Original firmware images

### Procedure

1. Enter Maskrom mode:
   - Power off completely
   - Hold Maskrom button (near USB-C port)
   - Connect USB-C to computer
   - Release button after 3 seconds

2. Verify device detected:
   ```bash
   rkdeveloptool ld
   ```

3. Flash bootloader (commands depend on firmware package)

## Prevention

### Always Keep Backups

Before any kernel update:
```bash
sudo cp /boot/vmlinuz-linux-fydetab-itztweak /boot/vmlinuz-linux-fydetab-itztweak.backup
sudo cp /boot/initramfs-linux-fydetab-itztweak.img /boot/initramfs-linux-fydetab-itztweak.img.backup
```

### Keep Bootable SD Card Ready

A rescue SD card is invaluable for kernel development.

### Document Your System

```bash
lsblk -f > ~/partition-layout.txt
sudo blkid >> ~/partition-layout.txt
```

## Diagnosing Boot Failures

### With Serial Console

Watch for:
- **"Wrong image format"** - kernel/initramfs corrupted
- **"Unable to read file"** - file missing or filesystem issue
- **Kernel panic** - config issue or missing modules
- **Hangs after "Starting kernel"** - DTB or early boot issue

### Common Failures

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No output after "Starting kernel" | Bad DTB | Check DTB path |
| Kernel panic: VFS unable to mount | Wrong root= | Check boot.scr |
| Kernel panic: init not found | Corrupted rootfs | Check filesystem |
| Hangs with blinking cursor | initramfs issue | Regenerate with mkinitcpio |

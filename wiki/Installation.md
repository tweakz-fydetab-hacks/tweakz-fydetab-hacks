# Installation Guide

This guide covers installing Arch Linux on the FydeTab Duo tablet.

## Download

Download the latest image from [Releases](https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks/releases).

Or build your own (see [[Building]]).

## Flash to SD Card

### Requirements

- MicroSD card (16GB+ recommended)
- SD card reader
- Linux/macOS/Windows computer

### Linux

```bash
# Find SD card device
lsblk

# Flash (replace sdX with your device)
xzcat ArchLinux-ARM-FydeTab-Duo-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

### macOS

```bash
# Find disk number
diskutil list

# Unmount
diskutil unmountDisk /dev/diskN

# Flash
xzcat ArchLinux-ARM-FydeTab-Duo-*.img.xz | sudo dd of=/dev/rdiskN bs=4m
```

### Windows

Use [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/).

## First Boot

1. Insert SD card into FydeTab Duo
2. Power on the tablet
3. U-Boot should boot from SD card automatically
4. Wait for GNOME desktop to appear

### Default Credentials

| User | Password |
|------|----------|
| arch | arch |
| root | root |

**Change these immediately after first boot!**

```bash
passwd
sudo passwd root
```

## Post-Installation

### Connect to WiFi

1. Click network icon in top bar
2. Select your network
3. Enter password

Or via command line:
```bash
nmcli device wifi list
nmcli device wifi connect "SSID" password "password"
```

### System Update

```bash
sudo pacman -Syu
```

### Verify GPU

```bash
# Check panthor driver loaded
dmesg | grep panthor

# Check for GPU render node
ls /dev/dri/

# Test acceleration (should not show llvmpipe)
glxinfo | grep "OpenGL renderer"
```

## Installing to eMMC

After testing on SD card, you can install to internal eMMC.

### Option 1: Flash Image to eMMC

Boot from SD, then flash to eMMC:

```bash
# Find eMMC device (usually mmcblk0)
lsblk

# Flash (THIS ERASES eMMC)
xzcat /path/to/image.img.xz | sudo dd of=/dev/mmcblk0 bs=4M status=progress
sync

# Reboot and remove SD card
sudo reboot
```

### Option 2: Install Kernel Only

If you have a working Arch installation on eMMC and just want the custom kernel:

```bash
cd ~/builds/tweakz-fydetab-hacks/pkgbuilds/linux-fydetab
sudo pacman -U linux-fydetab-*.pkg.tar.zst
```

## Troubleshooting

### Won't Boot

- Try different SD card
- Check image integrity (redownload)
- Use serial console to see boot messages

See [[Recovery]] for more options.

### No Display

- Wait 30+ seconds (first boot can be slow)
- Try connecting to HDMI
- Check serial console for kernel panics

### No WiFi

- Check that AP6275P firmware is installed
- Try: `sudo modprobe brcmfmac`
- Check dmesg for firmware loading errors

### Touch Not Working

- Check Himax driver loaded: `dmesg | grep himax`
- Try: `sudo modprobe hx83112b_ts` (if modular)

## Dual Boot with FydeOS

The FydeTab comes with FydeOS on eMMC. To dual boot:

1. Keep FydeOS on eMMC
2. Boot Arch from SD card
3. Hold volume down during boot for boot menu (device-dependent)

Or use a boot menu solution (advanced).

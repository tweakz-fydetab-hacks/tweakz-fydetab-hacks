# Welcome to tweakz-fydetab-hacks

This wiki documents the process of getting Arch Linux running well on the FydeTab Duo tablet.

## What is FydeTab Duo?

The FydeTab Duo is a 12.4" tablet based on the Rockchip RK3588S SoC. Key hardware:

| Component | Details |
|-----------|---------|
| SoC | Rockchip RK3588S (4x A76 + 4x A55) |
| GPU | ARM Mali G610 (Valhall architecture) |
| RAM | 8GB/16GB LPDDR5 |
| Storage | 128GB/256GB eMMC |
| Display | 12.4" 2560x1600 IPS |
| WiFi/BT | AP6275P (Broadcom) |
| Touch | Himax HX83112B |

## Quick Links

- **[Installation](Installation)** - Flash image and first boot
- **[GPU Driver Fix](GPU-Driver-Fix)** - Making GPU work with open-source drivers
- **[Recovery](Recovery)** - Boot recovery options
- **[Update Procedure](Update-Procedure)** - Safe kernel update workflow
- **[Building](Building)** - Building packages and images

## Current Status

| Feature | Status | Notes |
|---------|--------|-------|
| Boot | Working | U-Boot + GRUB |
| Display | Working | rockchip-drm |
| GPU | Working | Panthor driver + Mesa 24.1+ |
| Touch | Working | Himax driver |
| WiFi | Working | brcmfmac |
| Bluetooth | Working | btusb |
| Sound | Partial | HDMI works, speakers need config |
| USB-C | Working | Charging + data |
| Suspend | Untested | |

## Project Structure

This project uses git submodules:

```
tweakz-fydetab-hacks/
├── pkgbuilds/      # Fork of Linux-for-Fydetab-Duo/pkgbuilds
├── images/         # Fork of Linux-for-Fydetab-Duo/images
└── scripts/        # Build automation
```

## Getting Started

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks.git

# Build everything
cd tweakz-fydetab-hacks
./scripts/build-all.sh

# Flash to SD card
sudo dd if=images/out/ArchLinux-ARM-FydeTab-Duo-*.img of=/dev/sdX bs=4M status=progress
```

See [[Installation]] for detailed instructions.

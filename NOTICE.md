# Third-Party Notices and Attribution

This project incorporates and builds upon work from multiple upstream sources. This document provides attribution and license information for all components.

## Upstream Projects

### Linux-for-Fydetab-Duo

The core packages and image build system are forked from the Linux-for-Fydetab-Duo community project.

- **Repository**: https://github.com/Linux-for-Fydetab-Duo
- **License**: GPL v3

### Linux Kernel

The kernel is based on the Rockchip BSP kernel with patches for FydeTab Duo support.

- **Source**: Linux-for-Fydetab-Duo/linux-rockchip (noble-panthor branch)
- **License**: GPL v2
- **Copyright**: Linus Torvalds and kernel contributors

### GNOME / Mutter

The mutter package includes a patch to prevent automatic screen orientation reset.

- **Upstream**: https://gitlab.gnome.org/GNOME/mutter
- **License**: GPL v2+
- **Copyright**: GNOME Project

### GRUB

Custom GRUB build with DTB support for ARM64.

- **Upstream**: https://www.gnu.org/software/grub/
- **License**: GPL v3
- **Copyright**: Free Software Foundation

### grub-btrfs

Btrfs snapshot integration for GRUB boot menu.

- **Repository**: https://github.com/Antynea/grub-btrfs
- **License**: GPL v3

### Calamares

System installer framework with custom patches.

- **Upstream**: https://calamares.io/
- **License**: GPL v3 / BSD / LGPL (multi-licensed)

### ckbcomp

Console keyboard compiler from Debian.

- **Upstream**: Debian console-setup package
- **License**: GPL v2

### Mesa

Open-source graphics drivers providing Panthor support.

- **Upstream**: https://mesa3d.org/
- **License**: MIT
- **Note**: Requires Mesa 24.1+ for Panthor driver

## Proprietary Firmware

The following firmware packages contain proprietary binary blobs. These are necessary for hardware functionality and are redistributed under their original vendor terms.

### Mali G610 GPU Firmware (mali-G610-firmware-rkr4)

- **Vendor**: ARM / Rockchip
- **License**: Proprietary
- **Purpose**: GPU firmware for Mali G610 (Valhall architecture)

### AP6275P WiFi/Bluetooth Firmware (ap6275p-firmware)

- **Vendor**: Broadcom
- **License**: Proprietary
- **Purpose**: WiFi and Bluetooth firmware for AP6275P module

### Himax Touch Firmware

- **Vendor**: Himax
- **License**: Proprietary
- **Purpose**: Touchscreen controller firmware (included in fydetabduo-post-install)
- **Location**: Distributed as binary blob

## Tools and Build System

### ImageForge

Custom image build system.

- **Repository**: Linux-for-Fydetab-Duo/images
- **License**: GPL v3

### Arch Linux ARM

Base distribution and package repositories.

- **Website**: https://archlinuxarm.org/
- **License**: Various (package-dependent)

## Documentation

Documentation in this repository (wiki pages, README files) is released under the same MIT license as the main repository, unless otherwise noted.

## Trademark Notice

- "Arch Linux" is a trademark of Levente Polyak
- "GNOME" is a trademark of the GNOME Foundation
- "FydeTab" and "FydeOS" are trademarks of Fyde Innovations

This project is not affiliated with or endorsed by any of these organizations.

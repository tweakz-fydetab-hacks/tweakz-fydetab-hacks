# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the main repository for the tweakz-fydetab-hacks project - a personal documentation and build system for running Arch Linux on the FydeTab Duo tablet.

## Structure

```
tweakz-fydetab-hacks/
├── pkgbuilds/          # Submodule: Arch Linux PKGBUILDs
├── images/             # Submodule: ImageForge build profiles
├── scripts/            # Build automation scripts
│   └── tests/          # Hardware test scripts
└── wiki/               # GitHub wiki documentation
```

## Build Workflow

### Full Pipeline (packages + image)

```sh
./scripts/build-all.sh
```

This script:
1. Builds kernel and other packages in `pkgbuilds/`
2. Copies built packages to `images/fydetab-arch/local-pkgs/`
3. Builds a bootable image using ImageForge

### Individual Steps

```sh
# Build packages only
./scripts/build-packages.sh

# Build image only (requires packages already built)
./scripts/build-image.sh

# Flash image to SD card
./scripts/flash-sd.sh
```

## Submodule Commands

```sh
# Initialize submodules after clone
git submodule update --init --recursive

# Update submodules to latest
git submodule update --remote

# Work in a submodule
cd pkgbuilds
# make changes
git add . && git commit -m "message"
cd ..
git add pkgbuilds  # Update parent's submodule reference
```

## Key Files

| File | Purpose |
|------|---------|
| `pkgbuilds/linux-fydetab/PKGBUILD` | Kernel package definition |
| `pkgbuilds/linux-fydetab/config` | Kernel .config |
| `pkgbuilds/linux-fydetab/build.sh` | Kernel build script with logging |
| `pkgbuilds/waydroid-panthor-images/PKGBUILD` | Waydroid Android images only |
| `pkgbuilds/waydroid-panthor-config/PKGBUILD` | Waydroid binder/init services |
| `images/fydetab-arch/profiledef` | ImageForge profile |
| `images/fydetab-arch/packages.aarch64` | Package list for image |
| `images/fydetab-arch/pacman.conf.aarch64` | Pacman config for image build |
| `scripts/tests/run-all-tests.sh` | Master test runner |

## Local Package Cache

The build system uses a local package cache to avoid dependency on external repos during image builds:

1. Packages are built in `pkgbuilds/`
2. `.pkg.tar.zst` files are copied to `images/fydetab-arch/local-pkgs/`
3. ImageForge's pacman.conf includes the local cache with priority

This allows:
- Offline image builds after initial package build
- Testing kernel changes without pushing to remote repos
- Reproducible builds with specific package versions

## Wiki Documentation

The GitHub wiki contains detailed documentation. When updating docs:
1. Clone wiki: `git clone https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks.wiki.git`
2. Edit markdown files
3. Commit and push

Key wiki pages:
- GPU-Driver-Fix.md - Panthor investigation notes
- Recovery.md - Boot recovery procedures
- Update-Procedure.md - Safe update workflow

## Git Remotes

Both submodules have dual remotes configured:

```sh
# In pkgbuilds/
origin    -> tweakz-fydetab-hacks/pkgbuilds (push here)
upstream  -> Linux-for-Fydetab-Duo/pkgbuilds (pull updates from here)

# Sync from upstream
git fetch upstream
git merge upstream/main
```

## Workflow Notes

- **Testing**: Always test kernel changes on SD card before installing to eMMC
- **Logs**: Build logs are saved to `pkgbuilds/linux-fydetab/logs/`
- **Recovery**: Keep a bootable SD card ready when doing kernel development

## Test Framework

Test scripts are development tools for verifying hardware after image builds.

### SD Card Test Workflow

```sh
# After flashing image
./scripts/flash-sd.sh
./scripts/copy-test-scripts.sh
./scripts/copy-waydroid-pkgs.sh  # optional

# On FydeTab (boot from SD, open GNOME Terminal)
~/tests/run-all-tests.sh

# Back on dev machine
./scripts/get-sd-results.sh
```

### SD Card Results Location

**Mount point:** `/run/media/$USER/ROOTFS`
**Test results:** `/run/media/$USER/ROOTFS/@home/arch/test-results/<timestamp>/`
**Test scripts:** `/run/media/$USER/ROOTFS/@home/arch/tests/`

### Available Tests

| Script | Verifies |
|--------|----------|
| `test-gpu.sh` | Panthor driver, DRI render devices, no llvmpipe |
| `test-display.sh` | rockchip-drm, resolution 2560x1600 |
| `test-touch.sh` | Himax HX83112B touchscreen |
| `test-wifi.sh` | brcmfmac, AP6275P firmware, NetworkManager |
| `test-bluetooth.sh` | btusb, hci0 device |
| `test-audio.sh` | es8326 codec, ALSA, HDMI audio |
| `test-usbc.sh` | fusb302, Type-C port0, power delivery |
| `test-battery.sh` | sbs-battery, bq25700 charger |
| `test-waydroid.sh` | Binder module/binderfs, waydroid init |
| `test-vscodium.sh` | Interactive VSCodium Wayland test |
| `test-system.sh` | Failed services, boot media, system health |

### Waydroid Package Split

Waydroid is split into two packages for faster iteration:

| Package | Size | Contents |
|---------|------|----------|
| `waydroid-panthor-images` | ~4.9GB | system.img, vendor.img |
| `waydroid-panthor-config` | ~100KB | Systemd units, init scripts |

Waydroid is NOT included in the base image. Copy packages to SD after flash:
```sh
./scripts/copy-waydroid-pkgs.sh
```

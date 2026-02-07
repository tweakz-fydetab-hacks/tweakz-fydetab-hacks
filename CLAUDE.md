# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is the main repository for the tweakz-fydetab-hacks project - a personal documentation and build system for running Arch Linux on the FydeTab Duo tablet.

## Structure

```
tweakz-fydetab-hacks/
├── pkgbuilds/                      # Package submodules and local builds
│   ├── linux-fydetab-itztweak/     # Custom kernel (submodule)
│   ├── waydroid-panthor-images/    # Waydroid Android images (submodule)
│   └── waydroid-panthor-config/    # Waydroid services (submodule)
├── images/                         # Submodule: ImageForge build profiles
├── scripts/                        # Build automation scripts
└── wiki/                           # GitHub wiki documentation
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
| `pkgbuilds/linux-fydetab-itztweak/PKGBUILD` | Kernel package definition |
| `pkgbuilds/linux-fydetab-itztweak/config` | Kernel .config |
| `pkgbuilds/linux-fydetab-itztweak/build.sh` | Kernel build script with logging |
| `pkgbuilds/waydroid-panthor-images/PKGBUILD` | Waydroid Android images only |
| `pkgbuilds/waydroid-panthor-config/PKGBUILD` | Waydroid binder/init services |
| `images/fydetab-arch/profiledef` | ImageForge profile |
| `images/fydetab-arch/packages.aarch64` | Package list for image |
| `images/fydetab-arch/pacman.conf.aarch64` | Pacman config for image build |

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

## Submodule Remotes

Each package submodule is an independent repo:

```sh
# Kernel
pkgbuilds/linux-fydetab-itztweak -> github.com/tweakz-fydetab-hacks/linux-fydetab-itztweak

# Waydroid
pkgbuilds/waydroid-panthor-images -> github.com/tweakz-fydetab-hacks/waydroid-panthor-images
pkgbuilds/waydroid-panthor-config -> github.com/tweakz-fydetab-hacks/waydroid-panthor-config

# Images
images/ -> github.com/tweakz-fydetab-hacks/fydetab-images
```

## Workflow Notes

- **Testing**: Always test kernel changes on SD card before installing to eMMC
- **Logs**: Build logs are saved to `pkgbuilds/linux-fydetab-itztweak/logs/`
- **Recovery**: Keep a bootable SD card ready when doing kernel development
- **pkgrel**: Never increment `pkgrel` in any PKGBUILD. Version bumps are handled by an upstream build server. Only change `pkgver` if the actual upstream source version changes.

## Waydroid

Waydroid is split into two packages for faster iteration:

| Package | Size | Contents |
|---------|------|----------|
| `waydroid-panthor-images` | ~4.9GB | system.img, vendor.img |
| `waydroid-panthor-config` | ~100KB | Systemd units, init scripts |

Waydroid is NOT included in the base image. Copy packages to SD after flash:
```sh
./scripts/copy-waydroid-pkgs.sh
```

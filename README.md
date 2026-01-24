# tweakz-fydetab-hacks

Personal documentation and tools for running Arch Linux on the FydeTab Duo tablet (Rockchip RK3588-based ARM device).

## What This Is

This project documents the journey of getting Arch Linux running well on the FydeTab Duo, including:

- Custom kernel with Panthor GPU driver support
- GNOME desktop with proper hardware acceleration
- WiFi, Bluetooth, and touchscreen configuration
- Build scripts for reproducible image creation

## Quick Start

### Prerequisites

```sh
# On the FydeTab Duo (or any aarch64 Arch Linux system)
sudo pacman -S base-devel git
```

### Clone with Submodules

```sh
git clone --recurse-submodules https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks.git
cd tweakz-fydetab-hacks
```

### Build Everything

```sh
# Build kernel packages
./scripts/build-packages.sh

# Build bootable image with local packages
./scripts/build-image.sh

# Or do both in one step
./scripts/build-all.sh
```

### Development Environment (Optional)

If you use [direnv](https://direnv.net/), copy the example config:

```sh
cp .envrc.example .envrc
direnv allow
```

## Repository Structure

```
tweakz-fydetab-hacks/
├── README.md           # This file
├── LICENSE             # MIT license
├── NOTICE.md           # Attribution for upstream sources
├── CLAUDE.md           # AI agent guidance
├── pkgbuilds/          # Submodule: Arch Linux PKGBUILDs
├── images/             # Submodule: ImageForge profiles
└── scripts/
    ├── build-packages.sh   # Build kernel + other packages
    ├── build-image.sh      # Build bootable image
    └── build-all.sh        # Full pipeline
```

## Submodules

| Submodule | Description | Upstream |
|-----------|-------------|----------|
| `pkgbuilds` | Custom PKGBUILDs for FydeTab | Fork of Linux-for-Fydetab-Duo/pkgbuilds |
| `images` | ImageForge build profiles | Fork of Linux-for-Fydetab-Duo/images |

## Documentation

See the [Wiki](https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks/wiki) for detailed guides:

- **[Home](../../wiki/Home)** - Project overview
- **[Installation](../../wiki/Installation)** - Flashing images and first boot
- **[Waydroid](../../wiki/Waydroid)** - Running Android apps with Panthor GPU
- **[GPU Driver Fix](../../wiki/GPU-Driver-Fix)** - Panthor vs Panfrost investigation
- **[Recovery](../../wiki/Recovery)** - Serial console, SD card boot, Maskrom mode
- **[Update Procedure](../../wiki/Update-Procedure)** - Safe kernel update workflow
- **[Building](../../wiki/Building)** - Package and image development
- **[Battery Management](../../wiki/Battery-Management)** - Charge control investigation and future enhancements

## Hardware Compatibility

| Component | Status | Driver |
|-----------|--------|--------|
| GPU (Mali G610) | Working | Panthor (mainline Mesa 24.1+) |
| WiFi (AP6275P) | Working | brcmfmac |
| Bluetooth | Working | btusb |
| Touchscreen | Working | Himax HX83112B |
| Display | Working | rockchip-drm |
| USB-C | Working | fusb302 |
| Audio | Partial | es8326 (HDMI works, speakers need config) |
| Battery | Working | sbs-battery (charge limiting not yet supported) |

## Licensing

This wrapper repository is MIT licensed. See [NOTICE.md](NOTICE.md) for attribution of all upstream components.

The submodule repositories maintain their original licenses:
- `pkgbuilds`: GPL v3 (PKGBUILD infrastructure)
- `images`: GPL v3

Note: Some firmware packages contain proprietary blobs (Mali GPU firmware, WiFi firmware). These are standard for ARM devices and are redistributed under their original terms.

## Contributing

This is a personal project, but issues and suggestions are welcome. For substantial changes to the core packages, consider contributing to the upstream Linux-for-Fydetab-Duo project.

## Related Projects

- [Linux-for-Fydetab-Duo](https://github.com/Linux-for-Fydetab-Duo) - Upstream community project
- [FydeOS](https://fydeos.io/) - Official ChromeOS-like distribution
- [Arch Linux ARM](https://archlinuxarm.org/) - Arch Linux for ARM devices

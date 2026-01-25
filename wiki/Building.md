# Building Packages and Images

This page covers building custom packages and bootable images for the FydeTab Duo.

## Prerequisites

```bash
sudo pacman -S base-devel git
```

## Project Setup

### Clone Repository

```bash
git clone --recurse-submodules https://github.com/tweakz-fydetab-hacks/tweakz-fydetab-hacks.git
cd tweakz-fydetab-hacks
```

### Initialize Submodules (if cloned without --recurse)

```bash
git submodule update --init --recursive
```

## Building Packages

### Using Build Script

```bash
# Build kernel packages
./scripts/build-packages.sh

# Clean build (removes src/pkg first)
./scripts/build-packages.sh clean
```

### Manual Kernel Build

```bash
cd pkgbuilds/linux-fydetab-itztweak

# Resume build
./build.sh

# Clean build
./build.sh clean
```

Build logs are saved to `logs/`:
- `build-latest.log` - Build output
- `system-latest.log` - System diagnostics

### Other Packages

Most packages can be installed from the Fyde repo. To build locally:

```bash
cd pkgbuilds/<package-name>
makepkg -sf
sudo pacman -U *.pkg.tar.zst
```

## Building Images

### Full Pipeline

```bash
./scripts/build-all.sh
```

This:
1. Builds kernel packages
2. Copies packages to local cache
3. Builds bootable image with ImageForge

### Image Only (packages already built)

```bash
./scripts/build-image.sh
```

### Manual Image Build

```bash
cd images
sudo ./fydetab-arch/profiledef -c fydetab-arch -w ./work -o ./out
```

Output: `images/out/ArchLinux-ARM-FydeTab-Duo-Gnome-*.img.xz`

## Local Package Cache

The build system uses a local package cache so images can be built with locally-compiled packages instead of pulling from remote repos.

### How It Works

1. Packages built in `pkgbuilds/` are copied to `images/fydetab-arch/local-pkgs/`
2. A local repo database is created
3. ImageForge's pacman.conf checks local cache first

### Benefits

- Test kernel changes without pushing to remote
- Reproducible builds with specific package versions
- Offline builds after initial setup

### Manual Setup

If the scripts don't set up the cache:

```bash
# Create local package directory
mkdir -p images/fydetab-arch/local-pkgs

# Copy packages
cp pkgbuilds/linux-fydetab-itztweak/*.pkg.tar.zst images/fydetab-arch/local-pkgs/

# Create repo database
cd images/fydetab-arch/local-pkgs
repo-add local.db.tar.gz *.pkg.tar.zst
```

## Flashing Images

### To SD Card

```bash
# Using the flash script (recommended)
./scripts/flash-sd.sh

# Or manually with dd
xzcat images/out/ArchLinux-ARM-FydeTab-Duo-*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
```

### To eMMC (from running system)

Not recommended for testing - use SD card first, then install packages to eMMC after verification.

## Customizing the Image

### Package List

Edit `images/fydetab-arch/packages.aarch64` to add/remove packages.

### Rootfs Overlay

Files in `images/fydetab-arch/rootfs/` are copied to the image root.

### Image Configuration

Edit `images/fydetab-arch/profiledef` for:
- Image size calculation
- Partition layout
- Boot configuration
- Filesystem type

## Troubleshooting

### Build Crashes

Check logs:
```bash
tail -f pkgbuilds/linux-fydetab-itztweak/logs/build-latest.log
```

Monitor system:
```bash
watch -n 1 'free -h; sensors 2>/dev/null | grep temp'
```

### Out of Memory

Kernel builds can OOM on 8GB RAM. Options:
- Add swap
- Reduce parallel jobs: edit PKGBUILD `MAKEFLAGS`
- Build incrementally: `./build.sh` resumes where it left off

### Package Not Found in Image

1. Check package is in `packages.aarch64`
2. Check pacman.conf has correct repos
3. If using local cache, verify package was copied and database updated

## Test Workflow

The repository includes a test framework for verifying hardware functionality after flashing.

### Quick Start

```bash
# After flashing image to SD
./scripts/flash-sd.sh

# Copy test scripts to SD
./scripts/copy-test-scripts.sh

# Copy waydroid packages (optional)
./scripts/copy-waydroid-pkgs.sh
```

### On the FydeTab

After booting from SD card:

```bash
# Run all tests
~/tests/run-all-tests.sh

# Or click "FydeTab Tests" in app menu
```

### Retrieving Results

Back on your development machine:

```bash
# Get results from SD card
./scripts/get-sd-results.sh

# Results are in test-results/<timestamp>/
```

### Test Coverage

| Test | Verifies |
|------|----------|
| `test-gpu.sh` | Panthor driver, DRI devices, no software rendering |
| `test-display.sh` | rockchip-drm, resolution, compositor |
| `test-touch.sh` | Himax driver, input devices |
| `test-wifi.sh` | brcmfmac, NetworkManager, scanning |
| `test-bluetooth.sh` | btusb, hci0 device |
| `test-audio.sh` | ALSA devices, PipeWire, HDMI audio |
| `test-usbc.sh` | fusb302, Type-C port, power delivery |
| `test-battery.sh` | sbs-battery, charger, capacity |
| `test-waydroid.sh` | Binder setup, waydroid init |
| `test-vscodium.sh` | Interactive Wayland app test |
| `test-system.sh` | Failed services, boot media, health |

### SD Card Results Location

Test results are saved to:
```
/home/arch/test-results/<timestamp>/
```

When mounted on dev machine:
```
/run/media/$USER/ROOTFS/@home/arch/test-results/<timestamp>/
```

### Building Waydroid Packages

Waydroid is not included in the base image for faster builds. Build separately:

```bash
# Build images (5GB download, only needed once)
cd pkgbuilds/waydroid-panthor-images
makepkg -s

# Build config
cd ../waydroid-panthor-config
makepkg -s

# Copy to SD card
./scripts/copy-waydroid-pkgs.sh
```

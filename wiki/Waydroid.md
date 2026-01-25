# Waydroid on FydeTab Duo

Waydroid runs Android apps in a container using the Linux kernel's capabilities. On FydeTab Duo, it uses the Panthor GPU driver for hardware acceleration.

## Status

Waydroid works with hardware GPU acceleration via the Panthor driver. The waydroid packages provide pre-configured Android images and automatic setup.

## Package Structure

Waydroid support is split into two packages:

| Package | Size | Contents | Update Frequency |
|---------|------|----------|------------------|
| `waydroid-panthor-images` | ~4.9GB | Android system.img + vendor.img | Rarely |
| `waydroid-panthor-config` | ~100KB | Binder services, init scripts, test tools | During debugging |

This split allows faster iteration on binder configuration without re-downloading large images.

## Installation

### From Pre-built Packages (Recommended)

If packages were copied to `~/pkgs/` on the SD card:

```bash
# Install both packages
sudo pacman -U ~/pkgs/waydroid*.pkg.tar.zst
```

### Build From Source

```bash
cd ~/repos/tweakz-fydetab-hacks/tweakz-fydetab-hacks/pkgbuilds

# Build images (only needed once, ~5GB download)
cd waydroid-panthor-images
makepkg -s

# Build config
cd ../waydroid-panthor-config
makepkg -s

# Install
sudo pacman -U waydroid-panthor-images/*.pkg.tar.zst
sudo pacman -U waydroid-panthor-config/*.pkg.tar.zst
```

## How It Works

### Binder IPC

Android requires binder for inter-process communication. The setup:

1. `binder_linux` module is loaded at boot via `/usr/lib/modules-load.d/waydroid.conf`
2. `dev-binderfs.mount` - Mounts binderfs at `/dev/binderfs`
3. `waydroid-binder-setup.service` - Creates devices:
   - `/dev/binderfs/binder` (symlinked to `/dev/binder`)
   - `/dev/binderfs/hwbinder` (symlinked to `/dev/hwbinder`)
   - `/dev/binderfs/vndbinder` (symlinked to `/dev/vndbinder`)

### GPU Configuration

The Panthor GPU (Mali G610) is configured automatically:
- Render device detected at `/dev/dri/renderD128` or similar
- Properties set: `persist.waydroid.render_device`, `ro.hardware.gralloc=gbm`, `ro.hardware.egl=mesa`

### First Boot

On first boot, `waydroid-panthor-init.service` runs to:
1. Check binder devices are available
2. Initialize waydroid with pre-installed images
3. Configure GPU properties
4. Create LXC container

## Using Waydroid

### Quick Test

```bash
# From GNOME desktop (requires Wayland session)
waydroid-test
```

This runs preflight checks and launches the UI.

### Manual Launch

```bash
# Start container service
sudo systemctl start waydroid-container

# Launch UI
waydroid show-full-ui
```

### Installing Apps

```bash
# Install APK
waydroid app install /path/to/app.apk

# Or use F-Droid/Aurora Store from within Android
```

## Troubleshooting

### Check Services

```bash
systemctl status dev-binderfs.mount
systemctl status waydroid-binder-setup.service
systemctl status waydroid-container.service
```

### Check Binder Devices

```bash
ls -la /dev/binderfs/
# Expected: binder, binder-control, hwbinder, vndbinder

ls -la /dev/binder /dev/hwbinder /dev/vndbinder
# Should be symlinks to /dev/binderfs/*
```

### Check Initialization

```bash
# Was init successful?
ls /var/lib/waydroid/.panthor-initialized

# Check waydroid config
cat /var/lib/waydroid/waydroid.cfg

# Check LXC container exists
ls /var/lib/waydroid/lxc/waydroid/
```

### Common Issues

#### "Session not found"

Run from GNOME desktop, not SSH:
```bash
# Check you're in Wayland session
echo $XDG_SESSION_TYPE  # should be "wayland"
echo $WAYLAND_DISPLAY   # should be set
```

#### Binder devices missing

```bash
# Check module is loaded
lsmod | grep binder_linux

# Load manually if needed
sudo modprobe binder_linux

# Restart binder setup
sudo systemctl restart dev-binderfs.mount
sudo systemctl restart waydroid-binder-setup.service
```

#### Re-initialize from scratch

```bash
sudo rm -f /var/lib/waydroid/.panthor-initialized
sudo rm -rf /var/lib/waydroid/lxc
sudo systemctl start waydroid-panthor-init
```

#### Check logs

```bash
# Init service logs
journalctl -u waydroid-panthor-init

# Container logs
journalctl -u waydroid-container

# Android logcat
waydroid logcat
```

### Diagnostic Test Script

Run the comprehensive diagnostic test:

```bash
~/tests/test-waydroid.sh /tmp/waydroid-diag
```

This collects:
- Binder module status
- Binderfs mount status
- Service logs
- Kernel config
- Remediation attempts

## Technical Details

### waydroid-panthor-images Contents

| Path | Description |
|------|-------------|
| `/var/lib/waydroid/images/system.img` | Android system image (~3.4GB) |
| `/var/lib/waydroid/images/vendor.img` | Vendor image with GPU support (~1.5GB) |

### waydroid-panthor-config Contents

| Path | Description |
|------|-------------|
| `/usr/lib/systemd/system/dev-binderfs.mount` | Binderfs mount unit |
| `/usr/lib/systemd/system/waydroid-binder-setup.service` | Binder device creation |
| `/usr/lib/systemd/system/waydroid-panthor-init.service` | First-boot init |
| `/usr/lib/modules-load.d/waydroid.conf` | Module load config |
| `/usr/local/bin/waydroid-panthor-init` | Init script |
| `/usr/local/bin/waydroid-test` | Test/diagnostic script |
| `/usr/share/applications/waydroid-test.desktop` | Desktop shortcut |

### Image Source

Android images are from [WillzenZou's Armbian fork](https://github.com/WillzenZou/armbian_fork_build) with Panthor GPU patches for the Mali G610.

### Binder Failure Chain

When diagnosing binder issues, check in order:
```
binder_linux module → /sys/fs/binder → dev-binderfs.mount → waydroid-binder-setup.service
```

Each step depends on the previous. If an early step fails, later steps will also fail.

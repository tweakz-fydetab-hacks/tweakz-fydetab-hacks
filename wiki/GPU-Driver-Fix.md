# GPU Driver Investigation

This page documents the investigation into getting GPU acceleration working on the FydeTab Duo with open-source drivers.

## The Problem

The Mali G610 GPU in the FydeTab Duo is a CSF-based Valhall architecture GPU. The original Fyde kernel configuration enables proprietary Mali drivers (`CONFIG_MALI_BIFROST=y`) which:

- Don't provide a standard DRI render node
- Cause Wayland applications to crash
- Block the open-source panfrost driver from loading

Symptoms:
- VSCodium crashes with SIGTRAP
- `wl_drm authentication failed` errors
- No `/dev/dri/renderD*` GPU render node

## Hardware Info

| Property | Value |
|----------|-------|
| GPU | Mali G610 |
| Architecture | Valhall (CSF-based) |
| Device Tree Node | `gpu@fb000000` (bifrost) or `gpu-panthor@fb000000` |
| Required Driver | Panthor (kernel) + Mesa 24.1+ |

## Solution Summary

1. **Kernel**: Disable bifrost node, enable panthor node with correct regulator
2. **Mesa**: Use mainline Mesa 24.1+ (not mesa-panfork-git)

## Kernel Configuration

The kernel needs these changes:

```
# Disable proprietary drivers
# CONFIG_MALI_BIFROST is not set
# CONFIG_MALI_MIDGARD is not set

# Enable open-source drivers as modules
CONFIG_DRM_PANFROST=m
CONFIG_DRM_PANTHOR=m
```

## Device Tree Patch

The FydeTab device tree needs a patch to:
1. Disable the old `&gpu` (bifrost) node
2. Enable `&gpu_panthor` with the correct `mali-supply` regulator

**Patch file: `enable-panthor-gpu.patch`**

```diff
--- a/arch/arm64/boot/dts/rockchip/rk3588s-fydetab-duo.dts
+++ b/arch/arm64/boot/dts/rockchip/rk3588s-fydetab-duo.dts
@@ -13,3 +13,13 @@
 	model = "Fydetab Duo";
 	compatible = "rockchip,rk3588s-tablet-12c-linux", "rockchip,rk3588";
 };
+
+/* Use Panthor driver instead of Bifrost for Mali G610 GPU */
+&gpu {
+	status = "disabled";
+};
+
+&gpu_panthor {
+	status = "okay";
+	mali-supply = <&vdd_gpu_s0>;
+};
```

## Mesa Package

The image must use mainline Mesa, not mesa-panfork:

**In `packages.aarch64`:**
```
mesa
# NOT mesa-panfork-git (only has panfrost, not panthor)
```

## Verification

After booting with the fixed kernel:

```bash
# Check panthor initialized
dmesg | grep -i panthor
# Should show: [drm] Initialized panthor 1.0.0 ... for fb000000.gpu-panthor

# Check for GPU render node
ls -la /dev/dri/
# Should see: renderD130 or similar

# Check GDM/GNOME running
systemctl status gdm

# Test GPU acceleration
glxinfo | grep "OpenGL renderer"
# Should NOT show llvmpipe (software rendering)
```

## Failed Approaches

### 1. Runtime Unbind/Rebind
Attempting to unbind from mali and rebind to panfrost at runtime crashed the system.

### 2. Device Tree Overlay
Creating an overlay to disable the mali node didn't work because the gpu_panthor node was missing the `mali-supply` regulator.

### 3. Kernel Config Only
Just disabling the proprietary drivers wasn't enough - panfrost can't handle CSF-based GPUs. Panthor is required.

### 4. Panthor DTB without mali-supply
The panthor driver failed DVFS initialization:
```
panthor: error -ENODEV: _opp_set_regulators: no regulator (mali) found
```

## References

- [Panthor driver documentation](https://docs.kernel.org/gpu/panthor.html)
- [Mesa Panthor support](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/22615)
- [RK3588 GPU on mainline](https://linux-sunxi.org/Mali_Open_Source_Driver)

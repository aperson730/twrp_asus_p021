# TWRP device tree: ASUS ZenPad 10 Z300CG (P021)

Experimental TWRP tree for the ASUS ZenPad 10 Z300CG (3G), codename `P021`,
Intel SoFIA 3G (x86), stock Android 5.0.2 (LRX22G, WW_P021-V4.6.5-20160419).

**Status: boots via `fastboot boot` only. Flashing is untested.**

## What works (tested)
- Source-built TWRP boots and draws: first on twrp-5.1, now on twrp-7.1 as a hybrid stage 2
  (see "Building on twrp-7.1" below).
- Touch, brightness slider, USB/adb (VID:PID 8087:08f4) work. adb runs as root (uid 0).
- Advanced > Terminal works (7.1 hybrid).
- Boot partition backup works, and was verified byte-for-byte against the stock boot image.

## Not tested / unknown
- `fastboot flash` (bootloader reports `secure: yes`; signature checks unknown)
- Wipe, Format, Install, Restore
- SD card (exFAT, stock uses `texfat.ko`; the vfat mount fails)
- MTP, screen rotation, pixel format colors
- Encryption

## Hardware facts
- Display 800x1280, framebuffer 32 bpp. Touch is Atmel maXTouch (`atmel_mxt_ts`).
- Backlight: `/sys/class/leds/lcd-backlight/brightness`, max 255.
- Kernel: stock 3.14.0-00002-ge2a1f04 (prebuilt in `prebuilt/kernel`). A kernel rebuilt from
  the ASUS source also boots; see `kernel/README.md` (only gcc 4.6.3 works).
  `prebuilt/kernel` is a bzImage with the real-mode setup sectors removed (starts at the 32-bit
  entry code, `fc f6 86 11 ...`); `bringup/repack-kernel.py` strips them from a fresh bzImage.
- The bootloader does not check the kernel's size, hash or signature: the stock kernel padded
  by 4096 bytes, or with a changed gzip header, still boots via `fastboot boot`.
- SoC: 4 cores, frequencies 416/728/900 MHz. Stock rc caps `thermal_scaling_max_freq` at 728000.
- USB IDs: stock Android 0b05:7773, fastboot 8087:0912, recovery 8087:08f4.
- Framebuffer node is `/dev/graphics/fb0` (there is no `/dev/fb0`). Byte order R,G,B,X, stride 3200.
- boot and recovery partitions: 17,825,792 bytes each (`ImcPartID071` / `ImcPartID121`).
- `/nvm_fs_partition` and `/ADF` hold modem and calibration data. They are deliberately
  NOT in `recovery.fstab`. Never back up, wipe or write them.

## Important quirks
1. **Not all cores online.** With all 4 cores online, TWRP stalls and the tablet hard-resets
   within about 2 minutes, on both the stock and the rebuilt kernel. Cause not identified.
   Cores 0-2 with cpu3 offline is stable. Once offline, cpu3 cannot be brought back
   (`smpboot: CPU3: Not responding`); cpu1 and cpu2 re-online fine. Under stock Android all
   4 cores run.
   - twrp-5.1 tree: single core (cpu1-3 offline in `recovery/root/init.recovery.sofia3g.rc`).
   - twrp-7.1 hybrid: three cores (only cpu3 offline in `bringup/hybrid-71/init.recovery.sofia3g.rc`).
2. **Ramdisk size limit.** The stock layout leaves about 3 MB between the ramdisk and second-blob
   addresses, so a full TWRP ramdisk does not fit. Boot is **two-stage**:
   - Stage 1: a modified stock recovery image (`mod-recovery.img`) mounts `/data` read-only,
     unpacks `/data/local/tmp/stage2.tar.gz` into a tmpfs and runs `switch_root`.
   - Stage 2: the TWRP ramdisk (`out/.../recovery/root`) packed as that tarball.
   - Stage 1 and the helper scripts are in `bringup/` (see `bringup/README.md`). The stock
     `init` binary and the static busybox it needs are not committed.
3. **Tarballs must be root-owned**: `tar --owner=0 --group=0 --numeric-owner -czf ...`
4. **Push the tarball from stock Android**, not from recovery, then `fastboot boot` stage 1.
5. Do not wipe or format `/data` from TWRP: it holds the stage-2 tarball.
6. The `second` blob (`prebuilt/second`, 236575 bytes) is the device tree (dtb, model
   `intel,sofia_3gr_soc-es2`); the kernel source builds an identical one as
   `SF_3GR-es1-sr-garnet-Z300CG.dtb`. It
   must be passed to mkbootimg.

## Build (twrp-5.1, Ubuntu 16.04 Docker container)
```
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git -b twrp-5.1
repo sync -c -j4 --force-sync --no-clone-bundle --no-tags
git clone https://github.com/aperson730/twrp_asus_p021 device/asus/P021
# apply the source fixes (see patches/)
source build/envsetup.sh && lunch omni_P021-eng
make -j4 recoveryimage        # mka needs schedtool, plain make works
```
Source patches needed on this branch (`patches/twrp-5.1-bootable-recovery.diff`):
- `partition.cpp`: replace `nullptr` with `NULL` (clang 3.5 build mode).
- `bootable/recovery/Android.mk`: add `LOCAL_CFLAGS += -mstackrealign` to the `recovery` module.
  Without it `recovery` crashes at startup with a general protection fault (misaligned `movaps`).
  Putting the flag in `TARGET_GLOBAL_CFLAGS` does not reach the compiler on this branch.

After building, copy `recovery/root`, make sure the USB gadget and touch firmware files are
present (they live in this tree under `recovery/root/`), then tar it as stage 2.

## Notes
- Touch needs `mTX1666T2_cfg*.raw` in `/system/vendor/firmware` and `/lib/firmware`.
- The 5.1 build is CPU-bound and laggy on one core. A TWRP 3.3.1 binary from another device
  was much faster, which led to the move to twrp-7.1.
- Keep a stock boot/recovery backup before experimenting. Never flash the modem partitions.
- Redact the device serial number before sharing logs or backup folder names.

## Credits
Generated with twrpdtgen (SebaUbuntu), then heavily modified by hand.

## Known issues (open)
- Splash logo not shown (gray background); cause unknown. `indeterminate013` image fails to load.
- SD card (exFAT) does not mount; needs texfat.ko from stock system/lib/modules.
- Hybrid: stock Intel init/sepolicy with 7.1 recovery, linker, libs and adbd (no --root_seclabel).

## Building on twrp-7.1 (current)
Use `-b twrp-7.1` in `repo init`. Apply `patches/twrp-7.1-busybox.diff` in `external/busybox`
(strchrnul declaration conflict). `BoardConfig.mk` uses base 0 with absolute offsets because the
7.1 mkbootimg overflows on wrapped offsets. No `-mstackrealign` is needed on this branch.
The built root does not boot with its own init on this kernel, so the working tarball is a hybrid
(stock Intel init/sepolicy/rc files plus the 7.1 recovery, linker, libs, twres and adbd).

## Assembling the stage-2 tarball (tested)
After a twrp-7.1 build:
    bringup/assemble-hybrid.sh <stock-recovery-ramdisk-dir> <out/.../recovery/root> stage2.tar.gz
Needs a static i686 busybox saved as bringup/busybox-i686.bin (not committed).
The stock ramdisk dir comes from unpacking your own stock recovery.img.
Push the result from stock Android to /data/local/tmp/stage2.tar.gz, then `fastboot boot mod-recovery.img`.
Verified: uid=0 adb, one TWRP start, UI and boot backup working with the 7.1 toybox tools
(first tested on one core; three cores, with cpu3 offline, also stable).

## Repository layout
- Top level, `recovery/`, `recovery.fstab`, `prebuilt/`: the TWRP device tree itself.
- `patches/`: source fixes for twrp-5.1 (bootable/recovery) and twrp-7.1 (busybox, mkbootimg).
- `bringup/`: stage-1 image, stage-2 assembly, boot image tools; `hybrid-71/` holds the edited
  init files for the 7.1 hybrid.
- `kernel/`: stock kernel config and build script for the kernel build that boots.
- `tools/fb/`: framebuffer text viewers for showing output on screen with TWRP stopped.

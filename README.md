# TWRP device tree: ASUS ZenPad 10 Z300CG (P021)

Experimental TWRP tree for the ASUS ZenPad 10 Z300CG (3G), codename `P021`,
Intel SoFIA 3G (x86), stock Android 5.0.2 (LRX22G, WW_P021-V4.6.5-20160419).

**Status: boots via `fastboot boot` only. Flashing is untested.**

## What works (tested)
- Source-built TWRP (twrp-5.1 minimal manifest) boots and draws.
- Touch, brightness slider, USB/adb (VID:PID 8087:08f4) work.
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
- Kernel: stock 3.14.0-00002-ge2a1f04 (prebuilt in `prebuilt/kernel`, kernel source not used).
- boot and recovery partitions: 17,825,792 bytes each (`ImcPartID071` / `ImcPartID121`).
- `/nvm_fs_partition` and `/ADF` hold modem and calibration data. They are deliberately
  NOT in `recovery.fstab`. Never back up, wipe or write them.

## Important quirks
1. **Single core only.** With all 4 cores online, TWRP stalls and the tablet hard-resets within
   about 2 minutes. Cores 1-3 are taken offline in `recovery/root/init.recovery.sofia3g.rc`.
   Cause not identified.
2. **Ramdisk size limit.** The stock layout leaves about 3 MB between the ramdisk and second-stage
   addresses, so a full TWRP ramdisk does not fit. Boot is **two-stage**:
   - Stage 1: a modified stock recovery image (`mod-recovery.img`) mounts `/data` read-only,
     unpacks `/data/local/tmp/stage2.tar.gz` into a tmpfs and runs `switch_root`.
   - Stage 2: the TWRP ramdisk (`out/.../recovery/root`) packed as that tarball.
   - Stage 1 and the helper scripts are **not** in this repo.
3. **Tarballs must be root-owned**: `tar --owner=0 --group=0 --numeric-owner -czf ...`
4. **Push the tarball from stock Android**, not from recovery, then `fastboot boot` stage 1.
5. Do not wipe or format `/data` from TWRP: it holds the stage-2 tarball.
6. The `second` blob (`prebuilt/second`, 236575 bytes) is the stock Intel second stage and
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
  was much faster, so a newer branch is the next goal.
- Keep a stock boot/recovery backup before experimenting. Never flash the modem partitions.
- Redact the device serial number before sharing logs or backup folder names.

## Credits
Generated with twrpdtgen (SebaUbuntu), then heavily modified by hand.

## Known issues (open)
- Splash logo not shown (gray background); cause unknown. `indeterminate013` image fails to load.
- SD card (exFAT) does not mount; needs texfat.ko from stock system/lib/modules.
- Hybrid: stock Intel init/sepolicy with 7.1 recovery, linker, libs and adbd (no --root_seclabel).

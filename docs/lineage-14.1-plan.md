# LineageOS 14.1 (Android 7.1) for the Z300CG (P021): findings and plan

Status (2026-11-13): phases 1-2 done. LineageOS 14.1 builds and completes a full boot
(`sys.boot_completed=1`, Setup Wizard on screen) with software graphics. See "Progress" at the end.

## Findings

**No existing port.** No Nougat or LineageOS build was found for any SoFIA x86 ZenPad
(Z170C/CG, Z300C/CG, Z380C). The "LineageOS 14.1 for ZenPad 8.0" builds (P024) are for the
Qualcomm Z380KL and cannot run on the x86 models. Closest relatives: Android-x86's LineageOS
14.1 builds (generic x86, newer kernels) and the unofficial LineageOS 14.1 for the ASUS MeMO Pad 7
ME176C (Bay Trail, shipped without Houdini).

**64-bit is ruled out.** Mobilevisor resets the platform when the guest enters long mode
(see `kernel/README.md`), so the port must be 32-bit x86 (i386 userspace, i386 kernel).

**Kernel: ready.** The stock 3.14 config (`kernel/stock-embedded.config`) already has what
Android 7.1 needs: `ANDROID_BINDER_IPC`, `ASHMEM`, `ANDROID_LOW_MEMORY_KILLER`, `ION`, `SYNC`,
`SW_SYNC`, `SECCOMP_FILTER`, `SECURITY_SELINUX`, `AUDIT`, cgroups (sched, freezer, cpuacct, memcg),
`PM_WAKELOCKS`, `NETFILTER_XT_MATCH_QTAGUID`, `FUSE_FS`, `DM_CRYPT`, `DM_VERITY`.
Missing: `CPUSETS` (used by Nougat for background/foreground core groups; an ordinary option).
`FHANDLE` and `QUOTA` are off (optional). The kernel builds reproducibly (gcc 4.6.3, `kernel/build.sh`),
boots, and runs all 4 cores once the modem VM is started (`bringup/modem-start.sh`).

**Source available.**
- Kernel: ASUS `Z300CG_V4.6.5-update/linux-3.10` (3.14).
- Wi-Fi: Intel iwlwifi backports in `Z300CG_V4.6.5-update/android/hardware/imc/wlan/iwlwifi`.
  Stock loads them as out-of-tree modules (`compat_iwlwifi.ko`, `iwlmvm.ko`, `compat_mac80211.ko`,
  `compat_cfg80211.ko`, ...). With `CONFIG_MODVERSIONS=y` the stock `.ko` files may not load on a
  rebuilt kernel, so rebuild them from this tree.
- Device tree: `prebuilt/second` (same as `SF_3GR-es1-sr-garnet-Z300CG.dtb` built from source).

**Closed userspace (from stock /system, Android 5.0.2):**

| Area | Closed parts | Risk on 7.1 |
| --- | --- | --- |
| Graphics | `libGLES_mali.so` (Mali-450), `gralloc.sofia3g.so`, `hwcomposer.sofia3g.so` | Highest. Built for Android 5; shims likely. The kernel Mali driver stays the same version, which helps. Fallback: software rendering. |
| Modem | `librpc-ril.so`, `libRpcService.so`, `rpcServer`, `rpc-daemon`, `nvm_useragent` | Medium. Nougat still accepts old RIL versions. Not needed to boot. Modem start itself is solved (`modem-start.sh`). |
| ARM apps | `libhoudini.so` (`ro.product.cpu.abilist=x86,armeabi-v7a,armeabi`) | Medium, optional. One unverified report says bundled Houdini stopped working in 2026 (built-in expiry). |
| Other HALs | `audio.primary`, `camera`, `gps`, `sensors`, `lights`, `power`, `keystore` (`.sofia3g`), `libbt-vendor.so` | Normal porting work, one at a time. |

## Constraints

- **Build disk space:** a cm-14.1 checkout plus build needs roughly 100-120 GB. The build PC had
  25 GB free on `/home` (2026-11-13). Free space or add a drive first. CPU (6 cores) and RAM
  (15 GB) are adequate; the existing Ubuntu 16.04 `twrp-builder` container fits cm-14.1 (OpenJDK 8).
- **No flashing.** Test only with `fastboot boot` (bootloader `secure: YES`, flashing unproven).
- **Never write** `/nvm_fs_partition` (ImcPartID076) or `/ADF` (ImcPartID033). Never run
  `setup_fs_nvm`. If the modem daemons need NVM: mount 076 `ro,noload` and copy it to a tmpfs.
- **Ramdisk window ~3 MB** (0x400000-0x700000). The stock boot ramdisk is 1.95 MB; a LineageOS
  ramdisk should fit, otherwise reuse the stage-1/stage-2 approach.

## Test method without flashing

- Keep stock Android untouched. Store LineageOS `system.img` and `data.img` as files in a
  directory on the internal `/data` (5.7 GB free on 2026-11-13).
- Boot with `fastboot boot`. A stage 1 like `bringup/stage1.sh` mounts `/data`, attaches the two
  images to loop devices, and starts LineageOS's `/init` (via `switch_root` if needed). The fstab
  points `/system` and `/data` at the loop devices.
- Start the modem VM early (as in `modem-start.sh`) so all 4 cores stay usable.

## Phases

1. **Setup.** Free disk space; `repo init -u https://github.com/LineageOS/android.git -b cm-14.1`
   and sync. New `device/asus/P021` tree for LineageOS: x86 target (`TARGET_ARCH := x86`,
   `TARGET_ARCH_VARIANT := silvermont`), board config from this TWRP tree, prebuilt kernel from our
   build with `CPUSETS` enabled, init/ueventd/fstab adapted from the stock ramdisk and the 7.1
   hybrid, vendor blobs extracted from stock `/system`.
2. **First boot, software graphics.** Goal: adb, logcat, boot animation. Proves kernel, init,
   SELinux (start permissive), property service and the loop-mount boot.
3. **Graphics.** Mali blob, `gralloc`, `hwcomposer`; shims for missing symbols. Decides whether
   the result is usable or only a technical demo.
4. **Basic hardware.** Wi-Fi (rebuild iwlwifi), modem start, audio, sensors, lights, power,
   battery/healthd.
5. **Extras.** Camera, RIL (3G data and calls), Houdini.

Rough effort: phase 2 in days; phase 3 days or possibly not solvable.

## Sources
- LineageOS wiki, ZenPad 8.0 Z380KL (P024): https://wiki.lineageos.org/devices/P024/install/
- Unofficial LineageOS 14.1 for Z380K[N]L (XDA): https://xdaforums.com/t/rom-7-1-2-unofficial-lineageos-14-1-weekly-builds-for-asus-zenpad-8-0-z380k-n-l.3968526/page-4
- Z380C custom ROM thread (XDA): https://xdaforums.com/t/asus-zenpad-8-0-z380c-any-custom-roms-available.3261934/
- ZenPad 10 Z300C root thread (XDA): https://xdaforums.com/t/anyone-know-how-to-root-asus-zenpad-10-z300c.3214802/page-20
- postmarketOS, ODYS Thor 10 +3G (sofia3gr): https://wiki.postmarketos.org/wiki/ODYS_Thor_10_%2B3G_(odys-sofia3gr)
- Android-x86 cm-x86 14.1 r1: https://www.android-x86.org/releases/releasenote-cm-x86-14-1-r1
- Unofficial LineageOS 14.1 for ME176C (XDA): https://forum.xda-developers.com/t/rom-7-1-2-2018-09-26-unofficial-lineageos-14-1-for-asus-memo-pad-7-me176c-x.3633341/
- android-x86 group, libnb vs libhoudini: https://groups.google.com/g/android-x86/c/SEMbCDXzTz4

## Progress (2026-11-13)

Where things live (PC, not in this repo):
- Source: `~/lineage-14.1` (cm-14.1, synced with `--no-git-lfs`; only
  `external/chromium-webview/prebuilt/x86/webview.apk` was fetched from LFS by hand).
- Device tree: `~/lineage-14.1/device/asus/P021` (local git; backup tarball in
  `~/z300cg-final-backup/lineage-device-P021-*.tar.gz`). Contains `patches/` with the
  `system/sepolicy` change (re-apply after `repo sync`).
- Closed files: `~/lineage-14.1/vendor/asus/P021` (from `extract-files.sh`; private, never publish).
  Full stock /system copy: `~/z300cg/stock-system/system.tar` (read-only tar from TWRP).
- Build container: image `lineage-builder` (twrp-builder + imagemagick, schedtool, pngcrush,
  yasm, Jack TLS fix). Run as `-u 1000:1000 -e HOME=/tmp/home` and `mkdir -p $HOME` first.
- Test boot: `device/asus/P021/preinit/make-test-boot.sh <busybox-i686.bin>` makes
  `out/.../boot-looptest.img`; images live on the tablet in `/data/local/tmp/lineage/`
  (`system.img` raw ext4 from `simg2img`, `data.img`, `cache.img` from `make_ext4fs`).
  Push them from TWRP, then `fastboot boot boot-looptest.img`.

Fixes needed to get a full boot (all in the device tree):
1. Product file must be named `lineage.mk` (cm-14.1 looks up `device/*/P021/lineage.mk`).
2. Prebuilt kernel: ship `make headers_install` output for `KERNEL_OBJ/usr`.
3. SELinux: kernel 3.14 accepts policy v29 only; `POLICYVERS := 29` and strip `*xperm` rules.
4. Pre-init: `/sbin/ueventd` and `/sbin/watchdogd` link to `../init`; point them at `init.real`.
5. adb over FunctionFS (`f_ffs/aliases adb`, functionfs mount), adb key shipped as `/adb_keys`,
   `persist.sys.root_access=3`.
6. Software GLES: `persist.sys.force_sw_gles=1`, no `hwcomposer.default` (NULL hooks, crashes SF).
7. Stock `by-name` path symlink (the vmodem kernel driver and the modem start need it).
8. `notrim` on the loop devices: vold fstrim corrupted dalvik-cache through the loop device
   (SIGBUS in system_server 30 s after the trim).
9. cpusets: N init.rc puts every cpuset on cpu 0; set real cores in `init.sofia3g.rc`
   (boot stalled for 10+ minutes before this).
10. Modem start works under LineageOS; all 4 cores online.

In the device tree but not yet built/tested: dexpreopt, cpuset cores, no 728 MHz cap
(interactive governor), boot animation size (built, works).

Current blocker: input does not reach apps. The window manager waits for SystemUI's keyguard
to finish drawing (`mKeyguardDrawComplete=false`, `KeyguardScrim` holds focus). SystemUI cannot
render properly with the GLES 1.x software renderer (wallpaper and keyguard need GLES 2).
Touch itself works (events reach the input dispatcher).

Next steps:
- Workaround build: `ro.lockscreen.disable.default=true`, optionally mark setup complete.
- Phase 3: Mali-450 (`libGLES_mali.so`, `gralloc.sofia3g`, `hwcomposer.sofia3g`) with shims.
- Kernel: backport SELinux extended permissions (ioctl xperms) to allow policy v30.

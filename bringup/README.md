# Bring-up tools (ASUS P021)

- bootinfo.py: prints boot image header fields (page size, addresses, cmdline).
- repack.py: rebuilds a boot image from a stock one with a new ramdisk
  (copies kernel + second blob, which is the device tree, recomputes SHA). Optional 4th arg sets ramdisk address.
- build-mod.sh [RAMDISK_DIR] [STOCK_RECOVERY_IMG] [OUT_DIR]: builds mod-recovery.img (stage 1)
  with this repo's repack.py, and fails if the ramdisk reaches 3,145,728 bytes.
- stage1.sh: init script in stage 1. Mounts /data read-only, unpacks
  /data/local/tmp/stage2.tar.gz into a 96 MB tmpfs, switch_root to /twrp/init.
  Falls back to /init.stock on any failure.

Stage 1 needs a static i686 busybox (busybox.net 1.30.0-i686) at /system/bin/busybox
in the ramdisk. It is not committed. Stage 1 + busybox must stay under 3,145,728 bytes.
Stock /init is renamed init.stock; sbin/ueventd and sbin/watchdogd symlink to it.

Inputs are your own stock images split from fwu_image.bin (not committed).
Boot with: fastboot boot mod-recovery.img   (never flash, unproven)

- modem-start.sh: starts the modem VM in TWRP without Android daemons (read-only /system,
  firmware into /dev/vmodem, `modem_state` = 1). Keeps cpu3 alive on 4 cores. Run before ~57 s.
- stall-logger.sh: every 2 s logs per-CPU time, timer/IPI counts and per-CPU kernel threads to
  /data/local/tmp/stall/log.txt. Run pinned to cpu0:
  `busybox setsid busybox taskset 0x1 sh /data/local/tmp/stall-logger.sh`

## Saved files
- stage1.sh: the stage-1 /init script (installed as /init in the ramdisk).
- stage1-init.rc, stage1-default.prop: modified stock init.rc (adds `disabled` under
  service recovery so it does not auto-reboot) and default.prop (ro.secure=0,
  ro.debuggable=1, ro.adb.secure=0).
- Not committed: init.stock (the original stock /init binary, renamed) and busybox.
  Recreate init.stock by renaming /init from your own stock recovery.img.

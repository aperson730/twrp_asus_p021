# Bring-up tools (ASUS P021)

- bootinfo.py: prints boot image header fields (page size, addresses, cmdline).
- repack.py: rebuilds a boot image from a stock one with a new ramdisk
  (copies kernel + second blob, which is the device tree, recomputes SHA). Optional 4th arg sets ramdisk address.
- build-mod.sh: builds mod-recovery.img (stage 1).
- stage1.sh: init script in stage 1. Mounts /data read-only, unpacks
  /data/local/tmp/stage2.tar.gz into a 96 MB tmpfs, switch_root to /twrp/init.
  Falls back to /init.stock on any failure.

Stage 1 needs a static i686 busybox (busybox.net 1.30.0-i686) at /system/bin/busybox
in the ramdisk. It is not committed. Stage 1 + busybox must stay under 3,145,728 bytes.
Stock /init is renamed init.stock; sbin/ueventd and sbin/watchdogd symlink to it.

Inputs are your own stock images split from fwu_image.bin (not committed).
Boot with: fastboot boot mod-recovery.img   (never flash, unproven)

## Saved files
- stage1.sh: the stage-1 /init script (installed as /init in the ramdisk).
- stage1-init.rc, stage1-default.prop: modified stock init.rc (adds `disabled` under
  service recovery so it does not auto-reboot) and default.prop (ro.secure=0,
  ro.debuggable=1, ro.adb.secure=0).
- Not committed: init.stock (the original stock /init binary, renamed) and busybox.
  Recreate init.stock by renaming /init from your own stock recovery.img.

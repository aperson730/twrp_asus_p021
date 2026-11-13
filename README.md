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
   Timer layout from the boot log: cpu0 and cpu1 use the STM timer, cpu2 and cpu3 use the two
   CapCom channels. A 4-core boot log of the rebuilt kernel (ends at 56 s, before the stall)
   shows no warnings, so a kernel log of the stall itself has not been captured yet.
   See "Four-core stall: findings from the kernel source" below.
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

## Four-core stall: findings from the kernel source
Read from the ASUS source, not yet tested on the device.

- **Linux is a guest under Intel's Mobilevisor hypervisor**, which also runs a separate modem VM.
  The 4 CPUs Linux sees are virtual. Core start/stop, IPIs, the APIC timer and CPU frequency
  are hypercalls (`arch/x86/kernel/apic/apic_sofia.c`, `arch/x86/sofia/`).
- **cpu3 re-online failure happens in the hypervisor.** Offlining calls `mv_vcpu_stop`,
  onlining calls `mv_vcpu_start`. `CPU3: Not responding` (`smpboot.c`) means vcpu3 never
  reached Linux code after `mv_vcpu_start`; the CapCom timer setup comes later and is never hit.
- **The "hard reset" is probably a Linux panic.** The stock config has
  `BOOTPARAM_SOFTLOCKUP_PANIC`, `BOOTPARAM_HARDLOCKUP_PANIC`, `PANIC_ON_OOPS` and
  `PANIC_TIMEOUT=1` (reboot 1 s after a panic). The panic text goes to ramoops
  (`/sys/fs/pstore`, 2 MB console, `arch/x86/platform/xgold/xgold_pstore_ram.c`) and to the
  hypervisor via `drivers/mobilevisor/vdump.c`.
- **cpu3 probably shares its physical core with the modem VM.** Under stock Android cpu3 shows
  steal time and the others don't; `arch/x86/sofia/cpu.c` has
  "FIXME: Get the vcpu shared with another vm". Android starts the modem VM by writing 1 to
  `/sys/class/misc/vmodem/modem_state` (`drivers/mobilevisor/modem.c`). Recovery runs none of
  the modem daemons, so cpu3 runs under different conditions in TWRP. How this would cause the
  stall is a guess.
- Timer layout (device tree): STM timer `intel,stm,cpumask = <0x03>` (cpu0-1), CapCom
  `intel,cc,cpumask = <0x0c>` (cpu2-3).
- **CapCom `_xgold_cc_set_mode` early return is NOT a bug in practice (tested 2026-11-13).**
  It looks like the switch to oneshot is skipped once the timer is periodic. A patch that
  removed the early return made idle cpu2 take 1225 CapCom interrupts in 10 s, against 56 with
  the original code (3 cores, TWRP idle, `/proc/interrupts` IRQ 124). The patch was dropped;
  leave this code as it is.

Test run 2026-11-13 (old gcc 4.6.3 kernel, `stage2-4core`, TWRP left idle, kmsg streamed live,
`/proc/stat` + `/proc/interrupts` every 5 s):
- At about 57 s uptime touch and adb died (`adb shell` and `adb pull` both hang; device still
  listed as `recovery`). The TWRP clock kept running, so the kernel and display were alive.
- The kernel log has nothing after 56.7 s: no soft lockup, RCU stall or panic in 7 minutes.
- No reset by itself in 7 minutes; it needed a forced power-off.
- The last snapshot (54 s) was normal on all 4 cores.
- Under stock Android only cpu3 shows steal time (`/proc/stat` steal column: 615, others 0).
- Reading: a partial freeze, consistent with one vCPU (probably cpu3) no longer being run by
  the hypervisor while the others continue. Per-CPU lockup detectors cannot report a CPU that
  does not run. Not proven.

Second run 2026-11-13 (same setup, logger on the tablet pinned to cpu0 writing to /data every
2 s, then the pstore panic record read from a 3-core TWRP). **Root cause found:**
- At ~57 s uptime cpu3 stops taking any interrupt: its CapCom timer IRQ (125) and its
  rescheduling-IPI count freeze, and `watchdog/3`, `ksoftirqd/3`, `migration/3` never run again.
  `/proc/stat` keeps adding idle time for cpu3 only because NO_HZ fills in idle time for a sleeping
  CPU: cpu3 went idle and was never woken.
- ~6 s later cpu2 hangs: `recovery` calls `madvise` -> `zap_page_range` -> TLB flush ->
  `smp_call_function_single` to cpu3 and spins waiting for an answer that never comes.
- Panic record (`/sys/fs/pstore/dmesg-ramoops-0.enc.z`; skip the `====...` header line, the rest
  is zlib): `BUG: soft lockup - CPU#2 stuck for 22s! [recovery:189]`,
  `EIP is at generic_exec_single`, `EDI: 00000003`, then `Kernel panic - not syncing: softlockup`.
  `PANIC_TIMEOUT=1` reboots one second later. That is the "hard reset".
- An RCU stall warning at 85 s ended before its dump.
- The first run froze without a reset because nothing happened to spin in the kernel waiting on
  cpu3; the tasks queued on cpu3 just never ran.
- Every run logs `vdump: Kernel vdump Thread running` at 56.7 s, right before cpu3 dies. That is
  `vdump_set_linux_config` giving up after 20 x 2 s waiting for `/data/local/tmp/vdump.conf`; it
  makes no hypercall when the file is missing, so it is probably only a timing coincidence.
- Open question: why the hypervisor stops delivering interrupts to vcpu3 (or stops running it)
  at ~57 s in TWRP but not in Android, where cpu3 shows steal time and keeps working.

Third run 2026-11-13: cpu3 kept busy from 9 s (`busybox taskset 0x8 sh -c "while :; do :; done"`),
logger on cpu0. **cpu3 still died between 49 s and 62 s uptime** (busy ticks frozen at 4890,
CapCom IRQ 125 frozen, `watchdog/3` stopped). So the loss does not depend on idle; the
hypervisor stops running vcpu3 at a fixed point (~57 s) whatever it is doing.
Side effect: busy cpu3 still held the `do_timer` (timekeeping) duty when it froze, so system time
stopped advancing. The TWRP clock froze, `/proc/uptime` read 101 s after 10 minutes (it only wraps
from the last update), the logger's `sleep 2` never returned after 199.6 s, and no soft lockup
fired (its timer depends on the same clock). In the idle run the duty had moved to another CPU,
which is why that clock kept going. Workaround for now: keep cpu3 offline (current default).

Fourth run 2026-11-13: modem start attempted in 4-core TWRP at 8 s uptime with
`echo 1 > /sys/class/misc/vmodem/modem_state` (driver reads ImcPartID022-024 read-only into the
modem's memory and calls `mv_vm_start(1)`). The write returned success but the state stayed
**Off** for the whole run, so the modem VM never started. cpu3 died at the usual point (CapCom
IRQ 125 frozen between 56.6 s and 62.8 s), adb dropped at ~75 s and the tablet reset by itself.
Inconclusive about the modem's role, since it never ran. In Android the `modem_state` node is
owned by `radio`, so a radio daemon (probably rild) starts it, maybe after other setup
(`sec_daemon`, `setup_fs_nvm`) that TWRP lacks.

**Fix found (fifth run, 2026-11-13): start the modem VM and cpu3 survives.**
Android loads the modem firmware from userspace (`libRpcService.so` runs
`cat /system/vendor/firmware/modem.fls_ID0_CUST_LoadMap0.bin > /dev/vmodem`) before writing
`modem_state`; the fourth run skipped that, so the hypervisor had nothing to start.
`bringup/modem-start.sh` does the same with no Android daemons: mounts system (ImcPartID068)
read-only with `noload` at /mnt/sysro, copies the 29 MB firmware into the modem's RAM through
`/dev/vmodem` (the driver only `ioremap`s the reserved region), writes 1 to `modem_state`
(the driver reads ImcPartID022-024 read-only into modem RAM and calls `mv_vm_start(1)`).
No flash writes.
Result with `stage2-4core`, the gcc 4.6.3 kernel, script started at ~9 s by hand over adb:
- `modem_state` On at 11.5 s and for the whole run.
- All 4 cores online past 5 minutes (300+ s). cpu3's CapCom IRQ kept counting
  (5007 -> 16512 between 118 s and 293 s), `watchdog/3` kept running (81 switches vs 17 when stuck).
- cpu3 now shows steal time (82 -> 853 ticks), like stock Android: the modem VM shares
  physical core 3.
- Touch, UI and adb worked throughout; adbd even ran on cpu3.
Reading: the hypervisor stops running vcpu3 at ~57 s if the modem VM has not been started,
probably because vcpu3 shares its physical core with the modem. Not yet automatic: the
script must run before ~57 s. Without it, keep the 3-core default.

Tests to run next:
- Make it automatic (stage-2 init service, before 57 s), then repeat over several boots
  before making 4 cores the default.
- Watch for modem traps or resets without the Android modem daemons (`nvm_useragent` etc.).
  If needed, phase 2: run rpcServer/rpc-daemon from read-only /system, with
  /nvm_fs_partition mounted `ro,noload` and copied to a tmpfs (never written, never run
  `setup_fs_nvm`).
0. (done, see above) Keep cpu3 busy (a spin loop pinned with `taskset 0x8`) so it never goes idle. If it survives
   past 60 s, the loss happens on idle entry/wakeup; if it still dies, the hypervisor takes the
   vcpu at a fixed time. Then try disabling cpu3's cpuidle state
   (`/sys/devices/system/cpu/cpu3/cpuidle/state*/disable`).
1. Stream the kernel log to the PC through the stall: `adb shell cat /proc/kmsg > kmsg-stall.txt`,
   then look for `soft lockup`, `hard LOCKUP` or `RCU stall` near the end (names the stuck CPU).
2. In TWRP, before onlining cpu3: `echo 0 > /proc/sys/kernel/softlockup_panic; echo 0 > /proc/sys/kernel/panic`.
   If the tablet then freezes without resetting, the reset is a Linux panic; try `dmesg` over adb.
3. After a stall reset, go straight to fastboot (not stock Android), boot TWRP, then
   `mount -t pstore pstore /sys/fs/pstore; ls /sys/fs/pstore`.
4. `cat /sys/class/misc/vmodem/modem_state` in TWRP and in stock Android.

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

# Kernel build that boots (ASUS Z300CG / P021)

Source: ASUS Z300CG_V4.6.5-update, linux-3.10 folder (Makefile says 3.14.0).
Config: the one embedded in the stock kernel (extracted with scripts/extract-ikconfig).
Toolchain: Ubuntu 12.04 container, gcc 4.6.3 (the compiler named in the stock banner), plus openssl.
Build: run kernel/build.sh in the container (checks for gcc 4.6.3; config defaults to
/ksrc/kernel-running.config, then /ksrc/stock-embedded.config). It runs these steps:
  export TARGET_BUILD_VARIANT=user
  make O=out ARCH=i386 olddefconfig
  scripts/config --file out/.config --set-str LOCALVERSION "-00002-ge2a1f04"
  scripts/config --file out/.config --disable LOCALVERSION_AUTO
  make O=out ARCH=i386 -j4 bzImage
Package: bringup/repack-kernel.py STOCK_RECOVERY.img RAMDISK.gz OUT.img bzImage
Boot: fastboot boot OUT.img   (never flash; unproven with secure: YES)
Builds with gcc 5.4 and gcc 4.8 crashed immediately at boot with the same source and config.
build.sh tested as a script on 2026-11-13 (incremental build in the existing container).

## 64-bit (x86_64) experiment, 2026-11-13: builds, does not boot yet
Intel's tree has `x86_64_sofia_defconfig` and 64-bit branches in the SoFIA code, but did not
compile for 64-bit as shipped. `patches/x86_64-build.diff` (apply with `patch -p1`; no effect on
32-bit builds) fixes:
- `include/sofia/irq_vectors.h`: IPI vectors written as `(X+4)` break the nested gas macros in
  `entry_64.S`; drop the parentheses for 64-bit assembly only.
- `apic_sofia.c`: `default_phys_pkg_id` exists only for 32-bit; add a 64-bit copy.
- `drivers/mobilevisor/sec_shared_mem.[ch]`: heap bounds kept in `unsigned int`; widen to
  `unsigned long`, make the prototype `size_t`.
Config: the stock config built with `ARCH=x86_64` (olddefconfig), `IA32_EMULATION=y` for the 32-bit
userspace. Intel's `x86_64_sofia_defconfig` fails on board drivers (backlight, bq27520, DSI).
Build: in the 12.04 container, `O=/ksrc/kout64s`, `make ARCH=x86_64 bzImage`. The image starts
with the same 32-bit entry bytes as the stock kernel (`fc f6 86 11 ...`).
Boot test (`fastboot boot test64.img`, stage 1 + modem stage 2): no adb; the tablet reset and
started stock Android. No pstore record (it either dies before pstore registers at ~8.9 s or
resets without a panic). Answered by two hang tests the same day (an infinite loop `jmp .` = `eb fe` placed in
`arch/x86/boot/compressed/head_64.S`; a hang means the code ran, a reset means it died first):
- A: loop right after `cld` at the start of `startup_32` (32-bit): logo stayed, no USB for 95 s.
  The bootloader does run the 64-bit image.
- B: loop as the first instruction of `startup_64` (just after the `lret` into 64-bit mode):
  reset into stock Android after ~18 s.
So the guest dies inside the long-mode switch (PAE, `wrmsr` EFER.LME, CR0.PG, `lret`).
Mobilevisor runs the Linux VM as a 32-bit guest and resets the platform when it tries to enter
64-bit mode. The hypervisor sits in its own partition and cannot be changed here, so a 64-bit
kernel is not possible on this device. 32-bit (i386) stays the only option.
Remaining 64-bit truncation warnings are in vdump/voemcrypto/oct/rga/vpu (crash dump, DRM,
tracing, 2D/video), not on the boot path; hypercall casts carry physical addresses < 4 GB.

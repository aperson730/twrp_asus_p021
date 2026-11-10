# Kernel build that boots (ASUS Z300CG / P021)

Source: ASUS Z300CG_V4.6.5-update, linux-3.10 folder (Makefile says 3.14.0).
Config: the one embedded in the stock kernel (extracted with scripts/extract-ikconfig).
Toolchain: Ubuntu 12.04 container, gcc 4.6.3 (the compiler named in the stock banner), plus openssl.
Build:
  export TARGET_BUILD_VARIANT=user
  make O=out ARCH=i386 olddefconfig
  scripts/config --file out/.config --set-str LOCALVERSION "-00002-ge2a1f04"
  scripts/config --file out/.config --disable LOCALVERSION_AUTO
  make O=out ARCH=i386 -j4 bzImage
Package: bringup/repack-kernel.py STOCK_RECOVERY.img RAMDISK.gz OUT.img bzImage
Boot: fastboot boot OUT.img   (never flash; unproven with secure: YES)
Builds with gcc 5.4 and gcc 4.8 crashed immediately at boot with the same source and config.

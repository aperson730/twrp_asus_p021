#!/bin/bash
# Usage: assemble-hybrid.sh <stock-recovery-ramdisk-dir> <twrp-7.1 out/.../recovery/root> <out.tar.gz>
# Builds the stage-2 tarball: stock Intel init/sepolicy + 7.1 recovery, linker, libs, tools, twres, adbd.
set -euo pipefail
STOCK=$(realpath "$1"); BUILD=$(realpath "$2"); OUT=$(realpath -m "$3")
HERE=$(cd "$(dirname "$0")" && pwd); REPO=$(dirname "$HERE")
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

cp -a "$STOCK"/. "$W"/                      # stock base (init, sepolicy, rc files)

# Overlay the 7.1 sbin, but keep the stock init-related entries
for f in "$BUILD"/sbin/*; do
  n=$(basename "$f")
  case "$n" in ueventd|watchdogd|charger|healthd|pclinkd) continue;; esac
  rm -rf "$W/sbin/$n"; cp -a "$f" "$W/sbin/$n"
done
rm -rf "$W/twres"; cp -a "$BUILD/twres" "$W/twres"
[ -f "$BUILD/etc/mke2fs.conf" ] && { mkdir -p "$W/etc"; cp "$BUILD/etc/mke2fs.conf" "$W/etc/"; }

# Hand-edited files kept in the repo
cp "$HERE/hybrid-71/init.rc" "$HERE/hybrid-71/default.prop" "$W/"
mkdir -p "$W/etc"; cp "$HERE/hybrid-71/twrp.fstab" "$W/etc/twrp.fstab"
cp "$HERE/hybrid-71/init.recovery.sofia3g.rc" "$W/"
mkdir -p "$W/system/vendor" "$W/lib"
cp -a "$REPO/recovery/root/system/vendor/firmware" "$W/system/vendor/"
cp -a "$REPO/recovery/root/lib/firmware" "$W/lib/"

# /system/bin/sh for the adb shell (static busybox, kept out of the repo)
mkdir -p "$W/system/bin"
cp "$HERE/busybox-i686.bin" "$W/system/bin/busybox"
ln -sf busybox "$W/system/bin/sh"

# Sanity checks
grep -q "root_seclabel" "$W/init.rc" && { echo "ERROR: init.rc still uses --root_seclabel"; exit 1; }
grep -qE "service (snap|kick) " "$W/init.rc" && { echo "ERROR: debug services present"; exit 1; }
grep -q "cpu3/online" "$W/init.recovery.sofia3g.rc" || { echo "ERROR: single-core block missing"; exit 1; }
miss=0
for b in recovery adbd; do
  for l in $(readelf -d "$W/sbin/$b" | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do
    [ -e "$W/sbin/$l" ] || [ -e "$W/system/lib/$l" ] || { echo "MISSING: $l (needed by $b)"; miss=1; }
  done
done
[ $miss = 0 ] || exit 1

chmod 755 "$W/sbin"
tar --owner=0 --group=0 --numeric-owner -czf "$OUT" -C "$W" .
echo "OK: $OUT ($(du -sh "$W" | cut -f1) extracted, must stay under 96 MB)"
ls -l "$OUT"

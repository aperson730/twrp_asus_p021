#!/bin/sh
# Build mod-recovery.img (stage 1) from an unpacked, modified stock recovery ramdisk.
# Usage: build-mod.sh [RAMDISK_DIR] [STOCK_RECOVERY_IMG] [OUT_DIR]
# Defaults match the original layout: ~/z300cg/work/recovery-rd-mod, ~/z300cg/stock/recovery.img,
# output in ~/z300cg/work. Uses repack.py from this repo (next to this script).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
RD=$(realpath "${1:-$HOME/z300cg/work/recovery-rd-mod}")
STOCK=$(realpath "${2:-$HOME/z300cg/stock/recovery.img}")
OUT=$(realpath "${3:-$HOME/z300cg/work}")
MAX=3145728   # ramdisk window (0x400000 to 0x700000)

cd "$RD"
find . | cpio -o -H newc -R 0:0 | gzip -9 > "$OUT/mod-ramdisk.gz"
SIZE=$(wc -c < "$OUT/mod-ramdisk.gz")
if [ "$SIZE" -ge "$MAX" ]; then
  echo "ERROR: ramdisk is $SIZE bytes, must stay under $MAX" >&2
  exit 1
fi
python3 "$HERE/repack.py" "$STOCK" "$OUT/mod-ramdisk.gz" "$OUT/mod-recovery.img"
echo "built $OUT/mod-recovery.img (ramdisk $SIZE bytes)"

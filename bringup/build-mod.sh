#!/bin/sh
set -e
cd ~/z300cg/work/recovery-rd-mod
find . | cpio -o -H newc -R 0:0 | gzip -9 > ../mod-ramdisk.gz
cd ..
python3 ../tools/repack.py ../stock/recovery.img mod-ramdisk.gz mod-recovery.img
echo "built mod-recovery.img"

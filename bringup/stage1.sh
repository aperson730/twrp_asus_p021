#!/system/bin/busybox sh
B=/system/bin/busybox
L=/stage1.log
$B mount -t proc proc /proc
echo "stage1 started" > $L
$B mkdir -p /mnt/d /twrp
$B mknod /dev/mmcblk0p18 b 259 2 >> $L 2>&1
if $B mount -t ext4 -o ro,noload /dev/mmcblk0p18 /mnt/d >> $L 2>&1; then
  echo "data mounted" >> $L
  if [ -f /mnt/d/local/tmp/stage2.tar.gz ]; then
    echo "stage2 found" >> $L
    $B mount -t tmpfs -o size=96m tmpfs /twrp >> $L 2>&1
    if $B gunzip -c /mnt/d/local/tmp/stage2.tar.gz | $B tar -x -C /twrp >> $L 2>&1 && [ -x /twrp/init ]; then
      echo "stage2 extracted" >> $L
      $B cp $L /twrp/stage1.log
      $B umount /mnt/d
      $B umount /proc
      exec $B switch_root /twrp /init
    fi
    echo "stage2 failed" >> $L
  fi
  $B umount /mnt/d
else
  echo "data mount failed" >> $L
fi
$B umount /proc
exec /init.stock

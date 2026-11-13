#!/system/bin/sh
# Phase 1 modem start for TWRP on the P021 (no Android daemons).
# Reads /system read-only, copies the modem firmware into the modem's RAM through /dev/vmodem,
# then asks the vmodem driver to start VM 1. Writes nothing to flash.
B=/system/bin/busybox
D=/data/local/tmp/stall
$B mkdir -p $D
L=$D/modem.log
log() { echo "$($B cut -d' ' -f1 /proc/uptime) $*" >> $L; }

FW=modem.fls_ID0_CUST_LoadMap0.bin
M=/mnt/sysro
$B mkdir -p $M
# Mounted elsewhere than /system: the ramdisk's /system holds busybox and sh.
if $B mount -t ext4 -o ro,noload /dev/block/platform/soc0/e0000000.noc/by-name/ImcPartID068 $M >> $L 2>&1; then
  log "system mounted ro"
else
  log "system mount FAILED"; exit 1
fi
log "state before: $($B cat /sys/class/misc/vmodem/modem_state)"
log "firmware: $($B ls -l $M/vendor/firmware/$FW)"
if $B cat $M/vendor/firmware/$FW > /dev/vmodem 2>> $L; then
  log "firmware written to /dev/vmodem"
else
  log "firmware write FAILED"; exit 1
fi
echo 1 > /sys/class/misc/vmodem/modem_state 2>> $L
log "modem_state write rc=$?"
i=0
while [ $i -lt 30 ]; do
  log "state: $($B cat /sys/class/misc/vmodem/modem_state)"
  $B sleep 1
  i=$((i+1))
done
$B umount $M 2>> $L && log "system unmounted"

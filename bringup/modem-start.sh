#!/system/bin/sh
# Start the modem VM in TWRP on the P021 without Android daemons, so cpu3 keeps running.
# Without a running modem VM the hypervisor stops running vcpu3 at ~57 s uptime (see README).
#
# Steps (no flash writes):
#   1. mount system (ImcPartID068) read-only, noload, at /mnt/sysro
#   2. copy the modem firmware into the modem's RAM through /dev/vmodem
#   3. write 1 to modem_state (driver reads NVM 022-024 read-only, calls mv_vm_start(1))
# Fallback: if the modem is not On within 10 s, take cpu3 offline (the old safe setup).
#
# Started by init as service modem_start (bringup/hybrid-71/init.rc). Log: /tmp/modem-start.log
B=/system/bin/busybox
L=/tmp/modem-start.log
FW=modem.fls_ID0_CUST_LoadMap0.bin
M=/mnt/sysro
STATE=/sys/class/misc/vmodem/modem_state
log() { echo "$($B cut -d' ' -f1 /proc/uptime) $*" >> $L; }

fallback() {
  log "FALLBACK: $1; taking cpu3 offline"
  echo 0 > /sys/devices/system/cpu/cpu3/online
  log "cpus online: $($B cat /sys/devices/system/cpu/online)"
  exit 1
}

log "modem-start begin, cpus online: $($B cat /sys/devices/system/cpu/online)"
[ -w /dev/vmodem ] || fallback "/dev/vmodem missing"
log "state before: $($B cat $STATE)"

$B mkdir -p $M
# Not /system: the ramdisk's /system holds busybox and sh.
$B mount -t ext4 -o ro,noload /dev/block/platform/soc0/e0000000.noc/by-name/ImcPartID068 $M >> $L 2>&1 \
  || fallback "system mount failed"
if [ ! -f $M/vendor/firmware/$FW ]; then
  $B umount $M; fallback "firmware not found"
fi
if ! $B cat $M/vendor/firmware/$FW > /dev/vmodem 2>> $L; then
  $B umount $M; fallback "firmware write failed"
fi
log "firmware written ($($B stat -c %s $M/vendor/firmware/$FW) bytes)"
$B umount $M >> $L 2>&1 && log "system unmounted"

echo 1 > $STATE 2>> $L
log "modem_state write rc=$?"
i=0
while [ $i -lt 10 ]; do
  if [ "$($B cat $STATE)" = "On" ]; then
    log "modem On; keeping all cpus: $($B cat /sys/devices/system/cpu/online)"
    exit 0
  fi
  $B sleep 1
  i=$((i+1))
done
fallback "modem still $($B cat $STATE) after 10 s"

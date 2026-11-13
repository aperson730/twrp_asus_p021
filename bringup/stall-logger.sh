#!/system/bin/sh
# Stall logger for the P021 4-core test. Run pinned to cpu0:
#   busybox setsid busybox taskset 0x1 sh /data/local/tmp/stall-logger.sh
# Every 2 s appends per-CPU times, timer/IPI counts, and the context-switch counts of the
# per-CPU kernel threads (watchdog/N, ksoftirqd/N, migration/N) plus recovery and adbd.
# If a CPU stops running, its threads' counts stop increasing.
B=/system/bin/busybox
D=/data/local/tmp/stall
$B mkdir -p $D
L=$D/log.txt
echo "logger start $($B cat /proc/uptime) on cpu mask $($B taskset -p $$ 2>&1)" >> $L

# Find the per-CPU kernel threads once
PIDS=""
for s in /proc/[0-9]*/comm; do
  c=$($B cat $s 2>/dev/null)
  case "$c" in
    watchdog/*|ksoftirqd/*|migration/*|recovery|adbd) p=${s#/proc/}; PIDS="$PIDS ${p%/comm}";;
  esac
done
echo "tracked pids:$PIDS" >> $L

while true; do
  {
    echo "=== up $($B cat /proc/uptime)"
    $B grep "^cpu[0-9]" /proc/stat
    $B grep -E "CapCom|STM|RES|CAL|TLB" /proc/interrupts
    for p in $PIDS; do
      [ -r /proc/$p/stat ] || continue
      n=$($B cat /proc/$p/comm)
      st=$($B cut -d' ' -f3 /proc/$p/stat)
      cpu=$($B cut -d' ' -f39 /proc/$p/stat)
      sw=$($B grep -E "^(voluntary|nonvoluntary)_ctxt_switches" /proc/$p/status | $B tr -s ' \t' ' ' | $B cut -d' ' -f2 | $B tr '\n' '/')
      echo "T $p $n state=$st cpu=$cpu sw=$sw"
    done
    [ -r /proc/sched_debug ] && $B grep -E "^cpu#|\.nr_running|\.curr->pid" /proc/sched_debug
  } >> $L 2>&1
  $B sync
  $B sleep 2
done

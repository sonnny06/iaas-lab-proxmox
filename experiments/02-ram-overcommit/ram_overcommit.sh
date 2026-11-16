#!/bin/bash
# ram_overcommit.sh - chay tren Proxmox host
set -u
D=/root/iaas-lab/experiments/02-ram-overcommit
OUT=$D/raw; mkdir -p "$OUT"

IDS=(101 102 103 104)
CFGS=(0.5:off 1.0:off 1.5:off 1.5:balloon)   # ty le tong RAM cap / RAM host : che do balloon
RUNS=3; DUR=45
declare -A IP=( [101]=10.10.1.11 [102]=10.10.1.12 [103]=10.10.2.11 [104]=10.10.1.20 )
S="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=10"
N=${#IDS[@]}
H=$(free -m | awk '/^Mem:/{print $2}')

[ "$(awk '/SwapTotal/{print $2}' /proc/meminfo)" -gt 0 ] || { echo "Host khong co swap, dung lai"; exit 1; }

wait_ssh() { for i in $(seq 1 60); do $S lab@$1 true 2>/dev/null && return 0; sleep 3; done; echo "TIMEOUT $1"; return 1; }

cycle_vms() {
  for id in "${IDS[@]}"; do qm shutdown $id --timeout 60 >/dev/null 2>&1 || qm stop $id >/dev/null 2>&1; done
  for id in "${IDS[@]}"; do while [ "$(qm status $id | awk '{print $2}')" != "stopped" ]; do sleep 2; done; done
  for id in "${IDS[@]}"; do qm set $id --memory $M --balloon $BAL --cores 1 --cpulimit 1 >/dev/null; qm start $id; done
  for id in "${IDS[@]}"; do wait_ssh ${IP[$id]}; done
  sleep $SETTLE
}

for CFG in "${CFGS[@]}"; do
  K=${CFG%%:*}; MODE=${CFG##*:}
  M=$(awk -v k=$K -v h=$H -v n=$N 'BEGIN{printf "%d", k*h/n}')
  if [ "$MODE" = off ]; then BAL=0; SETTLE=30; else BAL=$((M/2)); SETTLE=120; fi
  TAG=k${K}_${MODE}
  echo "=== $TAG: host=${H}MB, moi VM=${M}MB, tong=$((M*N))MB, balloon_min=$BAL ==="
  for run in $(seq 1 $RUNS); do
    cycle_vms
    echo "  run $run"
    sync; echo 3 > /proc/sys/vm/drop_caches
    GM=$($S lab@${IP[101]} "free -m | awk '/^Mem:/{print \$2}'")
    SW0=$(free -m | awk '/^Swap:/{print $3}')
    OOM0=$(dmesg | grep -ci -E 'out of memory|oom-kill')
    vmstat 1 $((DUR+2)) > $OUT/host_vmstat_${TAG}_run$run.txt &
    for id in "${IDS[@]}"; do
      ping -c $DUR -i 1 -q ${IP[$id]} > $OUT/ping_${TAG}_vm${id}_run$run.txt 2>&1 &
      $S lab@${IP[$id]} "stress-ng --vm 1 --vm-bytes 80% --vm-keep --timeout ${DUR}s --metrics-brief 2>&1" \
         > $OUT/vm_${TAG}_vm${id}_run$run.txt 2>&1 &
    done
    wait
    SW1=$(free -m | awk '/^Swap:/{print $3}')
    OOM1=$(dmesg | grep -ci -E 'out of memory|oom-kill')
    ALIVE=0; for id in "${IDS[@]}"; do $S lab@${IP[$id]} true 2>/dev/null && ALIVE=$((ALIVE+1)); done
    echo "$H $M $((M*N)) $SW0 $SW1 $((OOM1-OOM0)) $ALIVE $GM" > $OUT/meta_${TAG}_run$run.txt
    sleep 15
  done
done
echo "Xong. Du lieu trong $OUT"

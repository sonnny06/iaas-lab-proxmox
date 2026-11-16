#!/bin/bash
# cpu_overcommit.sh - chay tren Proxmox host
set -u
D=/root/iaas-lab/experiments/01-cpu-overcommit
OUT=$D/raw; mkdir -p "$OUT"

# ---- SUA THEO BANG O BUOC 0 ----
IDS=(101 102) # Chỉ chạy 2 VM này vì máy có 2 CPU 
CLIST=(1 2) # số vCPU mỗi VM 
# --------------------------------
RUNS=3; DUR=60
declare -A IP=( [101]=10.10.1.11 [102]=10.10.1.12 [103]=10.10.2.11 [104]=10.10.1.20 )
S="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5"
P=$(nproc); N=${#IDS[@]}

wait_ssh() { for i in $(seq 1 60); do $S lab@$1 true 2>/dev/null && return 0; sleep 3; done; echo "TIMEOUT $1"; return 1; }

for C in "${CLIST[@]}"; do
  echo "=== C=$C vCPU/VM, N=$N VM, tong=$((C*N)) vCPU, pCPU=$P ==="
  for id in "${IDS[@]}"; do qm shutdown $id --timeout 90 >/dev/null 2>&1 || qm stop $id; done
  for id in "${IDS[@]}"; do while [ "$(qm status $id | awk '{print $2}')" != "stopped" ]; do sleep 2; done; done
  for id in "${IDS[@]}"; do qm set $id --cores $C --cpulimit 0 >/dev/null; qm start $id; done
  for id in "${IDS[@]}"; do wait_ssh ${IP[$id]}; done
  sleep 60                                   # cho he thong yen
  for run in $(seq 1 $RUNS); do
    echo "  run $run"
    vmstat 1 $((DUR+2)) > $OUT/host_vmstat_c${C}_run$run.txt &
    for id in "${IDS[@]}"; do
      ( $S lab@${IP[$id]} "vmstat 1 $((DUR+2)) > /tmp/vm.txt 2>&1 & stress-ng --cpu $C --timeout ${DUR}s --metrics-brief 2>&1; wait" \
          > $OUT/cpu_c${C}_vm${id}_run$run.txt
        $S lab@${IP[$id]} "cat /tmp/vm.txt" > $OUT/vmstat_c${C}_vm${id}_run$run.txt ) &
    done
    wait
    sleep 20
  done
done
echo "Xong. Du lieu trong $OUT"

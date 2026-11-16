#!/bin/bash
# baseline.sh - chay tren Proxmox host, do VM web chay mot minh
set -u
OUT=/root/iaas-lab/experiments/00-baseline/raw
mkdir -p "$OUT"
S="ssh -o StrictHostKeyChecking=no -o BatchMode=yes"
WEB=10.10.1.11; DB=10.10.2.11; CLI=10.10.1.20

# bat iperf3 server tren web va db
for h in $WEB $DB; do $S lab@$h 'pkill iperf3 || true; iperf3 -s -D'; done

for run in 1 2 3; do
  echo "=== run $run ==="

  # 1) CPU 60s + do steal bang vmstat
  $S lab@$WEB '(vmstat 1 62 > /tmp/vmstat.txt 2>&1 < /dev/null &); stress-ng --cpu 1 --timeout 60s --metrics-brief' \
     > "$OUT/cpu_run$run.txt" 2>&1
  sleep 4
  scp -q -o StrictHostKeyChecking=no lab@$WEB:/tmp/vmstat.txt "$OUT/cpu_vmstat_run$run.txt"

  # 2) I/O: randread 4k, randwrite 4k, doc tuan tu 1M
  for job in randread:4k randwrite:4k read:1M; do
    RW=${job%%:*}; BS=${job##*:}
    $S lab@$WEB "fio --name=t --filename=/home/lab/fio.test --rw=$RW --bs=$BS --size=512M \
      --runtime=30 --time_based --ioengine=libaio --iodepth=16 --direct=1 \
      --output-format=json --output=/tmp/fio.json >/dev/null 2>&1; cat /tmp/fio.json" \
      > "$OUT/fio_${RW}_${BS}_run$run.json"
  done

  # 3) Mang: cung bridge (client->web) va qua router (client->db)
  $S lab@$CLI "iperf3 -c $WEB -t 20 -J" > "$OUT/iperf_same_run$run.json"
  $S lab@$CLI "iperf3 -c $DB  -t 20 -J" > "$OUT/iperf_routed_run$run.json"
  $S lab@$CLI "ping -c 30 -i 0.2 $WEB"  > "$OUT/ping_same_run$run.txt"
  $S lab@$CLI "ping -c 30 -i 0.2 $DB"   > "$OUT/ping_routed_run$run.txt"
done

# don dep
$S lab@$WEB 'rm -f /home/lab/fio.test'
for h in $WEB $DB; do $S lab@$h 'pkill iperf3 || true'; done
echo "Xong. Ket qua trong $OUT"

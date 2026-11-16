#!/bin/bash
# noisy_neighbor.sh <cpu|io|net> - chay tren Proxmox host
set -u
SC=${1:?"dung: noisy_neighbor.sh cpu|io|net"}
D=/root/iaas-lab/experiments/03-noisy-neighbor
OUT=$D/raw; mkdir -p "$OUT"
P=$(nproc)
VIC=101; NOI=105
VIP=10.10.1.11; NIP=10.10.1.30; CIP=10.10.1.20; SIP=10.10.1.12
RUNS=3; DUR=45
S="ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=10"
MAC=$(qm config $NOI | sed -n 's/^net0: virtio=\([^,]*\).*/\1/p')
[ -n "$MAC" ] || { echo "Khong thay VM $NOI"; exit 1; }
case $SC in
  cpu) STATES="alone noisy cpulimit cpuunits";;
  io|net) STATES="alone noisy limited";;
  *) echo "kich ban sai"; exit 1;;
esac

wait_ssh() { for i in $(seq 1 60); do $S lab@$1 true 2>/dev/null && return 0; sleep 3; done; echo "TIMEOUT $1"; return 1; }
stop_vm() { qm shutdown $1 --timeout 60 >/dev/null 2>&1 || qm stop $1 >/dev/null 2>&1
            while [ "$(qm status $1 | awk '{print $2}')" != "stopped" ]; do sleep 2; done; }

apply_state() {
  local ST=$1
  stop_vm $VIC; stop_vm $NOI
  # cau hinh trung tinh
  qm set $VIC --cores 1 --cpulimit 1 >/dev/null; qm set $VIC --delete cpuunits >/dev/null 2>&1
  qm set $NOI --cores $P --cpulimit 0 --memory 512 >/dev/null; qm set $NOI --delete cpuunits >/dev/null 2>&1
  qm set $NOI --scsi0 local-lvm:vm-$NOI-disk-0 >/dev/null
  qm set $NOI --net0 virtio=$MAC,bridge=vmbr1 >/dev/null
  [ "$SC" = cpu ] && qm set $VIC --cores $P --cpulimit 0 >/dev/null
  # cau hinh rieng tung trang thai
  case "$SC:$ST" in
    cpu:cpulimit) qm set $NOI --cpulimit $(awk -v p=$P 'BEGIN{printf "%.2f", p/4}') >/dev/null;;
    cpu:cpuunits) qm set $VIC --cpuunits 800 >/dev/null; qm set $NOI --cpuunits 100 >/dev/null;;
    io:limited)   qm set $NOI --scsi0 local-lvm:vm-$NOI-disk-0,iops_wr=200,mbps_wr=10 >/dev/null;;
    net:limited)  qm set $NOI --net0 virtio=$MAC,bridge=vmbr1,rate=5 >/dev/null;;
  esac
  qm start $VIC >/dev/null; wait_ssh $VIP
  if [ "$ST" != alone ]; then qm start $NOI >/dev/null; wait_ssh $NIP; fi
  sleep 30
}

run_once() {
  local ST=$1 run=$2 tag=${SC}_${1}_run$2 NOISE=0
  [ "$ST" != alone ] && NOISE=1
  case $SC in
    cpu)
      [ $NOISE = 1 ] && { $S lab@$NIP "stress-ng --cpu $P --timeout $((DUR+10))s 2>&1" > $OUT/noise_$tag.txt 2>&1 & sleep 5; }
      ping -c $((DUR*5)) -i 0.2 $VIP > $OUT/ping_$tag.txt 2>&1 &
      $S lab@$VIP "stress-ng --cpu $P --timeout ${DUR}s --metrics-brief 2>&1" > $OUT/victim_$tag.txt 2>&1 &
      ;;
    io)
      [ $NOISE = 1 ] && { $S lab@$NIP "fio --name=n --filename=/home/lab/noise.n --rw=randwrite --bs=4k --size=1G --runtime=$((DUR+10)) --time_based --ioengine=libaio --iodepth=64 --numjobs=2 --direct=1 --group_reporting --output-format=json --output=/tmp/n.json >/dev/null 2>&1; cat /tmp/n.json" > $OUT/noise_$tag.json 2>&1 & sleep 5; }
      ping -c $((DUR*5)) -i 0.2 $VIP > $OUT/ping_$tag.txt 2>&1 &
      $S lab@$VIP "fio --name=v --filename=/home/lab/fio.v --rw=randread --bs=4k --size=512M --runtime=$DUR --time_based --ioengine=libaio --iodepth=16 --direct=1 --output-format=json --output=/tmp/v.json >/dev/null 2>&1; cat /tmp/v.json" > $OUT/victim_$tag.json 2>&1 &
      ;;
    net)
      $S lab@$VIP "pkill iperf3; iperf3 -s -D" >/dev/null 2>&1
      $S lab@$SIP "pkill iperf3; iperf3 -s -D" >/dev/null 2>&1
      [ $NOISE = 1 ] && { $S lab@$NIP "iperf3 -c $SIP -t $((DUR+10)) -P 4 -J" > $OUT/noise_$tag.json 2>&1 & sleep 5; }
      ping -c $((DUR*5)) -i 0.2 $VIP > $OUT/ping_$tag.txt 2>&1 &
      $S lab@$CIP "iperf3 -c $VIP -t $DUR -J" > $OUT/victim_$tag.json 2>&1 &
      ;;
  esac
  wait
  sleep 20
}

for ST in $STATES; do
  echo "=== $SC / $ST ==="
  apply_state $ST
  for run in $(seq 1 $RUNS); do echo "  run $run"; run_once $ST $run; done
done
echo "Xong $SC. Du lieu trong $OUT"

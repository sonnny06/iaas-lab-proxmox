#!/bin/bash
cd /root/iaas-lab/experiments/00-baseline/raw
echo "run,cpu_bogo_ops_s,steal_pct,randread_iops,randread_p99_us,randwrite_iops,seqread_MiBps,iperf_same_Gbps,iperf_routed_Gbps,ping_same_ms,ping_routed_ms" | tee ../results.csv
for r in 1 2 3; do
  cpu=$(grep -E ' cpu +[0-9]' cpu_run$r.txt | awk '{print $(NF-1)}')
  st=$(awk 'NR>2{s+=$17;n++} END{printf "%.2f", s/n}' cpu_vmstat_run$r.txt)
  rri=$(jq '.jobs[0].read.iops|floor' fio_randread_4k_run$r.json)
  rrl=$(jq '.jobs[0].read.clat_ns.percentile["99.000000"]/1000|floor' fio_randread_4k_run$r.json)
  rwi=$(jq '.jobs[0].write.iops|floor' fio_randwrite_4k_run$r.json)
  sr=$(jq '.jobs[0].read.bw/1024|floor' fio_read_1M_run$r.json)
  ips=$(jq '.end.sum_received.bits_per_second/1e9*100|floor/100' iperf_same_run$r.json)
  ipr=$(jq '.end.sum_received.bits_per_second/1e9*100|floor/100' iperf_routed_run$r.json)
  pgs=$(tail -1 ping_same_run$r.txt | awk -F'/' '{print $5}')
  pgr=$(tail -1 ping_routed_run$r.txt | awk -F'/' '{print $5}')
  echo "$r,$cpu,$st,$rri,$rrl,$rwi,$sr,$ips,$ipr,$pgs,$pgr" | tee -a ../results.csv
done

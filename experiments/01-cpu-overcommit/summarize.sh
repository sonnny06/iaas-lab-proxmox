#!/bin/bash
cd /root/iaas-lab/experiments/01-cpu-overcommit/raw
P=$(nproc)
IDS="101 102"      # Da sua lai chi con 2 may
CLIST="1 2"              # Da sua lai chi con 2 cau hinh
N=$(echo $IDS | wc -w)
echo "cores_per_vm,total_vcpu,ratio,run,vm,bogo_ops_s,bogo_per_vcpu,steal_pct" > ../results.csv
for C in $CLIST; do for run in 1 2 3; do for id in $IDS; do
  b=$(grep -E ' cpu +[0-9]' cpu_c${C}_vm${id}_run$run.txt | awk '{print $(NF-1)}')
  st=$(awk 'NR>3{s+=$17;n++} END{printf "%.2f", s/n}' vmstat_c${C}_vm${id}_run$run.txt)
  tot=$((C*N))
  echo "$C,$tot,$(awk -v t=$tot -v p=$P 'BEGIN{printf "%.2f",t/p}'),$run,$id,$b,$(awk -v b=$b -v c=$C 'BEGIN{printf "%.2f",b/c}'),$st" >> ../results.csv
done; done; done
awk -F, -v N=$N 'NR>1{n[$1]++; a[$1]+=$6; b[$1]+=$7; s[$1]+=$8; r[$1]=$3; t[$1]=$2}
 END{print "cores_per_vm,total_vcpu,ratio,mean_bogo_per_vcpu,total_bogo_all_vms,mean_steal_pct";
 for(c in n) printf "%s,%s,%s,%.2f,%.2f,%.2f\n", c,t[c],r[c],b[c]/n[c],a[c]/(n[c]/N),s[c]/n[c]}' ../results.csv | sort -t, -k1,1n | tee ../summary.csv

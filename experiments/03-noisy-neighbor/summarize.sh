#!/bin/bash
cd /root/iaas-lab/experiments/03-noisy-neighbor/raw
echo "scenario,state,run,victim_metric,victim_p99_us,ping_avg_ms,ping_p99_ms" > ../results.csv
for SC in cpu io net; do
  case $SC in cpu) STATES="alone noisy cpulimit cpuunits";; *) STATES="alone noisy limited";; esac
  for ST in $STATES; do for run in 1 2 3; do
    tag=${SC}_${ST}_run$run
    [ -f ping_$tag.txt ] || continue
    case $SC in
      cpu) m=$(grep -E ' cpu +[0-9]' victim_$tag.txt | awk '{print $(NF-1)}'); p=0;;
      io)  m=$(jq '.jobs[0].read.iops|floor' victim_$tag.json); p=$(jq '.jobs[0].read.clat_ns.percentile["99.000000"]/1000|floor' victim_$tag.json);;
      net) m=$(jq '.end.sum_received.bits_per_second/1e9*100|floor/100' victim_$tag.json); p=0;;
    esac
    pa=$(grep -oE 'time=[0-9.]+' ping_$tag.txt | cut -d= -f2 | awk '{s+=$1;n++} END{if(n)printf "%.3f",s/n; else print 0}')
    pp=$(grep -oE 'time=[0-9.]+' ping_$tag.txt | cut -d= -f2 | sort -n | awk '{a[NR]=$1} END{if(NR){i=int(NR*0.99); if(i<1)i=1; print a[i]} else print 0}')
    echo "$SC,$ST,$run,${m:-0},${p:-0},$pa,$pp" >> ../results.csv
  done; done
done
echo "scenario,state,mean_victim_metric,pct_of_alone,mean_p99_us,ping_avg_ms,ping_p99_ms" | tee ../summary.csv
awk -F, 'NR>1{k=$1","$2; n[k]++; m[k]+=$4; p[k]+=$5; a[k]+=$6; q[k]+=$7; sc[k]=$1}
 END{for(k in n){mm[k]=m[k]/n[k]}
  for(k in n){b=mm[sc[k]",alone"]; printf "%s,%.2f,%.1f,%.0f,%.3f,%.3f\n", k, mm[k], (b>0?mm[k]/b*100:0), p[k]/n[k], a[k]/n[k], q[k]/n[k]}}' ../results.csv | sort -t, -k1,1 -k2,2 | tee -a ../summary.csv

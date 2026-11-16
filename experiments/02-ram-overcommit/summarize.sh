#!/bin/bash
cd /root/iaas-lab/experiments/02-ram-overcommit/raw
echo "k,mode,run,total_alloc_MB,host_MB,guest_mem_MB,bogo_per_vm,swapout_MiB,swapin_MiB,wa_max,ping_avg_ms,ping_max_ms,loss_pct,oom_events,alive_vms" > ../results.csv
for CFG in 0.5:off 1.0:off 1.5:off 1.5:balloon; do
  K=${CFG%%:*}; MODE=${CFG##*:}; TAG=k${K}_${MODE}
  for run in 1 2 3; do
    read H M TOT SW0 SW1 OOM ALIVE GM < meta_${TAG}_run$run.txt
    bogo=$(for f in vm_${TAG}_vm*_run$run.txt; do grep -E ' vm +[0-9]' $f | awk '{print $(NF-1)}'; done | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n; else print 0}')
    so=$(awk 'NR>3{s+=$8} END{printf "%.1f", s/1024}' host_vmstat_${TAG}_run$run.txt)
    si=$(awk 'NR>3{s+=$7} END{printf "%.1f", s/1024}' host_vmstat_${TAG}_run$run.txt)
    wa=$(awk 'NR>3{if($16>m)m=$16} END{print m+0}' host_vmstat_${TAG}_run$run.txt)
    pa=$(for f in ping_${TAG}_vm*_run$run.txt; do grep rtt $f | awk -F'/' '{print $5}'; done | awk '{s+=$1;n++} END{if(n)printf "%.2f",s/n; else print 0}')
    pm=$(for f in ping_${TAG}_vm*_run$run.txt; do grep rtt $f | awk -F'/' '{print $6}'; done | awk '{if($1>m)m=$1} END{printf "%.2f",m}')
    loss=$(for f in ping_${TAG}_vm*_run$run.txt; do grep -oE '[0-9.]+% packet loss' $f | grep -oE '^[0-9.]+'; done | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n; else print 100}')
    echo "$K,$MODE,$run,$TOT,$H,$GM,$bogo,$so,$si,$wa,$pa,$pm,$loss,$OOM,$ALIVE" >> ../results.csv
  done
done
awk -F, 'NR>1{k=$1","$2; n[k]++; t[k]=$4; g[k]=$6; b[k]+=$7; so[k]+=$8; si[k]+=$9; if($10>w[k])w[k]=$10; pa[k]+=$11; if($12>pm[k])pm[k]=$12; l[k]+=$13; o[k]+=$14; if(!(k in al)||$15<al[k])al[k]=$15}
 END{print "k,mode,total_alloc_MB,guest_mem_MB,mean_bogo_per_vm,mean_swapout_MiB,mean_swapin_MiB,max_wa_pct,mean_ping_avg_ms,max_ping_ms,mean_loss_pct,oom_events_total,min_alive_vms";
 for(k in n) printf "%s,%s,%s,%.1f,%.1f,%.1f,%d,%.2f,%.2f,%.1f,%d,%d\n", k,t[k],g[k],b[k]/n[k],so[k]/n[k],si[k]/n[k],w[k],pa[k]/n[k],pm[k],l[k]/n[k],o[k],al[k]}' ../results.csv | sort -t, -k1,1n -k2,2 | tee ../summary.csv

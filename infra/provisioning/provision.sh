#!/bin/bash
# provision.sh - cap phat VM lab tu template
set -euo pipefail

TPL=9000
POOL=lab-pool
STORAGE=local-lvm
MAX_VMS=6          # quota: so VM toi da moi lan cap phat
MAX_RAM_MB=4096    # quota: tong RAM toi da

# ten | id | bridge | ip | gateway | cores | ram_mb
VMS=(
"lab-web-01|101|vmbr1|10.10.1.11/24|10.10.1.1|1|512"
"lab-app-01|102|vmbr1|10.10.1.12/24|10.10.1.1|1|512"
"lab-db-01|103|vmbr2|10.10.2.11/24|10.10.2.1|1|512"
"lab-client-01|104|vmbr1|10.10.1.20/24|10.10.1.1|1|512"
)

# --- kiem tra quota ---
total_ram=0
for v in "${VMS[@]}"; do
  IFS='|' read -r _ _ _ _ _ _ ram <<< "$v"
  total_ram=$((total_ram + ram))
done
[ "${#VMS[@]}" -le "$MAX_VMS" ] || { echo "VUOT QUOTA: so VM (${#VMS[@]} > $MAX_VMS)"; exit 1; }
[ "$total_ram" -le "$MAX_RAM_MB" ] || { echo "VUOT QUOTA: RAM ($total_ram > $MAX_RAM_MB MB)"; exit 1; }

# --- cap phat ---
for v in "${VMS[@]}"; do
  IFS='|' read -r NAME ID BR IP GW CORES RAM <<< "$v"
  if qm status "$ID" &>/dev/null; then
    echo "[skip] $NAME ($ID) da ton tai"; continue
  fi
  echo "[create] $NAME ($ID) -> $BR $IP"
  qm clone "$TPL" "$ID" --name "$NAME" --pool "$POOL"
  qm set "$ID" --net0 "virtio,bridge=$BR" --ipconfig0 "ip=$IP,gw=$GW" \
     --cores "$CORES" --memory "$RAM" --cpulimit "$CORES" --tags lab
  qm set "$ID" --scsi0 "$STORAGE:vm-$ID-disk-0,mbps_rd=100,mbps_wr=100"
  qm start "$ID"
done
echo "Hoan tat."

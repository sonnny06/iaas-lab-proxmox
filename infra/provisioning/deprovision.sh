#!/bin/bash
# deprovision.sh - thu hoi VM lab
for ID in 101 102 103 104; do
  if qm status "$ID" &>/dev/null; then
    echo "[destroy] $ID"
    qm stop "$ID" 2>/dev/null || true
    qm destroy "$ID" --purge
  fi
done

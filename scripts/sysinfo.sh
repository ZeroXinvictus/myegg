#!/bin/bash

bytes_to_human() {
  awk -v b="$1" 'BEGIN{split("B KiB MiB GiB TiB",u," ");i=1;while(b>=1024&&i<5){b/=1024;i++}printf "%.1f%s",b,u[i]}'
}

get_container_memory() {
  local used limit
  if [ -f /sys/fs/cgroup/memory.current ]; then used=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then used=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)
  fi
  [ -z "$used" ] && { echo "unknown"; return; }
  if [ -n "$SERVER_MEMORY" ] && [ "$SERVER_MEMORY" != "0" ]; then
    limit=$(bytes_to_human "$((SERVER_MEMORY * 1024 * 1024))")
  elif [ -f /sys/fs/cgroup/memory.max ]; then
    local raw; raw=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
    if [ "$raw" = "max" ] || [ -z "$raw" ]; then limit="unlimited"; else limit=$(bytes_to_human "$raw"); fi
  else
    limit="unlimited"
  fi
  echo "$(bytes_to_human "$used") / $limit"
}

get_server_address() {
  if [ -n "$SERVER_IP" ] && [ -n "$SERVER_PORT" ]; then echo "${SERVER_IP}:${SERVER_PORT}"
  elif [ -n "$SERVER_IP" ]; then echo "$SERVER_IP"
  else echo "unknown"
  fi
}

get_container_cpu_cores() {
  local quota period
  if [ -f /sys/fs/cgroup/cpu.max ]; then read -r quota period < /sys/fs/cgroup/cpu.max
  elif [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us); period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us)
  else nproc 2>/dev/null || echo "?"; return
  fi
  [ "$quota" = "max" ] || [ "$quota" = "-1" ] && { nproc 2>/dev/null || echo "?"; return; }
  awk -v q="$quota" -v p="$period" 'BEGIN{printf "%.1f",q/p}'
}

get_browser_path() {
  local engine="$1" dir exe
  dir=$(find /opt/browsers -maxdepth 1 -type d -iname "${engine}-*" 2>/dev/null | head -n1)
  [ -z "$dir" ] && { echo "not found"; return; }
  exe=$(find "$dir" -maxdepth 4 -type f -executable \( -iname "firefox" -o -iname "MiniBrowser" -o -iname "chrome" \) 2>/dev/null | head -n1)
  [ -n "$exe" ] && echo "$exe" || echo "$dir"
}

get_bexxcv_path() {
  find "${BEXXCV_HOME:-/opt/bexxcv}" -maxdepth 5 -type f -executable 2>/dev/null | head -n1
}

get_camoufox_path() {
  find "${CAMOUFOX_INSTALL_DIR:-/opt/camoufox}" -maxdepth 5 -type f -executable -iname 'camoufox' 2>/dev/null | head -n1
}

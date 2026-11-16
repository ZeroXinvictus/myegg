#!/bin/bash

bytes_to_human() {
  awk -v b="$1" 'BEGIN{
    split("B KiB MiB GiB TiB", units, " ")
    i=1
    while (b>=1024 && i<5) { b/=1024; i++ }
    printf "%.1f%s", b, units[i]
  }'
}

get_memory_used_bytes() {
  if [ -f /sys/fs/cgroup/memory.current ]; then
    cat /sys/fs/cgroup/memory.current 2>/dev/null
  elif [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
    cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null
  fi
}

get_memory_limit_bytes() {
  local limit_raw=""

  if [ -n "$SERVER_MEMORY" ] && [ "$SERVER_MEMORY" != "0" ]; then
    echo $((SERVER_MEMORY * 1024 * 1024))
    return
  fi

  if [ -f /sys/fs/cgroup/memory.max ]; then
    limit_raw=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)
  elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
    limit_raw=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
  fi

  if [ -z "$limit_raw" ] || [ "$limit_raw" = "max" ] || [ "$limit_raw" -ge 9000000000000000000 ] 2>/dev/null; then
    echo 0
  else
    echo "$limit_raw"
  fi
}

get_container_memory() {
  local used limit
  used=$(get_memory_used_bytes)
  [ -z "$used" ] && { echo "unknown"; return; }
  limit=$(get_memory_limit_bytes)
  if [ "$limit" -gt 0 ] 2>/dev/null; then
    echo "$(bytes_to_human "$used") / $(bytes_to_human "$limit")"
  else
    echo "$(bytes_to_human "$used") / unlimited"
  fi
}

get_memory_percent() {
  local used limit
  used=$(get_memory_used_bytes)
  [ -z "$used" ] && { echo "-1"; return; }
  limit=$(get_memory_limit_bytes)
  if [ "$limit" -gt 0 ] 2>/dev/null; then
    awk -v u="$used" -v l="$limit" 'BEGIN{printf "%d", (u/l)*100}'
  else
    echo "-1"
  fi
}

get_disk_usage() {
  df -h /home/container 2>/dev/null | awk 'NR==2 {print $3 " / " $2}'
}

get_disk_percent() {
  df /home/container 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5}'
}

get_server_address() {
  if [ -n "$SERVER_IP" ] && [ -n "$SERVER_PORT" ]; then
    echo "${SERVER_IP}:${SERVER_PORT}"
  elif [ -n "$SERVER_IP" ]; then
    echo "$SERVER_IP"
  else
    echo "unknown"
  fi
}

get_container_cpu_cores() {
  local quota period

  if [ -f /sys/fs/cgroup/cpu.max ]; then
    read -r quota period < /sys/fs/cgroup/cpu.max
    if [ "$quota" = "max" ]; then
      nproc 2>/dev/null || echo "?"
      return
    fi
  elif [ -f /sys/fs/cgroup/cpu/cpu.cfs_quota_us ]; then
    quota=$(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null)
    period=$(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null)
    if [ "$quota" = "-1" ]; then
      nproc 2>/dev/null || echo "?"
      return
    fi
  else
    nproc 2>/dev/null || echo "?"
    return
  fi

  awk -v q="$quota" -v p="$period" 'BEGIN{printf "%.1f", q/p}'
}

find_playwright_binary() {
  local engine="$1" pattern="$2"
  find /opt/browsers -maxdepth 4 -type f -path "/opt/browsers/${engine}-*" -name "$pattern" 2>/dev/null | sort -V | tail -n1
}

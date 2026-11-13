#!/bin/bash

print_banner() {
  local cpu ram disk_used disk_total
  cpu=$(get_container_cpu_cores)
  ram=$(get_container_memory)
  disk_used=$(df -h /home/container 2>/dev/null | awk 'NR==2 {print $3}')
  disk_total=$(df -h /home/container 2>/dev/null | awk 'NR==2 {print $2}')
  printf '\n%s╭──────────────────────────────────────────────╮%s\n' "$C_ACCENT" "$C_RESET"
  printf '%s│%s  %sZeroXinvictus%s  %s/  MyEgg Runtime%s          %s│%s\n' "$C_ACCENT" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_ACCENT" "$C_RESET"
  printf '%s╰──────────────────────────────────────────────╯%s\n' "$C_ACCENT" "$C_RESET"
  ui_section "System"
  ui_row "CPU" "${cpu} cores"
  ui_row "RAM" "$ram"
  ui_row "Disk" "${disk_used} / ${disk_total}"
}

print_runtime_status() {
  ui_section "Runtime"
  command -v node >/dev/null 2>&1 && ui_check_ver "Node.js" true "$(node -v)" || ui_check_ver "Node.js" false ""
  command -v bun >/dev/null 2>&1 && ui_check_ver "Bun" true "v$(bun --version)" || ui_check_ver "Bun" false ""
  command -v python3 >/dev/null 2>&1 && ui_check_ver "Python" true "v$(python3 --version | awk '{print $2}')" || ui_check_ver "Python" false ""
  command -v php >/dev/null 2>&1 && ui_check_ver "PHP" true "v$(php -v | head -n1 | awk '{print $2}')" || ui_check_ver "PHP" false ""
  command -v go >/dev/null 2>&1 && ui_check_ver "Go" true "$(go version | awk '{print $3}')" || ui_check_ver "Go" false ""
  command -v rustc >/dev/null 2>&1 && ui_check_ver "Rust" true "v$(rustc --version | awk '{print $2}')" || ui_check_ver "Rust" false ""
  command -v java >/dev/null 2>&1 && ui_check_ver "JDK" true "$(java -version 2>&1 | head -n1 | sed 's/.*version \"\([^\"]*\)\".*/\1/')" || ui_check_ver "JDK" false ""
  command -v adb >/dev/null 2>&1 && ui_check_ver "Android SDK" true "$(adb version | awk 'NR==1 {print $1" "$5}')" || ui_check_ver "Android SDK" false ""
}

print_access_info() {
  local port="${APP_PORT:-3000}" addr
  addr=$(get_server_address)
  ui_section "Access"
  ui_row "App" "http://${SERVER_IP:-$addr}:${port}"
  [ -n "$DETECTED_RUNTIME" ] && [ "$DETECTED_RUNTIME" != "Unknown" ] && ui_ok "Runtime: ${DETECTED_RUNTIME}"
}

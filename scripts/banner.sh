#!/bin/bash

print_banner() {
  local mem_pct disk_pct

  mem_pct=$(get_memory_percent)
  disk_pct=$(get_disk_percent)

  ui_section "Sistem"
  ui_row "cpu" "$(get_container_cpu_cores) core"
  ui_gauge "ram" "${mem_pct:--1}" "$(get_container_memory)"
  ui_gauge "disk" "${disk_pct:--1}" "$(get_disk_usage)"
}

print_runtime_status() {
  local node_ver bun_ver python_ver php_ver go_ver rust_ver gcc_ver java_ver

  ui_section "Runtime"

  if command -v node >/dev/null 2>&1; then
    node_ver=$(node -v 2>/dev/null)
    ui_check_ver "node" "true" "${node_ver} · npm $(npm -v 2>/dev/null)"
  else
    ui_check_ver "node" "false" ""
  fi

  if command -v bun >/dev/null 2>&1; then
    bun_ver=$(bun --version 2>/dev/null)
    ui_check_ver "bun" "true" "v${bun_ver}"
  else
    ui_check_ver "bun" "false" ""
  fi

  if command -v python3 >/dev/null 2>&1; then
    python_ver=$(python3 --version 2>/dev/null | awk '{print $2}')
    ui_check_ver "python" "true" "v${python_ver}"
  else
    ui_check_ver "python" "false" ""
  fi

  if command -v php >/dev/null 2>&1; then
    php_ver=$(php -v 2>/dev/null | head -n1 | awk '{print $2}')
    ui_check_ver "php" "true" "v${php_ver}"
  else
    ui_check_ver "php" "false" ""
  fi

  if command -v go >/dev/null 2>&1; then
    go_ver=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go/v/')
    ui_check_ver "go" "true" "$go_ver"
  else
    ui_check_ver "go" "false" ""
  fi

  if command -v rustc >/dev/null 2>&1; then
    rust_ver=$(rustc --version 2>/dev/null | awk '{print $2}')
    ui_check_ver "rust" "true" "v${rust_ver}"
  else
    ui_check_ver "rust" "false" ""
  fi

  if command -v gcc >/dev/null 2>&1; then
    gcc_ver=$(gcc -dumpversion 2>/dev/null)
    ui_check_ver "c / c++" "true" "gcc ${gcc_ver}"
  else
    ui_check_ver "c / c++" "false" ""
  fi

  if command -v java >/dev/null 2>&1; then
    java_ver=$(java -version 2>&1 | head -n1 | grep -oE '[0-9]+(\.[0-9]+)*' | head -n1)
    ui_check_ver "java" "true" "v${java_ver}"
  else
    ui_check_ver "java" "false" ""
  fi
}

print_browser_status() {
  local ver

  ui_section "Browser"

  if [ -n "$CHROME_BIN" ]; then
    ver=$(browser_version_of "$CHROME_BIN")
    ui_check_ver "chromium" "true" "${ver:-ready}"
  else
    ui_check_ver "chromium" "false" ""
  fi

  if [ -n "$FIREFOX_BIN" ]; then
    ver=$(browser_version_of "$FIREFOX_BIN")
    ui_check_ver "firefox" "true" "${ver:-ready}"
  else
    ui_check_ver "firefox" "false" ""
  fi

  if [ -n "$WEBKIT_BIN" ]; then
    ui_check_ver "webkit" "true" "ready"
  else
    ui_check_ver "webkit" "false" ""
  fi

  ui_check_ver "camoufox" "$CAMOUFOX_PY_READY" "python · ~/.cache/camoufox"
  ui_check_ver "camoufox-js" "$CAMOUFOX_JS_READY" "node · ${CAMOUFOX_INSTALL_DIR}"
}

print_android_status() {
  [ "$ANDROID_SDK_STATE" = "absent" ] && return 0

  ui_section "Android SDK"
  ui_row "home" "$ANDROID_HOME"
  ui_row "mode" "$([ "$ANDROID_SDK_STATE" = "overlay" ] && echo "bawaan + ANDROID_PACKAGES" || echo "bawaan image")"
  ui_row "platforms" "$(list_android_components platforms)"
  ui_row "build-tools" "$(list_android_components build-tools)"
  if command -v adb >/dev/null 2>&1; then
    ui_row "adb" "$(adb version 2>/dev/null | awk 'NR==1 {print $5}')"
  fi
}

print_access_info() {
  local port="${APP_PORT:-3000}" addr host tunnel_id

  addr=$(get_server_address)
  host="${SERVER_IP:-$addr}"

  ui_section "Akses"
  ui_row "app" "http://${host}:${port}"

  if [ "$ENABLE_CF_TUNNEL" = "true" ] && [ -n "$CF_TOKEN" ]; then
    tunnel_id=$(echo "$CF_TOKEN" | base64 -d 2>/dev/null | jq -r '.t // empty' 2>/dev/null)
    [ -n "$tunnel_id" ] && ui_row "tunnel" "${tunnel_id}.cfargotunnel.com"
  fi

  if [ -n "$WEB_TERMINAL_PID" ]; then
    ui_row "terminal" "http://${host}:${WEB_TERMINAL_PORT:-7681}"
  fi

  if [ -n "$DETECTED_RUNTIME" ] && [ "$DETECTED_RUNTIME" != "Unknown" ]; then
    ui_row "terdeteksi" "$DETECTED_RUNTIME"
  fi
}

#!/bin/bash

run_config_check() {
  local warnings=()
  [ "$HEADLESS_MODE" = "false" ] && ! command -v xvfb-run >/dev/null 2>&1 && warnings+=("HEADLESS_MODE=false tetapi xvfb-run tidak tersedia")
  [ -z "$SERVER_IP" ] && warnings+=("SERVER_IP tidak tersedia dari Wings")
  [ "$STATIC_HOST_MODE" = "true" ] && [ -n "$STARTUP_CMD" ] && warnings+=("Static Host Mode aktif; STARTUP_CMD akan diabaikan")
  [ "$STATIC_HOST_MODE" != "true" ] && [ -z "$STARTUP_CMD" ] && warnings+=("STARTUP_CMD kosong; container akan masuk shell")
  [ "$ENABLE_TELEGRAM_BACKUP" = "true" ] && { [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; } && warnings+=("Backup Telegram aktif tetapi kredensial belum lengkap")
  if [ "${#warnings[@]}" -gt 0 ]; then
    ui_section "Config Warnings"
    local item
    for item in "${warnings[@]}"; do ui_warn "$item"; done
  fi
}

#!/bin/bash

validate_cron_lines() {
  local line min hour dom mon dow cmd bad=0 n=0
  while IFS= read -r line; do
    n=$((n + 1))
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    case "$line" in
      @reboot\ *|@hourly\ *|@daily\ *|@midnight\ *|@weekly\ *|@monthly\ *) continue ;;
    esac
    read -r min hour dom mon dow cmd <<< "$line"
    if [ -z "$cmd" ]; then
      echo "baris ${n}"
      bad=1
    fi
  done <<< "$CRON_JOBS"
  return "$bad"
}

run_config_check() {
  local warnings=() errors=() invalid disk_pct

  if [ "$ENABLE_WEB_TERMINAL" = "true" ] && [ "${WEB_TERMINAL_PASSWORD:-changeme}" = "changeme" ]; then
    errors+=("Web Terminal tidak dijalankan: password masih 'changeme', ganti dulu")
  fi

  if [ "$ENABLE_CF_TUNNEL" = "true" ] && [ -z "$CF_TOKEN" ]; then
    errors+=("Cloudflare Tunnel aktif tapi CF_TOKEN kosong, tunnel tidak jalan")
  fi

  if [ "$ENABLE_TELEGRAM_BACKUP" = "true" ] && { [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; }; then
    errors+=("Backup Telegram aktif tapi Bot Token / Chat ID belum lengkap")
  fi

  if [ "$ENABLE_TELEGRAM_BACKUP" = "true" ] && [ "$ENABLE_AUTO_BACKUP" != "true" ]; then
    warnings+=("Backup Telegram aktif tapi Enable Auto Backup masih false, tidak ada yang terkirim")
  fi

  if [ "$ENABLE_BACKUP_ON_STOP" = "true" ] && [ "$ENABLE_AUTO_BACKUP" != "true" ]; then
    warnings+=("Backup Saat Server Stop butuh Enable Auto Backup = true")
  fi

  if [ "$HEADLESS_MODE" = "false" ] && ! command -v xvfb-run >/dev/null 2>&1; then
    errors+=("HEADLESS_MODE=false tapi xvfb-run tidak ada di image")
  fi

  if [ "$STATIC_HOST_MODE" = "true" ] && [ -n "$STARTUP_CMD" ]; then
    warnings+=("Static Host Mode aktif, STARTUP_CMD diabaikan")
  fi

  if [ "$STATIC_HOST_MODE" != "true" ] && [ -z "$STARTUP_CMD" ]; then
    warnings+=("STARTUP_CMD kosong dan Static Host Mode mati, server bakal drop ke shell")
  fi

  if [ -n "$ANDROID_PACKAGES" ] && [ "$ANDROID_SDK_STATE" = "absent" ]; then
    errors+=("ANDROID_PACKAGES diisi tapi Android SDK tidak ada di image (arsitektur bukan x86_64)")
  fi

  if [ -n "$ANDROID_PACKAGES" ] && [ "$ANDROID_SDK_STATE" = "baked" ]; then
    errors+=("Install ANDROID_PACKAGES gagal, pakai SDK bawaan image")
  fi

  if [ -n "$CRON_JOBS" ]; then
    invalid=$(validate_cron_lines | paste -sd',' - | sed 's/,/, /g')
    [ -n "$invalid" ] && warnings+=("CRON_JOBS format salah di ${invalid} (butuh 5 kolom jadwal + command)")
  fi

  disk_pct=$(get_disk_percent)
  if [ -n "$disk_pct" ] && [ "$disk_pct" -ge 90 ] 2>/dev/null; then
    warnings+=("Disk terpakai ${disk_pct}%, hapus file atau kurangi backup")
  fi

  case "$NODE_VERSION" in 22|24|26|'') ;; *) warnings+=("NODE_VERSION=${NODE_VERSION} di luar versi image (22/24/26)") ;; esac
  case "$PYTHON_VERSION" in 3.12|3.13|3.14|'') ;; *) warnings+=("PYTHON_VERSION=${PYTHON_VERSION} di luar versi image (3.12/3.13/3.14)") ;; esac
  case "$PHP_VERSION" in 8.2|8.3|8.4|8.5|'') ;; *) warnings+=("PHP_VERSION=${PHP_VERSION} di luar versi image (8.2-8.5)") ;; esac
  case "$JAVA_VERSION" in 17|21|'') ;; *) warnings+=("JAVA_VERSION=${JAVA_VERSION} di luar versi image (17/21)") ;; esac

  if [ "${#warnings[@]}" -eq 0 ] && [ "${#errors[@]}" -eq 0 ]; then
    return 0
  fi

  ui_section "Config"
  local w
  for w in "${errors[@]}"; do
    ui_err "$w"
  done
  for w in "${warnings[@]}"; do
    ui_warn "$w"
  done
}

#!/bin/bash

send_backup_to_telegram() {
  local file="$1" size_mb
  [ "$ENABLE_TELEGRAM_BACKUP" != "true" ] || [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ] || return 0
  size_mb=$(( $(stat -c%s "$file" 2>/dev/null || echo 0) / 1024 / 1024 ))
  [ "$size_mb" -le 49 ] || { ui_warn "backup ${size_mb}MB melewati batas upload Telegram"; return 1; }
  curl -s -o /tmp/telegram-backup.log -F "chat_id=${TELEGRAM_CHAT_ID}" -F "document=@${file}" -F "caption=ZeroXinvictus backup: $(basename "$file")" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
  grep -q '"ok":true' /tmp/telegram-backup.log 2>/dev/null && ui_ok "backup terkirim ke Telegram" || ui_err "backup Telegram gagal"
}

run_backup_once() {
  local dir="/home/container/.codex/backups" stamp target keep
  mkdir -p "$dir"
  stamp=$(date '+%Y%m%d-%H%M%S')
  target="$dir/backup-${stamp}.tar.gz"
  keep="${BACKUP_KEEP_COUNT:-5}"
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=5
  tar --exclude='./.codex/backups' -czf "$target" -C /home/container . 2>/dev/null
  ui_ok "backup dibuat: $(basename "$target") ($(bytes_to_human "$(stat -c%s "$target" 2>/dev/null || echo 0)"))"
  ls -1t "$dir"/backup-*.tar.gz 2>/dev/null | tail -n "+$((keep + 1))" | xargs -r rm -f
  send_backup_to_telegram "$target"
}

start_auto_backup() {
  [ "$ENABLE_AUTO_BACKUP" = "true" ] || return 0
  local hours="${BACKUP_INTERVAL_HOURS:-24}"
  (
    while true; do sleep "$((hours * 3600))"; run_backup_once; done
  ) &
  BACKUP_TICKER_PID=$!
  export BACKUP_TICKER_PID
}

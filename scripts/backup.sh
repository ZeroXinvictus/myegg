#!/bin/bash

TELEGRAM_PART_SIZE="45m"
TELEGRAM_MAX_PARTS=40

telegram_send_file() {
  local file="$1" caption="$2"
  curl -s -o /tmp/telegram-backup.log \
    -F "chat_id=${TELEGRAM_CHAT_ID}" \
    -F "document=@${file}" \
    -F "caption=${caption}" \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument"
  grep -q '"ok":true' /tmp/telegram-backup.log 2>/dev/null
}

send_backup_to_telegram() {
  local file="$1" name size part parts=() total i=0 split_dir
  [ "$ENABLE_TELEGRAM_BACKUP" != "true" ] && return 0
  [ -z "$TELEGRAM_BOT_TOKEN" ] && return 0
  [ -z "$TELEGRAM_CHAT_ID" ] && return 0

  name=$(basename "$file")
  size=$(stat -c%s "$file" 2>/dev/null || echo 0)

  if [ "$size" -le $((49 * 1024 * 1024)) ]; then
    if telegram_send_file "$file" "codex-tools backup: ${name}"; then
      ui_ok "backup terkirim ke Telegram: ${name}"
    else
      ui_err "gagal kirim backup ke Telegram, cek token dan chat id"
    fi
    return 0
  fi

  split_dir=$(mktemp -d /tmp/backup-split.XXXXXX)
  split -b "$TELEGRAM_PART_SIZE" -d -a 3 "$file" "${split_dir}/${name}.part"
  for part in "${split_dir}"/*; do parts+=("$part"); done
  total=${#parts[@]}

  if [ "$total" -gt "$TELEGRAM_MAX_PARTS" ]; then
    ui_warn "backup ${name} kebesaran (${total} bagian), skip upload Telegram"
    rm -rf "$split_dir"
    return 1
  fi

  for part in "${parts[@]}"; do
    i=$((i + 1))
    if ! telegram_send_file "$part" "codex-tools backup ${name} (${i}/${total}), gabung: cat ${name}.part* > ${name}"; then
      ui_err "gagal kirim bagian ${i}/${total} ke Telegram"
      rm -rf "$split_dir"
      return 1
    fi
  done

  rm -rf "$split_dir"
  ui_ok "backup terkirim ke Telegram dalam ${total} bagian: ${name}"
}

build_backup_excludes() {
  local list="${BACKUP_EXCLUDE-node_modules,.cache,.npm,.gradle,.android-sdk,.codex/state}" item
  BACKUP_EXCLUDE_ARGS=(--exclude="./.codex/backups")
  IFS=',' read -ra items <<< "$list"
  for item in "${items[@]}"; do
    item="${item// /}"
    [ -z "$item" ] && continue
    BACKUP_EXCLUDE_ARGS+=(--exclude="$item")
  done
}

run_backup_once() {
  local backup_dir="/home/container/.codex/backups" stamp target keep rc

  mkdir -p "$backup_dir"
  stamp=$(date '+%Y%m%d-%H%M%S')
  target="${backup_dir}/backup-${stamp}.tar.gz"
  keep="${BACKUP_KEEP_COUNT:-5}"
  case "$keep" in ''|*[!0-9]*) keep=5 ;; esac

  build_backup_excludes
  tar "${BACKUP_EXCLUDE_ARGS[@]}" -czf "$target" -C /home/container . 2>/tmp/backup-tar.log
  rc=$?
  if [ "$rc" -gt 1 ]; then
    ui_err "backup gagal (tar exit ${rc}): $(tail -n1 /tmp/backup-tar.log 2>/dev/null)"
    rm -f "$target"
    return 1
  fi

  ui_ok "backup dibuat: $(basename "$target") ($(bytes_to_human "$(stat -c%s "$target" 2>/dev/null || echo 0)"))"

  ls -1t "$backup_dir"/backup-*.tar.gz 2>/dev/null | tail -n "+$((keep + 1))" | xargs -r rm -f

  send_backup_to_telegram "$target"
}

start_auto_backup() {
  [ "$ENABLE_AUTO_BACKUP" != "true" ] && return 0
  local interval_hours="${BACKUP_INTERVAL_HOURS:-24}"
  case "$interval_hours" in ''|*[!0-9]*|0) interval_hours=24 ;; esac

  (
    while true; do
      sleep "$((interval_hours * 3600))"
      run_backup_once
    done
  ) &
  BACKUP_TICKER_PID=$!
  export BACKUP_TICKER_PID
}

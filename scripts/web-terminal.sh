#!/bin/bash

start_web_terminal() {
  [ "$ENABLE_WEB_TERMINAL" != "true" ] && return 0
  local port="${WEB_TERMINAL_PORT:-7681}" user="${WEB_TERMINAL_USER:-admin}" pass="${WEB_TERMINAL_PASSWORD:-changeme}"

  if [ "$pass" = "changeme" ]; then
    return 0
  fi

  if ! command -v ttyd >/dev/null 2>&1; then
    ui_err "ttyd tidak ditemukan, web terminal tidak dijalankan"
    return 0
  fi

  ttyd -p "$port" -c "${user}:${pass}" -W \
    -t fontSize=14 \
    -t 'theme={"background":"#101216","foreground":"#cfd3d9","cursor":"#4fb8a5"}' \
    bash >/tmp/ttyd.log 2>&1 &
  WEB_TERMINAL_PID=$!
  export WEB_TERMINAL_PID
}

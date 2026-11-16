#!/bin/bash

CD_TRIES=0
until cd /home/container 2>/tmp/cd-error.log; do
  CD_TRIES=$((CD_TRIES + 1))
  if [ "$CD_TRIES" -ge 10 ]; then
    echo "[boot] FATAL: /home/container tidak bisa diakses setelah ${CD_TRIES}x percobaan"
    cat /tmp/cd-error.log 2>/dev/null
    exit 1
  fi
  echo "[boot] /home/container belum siap, retry ${CD_TRIES}/10"
  sleep 1
done

SCRIPTS_TO_LOAD="theme identity sysinfo browsers android-sdk config-check banner log-rotate detect-runtime webhook backup web-terminal tunnel git-setup cron-runner"

for s in $SCRIPTS_TO_LOAD; do
  if [ ! -f "/scripts/${s}.sh" ]; then
    echo "[boot] FATAL: /scripts/${s}.sh tidak ditemukan di image"
    exit 1
  fi
  if ! source "/scripts/${s}.sh"; then
    echo "[boot] FATAL: gagal source /scripts/${s}.sh (kemungkinan file corrupt atau CRLF)"
    exit 1
  fi
done

APP_PID=""
SHUTTING_DOWN="false"

graceful_shutdown() {
  [ "$SHUTTING_DOWN" = "true" ] && return 0
  SHUTTING_DOWN="true"
  ui_warn "sinyal stop diterima, mematikan dengan rapi"
  send_webhook_notification stop
  if [ "$ENABLE_AUTO_BACKUP" = "true" ] && [ "$ENABLE_BACKUP_ON_STOP" = "true" ]; then
    run_backup_once
  fi
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill -TERM "$APP_PID" 2>/dev/null
    wait "$APP_PID" 2>/dev/null
  fi
  exit 0
}
trap graceful_shutdown SIGTERM SIGINT

setup_identity
clear 2>/dev/null
ui_header "codex-tools" "${TZ:-UTC}"

setup_git_repo
setup_runtime_paths
detect_and_setup_runtime
resolve_browsers
setup_android_sdk

start_web_terminal
start_cf_tunnel
start_auto_backup
send_webhook_notification start &
start_cron_runner
start_log_rotation

run_config_check
print_banner
print_runtime_status
print_browser_status
print_android_status

export HEADLESS_MODE="${HEADLESS_MODE:-true}"

FINAL_CMD="$STARTUP_CMD"
USE_SUPERVISOR="false"
PM_LABEL="off"

if [ "$STATIC_HOST_MODE" = "true" ]; then
  STATIC_DIR="${STATIC_HOST_DIR:-public}"
  mkdir -p "/home/container/${STATIC_DIR}"
  FINAL_CMD="python3 -m http.server ${APP_PORT:-3000} --directory ${STATIC_DIR} --bind 0.0.0.0"
  DETECTED_RUNTIME="Static host"
elif [ "$PROCESS_MANAGER" = "true" ] && [[ "$STARTUP_CMD" == node\ * ]]; then
  FINAL_CMD="pm2-runtime ${STARTUP_CMD#node }"
  PM_LABEL="pm2"
elif [ "$PROCESS_MANAGER" = "true" ] && [ -n "$STARTUP_CMD" ]; then
  USE_SUPERVISOR="true"
  PM_LABEL="supervisor"
fi

print_access_info

if [ -z "$FINAL_CMD" ]; then
  ui_warn "STARTUP_CMD kosong, masuk ke shell"
  exec /bin/bash
fi

XVFB_PREFIX=""
DISPLAY_LABEL="headless"
if [ "$HEADLESS_MODE" = "false" ]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    XVFB_PREFIX="xvfb-run -a --server-args=-screen\ 0\ 1280x1024x24\ -ac "
    DISPLAY_LABEL="xvfb 1280x1024"
  else
    ui_err "HEADLESS_MODE=false tapi xvfb-run tidak ada, lanjut tanpa display virtual"
  fi
fi

EXEC_CMD="${XVFB_PREFIX}${FINAL_CMD}"

ui_section "Start"
ui_row "perintah" "$FINAL_CMD"
ui_row "proses" "$PM_LABEL"
ui_row "display" "$DISPLAY_LABEL"
echo ""

if [ "$USE_SUPERVISOR" = "true" ]; then
  cat > /tmp/supervisord.conf << SUPERVISOR_EOF
[supervisord]
nodaemon=true
logfile=/tmp/supervisord.log
pidfile=/tmp/supervisord.pid

[program:app]
command=/bin/bash -lc '${EXEC_CMD}'
directory=/home/container
autostart=true
autorestart=true
startretries=999
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUPERVISOR_EOF
  supervisord -c /tmp/supervisord.conf &
  APP_PID=$!
else
  /bin/bash -lc "$EXEC_CMD" &
  APP_PID=$!
fi

wait "$APP_PID"
EXIT_CODE=$?

[ "$SHUTTING_DOWN" = "true" ] && exit 0

if [ "$EXIT_CODE" -eq 0 ]; then
  send_webhook_notification stop 0
else
  ui_err "aplikasi berhenti dengan exit code ${EXIT_CODE}"
  send_webhook_notification crash "$EXIT_CODE"
fi
exit "$EXIT_CODE"

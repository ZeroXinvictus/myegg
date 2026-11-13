#!/bin/bash

cd /home/container || exit 1

SCRIPTS_TO_LOAD="theme identity sysinfo config-check banner android detect-runtime git-setup backup cron-runner"
for s in $SCRIPTS_TO_LOAD; do
  [ -f "/scripts/${s}.sh" ] || { echo "[boot] missing /scripts/${s}.sh"; exit 1; }
  source "/scripts/${s}.sh" || { echo "[boot] failed loading ${s}.sh"; exit 1; }
done

APP_PID=""

graceful_shutdown() {
  ui_warn "shutdown requested"
  [ "$ENABLE_AUTO_BACKUP" = "true" ] && [ "$ENABLE_BACKUP_ON_STOP" = "true" ] && run_backup_once
  [ -n "$APP_PID" ] && kill -TERM "$APP_PID" 2>/dev/null || true
  [ -n "$APP_PID" ] && wait "$APP_PID" 2>/dev/null || true
  exit 0
}
trap graceful_shutdown SIGTERM SIGINT

setup_identity
setup_android_sdk
setup_runtime_paths
setup_git_repo
detect_and_setup_runtime
android_project_setup

export HEADLESS_MODE="${HEADLESS_MODE:-true}"
CHROME_BIN=$(find /opt/browsers -maxdepth 4 -type f -executable -name chrome 2>/dev/null | head -n1)
[ -n "$CHROME_BIN" ] && export PUPPETEER_EXECUTABLE_PATH="$CHROME_BIN" && export CHROME_PATH="$CHROME_BIN"

if [ "$STATIC_HOST_MODE" = "true" ]; then
  STATIC_DIR="${STATIC_HOST_DIR:-public}"
  mkdir -p "/home/container/${STATIC_DIR}"
  FINAL_CMD="python3 -m http.server ${APP_PORT:-3000} --directory ${STATIC_DIR} --bind 0.0.0.0"
elif [ -n "$STARTUP_CMD" ]; then
  FINAL_CMD="$STARTUP_CMD"
else
  FINAL_CMD=""
fi

if [ "$PROCESS_MANAGER" = "true" ] && [[ "$FINAL_CMD" == node\ * ]]; then
  FINAL_CMD="pm2-runtime ${FINAL_CMD#node }"
  USE_SUPERVISOR="false"
elif [ "$PROCESS_MANAGER" = "true" ] && [ -n "$FINAL_CMD" ]; then
  USE_SUPERVISOR="true"
else
  USE_SUPERVISOR="false"
fi

run_config_check
print_banner
print_runtime_status
print_access_info

ui_section "Browser"
ui_row "Chromium" "${PUPPETEER_EXECUTABLE_PATH:-$(find /opt/browsers -maxdepth 3 -type f -executable -name chrome 2>/dev/null | head -n1)}"
ui_row "Firefox" "$(get_browser_path firefox)"
ui_row "WebKit" "$(get_browser_path webkit)"
ui_row "Camoufox" "$(get_camoufox_path)"
ui_row "camoufox-js" "$(npm root -g 2>/dev/null)/camoufox-js"
ui_row "bexxcv" "$(npm root -g 2>/dev/null)/bexxcv"
ui_row "bexxcv CLI" "$(command -v bexxcv 2>/dev/null || echo not-found)"

ui_section "Android"
ui_row "SDK" "${ANDROID_SDK_ROOT:-not set}"
ui_row "Platform" "android-${ANDROID_PLATFORM_VERSION:-36}"
ui_row "Build Tools" "${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}"
ui_row "NDK" "${ANDROID_NDK_VERSION:-28.2.13676358}"

[ "$HEADLESS_MODE" = "false" ] && XVFB_PREFIX="xvfb-run -a --server-args=-screen\ 0\ 1280x1024x24\ -ac " || XVFB_PREFIX=""

if [ -z "$FINAL_CMD" ]; then
  ui_warn "No startup command; opening shell"
  exec /bin/bash
fi

EXEC_CMD="${XVFB_PREFIX}${FINAL_CMD}"
ui_section "Launch"
ui_row "Runtime" "${DETECTED_RUNTIME:-Unknown}"
ui_row "Command" "$EXEC_CMD"

if [ "$USE_SUPERVISOR" = "true" ]; then
  cat > /tmp/supervisord.conf <<SUPERVISOR_EOF
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
exit $?

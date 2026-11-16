#!/bin/bash

cron_field_match() {
  local field="$1" value="$2" part base lo hi step parts

  IFS=',' read -ra parts <<< "$field"
  for part in "${parts[@]}"; do
    if [ "$part" = "*" ]; then
      return 0
    elif [[ "$part" == */* ]]; then
      step="${part#*/}"
      base="${part%/*}"
      case "$step" in ''|*[!0-9]*|0) continue ;; esac
      if [ "$base" = "*" ]; then
        [ "$((value % step))" -eq 0 ] && return 0
      elif [[ "$base" == *-* ]]; then
        lo="${base%-*}"; hi="${base#*-}"
        case "$lo$hi" in *[!0-9]*) continue ;; esac
        if [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] && [ "$(((value - lo) % step))" -eq 0 ]; then
          return 0
        fi
      fi
    elif [[ "$part" == *-* ]]; then
      lo="${part%-*}"; hi="${part#*-}"
      case "$lo$hi" in *[!0-9]*) continue ;; esac
      [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] && return 0
    else
      [ "$part" = "$value" ] && return 0
    fi
  done
  return 1
}

cron_dow_match() {
  local field="$1" value="$2"
  cron_field_match "$field" "$value" && return 0
  [ "$value" = "0" ] && cron_field_match "$field" 7 && return 0
  return 1
}

cron_expand_alias() {
  case "$1" in
    @hourly)   echo "0 * * * *" ;;
    @daily|@midnight) echo "0 0 * * *" ;;
    @weekly)   echo "0 0 * * 0" ;;
    @monthly)  echo "0 0 1 * *" ;;
    *)         echo "$1" ;;
  esac
}

cron_run_job() {
  ui_info "cron: $1"
  bash -c "$1" >> /tmp/cron-runner.log 2>&1 &
}

cron_line_due() {
  local min="$1" hour="$2" dom="$3" mon="$4" dow="$5" day_ok=1

  cron_field_match "$min" "$now_min" || return 1
  cron_field_match "$hour" "$now_hour" || return 1
  cron_field_match "$mon" "$now_mon" || return 1

  if [ "$dom" != "*" ] && [ "$dow" != "*" ]; then
    cron_field_match "$dom" "$now_dom" || cron_dow_match "$dow" "$now_dow" || day_ok=0
  else
    cron_field_match "$dom" "$now_dom" || day_ok=0
    cron_dow_match "$dow" "$now_dow" || day_ok=0
  fi

  [ "$day_ok" -eq 1 ]
}

start_cron_runner() {
  [ -z "$CRON_JOBS" ] && return 0

  local line first rest
  while IFS= read -r line; do
    first="${line%% *}"
    rest="${line#* }"
    [ "$first" = "@reboot" ] && [ "$rest" != "$line" ] && cron_run_job "$rest"
  done <<< "$CRON_JOBS"

  (
    local last_minute=""
    while true; do
      local now_min now_hour now_dom now_mon now_dow current_stamp
      now_min=$(date +%-M)
      now_hour=$(date +%-H)
      now_dom=$(date +%-d)
      now_mon=$(date +%-m)
      now_dow=$(date +%w)
      current_stamp="${now_hour}:${now_min}"

      if [ "$current_stamp" != "$last_minute" ]; then
        last_minute="$current_stamp"

        while IFS= read -r line; do
          [ -z "$line" ] && continue
          [[ "$line" == \#* ]] && continue

          local min hour dom mon dow cmd spec
          first="${line%% *}"
          if [[ "$first" == @* ]]; then
            [ "$first" = "@reboot" ] && continue
            spec=$(cron_expand_alias "$first")
            cmd="${line#* }"
            [ "$cmd" = "$line" ] && continue
            read -r min hour dom mon dow <<< "$spec"
          else
            read -r min hour dom mon dow cmd <<< "$line"
          fi
          [ -z "$cmd" ] && continue

          cron_line_due "$min" "$hour" "$dom" "$mon" "$dow" && cron_run_job "$cmd"
        done <<< "$CRON_JOBS"
      fi

      sleep 20
    done
  ) &
  CRON_RUNNER_PID=$!
  export CRON_RUNNER_PID
}

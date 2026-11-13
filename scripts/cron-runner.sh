#!/bin/bash

cron_field_match() {
  local field="$1" value="$2" part base lo hi step
  IFS=',' read -ra parts <<< "$field"
  for part in "${parts[@]}"; do
    [ "$part" = "*" ] && return 0
    if [[ "$part" == */* ]]; then
      step="${part#*/}"; base="${part%/*}"; [[ "$step" =~ ^[0-9]+$ ]] || continue
      if [ "$base" = "*" ]; then [ "$((value % step))" -eq 0 ] && return 0
      elif [[ "$base" == *-* ]]; then
        lo="${base%-*}"; hi="${base#*-}"
        [[ "$lo$hi" =~ ^[0-9]+$ ]] && [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] && [ "$(((value-lo)%step))" -eq 0 ] && return 0
      fi
    elif [[ "$part" == *-* ]]; then
      lo="${part%-*}"; hi="${part#*-}"; [[ "$lo$hi" =~ ^[0-9]+$ ]] && [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] && return 0
    else
      [ "$part" = "$value" ] && return 0
    fi
  done
  return 1
}

start_cron_runner() {
  [ -z "$CRON_JOBS" ] && return 0
  (
    local last=""
    while true; do
      local m h d mo w stamp
      m=$(date +%-M); h=$(date +%-H); d=$(date +%-d); mo=$(date +%-m); w=$(date +%w); stamp="${h}:${m}"
      if [ "$stamp" != "$last" ]; then
        last="$stamp"
        while IFS= read -r line; do
          [ -z "$line" ] && continue; [[ "$line" == \#* ]] && continue
          local min hour dom mon dow cmd
          read -r min hour dom mon dow cmd <<< "$line"
          [ -z "$cmd" ] && continue
          cron_field_match "$min" "$m" && cron_field_match "$hour" "$h" && cron_field_match "$dom" "$d" && cron_field_match "$mon" "$mo" && cron_field_match "$dow" "$w" && { ui_info "cron -> ${cmd}"; /bin/bash -lc "$cmd" >>/tmp/cron-runner.log 2>&1 & }
        done <<< "$CRON_JOBS"
      fi
      sleep 20
    done
  ) &
  CRON_RUNNER_PID=$!
  export CRON_RUNNER_PID
}

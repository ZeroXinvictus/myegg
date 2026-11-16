#!/bin/bash

CODEX_VERSION="${CODEX_VERSION:-15}"
UI_WIDTH=52
LABEL_WIDTH=12
VALUE_MAX=$((UI_WIDTH - 2 - LABEL_WIDTH - 1))
GAUGE_CELLS=12

if [ -n "$NO_COLOR" ] || [ "$TERM" = "dumb" ]; then
  C_RESET="" C_BOLD="" C_ACCENT="" C_OK="" C_WARN="" C_ERR="" C_MUTED="" C_TEXT="" C_RULE=""
else
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_ACCENT=$'\033[38;2;79;184;165m'
  C_OK=$'\033[38;2;134;192;108m'
  C_WARN=$'\033[38;2;224;176;80m'
  C_ERR=$'\033[38;2;229;104;106m'
  C_MUTED=$'\033[38;2;116;122;134m'
  C_TEXT=$'\033[38;2;207;211;217m'
  C_RULE=$'\033[38;2;63;68;77m'
fi

_ui_repeat() {
  local char="$1" count="$2" out
  [ "$count" -le 0 ] && return 0
  printf -v out '%*s' "$count" ''
  printf '%s' "${out// /$char}"
}

_ui_truncate() {
  local str="$1" max="$2"
  if [ "${#str}" -le "$max" ]; then
    printf '%s' "$str"
  else
    printf '%s…' "${str:0:$((max - 1))}"
  fi
}

_ui_pad() {
  local str="$1" width="$2" pad=$((${2} - ${#1}))
  [ "$pad" -lt 0 ] && pad=0
  printf '%s%*s' "$str" "$pad" ""
}

ui_header() {
  local name="${1:-codex-tools}" meta="${2:-}" left right gap
  left="${name} ${CODEX_VERSION}"
  right="$meta"
  gap=$((UI_WIDTH - ${#left} - ${#right}))
  [ "$gap" -lt 1 ] && gap=1
  printf '%s%s%s%s %s%s%s%*s%s%s%s\n' \
    "$C_BOLD" "$C_ACCENT" "$name" "$C_RESET" \
    "$C_MUTED" "$CODEX_VERSION" "$C_RESET" \
    "$gap" "" "$C_MUTED" "$right" "$C_RESET"
  printf '%s%s%s\n' "$C_RULE" "$(_ui_repeat '─' "$UI_WIDTH")" "$C_RESET"
}

ui_section() {
  local title="$1" fill
  fill=$((UI_WIDTH - ${#title} - 4))
  echo ""
  printf '%s── %s%s%s %s%s%s\n' "$C_RULE" "$C_ACCENT" "$title" "$C_RESET" "$C_RULE" "$(_ui_repeat '─' "$fill")" "$C_RESET"
}

ui_row() {
  local label value
  label=$(_ui_pad "$(_ui_truncate "$1" "$LABEL_WIDTH")" "$LABEL_WIDTH")
  value=$(_ui_truncate "$2" "$VALUE_MAX")
  printf '  %s%s%s %s%s%s\n' "$C_MUTED" "$label" "$C_RESET" "$C_TEXT" "$value" "$C_RESET"
}

ui_row_dim() {
  local label value
  label=$(_ui_pad "$(_ui_truncate "$1" "$LABEL_WIDTH")" "$LABEL_WIDTH")
  value=$(_ui_truncate "$2" "$VALUE_MAX")
  printf '  %s%s %s%s\n' "$C_MUTED" "$label" "$value" "$C_RESET"
}

ui_ok()   { printf '  %s+%s %s\n' "$C_OK" "$C_RESET" "$1"; }
ui_warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_RESET" "$1"; }
ui_err()  { printf '  %sx%s %s\n' "$C_ERR" "$C_RESET" "$1"; }
ui_info() { printf '  %s·%s %s%s%s\n' "$C_MUTED" "$C_RESET" "$C_MUTED" "$1" "$C_RESET"; }

ui_gauge() {
  local label="$1" pct="$2" text="$3" filled color
  label=$(_ui_pad "$(_ui_truncate "$label" "$LABEL_WIDTH")" "$LABEL_WIDTH")
  if [ "$pct" -lt 0 ] 2>/dev/null; then
    printf '  %s%s%s %s%s%s\n' "$C_MUTED" "$label" "$C_RESET" "$C_TEXT" "$text" "$C_RESET"
    return 0
  fi
  [ "$pct" -gt 100 ] && pct=100
  filled=$((pct * GAUGE_CELLS / 100))
  color="$C_OK"
  [ "$pct" -ge 70 ] && color="$C_WARN"
  [ "$pct" -ge 90 ] && color="$C_ERR"
  printf '  %s%s%s %s%s%s%s%s %s%s%s\n' \
    "$C_MUTED" "$label" "$C_RESET" \
    "$color" "$(_ui_repeat '━' "$filled")" "$C_RULE" "$(_ui_repeat '╌' $((GAUGE_CELLS - filled)))" "$C_RESET" \
    "$C_TEXT" "$text" "$C_RESET"
}

ui_check_ver() {
  local name="$1" ok="$2" ver="$3" label
  label=$(_ui_pad "$(_ui_truncate "$name" "$LABEL_WIDTH")" "$LABEL_WIDTH")
  if [ "$ok" = "true" ]; then
    printf '  %s%s%s %s%s%s\n' "$C_TEXT" "$label" "$C_RESET" "$C_TEXT" "$(_ui_truncate "$ver" "$VALUE_MAX")" "$C_RESET"
  else
    printf '  %s%s -%s\n' "$C_MUTED" "$label" "$C_RESET"
  fi
}

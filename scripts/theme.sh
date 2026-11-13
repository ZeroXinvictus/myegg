#!/bin/bash

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_ACCENT=$'\033[38;2;124;180;255m'
C_OK=$'\033[38;2;143;211;164m'
C_WARN=$'\033[38;2;232;194;112m'
C_ERR=$'\033[38;2;239;126;126m'
C_MUTED=$'\033[38;2;112;121;139m'
C_TEXT=$'\033[38;2;224;228;235m'

LABEL_WIDTH=15
VALUE_MAX=46

_ui_truncate() {
  local str="$1" max="$2"
  [ "${#str}" -le "$max" ] && printf '%s' "$str" || printf '%s…' "${str:0:$((max - 1))}"
}

_ui_pad() {
  local str="$1" width="$2" pad=$((width - ${#str}))
  [ "$pad" -lt 0 ] && pad=0
  printf '%s%*s' "$str" "$pad" ""
}

ui_section() {
  local title="$1"
  printf '\n%s%s%s%s\n' "$C_BOLD" "$C_ACCENT" "$title" "$C_RESET"
  printf '%s%*s%s\n' "$C_MUTED" "${#title}" '' "$C_RESET" | tr ' ' '─'
}

ui_row() {
  local label value
  label=$(_ui_pad "$(_ui_truncate "$1" "$LABEL_WIDTH")" "$LABEL_WIDTH")
  value=$(_ui_truncate "$2" "$VALUE_MAX")
  printf '  %s%s%s %s%s%s\n' "$C_MUTED" "$label" "$C_RESET" "$C_TEXT" "$value" "$C_RESET"
}

ui_ok() { printf '  %s%-4s%s %s\n' "$C_OK" 'OK' "$C_RESET" "$1"; }
ui_warn() { printf '  %s%-4s%s %s\n' "$C_WARN" 'WARN' "$C_RESET" "$1"; }
ui_err() { printf '  %s%-4s%s %s\n' "$C_ERR" 'ERR' "$C_RESET" "$1"; }
ui_info() { printf '  %s%-4s%s %s\n' "$C_MUTED" 'INFO' "$C_RESET" "$1"; }

ui_check_ver() {
  local name="$1" ok="$2" ver="$3" label
  label=$(_ui_pad "$(_ui_truncate "$name" 13)" 13)
  if [ "$ok" = "true" ]; then
    printf '  %s%s%s %sOK%s   %s%s%s\n' "$C_TEXT" "$label" "$C_RESET" "$C_OK" "$C_RESET" "$C_MUTED" "$ver" "$C_RESET"
  else
    printf '  %s%s%s %s—%s    %snot installed%s\n' "$C_MUTED" "$label" "$C_RESET" "$C_MUTED" "$C_RESET" "$C_MUTED" "$C_RESET"
  fi
}

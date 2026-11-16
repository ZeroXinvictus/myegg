#!/bin/bash

setup_identity() {
  export USER="root"
  export HOME="/home/container"
  export TERM="${TERM:-xterm-256color}"
  export COLORTERM="${COLORTERM:-truecolor}"

  local prompt="\[${C_BOLD}${C_ACCENT}\]codex\[${C_RESET}\]\[${C_MUTED}\] \w\[${C_RESET}\] \$ "

  export PS1="$prompt"
  export CODEX_PS1="$prompt"
}

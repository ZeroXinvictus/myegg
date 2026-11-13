#!/bin/bash

setup_identity() {
  export USER="root"
  export HOME="/home/container"
  export TERM="xterm-256color"
  local prompt='\[\033[1m\033[38;2;124;180;255m\]ZeroXinvictus\[\033[0m\]\[\033[38;2;92;102;120m\]:\[\033[0m\]\[\033[38;2;224;228;235m\]\w\[\033[0m\]\[\033[38;2;92;102;120m\]\$\[\033[0m\] '
  export PS1="$prompt"
  export CODEX_PS1="$prompt"
}

#!/bin/bash

mask_secret() {
  local line
  while IFS= read -r line; do
    if [ -n "$ACCESS_TOKEN" ]; then
      line="${line//"$ACCESS_TOKEN"/***}"
    fi
    printf '%s\n' "$line"
  done
}

setup_git_repo() {
  git config --global --add safe.directory /home/container >/dev/null 2>&1

  [ "$USER_UPLOAD" = "true" ] && return 0
  [ -z "$GIT_ADDRESS" ] && return 0

  local repo_url="$GIT_ADDRESS" branch_args=()
  if [ -n "$USERNAME" ] && [ -n "$ACCESS_TOKEN" ]; then
    repo_url="${GIT_ADDRESS/https:\/\//https://${USERNAME}:${ACCESS_TOKEN}@}"
  fi
  [ -n "$BRANCH" ] && branch_args=(-b "$BRANCH")

  if [ ! -d ".git" ]; then
    ui_info "git clone ${GIT_ADDRESS}"
    git clone --depth 1 "${branch_args[@]}" "$repo_url" temp_clone 2>&1 | mask_secret
    if [ -d "temp_clone" ]; then
      git -C temp_clone remote set-url origin "$GIT_ADDRESS"
      cp -a temp_clone/. . && rm -rf temp_clone
      git config --global --add safe.directory /home/container >/dev/null 2>&1
    else
      ui_err "git clone gagal, cek GIT_ADDRESS / username / token"
    fi
  elif [ "$AUTO_UPDATE" = "true" ]; then
    ui_info "git pull"
    git remote set-url origin "$repo_url" 2>/dev/null
    git pull --ff-only 2>&1 | mask_secret
    git remote set-url origin "$GIT_ADDRESS" 2>/dev/null
  fi
}

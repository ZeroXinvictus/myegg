#!/bin/bash

setup_runtime_paths() {
  export NVM_DIR="/usr/local/nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  if [ -n "$NODE_VERSION" ] && command -v nvm >/dev/null 2>&1; then
    nvm ls "$NODE_VERSION" >/dev/null 2>&1 && nvm use "$NODE_VERSION" >/dev/null 2>&1 || {
      ui_warn "Node ${NODE_VERSION} belum tersedia; mencoba install saat start"
      nvm install "$NODE_VERSION" >/tmp/nvm-install.log 2>&1 && nvm use "$NODE_VERSION" >/dev/null 2>&1 || ui_warn "Node ${NODE_VERSION} gagal diaktifkan"
    }
  fi
  [ -n "$PYTHON_VERSION" ] && command -v "python$PYTHON_VERSION" >/dev/null 2>&1 && update-alternatives --set python3 "/usr/bin/python$PYTHON_VERSION" >/dev/null 2>&1
  [ -n "$PHP_VERSION" ] && command -v "php$PHP_VERSION" >/dev/null 2>&1 && update-alternatives --set php "/usr/bin/php$PHP_VERSION" >/dev/null 2>&1
  export PATH="/usr/local/go/bin:${CARGO_HOME:-/usr/local/cargo}/bin:${BUN_INSTALL:-/usr/local/bun}/bin:${PATH}"
  export GOCACHE="/home/container/.cache/go-build"
  mkdir -p "$GOCACHE" 2>/dev/null
}

resolve_package_manager() {
  case "$INSTALL_DEPS" in npm|pnpm|yarn|bun) echo "$INSTALL_DEPS"; return;; esac
  [ -f bun.lockb ] || [ -f bun.lock ] && echo bun && return
  [ -f pnpm-lock.yaml ] && echo pnpm && return
  [ -f yarn.lock ] && echo yarn && return
  echo npm
}

install_node_deps() {
  [ ! -f package.json ] || [ "$SKIP_DEPS_INSTALL" = "true" ] && return 0
  local manager hash prev
  hash=$(sha256sum package.json package-lock.json pnpm-lock.yaml yarn.lock bun.lock bun.lockb 2>/dev/null | sha256sum | awk '{print $1}')
  prev=$(cat .codex-deps-hash 2>/dev/null || true)
  if [ -d node_modules ] && [ "$hash" = "$prev" ]; then ui_ok "Node dependencies unchanged"; return 0; fi
  manager=$(resolve_package_manager)
  ui_info "package manager -> $manager"
  case "$manager" in
    pnpm) pnpm install --frozen-lockfile 2>/dev/null || pnpm install;;
    yarn) yarn install --immutable 2>/dev/null || yarn install;;
    bun) bun install --frozen-lockfile 2>/dev/null || bun install;;
    *) [ -f package-lock.json ] && npm ci || npm install;;
  esac
  echo "$hash" > .codex-deps-hash
}

detect_and_setup_runtime() {
  local cmd="$STARTUP_CMD"
  DETECTED_RUNTIME="Unknown"
  [ "$SKIP_DEPS_INSTALL" = "true" ] && ui_info "SKIP_DEPS_INSTALL=true"
  case "$cmd" in
    *bun\ *|bun*) DETECTED_RUNTIME="Bun"; [ "$SKIP_DEPS_INSTALL" = "true" ] || [ ! -f package.json ] || bun install;;
    *node\ *|node*|*npm\ *|npm*|*npx\ *|*pnpm\ *|pnpm*|*yarn\ *|yarn*) DETECTED_RUNTIME="Node.js"; install_node_deps;;
    *python3\ *|python3*|*python\ *|python*) DETECTED_RUNTIME="Python"; [ -f requirements.txt ] && [ "$SKIP_DEPS_INSTALL" != "true" ] && pip install --break-system-packages -r requirements.txt;;
    *php\ *|php*|*artisan\ *) DETECTED_RUNTIME="PHP"; [ -f composer.json ] && [ "$SKIP_DEPS_INSTALL" != "true" ] && composer install --no-interaction;;
    *go\ run\ *|*go\ build\ *|go\ *|./app_bin*|./main*) DETECTED_RUNTIME="Go"; [ -f go.mod ] && [ "$SKIP_DEPS_INSTALL" != "true" ] && go mod download; [ "$AUTO_BUILD" = "true" ] && [[ "$cmd" == ./* ]] && go build -o app_bin .;;
    *cargo\ run*|*cargo\ *|./target/*) DETECTED_RUNTIME="Rust"; [ -f Cargo.toml ] && [ "$AUTO_BUILD" = "true" ] && cargo build --release;;
    *gradlew*|*gradle\ *|*android*|*\.apk*) DETECTED_RUNTIME="Android";;
    *g++\ *|*gcc\ *) DETECTED_RUNTIME="C/C++";;
  esac
  export DETECTED_RUNTIME
}

#!/bin/bash

CODEX_STATE_DIR="/home/container/.codex/state"
CODEX_SHIM_DIR="/home/container/.codex/bin"

hash_files() {
  local f out=""
  for f in "$@"; do
    [ -f "$f" ] && out="${out}$(md5sum "$f" 2>/dev/null)"
  done
  printf '%s' "$out" | md5sum | awk '{print $1}'
}

deps_unchanged() {
  local name="$1" current="$2" file="${CODEX_STATE_DIR}/${1}.hash"
  [ -f "$file" ] && [ "$(cat "$file" 2>/dev/null)" = "$current" ]
}

remember_deps() {
  mkdir -p "$CODEX_STATE_DIR"
  echo "$2" > "${CODEX_STATE_DIR}/${1}.hash"
}

build_version_shims() {
  mkdir -p "$CODEX_SHIM_DIR"
  rm -f "${CODEX_SHIM_DIR}"/* 2>/dev/null

  if [ -n "$PYTHON_VERSION" ] && command -v "python${PYTHON_VERSION}" >/dev/null 2>&1; then
    ln -s "$(command -v "python${PYTHON_VERSION}")" "${CODEX_SHIM_DIR}/python3"
    ln -s "$(command -v "python${PYTHON_VERSION}")" "${CODEX_SHIM_DIR}/python"
    printf '#!/bin/bash\nexec python3 -m pip "$@"\n' > "${CODEX_SHIM_DIR}/pip"
    cp "${CODEX_SHIM_DIR}/pip" "${CODEX_SHIM_DIR}/pip3"
    chmod +x "${CODEX_SHIM_DIR}/pip" "${CODEX_SHIM_DIR}/pip3"
  fi

  if [ -n "$PHP_VERSION" ] && command -v "php${PHP_VERSION}" >/dev/null 2>&1; then
    ln -s "$(command -v "php${PHP_VERSION}")" "${CODEX_SHIM_DIR}/php"
  fi

  export PATH="${CODEX_SHIM_DIR}:${PATH}"
}

setup_runtime_paths() {
  export NVM_DIR="/usr/local/nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  if [ -n "$NODE_VERSION" ] && command -v nvm >/dev/null 2>&1; then
    if nvm ls "$NODE_VERSION" >/dev/null 2>&1; then
      nvm use "$NODE_VERSION" >/dev/null 2>&1
    else
      ui_warn "Node ${NODE_VERSION} belum ada di image, mencoba download"
      nvm install "$NODE_VERSION" >/tmp/nvm-install.log 2>&1 && nvm use "$NODE_VERSION" >/dev/null 2>&1
    fi
  fi

  export PATH="/opt/node-global/node_modules/.bin:/usr/local/go/bin:${CARGO_HOME:-/usr/local/cargo}/bin:${BUN_INSTALL:-/usr/local/bun}/bin:${PATH}"
  export GOCACHE="/home/container/.cache/go-build"
  mkdir -p "$GOCACHE" 2>/dev/null

  build_version_shims
}

resolve_package_manager() {
  case "$INSTALL_DEPS" in
    npm|pnpm|yarn|bun)
      echo "$INSTALL_DEPS"
      return
      ;;
  esac

  if [ -f "bun.lockb" ] || [ -f "bun.lock" ]; then
    echo "bun"
  elif [ -f "pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "yarn.lock" ]; then
    echo "yarn"
  else
    echo "npm"
  fi
}

node_deps_hash() {
  hash_files package.json package-lock.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock
}

has_node_dependencies() {
  node -e 'const p=require("./package.json");process.exit(["dependencies","devDependencies","optionalDependencies"].some(k=>p[k]&&Object.keys(p[k]).length)?0:1)' >/dev/null 2>&1
}

install_node_deps() {
  local current manager
  current=$(node_deps_hash)

  if { [ -d "node_modules" ] || ! has_node_dependencies; } && deps_unchanged node "$current"; then
    ui_ok "node_modules cocok dengan lockfile, skip install"
    return 0
  fi

  manager=$(resolve_package_manager)
  ui_info "install dependency pakai ${manager}"
  case "$manager" in
    pnpm) pnpm install ;;
    yarn) yarn install ;;
    bun)  bun install ;;
    *)    if [ -f "package-lock.json" ]; then npm ci; else npm install; fi ;;
  esac && remember_deps node "$(node_deps_hash)"
}

install_python_deps() {
  local current
  current=$(hash_files requirements.txt)

  if deps_unchanged python "${current}-${PYTHON_VERSION}"; then
    ui_ok "requirements.txt tidak berubah, skip install"
    return 0
  fi

  ui_info "pip install -r requirements.txt"
  pip install --user --break-system-packages -r requirements.txt && remember_deps python "${current}-${PYTHON_VERSION}"
}

detect_and_setup_runtime() {
  local cmd="$STARTUP_CMD"
  DETECTED_RUNTIME="Unknown"

  if [ "$SKIP_DEPS_INSTALL" = "true" ]; then
    ui_info "SKIP_DEPS_INSTALL=true, semua install dependency dilewati"
  fi

  case "$cmd" in
    *bun\ * | bun*)
      DETECTED_RUNTIME="Bun"
      if [ -f "package.json" ] && [ "$SKIP_DEPS_INSTALL" != "true" ]; then
        bun install
      fi
      ;;

    *node\ * | node* | *npm\ * | npm* | *npx\ * | pnpm* | *yarn\ * | yarn*)
      DETECTED_RUNTIME="Node.js"
      if [ -f "package.json" ] && [ "$SKIP_DEPS_INSTALL" != "true" ]; then
        install_node_deps
      fi
      ;;

    *python3\ * | python3* | *python\ * | python*)
      DETECTED_RUNTIME="Python"
      if [ -f "requirements.txt" ] && [ "$SKIP_DEPS_INSTALL" != "true" ]; then
        install_python_deps
      fi
      ;;

    *php\ * | php* | *artisan\ *)
      DETECTED_RUNTIME="PHP"
      if [ -f "composer.json" ] && [ "$SKIP_DEPS_INSTALL" != "true" ]; then
        composer install --no-interaction
      fi
      ;;

    *java\ * | java* | ./gradlew* | *gradle\ *)
      DETECTED_RUNTIME="Java"
      ;;

    *go\ run\ * | *go\ build\ * | go\ * | ./app_bin* | ./main*)
      DETECTED_RUNTIME="Go"
      if [ -f "go.mod" ] && [ "$SKIP_DEPS_INSTALL" != "true" ]; then
        go mod download
        if [ "$AUTO_BUILD" = "true" ] && [[ "$cmd" == ./* ]]; then
          go build -o app_bin .
        fi
      fi
      ;;

    *cargo\ * | ./target/*)
      DETECTED_RUNTIME="Rust"
      if [ -f "Cargo.toml" ] && [ "$AUTO_BUILD" = "true" ] && [ "$SKIP_DEPS_INSTALL" != "true" ] && [[ "$cmd" == ./target/* ]]; then
        cargo build --release
      fi
      ;;

    *g++\ * | *gcc\ *)
      DETECTED_RUNTIME="C/C++"
      ;;
  esac

  export DETECTED_RUNTIME
}

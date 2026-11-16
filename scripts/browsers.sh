#!/bin/bash

resolve_browsers() {
  local py_cache="${HOME}/.cache/camoufox"

  CHROME_BIN=$(find_playwright_binary chromium chrome)
  FIREFOX_BIN=$(find_playwright_binary firefox firefox)
  WEBKIT_BIN=$(find_playwright_binary webkit pw_run.sh)

  if [ -n "$CHROME_BIN" ]; then
    export PUPPETEER_EXECUTABLE_PATH="$CHROME_BIN"
    export CHROME_PATH="$CHROME_BIN"
  fi
  if [ -n "$FIREFOX_BIN" ]; then
    export FIREFOX_BIN
    export FIREFOX_PATH="$FIREFOX_BIN"
  fi
  [ -n "$WEBKIT_BIN" ] && export WEBKIT_BIN

  if [ -d /opt/camoufox-cache/camoufox ] && [ ! -e "$py_cache" ]; then
    mkdir -p "${HOME}/.cache" 2>/dev/null
    ln -s /opt/camoufox-cache/camoufox "$py_cache" 2>/dev/null
  fi

  CAMOUFOX_PY_READY="false"
  [ -n "$(ls -A "${py_cache}/" 2>/dev/null)" ] && CAMOUFOX_PY_READY="true"

  CAMOUFOX_JS_READY="false"
  if [ -n "$CAMOUFOX_INSTALL_DIR" ] && [ -n "$(ls -A "$CAMOUFOX_INSTALL_DIR" 2>/dev/null)" ]; then
    CAMOUFOX_JS_READY="true"
  fi

  export CAMOUFOX_PY_READY CAMOUFOX_JS_READY
}

browser_version_of() {
  local bin="$1" ver
  [ -z "$bin" ] && return 0
  ver=$("$bin" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1)
  echo "$ver"
}

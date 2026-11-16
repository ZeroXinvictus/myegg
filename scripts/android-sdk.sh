#!/bin/bash

ANDROID_OVERLAY_ROOT="/home/container/.android-sdk"

select_java() {
  local want="${JAVA_VERSION:-21}" arch dir
  arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
  dir="/usr/lib/jvm/java-${want}-openjdk-${arch}"

  if [ ! -x "${dir}/bin/java" ]; then
    ui_warn "JAVA_VERSION=${want} tidak ada di image, pakai default"
    dir="/usr/lib/jvm/java-21-openjdk-${arch}"
  fi

  if [ -x "${dir}/bin/java" ]; then
    export JAVA_HOME="$dir"
    export PATH="${JAVA_HOME}/bin:${PATH}"
  fi
}

prepare_android_overlay() {
  local baked="$1" root="$ANDROID_OVERLAY_ROOT" name entry base

  mkdir -p "$root"

  for name in cmdline-tools platform-tools; do
    [ -e "${root}/${name}" ] || ln -s "${baked}/${name}" "${root}/${name}"
  done

  for name in platforms build-tools; do
    mkdir -p "${root}/${name}"
    for entry in "${baked}/${name}"/*; do
      [ -e "$entry" ] || continue
      base=$(basename "$entry")
      [ -e "${root}/${name}/${base}" ] || ln -s "$entry" "${root}/${name}/${base}"
    done
  done

  [ -d "${root}/licenses" ] || cp -r "${baked}/licenses" "${root}/licenses" 2>/dev/null
}

install_android_packages() {
  local baked="$1" packages stamp_dir stamp wanted
  packages=$(echo "$ANDROID_PACKAGES" | tr ',\n' '  ' | xargs)
  [ -z "$packages" ] && return 0

  stamp_dir="/home/container/.codex/state"
  stamp="${stamp_dir}/android-packages.hash"
  mkdir -p "$stamp_dir"
  wanted=$(printf '%s' "$packages" | md5sum | awk '{print $1}')

  prepare_android_overlay "$baked"

  if [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$wanted" ]; then
    ui_ok "android packages sudah terpasang, skip install"
    return 0
  fi

  ui_info "sdkmanager install: ${packages}"
  if (yes || true) | "${baked}/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_OVERLAY_ROOT" $packages >/tmp/android-sdkmanager.log 2>&1; then
    echo "$wanted" > "$stamp"
    ui_ok "android packages terpasang"
    return 0
  fi

  ui_err "sdkmanager gagal, 5 baris terakhir log:"
  tail -n 5 /tmp/android-sdkmanager.log 2>/dev/null | sed 's/^/      /'
  return 1
}

setup_android_sdk() {
  local baked="${ANDROID_SDK_BAKED:-/opt/android-sdk}" latest_bt

  select_java

  export ANDROID_USER_HOME="/home/container/.android"
  export ANDROID_AVD_HOME="${ANDROID_USER_HOME}/avd"
  export GRADLE_USER_HOME="/home/container/.gradle"
  export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false}"
  mkdir -p "$ANDROID_USER_HOME" "$GRADLE_USER_HOME" 2>/dev/null

  ANDROID_SDK_STATE="absent"
  if [ ! -x "${baked}/cmdline-tools/latest/bin/sdkmanager" ]; then
    export ANDROID_SDK_STATE
    return 0
  fi

  export ANDROID_HOME="$baked"
  ANDROID_SDK_STATE="baked"

  if [ -n "$(echo "$ANDROID_PACKAGES" | tr -d ' ,\n')" ]; then
    if install_android_packages "$baked"; then
      export ANDROID_HOME="$ANDROID_OVERLAY_ROOT"
      ANDROID_SDK_STATE="overlay"
    fi
  fi

  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  export ANDROID_SDK_STATE

  latest_bt=$(ls -1 "${ANDROID_HOME}/build-tools" 2>/dev/null | sort -V | tail -n1)
  export PATH="${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/${latest_bt}:${PATH}"
}

list_android_components() {
  local kind="$1"
  ls -1 "${ANDROID_HOME}/${kind}" 2>/dev/null | sed 's/^android-//' | sort -V | paste -sd' ' -
}

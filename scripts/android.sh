#!/bin/bash

setup_android_sdk() {
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
  export ANDROID_HOME="$ANDROID_SDK_ROOT"
  export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/build-tools/${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}:$PATH"

  if [ "${ENABLE_ANDROID_SDK:-true}" != "true" ]; then
    ui_info "Android SDK disabled"
    return 0
  fi

  if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
    ui_warn "Android SDK command-line tools tidak tersedia di image"
    return 0
  fi

  if [ "${ANDROID_INSTALL_ON_START:-false}" = "true" ]; then
    install_android_packages
  fi
}

install_android_packages() {
  local packages="platform-tools platforms;android-${ANDROID_PLATFORM_VERSION:-36} build-tools;${ANDROID_BUILD_TOOLS_VERSION:-36.0.0}"
  [ "${ANDROID_INSTALL_NDK:-false}" = "true" ] && packages="$packages ndk;${ANDROID_NDK_VERSION:-28.2.13676358}"
  ui_info "Android SDK packages -> $packages"
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
  sdkmanager $packages >/tmp/android-sdk-install.log 2>&1 || {
    ui_err "Android SDK package install gagal; lihat /tmp/android-sdk-install.log"
    return 1
  }
  ui_ok "Android SDK siap"
}

android_project_detect() {
  [ -f "settings.gradle" ] || [ -f "settings.gradle.kts" ] || [ -f "gradlew" ] || return 1
  [ -f "AndroidManifest.xml" ] || find . -maxdepth 3 -name AndroidManifest.xml -print -quit | grep -q .
}

android_project_setup() {
  if android_project_detect; then
    export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"
    ui_ok "Android project terdeteksi"
    if [ "${AUTO_ANDROID_DEPS:-false}" = "true" ] && [ -x ./gradlew ]; then
      chmod +x ./gradlew
      ./gradlew dependencies >/tmp/android-gradle-deps.log 2>&1 || ui_warn "Gradle dependency warm-up gagal, build tetap bisa dijalankan manual"
    fi
  fi
}

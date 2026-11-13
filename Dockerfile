FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Jakarta
ENV HOME=/home/container
ENV USER=container
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update -y && apt-get install -y \
    curl wget git unzip zip tar ca-certificates gnupg dirmngr lsb-release \
    build-essential software-properties-common jq nano vim htop sqlite3 \
    ffmpeg imagemagick openssh-client supervisor python3-dev python3-pip \
    libvips-dev libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
    postgresql-client default-mysql-client redis-tools git-lfs \
    cmake ninja-build gdb valgrind clang clang-format libboost-all-dev \
    openjdk-17-jdk-headless \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 \
    libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2t64 \
    libpango-1.0-0 libcairo2 fonts-liberation libx11-6 libxext6 libxcb1 libxrender1 \
    libxi6 libgtk-3-0 libvulkan1 libdbus-glib-1-2 libx11-xcb1 xvfb x11-utils xauth \
    libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libwoff1 libopus0 libwebpdemux2 \
    libharfbuzz-icu0 libenchant-2-2 libsecret-1-0 libhyphen0 libmanette-0.2-0 \
    libgles2 libx264-dev fonts-noto fonts-noto-cjk fonts-dejavu-core locales tzdata \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p "$NVM_DIR" \
    && curl --retry 5 --retry-delay 2 -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 22 \
    && nvm install 24 \
    && nvm install 26 \
    && nvm alias default 24 \
    && npm install -g pnpm yarn pm2 playwright@1.62.1 playwright-core@1.62.1 puppeteer puppeteer-real-browser puppeteer-extra puppeteer-extra-plugin-stealth camoufox-js@0.13.0 bexxcv@1.1.0 \
    && ln -s "$NVM_DIR/versions/node/$(nvm version default)" /usr/local/node-current
ENV PATH="/usr/local/node-current/bin:$PATH"

ENV BUN_INSTALL=/usr/local/bun
RUN curl --retry 5 --retry-delay 2 -fsSL https://bun.sh/install | bash
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

RUN for i in 1 2 3 4 5; do add-apt-repository -y ppa:deadsnakes/ppa && break || sleep 5; done \
    && apt-get update -y \
    && apt-get install -y python3.12 python3.12-venv python3.13 python3.13-venv python3.14 python3.14-venv \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1

RUN for i in 1 2 3 4 5; do add-apt-repository -y ppa:ondrej/php && break || sleep 5; done \
    && apt-get update -y \
    && for v in 8.2 8.3 8.4 8.5; do \
      apt-get install -y php$v php$v-cli php$v-fpm php$v-common php$v-mysql php$v-pgsql php$v-sqlite3 php$v-curl php$v-gd php$v-mbstring php$v-xml php$v-zip php$v-bcmath php$v-intl; \
    done \
    && apt-get install -y composer \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.3 83 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.4 84 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.5 85 \
    && update-alternatives --set php /usr/bin/php8.4

ENV GO_VERSION=1.27.4
RUN ARCH=$(dpkg --print-architecture) \
    && curl --retry 5 --retry-delay 2 -fsSL -Lo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm -f /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:/usr/local/cargo/bin:$PATH"
ENV GOPATH=/home/container/go
ENV GOCACHE=/home/container/.cache/go-build

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
RUN curl --retry 5 --retry-delay 2 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && chmod -R a+w "$RUSTUP_HOME" "$CARGO_HOME"

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/browsers
RUN . "$NVM_DIR/nvm.sh" \
    && npx --yes playwright install chromium firefox webkit --with-deps

ENV CAMOUFOX_INSTALL_DIR=/opt/camoufox
ENV BEXXCV_HOME=/opt/bexxcv
ENV XDG_CACHE_HOME=/opt/camoufox-cache
RUN mkdir -p /opt/camoufox /opt/camoufox-cache /opt/bexxcv \
    && . "$NVM_DIR/nvm.sh" \
    && CAMOUFOX_INSTALL_DIR=/opt/camoufox npx bexxcv fetch \
    && CAMOUFOX_INSTALL_DIR=/opt/camoufox npx bexxcv doctor

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_PLATFORM_VERSION=36
ENV ANDROID_BUILD_TOOLS_VERSION=36.0.0
ENV ANDROID_NDK_VERSION=28.2.13676358
RUN mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools" \
    && cd /tmp \
    && curl --retry 5 --retry-delay 2 -fsSL -o commandlinetools.zip https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip \
    && unzip -q commandlinetools.zip -d "$ANDROID_SDK_ROOT/cmdline-tools" \
    && mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest" \
    && rm -f commandlinetools.zip \
    && yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true \
    && "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" \
       "platform-tools" \
       "platforms;android-36" \
       "build-tools;36.0.0" \
       "ndk;28.2.13676358" \
    && ln -sf "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" /usr/local/bin/sdkmanager \
    && ln -sf "$ANDROID_SDK_ROOT/platform-tools/adb" /usr/local/bin/adb \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:/opt/android-sdk/build-tools/36.0.0:$PATH"
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

WORKDIR /home/container
RUN echo 'if [ -n "$CODEX_PS1" ]; then PS1="$CODEX_PS1"; fi' >> /etc/bash.bashrc

COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/
RUN sed -i '1s/^\xEF\xBB\xBF//' /entrypoint.sh /scripts/*.sh \
    && chmod +x /entrypoint.sh /scripts/*.sh \
    && rm -rf /tmp/*

CMD ["/bin/bash", "/entrypoint.sh"]

FROM ubuntu:24.04

ENV CODEX_VERSION=15
LABEL org.opencontainers.image.title="codex-tools" \
      org.opencontainers.image.version="${CODEX_VERSION}" \
      org.opencontainers.image.source="https://github.com/ZeroXinvictus/myegg"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Jakarta

RUN apt-get update -y && apt-get install -y \
    curl wget git git-lfs unzip zip tar xz-utils zstd bzip2 \
    ca-certificates gnupg dirmngr lsb-release \
    build-essential software-properties-common \
    jq nano vim htop procps \
    sqlite3 ffmpeg imagemagick \
    openssh-client cron supervisor \
    python3-dev libvips-dev \
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
    postgresql-client default-mysql-client redis-tools \
    && rm -rf /var/lib/apt/lists/*

ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p $NVM_DIR && \
    curl -fsS --retry 3 --retry-delay 2 -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
RUN . $NVM_DIR/nvm.sh && \
    nvm install 22 && \
    nvm install 24 && \
    nvm install 26 && \
    nvm alias default 24 && \
    ln -s "$NVM_DIR/versions/node/$(nvm version default)" /usr/local/node-current && \
    chmod -R a+rX $NVM_DIR
ENV PATH="/usr/local/node-current/bin:$PATH"

ENV BUN_INSTALL=/usr/local/bun
RUN curl -fsS --retry 3 --retry-delay 2 https://bun.sh/install | bash && chmod -R a+rX $BUN_INSTALL
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

RUN for i in 1 2 3 4 5; do add-apt-repository -y ppa:deadsnakes/ppa && break || sleep 5; done && \
    apt-get update -y && \
    apt-get install -y \
      python3.12 python3.12-venv \
      python3.13 python3.13-venv \
      python3.14 python3.14-venv \
      python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN for i in 1 2 3 4 5; do add-apt-repository -y ppa:ondrej/php && break || sleep 5; done && \
    apt-get update -y && \
    for v in 8.2 8.3 8.4 8.5; do \
      apt-get install -y \
        php$v php$v-cli php$v-fpm php$v-common \
        php$v-mysql php$v-pgsql php$v-sqlite3 \
        php$v-curl php$v-gd php$v-mbstring \
        php$v-xml php$v-zip php$v-bcmath php$v-intl; \
    done && \
    apt-get install -y composer && \
    rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82 && \
    update-alternatives --install /usr/bin/php php /usr/bin/php8.3 83 && \
    update-alternatives --install /usr/bin/php php /usr/bin/php8.4 84 && \
    update-alternatives --install /usr/bin/php php /usr/bin/php8.5 85 && \
    update-alternatives --set php /usr/bin/php8.4

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1

ARG GO_VERSION=latest
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$GO_VERSION" = "latest" ]; then GO_VERSION=$(curl -fsS "https://go.dev/VERSION?m=text" | head -n1 | sed 's/^go//'); fi && \
    curl -fsSL --retry 3 --retry-delay 2 -o /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    /usr/local/go/bin/go version
ENV PATH="/usr/local/go/bin:${PATH}" \
    GOPATH="/home/container/go" \
    GOCACHE="/home/container/.cache/go-build"

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo
RUN curl -fsS --retry 3 --retry-delay 2 --proto '=https' --tlsv1.2 https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable --profile minimal && \
    chmod -R a+rwX $RUSTUP_HOME $CARGO_HOME
ENV PATH="${CARGO_HOME}/bin:${PATH}"

RUN apt-get update -y && apt-get install -y \
    cmake ninja-build gdb valgrind clang clang-format \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update -y && apt-get install -y \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2t64 \
    libpango-1.0-0 libcairo2 fonts-liberation \
    libx11-6 libxext6 libxcb1 libxrender1 libxi6 \
    libgtk-3-0 libvulkan1 libdbus-glib-1-2 libx11-xcb1 \
    xvfb x11-utils xauth \
    libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
    libwoff1 libopus0 libwebpdemux2 libharfbuzz-icu0 \
    libenchant-2-2 libsecret-1-0 libhyphen0 libmanette-0.2-0 libgles2 \
    fonts-noto fonts-noto-color-emoji fonts-noto-cjk fonts-dejavu-core \
    locales tzdata \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

ARG PLAYWRIGHT_VERSION=1.62.0
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/browsers \
    PUPPETEER_SKIP_DOWNLOAD=true \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
RUN pip install --break-system-packages "playwright==${PLAYWRIGHT_VERSION}" && \
    python3 -m playwright install chromium firefox webkit --with-deps && \
    chmod -R a+rX /opt/browsers && \
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=secret,id=github_token,required=false \
    if [ -f /run/secrets/github_token ]; then export GITHUB_TOKEN="$(cat /run/secrets/github_token)"; fi && \
    pip install --break-system-packages --ignore-installed "PyYAML>=6.0.1" && \
    pip install --break-system-packages "playwright==${PLAYWRIGHT_VERSION}" "camoufox[geoip]" && \
    for i in 1 2 3 4 5; do \
      XDG_CACHE_HOME=/opt/camoufox-cache python3 -m camoufox fetch && break || { echo "camoufox fetch gagal, retry $i/5"; sleep 10; }; \
    done && \
    test -n "$(ls -A /opt/camoufox-cache/camoufox 2>/dev/null)" && \
    chmod -R a+rX /opt/camoufox-cache

ENV NODE_GLOBAL=/opt/node-global \
    CAMOUFOX_INSTALL_DIR=/opt/camoufox-js
RUN --mount=type=secret,id=github_token,required=false \
    if [ -f /run/secrets/github_token ]; then export GITHUB_TOKEN="$(cat /run/secrets/github_token)"; fi && \
    . $NVM_DIR/nvm.sh && \
    mkdir -p $NODE_GLOBAL && \
    npm install --prefix $NODE_GLOBAL \
      "playwright@${PLAYWRIGHT_VERSION}" "playwright-core@${PLAYWRIGHT_VERSION}" \
      camoufox-js \
      puppeteer puppeteer-core puppeteer-real-browser \
      puppeteer-extra puppeteer-extra-plugin-stealth \
      pm2 pnpm yarn && \
    for i in 1 2 3 4 5; do \
      NODE_PATH=$NODE_GLOBAL/node_modules $NODE_GLOBAL/node_modules/.bin/camoufox-js fetch && break || { echo "camoufox-js fetch gagal, retry $i/5"; sleep 10; }; \
    done && \
    test -n "$(ls -A /opt/camoufox-js 2>/dev/null)" && \
    chmod -R a+rX $NODE_GLOBAL /opt/camoufox-js
ENV NODE_PATH=/opt/node-global/node_modules
ENV PATH="/opt/node-global/node_modules/.bin:${PATH}"

RUN ARCH=$(uname -m) && \
    case "$ARCH" in x86_64) T=x86_64 ;; aarch64) T=aarch64 ;; *) echo "arsitektur $ARCH tidak didukung ttyd" && exit 1 ;; esac && \
    curl -fsSL --retry 3 --retry-delay 2 -o /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.${T}" && \
    chmod +x /usr/local/bin/ttyd && \
    /usr/local/bin/ttyd --version

RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL --retry 3 --retry-delay 2 -o /usr/local/bin/cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" && \
    chmod +x /usr/local/bin/cloudflared && \
    /usr/local/bin/cloudflared --version

ARG ANDROID_CMDLINE_TOOLS=15859902
ARG ANDROID_CMDLINE_SHA256=
ARG ANDROID_PLATFORMS="android-36 android-37"
ARG ANDROID_BUILD_TOOLS="36.0.0 37.0.0"
ENV ANDROID_SDK_BAKED=/opt/android-sdk
RUN apt-get update -y && apt-get install -y --no-install-recommends \
      openjdk-17-jdk-headless openjdk-21-jdk-headless \
    && rm -rf /var/lib/apt/lists/*
RUN if [ "$(dpkg --print-architecture)" != "amd64" ]; then \
      echo "Android SDK dilewati: build-tools resmi Google cuma tersedia untuk linux x86_64"; \
    else \
      curl -fsSL --retry 3 --retry-delay 2 -o /tmp/cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS}_latest.zip" && \
      if [ -n "$ANDROID_CMDLINE_SHA256" ]; then echo "${ANDROID_CMDLINE_SHA256}  /tmp/cmdline-tools.zip" | sha256sum -c -; fi && \
      mkdir -p $ANDROID_SDK_BAKED/cmdline-tools && \
      unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-extract && \
      mv /tmp/cmdline-extract/cmdline-tools $ANDROID_SDK_BAKED/cmdline-tools/latest && \
      rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-extract && \
      export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 && \
      (yes || true) | $ANDROID_SDK_BAKED/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_SDK_BAKED --licenses >/dev/null && \
      PKGS="platform-tools" && \
      for p in $ANDROID_PLATFORMS; do PKGS="$PKGS platforms;$p"; done && \
      for b in $ANDROID_BUILD_TOOLS; do PKGS="$PKGS build-tools;$b"; done && \
      $ANDROID_SDK_BAKED/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_SDK_BAKED $PKGS && \
      chmod -R a+rX $ANDROID_SDK_BAKED; \
    fi

WORKDIR /home/container
ENV HOME=/home/container \
    USER=container

RUN echo '' >> /etc/bash.bashrc && \
    echo 'if [ -n "$CODEX_PS1" ]; then' >> /etc/bash.bashrc && \
    echo '  PS1="$CODEX_PS1"' >> /etc/bash.bashrc && \
    echo 'fi' >> /etc/bash.bashrc

COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/

RUN apt-get update -y && apt-get install -y --no-install-recommends dos2unix && \
    dos2unix /entrypoint.sh /scripts/*.sh && \
    sed -i '1s/^\xEF\xBB\xBF//' /entrypoint.sh /scripts/*.sh && \
    chmod +x /entrypoint.sh /scripts/*.sh && \
    for f in /entrypoint.sh /scripts/*.sh; do bash -n "$f" || exit 1; done && \
    apt-get purge -y dos2unix && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash", "/entrypoint.sh"]

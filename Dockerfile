FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Asia/Jakarta

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=${TZ}

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV NVM_DIR=/usr/local/nvm
ENV NODE_VERSION_DEFAULT=24

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/browsers

ENV CAMOUFOX_INSTALL_DIR=/opt/camoufox
ENV BEXXCV_HOME=/opt/bexxcv
ENV XDG_CACHE_HOME=/opt/camoufox-cache

ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_PLATFORM_VERSION=36
ENV ANDROID_BUILD_TOOLS_VERSION=36.0.0
ENV ANDROID_NDK_VERSION=28.2.13676358

ENV PATH=/usr/local/nvm/versions/node/v24/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:/opt/android-sdk/build-tools/36.0.0:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        unzip \
        zip \
        xz-utils \
        bzip2 \
        gzip \
        tar \
        jq \
        file \
        procps \
        psmisc \
        lsof \
        net-tools \
        iproute2 \
        iputils-ping \
        dnsutils \
        openssh-client \
        rsync \
        sudo \
        nano \
        vim \
        less \
        tree \
        htop \
        screen \
        tmux \
        locales \
        tzdata \
        gnupg \
        dirmngr \
        software-properties-common \
        apt-transport-https \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        pkg-config \
        libssl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libfreetype6-dev \
        libx11-xcb1 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libgbm1 \
        libgtk-3-0 \
        libnss3 \
        libnspr4 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libcups2 \
        libdrm2 \
        libdbus-1-3 \
        libasound2t64 \
        libxshmfence1 \
        xvfb \
        xauth \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p \
        /usr/local/nvm \
        /opt/browsers \
        /opt/camoufox \
        /opt/camoufox-cache \
        /opt/bexxcv \
        /opt/android-sdk \
        /workspace \
        /data \
    && chmod -R 755 /opt /workspace /data

RUN curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && . "${NVM_DIR}/nvm.sh" \
    && nvm install 22 \
    && nvm install 24 \
    && nvm install 26 \
    && nvm alias default 24 \
    && nvm use 24 \
    && npm install -g \
        pnpm \
        yarn \
        pm2 \
        playwright@1.62.1 \
        playwright-core@1.62.1 \
        puppeteer \
        puppeteer-real-browser \
        puppeteer-extra \
        puppeteer-extra-plugin-stealth \
        camoufox-js@0.13.0 \
        bexxcv@1.1.0 \
    && npm cache clean --force \
    && ln -sfn "${NVM_DIR}/versions/node/$(nvm version default)" /usr/local/node-current

ENV PATH=/usr/local/node-current/bin:${PATH}

RUN . "${NVM_DIR}/nvm.sh" \
    && npx --yes playwright install chromium firefox webkit --with-deps

RUN mkdir -p \
        /opt/camoufox \
        /opt/camoufox-cache \
        /opt/bexxcv \
    && . "${NVM_DIR}/nvm.sh" \
    && CAMOUFOX_INSTALL_DIR=/opt/camoufox npx bexxcv fetch \
    && CAMOUFOX_INSTALL_DIR=/opt/camoufox npx bexxcv doctor

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-17-jdk \
        lib32stdc++6 \
        lib32z1 \
        libc6-i386 \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    mkdir -p /tmp/android-cmdline; \
    cd /tmp/android-cmdline; \
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip; \
    unzip -q commandlinetools-linux-13114758_latest.zip; \
    mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools"; \
    mv cmdline-tools "${ANDROID_SDK_ROOT}/cmdline-tools/latest"; \
    rm -rf /tmp/android-cmdline

RUN yes | sdkmanager --licenses >/dev/null || true

RUN sdkmanager \
        "platform-tools" \
        "platforms;android-${ANDROID_PLATFORM_VERSION}" \
        "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
        "ndk;${ANDROID_NDK_VERSION}" \
        "cmdline-tools;latest" \
    && yes | sdkmanager --licenses >/dev/null || true

RUN mkdir -p /opt/android-sdk/tools \
    && ln -sfn /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager /usr/local/bin/sdkmanager \
    && ln -sfn /opt/android-sdk/platform-tools/adb /usr/local/bin/adb \
    && ln -sfn /opt/android-sdk/platform-tools/fastboot /usr/local/bin/fastboot

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        lsb-release \
        ca-certificates \
        apt-transport-https \
        software-properties-common \
    && add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        php8.2 \
        php8.2-cli \
        php8.2-fpm \
        php8.2-common \
        php8.2-mysql \
        php8.2-pgsql \
        php8.2-sqlite3 \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-xml \
        php8.2-zip \
        php8.2-bcmath \
        php8.2-intl \
        php8.3 \
        php8.3-cli \
        php8.3-fpm \
        php8.3-common \
        php8.3-mysql \
        php8.3-pgsql \
        php8.3-sqlite3 \
        php8.3-curl \
        php8.3-gd \
        php8.3-mbstring \
        php8.3-xml \
        php8.3-zip \
        php8.3-bcmath \
        php8.3-intl \
        php8.4 \
        php8.4-cli \
        php8.4-fpm \
        php8.4-common \
        php8.4-mysql \
        php8.4-pgsql \
        php8.4-sqlite3 \
        php8.4-curl \
        php8.4-gd \
        php8.4-mbstring \
        php8.4-xml \
        php8.4-zip \
        php8.4-bcmath \
        php8.4-intl \
        php8.5 \
        php8.5-cli \
        php8.5-fpm \
        php8.5-common \
        php8.5-mysql \
        php8.5-pgsql \
        php8.5-sqlite3 \
        php8.5-curl \
        php8.5-gd \
        php8.5-mbstring \
        php8.5-xml \
        php8.5-zip \
        php8.5-bcmath \
        php8.5-intl \
        composer \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.3 83 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.4 84 \
    && update-alternatives --install /usr/bin/php php /usr/bin/php8.5 85 \
    && update-alternatives --set php /usr/bin/php8.4 \
    && rm -rf /var/lib/apt/lists/*

RUN php -v \
    && php8.2 -v \
    && php8.3 -v \
    && php8.4 -v \
    && php8.5 -v \
    && composer --version

RUN . "${NVM_DIR}/nvm.sh" \
    && node --version \
    && npm --version \
    && npx --yes bexxcv version \
    && npx --yes bexxcv path

RUN cat > /usr/local/bin/runtime-info <<'EOF'
#!/bin/sh
printf '%s\n' 'ZeroXinvictus Runtime'
printf '%s\n' '---------------------'
printf 'Node       : '
node --version
printf 'npm        : '
npm --version
printf 'PHP        : '
php --version | head -n 1
printf 'Composer   : '
composer --version 2>/dev/null | head -n 1
printf 'Python     : '
python3 --version
printf 'Java       : '
java -version 2>&1 | head -n 1
printf 'ADB        : '
adb version 2>/dev/null | head -n 1
printf 'Playwright : '
playwright --version 2>/dev/null || true
printf 'Bexxcv     : '
npx --yes bexxcv version 2>/dev/null || true
printf 'Camoufox   : '
if [ -d "${CAMOUFOX_INSTALL_DIR}" ]; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'missing'
fi
EOF

RUN chmod +x /usr/local/bin/runtime-info

RUN cat > /usr/local/bin/start-xvfb <<'EOF'
#!/bin/sh
if [ -n "${DISPLAY:-}" ]; then
    exit 0
fi

export DISPLAY=:99

if ! pgrep -x Xvfb >/dev/null 2>&1; then
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension RANDR >/tmp/xvfb.log 2>&1 &
    sleep 1
fi

export DISPLAY=:99
EOF

RUN chmod +x /usr/local/bin/start-xvfb

RUN cat > /usr/local/bin/bexxcv-doctor <<'EOF'
#!/bin/sh
set -e

export CAMOUFOX_INSTALL_DIR="${CAMOUFOX_INSTALL_DIR:-/opt/camoufox}"

printf '%s\n' 'Running Bexxcv doctor...'
npx --yes bexxcv doctor
EOF

RUN chmod +x /usr/local/bin/bexxcv-doctor

RUN cat > /usr/local/bin/browser-status <<'EOF'
#!/bin/sh
printf '%s\n' 'Browser Runtime'
printf '%s\n' '---------------'

printf 'Chromium   : '
if [ -d "${PLAYWRIGHT_BROWSERS_PATH}/chromium-"* ] 2>/dev/null; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'installed'
fi

printf 'Firefox    : '
if [ -d "${PLAYWRIGHT_BROWSERS_PATH}/firefox-"* ] 2>/dev/null; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'installed'
fi

printf 'WebKit     : '
if [ -d "${PLAYWRIGHT_BROWSERS_PATH}/webkit-"* ] 2>/dev/null; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'installed'
fi

printf 'Camoufox   : '
if [ -d "${CAMOUFOX_INSTALL_DIR}" ]; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'missing'
fi

printf 'camoufox-js: '
if npm root -g | xargs -I{} test -d "{}/camoufox-js"; then
    printf '%s\n' 'installed'
else
    printf '%s\n' 'missing'
fi

printf 'bexxcv     : '
if npm root -g | xargs -I{} test -d "{}/bexxcv"; then
    printf '%s\n' 'installed'
else
    printf '%s\n' 'missing'
fi

printf 'bexxcv CLI : '
if command -v bexxcv >/dev/null 2>&1; then
    printf '%s\n' 'ready'
else
    printf '%s\n' 'missing'
fi
EOF

RUN chmod +x /usr/local/bin/browser-status

RUN cat > /usr/local/bin/php-versions <<'EOF'
#!/bin/sh
printf '%s\n' 'PHP Versions'
printf '%s\n' '------------'
php8.2 --version | head -n 1
php8.3 --version | head -n 1
php8.4 --version | head -n 1
php8.5 --version | head -n 1
printf '%s\n' ''
printf '%s\n' 'Default PHP'
php --version | head -n 1
EOF

RUN chmod +x /usr/local/bin/php-versions

ENV PROJECT_NAME=ZeroXinvictus
ENV PROJECT_IDENTITY=ZeroXinvictus

WORKDIR /workspace

RUN useradd \
        --create-home \
        --shell /bin/bash \
        --uid 1000 \
        zero \
    && usermod -aG sudo zero \
    && echo 'zero ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/zero \
    && chmod 440 /etc/sudoers.d/zero \
    && chown -R zero:zero /workspace /data \
    && chown -R zero:zero /home/zero

COPY entrypoint.sh /entrypoint.sh
COPY scripts /scripts

RUN chmod +x /entrypoint.sh \
    && find /scripts -type f -name '*.sh' -exec chmod +x {} \;

ENV SHELL=/bin/bash
ENV TERM=xterm-256color

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

# MyEgg v2

Production-focused Pterodactyl egg image for Node.js, Bun, Python, PHP, Go, Rust, C/C++, Android builds, Playwright, Puppeteer, Firefox, WebKit, and Camoufox.

Identity: ZeroXinvictus

Browser package compatibility includes both `camoufox-js` and `bexxcv`; bexxcv is installed globally so Node projects can use it directly.

## Browser stack

- Chromium
- Firefox
- WebKit
- Puppeteer
- Playwright
- puppeteer-real-browser
- puppeteer-extra
- camoufox-js
- bexxcv 1.1.0
- Camoufox browser runtime
- bexxcv browser runtime support

## Android stack

- Android SDK Command-line Tools
- platform-tools / adb
- Android 16 API 36 platform
- Build Tools 36.0.0
- NDK 28.2.13676358
- OpenJDK 17
- Gradle wrapper compatible projects

## Design goals

- Minimal boot path
- No decorative boot animation
- No always-on live stats loop
- No bundled web terminal
- No bundled Cloudflare tunnel daemon
- No bundled webhook worker
- Configurable dependency installation
- Android SDK and browser runtimes baked into the image
- Clean console UI

## Bexxcv runtime

`bexxcv` is installed globally with `playwright-core@1.62.1`, which satisfies its documented Playwright compatibility range. The image pre-provisions the Camoufox browser under `/opt/camoufox` and exposes the `bexxcv` CLI.

Supported usage includes the package's standard launch API, persistent profiles, plugins, fingerprint tooling, Xvfb helpers, and CLI commands. Projects can still install a local compatible `playwright-core` version when they need dependency isolation.

Build-time verification runs `bexxcv doctor` against the bundled browser data.

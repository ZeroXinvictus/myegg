# myegg

Egg Pterodactyl "Codex Tools": satu image untuk hosting aplikasi Node.js, Bun, Python, PHP, Go, Rust, C/C++ dan Java, lengkap dengan browser automation dan Android SDK.

Image: `ghcr.io/zeroxinvictus/myegg:main`

## Pasang

1. Import `egg-codex-tools.json` di panel (Nests, Import Egg).
2. Push repo ini ke GitHub. Workflow `docker-build.yml` membangun dan push image ke GHCR.
3. Setelah build pertama selesai, ubah visibility package `myegg` jadi Public lewat halaman package di GitHub (satu kali saja, GitHub tidak menyediakan API untuk ini).

Versi image dibaca dari `ENV CODEX_VERSION` di `Dockerfile`.

## Isi image

| Kategori | Detail |
| --- | --- |
| Node.js | 22, 24 (default), 26 lewat nvm, plus pnpm, yarn, pm2 |
| Bun, Go, Rust | versi terbaru saat build (Go otomatis ambil rilis terakhir) |
| Python | 3.12, 3.13 (default), 3.14 |
| PHP | 8.2, 8.3, 8.4 (default), 8.5, plus composer |
| Java | OpenJDK 17 dan 21 |
| Android SDK | cmdline-tools, platform-tools (adb), platform android-36 dan android-37, build-tools 36.0.0 dan 37.0.0 |
| Browser | Playwright Chromium, Firefox, WebKit, Puppeteer, puppeteer-real-browser, Camoufox (Python), camoufox-js |
| Tools | ttyd, cloudflared, ffmpeg, ImageMagick, klien PostgreSQL, MySQL, Redis |

Versi runtime dipilih lewat variabel `NODE_VERSION`, `PYTHON_VERSION`, `PHP_VERSION`, `JAVA_VERSION`. Pemilihan Python dan PHP memakai folder shim di `.codex/bin`, jadi tidak butuh akses root.

## Firefox dan Camoufox

Playwright dipin ke 1.62.0 karena `camoufox-js` mensyaratkan `playwright-core` di bawah 1.63. Versi npm dan pip disamakan supaya browser Playwright dipakai bersama.

Modul global ada di `/opt/node-global` dan terbaca lewat `NODE_PATH`, jadi `require` langsung jalan tanpa install:

```js
const { firefox } = require('playwright');
const { Camoufox } = require('camoufox-js');

(async () => {
  const browser = await Camoufox({ headless: process.env.HEADLESS_MODE !== 'false' });
  const page = await browser.newPage();
  await page.goto('https://example.com');
  console.log(await page.title());
  await browser.close();
})();
```

Python:

```python
from camoufox.sync_api import Camoufox

with Camoufox(headless=True) as browser:
    page = browser.new_page()
    page.goto("https://example.com")
    print(page.title())
```

Catatan:

- `NODE_PATH` tidak dipakai oleh `import` ESM. Untuk project ESM, install lokal: `npm i camoufox-js playwright-core@1.62.0`.
- Path binary tersedia di env: `CHROME_PATH`, `PUPPETEER_EXECUTABLE_PATH`, `FIREFOX_PATH`, `WEBKIT_BIN`. Browser Camoufox untuk Node ada di `CAMOUFOX_INSTALL_DIR`.
- Kalau project memakai versi Playwright lain, browser-nya harus diunduh sendiri karena `/opt/browsers` read-only.
- `HEADLESS_MODE=false` menjalankan aplikasi di Xvfb 1280x1024. Camoufox juga bisa `headless: 'virtual'`.

## Android SDK

Environment diatur otomatis saat boot: `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `GRADLE_USER_HOME` (`.gradle`) dan `ANDROID_USER_HOME` (`.android`). `adb`, `sdkmanager`, `aapt2`, `apksigner` dan `zipalign` masuk ke `PATH`. Gradle daemon dimatikan secara default lewat `GRADLE_OPTS`.

SDK bawaan di `/opt/android-sdk` bersifat read-only. Untuk paket tambahan, isi variabel `ANDROID_PACKAGES`:

```
platforms;android-34 build-tools;34.0.0 ndk;27.0.12077973
```

Paket dipasang sekali ke `/home/container/.android-sdk` (digabung dengan SDK bawaan lewat symlink), dan dilewati saat restart selama isi variabel sama. Kalau install gagal, container tetap jalan dengan SDK bawaan.

Batasan: SDK hanya dipasang di image `linux/amd64` karena build-tools resmi Google tidak ada untuk arm64. Emulator tidak disertakan (butuh KVM).

## Variabel yang sering dipakai

| Variabel | Fungsi |
| --- | --- |
| `STARTUP_CMD` | perintah start, runtime dan dependency dideteksi otomatis |
| `STATIC_HOST_MODE`, `STATIC_HOST_DIR` | host file statis tanpa menulis server |
| `PROCESS_MANAGER` | auto-restart: pm2 untuk Node, supervisor untuk lainnya |
| `INSTALL_DEPS`, `SKIP_DEPS_INSTALL` | pilih package manager atau lewati install |
| `CRON_JOBS` | jadwal cron, mendukung list, range, step, `@daily` dan `@reboot` |
| `ENABLE_AUTO_BACKUP`, `BACKUP_EXCLUDE`, `ENABLE_TELEGRAM_BACKUP` | backup ke `.codex/backups`, bisa dikirim ke Telegram (file besar dipecah 45MB) |
| `WEBHOOK_URL`, `WEBHOOK_PAYLOAD` | notifikasi start, stop, crash. Placeholder: `{event}` `{server}` `{ip}` `{time}` `{exit_code}` |
| `ENABLE_WEB_TERMINAL` | terminal browser via ttyd, tidak jalan selama password masih `changeme` |
| `ENABLE_CF_TUNNEL`, `CF_TOKEN` | Cloudflare Tunnel |
| `GIT_ADDRESS`, `USERNAME`, `ACCESS_TOKEN`, `BRANCH`, `AUTO_UPDATE` | clone atau pull repo saat start |

## Perubahan v15

- Web terminal diperbaiki: sebelumnya Dockerfile mengunduh `ttyd.amd64` yang tidak ada (404), sekarang memakai nama asset yang benar dan build gagal kalau unduhan gagal.
- Tambah camoufox-js, modul Node global lintas versi Node, dan path Firefox.
- Tambah Android SDK, JDK 17/21, variabel `JAVA_VERSION` dan `ANDROID_PACKAGES`.
- Workflow: nama image dipaksa lowercase (GHCR menolak huruf besar), cache pindah ke registry, ruang disk runner dibebaskan, tag versi ditambahkan, build secret `GITHUB_TOKEN` untuk fetch camoufox.
- Dihapus: animasi boot palsu, live stats ticker (`LIVE_STATS_INTERVAL`), langkah "make package public" di workflow (API-nya tidak ada), `libboost-all-dev`, `libx264-dev`, dan download Chrome Puppeteer yang tidak terpakai.
- Pemilihan versi Python dan PHP tidak lagi bergantung pada `update-alternatives` (butuh root).
- `pip install` memakai `--user`, hash dependency disimpan di `.codex/state` (tidak lagi mengotori folder project).
- Token git tidak lagi tersimpan di `.git/config`, dan output git disensor dengan benar saat token kosong.
- Cron: dukungan `@reboot`, `@hourly`, `@daily`, `@weekly`, `@monthly`, semantik tanggal dan hari seperti cron asli, validasi format.
- Backup: exclude folder berat secara default, status error tar dicek, pengiriman Telegram dipecah untuk file besar.
- Webhook: event `crash` dengan `{exit_code}`.

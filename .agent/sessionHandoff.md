# Session Handoff — AGAM

## Current — PB01 scaffolding dan kontrak v1.0, 2 November 2026

**Tujuan sesi:** membuat scaffolding project Flutter (PB01) agar ketiga track dapat mulai bekerja.

**Branch:** `chore/pb01-la-scaffolding` (dari `main` 3dff0f7). Perubahan belum di-commit.

**Yang dibuat:**

- Project Flutter khusus Android: application ID `site.agam`, label "AGAM", minSdk 24, targetSdk/compileSdk 36.
- Flutter 3.47.9 / Dart 3.13.7 dikunci dengan FVM (`.fvmrc`). FVM dipasang lewat Homebrew; developer menjalankan `fvm install` lalu memakai `fvm flutter`.
- Struktur folder per track (`.agent/implementationPhases.md` §2.3) dengan `.gitkeep`.
- Kerangka aplikasi: `lib/main.dart` → `lib/ui/app.dart` (`AgamApp`, layar placeholder bertuliskan "AGAM"); test `test/ui/app_test.dart`.
- `.github/workflows/ci.yml`: format, analyze, test, build APK debug (artifact) pada PR dan push ke `main`.
- `.github/workflows/release.yml`: tag `v*` → build APK rilis → GitHub Releases.
- `.gitignore` standar Flutter + `.fvm/`.

- Kontrak v1.0 di `lib/contracts/`: konstanta produk, model data, antarmuka layanan LA dan LB, fake yang saling terhubung, dan `AppServices.fake()`. Rincian di `.agent/implementationPhases.md` §3. **Disepakati ketiga track pada 2 November 2026**; perubahan berikutnya wajib mengikuti §2.4.
- Test kontrak di `test/contracts/`: jarak haversine dengan nilai acuan yang dihitung terpisah (Python), poligon kampus, progres trail, serta alur fake (pencarian alias, trigger, check-in, respons ringkas saat Navigasi, tiba ≤15 m).

**Pemeriksaan yang dijalankan (lokal, Flutter 3.47.9):** `dart format` tanpa perubahan; `flutter analyze` tanpa issue; `flutter test` 11 test lulus.

**Belum diverifikasi:**

- Build APK lokal: Android SDK belum terpasang di mesin setup (`flutter doctor`: "Unable to locate Android SDK"). JDK lokal adalah versi 27; CI memakai JDK 17.
- Workflow CI dan rilis belum pernah berjalan di GitHub.
- APK belum dipasang di perangkat fisik.

**Keputusan sesi ini:** kontrak v1.0 disepakati ketiga track; application ID `site.agam`; Flutter 3.47.9 via FVM (Homebrew); keystore rilis ditunda ke PB19. Selama itu APK rilis memakai debug key runner CI yang berbeda setiap run, sehingga penguji harus uninstall sebelum memasang versi baru.

**Blocker / data yang belum tersedia** ([PRD §22](PRD.md#22-hal-tertunda-tbd)): project Firebase, konten P01–P10, koordinat pintu masuk, urutan trail, dataset fasilitas, perangkat uji.

**Tindakan PM yang tertunda:** mencatat perbedaan terhadap baseline W9 ([PRD §23](PRD.md#23-perbedaan-terhadap-prd-baseline-w9)) di Change Log PRD resmi.

**Model kerja:** tiga track paralel dengan satu developer per track — FE (frontend), LA (lokasi/sesi/data/audio), LB (peta/rute/pencarian/trail). Track tidak terikat pada orang tertentu. `AGENTS.md` adalah satu-satunya file instruksi agent; jangan menambahkan `CLAUDE.md`.

**Langkah berikutnya:**

1. Commit dan push, buka PR, pastikan workflow CI lulus (termasuk build APK). Disarankan dua commit/PR terpisah: scaffolding PB01 dan kontrak v1.0.
2. Pasang APK debug dari artifact CI di perangkat Android untuk menutup PB01.
3. Kerja paralel Sprint 1 dimulai sesuai `.agent/implementationPhases.md` §5 (PB02–PB04).
4. FE menyambungkan `AppServices.fake()` ke `AgamApp` (saat ini `lib/ui/app.dart` belum memakai layanan apa pun).

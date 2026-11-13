# Session Handoff — AGAM

## Current — Keputusan akun, login, dan log aktivitas, 14 November 2026

**Tujuan:** mendokumentasikan fitur akun atas keputusan PM. Hanya dokumen; tidak ada perubahan kode. Atas instruksi PM, perubahan di-commit pada branch `chore/integration-fe-la-lb` yang dibuat dari `dev` (`a1775f7`); branch yang sama dipakai untuk integrasi berikutnya. Belum di-push.

**Keputusan PM:**

- 6 November 2026: login **wajib**, tidak membuka fitur tambahan; data akun hanya untuk keperluan internal tim (jumlah pengguna, success metric, log aktivitas). Keputusan 4 November (login opsional, opsi sinkron progres) tidak berlaku lagi.
- 14 November 2026: role Mahasiswa ITB dan Pengunjung sebagai label statistik; daftar event log tertutup (PRD §15.5); hapus akun tersedia; log dihapus paling lambat setelah penilaian akhir; tanpa verifikasi email, lupa password lewat email reset; teks pemberitahuan privasi disusun FE dan disetujui PM; progres lokal dipisahkan per akun dan tidak dihapus saat logout; PB21–PB22 dijadwalkan di Sprint 3; tugas utama dipegang LA.
- Pemeriksaan PDF PRD resmi (draft W9 dan presentasi), laporan Sprint 1–2, dan catatan asistensi 4 November: tidak ada fitur login di requirement, backlog, maupun sprint plan. Fitur akun adalah scope baru dan tercatat di PRD §23.

**File yang diubah:** `.agent/PRD.md` (header, §3, §4, §6, §15.1–§15.5, §16, §17, §18, §20, §22, §23), `.agent/rules.md` (§3, §5.1, §5.2, §5.4), `.agent/implementationPhases.md` (header, §2.1, §2.3, §3.3 baru, §4, §5 PB04, §7 beserta PB21/PB22, §10, §11), `AGENTS.md`, dan catatan ini.

**Rancangan privasi log:** event mode dan trail selesai hanya bertanggal karena jamnya dapat bertepatan dengan kedatangan di POI tertentu; `appOpen` hanya saat cold start supaya membuka aplikasi dari notifikasi trigger tidak meninggalkan jejak waktu trigger; rules Firestore memakai `hasOnly` untuk menolak field di luar daftar.

**Belum/terbuka:** project Firebase (Firestore + Authentication) belum dibuat; kontrak v1.1 (§3.3) belum disepakati ketiga track; desain UI10 dan teks pemberitahuan privasi belum ada; success metric dan tanggal penghapusan log belum ditetapkan. PM perlu mencatat perubahan §23 di Change Log PRD resmi.

**Pemeriksaan:** `git diff --check` dan pemeriksaan anchor tautan internal. Tidak ada build atau test karena tidak ada perubahan kode.

**Berikutnya:** PM meninjau diff dan menentukan commit; PM membuat project Firebase; integrasi `LA`/`LB`/`FE` ke `dev` (ditunda atas instruksi PM sampai dokumen akun selesai); usulan kontrak v1.1; PB21–PB22.

---

## Sebelumnya — Bagian LA PB12, 10 November 2026

**Lanjutan sesi yang sama**, setelah commit `38c54a0` di-push ke `origin/LA` atas instruksi pengguna (tanpa PR). Pengguna meminta pesan commit cukup `feat:` + PB, tanpa nomor sprint dan tanpa baris atribusi AI.

**Dibuat:** `lib/logic/audio/device_voice_guidance.dart` (`VoiceGuidance`, `flutter_tts` ^4.2.5, suara `id-ID` offline), `lib/logic/audio/navigation_announcer.dart` (arahan per langkah + audio tiba), query `TTS_SERVICE` di manifest, `createLaServices` kini menerima `navigation` (LB) dan membuat `voice` serta `navigationAnnouncer`. Test: `test/logic/audio/device_voice_guidance_test.dart`, `navigation_announcer_test.dart` (termasuk dengan `FakeNavigationController` kontrak).

**Pemeriksaan:** `fvm flutter analyze` tanpa issue; `fvm flutter test` **225 lulus**; `fvm flutter build apk --debug` berhasil dengan `flutter_tts`. Tidak ada uji perangkat.

**Keputusan terbuka (PM):** pengumuman tiba untuk fasilitas atau fallback TTS saat audio POI belum ada — tidak diterapkan karena PRD §10 membatasi TTS untuk arahan navigasi.

**Berikutnya:** sama dengan catatan di bawah; ditambah integrasi `NavigationAnnouncer` dengan `NavigationController` asli LB.

---

## Sebelumnya — Logic LA Sprint 1–2, 10 November 2026

**Tujuan:** atas permintaan pengguna, mengerjakan seluruh tugas track LA Sprint 1–2 (PB01 CI, PB02, PB03 sisa, PB05 sisa, PB06, PB08, bagian LA PB09). **Branch:** `LA` (dasar `accddc1`, sama dengan `main`/`dev`/`FE`). **Mesin:** macOS, FVM 4.3.2 + Flutter 3.47.9 / Dart 3.13.7 (`fvm flutter`). Belum ada commit, push, PR, atau rilis.

**Package ditambahkan** (versi diperiksa di pub.dev, dikunci `pubspec.lock`): `geolocator` ^14.1.2, `flutter_local_notifications` ^22.3.3 (sengaja bukan 23.0.0 yang dirilis 6 November 2026), `just_audio` ^0.10.6, `audio_service` ^0.18.19, `shared_preferences` ^2.5.6, `path_provider` ^2.1.6; dev `fake_async` ^1.3.3. Perilaku plugin yang dipakai diperiksa dari source di pub cache.

**Yang dibuat/diubah:**

- Android (`android/`): manifest (izin lokasi akurat, foreground service `location`/`mediaPlayback`, notifikasi/getar, `ACCESS_BACKGROUND_LOCATION` dihapus eksplisit, service/receiver audio_service, receiver aksi notifikasi); `MainActivity` turunan `AudioServiceActivity` + channel `site.agam/battery`; desugaring `desugar_jdk_libs` 2.1.4 (README plugin notifikasi); `.kotlin/` di `android/.gitignore`.
- `lib/logic/location/`: `position_source.dart` (geolocator, filter jarak 0), `adaptive_interval.dart`, `device_location_service.dart` (`LocationService`), `device_permission_service.dart` (`PermissionService`); `geofence_engine.dart` + `suspend()` dan `updatePois()`.
- `lib/logic/session/`: `device_session_controller.dart` (`SessionController`), `trigger_notifier.dart`, `trigger_responder.dart`.
- `lib/logic/audio/`: `audio_backend.dart`, `device_audio_service.dart` (`AudioService`), `agam_audio_handler.dart`.
- `lib/logic/settings/device_settings_store.dart` (`SettingsStore`; sebenarnya PB16, dibuat karena auto-play dipakai trigger/PB08).
- `lib/logic/la_bootstrap.dart`: `createLaServices(map:)` merangkai layanan LA asli. **Belum dipanggil** dari `main.dart`.
- CI: `checkout@v7`, `setup-java@v6`, `upload-artifact@v7`, `action-gh-release@v3`; CI juga pada push ke `dev`; `release.yml` menjalankan format + analyze.
- Brief/format konten: `task-implementation/backend/PB09-LA-01-content-format.md`.
- Test baru: `test/logic/{location,session,audio,settings,support}/`, `test/logic/data/content_assets_test.dart`, `test/android/manifest_privacy_test.dart`.
- Dokumen: PRD (header status, §9.2 parameter adaptif + keterbatasan, §17 package, §22), implementation phases (PB01–PB09).

**Keputusan engineering (belum dikalibrasi; tercatat di PRD §9.2):** zona dekat POI = radius + 30 m tanpa perlambatan; diam = <10 m selama ≥30 detik; area kampus hanya dari pembacaan ≤20 m. Interval adaptif hanya diterapkan saat aplikasi tampil karena geolocator memulai ulang foreground service saat langganan diganti. Tombol notifikasi Dengarkan/Lewati diteruskan dari isolate latar belakang ke isolate utama via `IsolateNameServer`.

**Pemeriksaan nyata (mesin ini):**

| Command | Hasil |
| --- | --- |
| `fvm dart format lib test` | Diterapkan; `dart fix --apply` untuk lint initializing formals |
| `fvm flutter analyze` | No issues found |
| `fvm flutter test` | **210 test lulus** (113 lama + 97 baru) |
| `fvm flutter build apk --debug` | Berhasil (`app-debug.apk` ±167 MB debug); Gradle mengunduh Android SDK Platform 35 |
| Manifest merge debug | Tanpa `ACCESS_BACKGROUND_LOCATION`; `INTERNET` dari manifest debug Flutter; `ACCESS_NETWORK_STATE` dari media3 |
| `git diff --check` | Lulus |

**Tidak dijalankan:** emulator, perangkat fisik, build rilis, workflow GitHub, field test. Catatan test: dalam `fakeAsync`, future `cancel()` bawaan Dart terjadwal di zona root sehingga penghentian langganan pada auto-end diverifikasi lewat jalur `_end` di test non-fakeAsync.

**Status:** PB02, PB06, PB08, PB09 → `in_progress` (logic LA selesai, belum terintegrasi/diuji perangkat). PB01/PB03/PB05 tetap `in_progress`. Tidak ada yang `done`.

**Blocker/tertunda:** Firestore (project Firebase belum ada); konten/audio P01–P10; perangkat uji; urutan trail. `VoiceGuidance` (PB12, Sprint 3) belum dibuat.

**Berikutnya:**

1. Review diff; commit di `LA` hanya dengan instruksi pengguna (disarankan dipisah: Android+package, lokasi/izin, sesi/notifikasi, audio/pengaturan, CI, dokumentasi).
2. Integrasi bersama FE/LB: panggil `createLaServices(map: <MapConfig LB>)` di `main.dart`, rangkai `AppServices` (sementara `FakeVoiceGuidance`). `TriggerResponder.viewRequests` belum ada di `AppServices` v1.0 → perlu kesepakatan FE (usulan kontrak §2.4) atau penyambungan di `main.dart`.
3. Uji perangkat fisik: izin (termasuk perkiraan), trigger saat layar mati, notifikasi + tombol di lock screen, narasi dari notifikasi, auto-end, optimasi baterai per merek, dan ikon notifikasi (saat ini memakai `ic_launcher`; ikon monokrom mungkin diperlukan).
4. Verifikasi CI baru berjalan di GitHub setelah push/PR.

---

## Sebelumnya — Penyelarasan lokasi brief, 4 November 2026

**Otorisasi:** pengguna meminta satu commit dokumentasi diselaraskan dan di-push ke lima branch tetap (`main`, `dev`, `LA`, `LB`, `FE`), kemudian PB04-LB-01 dikerjakan lokal pada `LB`. Branch historis PB03 tidak diubah; tanpa PR, merge fitur, atau rilis. Instruksi ini menggantikan pembatasan publikasi sesi sebelumnya khusus migrasi dokumentasi ini.

**Struktur aktif:** panduan di `task-implementation/README.md`; brief logic LA/LB di `task-implementation/backend/`. Brief PB05 dipindahkan dari `.agent/tasks/`; seluruh penyebutan path lama di catatan historis di bawah menggambarkan lokasi pada waktu sesi tersebut, bukan lokasi aktif.

**Dasar pemeriksaan:** working tree bersih di `dev`; `main`, `dev`, dan `LA` lokal/remote sama-sama `29db871`; `LB`/`FE` belum ada. Pembuatan kedua branch dari `dev` dan publikasi eksplisit dilakukan setelah pemeriksaan dokumentasi. Hasil publikasi diverifikasi sebelum mulai implementasi LB dan dicatat dalam handoff lokal LB berikutnya.

**Verifikasi dokumentasi:** pemeriksaan target tautan relatif, referensi lokasi aktif, dan `git diff --check`. Status PBI tidak berubah oleh migrasi. Flutter/build/perangkat tidak diperlukan untuk perubahan dokumentasi ini.

---

## Sebelumnya — Migrasi progres LA dan publikasi GitHub, 4 November 2026

**Instruksi pengguna:** lanjutkan progres PB03/PB05 pada `LA`, biarkan branch PB03 lama, jangan push branch PB05 terpisah, dan push pekerjaan ke GitHub. Instruksi ini mengotorisasi commit/push untuk perubahan yang disiapkan; tidak mencakup merge ke `dev`/`main`, penghapusan branch PB03, atau rilis.

**Migrasi aktual:** branch lokal `feat/pb05-la-geofence-engine` diganti menjadi `LA` tanpa kehilangan perubahan. Dasarnya `b1b165b` sudah mencakup PB03 (`1344c21` dan `b1b165b`). Branch `feat/pb03-la-poi-repository` lokal/remote dipertahankan. Sebelum publikasi, remote `LA` maupun branch PB05 belum ada; remote `dev`/PB03 masih menunjuk `b1b165b` dan `main` menunjuk `fbef32c`. Branch LB/FE tidak dibuat dalam sesi ini.

**Commit:** `5256ec0` — `feat: add synchronous geofence engine with deterministic tests` (engine dan test PB05). Dokumentasi brief, parameter PRD, progres, serta aturan branch tetap disiapkan dalam commit terpisah pada `LA`. Catatan branch lama di bawah adalah riwayat sesi sebelumnya, bukan branch aktif.

**Verifikasi ulang sebelum publikasi:** SDK terkunci Flutter 3.47.9 / Dart 3.13.7 pada path absolut yang tercatat di sesi PB05 digunakan untuk `dart format --output=none --set-exit-if-changed lib test` (31 file, 0 perubahan), `flutter analyze` (tanpa issue), dan `flutter test --reporter compact` (**113 test lulus**). `git diff --check` lulus. Tidak ada perubahan dependency, UI, Android, atau CI. PB03 dan PB05 tetap `in_progress`; hasil ini bukan acceptance perangkat/field test.

**Publikasi:** hanya target `origin/LA` melalui `git push -u origin LA`. Hasil push dan kesamaan hash remote diperiksa setelah commit dokumentasi; hasil akhirnya dilaporkan pada chat. Jangan push semua branch, branch PB05, atau mengubah branch PB03 lama.

**Berikutnya:** pekerjaan LA menggunakan `LA`; integrasi berikutnya melalui PR `LA` → `dev`, bukan push langsung ke `dev`/`main`. Penyesuaian CI untuk push ke `dev` tetap tindak lanjut terpisah. LA-01 selesai secara teknis; integrasi PB06, interval adaptif, dan kalibrasi tetap tertunda.

---

## Pembaruan aturan branch tetap — 4 November 2026

**Permintaan:** mengganti model branch per task menjadi lima branch tetap `main`, `dev`, `LA`, `LB`, dan `FE`. `dev` menjadi pusat integrasi; `main` untuk versi stabil. Alur PR: branch track → `dev`, kemudian `dev` → `main` setelah verifikasi integrasi. Review, ownership, persetujuan perubahan kontrak, dan larangan commit/push/merge tanpa instruksi tetap berlaku.

**Perubahan sesi ini:** hanya `.agent/rules.md`, bagian alur kerja pada `.agent/implementationPhases.md`, `.agent/tasks/README.md`, dan catatan handoff ini. Tidak mengubah kode, workflow CI, status PBI, branch Git, atau pekerjaan PB05 yang sudah ada. Nama branch lama di catatan historis dipertahankan.

**Keadaan checkout saat pemeriksaan:** masih `feat/pb05-la-geofence-engine`, dengan perubahan implementasi/dokumentasi PB05 yang belum di-commit. Tidak dilakukan switch, rename, merge, maupun penghapusan branch agar pekerjaan sesi utama tidak terganggu. Migrasi checkout ke model baru memerlukan instruksi pengguna tersendiri.

**Verifikasi:** pemeriksaan konsistensi aturan branch aktif dan `git diff --check`; tidak menjalankan ulang test/build karena perubahan sesi ini hanya dokumentasi. Evidence test PB05 pada catatan sebelumnya tetap merupakan hasil sesi implementasi tersebut.

**Tindak lanjut:** siapkan/sinkronkan branch tetap sesuai instruksi pengguna; LA menyesuaikan CI agar push ke `dev` juga diperiksa. CI saat ini sudah mencakup PR, tetapi push hanya ke `main`. Ini belum mengubah konfigurasi atau branch protection GitHub.

---

## Current — PB05-LA-01 engine geofence dan brief task, 4 November 2026

**Tujuan:** mengadopsi brief task dan mengimplementasikan engine geofence murni sesuai rencana pengguna. **Branch:** `feat/pb05-la-geofence-engine`, dibuat dari checkout `dev` pada `b1b165b`. Perubahan review sebelumnya pada file ini dipertahankan. Tidak ada commit, push, merge, atau rilis.

**Perubahan:**

- `.agent/tasks/README.md`: tata cara brief, penamaan, konteks, ownership, dan evidence.
- `.agent/tasks/PB05-LA-01-geofence-engine.md`: spesifikasi diadopsi, API, state machine, validasi, matriks test, batas PB06, acceptance, dan contoh instruksi agent.
- `lib/logic/location/geofence_engine.dart`: engine sinkron memakai model/konstanta existing; snapshot POI, dwell/cooldown/histeresis, validasi input, timestamp monoton, dan kalkulator jarak terinjeksi. State pengguna hanya waktu/flag per POI; tanpa riwayat koordinat, jaringan, timer, atau penyimpanan.
- `test/logic/location/geofence_engine_test.dart`: 46 test deterministik; fixture sintetis, batas numerik, multi-POI, kualitas input, aktivasi, cooldown, snapshot, konfigurasi invalid, dan haversine default dengan acuan existing independen.
- PRD §9.2/§22: margin default 5 m serta jeda sampel maksimum 10 detik **diterapkan, belum dikalibrasi**. Implementation phases menautkan brief dan mencatat PB05/Sprint 2 `in_progress`; Sprint 1 belum dianggap selesai.

**Lingkungan dan command nyata:** pada awal sesi `fvm dart format ...`, `fvm flutter analyze`, serta kedua command test gagal dimulai karena `fvm` tidak ada di PATH. Flutter/Dart global juga tidak ditemukan. SDK resmi tag `3.47.9` (`c197ca5199e9ee5661e865596c9c07294dfab51c`) di-clone ke `C:\Users\ASUS\.cache\tooling\flutter-3.47.9`, di luar repo; bootstrap memastikan Flutter 3.47.9 / Dart 3.13.7. Metadata archive awal memberi HTTP NoSuchKey; unduhan SDK lewat bootstrap resmi kemudian berhasil. FVM 4.3.2 juga dipasang lewat `dart pub global activate fvm`, tetapi PATH sistem tidak diubah dan pemeriksaan berikut memakai SDK terkunci langsung. Tidak ada perubahan pubspec atau lockfile.

Dalam tabel, `<sdk>` = `C:\Users\ASUS\.cache\tooling\flutter-3.47.9`; command dijalankan dari root repo dengan operator PowerShell `&` dan path executable berpetik.

| Command/check | Hasil aktual | Cakupan/keterbatasan |
| --- | --- | --- |
| `<sdk>\bin\flutter.bat --version` | Flutter 3.47.9 / Dart 3.13.7 | SDK sama dengan `.fvmrc`; bukan Flutter global |
| `<sdk>\bin\flutter.bat pub get` | Lulus | Dependency existing, tanpa upgrade requirement/lockfile |
| `<sdk>\bin\cache\dart-sdk\bin\dart.exe format lib/logic/location/geofence_engine.dart test/logic/location/geofence_engine_test.dart` | Dua file diformat | Awalnya peringatan lint include belum ter-resolve sebelum pub get |
| `<sdk>\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test` | 31 file, 0 perubahan | Check setelah pub get |
| `<sdk>\bin\flutter.bat analyze` | No issues found | Analisis statis seluruh proyek |
| `<sdk>\bin\flutter.bat test test/logic/location/geofence_engine_test.dart` | 46 test lulus | Logic murni, bukan GPS/perangkat |
| `<sdk>\bin\flutter.bat test` | 113 test lulus | 67 existing + 46 geofence |
| `git diff --check` dan pemeriksaan tautan file lokal brief | Lulus | Tidak menggantikan review kode/manusia |

**Status:** LA-01 selesai secara teknis dan teruji lokal. PB05 tetap `in_progress`; acceptance F02/perangkat/lapangan belum diverifikasi. Tidak menjalankan APK build, emulator, perangkat fisik, CI remote, atau field test. UI, Android, kontrak bersama, fake, dan package tidak diubah. Penggunaan AI material sesi ini perlu dicakup PB20 oleh tim.

**Berikutnya:** review perubahan; lanjutkan PB02/PB04 dan integrasi Sprint 1. Sebelum PB06 memakai engine, tetapkan lifecycle instance, pembaruan dataset tanpa kehilangan cooldown, pemetaan enabled dari sesi/area, dan pemetaan kandidat menjadi respons per mode. Interval GPS adaptif tetap belum dikerjakan. Kalibrasi margin/jeda perlu perangkat fisik dan field test; daftar perangkat tetap menunggu tim.

---

## Review dokumentasi dan keadaan checkout — 4 November 2026

**Tujuan sesi:** memeriksa dan menjelaskan cara pengembangan proyek berdasarkan seluruh dokumen `.agent/`, disertai pemeriksaan terbatas terhadap source dan konfigurasi.

**Temuan:** checkout berada di branch `dev`; working tree bersih sebelum pencatatan ini. Commit terbaru `b1b165b` (dokumentasi PB03) dan `1344c21` (dataset dan repository POI) menunjukkan pekerjaan PB03 sudah di-commit pada checkout ini. Keterangan belum di-commit pada sesi sebelumnya merupakan catatan historis. Status implementasi pada header PRD (repository hanya berisi dokumentasi) sudah usang; source sudah memiliki scaffolding, kontrak/fake, dan lapisan data PB03. `lib/ui/app.dart` masih menampilkan placeholder "AGAM" dan dependency di `pubspec.yaml` belum mencakup plugin lokasi atau Firestore.

**Perubahan sesi:** hanya catatan review ini; tidak mengubah kode, keputusan produk, atau status PBI. PB01 dan PB03 tetap `in_progress`; blocker dan langkah implementasi pada sesi sebelumnya tetap berlaku. Status merge PB03 ke `main` tidak diverifikasi.

**Verifikasi:** membaca empat dokumen `.agent/`, memeriksa daftar source/test/aset, `lib/ui/app.dart`, `pubspec.yaml`, `.fvmrc`, serta branch, status, dan tiga commit terbaru. `git diff --check` dijalankan setelah pencatatan. Build, analyze, test Flutter, CI remote, dan uji perangkat tidak dijalankan; hasil 67 test dan CI pada sesi sebelumnya adalah evidence historis.

**Langkah berikutnya:** selaraskan catatan status dokumen dengan checkout saat pekerjaan implementasi berikutnya; lanjutkan sisa PB01, PB02, PB03, dan PB04 sesuai pembagian track. Panduan instalasi FVM lewat Homebrew pada dokumen berasal dari mesin sesi sebelumnya, bukan instruksi yang telah diverifikasi untuk Windows.

**Pemeriksaan lanjutan CI/CD:** membaca `.github/workflows/ci.yml`, `release.yml`, widget test placeholder, dan sebagian test repository. CI pada PR dan push ke `main` menjalankan format, analyze, test, build APK debug, lalu upload artifact. Release pada tag `v*` menjalankan test, build APK release, lalu menerbitkan GitHub Release; belum menjalankan format/analyze dalam workflow tersebut. Workflow belum menjalankan aplikasi di emulator/perangkat atau integration test. Push ke `dev` saja tidak memicu CI kecuali ada PR yang sesuai. Pemeriksaan ini hanya membaca konfigurasi lokal; tidak menjalankan test/build atau memverifikasi run GitHub terbaru. Tidak ada perubahan status PBI.

---

## Current — PB03 dataset dan PoiRepository (track LA), 3 November 2026

**Tujuan sesi:** mengerjakan bagian PB03 yang tidak bergantung pada project Firebase.

**Branch:** `feat/pb03-la-poi-repository` (dari `main` fbef32c). Perubahan belum di-commit.

**Yang dibuat:**

- `assets/data/pois.json` — dataset bawaan 10 POI. Id, nama, alias, kategori, koordinat, dan radius 15 m diambil dari [PRD §9.1](PRD.md#91-dataset-poi); seluruh teks dan media berlabel `PLACEHOLDER`, `entrances` kosong, `trailOrder` null, metadata belum disetujui. Didaftarkan di `pubspec.yaml` (folder `assets/data/` milik LA).
- `lib/logic/data/poi_codec.dart` — validasi per dokumen (tipe, rentang koordinat, radius > 0, field wajib, id ganda, kelengkapan metadata A02). Dokumen tidak valid diabaikan satu per satu beserta alasannya, bukan menggagalkan seluruh dataset.
- `lib/logic/data/poi_sources.dart` — `BundledDataset`, `DatasetCache` (`FileDatasetCache`, `InMemoryDatasetCache`), dan `RemoteDatasetSource`. Selama project Firebase belum ada, defaultnya `UnavailableRemoteSource` sehingga aplikasi menempuh jalur fallback [PRD §15.2](PRD.md#152-alur-sinkronisasi).
- `lib/logic/data/poi_repository_impl.dart` — `PoiRepository` asli: urutan cache → JSON bawaan, `refresh()` yang tidak pernah melempar error jaringan, dan dataset tanpa POI valid tidak dipakai maupun disimpan ke cache.
- `lib/logic/data/data.dart` — barrel export lapisan data.
- Test di `test/logic/data/`: validasi dokumen, alur sumber data, dan penguncian dataset bawaan terhadap PRD §9.1.
- [PRD §15.3](PRD.md#153-skema-konseptual) diperbarui: nama field final, nilai enum `category`, dan tabel aturan validasi.

**Pemeriksaan yang dijalankan (lokal, Flutter 3.47.9 via FVM):** `fvm dart format --set-exit-if-changed lib test` tanpa perubahan; `fvm flutter analyze` tanpa issue; `fvm flutter test` **67 test lulus** (56 baru + 11 test kontrak). Test dataset bawaan diuji benar-benar menangkap kesalahan: satu koordinat P01 sengaja diubah → test gagal; dataset dipulihkan → lulus kembali.

**Catatan lingkungan:** FVM belum ada di mesin ini dan dipasang sesi ini (`brew install leoafarias/fvm/fvm`, FVM 4.3.2) lalu `fvm install` mengambil Flutter 3.47.9 / Dart 3.13.7. Flutter global di mesin ini 3.35.7 (Dart 3.9.2) dan **tidak dapat** dipakai: `pubspec.yaml` mensyaratkan `sdk: ^3.13.7`. Gunakan `fvm flutter`, bukan `flutter`.

**Belum diverifikasi / blocked:**

- Sinkronisasi Firestore belum dibuat: project Firebase belum ada ([PRD §22](PRD.md#22-hal-tertunda-tbd)), `cloud_firestore` belum ditambahkan ke `pubspec.yaml`.
- Direktori cache untuk `FileDatasetCache` saat integrasi masih butuh package penyedia path; versinya wajib diverifikasi sebelum ditambahkan.
- PB03 belum terintegrasi dengan UI dan belum diuji di perangkat fisik, sehingga statusnya `in_progress`, bukan `done`.

**Temuan tentang PB01 (memperbaiki catatan sesi sebelumnya):** branch `chore/pb01-la-scaffolding` sudah di-merge ke `main` lewat PR #1 (fbef32c). Workflow CI **sudah berjalan dan sukses** dua kali (run 41424657609 pada PR dan 41424686250 pada `main`), masing-masing menghasilkan artifact `agam-debug-apk`. Jadi sisa PB01 tinggal memasang APK debug di perangkat fisik. Catatan "1 test lulus" di PB01 sudah usang; suite sekarang 67 test. CI memberi peringatan deprecation: `actions/checkout@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4` dipaksa ke Node.js 24, dan `ubuntu-latest` akan pindah ke Ubuntu 26 pada 19 Oktober 2026.

**Langkah berikutnya:**

1. Review dan merge PR PB03 (hanya menyentuh folder milik LA, `assets/data/`, `pubspec.yaml`, dan `.agent/`).
2. Pasang APK debug dari artifact CI di perangkat Android untuk menutup PB01.
3. LA melanjutkan PB02: `PermissionService` dan `LocationService` asli. Butuh menambah `geolocator` (dan package izin) dengan versi yang diverifikasi lebih dulu, plus perubahan di `android/`.
4. Saat project Firebase tersedia, implementasikan `RemoteDatasetSource` untuk Firestore dan ganti `UnavailableRemoteSource`; test alur fallback sudah tersedia.
5. Pertimbangkan memperbarui versi action di `.github/workflows/` (perubahan `.github/` milik LA).

---

## Sebelumnya — PB01 scaffolding dan kontrak v1.0, 2 November 2026

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

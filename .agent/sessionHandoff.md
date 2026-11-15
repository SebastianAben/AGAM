# Session Handoff — AGAM

## Current — APK internal terbaru dipasang ke OPPO, 16 November 2026

**Instruksi:** pengguna meminta instalasi APK terbaru pada HP. Branch `LB`
sebelumnya sudah dipush; APK sumbernya dari `LB` HEAD `d15c57c` (source FE demo
repository-backed) dan telah dibangun lokal.

**Perangkat/aksi:** ADB mendeteksi OPPO CPH2739 / Android 16. APK
`build/app/outputs/flutter-apk/app-debug.apk` (`site.agam` 1.0.0+1, minSdk 24,
targetSdk 36) dipasang dengan `adb install -r`, tanpa uninstall dan tanpa
menghapus data. ADB melaporkan `Success`.

**Verifikasi:** SHA-256 APK host dan `/data/app/.../base.apk` terpasang sama:
`9bf687a32fa492c4cae0e638eadd26e5211087fcdd39baf3903a97d0c37014d6`.
Pemasangan saja yang diminta; aplikasi belum diluncurkan dan UI Cari POI,
Explore, izin, GPS, atau session baru belum diuji pada build ini. Tidak
mengambil/mencatat posisi perangkat.

**Berikutnya:** bila diperlukan, lakukan launch/smoke test UI baru pada perangkat;
uji fisik Labtek V tetap butuh pengguna berada di lokasi. APK dibangun dengan
shell demo dua tab, tetapi pemasangan ini belum menjadi bukti acceptance.

---

## Current — FE demo sementara repository-backed, 16 November 2026

**Permintaan:** sambungkan tampilan FE yang telah di-merge ke fungsi nyata di
source, khusus sementara untuk demo, dan dorong pembaruan pada branch `LB`.

**Implementasi pada branch `LB` (basis `046b646`):** `lib/ui/app.dart` menampilkan
shell demo dua tab Jelajah/Cari POI, dengan tab FE Cari POI yang memakai layout
UI05 yang sudah ada. `PoiSearchService` baru membaca dari `PoiRepository`,
menormalkan alias Arab/Romawi, mengurutkan kecocokan, lalu hasil membuka UI04 dan
`AudioService` LA. Jalur Explore/UI02/UI03/UI04 tetap memakai peta, posisi, sesi,
geofence, notifikasi dan repository yang ada. Demo memakai `bundledOnly` agar
dataset berasal dari JSON APK tanpa cache konten lama atau refresh Firestore.
Commit source/dokumen rencana dan status PBI: `d15c57c` (`feat: wire real POI
search into demo shell`). Push fast-forward ke `origin/LB` berhasil; remote
diverifikasi pada SHA `d15c57ced8f5bf0651ac88ad0f4ba28d4b88960d`.

**Batas:** perubahan hanya pada flag `AGAM_INTERNAL_DEMO=true`; shell default
tidak diubah. Trail, fasilitas, navigasi dan profil/akun tidak diekspos karena
service/graf/data yang diperlukan belum tersedia atau masih TBD. Navigation
fake masih menjadi dependency `AppServices` tetapi tidak dipanggil/ditampilkan
di shell demo. Pencarian ini tidak menutup PB10. Konflik konten P01 approved vs
PRD §22 tetap mengikuti catatan sebelumnya; tidak mengubah data/approval.

**Verifikasi/perilaku delivery:** formatter 6 file source (0 perubahan),
`flutter analyze --no-pub` tanpa issue, build APK internal berhasil (16,4 detik)
dan audit aset APK lulus. APK: 185.500.958 byte, SHA-256
`9bf687a32fa492c4cae0e638eadd26e5211087fcdd39baf3903a97d0c37014d6`.
Test Flutter tidak dijalankan setelah update; hasil sebelumnya 251 lulus/1 gagal
karena assertion PLACEHOLDER P01 tetap belum diselaraskan dengan PRD §22.
UI Cari POI belum diuji runtime. Tidak mengubah kontrak atau PRD produk.

**Langkah berikutnya:** setelah review, jalankan test/UI Cari POI pada emulator.
Uji fisik Labtek V tetap terpisah dan diperlukan untuk menutup temporary demo.

---

## Sebelumnya — Pemeriksaan temporary demo pada branch LB, 16 November 2026

**Branch/source:** pekerjaan berada di worktree `AGAM-LB-PB04`, branch lokal `LB`, HEAD `046b646` (sama dengan `dev`). Tidak melakukan commit atau push. WIP dokumentasi yang sudah ada di worktree dipertahankan; dependency dipulihkan dengan `flutter pub get --enforce-lockfile`, tanpa perubahan `pubspec.lock`.

**Verifikasi source:** Flutter 3.47.9 / Dart 3.13.7; format 78 file tanpa perubahan; analyzer lulus; suite Flutter **251 lulus, 1 gagal** pada `test/ui/demo_explore_test.dart:187` karena assertion mencari `PLACEHOLDER`, sementara data P01 menandai `isPlaceholder: false` dan `approved: true`. PRD §22 masih menyatakan konten P01–P10 belum tersedia. Tidak mengubah test/UI milik FE atau data milik LA; minta PM/tim konten menyelaraskan status sumber sebelum menganggap P01 konten final.

**Build/peta:** 21 test pipeline lulus; audit source lulus. Build APK internal dari `LB` HEAD `046b646` lulus; `build/app/outputs/flutter-apk/app-debug.apk`, 185.500.958 byte, SHA-256 `162edfa6c98d805e30ae0d356846c68829c4f8b800ef75a174817441026c1329`. Audit APK memastikan PMTiles, style, dan manifest identik dengan source.

**Runtime simulasi:** AVD `agam_demo_api36` (API 36) dipakai dengan Wi-Fi/data mati. APK terbaru menampilkan basemap, atribusi, POI dan posisi simulasi; Explore dimulai; mock location dari koordinat P01 di dataset menghasilkan trigger UI03 dan tombol Lihat membuka detail Labtek V. Log Android tidak menunjukkan crash selama smoke test. Ini bukan bukti GPS/trigger fisik, field acceptance, atau audit privasi runtime lengkap. AVD dihentikan setelah test; `adb devices -l` tidak menemukan perangkat fisik ketika diperiksa.

**Temporary demo belum selesai:** perangkat fisik di Labtek V belum tersedia, build terbaru belum dipasang di OPPO, field trigger dan audit storage/network belum dilakukan, dan suite Flutter belum seluruhnya hijau. Checklist serta bukti terbaru dicatat di [rencana demo sementara](demo-apk-temporary-plan.md); pertahankan file dan pointer sampai semua kriteria §5 tercapai. PB04 tetap `in_progress`.

**Berikutnya:** selaraskan status konten P01 antara PRD §22 dan dataset dengan PM/tim konten; minta FE menyesuaikan assertion setelah sumber kebenaran dipastikan, lalu ulangi suite. Saat HP dan lokasi tersedia, install APK hash di atas, jalankan uji fisik P01 serta audit privasi; hanya setelah itu tinjau kriteria penghapusan rencana.

---
## Sebelumnya — Sinkronisasi branch LB dengan dev, 16 November 2026

**Branch/worktree:** `LB` sudah aktif di worktree `AGAM-LB-PB04`, pada `d602fed`; `dev` dan `origin/dev` berada di `046b646` dan 11 commit lebih maju. WIP tracked/untracked LB disimpan dengan stash `Preserve LB work before syncing dev`, lalu `LB` di-fast-forward ke `046b646`, sehingga HEAD branch sama dengan `dev`.

**Pemulihan WIP:** konflik dokumentasi diselesaikan dengan mempertahankan status terbaru dari `dev` dan menggabungkan keterangan batas area pada PRD. File lokal yang beradu dengan file baru di `dev` tidak menimpa versi `dev`; salinan pra-sinkronisasi tetap berada di stash. `tools/tiles/PB04-integration.md` dan `tools/tiles/pubspec-map-assets.patch` yang tidak bertabrakan dipulihkan ke worktree. Tidak ada commit atau push.

**Verifikasi:** fast-forward berhasil; automated test, analyzer, dan build tidak dijalankan karena sesi ini hanya menyelaraskan branch dan merapikan konflik dokumentasi. Status PBI tidak berubah.

**Berikutnya:** lanjutkan pekerjaan LB dari basis `046b646`; sebelum memakai kembali salinan lama dari stash, bandingkan dengan implementasi terbaru yang kini ada di `dev`. Jalankan pemeriksaan PB04 yang relevan sebelum mengajukan PR.

---
## Sebelumnya — Sinkronisasi `dev` dan pemulihan WIP, 16 November 2026

**Git:** `git fetch origin` menemukan `origin/dev` maju dari `d602fed` ke `8950a27`; checkout lokal `dev` berada di `089883c` dan tertinggal 11 commit. Seluruh perubahan tracked/untracked disimpan sementara dengan `git stash push --include-untracked`, lalu branch di-fast-forward ke `8950a27`. WIP diterapkan kembali tanpa reset atau force; stash pengaman masih dipertahankan.

**Isi remote yang kini ada di `dev`:** integrasi PB03 Firestore dan seed workflow, konten POI/media, serta perbaikan notifikasi PB06 (PR #4/#5). Konflik pemulihan pada `implementationPhases.md`, `sessionHandoff.md`, `main.dart`, `pubspec.yaml`, dan `pubspec.lock` sudah diselesaikan dengan mempertahankan perubahan remote dan demo lokal.

**WIP lokal:** pipeline dan aset peta PMTiles, renderer offline, alur Explore, perbaikan lokasi/geofence, test dan dokumentasi demo tetap dipertahankan. `main.dart` menggabungkan Firebase dengan gerbang demo eksplisit: Firebase diinisialisasi pada build `AGAM_INTERNAL_DEMO=true`, sementara build biasa tetap menampilkan gerbang login yang belum tersedia.

**Verifikasi:** evidence sebelumnya di `.agent/implementationPhases.md` (246 test Flutter, 21 test pipeline, format/analyze, build dan audit APK, serta pemeriksaan pada OPPO CPH2739) berasal dari source `089883c` + WIP sebelum sinkronisasi. Build dan test belum dijalankan pada tree gabungan ini; jangan menganggap APK/evidence lama sebagai verifikasi commit gabungan.

**Dependency:** setelah menggabungkan dependency Firebase dan peta pada `pubspec.yaml`, `flutter pub get` (Flutter 3.47.9) berhasil dan menyusun ulang lockfile tanpa mengubah versi package yang sudah terkunci; dependency peta yang dibutuhkan ditambahkan.

**Pemeriksaan pada tree gabungan:** `flutter pub get` berhasil; `dart format --output=none --set-exit-if-changed lib test` melaporkan 78 file, 0 perubahan; `flutter analyze --no-pub` tanpa issue; `git diff --cached --check` lulus. Automated test dan build APK tidak dijalankan setelah sinkronisasi, jadi evidence lama tetap terbatas pada source sebelumnya.

**Berikutnya:** jalankan CI pada `dev`, build dan audit APK dari tree gabungan, lalu lanjutkan simulasi emulator serta pengujian fisik/field P01 dan audit jaringan sesuai checklist di rencana demo. Pertahankan status PBI `in_progress` sampai evidence acceptance tersedia.

---
## Sebelumnya — Setup Firebase dan sumber Firestore PB03, 15 November 2026

**Konteks:** PR #3 (integrasi) sudah di-merge ke `dev`; branch `chore/integration-fe-la-lb` dihapus (lokal dan remote) atas instruksi PM. Pekerjaan ini di branch `feat/pb03-firestore-setup` dari `dev` `d602fed`, tanpa upstream ke `dev`. Empat commit PB06/PB09 di `LA` (`c8c06a6`…`605c8a9`) belum di `dev` dan dibiarkan untuk PR developer LA; simulasi menunjukkan tumpang tindih hanya mungkin di `pubspec.yaml` (bagian berbeda). PM perlu memberi tahu developer LA bahwa setup Firebase dikerjakan di branch ini.

**Firebase:** PM membuat project `agam-9e704` (Spark; Firestore Standard `asia-southeast2` production mode; Authentication Email/Password; Analytics tidak aktif). Firebase CLI 15.36.0 (Homebrew) dan FlutterFire CLI 1.5.0 dipasang di Mac PM; FlutterFire dijalankan lewat `fvm dart pub global run flutterfire_cli:flutterfire` karena wrapper global memakai Dart 3.8.1. Login CLI: akun PM. App Android `site.agam` terdaftar (`1:748977574626:android:1cd75697e6d1923b9104bb`).

**Keputusan PM (15 November 2026):** `assets/data/pois.json` satu-satunya sumber konten; Firestore disinkronkan otomatis oleh workflow saat `pois.json` berubah di `dev`, dan pindah ke `main` pada PB19; konten tidak diedit di Console; seed memakai Node; login Google/Apple tidak ditambahkan. Dicatat di PRD §15.2 dan §15.4.

**Perubahan:** lihat PB03 di `implementationPhases.md`. Ringkas: `firebase_core` ^5.1.0, `cloud_firestore` ^7.1.0, dev `fake_cloud_firestore` ^4.5.0; `FirestoreDatasetSource`; `refresh()` dipanggil di bootstrap; `INTERNET` di manifest (test manifest diubah dari melarang menjadi mewajibkan); `firestore.rules`, `firebase.json`, `.firebaserc`; `tools/firestore/` (seed, test rules, README, `package-lock.json`: `firebase-admin` 14.5.1, dev `@firebase/rules-unit-testing` 5.0.2 dan `firebase` 12.19.0); `.github/workflows/seed-firestore.yml` (`actions/setup-node@v7`).

**Pemeriksaan:** `dart format` 0 perubahan; `flutter analyze` tanpa issue; `flutter test` lulus (termasuk 3 test baru `firestore_dataset_source_test.dart`); test rules 21 lulus di emulator (Java 27 Homebrew), dan satu mutasi sengaja (melonggarkan `featureUsed`) tertangkap lalu dipulihkan; seed diuji di emulator (tulis 10, hapus dokumen asing, `--dry-run` tidak menulis). Rules di-deploy ke `agam-9e704` dan dikompilasi tanpa error. Seed pertama ke `agam-9e704` dari `pois.json` `dev` `d602fed`: 10 `pois`, 0 `facilities`; REST tanpa login dapat membaca `pois` dan ditolak (403) untuk `users`. Service account `agam-seed` (Cloud Datastore User) dibuat PM; key disimpan di luar repo (folder `Tubes`, bukan repo git, izin 600) dan isinya tidak dibaca agent. **Belum:** build APK (Android SDK tidak ada; CI terkunci billing), sehingga plugin Google Services 4.4.4 dengan AGP 9.1.0 belum terverifikasi; uji perangkat.

**Berikutnya:** simpan key sebagai secret `FIREBASE_SERVICE_ACCOUNT`; bereskan billing GitHub; review dan commit branch ini lalu PR ke `dev`; usulkan pembanding versi dataset ke LA.

---
## Target sementara demo APK

Rencana satu-satunya untuk vertical slice demo peta offline → lokasi nyata → trigger POI → kartu placeholder ada di [demo-apk-temporary-plan.md](demo-apk-temporary-plan.md). Rencana ini bukan pengganti PRD/PBI. Baca dan perbarui checklist di dokumen itu selama pengerjaan; jangan membuat dokumen sementara lain. Setelah kriteria demo tercapai atau target dibatalkan, hapus dokumen rencana dan pointer ini pada sesi yang sama, lalu verifikasi file sudah tidak ada.

## Sebelumnya — Pengujian Android Tahap 2/3, 15 November 2026

**Mandat:** lanjutkan implementasi/perbaikan, build/audit, emulator dan
pendampingan GPS fisik sampai kriteria demo terbukti. WIP existing tetap utuh;
tanpa reset, clean, commit, push, merge, rilis, perubahan kontrak atau threshold.

**Baseline ulang:** `dev`, HEAD dasar `089883c8d7d589eeb3fbabdc51b79808d86deccd`
+ WIP. APK existing versi `1.0.0+1`, 171.972.503 byte, SHA-256
`e54997a3bd133d933fbbfb968e2a8e7e4696e1107f1563552391099bc305ffce` cocok;
137 file snapshot source sebelum build identik. Audit `--apk`, metadata/izin
dan signature v2 diulang lulus. Belum build baru atau perubahan source.

**Runtime disiapkan:** emulator 37.2.13, Google APIs Android 16/API 36 x86_64
revision 7 dipasang di SDK existing. WHPX usable. AVD baru `agam_demo_api36`
di `D:\CodexRuntime\agam-android\avd\agam_demo_api36.avd`, headless software
renderer, RAM 2 GB, 2 core; tidak mengubah BIOS/Gradle atau menghapus data.
Serial yang dialokasikan `emulator-5554`; gunakan sebagai **simulasi** saja.
Log emulator dan helper ADB khusus emulator berada di direktori toolchain luar
repo. Jangan screenshot atau merekam koordinat/lintasan HP fisik.

**Pendampingan:** ADB awal kosong. Pengguna sudah menerima langkah USB debugging
dan menjawab HP akan dihubungkan serta izin diberikan. Koneksi/model/Android
dan akses area uji Labtek V belum terbukti. Tindak lanjut: selesaikan boot dan
skenario APK emulator, periksa daftar ADB lagi, install tanpa uninstall/hapus
data, lalu dampingi skenario fisik bertahap dan evaluasi evidence. Hasil runtime
harus ditambahkan ke evidence terbaru rencana demo dan status PBI; belum boleh
menandai Tahap 2/3 atau §5 selesai. Rencana/pointer tetap dipertahankan.

## Sebelumnya — APK demo berhasil dibangun dan diaudit, 15 November 2026

**Hasil permintaan lanjutan:** pengguna meminta APK dan audit APK diselesaikan
dalam progres ini. Android SDK dipasang di luar repo, build demo **berhasil**,
dan `python -X utf8 tools/tiles/audit_assets.py --apk build/app/outputs/flutter-apk/app-debug.apk`
**exit 0**. PMTiles/style/manifest di ZIP identik dengan source.

**APK:** `build/app/outputs/flutter-apk/app-debug.apk` (root repo),
**171.972.503 byte / 164,01 MiB**, SHA-256
`e54997a3bd133d933fbbfb968e2a8e7e4696e1107f1563552391099bc305ffce`.
`site.agam` versi `1.0.0+1`, minSdk 24, compile/targetSdk 36, ABI arm64-v8a /
armeabi-v7a / x86_64. Debug signature v2 valid (`apksigner verify` exit 0).
Manifest APK tidak memuat `ACCESS_BACKGROUND_LOCATION`; `INTERNET` debug dan
`ACCESS_NETWORK_STATE` ada. Belum merupakan audit lalu lintas/penyimpanan runtime.

**Source:** tetap `dev`, HEAD dasar
`089883c8d7d589eeb3fbabdc51b79808d86deccd` **+ perubahan lokal tracked/untracked**.
Jangan menyebut HEAD sebagai commit APK. Snapshot sebelum/sesudah build memastikan
137 file source di luar `.agent/` identik byte per byte. Tidak mengubah source,
aset, dependency, flag login, threshold, atau konfigurasi tracked Android; tidak
melakukan reset, clean, commit, push, merge atau rilis.

**Toolchain/reproduksi:** Flutter 3.47.9 / Dart 3.13.7 pada path absolut existing
(FVM tidak di PATH), JDK existing `C:\Program Files\Java\jdk-21.0.12`, Android SDK
`D:\CodexRuntime\agam-android\sdk`, Gradle 9.3.1. SDK Manager memasang Platform
36, build-tools 36.0.0, platform-tools, NDK 28.2.13676358, CMake 3.22.1; Gradle
otomatis memasang Platform 35 revision 2 untuk dependency. Android toolchain
`flutter doctor -v` kini lulus dan lisensi diterima. Command-line tools resmi
22.0 dan unduhan Gradle diverifikasi checksum; provenance/detail di progress
log rencana. Wrapper diabaikan Git yang belum ada disalin dari cache Flutter;
`android/local.properties` kini memiliki `sdk.dir`. Konfigurasi global/PATH tetap.

**Workaround lokal:** build pertama setelah SDK tersedia gagal pada cache
incremental Kotlin (`audio_session`/`flutter_tts`) karena root pub cache C:
berbeda dengan proyek D:. `D:\CodexRuntime\agam-android\gradle\gradle.properties`
berisi `kotlin.incremental=false`; build ulang sukses (`assembleDebug` 284,4 detik).
Untuk mengulang, set `ANDROID_HOME`/`ANDROID_SDK_ROOT` ke SDK di atas,
`JAVA_HOME` ke JDK di atas dan **`GRADLE_USER_HOME=D:\CodexRuntime\agam-android\gradle`**,
lalu jalankan Flutter SDK absolut dengan
`build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true`. Recipe PowerShell
lengkap ada pada rencana demo. Log di direktori toolchain luar repo:
`demo-build.log` (gagal), `demo-build-retry.log` (berhasil).
Peringatan kompatibilitas KGP `flutter_tts` untuk Flutter masa depan masih ada.

**Verifikasi/status:** build, audit tiga aset APK, metadata/izin/tanda tangan dan
snapshot source lulus. Source sama dengan evidence 233 test Flutter, 21 test
pipeline, format/analyze lulus sebelumnya; tidak diulang tanpa perubahan source.
Diff/check tautan dokumentasi diperiksa akhir sesi. Rencana/checklist,
implementation phases, header status PRD dan handoff diperbarui; penggunaan AI
untuk setup/build/audit dicakup PB20.

**Emulator/perangkat/berikutnya:** `flutter emulators` tetap tidak menemukan
sumber emulator, `adb devices -l` sekarang dapat dijalankan dan daftar kosong.
Belum install/launch APK atau uji GPS fisik. Install APK ini pada perangkat
Android, uji offline/pan/zoom/P01, izin/GPS/lifecycle, Explore→dwell→trigger→kartu,
akhir service, notifikasi/layar mati dan privasi runtime di Labtek V.
Tahap 2/3 dan PB02/PB04/PB05/PB06/PB07 tetap `in_progress`; PB21/PB22 `planned`.
Target build/audit permintaan lanjutan selesai; target demo keseluruhan belum,
sehingga rencana/pointer tetap dipertahankan.

## Sebelumnya — Verifikasi ulang demo APK Labtek V, 15 November 2026

**Scope:** melanjutkan Tahap 2/3 memakai APK internal jika mesin mendukung.
Seluruh perubahan lokal dipertahankan; tidak ada reset, clean, commit, push,
merge, rilis atau perubahan source/kontrak/threshold. Sesi ini memperbarui
`demo-apk-temporary-plan.md`, `implementationPhases.md`, dan handoff ini saja.
Rencana demo dan pointer tetap ada karena target belum tercapai.

**Checkout/source:** `dev`, HEAD dasar
`089883c8d7d589eeb3fbabdc51b79808d86deccd`, pubspec `1.0.0+1`, dengan WIP
tracked/untracked. Ini bukan commit APK. FVM tidak tersedia di PATH;
`C:\Users\ASUS\.cache\tooling\flutter-3.47.9\bin\flutter.bat --version`
membuktikan Flutter 3.47.9 / Dart 3.13.7 (framework `c197ca5199`). Perintah
Flutter sesi ini memakai path absolut tersebut, tanpa mengubah PATH global.

**Build:** pemeriksaan baru `doctor -v` tetap memberi `Unable to locate Android
SDK`. Environment Android tidak disetel, tidak ada `sdk.dir` lokal atau
konfigurasi SDK Flutter; lokasi standar dan beberapa lokasi tooling tambahan
tidak menemukan SDK/adb/emulator. Build ulang
`flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` exit 1 sebelum
Gradle: `No Android SDK found`. Target
`build/app/outputs/flutter-apk/app-debug.apk` tidak ada; ukuran/hash APK tidak
tersedia dan audit ZIP `--apk` tidak dijalankan. SDK tidak dipasang sesi ini.

**Emulator/perangkat:** `flutter devices` hanya Windows/Chrome/Edge;
`flutter emulators` tidak menemukan sumber emulator. Tidak ditemukan proses
adb/emulator atau entri PnP Android/ADB/MTP/USB Android yang cocok; nama ponsel
Bluetooth bukan koneksi debugging. `adb devices -l` tidak dijalankan karena adb
belum tersedia. Belum ada perangkat Android yang terdeteksi siap diuji; tidak
mengklaim tidak ada ponsel milik pengguna. Install/start, pan/zoom, marker P01,
izin/GPS Android, Explore, trigger→kartu, notifikasi/layar mati dan field test
Labtek V **belum dijalankan**. Tahap 2/3 belum selesai.

**Pemeriksaan aktual:** test terarah awal gagal kompilasi karena cache package
peta hilang. `flutter pub get --enforce-lockfile` memulihkan dependency tanpa
mengubah versi/lockfile. Setelah itu format 74 file tanpa perubahan, analyze
tanpa issue, **233 test Flutter lulus** (log cache lokal
`tools/tiles/.cache/demo-flutter-tests-2026-11-15.log`), **21 test pipeline lulus**,
dan audit aset sumber lulus (`apkChecked: null`). PMTiles tetap 1.022.885 byte,
SHA-256 `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`;
ini bukan hash APK. Simulasi widget tidak membuktikan GPS fisik.
Diff akhir ditinjau dan `git diff --check` lulus; tautan lokal rencana/status
tetap valid. Penggunaan AI untuk pemeriksaan dan dokumentasi ini dicakup PB20.

**Privasi/keputusan:** inspeksi source jalur posisi/sesi/peta tidak menemukan
pengiriman atau riwayat posisi; cache dataset berisi konten POI dan remote
default belum tersedia. Audit lalu lintas dan penyimpanan Android belum bisa
dijalankan. Build biasa tetap tertahan gerbang login sebelum layanan
diinisialisasi; flag demo eksplisit tetap wajib. Radius/akurasi/dwell/cooldown
dan coverage engineering berlabel tidak berubah. PB02/PB04/PB05/PB06/PB07 tetap
`in_progress`; PB21/PB22 tetap `planned`.

**Berikutnya:** sediakan lokasi SDK valid atau pasang Android SDK beserta
toolchain yang dibutuhkan, lalu jalankan build demo dan audit `--apk`, catat
ukuran/hash/versi/HEAD dasar + WIP. Gunakan emulator untuk simulasi awal, kemudian
perangkat fisik di Labtek V untuk akurasi/dwell/trigger/kartu, akhir service,
izin/lifecycle, notifikasi/layar mati, offline dan audit jaringan/penyimpanan.
Daftar perangkat/lokasi uji perlu tim; jangan menaikkan status sebelum evidence.

## Sebelumnya — Integrasi demo internal Labtek V, 14 November 2026

**Instruksi/keputusan:** pengguna memilih Labtek V (P01), mengizinkan skip login sementara, meminta kebutuhan lain disesuaikan dan memprioritaskan integrasi FE/logic untuk alur demo. Login dilewati hanya dengan `--dart-define=AGAM_INTERNAL_DEMO=true` dan label internal di UI; default false menampilkan gerbang login belum tersedia. Batas demo memakai coverage engineering OSM bersumber PRD §9.3 dalam mandat penyesuaian ini; bukan penetapan batas layanan produk atau geometri survei. Radius/dwell/akurasi/cooldown tidak berubah. PRD §4/§9.3/§14/§22/§23 dan status PBI diperbarui.

**Checkout:** root tetap `dev` `089883c` + working tree, tanpa commit/push, merge Git, PR, rilis, atau perubahan `lib/contracts/`. Instruksi integrasi diterapkan secara lokal lintas folder FE/LA/LB. WIP konfigurasi/style/test/audit dari sibling `../AGAM-LB-PB04` disalin ke root sebagai dasar dan disesuaikan di root; worktree asal `LB` `d602fed` tidak diubah. Integrasi branch formal dan review tim tetap tertunda; tidak menyamakan working tree ini dengan commit yang telah dipublikasikan.

**Ada di source dan teruji lokal:**

- Pipeline `tools/tiles/cluster_pmtiles.py` + hook `tile_pipeline.py` menyusun payload menurut tile ID, memvalidasi input/output, dan mencatat postprocess. Aset/manifest baru 1.022.885 byte, SHA-256 `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`. Seluruh 13 payload terdekompresi/metadata identik dengan arsip awal; transformasi ulang byte-identik. Full Planetiler tidak diulang.
- `lib/logic/map/agam_map_config.dart` (area pending produk + area internal engineering, pusat P01), `offline_map_tiles.dart`, `assets/map/agam-style.json`, dan `lib/ui/widgets/offline_campus_map.dart`: PMTiles aset → rasterisasi vektor seluruh 13 tile → PNG memori, marker repository, posisi perangkat, pan/zoom/overzoom, Pusatkan, atribusi dua sumber. Tidak memakai provider jaringan atau cache filesystem. Kombinasi probe `vector_map_tiles` ditinggalkan karena source layer bawaan tetap menulis cache disk saat TTL nol.
- `lib/main.dart`, `lib/ui/app.dart`, `explore_map_screen.dart`, `poi_detail_screen.dart`: layanan LA asli + repository yang sama untuk peta/trigger/detail, Mulai/Akhiri Explore, penanganan GPS/izin/lifecycle, dan kanal `TriggerResponder.viewRequests` sampai UI04 tanpa perubahan kontrak. Demo hanya menampilkan Explore; navigasi detail dan tab fitur lain yang masih fake tidak dibuka. Layanan LB fake di luar scope masih ada di composition root, tidak diklaim selesai.
- `pubspec.yaml`/lock: aset peta terdaftar, `flutter_map 7.0.2`, `vector_tile_renderer 5.2.0`, `pmtiles 1.3.0`, `latlong2 0.9.1`, `url_launcher ^6.3.2` (lock 6.3.3, tautan atribusi statis). `tools/tiles/README.md` memuat cara build/audit; `.github/workflows/ci.yml` menambah test pipeline dan artifact demo berflag + audit setelah artifact debug biasa. Workflow belum dijalankan di GitHub.
- Test baru/diadopsi: `test/logic/map/`, `test/ui/demo_explore_test.dart`, `tools/tiles/test_cluster_pmtiles.py`; audit aset `tools/tiles/audit_assets.py`. Snapshot widget di `tools/tiles/.cache/demo-labtek-v-widget.png` diperiksa visual; ini simulasi, bukan screenshot Android/perangkat.

**Verifikasi akhir (Flutter 3.47.9 / Dart 3.13.7):** format 74 file tanpa perubahan, analyze tanpa issue, **233 test Flutter lulus**, **21 test pipeline lulus**, audit aset sumber dan CLI `pmtiles verify` lulus. Uji widget membuktikan pan, overzoom 19, posisi dari stream, penolakan akurasi 30 m, dwell, trigger P01→UI04 P01, kanal view P02→P02, akhir service sesi, GPS mati, dan nol langganan setelah layar dilepas. Unit render membaca/rasterisasi seluruh tile dengan HTTP ditolak. Catatan awal kegagalan uji dan penjadwalan tester ada di progress rencana; tidak mengurangi threshold atau mengubah engine agar lulus.

**Build dan batas evidence:** `flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` dicoba, gagal sebelum Gradle: **No Android SDK found**. `flutter doctor -v` tidak menemukan Android toolchain/perangkat Android. Tidak ada APK baru, ukuran/hash APK, audit ZIP APK, emulator, install perangkat, GPS nyata, pengujian jaringan Android atau field test. Inspeksi source jalur peta tidak menemukan pengiriman/penyimpanan koordinat atau cache viewport; itu belum menggantikan audit runtime Android. Notifikasi native, kembali dari background dan cold start tetap perlu perangkat.

**Berikutnya:** pasang/konfigurasikan Android SDK lalu build flag demo dan jalankan audit `--apk`, atau verifikasi CI setelah pengguna mengotorisasi publikasi secara terpisah. Tetapkan perangkat, install APK internal, uji mode pesawat dan berjalan dekat Labtek V sesuai radius/dwell/akurasi/cooldown PRD, notifikasi layar mati dan akhir sesi. PB02/PB04/PB05/PB06/PB07 tetap `in_progress`, PB21/PB22 tetap `planned`. Target demo belum tercapai, rencana dan pointer dipertahankan. Penggunaan AI untuk implementasi/probe/test ini dicakup tim pada PB20.

## Sebelumnya — Awal rencana demo APK, 14 November 2026

**Scope sesi:** memulai rencana sementara secara bertahap. Tahap 0 menunggu keputusan PM (POI pertama, geometri/sumber/persetujuan area layanan, jalur login, perangkat/lokasi uji); permintaan keputusan telah diajukan, belum ada jawaban yang dicatat. Tidak mengaktifkan trigger dengan batas palsu atau melewati login. Checkout root tetap `dev` `089883c`; WIP sibling `../AGAM-LB-PB04` pada `LB` `d602fed` hanya dibaca, tidak ditimpa atau diintegrasikan.

**Hasil bagian Tahap 1:** dipilih kombinasi stabil `flutter_map 7.0.2`, `vector_map_tiles 8.0.0`, `vector_map_tiles_pmtiles` tepat `1.5.0`, `vector_tile_renderer 5.2.0` (`pmtiles 1.3.0` transitif), berdasarkan metadata/source package dan probe dengan Flutter 3.47.9 / Dart 3.13.7 di luar repo. Arsip produksi **unclustered** ditolak provider; uji awal 1 lulus/1 gagal. Salinan arsip dikonversi dengan CLI existing `pmtiles cluster`; dua test probe kemudian lulus (parse style, baca/decode tile lokal pada zoom 12–16 dengan HTTP ditolak). Seluruh 13 payload dan metadata identik sebelum/sesudah konversi. Ini belum menjadi renderer aplikasi dan belum bukti tampilan Android.

**Verifikasi:** 18 test pipeline root lulus; audit aset WIP LB tanpa APK lulus; CLI verify salinan clustered lulus. Patch aset WIP terbukti gagal `git apply --check` terhadap pubspec root. Rincian versi, command, path probe, hash, hasil gagal/lulus, dan keterbatasan hanya di progress log [rencana demo](demo-apk-temporary-plan.md#6-progress-log). Analyze/test aplikasi utama, APK build, emulator, perangkat fisik, dan field test tidak dijalankan. PB04 tetap `in_progress`; tidak ada commit, push, merge, atau rilis.

**File repo yang diperbarui:** checklist/progress rencana demo, catatan PB04 di `implementationPhases.md`, dan handoff ini. Perubahan awal pengguna pada pointer rencana dipertahankan. Tidak mengubah source, aset, dependency, atau WIP track lain. Penggunaan AI untuk pemilihan dependency/probe ini perlu dicakup PB20.

**Berikutnya:** lanjutkan track LB dengan clustering reproducible dalam pipeline (bukan mengedit flag header), perbarui manifest bersama output tervalidasi, verifikasi kesetaraan payload dan rerun deterministik. Setelah itu integrasi renderer/aset bersama FE/LA dan review sesuai ownership. Tunggu keputusan Tahap 0 untuk bagian yang bergantung pada area layanan/login/perangkat. Target demo belum selesai; rencana dan pointer tetap ada.

## Sebelumnya — Integrasi LA, LB, dan FE, 14 November 2026

**Tujuan:** menyatukan ketiga track pada branch `chore/integration-fe-la-lb` (dibuat dari `dev` `a1775f7`) atas instruksi PM, lalu menyambungkan layanan asli LA ke UI FE (Fase 4). Branch track `LA`, `LB`, dan `FE` tidak diubah. Belum ada PR ke `dev`; tidak ada merge ke `main`.

**Commit:**

| Commit | Isi |
| --- | --- |
| `2ce8275` | Merge `origin/LA` (`8e239b0`, konten Labtek V); tanpa konflik |
| `86480da` | Merge `origin/LB` (`ed2e7c0`, pipeline tile PB04-LB-01); konflik `.gitignore` digabung, PRD §22 mempertahankan isi kedua sisi, dokumen status disesuaikan |
| `85c4766` | Merge `origin/FE` (`5db4dd4`, layar UI01–UI08); manifest memakai versi `dev` (izin FE sudah tercakup), `pubspec.yaml` ditambah font Plus Jakarta Sans dan `assets/media/logo.png`, `pubspec.lock` tidak berubah setelah `pub get`. Status PB09 FE salin-tempel dari PB10 tidak dipakai. Pada commit ini `test/ui/app_test.dart` gagal (masih mencari teks "AGAM"); diperbaiki di commit berikutnya |
| `ef997a5` | Fase 4: `lib/main.dart` memanggil `createLaServices` dan menyerahkan `AppServices` ke `AgamApp`; parameter `navigation` di `lib/logic/la_bootstrap.dart` menjadi factory yang menerima `LocationService` asli; test aplikasi memakai `AppServices.fake` |

**Komposisi layanan saat ini:** LA asli (izin, lokasi, `PoiRepository`, sesi, audio, suara, pengaturan, notifikasi trigger, pengumuman navigasi). LB masih fake (`FakeMapConfig` dengan area sintetis, routing garis lurus, `FakeNavigationController` yang membaca posisi asli, pencarian, trail, fasilitas, rekomendasi). Peta UI02 masih ilustrasi skematis; PMTiles belum dirender maupun didaftarkan sebagai aset.

**Pemeriksaan (lokal, Flutter 3.47.9 via FVM):** `dart format` 0 perubahan; `flutter analyze` tanpa issue; `flutter test` 225 lulus. Test pipeline tile 18 lulus dengan Python 3.13 (`/opt/homebrew/bin/python3.13`); `python3` bawaan macOS 3.9 gagal 8 test karena tidak punya `hashlib.file_digest`, bukan kesalahan kode. **`flutter build apk --debug` tidak dapat dijalankan** karena Android SDK tidak terpasang di mesin ini; build Android akan diverifikasi CI saat PR ke `dev`. Belum diuji di perangkat fisik.

**Catatan untuk track:**

- FE: `lib/ui/device_app_services.dart` dan `lib/ui/device_location_services.dart` kini hanya fallback bila `AgamApp` dibuat tanpa `services`; nama kelasnya menduplikasi `DevicePermissionService`/`DeviceLocationService` milik LA. Perlu dibersihkan FE.
- FE/LA: `TriggerResponder.viewRequests` (tombol Lihat di notifikasi) belum punya jalur ke navigator FE; UI02 baru mendengarkan `session.triggers`. Butuh usulan kontrak §2.4 atau penyambungan di `main.dart`.
- LB: style AGAM, `MapConfig` asli, `SearchService`, `RoutingService`/`NavigationController`, `TrailService`, dan `FacilityService` asli masih belum ada; begitu tersedia, ganti fake di `lib/main.dart`.

**Berikutnya:** PR `chore/integration-fe-la-lb` → `dev` (menunggu instruksi PM) dan pastikan CI build APK lulus; setelah merge, sinkronkan `LA`, `LB`, `FE` dari `dev` dengan merge; uji APK di perangkat fisik; PM membuat project Firebase (Firestore + Authentication Email/Password); kontrak v1.1 dan PB21–PB22.

---

## Sebelumnya — Keputusan akun, login, dan log aktivitas, 14 November 2026

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

## Sebelumnya — Bagian LB PB04-LB-01 pipeline tile, 4 November 2026

**Otorisasi dan publikasi:** rencana pengguna diimplementasikan berurutan. Migrasi folder brief di-commit sebagai `accddc1` (`docs: relocate implementation briefs to root directory`) dan di-push atomik melalui `git push --atomic -u origin main dev LA LB FE`. Hasil `git ls-remote --heads origin` memastikan kelima branch menunjuk `accddc1090d38338a558e396d8ecb19e88aa003f`; tree `task-implementation` semuanya `20b312a28580ab0178c166165d2cc13c8b0f9da1`. `LB`/`FE` dibuat dari `dev` yang telah diselaraskan. Branch historis PB03 lokal/remote tetap `b1b165b`. Checkout akhir pekerjaan ini adalah `LB`; implementasi di bawah **lokal, belum di-commit/push**. Tanpa PR, merge fitur, atau rilis.

**Perubahan LB:** [brief PB04-LB-01](../task-implementation/backend/PB04-LB-01-tile-pipeline.md), entry PowerShell/Python, validator seluruh directory/payload MVT, test offline, snapshot/provenance batas, dan [panduan](../tools/tiles/README.md). Cache unduhan/scratch/log di `tools/tiles/.cache/` diabaikan Git. Tidak mengubah kontrak, UI, Android, `pubspec.yaml`, atau dependency Flutter. PRD §9.3 mencatat coverage tile; PB04 `in_progress`, bukan acceptance peta Android.

**Batas terverifikasi:** snapshot API `way/177629384` versi 19, timestamp objek `2026-07-24T05:11:05Z`, diambil 4 November 2026; checksum `253567b5d47f8f5cebc492cbec0d4760fcaffd2f6e3ab5cb195701a6070c0b2b`. Seluruh 10 POI existing berada dalam poligon sumber. Envelope + 200 m menghasilkan west/south/east/north `107.60635935,-6.89545535,107.61454265,-6.88552795`. Ini coverage engineering OSM, bukan survei batas resmi atau implementasi `MapConfig`.

**Tooling/sumber nyata:** Python 3.13.14 lokal, Windows PowerShell 5.1.26100.9818, Java 21.0.12, Planetiler v0.10.2 (JAR 93.278.824 bytes; SHA-256 resmi `f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d`). Extract Jawa Geofabrik 899.224.839 bytes, checksum `091e9183554ac4a91b399726dd85e6d1050ea4fe4b1f0b772962c3764a195d3c`. Tidak mengubah Java/PATH sistem atau menambahkan package Python. Verifier independen `pmtiles` v1.31.2 di cache, binary dari release resmi (ZIP dicek terhadap digest GitHub).

**Kegagalan dan pemulihan:** percobaan unduhan byte-range PBF gagal HTTP 502, kemudian strategi streaming berhasil. Build pertama gagal saat Planetiler mendapat timeout dari `osmdata.openstreetmap.de` untuk poligon laut. Natural Earth dan lake centerline berhasil di-cache. Mirror FAU bertanggal 31 Oktober 2026 dirujuk issue upstream #1642; akses Python ke mirror menolak chain sertifikat, sehingga pengambilan memakai `curl.exe` Schannel dengan validasi TLS normal (tanpa `--insecure`). Opsi `-WaterPolygonsUrl` mencatat URL konfigurasi mirror. Masalah default path wrapper Windows PowerShell 5.1 ditemukan lewat smoke test lalu diperbaiki dan diuji ulang.

**Hasil task:** PB04-LB-01 **selesai secara teknis dan terverifikasi lokal**. `assets/map/ganesha.pmtiles` berukuran **1.035.927 bytes** (sekitar 1,04 MB), SHA-256 `8501f70bcc5d8b2624a4eaa12074006b99a4631d9deba21a5b91496087e844f3`. Dua build nyata menghasilkan arsip **identik byte demi byte**, 13 tile (zoom 12–16), layer `building` dan `transportation` bergeometri. Hitungan feature agregat pada tile unik: 99 building dan 5.703 transportation; ini **bukan** jumlah bangunan/jalan unik di kampus. Manifest mencatat sumber/checksum, ZIP pendukung, bounds, generator, statistik, dan HTML atribusi OpenMapTiles/OSM. Ukuran ini ukuran arsip, bukan ukuran akhir APK.

| Command/check aktual | Hasil | Batas evidence |
| --- | --- | --- |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -v` | 18 test lulus; pemeriksaan terakhir setelah penyelarasan validator/atribusi juga 18 lulus | Offline/sintetis, kecuali regression snapshot coverage 10 POI existing |
| `./tools/tiles/build-tiles.ps1 -BoundsOnly` dan pemanggilan melalui `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ... -BoundsOnly` | Lulus setelah perbaikan default path | Tidak membuat/mengunduh aset |
| Build pertama: `./tools/tiles/build-tiles.ps1 -WaterPolygonsUrl <mirror>` | Lulus pada data nyata; validasi seluruh directory/payload MVT sebelum publikasi | PBF default Geofabrik; sumber pendukung sudah di-cache saat pemulihan |
| Build kedua: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/tiles/build-tiles.ps1 -OsmPbf tools/tiles/.cache/java-latest.osm.pbf -OsmSha256 <sha-pbf> -SourceUrl <geofabrik> -WaterPolygonsUrl <mirror> -Force` | Lulus; hash, ukuran, bounds, dan jumlah feature sama dengan build pertama | Membuktikan rerun dengan input/cache identik, bukan URL `latest` di masa mendatang |
| `tools/tiles/.cache/pmtiles.exe verify assets/map/ganesha.pmtiles` | Lulus untuk kedua build | Verifier independen resmi v1.31.2; bukan render visual |
| `pmtiles.exe show ... --header-json` dan `--metadata` | MVT, gzip, zoom 12–16, bounds sesuai; kredit OSM/OpenMapTiles tersedia | Presisi bounds PMTiles tersimpan 7 desimal sesuai format |
| Pemanggilan wrapper tanpa `-Force` setelah output ada | Ditolak seperti diharapkan; SHA tile dan manifest tidak berubah | Dijalankan melalui Windows PowerShell 5.1; failure yang disengaja |
| Pemeriksaan file/anchor Markdown, `git diff --check`, cache/staging ignore, cleanup staging/backup | Lulus | Tidak ada staging atau `.bak` tertinggal setelah rerun |

Dalam tabel: `<mirror>` = `https://ftp.fau.de/mirrors/openstreetmapdata.com-archive/2026-10-31/water-polygons-split-3857.zip`; `<geofabrik>` = `https://download.geofabrik.de/asia/indonesia/java-latest.osm.pbf`; `<sha-pbf>` adalah checksum PBF pada paragraf tooling di atas. Command dijalankan dari root repository yang path-nya mengandung spasi. Manifest/log build pertama dan pemeriksaan no-force disimpan lokal pada `.cache/`; log terbaru `last-build.log` akan ditimpa oleh build berikutnya.

**Peringatan generator yang teramati:** poligon US/IE/GB tidak tersedia untuk inferensi atribut regional; relasi OSM `304751` tidak dapat membentuk poligon tertutup. Inspeksi API OSM mengidentifikasi relasi tersebut sebagai batas administratif Indonesia (level 2), bukan way batas kampus `177629384`. Arsip lulus verifikasi struktur, bounds, dan layer; kualitas tampilan akhir dan kelengkapan data OSM tetap memerlukan inspeksi renderer/perangkat. Tidak mengklaim bahwa seluruh geometri sumber sudah lulus survei.

**Langkah berikutnya:** review perubahan lokal LB; lanjutkan task style AGAM dan `MapConfig`, kemudian integrasi renderer/pendaftaran aset melalui review LA/FE sesuai ownership. Jangan meng-commit/push implementasi ini tanpa instruksi baru.

**Sisa PB04:** style AGAM, `MapConfig`/batas layanan asli, pendaftaran aset APK dan renderer bersama FE, UI02, uji offline/emulator/perangkat/field test. Flutter analyze/test/build tidak dijalankan karena perubahan task berupa tooling dan data peta; bukan perubahan Dart atau bukti acceptance Android.

**AI & Tools Disclosure (PB20):** agent membantu migrasi dokumentasi, menulis pipeline/validator/test/brief, memeriksa sumber publik, dan menjalankan verifikasi. Tim tetap perlu review serta memahami kode dan mendemonstrasikan integrasi perangkat.

---

## Sebelumnya — Bagian FE, Preview UI Profil pada tab Pengaturan, 10 November 2026

**Perubahan FE:** tab Pengaturan menampilkan preview statis Profil Pengguna dengan detail akun sesuai referensi. Header menampilkan logo saja; navbar utama tetap berada di shell dan menandai Pengaturan aktif. Tombol Logout hanya menampilkan snackbar preview dan tidak mengubah status akun/sesi. Foto profil memakai ikon placeholder karena aset portrait tidak tersedia terpisah.

**Batas kontrak:** tidak ada autentikasi, akun, role, penyimpanan profil, atau logout sungguhan yang ditambahkan. Konten preview diambil dari gambar yang diberikan pengguna. PRD tanpa login tetap berlaku; PB16 fasilitas/pengaturan belum selesai.

**Pemeriksaan aktual:** `dart format` dan `flutter analyze` untuk `app.dart`, `agam_bottom_navigation.dart`, dan `profile_preview_screen.dart` lulus (No issues found); `git diff --check` lulus; APK debug dibangun dan dipasang ke `emulator-5554`; halaman preview dibuka melalui tab Pengaturan. Automated test, perangkat fisik, dan field test tidak dijalankan.

**Berikutnya:** jika dibutuhkan, ganti ikon placeholder dengan aset foto berizin; integrasi fitur UI09/PB16 tetap mengikuti kontrak produk.

---

## Sebelumnya — Bagian FE, UI05 Cari & Rute dan pratinjau UI06, 9 November 2026

**Perubahan FE:** tab `Cari & Rute` kini membuka halaman UI05 dalam shell utama; header logo dan navbar tetap tersedia. Halaman menyediakan pencarian dari `SearchService`, filter kategori, daftar gedung yang berasal dari repository, pemilihan tujuan, dan panel pratinjau UI06. Tombol mulai navigasi memulai sesi foreground, menunggu pembacaan lokasi bila belum ada, lalu memanggil `NavigationController`.

**Batas dan anti-halusinasi:** map preview, rute, langkah, serta fasilitas di shell saat ini tetap bergantung pada service fake/sintetis. Titik masuk gedung belum disurvei; lokasi fasilitas dan konten yang belum disetujui tidak ditampilkan sebagai fakta. Seluruh tujuan tanpa pintu masuk diberi label placeholder. Voice guidance, graf jalan, rerouting, rekomendasi/riwayat, SearchService produksi, dan dataset fasilitas masih belum terintegrasi.

**Pemeriksaan aktual:** `dart format` tanpa perubahan; `flutter analyze lib/ui/app.dart lib/ui/search_route_screen.dart` **No issues found**; `git diff --check` lulus; APK debug dibangun dan dipasang ke `emulator-5554`. Setelah melewati UI01, tap pada tab Cari & Rute membuka UI05 dan navbar menandai tab aktif. Ini pemeriksaan manual emulator; perangkat fisik/field test dan automated test tidak dijalankan.

**Berikutnya:** integrasi LB untuk PB10/PB11 dan LA untuk sesi/voice tetap diperlukan; PB10/PB11 `in_progress`, bukan selesai.

---

## Sebelumnya — Bagian FE, UI04 Detail Lokasi dari Orientation Trail, 9 November 2026

**Perubahan FE:** pada UI08, kartu POI yang sudah tercatat check-in otomatis atau berstatus tiba menampilkan tombol `Check-in` dan `Details`. `Details` membuka UI04 melalui route halaman penuh. UI04 menyediakan AppBar kembali, hero foto (memakai aset POI yang disetujui bila tersedia; selain itu placeholder gambar), kartu narasi dengan playback melalui `AudioService` jika aset disetujui tersedia, transkrip, fungsi/deskripsi, fasilitas, trivia, sumber/atribusi, serta CTA navigasi dan status check-in. Tombol check-in hanya mengonfirmasi status otomatis kontrak Trail; tidak menambah check-in manual baru. Konten yang belum diverifikasi berlabel `PLACEHOLDER`.

**Batas:** foto, teks konten, fasilitas, trivia, atribusi, dan audio P01–P10 belum tersedia; seluruhnya tetap jelas sebagai placeholder. `AudioService`, TrailService, dan navigasi yang tersedia selain adapter lokasi masih fake, sehingga halaman ini belum menjadi UI04 acceptance final.

**Pemeriksaan aktual:** `fvm dart format` tanpa perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. APK dibangun/dipasang ke `emulator-5554`; dengan koordinat sintetis emulator pada P06, check-in otomatis tampil dan tombol Details membuka UI04. Ini hanya pemeriksaan emulator; test dan field test tidak dijalankan.

**Berikutnya:** tim konten memasok media/teks bersumber dan metadata; LA mengintegrasikan audio; LB/LA menyelesaikan check-in/navigation produksi. PB07 dan bagian FE PB08 tetap `in_progress`.

---

## Sebelumnya — Bagian FE, Izin dan lokasi perangkat nyata, serta header shell, 9 November 2026

**Perubahan FE:** tombol izin UI01 sekarang meminta izin lokasi Android foreground dengan `geolocator`; ketika diizinkan, UI02 membaca stream posisi perangkat dan menampilkan koordinat/akurasi pada peta/status. `DeviceLocationService` menghentikan stream saat tidak ada listener atau aplikasi masuk background, lalu memulai ulang saat foreground. Shell memakai `AgamAppHeader` sebagai `Scaffold.appBar`, sehingga logo tampil sejak pertama membuka Jelajah tanpa perlu berpindah ke Trail. Saat mulai Trail, fake session/navigation yang masih ada memakai `LocationService` yang sama; peta/routing/trail selain pembacaan posisi tetap implementasi contoh.

**Privasi dan batas integrasi:** manifest hanya meminta coarse/fine foreground; tidak meminta `ACCESS_BACKGROUND_LOCATION`, tidak menyimpan koordinat, dan tidak mengirimkannya. Implementasi sesi foreground/service, notifikasi, battery settings, serta acceptance perangkat fisik PB02/PB06/PB15 masih tertunda. File `pubspec.yaml` dan `android/app/src/main/AndroidManifest.xml` milik LA sesuai aturan track dan perlu review LA sebelum integrasi branch.

**Pemeriksaan aktual:** package `geolocator: ^14.1.2` dipasang; `fvm dart format --set-exit-if-changed` tanpa perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. APK berhasil dibangun/dipasang ke `emulator-5554`; dialog izin Android foreground tampil, setelah diberi izin status peta memperlihatkan pembacaan GPS (`±5m` pada emulator), dan halaman Trail dapat memulai sesi yang memakai stream lokasi. Ini bukti emulator, bukan perangkat fisik/field test. Test tidak dijalankan.

**Berikutnya:** LA review perubahan manifest/dependency dan pindahkan adapter ke implementasi logic milik LA; uji alur izin serta pembacaan lokasi di perangkat Android fisik. PBI tetap `in_progress`.

---

## Sebelumnya — Bagian FE, Shell tetap, logo, dan batas scroll UI Jelajah/Trail, 9 November 2026

**Perbaikan lanjutan:** UI02 dan UI08 sekarang berada dalam `AgamMainShell` dengan `IndexedStack`; header bersama (`AgamAppHeader`) dan satu `AgamBottomNavigation` berada di luar konten halaman. Berpindah tab mempertahankan widget/posisi scroll dan tidak menumpuk route. Logo header memakai `assets/media/logo.png`. Jelajah, Trail, filter Trail, dan isi kartu Jelajah mengatur `ClampingScrollPhysics` secara eksplisit; daftar Trail dan filter juga di-clip ke viewport. Status PBI tidak berubah.

**Pemeriksaan aktual:** `fvm flutter pub get` berhasil; format Dart tidak menemukan perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. `fvm flutter run -d emulator-5554 --no-resident` membangun dan memasang APK. Header logo dan perpindahan ke tab Trail diperiksa melalui emulator; navbar terlihat sama. Test tidak dijalankan dan drag overscroll manual belum diukur.

**Berikutnya:** periksa drag scroll di emulator setelah pengguna menjalankan build terbaru. Bagian UI FE tetap belum menutup acceptance/integrasi PBI terkait.

---

## Sebelumnya — Bagian FE, Penyelarasan UI Jelajah dan Trail, 9 November 2026

**Perubahan FE:** navigasi bawah UI02 Jelajah dan UI08 Trail kini memakai `AgamBottomNavigation` bersama dengan ukuran, ikon, label, warna, serta inset sistem yang seragam; halaman aktif ditandai. Seluruh aplikasi memakai font Plus Jakarta Sans dari aset lokal di `assets/fonts/`, dengan lisensi OFL disertakan. `AgamScrollBehavior` memakai clamping dan meniadakan overscroll indicator, termasuk pada daftar Trail, filter horizontal, dan isi kartu Jelajah. Tombol pada kartu UI04 menutup panel sehingga hanya peta tersisa; saat panel diperluas, tombol tetap dapat menciutkannya.

**Pemeriksaan aktual:** `fvm flutter pub get` berhasil; `fvm dart format` pada file UI/widgets yang diubah; `fvm flutter analyze` **No issues found**. Test tidak dijalankan. Tidak ada commit/push.

**Berikutnya:** jalankan ulang aplikasi/emulator untuk pemeriksaan visual perangkat; status PB02/PB04/PB06/PB07/PB15 tetap `in_progress` sesuai integrasi layanan dan acceptance yang belum selesai.

---

## Sebelumnya — Bagian FE, UI08 Orientation Trail, 8 November 2026

**Pemetaan kode UI:** layar utama adalah **UI08 Orientation Trail** (PRD §18 / PB15). Panel progres, filter daftar, urutan POI, lencana, dan CTA tetap dalam UI08. Mini peta adalah pratinjau komponen UI02; CTA menginisiasi rute UI06. Callout pada contoh pengguna bukan hasil rekomendasi UI07; implementasi UI07 tetap terpisah.

**Perubahan FE:** `lib/ui/orientation_trail_screen.dart` menambahkan layout panjang scrollable dengan header/progres 0/10, statistik, badge, notice urutan TBD, filter semua/belum dikunjungi/selesai, kartu seluruh POI, peta skematis, CTA tetap di bawah, dan navigation bar. `lib/ui/explore_map_screen.dart` membuka UI08 dari tab Trail. Aksi mulai menggunakan `TrailService`, `SessionController`, dan `NavigationController` dari AppServices fake.

**Batas data:** daftar POI memakai nama P01–P10 dari PRD; urutan diambil dari `FakeTrailService` dan diberi label sintetis. Deskripsi, rute/jarak, media, dan progres tersimpan belum tersedia; UI mempertahankan placeholder dan tidak mengarang fasilitas/deskripsi. Mini peta dilabel ilustrasi karena tile/graf rute LB belum tersedia.

**Status PBI:** PB15 `in_progress` pada bagian FE. Urutan final masih TBD; penyimpanan progres lokal, sesi Trail asli LA, check-in terintegrasi LB, lencana acceptance, dan field test belum selesai.

**Pemeriksaan aktual:** `fvm dart format lib/ui/explore_map_screen.dart lib/ui/orientation_trail_screen.dart`; `fvm flutter analyze` **No issues found**; `fvm flutter run -d emulator-5554 --no-resident` membangun/memasang APK. Membuka tab Trail dan scroll sampai peta bawah diperiksa pada emulator; tidak ada exception Flutter baru pada log. Test tidak dijalankan.

**Berikutnya:** tinjau visual dengan tim; ganti urutan sintetis saat PM/tim menetapkan urutan resmi; integrasikan layanan LB/LA persisten dan navigation state sesudah tersedia.

---

## Sebelumnya — Bagian FE, UI02 Explore Map dengan UI03/UI04, 8 November 2026

**Definisi layar:** contoh pengguna menunjukkan gabungan tiga layar/state yang sudah didefinisikan PRD §18: UI02 Explore Map sebagai layar induk, UI03 trigger POI yang muncul di atas peta, dan UI04 kartu detail POI sebagai panel bawah. Bukan kode UI baru di luar UI01–UI09.

**Implementasi FE:** `lib/ui/explore_map_screen.dart` memakai `AppServices` dan fake contracts. Peta ilustratif, status posisi, penanda POI, kontrol sesi, bottom navigation, trigger, dan panel detail dibuat. Data ilustrasi diberi label; fasilitas fake menyebut contoh; foto/narasi tetap placeholder karena aset/konten resmi belum tersedia. `lib/ui/app.dart` meneruskan dari UI01 ke UI02 setelah izin fake berhasil.

**Status PBI:** PB02, PB04, PB06, dan PB07 `in_progress` pada bagian FE. Implementasi asli LA/LB, tile peta/routing, konten dan media, serta uji penerimaan belum selesai. Tidak mengubah kontrak bersama atau source track LA/LB.

**Pemeriksaan aktual:** format Dart untuk `app.dart`, `onboarding_screen.dart`, dan `explore_map_screen.dart`; `fvm flutter analyze` **No issues found**; `fvm flutter run -d emulator-5554 --no-resident` membangun dan memasang APK debug, UI02 terbuka setelah alur izin, log setelah perbaikan navigasi/layout tidak menunjukkan exception baru. `git diff --check` diperiksa. Test tidak dijalankan.

**Catatan keterbatasan:** SDK dan Android komponen pertama kali diunduh pada mesin ini; build pertama lama. Peta yang ditampilkan adalah skematis, bukan data jalan kampus atau tile offline. Logo, foto, narasi, dan fasilitas final belum tersedia.

**Berikutnya:** bandingkan visual pada emulator; koordinasikan konten/logo dengan tim terkait; integrasikan `MapConfig`, sesi, dan trigger asli saat LA/LB menyerahkan implementasinya.

---

## Sebelumnya — Bagian FE, Implementasi awal UI01 oleh FE, 8 November 2026

**Tujuan:** mulai mengimplementasikan layar Onboarding & Izin sesuai referensi visual yang dilampirkan pengguna dan PB02.

**Branch/keadaan:** `FE`; working tree sebelumnya bersih. Tidak ada commit, push, merge, atau rilis.

**Perubahan:** `lib/ui/onboarding_screen.dart` menambahkan tampilan onboarding responsif dengan kartu manfaat, pemberitahuan penggunaan lokasi, tombol izin, serta penanganan izin lokasi ditolak/perkiraan/permanen/layanan mati dan izin notifikasi opsional. `lib/ui/app.dart` menghubungkan layar ke `PermissionService` dari `AppServices.fake()` (dapat diinjeksi lewat konstruktor untuk integrasi berikutnya). Logo masih berupa mark ikon sementara karena aset logo resmi belum tersedia. Saat dijalankan, ukuran layar awal emulator sempat menghasilkan tinggi minimum negatif; batas layout diperbaiki agar aman ketika tinggi constraint belum tersedia.

**Status saat pencatatan awal:** UI01 FE baru mulai; PB02 `in_progress`. Handoff Current paling atas mencatat kemajuan sesudahnya.

**Pemeriksaan pada sesi awal:** format file UI01 dan build UI01 di emulator berhasil setelah memperbaiki tinggi layout awal. Analyzer dijalankan pada sesi UI02 berikutnya. Flutter 3.47.9/Dart 3.13.7 dan FVM 4.3.2 dipasang di mesin; Android SDK otomatis memasang NDK 28.2.13676358, Build Tools 36.0.0, dan CMake 3.22.1 selama build.

**Langkah berikutnya saat itu:** jalankan analyzer; lanjutkan layout dengan aset logo resmi bila tim menyediakannya; koordinasikan layanan izin asli dengan LA. UI02 kini tersedia sebagaimana catatan Current.

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

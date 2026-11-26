# Session Handoff — AGAM

## Penyatuan build produk dan alur login/akun — 26 November 2026

- **Branch:** `dev` (basis `b6426d8`).
- **Keputusan pengguna (final):** build demo (`AGAM_INTERNAL_DEMO=true`) dihapus
  sehingga seluruh build kini adalah **build produk utuh** dengan Firebase
  Auth/Firestore, gerbang login wajib (UI10), dan seluruh layanan asli LA/LB.
- **Yang berubah:**
  1. **Build produk tunggal:** flag `AGAM_INTERNAL_DEMO`, `_createAppServices()`,
     `AgamMapConfig.internalDemo()`, chip `Mode uji`, sakelar UI `Mode demo/trial`,
     serta parameter `internalDemo` dihapus dari `lib/main.dart`, `lib/ui/app.dart`,
     `lib/ui/explore_map_screen.dart`, `lib/ui/orientation_trail_screen.dart`,
     `lib/ui/search_route_screen.dart`, `lib/ui/profile_preview_screen.dart`,
     `lib/ui/widgets/agam_bottom_navigation.dart`, dan `.github/workflows/ci.yml`
     (CI kini membangun satu `agam-debug-apk` produk dan langsung mengaudit
     asetnya).
  2. **Alur login, onboarding, dan keluar akun (`lib/ui/app.dart`):**
     - `AgamApp` selalu masuk melalui `SplashScreen` → gerbang `AuthState`
       (`AuthScreen` bila belum login, `_SignedInFlow` bila sudah login),
       dengan langganan tunggal ke `auth.state` (menghindari re-subscribe
       `Stream.multi` tiap rebuild).
     - `_SignedInFlow` mengecek `permissions.locationStatus()` saat init: bila
       izin lokasi akurat sudah `granted`, langsung masuk ke `AgamMainShell`
       tanpa mengulang 4 halaman Onboarding pada cold start berikutnya.
     - Saat `auth.state` berubah menjadi `signedOut` dari mana pun,
       `navigatorKey` menutup seluruh route yang sedang terbuka (`popUntil`
       ke route pertama) agar `AuthScreen` tidak tertutupi layar lama.
  3. **Profil & Pengaturan UI09 (`lib/ui/profile_preview_screen.dart`):**
     - Menjadi `StatefulWidget` yang reaktif terhadap `auth.state`, membaca
       status izin lokasi aktual (segar saat `resumed`) dengan akses ketuk ke
       pengaturan aplikasi, menampilkan label mode sesi aktif (`Explore`,
       `Navigasi`, `Orientation Trail`), serta menambahkan **Hapus progres
       lokal** (`trail.reset()` dengan dialog konfirmasi, sesuai PRD §16/§18).
  4. **Pencatatan kunjungan Explore & ketahanan startup:**
     - `lib/main.dart` kini mencatat trigger mode Explore ke `AccountVisitStore`
       per akun agar selaras dengan rekomendasi dan hapus progres/hapus akun.
     - `lib/ui/search_route_screen.dart` menyatukan kartu tujuan gedung
       (`Rute`, `Tampilkan di peta`, `Lihat Detail POI`, `Tutup pilihan`) dan
       memperbaiki `_stopRoute()` agar menutup pilihan saat tidak menavigasi
       tidak ikut mengakhiri sesi Explore aktif.
     - `lib/logic/account/device_auth_service.dart` menambahkan timeout 5 detik
       pada fallback `_tryReadRole` saat cold start agar tidak menggantung jika
       cache lokal hilang saat jaringan lambat.
  5. **Test & dokumentasi:** seluruh test lama diperbarui ke jalur produk dan
     3 test alur baru ditambahkan di `test/ui/auth_gate_test.dart` (auto-skip
     onboarding saat izin sudah granted, sign-out eksternal menutup layar
     terdorong, serta status GPS/mode sesi dan hapus progres lokal di UI09).
     `.agent/PRD.md`, `.agent/implementationPhases.md`, dan dokumen ini
     diperbarui.
- **Pemeriksaan:** `fvm dart format --output=none --set-exit-if-changed lib test`
  (150 file, 0 perubahan), `fvm flutter analyze --no-pub` bersih,
  `fvm flutter test --no-pub` **507 lulus** (baseline 504 + 3 test baru − 1 test
  demo map + 1 = 507; `auth_gate_test.dart` 4/4 lulus), `git diff --check`
  bersih. Build APK produk `fvm flutter build apk --debug --no-pub` berhasil
  (SHA-256 `32c7ad020f2e24091c5e967054ed372dce852d93146216f906a39cf03be5f3bb`)
  dan berjalan di emulator `emulator-5554` (Android 16 / API 36, `site.agam`,
  cold start `Status: ok` 2.776 ms, Firebase `[DEFAULT]` aktif, tampil UI10
  "Selamat datang" tanpa galat logcat, hash APK terpasang cocok). Uji alur akun
  end-to-end di perangkat fisik dengan Firebase `agam-9e704` serta test rules
  emulator Firestore **belum** dijalankan.
- **Terbuka:**
  - Uji alur daftar/login/cold-start offline/logout/hapus akun di perangkat
    Android fisik dengan project Firebase `agam-9e704` (PB21).
  - Test rules Firestore emulator (`tools/firestore/rules.test.mjs`).
  - Persetujuan PM atas teks pemberitahuan privasi `AuthScreen.consentText`
    (PRD §22).
  - Item terbuka gelombang 2 sebelumnya (verifikasi lapangan selasar/titik
    akses, tombol pusatkan kamera navigasi, splash logo, build release
    shrinker, dsb.).

## Gelombang 2: preview rute, navigasi satu layar, selasar OSM — 26 November 2026

- **Branch:** `feat/route-preview-wave2` dari `dev` @ `22f28ad` (branch fitur atas
  instruksi pengguna, seperti PR #14–#20). Belum di-commit. Paket A–D dikerjakan
  sub agent paralel di worktree `.claude/worktrees/wave2-{a,b,c,d}` (branch
  `wave2/*`, perubahan tidak di-commit), lalu diterapkan ke checkout utama
  sebagai patch; paket E (audit copy) setelahnya.
- **Keputusan pengguna (final):** rekomendasi "Lanjut ke mana?" hanya setelah
  tiba (PRD F07/§23); routing diperbaiki dalam paket ini; atribusi peta menciut
  otomatis (diverifikasi ke OSMF Attribution Guidelines, revisi 10 September
  2026, oldid=14786; PRD §14); semua tombol Rute membuka preview, navigasi
  mulai dengan Mulai rute di layar yang sama (PRD §23). Setelah uji emulator,
  pengguna menyetujui opsi 1+3: garis lurus luar jaringan digambar abu-abu dan
  selasar OSM `highway=corridor` dipakai sebagai lorong kandidat (PRD §11/§23).
- **Yang berubah:**
  1. Ikon: launcher legacy + adaptif (latar `#09469F`, diukur dari logo) dan
     ikon notifikasi `ic_stat_agam` untuk sesi lokasi, trigger, dan
     audio_service; `res/raw/keep.xml` menahan ikon dari shrinker.
  2. Rekomendasi tidak lagi muncul saat kartu POI ditutup (`explore_map_screen`).
  3. Preview rute + navigasi satu layar (`walking_navigation_screen.dart`):
     rute dihitung tanpa sesi, Mulai rute memulai sesi dan menjeda narasi;
     dipakai kartu POI, detail, rekomendasi, Cari (termasuk fasilitas), Trail.
  4. Atribusi `MapAttribution` pindah ke `lib/ui/widgets/map_attribution.dart`,
     menciut jadi ⓘ (48 px) setelah 5 detik/sentuhan pertama.
  5. Routing: `lib/logic/routing/route_planner.dart` (`planWalkingRoute`) dipakai
     preview dan controller; pintu gedung tempat pengguna berada ikut dicoba;
     garis luar jaringan berbobot 2× (`kOffNetworkWeight`, nilai engineering);
     selasar OSM dari `tools/routing/export_osm_corridors.py` →
     `assets/routing/corridors.geojson` (didaftarkan di `pubspec.yaml`, dimuat
     di `main.dart`). Labtek V tengah → Labtek VII: 253 m → 161,6 m lewat
     selasar utara/timur (oracle `tools/routing/check_corridor_route.py`).
  6. Transisi: `AgamMotion.route` berlatar kanvas (tanpa fade ke hitam),
     `AgamMotion.mapRoute` 280/200 ms, reduced-motion tersedia; kamera mendekat
     (zoom 18,5) saat Mulai; kartu tiba boleh 85 % tinggi layar.
  7. Pesan gagal rute per sebab: lokasi belum terbaca, di luar kampus, terlalu
     jauh dari jalur, lainnya.
  8. Copy (paket E): 3 string diperbaiki (trail selesai, dialog notifikasi
     onboarding, catatan suara kartu tiba).
- **Pemeriksaan:** `flutter analyze --no-pub` bersih; `flutter test --no-pub`
  504 lulus (baseline 469); `git diff --check` bersih. Emulator `agam_lean`
  (API 36, demo, GPS simulasi) menjalankan 9 skenario brief: preview langsung
  dari kartu POI, Mulai tanpa fade hitam, narasi PLAYING → PAUSED, tutup kartu
  tanpa rekomendasi, tiba + rekomendasi + Rute → preview, Labtek V → VII lewat
  selasar, fasilitas dipreview, pesan luar kampus, atribusi menciut/dibuka,
  ikon launcher dan notifikasi AGAM. Screenshot di `build/wave2-evidence/`
  (lokal, tidak di-track). Bukan bukti field test.
- **Terbuka:**
  - Selasar OSM dan titik akses masih `verified: false`; bobot 2× perlu
    dikalibrasi saat field test PB11. Titik akses dekat selasar (mis. pintu
    timur 1 Labtek V) kini menempel ke selasar, bukan ke boulevard.
  - Kamera navigasi tidak mengikuti pengguna saat berjalan (perlu tombol
    pusatkan); arahan yang tampil kadang langkah berikutnya, bukan langkah
    saat ini (terlihat di emulator); latar `FlutterMap` sebelum tile muncul
    masih abu-abu bawaan.
  - Splash: `splash_logo.png` bersudut putih, di `drawable/` (mdpi), dan biru
    logo `#09469F` ≠ latar splash `#0D3F8F`; belum diubah.
  - Build release (shrinker vs `ic_stat_agam`) belum dijalankan.
  - Baris audio `PoiDetailScreen` overflow ±4 px di lebar 390 bila POI tanpa
    audio (temuan paket C).
  - Di mode Trail, Akhiri rute ikut menghentikan trail; detail dari kartu tiba
    trail menampilkan Rute yang belum tersedia.
  - Penggunaan AI dicatat di PB20.
- **Merge `dev` (PR #21, kartu status UI06):** conflict diselesaikan di
  branch ini. `_TripCard` kini memanggil `TripStatusCard`; alur preview dan
  "rekomendasi hanya setelah tiba" dari gelombang 2 dipertahankan, jadi tes
  dev yang menutup rekomendasi di peta diganti. Aksesibilitas pil **Tutup**
  dites langsung pada `RecommendationCard` (belum ada pemanggil `onDismiss`).
## Kartu status rute UI06 dan "Lanjut ke mana?" — 26 November 2026

- Branch `feat/end-route-card` dari `22f28ad`
  (worktree `.claude/worktrees/end-route-card`). Ikon X dihapus dari dua
  kartu dan diganti komponen bersama `AgamTextPill` di
  `agam_components.dart`.
- Kartu status saat berjalan dipindah ke
  `lib/ui/widgets/trip_status_card.dart` (`TripStatusCard`): satu baris,
  nama + "Sisa … · ~… menit" di kiri, pil merah muda **Akhiri rute** di
  kanan.
- "Lanjut ke mana?" (`recommendation_card.dart`): ikon kompas dan X
  dihapus. Header berisi judul + pil garis tepi **Tutup** (key
  `recommendation-dismiss`, label pembaca layar "Tutup rekomendasi") agar
  lebih tenang dibanding tombol **Rute**. Tes kini mengetuk lewat key,
  bukan tooltip.
- Source lokal di checkout utama sudah mengganti `_RouteSummary` menjadi
  `_TripCard`. Saat digabung, isi `build` `_TripCard` cukup diganti
  pemanggilan `TripStatusCard`.
- `flutter analyze` bersih dan 469 tes Flutter lulus. Belum dicek di
  perangkat. Status PBI tidak berubah.

## Pembersihan teks internal UI — 26 November 2026

- Detail POI menampilkan kredit dan sumber. Prefix teknis
  `assets/media/… — ` dibuang dari tampilan, dan kredit identik tampil
  sekali. Path tetap tersedia di metadata untuk penelusuran aset.
- Profil menghapus baris Fakultas / Sekolah yang selalu kosong.
  Pencarian memakai **Informasi gedung belum tersedia** pada kegagalan
  membuka detail demo. Penanda build uji dan sakelar developer tetap
  mengikuti PRD.
- PB09 dan PB10 tetap `in_progress`. Pemeriksaan mencakup 44 prefix di
  dataset bawaan, 469 tes Flutter, `flutter analyze --no-pub`, dan
  `git diff --check`. Perubahan tersedia di source lokal.

## Audit catatan internal pada UI — 26 November 2026

- Detail POI bagian **Sumber** merender `assetAttribution` langsung.
  Prefix `assets/media/…` di metadata 10 POI terlihat bersama kredit.
  Profil memuat baris statis **Fakultas / Sekolah — Belum tersedia**.
- **Mode uji**, **Mode demo/trial**, dan fallback **POI tidak tersedia
  di dataset demo** dibatasi ke build demo. Deskripsi teknis fasilitas
  ada di JSON, sementara UI fasilitas memakai nama dan jarak.
- Label **Tujuan perkiraan** dan arahan lorong kandidat mengikuti PRD §11.
  APK OPPO dari commit `22c67c1` masih memuat pesan panjang sebelumnya
  karena perubahan untuk menghapusnya baru ada di worktree.
- Audit source dan dataset bawaan. Tidak ada perubahan kode UI atau
  status PBI dan tidak ada pemeriksaan ulang pada emulator atau perangkat.

## Catatan titik akses di Trail dan UI06 — 26 November 2026

- Snackbar teknis saat Trail mulai dan uraian survei di ringkasan UI06
  dihapus. Tujuan sementara diberi label ringkas **Tujuan perkiraan**
  sesuai PRD §11. Status lorong pada langkah navigasi tetap mengikuti §11.
- Rincian titik akses, fallback titik tengah, dan pemeriksaan lapangan
  dicatat di [daftar cek PB11](../task-implementation/backend/PB11-access-point-field-check.md).
  PB11 tetap `in_progress` sampai verifikasi lapangan.
- `flutter analyze --no-pub` bersih, 469 tes Flutter lulus, dan
  `git diff --check` bersih. Pemeriksaan UI memakai widget test.

## Atribusi peta ringkas — 26 November 2026

- `MapAttribution` memakai teks 8 piksel logis dengan kontras lebih tinggi.
  Kredit OpenStreetMap (ODbL) dan OpenMapTiles tetap terlihat dan
  masing-masing tertaut. Luas area ketuk dan penskalaan teks sistem
  dipertahankan. PB04 tetap `in_progress`.
- Format 143 file bersih, `flutter analyze --no-pub` bersih, dan
  seluruh 469 tes Flutter lulus.
- Commit `22c67c1` dipush ke `origin/LB` dan diintegrasikan ke
  `origin/dev` lewat fast-forward. Sumber aplikasi dan aset hasil
  integrasi cocok dengan input build produk ARM64.
- Build debug produk, audit aset, dan verifikasi tanda tangan APK v2
  lulus. `adb install --no-streaming -r` berhasil pada OPPO CPH2739
  (Android 16). Waktu instalasi awal tetap sama. Cold start AGAM
  `Status: ok` dalam 4.066 ms. APK perangkat cocok dengan hash
  `308ad4249b53ba612704d52438faf2c4041ee00106c1c0f91dd26e8c5ee9953d`.
  Salinan APK ada di `D:/CodexRuntime/agam-android/agam-dev-22c67c1-product-arm64.apk`.

## Batas kamera Jelajah — 26 November 2026

- Pada branch lokal `LB`, Jelajah mengaktifkan batas kamera opsional
  `OfflineCampusMap` dari header PMTiles. Zoom minimum menyesuaikan ukuran
  dan rotasi viewport, lalu kamera membatasi geser dan pemusatan ke area
  yang dapat dirender. Peringatan luar kampus tetap memakai batas layanan
  PRD §9.3. UI06 dan peta kartu memakai perilaku kamera sebelumnya.
- Pemeriksaan direktori arsip mengonfirmasi 85 tile mencakup seluruh
  batas aset di setiap zoom native 12–18. `test/ui/demo_explore_test.dart`
  memeriksa pinch, geser ke tepi, rotasi, perubahan viewport, dan pesan
  lokasi di luar kampus dengan fix simulasi.
- `flutter analyze --no-pub` bersih, seluruh 469 tes Flutter lulus, dan
  `git diff --check` bersih. Build APK debug demo x86_64 berhasil
  dan hash APK terpasang di emulator cocok dengan hasil build
  `23e39b4d4b21e470c47f78a01423ac4e41069db1b1a99df0527ef6b0a227f6a4`.
- Emulator API 36 dalam mode pesawat memverifikasi zoom dengan ketukan
  ganda dan roda gulir, geser ke tepi, serta peringatan dan pemusatan saat
  GPS simulasi berada di luar kampus. Bukti layar tersedia di
  `D:/CodexRuntime/agam-android/explore-lock-evidence/`.
- PB04 tetap `in_progress`. Uji perangkat fisik dan lapangan tertunda.
  Penggunaan AI untuk implementasi dan verifikasi dicakup PB20.

## UI06 layar penuh — 26 November 2026

- Implementasi di worktree lokal `AGAM-LB-PB04`, branch `LB`, dengan
  baseline `1e46a86`. `lib/ui/walking_navigation_screen.dart` memakai
  viewport penuh dengan arahan di atas, ringkasan sisa jarak dan ETA,
  serta tombol Akhiri rute. Kamera dibingkai saat peta siap. Pengguna
  dapat menggeser, memperbesar, dan memusatkan kembali peta.
- `OfflineCampusMap` menggambar `WalkingRoute.path` dengan
  `StrokePattern.dashed` di atas tile dan di bawah penanda. Jalur baru
  mengganti jalur lama setelah reroute. State tanpa rute menghapus garis.
  Geometri lorong kandidat ikut digambar dan arahan membawa label belum
  diverifikasi. Semua pemrosesan peta dan lokasi berlangsung di perangkat.
- Cari & Rute mempertahankan pilihan dan kata kunci saat panduan ditutup.
  Saat tiba, layar asal menampilkan UI07, detail, dan rekomendasi dari
  layanan yang sama. Aksi satu ketukan dari detail membuka UI06 setelah
  halaman detail tertutup. Kegagalan hitung awal ditampilkan di Cari & Rute.
- `flutter analyze --no-pub` bersih, `flutter test --no-pub --concurrency=3
  --reporter expanded` lulus 469 tes, dan `git diff --check` bersih.
  Build debug demo x86_64 berhasil. SHA-256 APK pada emulator cocok dengan
  hasil build `3ba1f3c6e3cb5f34efceca26682fcc68c66627d8868c706857b438620c58b8f5`.
- Emulator API 36 (720 × 1600), mode pesawat dan Wi-Fi mati, memakai titik
  akses dataset Labtek V → Labtek VIII serta vertex jalur untuk GPS
  simulasi. Pemeriksaan mencakup lorong, pergantian instruksi belok kanan
  dan kiri, garis reroute, pemusatan peta, kartu tiba dan rekomendasi,
  serta pemulihan pencarian setelah Akhiri rute. Bukti `jelajah.png`,
  `navigasi-aktif.png`, dan tangkapan tambahan tersedia di
  `D:/CodexRuntime/agam-android/ui06-evidence/`.
- PB11 dan PB12 tetap `in_progress`. Survei titik akses/lorong, uji
  perangkat fisik, dan acceptance lapangan F06 masih tertunda. Penggunaan
  AI untuk implementasi dan pengujian dicakup PB20.

## Current — Gelombang 1: routing, tiba, trail, rekomendasi, akun, 25 November 2026

- Branch integrasi `feat/field-test-wave1` dari `dev` @ `5cc955c`, berisi merge
  WP2 `feat/access-point-routing`, WP3 `feat/arrival-feedback`, WP4
  `feat/trail-nearest-start`, WP6 `feat/account-delete-logs`, WP5
  `feat/recommendations-ui07`, plus commit penghubung. Dikerjakan paralel oleh
  subagent di worktree terpisah; konflik hanya di `demo_frontend_test.dart` dan
  satu blok `search_route_screen.dart`.
- WP2 routing: graf + `passages.geojson` dimuat dari aset di build produk dan
  demo; titik hanya ditempel ke jaringan terhubung terpanjang; tujuan = titik
  akses terdekat menurut jarak jalan kaki (kontrak `NavigationTarget.candidates`,
  perlu review LA/LB/FE); tiba ≤15 m dari titik akses mana pun; arahan lorong
  kandidat "(belum diverifikasi)". `pubspec.yaml` (LA) mendaftarkan dua aset graf.
- WP3 tiba: TTS "Anda telah tiba di {fasilitas}" bila suara `id-ID` ada; kartu
  tiba di Cari & Rute. `AgamAnimatedSize` menggantikan semua `AnimatedSize` di
  UI (crash build debug saat reduced motion; APK lapangan adalah build debug).
- WP4 trail: mulai dari POI terdekat, titik awal per akun, kandidat titik akses
  diterima, `trailCompleted` sekali; layar Trail berjalan di demo.
- WP5 rekomendasi: UI07 "Lanjut ke mana?" di bawah kartu tiba dan di peta
  setelah panel ditutup; Rute satu ketukan (`startRouteOnOpen` /
  `onStartRoute`); tanpa log.
- WP6 akun & log: hapus akun di UI09; `featureUsed` untuk search, poiCard,
  narration, facilities. Keputusan PM: aksi dari trigger/kartu tiba tidak
  dicatat (PRD §15.5, rules §5.1).
- Penghubung: trail dan rekomendasi di `main.dart` kedua build; satu
  `AccountVisitStore` dipakai trail, rekomendasi, dan hapus akun
  (`createLaAccountServices(trailVisits:)`); Rute di panel peta/detail aktif di
  demo; penanda rute di titik akses yang dipilih.
- Dokumen: rules §2 tabel Audio dan PRD §23 "Sumber suara" (TTS juga untuk tiba
  di fasilitas), PRD §15.5 baris `featureUsed`, implementationPhases (rekap 18
  `in_progress`/4 `planned`; PB11, PB12, PB14, PB15, PB16, PB21, PB22).
- Pratinjau web (Playwright, 390×844, lokasi palsu Labtek V → VIII): cari →
  Rute → kartu tiba + "Lanjut ke mana?" → Rute satu ketukan memulai rute; di
  peta, menutup panel memunculkan UI07 dan Rute langsung membuka rute; tanpa
  error console. Temuan: ETA "0 menit" untuk jalan <1 menit, kini dibulatkan
  ke atas (min. 1).
- Verifikasi: format/analyze bersih, 469 test lulus. Belum: build APK (CI PR),
  uji emulator/perangkat, tes lapangan.
- Terbuka: kunjungan Explore tidak dicatat ke `AccountVisitStore`;
  `DeviceAuthService.deleteAccount` bisa gagal setengah jalan; status suara
  `id-ID` di-cache sampai aplikasi dibuka ulang; rekomendasi di layar sangat
  pendek dan pergantian kartu tiba saat trail auto-route belum diuji; kelas
  `UnavailableRecommendationService` kini tak terpakai; `recommendation_bootstrap.dart`
  (folder LB) perlu review LB; CI `dev` `5cc955c` gagal di build APK dan belum
  di-re-run (CI PR untuk commit yang sama lulus, diduga gangguan runner); PB13
  eyes-free belum dimulai.

## Current — Gelombang 0: titik akses, urutan trail, dan dokumen, 24 November 2026

- Branch `feat/access-points-trail-data` dari `dev` @ `bc42624`, worktree
  `.claude/worktrees/wave0`. Bagian pertama rencana kerja menuju tes lapangan
  25 November 2026 (WP0 dokumen + WP1 data); WP2–WP6 menyusul.
- Keputusan pengguna 24 November 2026, dicatat [CL] di PRD: tujuan rute
  menjadi *titik akses* (F06/§11), tiba di fasilitas diumumkan dengan TTS
  (§10), trail berupa keliling yang dimulai dari POI terdekat (F08/§12).
- `tools/routing/plan_access_points.py` (fiona + shapely, deterministik, idempoten):
  titik akses = titik pada ruas jaringan utama graf yang menempel ke poligon gedung OSM
  (≤4 m dari dinding, 8 m bila kosong, digabung bila <5 m), lalu dikoreksi pengguna
  lewat peta 25 November (8 tambah, 6 hapus; `tools/routing/access_overrides.json`):
  41 kandidat untuk 10 gedung, semuanya `verified: false`. Empat kandidat lorong di
  `assets/routing/passages.geojson` (Labtek V, VII, VIII dari selasar; Labtek X dari
  koreksi peta, ujungnya titik akses, bukan simpul graf); aset ini belum didaftarkan di `pubspec.yaml` (dikerjakan WP2). Titik
  dan lorong `verified: true` tidak ditimpa saat script dijalankan ulang. Urutan trail = keliling terpendek dengan jarak
  antar-POI diukur di antara titik akses terdekat. Mengisi `entrances[]` (satu titik
  per baris) dan `trailOrder` 1–10 di `pois.json`, serta menulis daftar cek
  `task-implementation/backend/PB11-access-point-field-check.md`.
- Kontrak: `PoiEntrance.verified` (default `false`); `hasSurveyedEntrance`
  hanya untuk titik terverifikasi; `navigationPoint` memakai kandidat. Codec
  hanya menerima `true` eksplisit. Seed Firestore tidak menyaring field.
- Temuan untuk WP2/WP4: graf draf 17 potongan; WP2 harus memuat
  `passages.geojson` sebagai ruas tambahan dan menyebut lorong kandidat di arahan.
  Beberapa titik akses hanya terjangkau lewat lorong (mis. titik pertama Labtek
  VIII = ujung selasar; juga Labtek VII sisi tenggara, Labtek VI sisi selatan,
  Labtek V sisi barat laut). Acceptance WP2: rute ke titik akses terdekat (bukan
  `navigationPoint`) dan test bahwa rute ke seluruh 41 titik akses berhasil.
  Titik koreksi di sudut gedung berjarak 7–13 m dari jalur; routing menempelkannya
  (batas 25 m). Label kandidat dapat bernomor tidak berurutan setelah ada titik
  terverifikasi (kosmetik). Navigasi harus memilih titik akses terdekat dari
  `entrances[]`, bukan `navigationPoint` (titik pertama).
  `DeviceTrailService._canRoute` menolak titik kandidat, jadi trail tidak bisa
  dimulai sebelum aturan itu disesuaikan. Pesan "Pintu masuk belum disurvei"
  di `search_route_screen.dart` perlu diganti saat routing disambungkan.
- `implementationPhases.md`: rekap 24 November (17 `in_progress`, 5
  `planned`), PB03 seed otomatis berjalan, PB09/PB11/PB12/PB15/PB21/PB22
  diperbarui sesuai kode `dev`. PRD §22: titik akses, urutan trail, Firebase,
  dan konten diperbarui.
- Test: kandidat titik akses di dataset, urutan trail 1–10, codec `verified`,
  lorong menghubungkan simpul graf yang ada (`passages_data_test.dart`).
  Analyze bersih, 416 test lulus.

## Current — Onboarding crash di layar pendek, 24 November 2026

- Branch `fix/onboarding-small-height` dari `dev` @ `6329963`.
- Gejala: layar merah di pratinjau web setelah jendela browser dikecilkan
  ("BoxConstraints has a negative minimum height", disusul
  `_elements.contains(element)`); halaman tetap rusak setelah jendela
  dibesarkan lagi. Juga terjadi di ponsel landscape (tinggi 360 px).
- Sebab: di `onboarding_screen.dart` tinggi sheet minimal 280 px, sehingga
  `visualHeight` (tinggi layar − sheet) dan `photoHeight` (− overlap 92 px)
  bisa negatif. Kini `_sheetHeight` dibatasi ke tinggi layar dan
  `photoHeight` di-clamp ke 0–330.
- Test `test/ui/onboarding_small_height_test.dart` (2 test, keduanya gagal
  pada kode lama). Analyze bersih, 410 test lulus.

## Current — Animasi tombol narasi, gelombang audio, ikon fasilitas, 24 November 2026

- Branch `feat/narration-card-motion` dari `dev` @ `cd5753d`, worktree
  `.claude/worktrees/narration-card-motion`. Sudah di-commit, belum di-push.
- Tombol "Dengarkan Cerita" ↔ "Jeda cerita" tersendat karena di
  `AgamPrimaryButton` ikon berganti seketika, sedangkan label lama tetap
  menentukan lebar sampai fade selesai lalu lebar meloncat (baris rata
  tengah, jadi ikon ikut meloncat). Kini ikon berada di slot tetap 20 px
  dengan transisi `AgamMotion.iconSwap` (fade + skala 0,7→1 + blur 2 px,
  200 ms), dan lebar label mengikuti label baru lewat `AnimatedSize` 240 ms
  ease-out. Berlaku untuk semua tombol utama.
- Kartu Narasi (UI04): ikon headphone berganti menjadi bar gelombang yang
  mengikuti kerasnya audio. Data dari `narasi.wave.json` (5 pita frekuensi,
  20 frame/detik) di samping tiap `narasi.m4a`, dibangkitkan oleh
  `tool/build_narration_waves.py` (ffmpeg + numpy). **Jalankan ulang script
  setiap kali file narasi berubah.** Tanpa file envelope atau dengan reduced
  motion, kartu menampilkan ikon `graphic_eq` statis. Ticker hanya berjalan
  saat narasi diputar dan berhenti bila posisi tidak diperbarui 400 ms.
- Fasilitas di UI04 memakai ikon sesuai nama (Toilet, Mushalla, Kantin,
  Apotek, Laboratorium, Ruang Kelas, dst.), dengan penanda netral untuk nama
  lain. Pil "Fasilitas sekitar" di kartu peta tidak diubah (sedang dikerjakan
  di worktree dataset fasilitas).
- Verifikasi: analyze bersih, 396 test lulus (3 test baru di
  `test/ui/narration_wave_test.dart`); tampilan dicek lewat golden sementara
  (sudah dihapus). Belum dicoba di perangkat.
- Merge `origin/dev` (PR #15 dataset fasilitas) untuk PR #14: konflik hanya
  di catatan ini. Import `narration_wave.dart` di `poi_detail_screen.dart`
  diletakkan sebelum `agam_theme.dart` agar tidak bentrok dengan import
  `agam_video_player.dart` dari PR #13.
- CI PR #14: CI `dev` merah sejak `cd5753d` karena
  `tools/tiles/test_campus_export.py` butuh `requirements-campus.txt`
  (pmtiles, fiona, dst.) yang tidak dipasang; `ci.yml` kini memasang Python
  3.12 + requirements itu. Perubahan `ci.yml` identik di PR #13.

## Current — Transisi ganti tujuan di Cari & Rute, 24 November 2026

- Branch `feat/search-destination-transition` dari `dev` @ `6329963`; diuji
  manual oleh pengguna di pratinjau web.
- Sebelumnya peta kartu tujuan diberi key per tujuan, sehingga memilih titik
  lain membangun ulang peta langsung di titik baru dan teks berganti seketika.
- Kini satu peta hidup selama kartu terbuka (`GlobalKey`), dan
  `OfflineCampusMapState.flyTo` menggeser kamera A→B: 450–650 ms menurut
  jarak, kurva `AgamMotion.travel`, zoom turun sedikit di tengah jalan untuk
  jarak > 80 m. Penanda yang muncul setelah peta siap masuk dengan fade +
  skala 0,9→1.
- Teks kartu (nama; jarak/ETA di kartu produk) memakai `AgamArrival` baru:
  teks lama larut (fade + blur 2 px) selama 85 % waktu tunggu, teks baru
  muncul pada 55 % waktu terbang kamera. Perubahan dengan id sama (jarak/ETA
  saat navigasi) diperbarui tanpa animasi. Reduced motion: kamera melompat,
  teks crossfade singkat.
- Memilih tujuan dari daftar yang sudah digulir kini menggulir daftar ke atas
  (360 ms) agar kartu dan perpindahan kamera terlihat.
- Test `test/ui/search_destination_transition_test.dart` (4 test). Analyze
  bersih, 412 test lulus. Diperiksa dengan Playwright (390×844, mode demo):
  Labtek V→VIII, V→I, dan gulir balik dari TVST. Kartu versi produk memakai
  kode yang sama tetapi tidak tampil di pratinjau demo.

## Current — Dataset fasilitas versi pertama, 24 November 2026

- Branch `feat/facility-dataset` dari `dev` @ `cd5753d`; belum di-commit.
  Perbaikan uji alur sebelumnya sudah di `dev` (`bafd782`); branch ini
  di-rebase ke atasnya.
- `assets/data/pois.json`: 26 fasilitas, disetujui SebastianAben (owner,
  verifiedAt 2026-11-24, approved true).
  - F01–F19 toilet/musala/kantin dari daftar `facilities` tiap POI;
    `buildingId` gedungnya, titik = titik gedung (letak persis belum
    disurvei). "Mushalla" → kategori `musala`; "Apotek", ruang kelas, dan
    laboratorium tidak dipetakan.
  - F20–F26 dari informasi pengguna: ATM BCA, ATM Center, Perpustakaan Pusat
    ITB, Information Center (titik ditandai pengguna di screenshot peta AGAM,
    digeoreferensi terhadap 8 penanda POI; skala 0,59 m/px, residu 0,5–6 m);
    ATM BNI (GKUT lt. 1), Perpustakaan STEI (Labtek V lt. 3), Tata Usaha STEI
    (Labtek V lt. 2) memakai titik gedung.
- UI: kartu tujuan Cari & Rute kini menampilkan penanda fasilitas
  (`MapHighlight` baru di `OfflineCampusMap`). Dicek di browser: keempat
  titik yang ditandai jatuh di lokasi yang sama dengan tanda pengguna.
- Test: dataset (26 item, semua kategori, buildingId valid, di dalam batas
  kampus, cocok dengan daftar per POI) dan pencarian fasilitas diperbarui.
  Analyze bersih, 394 test lulus.
- PRD §22 dan implementationPhases (PB10) diperbarui.
- Terbuka: jarak/ETA tetap "—" karena routing belum ada; letak persis
  fasilitas dan verifikasi lapangan.
- Lanjutan: label "· contoh" di "Fasilitas sekitar" panel POI dihapus
  (`a42859a`). Panel kini menampilkan satu fasilitas terdekat per kategori,
  maks. 4 (`nearestPerCategory` di `facility_labels.dart`); TVST: Toilet
  TVST, Kantin Labtek X & XI, Musala Labtek VII, Tata Usaha STEI. Test
  `test/ui/nearest_facilities_test.dart`.

## Current — Pemutar video kartu POI (PB07), 24 November 2026

- Branch `feat/poi-video-player` dari `dev` @ `cd5753d`, atas instruksi
  pengguna (menyimpang dari model branch main/dev/LA/LB/FE di rules §8).
  Belum di-commit.
- Sebelumnya video P06 sudah dibundel dan terbaca di `PoiMedia.video`, tetapi
  tidak ada pemutar di branch mana pun.
- Baru: `lib/ui/widgets/agam_video_player.dart` (`AgamVideoPlayer`) dan bagian
  "Video" di `lib/ui/poi_detail_screen.dart`, hanya untuk POI approved dengan
  `media.video` (saat ini P06 GKUB). Controller dibuat saat diketuk, tanpa
  autoplay; layar penuh memakai controller yang sama; video dan audio POI
  saling menjeda; atribusi "Video: TikTok" tetap dari kartu Sumber.
- `pubspec.yaml`/`pubspec.lock` (milik LA): `video_player: ^2.14.1`
  (dependency) dan `video_player_platform_interface: ^6.9.0` (dev, untuk fake
  di test), keduanya dari resolver `pub add`; versi package lain tidak
  berubah. minSdk `video_player_android` 2.13.0 = 24, sama dengan default
  Flutter 3.47.9. PR perlu direview LA.
- Test: `test/ui/poi_video_player_test.dart` (5 test, fake platform mengikuti
  pola test `video_player`). Analyze bersih, 398 test lulus (393 + 5).
- Privasi (rules §5.1): `video_player` hanya memutar aset bundel APK; manifest
  plugin `video_player_android` 2.13.0 tidak mendeklarasikan izin apa pun, dan
  tidak ada akses lokasi atau pengiriman data. PRD §17 tabel stack baris Video
  kini menyebut `video_player`.
- Belum: build APK dan uji di perangkat (Mac ini tanpa Android SDK). PB07 tetap
  `in_progress`. Yang perlu dicek di HP:
  1. APK **release**, bukan hanya debug (lihat preseden `f033e4d`:
     resource shrinking merusak `audio_service` hanya di release).
  2. Video GKUB terputar dengan suara; layar penuh melanjutkan posisi yang
     sama.
  3. Mulai video saat narasi berjalan, dan sebaliknya: hanya satu suara,
     notifikasi media dan status kartu Narasi tetap konsisten (ExoPlayer
     video mengambil audio focus karena `mixWithOthers` bawaan `false`).
  4. Video berhenti saat aplikasi ke latar belakang.
- Preview web: video seharusnya dapat diputar lewat `video_player_web`, tetapi
  belum dicoba.
- Merge `origin/dev` (PR #15 dataset fasilitas) untuk PR #13: konflik hanya
  di catatan ini; catatan ini diletakkan di bawah catatan dataset fasilitas
  agar tidak bentrok dengan catatan PR #14.
- CI PR #13: `agam_video_player.dart` diformat ulang (`dart format`). CI
  `dev` merah sejak `cd5753d` karena `tools/tiles/test_campus_export.py`
  butuh `requirements-campus.txt` (pmtiles, fiona, dst.) yang tidak dipasang;
  `ci.yml` kini memasang Python 3.12 + requirements itu. Perubahan `ci.yml`
  identik di PR #14.

## Current — Uji alur Playwright `dev` setelah PR #12 (LB), 24 November 2026

- Basis `dev` @ `cd5753d`: analyze bersih, 393 test lulus. Branch kerja
  `chore/dev-flow-check`; masuk `dev` sebagai `bafd782`.
- Uji alur di browser (pratinjau web sementara, sudah dihapus): layanan
  perangkat (izin, lokasi, sesi, audio, akun) fake; selebihnya sama dengan
  wiring demo `main.dart` (repository + search asli, `AgamMapConfig.campus()`,
  `DeviceNavigationController` + `UnavailableCampusRouting`,
  `RepositoryFacilityService`, trail/rekomendasi unavailable). Alur yang
  lulus: splash → masuk gagal → daftar (persetujuan wajib, peran) →
  onboarding → peta tile HD → panel POI Labtek V → Cari & Rute → cari
  "labtek 5" → chip Toilet ("Data toilet belum tersedia.") → Trail →
  Explore mulai/akhiri → profil → keluar → masuk ulang. Tanpa error console.
- Bug yang ditemukan dan diperbaiki:
  1. Logout di build produk kembali ke peta, bukan UI10: onboarding memakai
     `pushReplacement` sehingga gerbang login hilang. Kini `_SignedInFlow`
     (onboarding → shell, crossfade) berada di dalam gerbang `app.dart`.
     Test `test/ui/auth_gate_test.dart` (gagal pada kode lama).
  2. Rute tanpa graf menampilkan "Rute pratinjau ..." seolah berhasil:
     `DeviceNavigationController` melapor status error tanpa throw. Kini
     `search_route_screen.dart` memeriksa status dan menampilkan "Rute belum
     tersedia untuk tujuan ini." Test `test/ui/route_unavailable_test.dart`
     (gagal pada kode lama).
  3. Galat kolom masuk/daftar tetap merah setelah diperbaiki: form kini
     memvalidasi ulang saat mengetik setelah submit pertama
     (`auth_screen.dart`, test baru di `auth_screen_test.dart`).
  4. Trail kosong berkata "Belum ada gedung di daftar ini." — kini
     "Urutan Orientation Trail belum tersedia." bila urutan kosong.
  5. Laten: tombol "Detail" langkah trail berikutnya (`AgamTonalButton` di
     `Row` tanpa `Expanded`) crash layout saat trail punya urutan; kini
     Expanded (Rute 2 : Detail 1). Akan muncul begitu `DeviceTrailService`
     disambungkan.
- Verifikasi: analyze bersih, 396 test lulus.
- Masih terbuka: `DeviceTrailService` dan graf draf LB belum disambungkan;
  build APK belum (tanpa Android SDK di Mac ini); tombol hapus akun belum ada.

## Current — Merge `dev` ke `LB` untuk PR LB → dev, 24 November 2026

- Konflik PR LB → `dev` hanya di catatan sesi ini; kedua catatan dipertahankan.
  Kode LB (tile HD z12–18, graf draf, `graphOnly`, `arriveAtRouteEnd`)
  tergabung tanpa konflik dengan `dev` @ `8964f7b` (batas layanan produk,
  wiring trigger produk, perbaikan header UI10).
- Merge tanpa konflik teks tetap merusak build: commit LB `eb87816` menghapus
  `UnavailableTrailService`, padahal `main.dart` di `dev` (PR #9 LA) masih
  memakainya. Kelas itu dikembalikan ke `account_visit_store.dart` agar
  perilaku `dev` tidak berubah (trail belum tersedia). `DeviceTrailService`
  (LB) tetap utuh dan menunggu disambungkan LA di bootstrap (akun, sesi,
  navigasi, log `trailCompleted`; urutan dari `trailOrder` di `pois.json`).
- Verifikasi hasil merge: analyze bersih, 393 test lulus.
- Graf draf `assets/routing/ganesha-walk-demo.geojson` belum didaftarkan di
  `pubspec.yaml` dan belum dipakai `main.dart`; routing tetap
  `UnavailableCampusRouting` sampai integrasi LA.

## Current — Perbaikan sambungan header dan sheet UI10, 24 November 2026

- Di layar Masuk/Daftar, glow cyan kiri bawah `AgamGround` terpotong di batas
  header sementara sudut sheet berada di atas latar navy polos, sehingga
  tampak garis/beda warna di kiri. Kini header dan sheet berada dalam satu
  sliver (viewport menggambar sliver awal di atas sliver berikutnya) dan
  sheet ditarik naik sebesar radius sheet, sehingga sudutnya duduk di atas
  gradien dan glow header yang sama. Latar di belakang scroll kini putih.
- Branch `fix/auth-header-seam` dari `dev` @ `b76cdce`; belum di-commit.
  Analyze bersih, 388 test lulus; dicek lewat render golden sementara.

## Current — Pemeriksaan sambungan `dev` setelah PR #9 (LA) dan #11 (redesign), 24 November 2026

- Basis `dev` @ `1cf202e`: analyze bersih, 387 test lulus.
- Jalur produksi `main.dart` kini meneruskan `poiViewRequests` dan
  `onPoiAction` dari `la.triggerResponder` ke `AgamApp`, sama seperti demo.
  Sebelumnya notifikasi trigger POI di build produk tidak membuka kartu POI.
- Rute tanpa graf (`UnavailableCampusRouting`) ditangani: navigasi berstatus
  error dan layar menampilkan "Rute belum tersedia untuk tujuan ini."
- Batas layanan produk ditetapkan atas keputusan tim (opsi 1):
  `AgamMapConfig.campus()` = bounds engineering OSM + 200 m, poligon yang sama
  dengan demo (konstanta `engineeringBounds`), berlabel sumber "PRODUK". Build
  produk memakainya sehingga trigger POI dan navigasi aktif. PRD §9.3, §22,
  §23 dan PB04 di implementationPhases diperbarui. Belum diverifikasi lapangan.
- Verifikasi: analyze bersih, 388 test lulus (test baru batas produk).
- APK tidak dapat dibangun di Mac ini: Android SDK tidak terpasang
  (`No Android SDK found`). Build Android dan uji perangkat perlu dijalankan
  di mesin dengan Android SDK.

## Current — Merge `dev` ke `feat/ui-ux-redesign`, 24 November 2026

- Konflik PR redesign → `dev` diselesaikan dengan merge `dev` (PR #9 LA:
  10/10 POI dan layanan LB asli) ke branch redesign.
- `lib/main.dart`: jalur produksi dari UI10 (Firebase + `createLaAccountServices`
  + gerbang login) dipertahankan, tetapi kini memakai layanan asli yang sama
  dengan demo (`DeviceNavigationController` + `UnavailableCampusRouting`,
  `RepositoryFacilityService`, `UnavailableRecommendationService`,
  `UnavailableTrailService`) karena layanan LB fake sudah dilepas di `dev`.
  Demo tetap memakai akun fake tanpa Firebase.
- Catatan LA di bawah ("jalur non-demo tetap terblokir sampai UI10 di-merge")
  sudah terpenuhi oleh merge ini.

## Current — UI10 dipisah menjadi halaman Masuk dan Daftar, 24 November 2026

**Permintaan:** pengguna ingin login dan register terasa sebagai dua layar
terpisah (bukan segmented switcher) dengan tautan "belum punya akun", dan
animasi transisinya diperhalus.

**Perubahan:**
- `lib/ui/auth_screen.dart`: segmented Masuk/Daftar dihapus. Halaman Masuk
  punya tautan "Baru di AGAM? Daftar"; halaman Daftar punya tombol kembali
  bulat, judul "Buat akun AGAM", dan tautan "Sudah punya akun? Masuk".
  Tombol back Android di halaman Daftar kembali ke Masuk (`PopScope`).
  Email terbawa antarhalaman, password tidak.
- Transisi: header dan form bergerak dengan shared axis horizontal 320 ms
  (sama dengan `AgamMotion.route`), maju ke Daftar dan mundur ke Masuk.
  Latar navy dan sheet putih tetap diam sehingga tidak ada kilatan warna.
  Tombol utama tidak ikut bergerak; labelnya fade-through.
  Keyboard ditutup sebelum transisi agar halaman tidak melompat.
- `AgamPrimaryButton`: label yang berubah kini fade-through 240 ms
  (berlaku di semua layar).
- Perbaikan: "Lupa password?" dan tautan pindah halaman sebelumnya memakai
  `TextButton.styleFrom(textStyle:)` sehingga jatuh ke font bawaan (Roboto);
  kini gaya ada di `Text` sehingga tetap PlusJakartaSans. Ripple baris
  persetujuan sekarang terlihat di atas latarnya.
- Ikon kartu peran beranimasi sekali saat kartu dipilih (460 ms, tanpa
  loop, dilewati pada reduced motion): topi toga Mahasiswa ITB terangkat
  dan miring lalu kembali; ikon Pengunjung melangkah maju sedikit lalu
  kembali. Warna ikon berpindah halus (abu → biru).

**Verifikasi:** analyze bersih, `flutter test` 387 lulus (tes auth 10 kasus,
termasuk halaman terpisah dan back sistem). Frame transisi diperiksa lewat
golden sementara (sudah dihapus). Belum di-commit.

## Current — Redesign UI10 (masuk/daftar) dan splash, 24 November 2026

**Permintaan:** pengguna meminta redesign layar login, register, dan splash
di branch `feat/ui-ux-redesign`, identitas AGAM tetap, lebih intuitif.
Perilaku `AuthService`, validasi, dan semua pesan galat tidak berubah.

**Perubahan:**
- `lib/ui/splash_screen.dart`: latar `#0D3F8F` sama dengan splash native,
  logo di tengah, wordmark "AGAM" naik sekali, lalu crossfade 320 ms ke layar
  berikutnya (sebelumnya berganti tanpa transisi). Tidak ada animasi loop;
  reduced motion menampilkan keadaan akhir langsung. Durasi tetap ±1,1 s.
- `lib/ui/auth_screen.dart`: header navy (logo + judul "Selamat datang" /
  "Buat akun AGAM", tanpa subjudul), sheet putih dengan `AgamSegmented`
  Masuk/Daftar, field filled dengan autofill (email, password/newPassword),
  "Lupa password?" di kanan bawah field, kartu peran Mahasiswa ITB /
  Pengunjung, baris persetujuan privasi yang menjadi merah beserta pesannya
  bila belum dicentang, dan banner galat/info di atas tombol (pengganti
  snackbar). Tombol utama dipin di bawah, naik di atas keyboard. Filler
  sliver menggantikan `SliverFillRemaining` berisi form (bug tinggi intrinsik).
- Teks pemberitahuan privasi tidak diubah (`AuthScreen.consentText`) dan tetap
  menunggu persetujuan PM (PRD §22).
- Berpindah Masuk/Daftar tidak lagi menghapus isi field (form diberi key
  baru, bukan `reset()`); tombol utama tidak menampilkan spinner saat
  mengirim reset password.
- Tes baru `test/ui/auth_screen_test.dart` (8 kasus: validasi, kredensial
  salah, persetujuan wajib + role, minimal 6 karakter, lupa password,
  offline, toggle password, isi field bertahan saat ganti mode).
- Status PBI di `implementationPhases.md` tidak berubah: UI10 tetap
  "implementasi awal, menunggu teks privasi serta verifikasi PM".

**Verifikasi:** `dart format`, `flutter analyze` bersih, `flutter test`
385 lulus. Pratinjau web diperiksa (splash, masuk, daftar, keadaan galat).
Belum diuji di perangkat fisik. Belum di-commit.

## Current — UI10 login/logout dan perangkaian akun, 23 November 2026

**Perubahan:**
- Splash native Android dan splash Flutter ditambahkan dengan logo [assets/media/logo.png](/Users/aliyaharta/Documents/GitHub/AGAM/assets/media/logo.png);
  splash Flutter berlangsung singkat lalu berpindah ke login/onboarding.
- Tambah [AuthScreen](/Users/aliyaharta/Documents/GitHub/AGAM/lib/ui/auth_screen.dart)
  untuk masuk, daftar, pemilihan role, lupa password, validasi, dan pesan
  offline sesuai kontrak `AuthService`.
- [AgamApp](/Users/aliyaharta/Documents/GitHub/AGAM/lib/ui/app.dart) sekarang
  menampilkan gerbang login dalam build produk dan memulihkan UI berdasarkan
  `AuthState`. Pengecualian demo internal tetap melewati login.
- [main.dart](/Users/aliyaharta/Documents/GitHub/AGAM/lib/main.dart) memakai
  Firebase initialization dan `createLaAccountServices` pada build produk.
- Profil menampilkan email dan role nyata bila tersedia serta tombol logout
  dengan konfirmasi. Logout mengakhiri navigasi profil dan kembali ke UI10.

**Verifikasi:** format selesai; analyzer pinned hanya tersisa pemeriksaan
lanjut terhadap test/build. Uji perangkat Firebase dan emulator Firestore belum
dijalankan. Logout/hapus akun di layar belum diuji perangkat fisik.

**Belum selesai:** teks pemberitahuan privasi tetap menunggu persetujuan PM,
progres trail per akun, event FE/LB PB22, dan verifikasi aturan emulator.

## Current — Redesign UI/UX menyeluruh (selain onboarding), 22 November 2026

**Permintaan:** pengguna meminta perombakan total UI, animasi dan UX seluruh
layar yang sudah ada, kecuali Onboarding & Izin, dengan identitas AGAM tetap
dijaga dan gaya disamakan dengan onboarding. Tab Pengaturan dihapus dari
navbar dan dipindah ke tombol akun di kanan atas. Layar yang belum ada (UI06
penuh, UI07, UI10) sengaja tidak dibuat. Branch `feat/ui-ux-redesign` dari
`dev` @ `5638f45` atas instruksi pengguna (pengecualian model branch track).

**Sistem desain baru:** `lib/ui/widgets/agam_theme.dart` (token warna dari
onboarding: navy/teal/forest/cyan/mint, kanvas `#F5F7FB` menggantikan tint
lavender lama, skala teks 26/20/17/15/13/12, radius, bayangan, tema global)
dan `agam_components.dart` (AgamGround = latar bergradien + glow onboarding,
kartu, tile ikon, pill, tombol utama stadium bercahaya, tombol tonal, grup
daftar, segmented control dengan thumb bergeser, tombol kembali bulat).
`agam_motion.dart` menambah route shared-axis dan `AgamReveal` (masuk sekali,
stagger 45 ms, menunggu tab pertama kali tampil, tanpa loop, reduced motion
langsung tampil).

**Per layar:**
- Shell/navbar: 3 tab (Jelajah, Trail, Cari & Rute) dengan pill aktif yang
  bergeser dan ikon outline→filled; haptic ringan saat ganti tab. Header
  logo + wordmark + chip Mode uji; avatar membuka Profil & Pengaturan lewat
  route shared-axis. Header lentur di 320 px.
- Jelajah: peta penuh, status lokasi melayang, kapsul kontrol 48 px, kartu
  sesi bawah yang berubah putih "Mulai" → navy "Explore aktif/Akhiri"
  (redup saat sibuk, tanpa spinner tak berujung). Penanda POI baru (lencana
  + label; label hanya saat zoom ≥18 atau terpilih agar tidak bertumpuk;
  terpilih digambar paling atas), titik posisi dengan halo statis, atribusi
  OSM satu baris di peta. Kartu UI03 meniru kartu prompt onboarding; POI yang
  terpicu menampilkan prompt suara, POI yang diketuk menampilkan ringkasan.
- Detail Lokasi: hero foto yang menyusut menjadi app bar berjudul, lembar
  putih di atas foto, pemutar narasi di latar navy, seksi fungsi/fasilitas
  (chip)/trivia/sumber, placeholder tanpa gambar gedung karangan.
- Trail: hero hijau-teal dengan cincin progres, kartu lencana, segmented
  filter, timeline bernomor bergaris; ilustrasi peta skematis dihapus dan
  diganti catatan jujur "Graf rute belum tersedia".
- Cari & Rute: hero navy dengan kolom cari (ring fokus cyan), pill filter
  beranimasi, grup daftar tujuan, grid ikon 6 kategori fasilitas, kartu
  tujuan/rute baru (painter rute palsu dihapus; peta asli bila titik ada).
- Profil & Pengaturan: app bar navy ter-pin dengan identitas yang menyusut,
  grup Detail Akun/Sesi/Narasi/Perangkat/Developer.

**Bug yang ditemukan saat verifikasi visual dan diperbaiki:** konten Profil
tidak bisa digulir sampai bawah (`SliverFillRemaining` mengukur intrinsics),
tombol kembali Profil ikut tergulir hilang, header overflow di layar sempit.

**Test:** asersi geometri FE lama di `demo_explore_test` ditulis ulang untuk
tata letak baru dengan maksud yang sama (kontrol 48 px di dalam peta,
atribusi satu baris tak tertutup kartu sesi, header di atas peta, target
avatar 44 px, 320 px tanpa exception); akses Pengaturan lewat avatar; foto
dicocokkan juga lewat `ResizeImage`; panel POI ditutup sebelum Akhiri sesi.
`demo_frontend_test` menambah pump setelah ensureVisible. Test baru
`test/ui/redesign_controls_test.dart` (3 tab + avatar, AgamReveal sekali
jalan + reduced motion, segmented control).

**Verifikasi:** format 0 perubahan, `fvm flutter analyze --no-pub` bersih,
`fvm flutter test --no-pub` **376 lulus**, `git diff --check` bersih. Render
diperiksa via golden sementara dengan dataset/tile asli di 390×844 dan
320×640 (sudah dihapus). **Tidak** dijalankan di emulator/perangkat. Status
PBI tidak berubah. Onboarding tidak disentuh. Belum commit/push.

**Lanjutan (22 November 2026):**
- Ligatur `liga` dimatikan di tema: Plus Jakarta Sans menggabungkan "fi"
  tanpa titik pada "i" ("Profil", "Notifikasi").
- Filter UI05 (keputusan pengguna, pilihan 1): chip/tombol filter jenis
  gedung "Ruang Kuliah"/"Laboratorium" dihapus karena bertentangan dengan
  PRD §9.1 (Labtek = gedung laboratorium **dan perkuliahan**; kesepuluh POI
  punya Ruang Kelas) dan tidak ada di kontrak `SearchService`. Grid enam
  kategori fasilitas kini satu-satunya "filter kategori" F05/UI05: memilih
  kategori menyembunyikan daftar gedung dan meneruskan `facilityCategories`
  ke pencarian; pill aktif muncul saat mengetik. Dataset fasilitas kosong →
  "Data <kategori> belum tersedia.".
- Ikon POI netral (satu ikon gedung) di peta, kartu, Trail, Cari, Detail.
- Copywriting atas arahan pengguna ("hindari label/deskripsi sekunder,
  biarkan tata letak menjelaskan"), termasuk onboarding (hanya teks): hapus
  tagline header, subjudul kartu sesi, overline kategori, label "Pemandu
  Suara", placeholder foto/fasilitas kosong, stat Jarak/Waktu kosong, pill
  "Belum dikunjungi", catatan graf rute, subjudul baris pengaturan; judul
  seksi detail dipendekkan (Narasi, Tentang gedung, Fungsi, Fasilitas,
  Trivia, Sumber). Teks wajib PRD dipertahankan (penjelasan lokasi UI01/A01,
  "Hanya saat aplikasi digunakan", panduan baterai, placeholder konten).
- **Untuk tim konten:** Labtek I (P10) berkategori `laboratoryAndLecture`
  tetapi `function` = "Gedung Kuliah" dan fasilitas tanpa "Laboratorium";
  perlu dicek. Data tidak diubah.
- Galeri screenshot untuk tinjauan dari HP: artifact privat
  `https://claude.ai/artifact/JRZfRwoyqJCucgMS8GLEs4` (versi 3).
- Pencarian pindah ke peta (persetujuan pengguna, pola Google Maps): tab
  "Cari & Rute" dihapus, navbar tinggal Jelajah dan Trail. Search bar
  melayang di atas peta membuka `SearchRouteScreen` sebagai halaman (fokus
  otomatis); chip enam kategori fasilitas di bawahnya membuka halaman yang
  sama dengan filter aktif (F05/UI05 tetap terpenuhi, hanya bentuknya
  berubah dari tab menjadi overlay peta). "Tampilkan di peta" menutup
  halaman dan memfokuskan peta.
- Pill status lokasi dihapus (permintaan pengguna). Mengikuti Google Maps:
  titik biru dengan lingkaran akurasi dalam meter, titik abu-abu saat
  akurasi > `kTriggerMaxAccuracyM` (20 m, trigger tidak jalan), ikon tombol
  pusatkan mengikuti keadaan GPS, dan banner hanya muncul saat GPS mati,
  izin dicabut, atau di luar kampus. Atribusi OSM pindah ke tumpukan bawah
  dan dapat membungkus baris.
- Galeri HP versi 4 (17 layar, termasuk akurasi rendah).
- Tombol "Rute" (F06) disiapkan di layar yang sudah ada, atas permintaan
  pengguna: kartu POI di peta (Rute · Lihat · Lewati), kartu tujuan di
  pencarian (aksi utama), baris fasilitas (ikon rute), Detail Lokasi
  (tombol bawah), dan Trail ("Pilih rute" → "Rute"). Satu komponen
  `AgamRouteButton`; di build demo (tanpa graf rute) tombol redup dan
  mengetuknya menampilkan "Rute belum tersedia." tanpa memulai sesi. Di
  build produk, Rute dari peta membuka halaman pencarian dengan gedung
  terpilih (kartu rute UI06 yang ada). UI07 (Tiba & Rekomendasi) dan UI06
  penuh belum dibuat. Test baru menelusuri ketiga titik masuk; **377 test
  lulus**. Galeri versi 5.
- Verifikasi: analyze bersih, **376 test lulus**. File sementara (belum
  dihapus, jangan di-commit): `test/_preview/`, `tool/redesign_preview.dart`,
  `web/`.
## Current — Konten 10/10 POI dan perangkaian layanan LB asli, 23 November 2026 (LA)

- PB09: 10/10 POI approved di `pois.json` (rincian dan sumber media di implementationPhases PB09; video GKUB/GKUT opsional atas keputusan PM 23 November 2026, PRD §23).
- `lib/main.dart` (build demo `AGAM_INTERNAL_DEMO`) kini memakai layanan LB asli: `DeviceNavigationController` dengan `UnavailableCampusRouting` (graf jalur kampus belum ada), `RepositoryFacilityService`, `UnavailableRecommendationService`, `UnavailableTrailService`. Factory `navigation` di `createLaServices` menerima `SessionController`. Akun tetap fake di demo (tanpa Firebase, belum ada gerbang login); jalur non-demo tetap terblokir sampai UI10 FE di-merge, lalu memakai `createLaAccountServices`.
- Verifikasi: analyze bersih, 373 test lulus; APK demo release dibangun ulang setelah `flutter clean` (build sebelumnya gagal karena duplikat Finder `launch_background 2.xml` di `build/`), dipasang di emulator `agam_api34`: onboarding, peta, trigger Labtek V (kartu, foto), chip "Fasilitas belum tersedia", Trail 0/10 dengan tombol nonaktif, daftar Cari & Rute; tanpa crash. Bukan bukti perangkat fisik.
- Berikutnya: push `LA` dan PR ke `dev`; sambungkan akun asli setelah UI10; keystore rilis (PB19).

---
## Peta HD dan graf jalan kaki PB04/PB11 — 24 November 2026

- Paket LB memuat PMTiles native z12–18, rasterisasi lokal 512 px, bounds
  dari header PMTiles, serta style atap, dinding dan bayangan skematis.
  GeoPackage menghasilkan tile dan graf draf dengan 1.256 ruas dari layer
  `walk`. Dijkstra graf-saja dan deteksi tiba di titik akhir snap dapat
  dipilih oleh bootstrap demo. Rute standar memakai perilaku sebelumnya.
- Varian integrasi yang memasang kamera terbatas dan banner area sudah diuji
  di emulator. UI banner dan kamera adalah perubahan FE. Registrasi aset
  graf serta wiring sesi demo mengikuti integrasi LA. Graf draf menunggu
  survei akses dan pintu masuk sebelum dipakai untuk acceptance F06.
- Paket ini bertumpu pada `origin/LB` sebelumnya (`eb87816`). Progres
  worktree LB lama dipertahankan. Keputusan batas layanan produk terbaru
  ada di `dev` (`b76cdce`). PB04 dan PB11 tetap `in_progress`.
  Pemakaian AI material dicakup PB20.
- Pada basis LB, analyzer bersih, 378 tes Flutter dan 23 tes pipeline
  lulus. Audit sumber mencocokkan graf dengan layer `walk` pada tile z18.
  Audit APK memeriksa empat aset dari build demo terintegrasi yang sudah
  ada. Build Android basis LB dan uji lapangan belum dijalankan pada sesi ini.


## Current — PB10/PB11 Logic LB untuk push, 19 November 2026

Perubahan disiapkan di atas `origin/LB` `9bc83cd`. Checkout lama `LB` pada
`../AGAM-LB-PB04` berada di `a5ca3ea`, empat commit di depan remote dan memuat
riwayat onboarding FE serta WIP PB04 (`.agent/PRD.md` dan dua file `tools/tiles`).
WIP itu dipertahankan. Push ini hanya memuat implementasi Logic LB Sprint 3 dan
catatan status PB10/PB11.

- `PoiSearchService` mencari POI serta fasilitas approved, memakai kategori,
  alias Arab/Romawi dan urutan hasil deterministik.
- `CampusRoutingService` menghitung graf GeoJSON lokal memakai Dijkstra,
  snapping segmen terbatas, jarak, ETA dan arahan belokan.
  `DeviceNavigationController` mengikat rute ke sesi, memperbarui langkah,
  melakukan reroute melewati 25 m, dan tiba dalam 15 m. Geometri test berlabel
  sintetis dan tidak masuk aset produksi.
- `RepositoryFacilityService` hanya mengembalikan fasilitas approved.
  `UnavailableRecommendationService` dan `UnavailableTrailService` menjaga
  alur rekomendasi/Trail tetap tertutup sampai data resmi tersedia.
  `AccountVisitStore` menyimpan ID kunjungan lokal dalam ruang per UID.
- `OfflineMapTiles` menggunakan ulang raster aset yang sama dalam memori,
  dengan kunci path aset saja.

**Verifikasi:** Flutter 3.47.9, `pub get --enforce-lockfile`, format delapan
file tanpa perubahan, `git diff --check`, `flutter analyze --no-pub` bersih,
dan tujuh test routing, pencarian, serta penyimpanan UID lulus. Tidak ada data
graf kampus atau fasilitas produksi yang ditambahkan. Uji manual/perangkat dan
integrasi UI/LA belum tercakup.

**Menunggu:** tim menyediakan graf jalan hasil survei, batas layanan dan titik
pintu masuk. Tim konten menyediakan dataset fasilitas dengan metadata yang
terverifikasi. QA menguji rute di kampus sebelum acceptance F06.

**Integrasi ke dev (20 November 2026):** `dev` (sudah berisi PR #7 `LA` dan
PR #6 onboarding) di-merge ke `LB` agar PR `LB` → `dev` bebas konflik. Satu-
satunya konflik ada di file ini; ketiga entri 17–19 November dipertahankan
berurutan dari yang terbaru. Kode tidak berkonflik.

---

## Sebelumnya — Redesign onboarding UI01, 17 November 2026

**Permintaan:** pengguna meminta onboarding yang tidak lagi satu halaman
statis, dengan animasi dan alur yang lebih intuitif (referensi: onboarding
multi-halaman berlatar warna + lembar teks putih). Semua branch lokal
di-fast-forward lebih dulu, lalu dibuat branch `feat/onboarding-redesign`
dari `dev` @ `dded02b` atas instruksi eksplisit pengguna (pengecualian dari
model branch track). Login UI10 belum dibuat dan sengaja tidak disentuh.

**Perubahan:** `lib/ui/onboarding_screen.dart` ditulis ulang. Kontrak
`OnboardingScreen(permissions:, onAccessGranted:)` dan `app.dart` tidak
berubah.
- 4 halaman dalam satu layar UI01: Selamat Datang di AGAM (judul
  dipertahankan), Cerita gedung datang sendiri (replay prompt trigger memakai
  templat PRD §5 dan nama POI P06 asli), Lokasi Anda tetap di ponsel (A01),
  Izinkan akses untuk mulai.
- Aset nyata: `logo.png` menggantikan mark placeholder; foto P01 foto-1,
  P02 foto-2, P06 foto-1/foto-2. Tidak ada konten/ilustrasi karangan.
- Motion: warna latar, parallax visual/teks, indikator titik, dan tinggi lembar
  mengikuti `PageController.page` (1:1 dengan jari, bisa diinterupsi).
  Tombol panah bulat berubah menjadi CTA lebar di halaman terakhir. Animasi
  reveal per halaman sekali jalan (tanpa loop), getar ringan saat prompt
  contoh muncul. Reduced motion mematikan gerak dan reveal.
- "Lewati" hanya menuju halaman izin; Back sistem kembali ke halaman
  sebelumnya. Logika izin sama (perkiraan/ditolak permanen/GPS mati memakai
  dialog; notifikasi opsional; granted langsung masuk). Spinner CTA kini
  berhenti sebelum dialog modal tampil.
- Halaman izin menampilkan status lokasi/notifikasi/baterai secara langsung
  dan menyegarkannya saat kembali dari Pengaturan. Panduan optimasi baterai
  (PRD UI01) tampil sebagai baris "Atur" yang tidak memblokir masuk.
- Test: test onboarding lama diperbarui (CTA di halaman 4); ditambah test
  navigasi/back, lokasi ditolak permanen, dan baris baterai. Fake `_Permissions`
  di test kini meniru efek membuka pengaturan baterai.

**Verifikasi:** `fvm dart format`, `fvm flutter analyze --no-pub` bersih,
`fvm flutter test --no-pub` **293 test lulus**, `git diff --check` bersih.
Render diperiksa via golden sementara (390×844 dan 360×640, sudah dihapus).
**Tidak** dijalankan di emulator/perangkat (Mac ini tanpa AVD/perangkat).
Catatan: worktree baru wajib `fvm flutter pub get --enforce-lockfile`; tanpa
itu Flutter memakai `package_config` checkout induk dan test berjalan pada
source `dev`.

**Belum/berikutnya:** smoke APK di OPPO (getar, dialog izin nyata, halaman
baterai OEM); keputusan apakah onboarding perlu disimpan sebagai "sudah
dilihat" (sekarang tampil setiap cold start seperti sebelumnya). Pengguna
berencana mengubah desain FE keseluruhan nanti; sesi ini sengaja hanya
menyentuh onboarding. Pengguna menguji desain lewat preview web sementara
(entrypoint khusus + `FakePermissionService`, sudah dihapus; aplikasi penuh
tidak jalan di web), lalu mengotorisasi commit dan push ke
`origin/feat/onboarding-redesign`, lalu di-merge ke `dev` lewat PR #6
(`4ee0b7d`); branch remote sudah dihapus. Mac ini tidak punya Android
SDK/adb; APK untuk OPPO perlu dibangun di mesin lain dari `dev`.

---

## Sebelumnya — LA disamakan dengan dev, kontrak v1.1, PB21–PB22 bagian LA, 17 November 2026

**Branch:** atas instruksi pengguna, `LA` di-reset ke `dev` `dded02b` (PR #4 konten POI sudah di-merge). Dua commit lama disimpan di branch lokal `backup/LA-sebelum-reset-2026-11-17` (tidak di-push). Di atas `dev`:

- `f033e4d` fix PB08: `android/app/src/main/res/raw/keep.xml` menjaga ikon `audio_service_*` dari resource shrinking. Tanpa ini, APK **release** tidak menampilkan notifikasi media (`AudioService.setState` gagal: "You must specify an icon resource id to build a CustomAction"); APK debug tidak terdampak, sehingga verifikasi LB di OPPO (debug) tidak menangkapnya.
- `cefa34f` kontrak v1.1 (akun + log aktivitas) dipulihkan; `PoiViewRequests` dibuang karena `dev` sudah mengoper tombol Lihat lewat `AgamApp.poiViewRequests`. Empat test UI ikut diberi `auth`/`activity`.
- commit "feat: PB21 PB22 add Firebase account, per-account settings, and activity logging": implementasi asli PB21/PB22 bagian LA di `lib/logic/account/`, pengaturan per `uid`, `LocalTriggerNotifier.launchedFromNotification()`, dependency `firebase_auth`, `package_info_plus`, `device_info_plus` (versi dari `pub add`). Rincian di implementationPhases PB21/PB22.

**Pemeriksaan:** format bersih; `fvm flutter analyze` tanpa issue; `fvm flutter test` **363 lulus**; `fvm flutter build apk --release` berhasil (63,1 MB). Ketiga commit di `LA` lokal; belum di-push, belum ada PR.

**Berikutnya:** pengguna menentukan commit dan push; PR kontrak v1.1 ke `dev` butuh persetujuan FE + LB; FE membuat UI10 dan gerbang login, lalu `lib/main.dart` jalur non-demo memanggil `createLaAccountServices(la)` dan mengisi `AppServices.auth`/`activity` dari situ; LB menyimpan progres trail per `uid` dan mencatat `trailCompleted`/`featureUsed` pencarian; test rules emulator (butuh Firebase CLI + Java) dan uji perangkat terhadap `agam-9e704`. (Status terkini: ketiga commit sudah
di-merge ke `dev` lewat PR #7 `a84fb67`.)

---

## Delivery — Instalasi dan integrasi LB → dev, 16 November 2026

Pengguna mengotorisasi instalasi APK terbaru, commit/push ke `LB`, lalu merge
ke `dev`. Snapshot mencakup perbaikan lifecycle/audio, trial developer, dan area
kontak/kartu foreground dari tiga sesi terakhir; 290 test lulus, analyze bersih,
APK build dan audit tiga aset peta sudah lulus sebagaimana catatan berikut.
APK SHA-256 `a1a07f41bede049b636b7a7ffce31744182f1130f351acbb6c9ad7e6e7fc1e80`
berhasil dipasang pada OPPO CPH2739 melalui `adb install --no-streaming -r`
(`Success`), data aplikasi dipertahankan. USB sempat terputus/offline; setelah
restart/reconnect ADB dan pengguna mengizinkan debugging kembali, perangkat
berstatus device. Cold start `am force-stop` lalu `am start -W` sukses:
Status ok, LaunchState COLD, TotalTime 2405 ms; PID 31867 masih aktif setelah
pemeriksaan. Hash base.apk yang ditarik dari HP identik dengan host (222.219.488
byte). Crash buffer proses AGAM kosong dan penanda unhandled Flutter/Android
error 0. Tidak mengambil screenshot posisi, dump lokasi, atau logcat umum.
Ini bukan bukti smoke visual/playback/GPS atau acceptance lapangan.
Log instalasi di `D:\CodexRuntime\agam-android\contact-install-20261116.log`,
launch di `contact-launch-final-20261116.log`, salinan APK perangkat di
`contact-device-base-20261116.apk` pada direktori yang sama.

Publikasi menggunakan worktree detached dari `origin/LB`, karena checkout `LB`
lokal di `AGAM-LB-PB04` tertinggal satu commit dan memiliki WIP PRD/tools yang
harus dipertahankan. Tree `dev` dan `origin/LB` identik sebelum delivery.
Integrasi langsung sesuai instruksi pengguna, tanpa PR/review manusia baru;
tidak membuat rilis atau menyentuh main. Status PBI tetap 15 in_progress,
7 planned, 0 done; instalasi tidak memenuhi acceptance field test.

Source dipush ke `origin/LB` pada `b5c6938`, lalu di-merge dan dipush ke
`origin/dev` pada `096b940`; kedua remote diverifikasi lewat ls-remote. Tree
hasil merge identik dengan snapshot WIP teruji termasuk empat file baru.
Seluruh **290 test** lulus ulang pada hasil merge (log
`contact-merged-tests-20261116.log`). Bukti debugging ditambahkan dalam commit
dokumentasi lanjutan via LB → dev. Checkout LB lama/WIP PRD dan tools tetap
utuh; sinkronisasi checkout itu menunggu pemiliknya menangani WIP.

---

## Current — Area kontak 5 m dan kartu foreground, 16 November 2026

**Permintaan/keputusan:** titik trigger menjadi area kontak lingkaran radius
5 m. Radius pendekatan per POI tetap 15 m pada dataset; jarak dihitung ke
tepi area kontak, sehingga batas efektif masuk ≤20 m dari pusat dan keluar
histeresis >25 m. Tidak mengubah radius tiba navigasi 15 m, data/koordinat,
dwell 5 detik, akurasi 20 m, cooldown atau pengunci kunjungan/trial.

**Source:** GeofenceEngine menambahkan konstanta area kontak. TriggerResponder
menerima visibilitas lifecycle dari bootstrap: Explore/Trail saat resumed
memutar audio tanpa popup sistem, saat background tetap notifikasi/getar/audio.
Explore memilih kartu POI terdekat di antara trigger aktif, membuka tab Jelajah
dari tab lain, menunda kartu background sampai resume, dan menutupnya pada
exit/akhir sesi. Lewati/Back/Tutup menutup panel sampai kunjungan berikutnya.
Navigasi mempertahankan respons ringkas tanpa audio/kartu otomatis. Sesi tetap
wajib; force-stop aplikasi bukan kondisi background yang dijamin berfungsi.
Kontrak bersama, dependency, data konten dan jaringan/privasi tidak diubah.

**Lingkup:** engine, responder, bootstrap, app/Explore, regression geofence,
responder, demo Explore dan test baru foreground_trigger_test.dart. PRD §7/9/23
dan PB05/PB06/PB07 diselaraskan. WIP sesi sebelumnya dipertahankan di checkout
`dev`; tidak commit/push/merge/rilis atau install ke perangkat.

**Verifikasi:** seluruh 290 test Flutter lulus; setelah perapian close panel,
3 test widget terdampak lulus lagi. Analyze --no-pub tanpa issue; format 89
file/0 perubahan dan git diff --check lulus.
Batas masuk 20 m, luar 20,001 m, histeresis 25/25,001 m, pendekatan 18 m,
cooldown/trial, nearest saat event lebih jauh datang terakhir, tab dan lifecycle
teruji sintetis. Fixture acuan haversine 49,3895 m tetap memakai nilai independen,
radius pendekatan fixture menjadi 44/45 m agar batas efektifnya 49/50 m.
Dua assertion geometri lama gagal pada run awal, lalu fixture diperbarui sesuai
kontrak baru. Test lifecycle dipisah agar tidak memengaruhi fokus test UI lain.
Flutter analyze/build awal tidak mengeluarkan hasil dalam waktu wajar; proses
milik sesi dihentikan dan diulang dengan --suppress-analytics --no-version-check.
Log di `D:\CodexRuntime\agam-android\contact-*20261116.log`.

**APK:** build debug demo dengan AGAM_INTERNAL_DEMO=true sukses (Gradle
256,7 detik), audit tiga aset peta APK exit 0. APK
`build/app/outputs/flutter-apk/app-debug.apk`, 222219488 byte,
SHA-256 `a1a07f41bede049b636b7a7ffce31744182f1130f351acbb6c9ad7e6e7fc1e80`.
Warning KGP firebase_core/flutter_tts dan SDK XML existing tetap ada.
Tidak mengulang signature/manifest atau audit privasi runtime.

**Status:** PB05/PB06/PB07 tetap in_progress; total 15 in_progress/7 planned/0 done.
Belum uji GPS/audio/notifikasi fisik atau acceptance/kalibrasi lapangan. Penggunaan
AI material sesi ini dicakup PB20. Berikutnya: uji HP pada pendekatan area baru,
foreground dari tab lain, background/layar mati, re-entry/trial dan keluar >25 m.

---

## Current — Sakelar demo/trial developer, 16 November 2026

**Permintaan:** pastikan POI tidak terpicu lagi hanya karena 10 menit berlalu
saat pengguna diam; tambahkan satu kontrol Pengaturan untuk uji cooldown.
Pengunci `triggeredInside` sudah menghalangi pengulangan sampai ada sampel
keluar >radius + margin. Regresi normal dan trial membuktikan perilaku ini.

**Implementasi:** sakelar **Mode demo/trial** hanya tampil pada Pengaturan build
internal jika controller mengizinkan. Bootstrap menerima opt-in eksplisit dari
`AGAM_INTERNAL_DEMO`; default controller false, sakelar default mati. Kemampuan
LA opsional baru `PoiTrialControl` tidak mengubah `lib/contracts`. Mengaktifkan
trial mereset cooldown engine dan melewati jedanya selama aktif; pengunci
kunjungan, dwell 5 detik, histeresis/akurasi/area/sesi tetap berlaku. Tetap harus
keluar lalu masuk kembali. Menonaktifkan kembali memeriksa cooldown normal
terhadap trigger terakhir; trial hanya di memori, tidak disimpan antar-restart.
Tidak mengubah data POI, konten, progres atau menambah request/log lokasi.

**File:** engine, DeviceSessionController, `poi_trial_control.dart`, bootstrap,
main, app/ProfilePreviewScreen, unit engine/sesi, regression demo frontend dan
Explore dengan controller asli/GPS simulasi. PRD §9.2/§23 dan PB05/PB16 mencatat
alat uji ini. Semua perubahan sesi perbaikan trigger sebelumnya dipertahankan;
tetap di `dev`, tanpa commit/push/merge/rilis.

**Verifikasi:** seluruh **286 test PASS**: mode normal/trial tidak mengulang
saat tetap di area >10 menit; re-entry trial tanpa tunggu 10 menit; kembali
normal setelah dimatikan; controller produk menolak aktivasi; toggle sebelum
dataset dimuat; UI tersembunyi di luar demo; sakelar Pengaturan → controller
asli → exit/re-entry cepat terpicu. Log di
`D:\CodexRuntime\agam-android\poi-trial-*-20261116.log`. Analyze --no-pub tanpa
issue; format 88 file/0 perubahan dan git diff --check lulus. Build debug demo
sukses (Gradle 56,8 detik), audit tiga aset peta APK exit 0; warning KGP existing
tetap. APK `build/app/outputs/flutter-apk/app-debug.apk`, 222.217.320 byte,
SHA-256 `6e75ff7effce6b6f417435a7cf158f80bf0003c05c3a03e0adfde31a3de2afba`.
Belum install/retest GPS/audio Android/field, signature/manifest terbaru atau
audit privasi runtime; AI material PB20.
Status tetap 15 in_progress/7 planned/0 done, termasuk PB05/PB06/PB08/PB16.

**Berikutnya:** pasang APK terbaru dan uji sakelar di HP. Trial mati: diam
>10 menit tidak mengulang; exit/re-entry tetap mengikuti cooldown. Trial aktif:
exit >20 m → re-entry ≤15 m/dwell ≥5 detik memicu tanpa menunggu 10 menit.
Matikan untuk kembali uji produk normal; restart aplikasi mengembalikan mati.

---

## Current — Perbaikan lifecycle trigger POI/audio, 16 November 2026

**Laporan pengguna:** trigger awal muncul, tetapi kartu terlihat tetap aktif
setelah meninggalkan gedung; saat kembali suara tidak muncul dan kontrol audio
terasa terkunci. Audit source memastikan engine sudah melepas pengunci setelah
jarak > radius + 5 m, namun belum ada propagasi keluar ke UI/notifikasi. Diam
saat kembali sebelum cooldown 10 menit habis merupakan perilaku PRD, bukan
bukti pengunci permanen. Kondisi HP yang dilaporkan belum direproduksi langsung.

**Perbaikan:** kemampuan opsional LA `PoiTriggerLifecycle.deactivatedPois`
diimplementasikan DeviceSessionController dari snapshot ID aktif engine.
Keluar histeresis, keluar kampus, penghapusan/perubahan geometri dataset dan
akhir sesi melepas trigger; pembacaan buruk tidak membuktikan keluar.
Explore menutup panel yang dibuka trigger tersebut; panel pilihan manual tetap
tersedia. Responder menghapus notifikasi dan menghentikan prompt terkait;
narasi yang sedang didengarkan dipertahankan. Revisi per POI membatalkan prompt
terlambat setelah Dengarkan/Lihat/Lewati/keluar. Aksi async juga dibatalkan saat
sesi berakhir. Kontrak bersama/radius/dwell/cooldown tidak diubah.

**Audio:** intent klip dipancarkan sebelum lookup repository agar prompt pending
dapat dihentikan. Stop lama tidak boleh menghapus state klip baru. Handler
menjeda sebelum load, memuat dari nol, dan seek ke nol ketika tombol play media
ditekan setelah completed; guard mencegah load/restart lama menimpa intent baru.
Perilaku `just_audio` 0.10.6 diperiksa pada source cache: `playing` dapat tetap
true setelah completed dan saat sumber diganti. Tidak menambah dependency.

**File:** engine, DeviceSessionController, lifecycle opsional baru,
TriggerResponder, DeviceAudioService, AgamAudioHandler, Explore serta regression
unit/widget terkait (termasuk test baru handler dengan player sintetis).
Checkout awal `dev` bersih; tetap di checkout itu, tanpa commit/push/merge/rilis.
Tidak mengubah data POI/aset/approval, lib/contracts, atau mengirim posisi.

**Verifikasi:** Flutter 3.47.9: analyze --no-pub tanpa issue; seluruh **282 test
PASS**. Uji mencakup exit/re-entry/histeresis/akurasi/cooldown dan panel nyata
dengan GPS simulasi, prompt tertunda setelah aksi/exit, pending lookup/stop,
completed → play, load lama dan pause saat restart. Log test/analyze/build di
`D:\CodexRuntime\agam-android\poi-trigger-*-20261116.log`. Format 87 file/0
perubahan dan git diff --check lulus. Build debug demo
`--dart-define=AGAM_INTERNAL_DEMO=true` sukses (Gradle 237,3 detik), audit tiga
aset peta APK exit 0. Upaya build pertama gagal karena JAVA_HOME mengarah ke
folder yang tidak ada; retry memakai JDK 21.0.12 existing. Warning KGP existing
dan SDK XML tetap ada. APK `build/app/outputs/flutter-apk/app-debug.apk`,
222.215.344 byte, SHA-256
`99351444528311dcc1d9f8aebc009bbceb0dab7a05f3a6adb33c3c93fcf9a1f7`.
Belum install/uji Android/field, signature/manifest terbaru atau audit privasi
runtime. Penggunaan AI material sesi ini dicakup PB20.

**Status/berikutnya:** PB05/PB06/PB08 tetap in_progress, total PBI tetap
15 in_progress/7 planned/0 done. Uji APK di HP: trigger setelah dwell 5 detik;
keluar >20 m menutup trigger/prompt; masuk sebelum 10 menit tetap diam; masuk
setelah cooldown dan dwell memicu kembali; Dengarkan/jeda/lanjut/ulang selesai
serta lock screen. Kalibrasi dan acceptance fisik tetap belum selesai.

---

## Delivery Git — 16 November 2026

Pengguna menginstruksikan push hasil demo/interaksi ke `LB`, kemudian merge ke
`dev`. Snapshot source yang sudah lulus 271 test, analyze, build dan audit APK
dipublikasikan dengan parent `origin/LB`, lalu diintegrasikan ke `dev` tanpa
perubahan source tambahan. Perubahan lokal pada worktree `AGAM-LB-PB04`
(`.agent/PRD.md` dan dua berkas tools/tiles) dipertahankan; checkout lokal `LB`
di sana perlu disinkronkan setelah pemiliknya menangani WIP. Status PBI tetap
15 in_progress, 7 planned, 0 done; CI remote diperiksa terpisah dari bukti lokal.

## Current — Audit interaksi UI dan motion, 16 November 2026

**APK:** panel POI native dapat ditarik/tap handle, expand/collapse, scroll dan
scrollbar interaktif (controller sama, extent 35/65/90%); Back menutup panel,
tetap menempel navigasi. Enter/exit 220/160 ms, tab fade-through 180 ms menjaga
state, kamera 220 ms dapat diinterupsi, press feedback 140 ms. Reduced motion
disediakan. Marker posisi tidak lagi menutup klik POI saat bertumpuk.

Aksi kartu Lihat/Lewati/Dengarkan memakai TriggerResponder yang sama dengan
notifikasi Android. Lihat dismiss notifikasi sebelum detail; Lewati dismiss dan
stop prompt cocok; narasi kartu pause/resume. Guard mencegah respons pending
muncul setelah Akhiri. Detail: play/pause/resume/replay/stop/seek/±10 detik,
auto-play ke store Pengaturan. Backend menolak media belum approved dan menjaga
intent pause saat load/seek/replay async. Filter modal/clear pencarian nyata;
Pengaturan membuka izin/notifikasi/baterai OS. Onboarding granted langsung masuk.
Trail/routing/fasilitas/akun tanpa dependency tetap nonaktif; UI tanpa note sistem.

**File:** UI app/Explore/detail/search/Trail/profil/onboarding/nav/offline map;
widget baru `agam_motion.dart`/`agam_poi_panel.dart`; LA audio capability
`audio_seek_control.dart`/implementasi, TriggerResponder/main DI; pubspec/lock;
test audio/responder/helper dan UI. WIP lain dipertahankan. Tidak mengubah
lib/contracts/aset/threshold/default login. Tidak commit/push/merge/rilis.

**Eksternal:** Flutter animations 3.0.0 (API pub.dev dan cache diperiksa), transitif
material_ui 1.11.0, cupertino_ui 1.1.6, flutter_localizations SDK. Pure Dart/UI,
tanpa SDK lokasi/telemetri atau request runtime. Versi existing tidak di-upgrade.
Skill animate/emil-design-eng dipakai untuk feedback/spatial consistency.

**Verifikasi:** format 85 file/0 perubahan, analyze tanpa issue, **271 test PASS**.
Gesture/scroll offset, overlap marker, Back, callback notifikasi, transport/seek/
autoplay, filter/clear, pengaturan OS, onboarding dan reduced motion diuji.
Unit async intent/race serta approval guard lulus. Bug overlap ditemukan uji,
tidak dibungkam; pratinjau widget diperiksa visual. Belum manual gesture/audio/
lock screen native, profil performa atau field. Pipeline tidak diulang (21 PASS
sebelumnya). Matriks cakupan ada di rencana demo §6; AI material PB20.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, **222.210.865 byte**,
SHA-256 `9675dcf66852695bb7316642997d6f5b105ffefe0c7de8226fd1eaf2d5cf6c9e`.
Build demo final 16,2 detik; audit tiga aset APK exit 0/signature v2 valid,
manifest tanpa ACCESS_BACKGROUND_LOCATION. Warning KGP existing tetap. Source
`dev` `046b646` + WIP, flag true; snapshot 152 input lib/test/aset/Android/CI/
pubspec identik pascabuild. Install streaming ditolak verifikasi Android;
retry standar `--no-streaming -r` sukses, data dipertahankan, pengguna mengonfirmasi
izin di HP. OPPO CPH2739 launch COLD/ok 3581 ms, PID aktif dan hash base.apk cocok.
Log/snapshot di `D:\CodexRuntime\agam-android\interaction-*20261116*`.

**Berikutnya:** smoke manual gesture/motion/audio/notifikasi APK ini; field,
kalibrasi dan privasi fisik Labtek V saat tersedia. Tidak mengambil koordinat/
lintasan/screenshot posisi HP. CI remote/emulator native terbaru belum diuji.
Target demo belum lengkap, rencana/pointer aktif. PBI tetap 15 in_progress,
7 planned, 0 done.

---

## Sebelumnya — Panel POI menempel navigasi dan UI bersih, 16 November 2026

**Perubahan APK:** panel POI full-width, bottom 0 dan menempel langsung ke bar
navigasi utama. Footer bawah dihapus; kredit OSM/ODbL/OpenMapTiles 9 px bertautan
berada di atas kanvas, Mode uji 8 px statis di header. Kontrol kanan tetap sama,
digeser 20 px turun untuk memberi tempat kredit. Note verifikasi konten,
penjelasan demo, label placeholder tambahan dan notice teknis di layar POI/
pencarian/Trail/profil dihapus sesuai instruksi PM; PRD mencatat pengecualian
presentasi ini. Data belum approved tetap tersembunyi/keadaan kosong ringkas.
Trail/rute/logout tanpa layanan nonaktif; diagram sintetis Trail demo disembunyikan.
Tidak mengubah metadata, kontrak, dependency, threshold, default login atau PBI.

**File:** app, Explore, detail POI, search, Trail, profil, offline map dan dua
regression UI existing; docs progres/rencana mengikuti APK. WIP lainnya utuh.
Regresi 320/430 px membuktikan batas bawah panel = batas atas navigasi, kredit/
mode di atas peta, note hilang, dan Trail nonaktif tidak mengganti Explore.
Test konten unapproved tetap membuktikan media tersembunyi/keadaan kosong;
finder/scroll awal yang gagal sudah diperbaiki. Pratinjau widget diperiksa visual.

**Verifikasi:** format 81 file/0 perubahan, analyze tanpa issue, **257 test PASS**.
Build demo debug 16,8 detik sukses, audit tiga aset APK exit 0, signature v2 valid,
manifest tanpa ACCESS_BACKGROUND_LOCATION. Warning KGP existing tetap. Pipeline,
CI remote, emulator native, field dan audit trafik/penyimpanan HP tidak diulang.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, **213.040.945 byte**,
SHA-256 `0d5ac9145efbb98dd8243ff916cac8716750cffb717ab2f1588ec6cacfc91f40`.
Source `dev` `046b646` + WIP, AGAM_INTERNAL_DEMO=true. Install -r OPPO CPH2739
Success, data dipertahankan; launch COLD/ok 2770 ms, PID aktif. Bukan konfirmasi
smoke manual visual/playback/GPS fisik. Hash base.apk perangkat telah diperiksa dan identik dengan host. Log/salinan APK di
`D:\CodexRuntime\agam-android\clean-ui-*20261116*`.

**Berikutnya:** periksa hasil visual/manual di HP, playback dan offline; field
Labtek V/privasi saat tersedia. Tidak mengambil koordinat/lintasan/screenshot
posisi HP. Rencana/pointer tetap aktif karena target demo penuh belum tercapai.
Tidak commit/push/merge/rilis. AI material PB20; total PBI tetap 15 in_progress,
7 planned, 0 done.

---

## Sebelumnya — APK fungsional dan watermark kecil, 16 November 2026

**Mandat:** penyesuaian harus diterapkan ke APK tanpa mengerjakan seluruh PBI;
watermark/placeholder dipisah dari peta dan area UI asli, sekecil mungkin.

**Source:** kontrol kanan FE sekarang nyata: reset orientasi utara, pusat fix
lokasi (pesan izin/GPS bila kosong), tampil/sembunyikan marker POI. Tidak memakai
sensor kompas baru. Pencarian demo menampilkan kartu PMTiles nyata; Tampilkan
di peta memusatkan/menyorot POI di Jelajah tanpa memulai sesi atau menampilkan
rute dummy. Detail/audio tetap layanan existing. Header FE kembali bebas chip;
Mode uji · info 8 px menjadi footer di atas nav. Kredit lengkap/bertautan
OSM/ODbL/OpenMapTiles 9 px berada di luar kanvas. Overlay Pusatkan duplikat
hilang. Tidak mengubah data/approval, kontrak, radius, layanan lokasi, dependency
atau default login; routing/Trail/fasilitas/akun tetap menunggu dependency.

**File sesi:** `lib/ui/app.dart`, `explore_map_screen.dart`,
`search_route_screen.dart`, `widgets/offline_campus_map.dart`, regression existing
`test/ui/demo_explore_test.dart` dan `demo_frontend_test.dart`. WIP lain tetap.
Dokumen progres/rencana hanya mengikuti perubahan APK. PBI tetap 15 in_progress,
7 planned, 0 done; tidak ada klaim completion baru. Skill redesign-existing-projects
untuk perbaikan terarah; penggunaan AI material dicakup PB20.

**Verifikasi:** format 81 file/0 perubahan; analyze tanpa issue; **257 test
Flutter PASS**. Regresi kamera/utara/lapisan/fix, pencarian P02 → peta P02,
footer di luar kanvas pada 320/430 px dan isolasi sesi lulus; pratinjau widget
diperiksa visual. Build demo debug sukses 31,4 detik; audit tiga aset APK exit 0,
signature v2 valid; manifest tanpa ACCESS_BACKGROUND_LOCATION. Peringatan KGP
firebase_core/flutter_tts tetap. Pipeline tidak diubah/diulang (21 PASS sesi
sebelumnya). Run awal satu test UI gagal akibat scroll belum selesai; test
menunggu scroll dan seluruh assertion tetap dipertahankan.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, **213.046.126 byte**,
SHA-256 `d54d2b514941a745b28861241e65266eda4b2eda209861b458a287312b24b515`.
Source `dev` `046b646` + WIP; flag AGAM_INTERNAL_DEMO=true, bukan commit bersih.
`adb install -r` OPPO CPH2739 sukses (data dipertahankan), `am start -W`
`Status: ok`, `LaunchState: COLD`, 3212 ms; PID aktif setelah pemeriksaan dan
hash base.apk perangkat identik. Ini bukti command cold start, bukan seluruh
UI/playback/manual/GPS/privasi Android. Log dan salinan APK perangkat di
`D:\CodexRuntime\agam-android\functional-*20261116*`.

**Sisa:** smoke manual kontrol/pencarian/detail/playback di OPPO dan offline APK
baru; trigger/kalibrasi/audit privasi fisik Labtek V ketika tersedia. Tidak
mengambil koordinat/lintasan/screenshot posisi HP. Target demo penuh belum
tercapai, rencana/pointer tetap aktif. Tidak commit/push/merge/rilis.

---

## Sebelumnya — Pemetaan demo dan rekap total, 16 November 2026

**Hasil:** pemetaan Sprint 1–2 pada [rencana demo](demo-apk-temporary-plan.md)
ditindaklanjuti dan status keseluruhan diselaraskan. Rekap 22 PBI kini
**15 `in_progress`, 7 `planned`, 0 `done`**. PB17 dikoreksi menjadi
`in_progress` karena verifikasi offline parsial sudah dijalankan; bukan
completion offline/navigasi. Ringkasan sprint, sisa PB01/PB02/PB04/PB06/PB07,
inventaris PB08/PB09 dan dependency diperbaiki pada implementation phases.

**Perangkat/APK:** OPPO CPH2739 terhubung; `base.apk` ditarik ke luar repo,
hash identik dengan host: `8ee36167b203d3cd91f165278b85005d1db575840c52c69e88346e3b9098b2f1`,
213.041.274 byte. `am start -W` sukses (`Status: ok`, `LaunchState: HOT`),
activity existing dibawa ke depan, PID tersedia. Ini bukan bukti cold start,
smoke visual atau playback. Pertanyaan manual mendapat jawaban “tidak” tanpa
hasil UI/playback; akses field Labtek V tetap tidak tersedia. Tidak mengambil
koordinat/lintasan/screenshot posisi atau dump lokasi/logcat umum HP.

**Konten:** audit JSON/aset mencatat 30 audio, enam foto P01/P02/P06, tanpa
video; P01/P02 approved/non-placeholder pada source, P03–P10 placeholder/
unapproved. PRD §22 kini mencatat keduanya sebagai fakta metadata; approval
P02 sebagai konten final tetap perlu rekonsiliasi pemilik konten/PM. Tidak
mengubah konten/metadata atau memberi approval baru. Fasilitas kosong,
entrances kosong dan urutan trail null tetap menjadi dependency.

**Verifikasi ulang:** format 81 file/0 perubahan, analyze tanpa issue,
**257 test Flutter PASS**, **21 test pipeline PASS**; audit tiga aset APK exit 0,
signature v2 valid, manifest tanpa `ACCESS_BACKGROUND_LOCATION`. `INTERNET`
ada; audit statis bukan bukti privasi runtime. Rekap 22 status PBI dan tautan
file lokal empat dokumen diperiksa otomatis; `git diff --check` lulus.
Log test dan salinan APK perangkat
di `D:\CodexRuntime\agam-android\mapping-*-20261116.*`. Build tidak diulang
karena source/aset tidak berubah. CI remote, cold start, smoke visual/playback,
trafik/penyimpanan HP dan field belum dijalankan/dikonfirmasi.

**Lingkup:** hanya `.agent/demo-apk-temporary-plan.md`, `implementationPhases.md`,
`PRD.md`, dan handoff ini. Semua WIP source `dev` `046b646` dipertahankan.
Tidak mengubah branch, kode, aset, kontrak, dependency, threshold atau default
login; tidak commit/push/merge/rilis. Penggunaan AI material dicakup PB20.

**Berikutnya:** smoke UI/playback P01 dan mulai/akhiri Explore pada HP;
ulang offline APK terbaru bila memungkinkan; field trigger/kalibrasi/privasi
Labtek V ketika tersedia. Pemilik konten/PM merekonsiliasi P02 dan kelengkapan/
hak/durasi/video. Target demo belum lengkap, rencana/pointer tetap aktif.

---

## Sebelumnya — Copy demo dan baseline kontrol kanan FE, 16 November 2026

**Hasil:** MaterialBanner demo diganti chip Mode uji di header tanpa menambah
baris peta; ketukan membuka keterangan skip login/cakupan engineering. Kredit
peta tetap lengkap/bertautan ke OSM contributors (ODbL) dan OpenMapTiles dalam
baris kecil. Kontrol kanan disalin langsung dari `origin/FE` `5db4dd4`, dengan
posisi/ukuran/gap/warna/ikon/bentuk/elevation yang sama. Tooltip sesi memberi
label Mulai Explore/Akhiri sesi; kompas/lapisan tetap PRATINJAU. Copy akun/rute/
pengaturan diringkas. Judul onboarding Selamat Datang di AGAM tetap sama.

**Lingkup:** `lib/ui/app.dart`, `explore_map_screen.dart`,
`orientation_trail_screen.dart`, `profile_preview_screen.dart`,
`search_route_screen.dart`, widget header/kredit peta, serta regression existing
`test/ui/demo_explore_test.dart`. WIP awal dicadangkan di luar repo dan diperiksa;
file di luar lingkup identik. Tidak mengubah layanan, mode, flag/default login,
POI, kontrak, radius, dependency atau lisensi. Tidak commit/push/merge/rilis.

**Verifikasi:** format 81 file/0 perubahan, analyzer tanpa issue, **257 test
Flutter PASS**. Regresi tambahan menguji geometri kontrol sesuai FE, info chip,
kredit satu baris pada lebar 430/320 px; dua test Explore lalu enam test UI diulang
pada source final dan lulus. Pratinjau widget diperiksa visual. Build demo final
29,4 detik berhasil, audit tiga aset APK exit 0, `git diff --check` lulus.
Peringatan KGP plugin tetap ada; build awal juga memberi peringatan SDK XML.
Pipeline tidak diubah/diulang. ADB menemukan satu perangkat; install/launch,
runtime Android, signature/manifest/jaringan dan field test terbaru tidak diuji.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, **213.041.274 byte**,
SHA-256 `8ee36167b203d3cd91f165278b85005d1db575840c52c69e88346e3b9098b2f1`.
Input `dev` `046b646` + WIP, `AGAM_INTERNAL_DEMO=true`; bukan commit bersih.
Log `D:\CodexRuntime\agam-android\copy-ui-*20261116*`; snapshot awal
`copy-ui-before-20261116` pada direktori luar repo yang sama.

**Berikutnya:** smoke APK terbaru di Android dan lanjutkan uji fisik/privasi
Labtek V ketika tersedia. [Rencana demo](demo-apk-temporary-plan.md) tetap aktif;
kriteria demo penuh belum tercapai dan status PBI tidak dinaikkan. Catatan
PB04 diperbarui; keputusan produk tetap. Penggunaan AI material dicakup PB20.

---

## Sebelumnya — Seluruh frontend FE pada demo integrasi, 16 November 2026

**Permintaan:** periksa branch FE dan pertahankan seluruh frontend/style dummy,
sambil menyambungkan fitur yang sudah tersedia pada progres demo sementara.
`origin/FE` `5db4dd4` terbukti ancestor HEAD `dev` `046b646`; tidak diperlukan
merge Git. Working tree awal berisi WIP yang dipertahankan. Tidak commit/push,
merge, switch branch atau mengubah kontrak/dependency/data POI.

**Implementasi:** `lib/ui/app.dart` menampilkan Jelajah, Trail, Cari & Rute,
Pengaturan dan ikon profil yang berfungsi. Font, warna, kartu dan ilustrasi FE
dipertahankan. Peta/lokasi/Explore/geofence/notifikasi/detail/audio dan pencarian
repository tetap memakai layanan nyata. `search_route_screen.dart` mempertahankan
kartu ilustrasi rute dan kategori fasilitas berlabel PRATINJAU/PLACEHOLDER;
Lihat Detail POI membuka data/audio repository. Aksi navigasi/tutup rute dummy
tidak memulai/mengakhiri sesi nyata. Pencarian memakai nomor request agar hasil
query/filter lama tidak menimpa yang baru.

`orientation_trail_screen.dart` mempertahankan UI progres/lencana/list/ilustrasi,
tetapi pada demo tidak membaca TrailService/NavigationController fake: daftar
memakai POI repository dalam urutan contoh sintetis, progres kosong dan aksi
penjelasan dependency. Tidak membuat check-in/trail palsu. Profil tetap pratinjau
berlabel tanpa identitas pribadi contoh; auto-play dan Akhiri memakai layanan LA.
Sheet Explore memuat foto aset bila metadata approved dan menjaga media/konten
belum approved. Rencana demo dan pengecualian PRD diselaraskan dengan instruksi PM
untuk menampilkan dummy berlabel. PB16 mulai `in_progress` karena UI09 pengaturan
terintegrasi, tetapi fasilitas/acceptance belum selesai; PBI lain tidak dinaikkan.

**Verifikasi aktual:** format 81 file/0 perubahan, `flutter analyze --no-pub`
tanpa issue, **257 test Flutter lulus**. Tiga regression widget baru memeriksa
isolasi Trail/navigation lewat layanan yang melempar saat diakses, alias ke
detail, serta auto-play/Akhiri; test Explore existing juga memeriksa empat tab,
ikon profil, dwell/trigger/detail dan lifecycle. Pratinjau widget diperiksa
visual; bukan screenshot Android/GPS nyata. Build debug demo sukses (34,4 detik),
audit tiga aset APK exit 0, `git diff --check` lulus. Peringatan Built-in Kotlin
firebase_core/flutter_tts tetap ada. Pipeline Python tidak diulang karena tidak
diubah (21 PASS sebelumnya). ADB daftar kosong: emulator/HP/runtime Android,
signature/manifest dan audit jaringan terbaru tidak dijalankan pada sesi ini.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, **213.038.726 byte**,
SHA-256 `9e415636b54eca36de0a63445f51d742d80baa3660303bed05f363fd2fd1425d`.
Dibangun dari `046b646` + WIP, flag `AGAM_INTERNAL_DEMO=true`; APK/evidence
simulasi native sebelumnya tidak memverifikasi perubahan frontend terbaru.
Log tes/build/audit: `D:\CodexRuntime\agam-android\frontend-20261116-*`.
Penggunaan AI material untuk integrasi dan regression dicakup PB20.

**Berikutnya:** install APK terbaru dan smoke seluruh tab di Android; ulangi
skenario fisik Labtek V/akhir sesi/privasi saat perangkat/lokasi tersedia.
Routing/trail/fasilitas/akun menunggu dependency resminya. Target demo penuh belum
selesai, rencana/pointer tetap dipertahankan. Login default produk tetap wajib.

---

## Sebelumnya — Integrasi FE nyata ke shell demo sementara, 16 November 2026

**Permintaan:** sambungkan tampilan FE yang telah di-merge ke fungsi nyata yang
tersedia, khusus jalur sementara `AGAM_INTERNAL_DEMO=true`, dan pertahankan
perilaku source lain.

**Source:** `lib/ui/app.dart` kini menampilkan shell demo FE dua tab, Jelajah dan
Cari POI. UI01 izin nyata, Explore/peta/lokasi/geofence/notifikasi/detail/audio
yang telah ada tetap digunakan. `lib/logic/search/poi_search_service.dart`
menambahkan `PoiSearchService` yang mengambil POI langsung dari repository,
menormalkan alias Arab/Romawi, dan mengembalikan hasil POI nyata. UI05 demo
memakai service itu; daftar/hasil membuka UI04 dan audio LA. Pencarian melalui
dataset bundled-only tetap offline. Tidak mengambil sumber fake POI untuk alur
tersebut.

**Batas jujur:** tab/aksi Trail, fasilitas, rute, dan profil/akun tidak
ditampilkan karena urutan trail/data fasilitas/graf/akun belum merupakan
service nyata atau masih TBD. CTA navigasi UI04 nonaktif. Fitur/fakes yang belum
dipakai shell masih menjadi dependency wajib `AppServices`, tetapi tidak
ditampilkan/dijalankan pada alur demo. Shell mode selain demo tetap memakai susunan
FE sebelumnya. Tidak ada kontrak, radius, konten, atau aturan privasi yang
diubah; PRD tidak diubah karena ini perubahan internal-demo saja.

**Verifikasi:** hanya `dart format` pada 5 file Dart (0 file berubah oleh formatter).
Tidak menjalankan test, analyzer, build atau runtime; APK dan evidence emulator
16 November sebelumnya dibuat sebelum perubahan shell ini. Jangan menyamakan
hasil APK lama itu dengan source baru. Belum ada commit/push.

**Berikutnya:** jalankan analyzer/test/build dan smoke UI pada emulator bila
pengguna meminta verifikasi; setelah build, ulangi audit APK. Tetap uji fisik
Labtek V untuk menyelesaikan target demo penuh.

---

## Sebelumnya — Verifikasi demo APK source gabungan, 16 November 2026

**Mandat/status:** melanjutkan rencana demo hingga tercapai. Pengguna mengonfirmasi
**belum dapat melakukan uji fisik**; ADB hanya emulator, tidak ada HP. Demo belum
selesai penuh: GPS nyata berjalan/trigger P01, install APK terbaru pada HP dan
audit jaringan fisik masih tertunda. Rencana sementara/pointer tetap dipertahankan.

**Source/perbaikan:** awal `dev` bersih pada `046b64629c14eea7550b62c28d8c2f0d2bd5b801`.
`main.dart` dan `la_bootstrap.dart` kini mengisolasi demo ke JSON bawaan + cache
memori tanpa refresh Firestore/inisialisasi Firebase dari Dart; jalur layanan
produk default tetap ada. Plugin native Firebase tetap dibundel. Test bootstrap
baru di `test/logic/demo_bootstrap_test.dart`; test UI demo diperbarui untuk media
P01 yang kini approved serta regression fixture placeholder terpisah. Tidak
mengubah konten/metadata, dependency, kontrak atau threshold. Tidak commit/push,
merge, rilis, atau memindahkan branch.

**Verifikasi:** format 79 file; analyze tanpa issue; **254 test Flutter / 21 test
pipeline lulus**. Kegagalan awal test PLACEHOLDER akibat konten baru ditangani
dengan assertion foto repository + test placeholder terpisah. Build demo debug
125,4 detik berhasil memakai toolchain existing. Audit tiga aset APK, signature
v2 dan manifest lulus; INTERNET ada, ACCESS_BACKGROUND_LOCATION tidak ada.

**APK terbaru:** `build/app/outputs/flutter-apk/app-debug.apk`, `site.agam`
1.0.0+1, **185.500.754 byte**, SHA-256
`d25348dcff1a6808e6be55c80c5ab6ee39f1085911e65bea47819278f8a926d1`.
APK berasal dari HEAD di atas **+ perubahan lokal**, bukan commit bersih.
Hash APK emulator cocok; snapshot 156 file source/test/aset/konfigurasi identik
setelah uji. APK lama/evidence HP 15 November bukan verifikasi APK terbaru.

**Emulator API 36 (SIMULASI):** install/launch, posisi ±5 m → Explore → dwell
P01 → UI03 → UI04 Labtek V dengan foto; cold start mode pesawat → peta/atribusi/
marker/posisi; Home + P02 → notifikasi native Lihat → kartu Labtek VI lulus.
Akhiri + Home: request lokasi 0/service lokasi tipe 0x8 tidak ada; service media
0x2 masih ada setelah prompt, bukan klaim semua service hilang. Counter OUTPUT
UID 10216 online IPv4/IPv6 tetap 0 paket/0 byte; snapshot penyimpanan terbatas
tidak mendeteksi field posisi. Database Firestore existing identik; hanya cache
prompt P02 aset + profileInstalled berubah pada pembanding online→final. Bukan
audit OS/GMS/HP atau baseline instalasi bersih. Rule counter dibersihkan dan
emulator dihentikan. Artefak di `D:\CodexRuntime\agam-android\demo-20261116-*`
dan `simulation-*`; rincian command/evidence pada rencana demo. Peringatan
Built-in Kotlin firebase_core/flutter_tts masih ada. AI material dicakup PB20.

**Berikutnya:** ketika HP/lokasi tersedia, install `-r` APK hash di atas dan uji
berjalan/trigger P01 serta privasi fisik, tanpa merekam posisi pengguna. PBI tetap
`in_progress`. Review/integrasi formal dan CI remote belum dijalankan. Jangan
menghapus rencana sampai seluruh kriteria demo terbukti.

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

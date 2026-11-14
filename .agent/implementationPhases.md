# Implementation Phases — AGAM v1

| Atribut | Nilai |
| --- | --- |
| Status dokumen | Aktif; status per PBI dicatat di bagian masing-masing |
| Tanggal | 2 November 2026, diperbarui 14 November 2026 |
| Kontrak produk | `.agent/PRD.md`; aturan kerja di `.agent/rules.md` |
| Model kerja | 5 sprint × 1 minggu (Week 10–14), deliverable final Week 15 |
| Pembagian kerja | Tiga track paralel: 1 developer frontend, 2 developer logic aplikasi (lihat §2) |
| Desain layar | UI01–UI09 sudah selesai; frontend tinggal mengimplementasikan. UI10 Daftar & Login (ditambahkan 14 November 2026) belum didesain |
| Backlog | PB01–PB20 dari PRD resmi, ditambah PB21–PB22 (akun, keputusan PM 6 dan 14 November 2026); ID tidak boleh diubah atau dinomori ulang |
| Current focus | Track LA: seluruh logic LA Sprint 1–3 ada di source dan lulus unit test (10 November 2026), belum terintegrasi dengan UI/LB dan belum diuji di perangkat fisik. PB01, PB02, PB03, PB05, PB06, PB08, PB09, PB12 `in_progress`; Firestore (PB03) `blocked`; PB04 `in_progress` (pipeline tile LB-01 selesai, belum terintegrasi). 14 November 2026: PB21 (akun dan login wajib) dan PB22 (log aktivitas) ditambahkan ke Sprint 3, `planned`, menunggu project Firebase dan kontrak v1.1 |

Dokumen ini menetapkan cara tim bekerja paralel, urutan pekerjaan per track, dependency, dan definition of done. Rencana bukan bukti implementasi.

## 1. Status dan Definition of Done

| Status | Makna |
| --- | --- |
| `planned` | Scope dan dependency diketahui; belum dimulai |
| `in_progress` | Sedang dikerjakan |
| `blocked` | Tidak dapat dilanjutkan karena dependency atau keputusan tertentu (dicatat) |
| `deferred` | Ditunda secara eksplisit oleh PM, dengan alasan dan dampak |
| `done` | Deliverable tersedia dan acceptance/done criteria memiliki evidence nyata |

Setiap PBI berstatus `done` wajib memiliki:

- Bagian frontend dan logic yang sudah **terintegrasi** (bukan lagi memakai fake).
- Pemeriksaan pada input final (command, cakupan, hasil) sesuai `.agent/rules.md` §6.
- Evidence acceptance; untuk perilaku lokasi, evidence dari perangkat fisik.
- Keterbatasan dan dependency yang belum selesai, tanpa diubah menjadi PASS.
- Pembaruan status di dokumen ini dan `.agent/sessionHandoff.md`.

Bagian satu track yang selesai tetapi belum terintegrasi dicatat sebagai `in_progress` dengan keterangan, misalnya "logic selesai, menunggu integrasi UI".

## 2. Model Kerja Paralel

### 2.1 Tiga track

AGAM tidak memiliki server milik tim; akun dan data memakai layanan terkelola Firebase. "Logic" berarti lapisan logika dan data **di dalam aplikasi**.

| Track | Developer | Tanggung jawab |
| --- | --- | --- |
| **FE** — Frontend | 1 | Seluruh layar UI01–UI10, navigasi antarlayar, state UI, dan penyambungan ke antarmuka logic |
| **LA** — Logic A: lokasi, sesi, data, audio, akun | 1 | Project & CI, izin dan layanan lokasi, data POI/Firestore, geofence, sesi & foreground service, notifikasi, audio, TTS, pengaturan, akun dan log aktivitas |
| **LB** — Logic B: peta, rute, pencarian, trail | 1 | Pipeline tile & batas kampus, graf jalur & routing, kontrol navigasi, pencarian, rekomendasi, progres trail, fasilitas |

Track tidak terikat pada orang tertentu. Pekerjaan suatu track dapat diambil oleh anggota tim yang sedang tersedia, selama komposisinya tetap satu developer frontend dan dua developer logic, dan pekerjaan tersebut mengikuti kepemilikan folder serta aturan kontrak di bawah.

Pekerjaan non-kode (konten PB09, survei pintu masuk, dataset fasilitas, urutan trail) berada di luar ketiga track dan diatur PM.

### 2.2 Kontrak lebih dulu (contract-first)

Ketiga track hanya dapat bekerja paralel jika batas di antara mereka disepakati sejak awal.

1. Pada **Sprint 1 Hari 1–2**, ketiga developer menyusun **kontrak** di `lib/contracts/`: model data dan antarmuka layanan (abstract class Dart). Daftar awalnya ada di §3.
2. Setiap track logic menyediakan **implementasi palsu (fake)** untuk antarmukanya. Fake mengembalikan data contoh berlabel sintetis dan dapat mensimulasikan perjalanan pengguna di kampus.
3. FE membangun layar menggunakan fake, sehingga tidak perlu menunggu logic selesai.
4. LA dan LB membangun implementasi asli dan mengujinya dengan unit test, tanpa menunggu layar.
5. Di **akhir setiap sprint** (§4), fake diganti dengan implementasi asli lalu diuji bersama di perangkat.

### 2.3 Kepemilikan folder

Untuk menghindari konflik merge, setiap track hanya mengubah foldernya sendiri. Struktur berikut sudah dibuat saat PB01; folder kosong berisi `.gitkeep`. Folder `assets/` belum didaftarkan di `pubspec.yaml`; track yang pertama kali menaruh aset di sebuah folder sekaligus mendaftarkannya.

| Folder | Pemilik |
| --- | --- |
| `lib/contracts/` (model, antarmuka, fake) | Bersama; perubahan mengikuti §2.4 |
| `lib/ui/` | FE |
| `lib/logic/location/`, `lib/logic/session/`, `lib/logic/data/`, `lib/logic/audio/`, `lib/logic/settings/`, `lib/logic/account/` | LA |
| `firestore.rules`, `firebase.json`, test rules Firestore | LA |
| `lib/logic/map/`, `lib/logic/routing/`, `lib/logic/search/`, `lib/logic/trail/` | LB |
| `lib/main.dart`, dependency injection, `pubspec.yaml`, `android/`, `.github/` | LA; perubahan oleh track lain lewat PR yang direview LA |
| `tools/tiles/`, `assets/map/`, `assets/routing/` | LB |
| `assets/data/`, `assets/media/` | LA (isi konten dari tim konten) |
| `test/` | Mengikuti folder yang diuji |

### 2.4 Perubahan kontrak

- Perubahan pada `lib/contracts/` dilakukan lewat PR tersendiri dari branch track pengusul ke `dev`, tanpa membuat branch tambahan, dan **disetujui oleh kedua track lain** sebelum di-merge. Selesaikan PR kontrak sebelum menumpuk pekerjaan lain pada branch yang sama agar diff tetap terpisah.
- Perubahan yang merusak (mengganti nama, menghapus field/metode, mengubah perilaku) wajib memperbarui fake dan semua pemakai dalam PR yang sama.
- Menambah field atau metode baru boleh dilakukan selama tidak merusak pemakai yang sudah ada.
- Jika kontrak ternyata tidak cukup di tengah sprint, track terkait berdiskusi dulu, bukan mengubah sepihak.

### 2.5 Alur kerja per PBI

**Persiapan lingkungan (sekali per developer):**

1. Pasang FVM lewat Homebrew: `brew install leoafarias/fvm/fvm`. Jika Homebrew menolak karena Command Line Tools usang, perbarui Command Line Tools terlebih dahulu.
2. Di root repo, jalankan `fvm install`. FVM membaca `.fvmrc` dan memasang Flutter 3.47.9. Unduhan pertama dapat memakan waktu lama karena FVM menyimpan cache repository Flutter.
3. Selalu gunakan `fvm flutter ...` dan `fvm dart ...`, bukan `flutter` global, agar versi sama dengan CI.
4. Untuk build APK dan menjalankan aplikasi di perangkat, pasang Android SDK (melalui Android Studio) dan JDK 17. `flutter analyze` dan `flutter test` tidak membutuhkan Android SDK.

**Langkah per PBI:**

1. Periksa working tree dan sinkronkan branch track dengan `dev` terbaru; pertahankan perubahan lokal yang belum selesai.
2. Baca `.agent/rules.md`, `.agent/sessionHandoff.md`, dan bagian PBI terkait di dokumen ini serta PRD.
3. Kerjakan pada branch tetap `LA`, `LB`, atau `FE` sesuai track. Tidak membuat branch baru per PBI/fitur/task. Branch track yang belum tersedia disiapkan dari `dev` dengan instruksi pengguna. Jika checkout masih berada di branch per PBI lama, laporkan kebutuhan migrasi; jangan memindahkan perubahan secara otomatis.
4. Kerjakan hanya di folder milik track sendiri (§2.3). Jika butuh perubahan kontrak, ikuti §2.4.
5. Jalankan `fvm dart format lib test`, `fvm flutter analyze`, dan test yang relevan. CI menolak kode yang belum diformat.
6. Buka PR dari branch track ke `dev` dengan deskripsi: PBI/bagian pekerjaan, apa yang berubah, cara menguji, dan keterbatasan. Batasi PR pada satu bagian yang dapat direview; jangan menumpuk task lain yang belum siap pada branch sebelum integrasi selesai.
7. PR direview minimal oleh satu developer lain sebelum di-merge.
8. Perbarui status PBI di dokumen ini dan catatan di `.agent/sessionHandoff.md`.

**Lima branch tetap:**

| Branch | Fungsi |
| --- | --- |
| `main` | Versi stabil yang sudah melewati integrasi |
| `dev` | Integrasi lintas track dan pengujian bersama |
| `LA` | Seluruh pekerjaan track Logic A |
| `LB` | Seluruh pekerjaan track Logic B |
| `FE` | Seluruh pekerjaan track Frontend |

Alur: `LA`/`LB`/`FE` → PR ke `dev` → pengujian integrasi → PR `dev` ke `main`. Setelah integrasi, sinkronkan kembali branch track dengan `dev` sebelum task berikutnya. Branch tetap dipakai ulang. Pekerjaan paralel menggunakan checkout/worktree terpisah dengan satu pemilik aktif per branch track. Ownership folder dan review kontrak tetap berlaku; branch tetap tidak menjamin bebas konflik.

Nama branch per PBI pada catatan implementasi sebelumnya adalah riwayat, bukan instruksi membuat branch baru. Pembuatan, migrasi, dan penghapusan branch tidak dilakukan otomatis. Commit, push, merge, dan rilis tetap memerlukan instruksi pengguna.

**Migrasi LA (instruksi pengguna, 4 November 2026):** progres PB03 sudah menjadi dasar `LA`; perubahan PB05 dilanjutkan pada branch yang sama setelah branch lokal PB05 diganti menjadi `LA`. Branch lama `feat/pb03-la-poi-repository` dibiarkan sebagai riwayat. Jangan push branch PB05 terpisah atau melanjutkan task baru pada branch PB03 lama. Status PB03/PB05 tidak berubah hanya karena migrasi branch.

**Catatan CI:** sejak 10 November 2026 `ci.yml` berjalan pada PR serta push ke `main` dan `dev` (belum diverifikasi dengan run GitHub).

### 2.6 Integrasi akhir sprint

Pada hari terakhir setiap sprint:

1. PR bagian pekerjaan yang siap diintegrasikan ke `dev`; integrasi kecil dilakukan sepanjang sprint, tidak menunggu hari terakhir.
2. FE mengganti fake dengan implementasi asli untuk fitur sprint itu.
3. Ketiga developer menguji alur sprint di perangkat fisik.
4. Defect integrasi dicatat; yang tidak selesai pindah ke sprint berikutnya dengan status yang jujur.
5. APK hasil integrasi dibangun oleh CI sebagai bukti sprint. Setelah pemeriksaan dan pengujian integrasi relevan lulus, ajukan PR `dev` → `main` untuk versi stabil; jangan mempromosikan pekerjaan yang belum siap. Merge dan rilis tetap menunggu instruksi pengguna.

## 3. Kontrak Awal

**Status: kontrak v1.0 disepakati ketiga track pada 2 November 2026.** Mulai saat ini, setiap perubahan pada `lib/contracts/` wajib mengikuti §2.4.

Lokasi kode:

| File | Isi |
| --- | --- |
| `lib/contracts/contracts.dart` | Satu import untuk semua model, antarmuka, dan `AppServices` |
| `lib/contracts/constants.dart` | Nilai produk bersama: radius 15 m, akurasi 20 m, dwell 5 detik, cooldown 10 menit, reroute 25 m, tiba 15 m, auto-end 30 menit, margin kampus 200 m |
| `lib/contracts/models/` | Model data (`AppSettings` di `models/settings.dart`) |
| `lib/contracts/services/la_services.dart`, `lb_services.dart` | Antarmuka layanan per track |
| `lib/contracts/fakes/` | Implementasi palsu dan data sintetis (`fake_data.dart`) |
| `lib/contracts/app_services.dart` | `AppServices`: kumpulan semua layanan; `AppServices.fake()` merangkai seluruh fake |

Pola yang dipakai semua layanan berstatus: getter `current` untuk nilai saat ini dan `Stream` untuk perubahan berikutnya (broadcast; tidak mengulang nilai lama).

Perilaku fake yang perlu diketahui FE:

- `FakeLocationService` mensimulasikan pengguna berjalan lurus antar-POI dalam urutan sintetis, 5 m per tick (default 1 detik), dan hanya berjalan selama ada listener.
- `FakeSessionController` memicu setiap POI sekali per sesi saat posisi masuk radius; tanpa dwell/cooldown. Mode Navigasi menghasilkan respons `brief`.
- `FakeMapConfig` memakai kotak pembungkus POI + 200 m dan `style.isPlaceholder == true` karena tile belum ada; FE menampilkan latar polos.
- `FakeRoutingService` menghasilkan garis lurus; `FakeNavigationController` menyatakan tiba pada ≤15 m tanpa rerouting.
- Teks POI berisi `PLACEHOLDER — menunggu tim konten`, `metadata.isPlaceholder == true`, dan media kosong. Fasilitas dan urutan trail berlabel sintetis.
- `FakePermissionService.locationResult`, `FakePermissionService.batteryOptimized`, dan `FakeVoiceGuidance.available` dapat diubah untuk mencoba keadaan izin ditolak, optimasi baterai, atau suara tidak tersedia.

Nama di tabel berikut sesuai kode kontrak v1.0.

### 3.1 Model data

| Model | Isi utama | Pemilik |
| --- | --- | --- |
| `GeoPoint` | lat, lng | Bersama |
| `LocationFix` | posisi, akurasi (m), waktu | LA |
| `Poi` | id, nama, alias, kategori, posisi, radius, pintu masuk, teks, fasilitas, path media, metadata A02 | LA |
| `Facility` | id, nama, kategori, posisi, gedung terkait, metadata | LA |
| `SessionState` | mode (`none`, `explore`, `navigation`, `trail`), aktif/tidak, alasan berakhir | LA |
| `PoiTriggerEvent` | id POI, mode saat trigger, jenis respons (penuh / ringkas tanpa audio) | LA |
| `WalkingRoute`, `RouteStep`, `NavigationTarget` | garis rute, jarak, ETA, langkah belokan; tujuan navigasi (POI/fasilitas) | LB |
| `NavigationState` | di rute / menyimpang / rerouting / tiba, sisa jarak, langkah berikutnya | LB |
| `SearchResult` | POI atau fasilitas, skor | LB |
| `Recommendation` | 1–3 POI dan fasilitas terdekat | LB |
| `TrailProgress` | urutan, POI dikunjungi, x/10, lencana | LB |
| `AppSettings` | auto-play narasi, dsb. | LA |
| `AudioClip`, `PlaybackState` | klip audio per POI (narasi/prompt/tiba), status pemutaran | LA |
| `CampusArea`, `MapStyleSource` | poligon area layanan, sumber tile dan style | LB |
| `ContentMetadata`, `PoiMedia`, `PoiEntrance`, `FacilityDistance` | metadata A02, path media, pintu masuk, fasilitas + jarak | LA / LB |

### 3.2 Antarmuka layanan

| Antarmuka | Fungsi untuk FE | Pemilik |
| --- | --- | --- |
| `PermissionService` | Status dan permintaan izin lokasi akurat & notifikasi; deteksi izin perkiraan; status dan halaman pengaturan optimasi baterai | LA |
| `LocationService` | Aliran posisi untuk mode peta biasa (hanya saat layar tampil) | LA |
| `PoiRepository` | Daftar POI dan fasilitas (bawaan + Firestore + cache) | LA |
| `SessionController` | Mulai/akhiri sesi per mode, aliran `SessionState` dan `PoiTriggerEvent`, auto-end 30 menit | LA |
| `AudioService` | Putar/jeda/ulang narasi, prompt, pengumuman tiba; kontrol dari notifikasi | LA |
| `VoiceGuidance` | Membacakan arahan navigasi (TTS `id-ID`), status ketersediaan suara | LA |
| `SettingsStore` | Baca/simpan pengaturan (progres trail dihapus lewat `TrailService.reset()`) | LA |
| `MapConfig` | Sumber tile dan style, batas area kampus, cek di dalam/luar area | LB |
| `RoutingService` | Hitung rute dari posisi ke tujuan | LB |
| `NavigationController` | Mulai/berhenti navigasi, aliran `NavigationState`, reroute >25 m, tiba ≤15 m | LB |
| `SearchService` | Pencarian dengan alias dan filter kategori | LB |
| `RecommendationService` | Rekomendasi setelah kartu ditutup/tiba | LB |
| `TrailService` | Mulai trail, POI berikutnya, progres, lencana; check-in dari `PoiTriggerEvent` | LB |
| `FacilityService` | Fasilitas terdekat per kategori | LB |

Titik sambung antar-logic: `TrailService` (LB) mendengarkan `PoiTriggerEvent` dari `SessionController` (LA); `NavigationController` (LB) memakai posisi dari layanan lokasi LA; `VoiceGuidance` (LA) membacakan langkah dari `NavigationState` (LB); auto-end 30 menit di `SessionController` (LA) memakai `MapConfig.isInsideCampus` (LB).

### 3.3 Usulan kontrak v1.1 — akun dan log aktivitas (PB21–PB22)

**Status: usulan, belum disepakati.** Wajib disetujui ketiga track sesuai §2.4 sebelum di-merge.

| Tambahan | Isi | Pemilik |
| --- | --- | --- |
| `UserRole` | `mahasiswaItb`, `pengunjung` | LA |
| `UserAccount` | `uid`, `email`, `role` | LA |
| `AuthState` | belum login, atau login dengan `UserAccount` | LA |
| `AuthService` | aliran `AuthState`; daftar (email, password, role), login, logout, kirim email reset password, hapus akun | LA |
| `ActivityEvent` | tipe tertutup sesuai PRD §15.5; hanya event dan field yang diizinkan | LA |
| `ActivityLogger` | mencatat `ActivityEvent`; tidak pernah melempar error ke pemanggil | LA |
| Fake | `FakeAuthService`, `FakeActivityLogger` (mencatat ke memori untuk test) | LA |
| `AppServices` | ditambah `auth` dan `activity` | Bersama |

`ActivityEvent` dibuat sebagai tipe tertutup supaya event di luar PRD §15.5 tidak dapat dibuat dari kode; privasi dijaga oleh tipe, bukan hanya oleh review.

Perubahan ini **merusak** pemakai yang ada karena `AppServices` mendapat dua field wajib. Sesuai §2.4, PR kontrak v1.1 wajib sekaligus memperbarui `AppServices.fake()` dan perangkaian layanan di `lib/ui/` milik FE, sehingga PR tersebut memerlukan persetujuan FE dan LB.

Progres trail, POI dikunjungi, dan pengaturan disimpan per akun (PRD §15.1). Implementasi `SettingsStore` (LA) dan penyimpanan progres `TrailService` (LB) wajib memakai `uid` aktif sebagai bagian kunci penyimpanan; antarmuka keduanya tidak berubah.

## 4. Milestone

| Waktu | Milestone |
| --- | --- |
| Week 9 | PRD baseline disetujui |
| Week 10 | Sprint 1 |
| Week 11 | Sprint 2 |
| Week 12 | Sprint 3 + **Major Progress Review** (UI01–UI06 dan alur eksplorasi inti dapat didemokan) |
| Week 13 | Sprint 4 + **Feature Freeze** di akhir minggu; seluruh layar dan fitur selesai |
| Week 14 | Sprint 5: testing acceptance, perbaikan defect, retest |
| Week 15 | Final deliverables: APK, Testing Report, PRD Compliance Matrix, video ≤3 menit, AI & Tools Disclosure |

| Sprint | Sprint goal | PBI | Status |
| --- | --- | --- | --- |
| S1 — Week 10 | Kontrak, fondasi aplikasi, lokasi, peta | PB01, PB02, PB03, PB04 | `in_progress` |
| S2 — Week 11 | Geofence, sesi, trigger, kartu POI, audio | PB05, PB06, PB07, PB08, PB09 | `in_progress` — logic LA PB05/PB06/PB08 dan format PB09 ada di source (10 November 2026); UI03/UI04 FE tersedia (14 November 2026); integrasi dan uji perangkat belum |
| S3 — Week 12 | Pencarian dan navigasi; akun dan log aktivitas | PB10, PB11, PB12, PB21, PB22 | `in_progress` — bagian LA PB12 ada di source (10 November 2026); UI05/UI06 FE tersedia; PB10/PB11 (LB) belum; PB21/PB22 `planned` |
| S4 — Week 13 | Eyes-free, rekomendasi, trail, fasilitas, offline; Feature Freeze | PB13, PB14, PB15, PB16, PB17 | `in_progress` — UI08 FE/PB15 mulai lebih awal; PBI Sprint 4 lainnya belum dimulai |
| S5 — Week 14 | Uji acceptance, perbaikan, rilis v1.0 | PB18, PB19, PB20 | `planned` |

## 5. Sprint 1 — Kontrak, Fondasi, Lokasi, dan Peta

**Hari 1–2 (bersama, wajib sebelum kerja paralel):** langkah 2–4 selesai (kontrak v1.0 disepakati 2 November 2026); langkah 1 menunggu CI dan uji perangkat.

1. LA menginisialisasi project Flutter, mengunci versi Flutter/Dart, membuat struktur folder §2.3, lint, dan workflow CI build APK (PB01).
2. Ketiga developer menyusun kontrak §3 di `lib/contracts/`, lalu merge sebagai satu PR.
3. LA dan LB menyediakan fake untuk antarmuka masing-masing, termasuk fake lokasi yang mensimulasikan perjalanan di kampus.
4. Nama final kontrak dicatat di §3.

**Hari 3–akhir sprint (paralel):**

| Track | Langkah |
| --- | --- |
| FE | 1. Kerangka aplikasi: tema, navigasi antarlayar. 2. UI01 Onboarding & izin (PB02) dengan `PermissionService` fake. 3. UI02 Explore Map (PB04): peta, penanda 10 POI, titik posisi, pesan di luar area, atribusi OSM; awalnya dengan `MapConfig` dan `LocationService` fake. |
| LA | 1. Workflow rilis APK ke GitHub Releases (PB01). 2. `PermissionService` dan `LocationService` asli: izin akurat, notifikasi, berhenti saat aplikasi diminimalkan (PB02). 3. `PoiRepository`: JSON bawaan 10 POI dari PRD §9.1, validasi, cache lokal, sinkronisasi Firestore (PB03; bagian Firestore `blocked` sampai project Firebase dibuat). |
| LB | 1. Script pipeline tile: data OSM → PMTiles area kampus + ±200 m (PB04). 2. File style AGAM. 3. `MapConfig` asli: sumber tile, style, poligon/batas kampus, cek di dalam area; catat batas di PRD §9.3. 4. Verifikasi renderer tile vektor bersama FE. |

**Integrasi akhir sprint:** aplikasi menampilkan peta offline, 10 POI, dan posisi pengguna asli di perangkat fisik.

### PB01 — Project Flutter, repository, pipeline build APK

- **Track:** LA · **Requirement:** —
- **Sudah dibuat (2 November 2026, branch `chore/pb01-la-scaffolding`):** project Flutter 3.47.9 dikunci via `.fvmrc`; application ID `site.agam`, label "AGAM"; minSdk 24, targetSdk/compileSdk 36; struktur folder §2.3; kerangka `AgamApp` di `lib/ui/app.dart`; workflow `ci.yml` (format, analyze, test, build APK debug sebagai artifact) dan `release.yml` (tag `v*` → APK di GitHub Releases).
- **Pemeriksaan lokal:** `dart format` tanpa perubahan, `flutter analyze` tanpa issue, `flutter test` lulus (saat PB01 berisi 1 test; suite tumbuh seiring PBI berikutnya). Build APK **belum** dijalankan lokal karena Android SDK belum terpasang di mesin setup.
- **CI (terverifikasi 3 November 2026):** workflow `ci.yml` sudah berjalan dan sukses — run 41424657609 (PR #1) dan 41424686250 (`main`), keduanya menghasilkan artifact `agam-debug-apk`. Peringatan deprecation: `actions/checkout@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4` dipaksa ke Node.js 24; `ubuntu-latest` pindah ke Ubuntu 26 pada 19 Oktober 2026.
- **Pembaruan CI (10 November 2026, LA):** action dinaikkan ke `actions/checkout@v7`, `actions/setup-java@v6`, `actions/upload-artifact@v7`, `softprops/action-gh-release@v3` (versi dan catatan rilis diperiksa via GitHub API; perubahan utama runtime Node 24). CI kini juga berjalan pada push ke `dev`. `release.yml` kini menjalankan format dan analyze sebelum test. Workflow baru belum dijalankan di GitHub.
- **Sisa:** APK belum dipasang di perangkat fisik; workflow `release.yml` belum pernah berjalan; keystore rilis ditunda ke PB19 (sampai saat itu APK rilis ditandatangani debug key runner sehingga tidak dapat dipasang menimpa versi sebelumnya).
- **Done:** APK debug terpasang dan dibuka tanpa crash di perangkat uji; workflow CI membangun APK dan mengunggahnya ke Releases.
- **Status:** `in_progress`

### PB02 — Onboarding privasi, izin, dan pembacaan lokasi

- **Track:** FE (UI01), LA (`PermissionService`, `LocationService`) · **Requirement:** F01, A01
- **Scope:** layar penjelasan privasi; izin lokasi akurat "saat aplikasi digunakan" dan notifikasi; penanganan izin perkiraan/ditolak; panduan pengaturan baterai pabrikan; pembacaan lokasi mode peta biasa.
- **Done:** izin diminta setelah layar penjelasan; lokasi terbaca dan diperbarui; pembacaan berhenti saat aplikasi diminimalkan.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/location/device_permission_service.dart`: `PermissionService` asli (geolocator + flutter_local_notifications + channel `site.agam/battery` di `MainActivity.kt`). Lokasi perkiraan → `approximateOnly`; permintaan ulang untuk lokasi akurat; tidak pernah meminta izin "sepanjang waktu".
  - `lib/logic/location/device_location_service.dart` + `position_source.dart`: `LocationService` asli. Peta biasa membaca lokasi hanya saat aplikasi tampil dan ada pendengar; berhenti saat diminimalkan; `lastFix` dihapus saat pembacaan berhenti.
  - Manifest: izin lokasi akurat, foreground service `location`/`mediaPlayback`, notifikasi; `ACCESS_BACKGROUND_LOCATION` dihapus eksplisit (`tools:node="remove"`), dijaga `test/android/manifest_privacy_test.dart`.
- **UI01/UI02 FE (14 November 2026):** onboarding meminta izin foreground lalu UI02 menampilkan posisi perangkat saat aplikasi aktif. FE sempat memakai adapter Geolocator sendiri di `lib/ui/device_location_services.dart`.
- **Sisa:** uji perangkat fisik (izin, perkiraan, notifikasi Android 13+, optimasi baterai per merek).
- **Status:** `in_progress` — logic LA dan UI01 tersedia; menunggu uji perangkat

### PB03 — Dataset 10 POI (Firestore + JSON bawaan)

- **Track:** LA · **Requirement:** F01, F02, F05, A02
- **Scope:** skema final (PRD §15.3); JSON bawaan; validasi dokumen; sinkronisasi Firestore → cache lokal; fallback ke salinan lokal.
- **Dependency eksternal:** project Firebase (belum dibuat).
- **Sudah dibuat (3 November 2026, branch `feat/pb03-la-poi-repository`):**
  - Skema final dicatat di PRD §15.3, termasuk tabel aturan validasi dan nilai enum `category`.
  - `assets/data/pois.json`: 10 POI dari PRD §9.1 (id, nama, alias, kategori, koordinat, radius 15 m). Teks dan media berlabel `PLACEHOLDER`, `entrances` kosong, `trailOrder` null, metadata belum disetujui. Didaftarkan di `pubspec.yaml`.
  - `lib/logic/data/poi_codec.dart`: validasi per dokumen; dokumen tidak valid diabaikan satu per satu beserta alasannya (`PoiDecodeIssue`).
  - `lib/logic/data/poi_sources.dart`: `BundledDataset`, `DatasetCache` (`FileDatasetCache` dan `InMemoryDatasetCache`), serta `RemoteDatasetSource` dengan `UnavailableRemoteSource` selama project Firebase belum ada.
  - `lib/logic/data/poi_repository_impl.dart`: `PoiRepository` asli dengan urutan cache → bawaan, `refresh()` yang tidak pernah melempar, dan dataset tanpa POI valid tidak dipakai maupun di-cache.
- **Pemeriksaan (lokal, Flutter 3.47.9 via FVM):** `dart format --set-exit-if-changed` tanpa perubahan; `flutter analyze` tanpa issue; `flutter test` 67 test lulus (56 baru + 11 test kontrak). Test dataset bawaan diverifikasi benar-benar menangkap kesalahan dengan sengaja mengubah satu koordinat, lalu dipulihkan.
- **Sisa (`blocked`):** sinkronisasi Firestore belum dibuat (project Firebase belum ada, PRD §22); `cloud_firestore` belum ditambahkan ke `pubspec.yaml`. Direktori cache saat integrasi masih perlu package penyedia path yang versinya wajib diverifikasi. Belum diuji di perangkat fisik.
- **Done:** data 10 POI terbaca dari server dan dari cache lokal; dokumen tidak valid diabaikan; aplikasi berjalan saat offline.
- **Pembaruan 10 November 2026:** `path_provider` ^2.1.6 ditambahkan; `lib/logic/la_bootstrap.dart` memakai `getApplicationSupportDirectory()` untuk `FileDatasetCache`.
- **Status:** `in_progress` — JSON bawaan, validasi, cache, dan fallback selesai dan teruji; bagian Firestore `blocked`, dan belum terintegrasi dengan UI.

### PB04 — Explore Map dengan tile vektor dibundel

- **Track:** LB (pipeline tile, style, `MapConfig`), FE (UI02) · **Requirement:** F01, A03
- **Brief:** [PB04-LB-01 — pipeline OSM ke PMTiles](../task-implementation/backend/PB04-LB-01-tile-pipeline.md).
- **Ada di source (4 November 2026):** pipeline PowerShell/Python di `tools/tiles/`, generator Planetiler v0.10.2 terverifikasi SHA-256, snapshot batas OSM `way/177629384`, coverage kampus + 200 m, validator arsip dan manifest. Tidak mengubah kontrak, UI, atau dependency Flutter.
- **Verifikasi lokal:** 18 test tooling lulus; dua build data nyata/cache menghasilkan PMTiles identik (1.035.927 bytes, 13 tile zoom 12–16); validator penuh dan CLI resmi `pmtiles verify` lulus. Manifest di `assets/map/ganesha.manifest.json`; command, checksum, peringatan sumber, dan batas evidence di handoff.
- **Sisa:** style AGAM, `MapConfig` asli, pendaftaran aset di APK, renderer bersama FE, serta uji offline/perangkat. Batas coverage tile tercatat di PRD §9.3; batas layanan belum diterapkan.
- **UI02 FE (14 November 2026):** kerangka Explore Map dengan penanda POI dan posisi; peta masih ilustrasi skematis berlabel, belum merender PMTiles.
- **Done:** peta tampil offline setelah login pertama; 10 POI dan posisi pengguna yang bergerak terlihat; script tile dapat dijalankan ulang; ukuran tile tercatat.
- **Status:** `in_progress` — pipeline tile LB-01 selesai dan kerangka UI02 FE tersedia; style, `MapConfig` asli, dan renderer tile belum

## 6. Sprint 2 — Geofence, Sesi, Trigger, Kartu POI, dan Audio

| Track | Langkah |
| --- | --- |
| FE | 1. Tombol mulai/akhiri sesi Explore dan indikator sesi aktif (PB06). 2. UI03 tampilan trigger: Dengarkan/Lihat/Lewati, notifikasi ringkas (PB06). 3. UI04 Kartu POI: foto, fungsi, fasilitas, trivia, sumber, pemutar video GKUB/GKUT; dibuka dari trigger dan dari peta (PB07). 4. Kontrol pemutar narasi di kartu (PB08). |
| LA | 1. Engine geofence: haversine, dwell, cooldown, histeresis, filter akurasi, interval adaptif, beserta unit test (PB05). 2. `SessionController`: foreground service tipe `location`, notifikasi tetap, trigger saat layar mati, tombol Akhiri, auto-end 30 menit, respons per mode (PB06). 3. Notifikasi trigger dan getar (PB06). 4. `AudioService`: narasi, prompt, kontrol dari notifikasi dan lock screen, auto-play (PB08). 5. Format aset konten dan validasi metadata A02 untuk tim konten (PB09). |
| LB | 1. Bangun graf jalur kampus (GeoJSON) dari data OSM; tandai bagian yang perlu dikoreksi survei (persiapan PB11). 2. `RoutingService`: Dijkstra/A* atas graf, beserta unit test (persiapan PB11). 3. `SearchService`: normalisasi, Arab ↔ Romawi, alias, filter kategori, beserta unit test (persiapan PB10). |

**Integrasi akhir sprint:** di perangkat fisik, memulai Explore lalu berjalan ke POI memunculkan trigger (juga saat layar mati), kartu POI terbuka, dan narasi dapat diputar.

LB mengerjakan persiapan Sprint 3 di Sprint 2 karena tidak ada PBI Sprint 2 yang menjadi milik LB.

### PB05 — Engine geofence in-app

- **Track:** LA · **Requirement:** F02
- **Brief:** [PB05-LA-01 — engine sinkron](../task-implementation/backend/PB05-LA-01-geofence-engine.md); tata cara brief di [panduan brief](../task-implementation/README.md).
- **Ada di source (4 November 2026):** `lib/logic/location/geofence_engine.dart`, API internal LA dan state machine sinkron; test deterministik di `test/logic/location/geofence_engine_test.dart`. Menggunakan model/konstanta existing tanpa mengubah kontrak, UI, GPS, Android, atau package.
- **Parameter:** margin histeresis default 5 m dan jeda sampel maksimum 10 detik telah diterapkan, belum dikalibrasi; lihat PRD §9.2.
- **Verifikasi lokal (4 November 2026):** SDK resmi tag Flutter 3.47.9 / Dart 3.13.7 dijalankan lewat path absolut setelah FVM awalnya tidak tersedia di PATH. Format: 31 file, 0 perubahan; analyze: tanpa issue; test geofence: 46 lulus; seluruh suite: 113 lulus (67 existing + 46 baru). Command/path dan catatan lingkungan ada di handoff; CI remote tidak dijalankan sesi ini.
- **Pembaruan 10 November 2026:** engine mendapat `suspend()` dan `updatePois()` (cooldown dipertahankan per ID saat dataset diperbarui); diuji di `test/logic/location/geofence_engine_update_test.dart`. Interval GPS adaptif ada di `lib/logic/location/adaptive_interval.dart` (parameter dan keterbatasan di PRD §9.2). Integrasi dengan sesi dilakukan `DeviceSessionController` (PB06).
- **Sisa:** uji perangkat fisik dan kalibrasi lapangan (margin, jeda sampel, parameter interval adaptif). Tidak menutup acceptance F02.
- **Done:** unit test lulus dengan nilai yang dihitung independen; trigger tepat pada POI uji.
- **Status:** `in_progress`

### PB06 — Sesi lokasi, notifikasi, getar, dan prompt saat trigger

- **Track:** LA (`SessionController`, notifikasi), FE (UI03, kontrol sesi) · **Requirement:** F02, F04, A01
- **Done:** notifikasi dan prompt muncul ≤10 detik setelah masuk radius, termasuk saat layar mati di perangkat fisik; tidak ada pembacaan lokasi di luar sesi kecuali mode peta biasa di layar.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/session/device_session_controller.dart`: `SessionController` asli. Foreground service tipe `location` lewat geolocator; ganti mode tanpa memulai ulang service; `end()` menghentikan lokasi dan service; auto-end 30 menit di luar kampus (memakai `MapConfig.isInsideCampus` dari LB); izin dicabut → `permissionRevoked`; trigger nonaktif di luar area; Navigasi → `brief`, Explore/Trail → `full`; cooldown bertahan antar-sesi.
  - `lib/logic/session/trigger_notifier.dart`: notifikasi trigger (getar, prioritas tinggi, tombol Dengarkan/Lihat/Lewati, terlihat di lock screen) dan notifikasi ringkas tanpa suara. Tombol tanpa membuka aplikasi diteruskan dari isolate latar belakang plugin ke isolate utama lewat `IsolateNameServer`.
  - `lib/logic/session/trigger_responder.dart`: respons per mode; prompt audio atau narasi langsung bila auto-play aktif; `viewRequests` untuk FE membuka kartu POI.
- **UI03 FE (14 November 2026):** kartu trigger Dengarkan/Lihat/Lewati di atas UI02 dan kontrol sesi.
- **Belum:** penyambungan `viewRequests` ke navigasi layar memerlukan keputusan FE (tidak ada di `AppServices` v1.0, sehingga butuh usulan perubahan kontrak §2.4 atau penyambungan di `main.dart`); uji perangkat fisik saat layar mati; teks notifikasi masih rumusan developer dari skenario PRD §5 dan dapat disesuaikan desain UI03.
- **Status:** `in_progress` — logic LA dan UI03 tersedia; menunggu penyambungan `viewRequests` dan uji perangkat

### PB07 — Kartu POI

- **Track:** FE (UI04); data dari `PoiRepository` (LA) · **Requirement:** F03
- **Done:** kartu terbuka dari trigger dan dari peta dengan konten sesuai; video GKUB/GKUT dapat diputar.
- **Status:** `in_progress` — UI04 tersedia sebagai halaman detail penuh yang dapat dibuka dari tombol Details pada POI yang sudah tiba/check-in. Data teks, foto, fasilitas, trivia, sumber, dan audio tetap placeholder sampai tim konten menyediakan materi terverifikasi.

### PB08 — Pemutar narasi audio

- **Track:** LA (`AudioService`), FE (kontrol di kartu) · **Requirement:** F03, F04
- **Done:** narasi dapat dikendalikan dari kartu dan notifikasi.
- **Ada di source (10 November 2026, LA):** `lib/logic/audio/device_audio_service.dart` (`AudioService` asli; path dari `Poi.media`; konten placeholder → `PlaybackStatus.error` tanpa crash) dan `lib/logic/audio/agam_audio_handler.dart` (`just_audio` + `audio_service`; putar/jeda/berhenti dari notifikasi media dan lock screen). `MainActivity` diturunkan dari `AudioServiceActivity`.
- **Kontrol di kartu (FE, 14 November 2026):** UI04 memanggil `AudioService`; kontrol aktif bila file narasi POI tersedia.
- **Sisa:** file audio belum ada (PB09); uji perangkat fisik.
- **Status:** `in_progress` — logic LA dan kontrol UI04 tersedia; menunggu file audio dan uji perangkat

### PB09 — Produksi konten 10 POI

- **Track:** di luar track developer; LA menyiapkan format dan validasi · **Requirement:** F03, A02
- **Catatan:** agent dilarang membuat konten ini.
- **Bagian LA (10 November 2026):** format aset dan aturan validasi untuk tim konten di [PB09-LA-01](../task-implementation/backend/PB09-LA-01-content-format.md); pemeriksaan otomatis `test/logic/data/content_assets_test.dart`.
- **Done:** konten 10 POI lengkap, sumber tercatat, hak penggunaan media aman, disetujui tim.
- **Status:** `in_progress` — format dan validasi LA tersedia; konten belum ada (tim konten)

## 7. Sprint 3 — Pencarian, Navigasi, dan Akun

| Track | Langkah |
| --- | --- |
| FE | 1. UI05 Pencarian dan filter kategori (PB10). 2. UI06 Navigasi: garis rute, jarak, ETA, langkah berikutnya, keadaan menyimpang/rerouting (PB11). 3. Tampilan tiba (bagian awal UI07) (PB12). 4. Rapikan UI01–UI06 untuk Major Progress Review. 5. UI10 Daftar & Login, gerbang login sebelum UI01, info akun, logout, dan hapus akun di UI09 (PB21). 6. Event `featureUsed` untuk kartu POI, narasi, dan fasilitas (PB22). |
| LA | 1. `VoiceGuidance`: TTS `id-ID`, deteksi ketersediaan suara, fallback visual (PB12). 2. Putar audio pengumuman tiba saat `NavigationState` tiba (PB12). 3. Mode Navigasi di `SessionController`: POI lain hanya notifikasi ringkas tanpa audio (PB06/PB11). 4. Usulan kontrak v1.1 (§3.3). 5. Setup Firebase di aplikasi, `AuthService`, profil `users/{uid}`, penyimpanan lokal per akun, rules Firestore beserta test (PB21). 6. `ActivityLogger` serta event akun, `appOpen`, dan mode (PB22). |
| LB | 1. `NavigationController`: posisi → `NavigationState`, reroute >25 m, tiba ≤15 m (PB11). 2. Koreksi graf jalur dan titik pintu masuk dari survei bila sudah tersedia; jika belum, pakai titik tengah gedung berlabel placeholder (PB11). 3. Integrasi `SearchService` dengan data asli (PB10). 4. Event `featureUsed` pencarian dan `trailCompleted` saat `SearchService` dan `TrailService` asli dibuat; progres trail disimpan per akun (PB22). |

**Syarat akun di Sprint 3:** project Firebase dengan Firestore dan Authentication sudah dibuat di awal minggu, dan kontrak v1.1 disepakati ketiga track sebelum FE dan LB memakainya. Gerbang login hanya di-merge ke `dev` setelah lengkap, supaya demo Major Progress Review tidak terhalang login yang setengah jadi.

**Integrasi akhir sprint:** mencari "labtek 5", menavigasi ke Labtek V dengan arahan suara, dan menerima pengumuman tiba di perangkat fisik. Hasilnya dipakai untuk Major Progress Review. Jika PB21 sudah lengkap, alur dimulai dari daftar/login.

### PB10 — Pencarian dengan alias dan filter kategori

- **Track:** LB (`SearchService`), FE (UI05) · **Requirement:** F05
- **Done:** "labtek 5", "Labtek V", "lab 5" → Labtek V teratas; respons ≤1 detik.
- **Status:** `in_progress` — UI05 FE tersedia dengan pencarian/filter lewat kontrak SearchService dan tujuan dari repository. Device shell masih memakai SearchService fake; integrasi LB dan verifikasi alias ≤1 detik belum dilakukan.

### PB11 — Navigasi jalan kaki di perangkat

- **Track:** LB (graf, `RoutingService`, `NavigationController`), FE (UI06), LA (sesi Navigasi) · **Requirement:** F06, A01
- **Dependency eksternal:** koordinat pintu masuk (survei).
- **Done:** rute tampil ke pintu masuk tujuan; rerouting berjalan; tidak ada request routing ke server.
- **Status:** `in_progress` — UI06 FE menampilkan pratinjau tujuan, jarak, ETA, dan langkah bila tersedia, serta memulai sesi/navigasi dari posisi perangkat. Shell masih memakai routing/navigation fake; graf jalur, pintu masuk survei, rerouting, dan verifikasi lapangan LB belum tersedia.

### PB12 — Arahan suara navigasi dan deteksi tiba

- **Track:** LA (`VoiceGuidance`, audio tiba), LB (event tiba), FE (tampilan tiba) · **Requirement:** F04, F06
- **Done:** arahan suara di setiap belokan; pengumuman tiba saat ≤15 m dari tujuan.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/audio/device_voice_guidance.dart`: `VoiceGuidance` asli dengan `flutter_tts` ^4.2.5, locale `id-ID`. Dianggap tersedia hanya jika suara `id-ID` **offline** terpasang (`isLanguageInstalled`); jika tidak, diam dan UI memakai arahan visual. Arahan baru menggantikan ucapan lama (QUEUE_FLUSH). Manifest menambah query `TTS_SERVICE` sesuai README plugin.
  - `lib/logic/audio/navigation_announcer.dart`: mendengarkan `NavigationState` (LB); membacakan `RouteStep.instruction` sekali per langkah dan saat rute baru setelah rerouting; langkah `arrive` tidak dibacakan; saat tiba, TTS dihentikan lalu file audio tiba POI diputar lewat `AudioService`.
  - Mode Navigasi di `SessionController` (POI lain hanya notifikasi ringkas) sudah selesai di PB06.
- **Belum/keputusan terbuka:** tujuan fasilitas tidak punya file audio tiba sehingga konfirmasinya hanya visual. Jika tim ingin pengumuman suara untuk fasilitas atau fallback TTS saat file audio POI belum ada, itu menyimpang dari PRD §10 (TTS hanya arahan) dan perlu keputusan PM. Integrasi dengan `NavigationController` asli (LB), tampilan tiba (FE), file audio tiba (PB09), dan uji perangkat belum dilakukan.
- **Status:** `in_progress` — logic LA selesai dan teruji unit dengan navigasi palsu

### PB21 — Akun dan login wajib

- **Asal:** tidak ada di PRD resmi; ditambahkan atas keputusan PM (6 dan 14 November 2026). Wajib dicatat di Change Log PRD resmi (PRD §23).
- **Track:** LA (`AuthService`, profil `users/{uid}`, penyimpanan lokal per akun, rules Firestore dan test-nya, setup Firebase, DI), FE (UI10, gerbang login, akun di UI09), LB (penyimpanan progres trail per akun) · **Requirement:** A01 · **[CL]**
- **Scope:** daftar dengan email, password, pilihan role, dan persetujuan pemberitahuan privasi; login; lupa password lewat email reset; logout; hapus akun (profil, log, data lokal milik akun, akun Auth); pesan offline saat login pertama; sesi login bertahan setelah aplikasi ditutup; progres lokal per akun (PRD §15.1). Tanpa verifikasi email.
- **Dependency:** project Firebase (Firestore + Authentication Email/Password); kontrak v1.1 (§3.3); teks pemberitahuan privasi disetujui PM; desain UI10.
- **Done:** pengguna baru tidak dapat masuk tanpa daftar/login; setelah login pertama aplikasi dapat dipakai dalam mode pesawat; logout kembali ke UI10 tanpa menghapus progres, dan login kembali dengan akun yang sama memulihkan progres; akun lain di perangkat yang sama tidak melihat progres akun pertama; hapus akun menghapus profil, log, dan data lokalnya; test rules dengan emulator menolak akses ke profil pengguna lain.
- **Status:** `planned`

### PB22 — Log aktivitas internal

- **Asal:** tidak ada di PRD resmi; ditambahkan atas keputusan PM (6 dan 14 November 2026). Wajib dicatat di Change Log PRD resmi (PRD §23).
- **Track:** LA (`ActivityLogger`, event `signUp`/`login`/`logout`/`appOpen`/`modeStart`/`modeEnd`, rules `hasOnly`), FE (event `featureUsed` untuk kartu POI, narasi, fasilitas), LB (event `featureUsed` pencarian dan `trailCompleted`) · **Requirement:** A01 · **[CL]**
- **Scope:** seluruh event PRD §15.5 dengan field yang diizinkan saja; antrean offline; `appOpen` hanya saat cold start; event mode dan trail selesai hanya bertanggal.
- **Dependency:** PB21; `SearchService` dan `TrailService` asli (LB) untuk event LB. Jika belum tersedia di Sprint 3, bagian LB pindah ke Sprint 4, tetap sebelum Feature Freeze.
- **Done:** setiap event PRD §15.5 tercatat dengan field yang benar; test rules dengan emulator menolak dokumen berfield tambahan (mis. `lat`) dan dokumen dengan `uid` milik orang lain; pemeriksaan lalu lintas jaringan menunjukkan tidak ada koordinat, ID POI, atau tujuan yang terkirim.
- **Status:** `planned`

## 8. Sprint 4 — Eyes-free, Rekomendasi, Trail, Fasilitas; Feature Freeze

| Track | Langkah |
| --- | --- |
| FE | 1. UI07 Rekomendasi setelah kartu ditutup/tiba, navigasi satu ketukan (PB14). 2. UI08 Orientation Trail: urutan, progres x/10, lencana (PB15). 3. UI09 Fasilitas & pengaturan: daftar fasilitas, auto-play, akhiri sesi, hapus progres (PB16). 4. Mode eyes-free: tombol besar dan alur tanpa membaca layar (PB13). 5. Keadaan offline yang jelas di semua layar (PB17). |
| LA | 1. Kontrol eyes-free dari notifikasi dan lock screen; auto-play (PB13). 2. `SettingsStore` untuk pengaturan (PB16). 3. Mode Trail di `SessionController` (PB15). 4. Uji offline: mode pesawat untuk data, media, trigger (PB17). |
| LB | 1. `RecommendationService` (PB14). 2. `TrailService`: urutan, navigasi berantai, check-in dari `PoiTriggerEvent` termasuk di luar urutan, progres tersimpan, lencana, hapus progres lokal lewat `reset()` (PB15/A01). 3. `FacilityService` (PB16; bergantung pada dataset fasilitas). 4. Uji offline peta dan navigasi (PB17). |

**Integrasi akhir sprint (Feature Freeze):** seluruh layar UI01–UI09 dan fitur F01–F08 terintegrasi tanpa fake. Setelah ini tidak ada fitur baru, hanya perbaikan.

### PB13 — Mode eyes-free

- **Track:** FE, LA · **Requirement:** F04
- **Done:** alur trigger, narasi, dan navigasi dapat dijalankan tanpa membaca layar.
- **Status:** `planned`

### PB14 — Rekomendasi POI berikutnya

- **Track:** LB (`RecommendationService`), FE (UI07) · **Requirement:** F07
- **Done:** rekomendasi muncul setelah kartu ditutup/tiba dan dapat langsung dinavigasikan.
- **Status:** `planned`

### PB15 — Orientation Trail

- **Track:** LB (`TrailService`), FE (UI08), LA (sesi Trail) · **Requirement:** F08
- **Dependency eksternal:** urutan trail dari tim.
- **Done:** progres tersimpan setelah aplikasi ditutup; lencana muncul saat 10/10.
- **Status:** `in_progress` — layar scrollable UI08 FE tersedia dan membaca `TrailProgress`/POI dari kontrak fake. Urutan yang tampil sintetis dan berlabel; penyimpanan progres, urutan resmi, check-in integrasi, badge acceptance, serta logic sesi/navigasi LA/LB belum selesai.

### PB16 — Fasilitas terdekat

- **Track:** LB (`FacilityService`), FE (UI09), LA (data fasilitas di `PoiRepository`) · **Requirement:** F05, F07 · **Prioritas:** Should
- **Dependency eksternal:** dataset fasilitas.
- **Status:** `planned`

### PB17 — Verifikasi akses offline

- **Track:** semua · **Requirement:** A03 · **Prioritas:** Could
- **Done:** trigger, kartu POI, peta, dan navigasi berfungsi dalam mode pesawat tanpa crash.
- **Status:** `planned`

## 9. Sprint 5 — Pengujian, Rilis, dan Dokumentasi

| Track | Langkah |
| --- | --- |
| Semua | 1. Field test dan usability test di Kampus Ganesha di beberapa perangkat (PB18). 2. Catat defect dengan prioritas. 3. Perbaiki defect di folder masing-masing (PB19). 4. Kalibrasi radius dan histeresis per POI; catat nilainya di PRD (PB19, LA). 5. Retest acceptance criteria. 6. Rilis APK v1.0 (PB19, LA). |

### PB18 — Field testing dan usability testing

- **Track:** semua · **Requirement:** F01–F08
- **Scope:** F02 (≥8/10 POI), F04 (≥3 penguji), F06 (≥4/5 tujuan acak); termasuk merek dengan optimasi baterai agresif.
- **Done:** laporan uji dan daftar defect tercatat.
- **Status:** `planned`

### PB19 — Perbaikan defect, kalibrasi, retest, rilis v1.0

- **Track:** semua · **Requirement:** F01–F08
- **Done:** defect prioritas tinggi selesai; APK v1.0 lulus retest acceptance criteria dan tersedia di GitHub Releases.
- **Status:** `planned`

### PB20 — Video showcase dan AI & Tools Disclosure

- **Track:** PM · **Requirement:** —
- **Done:** video ≤3 menit terunggah; dokumen disclosure lengkap.
- **Status:** `planned`

## 10. Requirement Coverage

| Requirement | PBI | Evidence akhir |
| --- | --- | --- |
| F01 Location Awareness | PB02, PB04 | Live demo + video test |
| F02 Location-Based Trigger | PB05, PB06, PB19 | Video field test + log (≥8/10 POI) |
| F03 Multimodal Exploration | PB07, PB08, PB09 | Pemeriksaan 10 kartu POI |
| F04 Eyes-Free Interaction | PB06, PB08, PB12, PB13 | Uji ≥3 penguji |
| F05 Search & Destination | PB03, PB10, PB16 | Test pencarian + pengukuran waktu respons |
| F06 Navigation | PB11, PB12 | Field test ≥4/5 tujuan acak |
| F07 Contextual Recommendation | PB14, PB16 | Demo alur kartu ditutup/tiba |
| F08 Orientation Trail | PB15 | Demo progres tersimpan + lencana |
| A01 Privacy & Session Control | PB02, PB06, PB11, PB21, PB22 | Pemeriksaan penyimpanan dan lalu lintas jaringan; test rules Firestore |
| A02 Content Traceability | PB03, PB07, PB09 | Metadata lengkap pada 10 POI |
| A03 Offline Information Access | PB03, PB04, PB17 | Uji mode pesawat |

## 11. Dependency Eksternal

| Dependency | Dibutuhkan oleh | Status |
| --- | --- | --- |
| Project Firebase (Firestore + Authentication Email/Password) | PB03, PB21, PB22 (LA) | Belum dibuat |
| Desain UI10 Daftar & Login dan teks pemberitahuan privasi | PB21 (FE) | Belum ada; teks wajib disetujui PM |
| Success metric | PB22 (finalisasi daftar event) | Belum ditetapkan |
| Konten P01–P10 (teks, foto, audio, video, metadata) | PB07, PB08, PB09 | Belum tersedia |
| Koordinat pintu masuk | PB11, PB12 (LB) | Menunggu survei |
| Urutan Orientation Trail | PB15 (LB) | Belum ditetapkan |
| Dataset fasilitas | PB16 (LB) | Akan dikumpulkan |
| Perangkat uji Android | PB02, PB06, PB18 | Belum ditetapkan |

Jika dependency belum tersedia, kerjakan bagian yang independen dengan fake atau placeholder berlabel, dan catat status `blocked` untuk bagian yang bergantung padanya. Track lain tidak boleh ikut berhenti karena dependency milik satu track.

## 12. Pencatatan Progres

Saat status PBI berubah, perbarui tabel sprint di §4, status di bagian PBI terkait, dan `.agent/sessionHandoff.md`. Untuk Major Progress Review Week 12, laporkan: sprint goal, PBI yang direncanakan, selesai, dan belum selesai, evidence, blocker, serta rencana tindak lanjut.

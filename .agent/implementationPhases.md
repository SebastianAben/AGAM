# Implementation Phases — AGAM v1

| Atribut | Nilai |
| --- | --- |
| Status dokumen | Aktif; status per PBI dicatat di bagian masing-masing |
| Tanggal | 2 November 2026, diperbarui 16 November 2026 |
| Kontrak produk | `.agent/PRD.md`; aturan kerja di `.agent/rules.md` |
| Model kerja | 5 sprint × 1 minggu (Week 10–14), deliverable final Week 15 |
| Pembagian kerja | Tiga track paralel: 1 developer frontend, 2 developer logic aplikasi (lihat §2) |
| Desain layar | UI01–UI09 sudah selesai; UI10 Daftar & Login (ditambahkan 14 November 2026) tersedia sebagai implementasi awal dan menunggu teks privasi serta verifikasi PM |
| Backlog | PB01–PB20 dari PRD resmi, ditambah PB21–PB22 (akun, keputusan PM 6 dan 14 November 2026); ID tidak boleh diubah atau dinomori ulang |
| Current focus | 16 November 2026: verifikasi pemetaan demo Sprint 1–2 dan penyelarasan progres total. APK interaktif terbaru 9675dcf6…5cf6c9e terpasang di OPPO dan cold start command sukses; hash APK perangkat cocok. Smoke visual/playback terbaru belum terkonfirmasi, uji fisik Labtek V tidak tersedia. Empat tab FE tersedia; fitur dengan dependency yang belum nyata tetap dibatasi tanpa note sistem tambahan. |

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

### Rekap total — 24 November 2026

| Cakupan | `done` | `in_progress` | `planned` | Total |
| --- | --- | --- | --- | --- |
| Sprint 1 | 0 | 4 | 0 | 4 |
| Sprint 2 | 0 | 5 | 0 | 5 |
| Sprint 3 | 0 | 5 | 0 | 5 |
| Sprint 4 | 0 | 3 | 2 | 5 |
| Sprint 5 | 0 | 0 | 3 | 3 |
| **Seluruh PBI** | **0** | **17** | **5** | **22** |

PBI aktif: PB01–PB12, PB15–PB17, PB21, PB22. PBI planned: PB13, PB14, PB18–PB20.
Tidak ada PBI berstatus `blocked`/`deferred`; blocker bagian pekerjaan tetap
dicatat pada PBI masing-masing. Angka ini menghitung status deliverable, bukan
persentase kode atau acceptance yang telah terpenuhi. PB17 dikoreksi dari
`planned` ke `in_progress` karena verifikasi offline parsial sudah dijalankan;
tidak ada PBI yang dinaikkan menjadi `done`. Koreksi 24 November 2026: PB21/PB22
tercatat `in_progress` di bagian masing-masing sejak logic LA tersedia, sehingga rekap
Sprint 3 disesuaikan.

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

**Ditulis di kode (branch `LA`, dipulihkan di atas `dev` `dded02b` pada 17 November 2026, belum di-PR):** `lib/contracts/models/account.dart` (`UserRole`, `UserAccount`, `AuthState`, serta `AuthErrorCode`/`AuthException` agar FE dapat memetakan pesan kesalahan), `lib/contracts/models/activity.dart` (`ActivityEvent` sebagai `sealed class` dengan delapan subclass `final`; `ActivityTimePrecision` menentukan `at` atau `date`; `ActivityMode`, `ActivityFeature`; `durationMin` dibulatkan ke 5 menit terdekat), `AuthService` dan `ActivityLogger` di `lib/contracts/services/la_services.dart`, `FakeAuthService` dan `FakeActivityLogger` di `lib/contracts/fakes/fake_la_services.dart`, serta `AppServices.auth`/`activity`. Keputusan rancangan yang perlu direview: event `signUp`/`login`/`logout` dicatat oleh implementasi `AuthService`, bukan UI; `ActivityLogger.log` bersifat `void` (tidak ditunggu, tidak melempar); `deleteAccount` meminta password untuk autentikasi ulang Firebase; mengakhiri sesi saat logout dilakukan perangkaian LA, bukan UI. Pemakai yang ikut diperbarui: `lib/main.dart`, dua baris di `lib/ui/device_app_services.dart` (FE), dan konstruksi `AppServices` di empat test UI (`auth`/`activity` dari `AppServices.fake()`). Tombol "Lihat" tidak masuk kontrak karena `dev` sudah mengopernya lewat parameter `AgamApp.poiViewRequests`. Test: `test/contracts/account_test.dart`.

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
| S2 — Week 11 | Geofence, sesi, trigger, kartu POI, audio | PB05, PB06, PB07, PB08, PB09 | `in_progress` — integrasi demo layanan LA/UI03/UI04 tersedia; simulasi native dan uji HP terdahulu parsial. Trigger fisik, konten lengkap, playback/acceptance belum selesai |
| S3 — Week 12 | Pencarian dan navigasi; akun dan log aktivitas | PB10, PB11, PB12, PB21, PB22 | `in_progress` — pencarian POI repository pada demo tersedia; UI rute pratinjau, routing/navigation masih fake; LA PB12 teruji unit. PB21: login wajib, UI10 dan gerbang login tersambung di jalur produk; hapus akun di UI09 belum. PB22: event akun, `appOpen` dan mode tercatat; `featureUsed`/`trailCompleted` belum |
| S4 — Week 13 | Eyes-free, rekomendasi, trail, fasilitas, offline; Feature Freeze | PB13, PB14, PB15, PB16, PB17 | `in_progress` — PB15 UI pratinjau, PB16 pengaturan nyata/kategori placeholder, PB17 verifikasi offline parsial. PB13/PB14 tetap `planned` |
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
| LA | 1. Workflow rilis APK ke GitHub Releases (PB01). 2. `PermissionService` dan `LocationService` asli: izin akurat, notifikasi, berhenti saat aplikasi diminimalkan (PB02). 3. `PoiRepository`: JSON bawaan 10 POI dari PRD §9.1, validasi, cache lokal, sinkronisasi Firestore (PB03; bagian Firestore dikerjakan setelah project Firebase dibuat 15 November 2026). |
| LB | 1. Script pipeline tile: data OSM → PMTiles area kampus + ±200 m (PB04). 2. File style AGAM. 3. `MapConfig` asli: sumber tile, style, poligon/batas kampus, cek di dalam area; catat batas di PRD §9.3. 4. Verifikasi renderer tile vektor bersama FE. |

**Integrasi akhir sprint:** aplikasi menampilkan peta offline, 10 POI, dan posisi pengguna asli di perangkat fisik.

### PB01 — Project Flutter, repository, pipeline build APK

- **Pemetaan terbaru (16 November 2026):** APK demo 213.041.274 byte, SHA-256 `8ee36167b203d3cd91f165278b85005d1db575840c52c69e88346e3b9098b2f1`, sudah di-install `-r` pada OPPO CPH2739. Hash `base.apk` perangkat diperiksa ulang dan identik. `am start -W` menghasilkan `Status: ok`, `LaunchState: HOT`, membawa task ke depan; PID tersedia. Ini bukan cold start atau bukti seluruh UI/playback bebas crash. CI remote/release terbaru belum diuji.

- **Verifikasi source gabungan (16 November 2026):** Build demo 125,4 detik, APK 185.500.754 byte / SHA-256 `d25348dcff1a6808e6be55c80c5ab6ee39f1085911e65bea47819278f8a926d1`, aset/signature/manifest lulus; install/hash emulator cocok. HEAD `046b646` + perubahan lokal; snapshot 156 file identik. HP terbaru/CI remote belum.

- **APK dan perangkat aktual (15 November 2026):** APK terbaru berflag demo dibangun ulang setelah perbaikan lokasi, 199.109.003 byte / SHA-256 `9373c5906d0f779bfa324c2048969e95f8deac0f7aa6f1437a690a5503f92873`. Build 18,4 detik, audit aset/signature/manifest lulus. Install tanpa hapus data dan launch OPPO CPH2739 Android 16 lulus; hash `base.apk` HP/emulator cocok dengan host. Tidak ada publikasi/CI/rilis baru; status keseluruhan tidak dinaikkan hanya karena demo lokal.
- **Build demo lokal (15 November 2026):** Android SDK disiapkan di `D:\CodexRuntime\agam-android\sdk`; Flutter 3.47.9 berhasil menghasilkan `build/app/outputs/flutter-apk/app-debug.apk` berflag internal, 171.972.503 byte, SHA-256 `e54997a3bd133d933fbbfb968e2a8e7e4696e1107f1563552391099bc305ffce`. Source `dev` HEAD dasar `089883c` + WIP, bukan commit APK bersih. Audit aset APK/signature lulus; install/perangkat fisik dan CI baru belum, status tetap `in_progress`. Recipe toolchain/workaround Kotlin lokal ada di rencana demo/handoff.
- **Track:** LA · **Requirement:** —
- **Sudah dibuat (2 November 2026, branch `chore/pb01-la-scaffolding`):** project Flutter 3.47.9 dikunci via `.fvmrc`; application ID `site.agam`, label "AGAM"; minSdk 24, targetSdk/compileSdk 36; struktur folder §2.3; kerangka `AgamApp` di `lib/ui/app.dart`; workflow `ci.yml` (format, analyze, test, build APK debug sebagai artifact) dan `release.yml` (tag `v*` → APK di GitHub Releases).
- **Pemeriksaan lokal:** `dart format` tanpa perubahan, `flutter analyze` tanpa issue, `flutter test` lulus (saat PB01 berisi 1 test; suite tumbuh seiring PBI berikutnya). Build APK **belum** dijalankan lokal karena Android SDK belum terpasang di mesin setup.
- **CI (terverifikasi 3 November 2026):** workflow `ci.yml` sudah berjalan dan sukses — run 41424657609 (PR #1) dan 41424686250 (`main`), keduanya menghasilkan artifact `agam-debug-apk`. Peringatan deprecation: `actions/checkout@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4` dipaksa ke Node.js 24; `ubuntu-latest` pindah ke Ubuntu 26 pada 19 Oktober 2026.
- **Pembaruan CI (10 November 2026, LA):** action dinaikkan ke `actions/checkout@v7`, `actions/setup-java@v6`, `actions/upload-artifact@v7`, `softprops/action-gh-release@v3` (versi dan catatan rilis diperiksa via GitHub API; perubahan utama runtime Node 24). CI kini juga berjalan pada push ke `dev`. `release.yml` kini menjalankan format dan analyze sebelum test. Workflow baru belum dijalankan di GitHub.
- **Sisa:** smoke UI/playback APK terbaru dan workflow CI/release integrasi terbaru; keystore rilis tetap PB19. Instalasi HP sudah terbukti; jangan memakai bukti APK lama sebagai runtime APK baru.
- **Done:** APK debug terpasang dan dibuka tanpa crash di perangkat uji; workflow CI membangun APK dan mengunggahnya ke Releases.
- **Status:** `in_progress`

### PB02 — Onboarding privasi, izin, dan pembacaan lokasi

- **Redesign UI01 (17 November 2026, branch `feat/onboarding-redesign` atas instruksi pengguna):** onboarding menjadi 4 halaman (Selamat datang, Cerita otomatis, Privasi, Izin) dengan logo resmi dan foto P01/P02/P06, parallax mengikuti geseran, serta animasi sekali jalan yang menghormati reduced motion. "Lewati" hanya menuju halaman izin. Logika izin tetap (lokasi wajib, notifikasi opsional, granted langsung masuk). Panduan optimasi baterai kini tampil di UI01 sebagai baris tidak memblokir (`isBatteryOptimized`/`openBatteryOptimizationSettings`). Analyze bersih, 293 test lulus; render diperiksa lewat golden sementara 390×844 dan 360×640. **Belum** dijalankan di emulator/perangkat. Status PB02 tidak berubah.

- **Verifikasi source gabungan (16 November 2026):** Format/analyze dan suite 254 test lulus; posisi simulasi ±5 m, fallback saat Google Accuracy ditolak dan posisi pada peta offline lulus APK emulator. Pengguna belum dapat uji fisik; bukti HP lama tidak mewakili APK baru.

- **Pengujian Android lanjutan (15 November 2026):** GPS OPPO CPH2739 Android 16 terbaca ±4–14 m; marker terlihat setelah Pusatkan di luar coverage tile kampus. Izin akurat/perkiraan/ditolak, pemulihan Settings, GPS mati→aktif, peta Home/resume dan penghentian pembacaan diuji. Dua defect runtime diperbaiki: fallback geolocator LocationManager ketika Google Accuracy ditolak meskipun GPS aktif, serta pemulihan stream/status GPS dan penghapusan `lastFix` lama. 246 test Flutter lulus; snapshot 138 file source cocok dengan input APK final. Pengguna belum bisa berjalan: gerak GPS fisik di atas tile lokal **belum diuji**, PB02 tetap `in_progress`. Tidak ada koordinat/lintasan/screenshot HP yang dicatat.
- **Verifikasi demo (15 November 2026):** 233 test Flutter dan analyze lulus ulang setelah `pub get --enforce-lockfile`; marker/GPS mati/lifecycle hanya terbukti simulasi widget. Android SDK/emulator/perangkat Android belum terdeteksi, sehingga dialog izin dan GPS fisik Tahap 2 tetap tertunda; status tidak naik.
- **Track:** FE (UI01), LA (`PermissionService`, `LocationService`) · **Requirement:** F01, A01
- **Scope:** layar penjelasan privasi; izin lokasi akurat "saat aplikasi digunakan" dan notifikasi; penanganan izin perkiraan/ditolak; panduan pengaturan baterai pabrikan; pembacaan lokasi mode peta biasa.
- **Done:** izin diminta setelah layar penjelasan; lokasi terbaca dan diperbarui; pembacaan berhenti saat aplikasi diminimalkan.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/location/device_permission_service.dart`: `PermissionService` asli (geolocator + flutter_local_notifications + channel `site.agam/battery` di `MainActivity.kt`). Lokasi perkiraan → `approximateOnly`; permintaan ulang untuk lokasi akurat; tidak pernah meminta izin "sepanjang waktu".
  - `lib/logic/location/device_location_service.dart` + `position_source.dart`: `LocationService` asli. Peta biasa membaca lokasi hanya saat aplikasi tampil dan ada pendengar; berhenti saat diminimalkan; `lastFix` dihapus saat pembacaan berhenti.
  - Manifest: izin lokasi akurat, foreground service `location`/`mediaPlayback`, notifikasi; `ACCESS_BACKGROUND_LOCATION` dihapus eksplisit (`tools:node="remove"`), dijaga `test/android/manifest_privacy_test.dart`.
- **UI01/UI02 FE (14 November 2026):** onboarding meminta izin foreground lalu UI02 menampilkan posisi perangkat saat aplikasi aktif. FE sempat memakai adapter Geolocator sendiri di `lib/ui/device_location_services.dart`.
- **Sisa terkini:** smoke izin/GPS APK terbaru, gerak fisik di atas tile kampus, serta perluasan uji perangkat/optimasi baterai per merek. Bukti OPPO 15 November di atas tetap historis.
- **Integrasi (14 November 2026):** layanan LA tersambung ke UI lewat `lib/main.dart` di branch integrasi.
- **Status:** `in_progress` — logic LA/UI01/lokasi/peta terintegrasi; izin/GPS/lifecycle OPPO diuji; gerak GPS fisik di atas tile lokal/lapangan belum

### PB03 — Dataset 10 POI (Firestore + JSON bawaan)

- **Verifikasi source gabungan (16 November 2026):** Demo kini memakai bootstrap `bundledOnly: true`: JSON APK + memori, tanpa cache konten produksi atau refresh Firestore. Jalur produk default tetap Firestore/cache file. Test memuat 10 POI/P01 tanpa inisialisasi Firebase/path_provider lulus; konten tim tidak diubah.

- **Track:** LA · **Requirement:** F01, F02, F05, A02
- **Scope:** skema final (PRD §15.3); JSON bawaan; validasi dokumen; sinkronisasi Firestore → cache lokal; fallback ke salinan lokal.
- **Dependency eksternal:** project Firebase (`agam-9e704`, dibuat 15 November 2026).
- **Sudah dibuat (3 November 2026, branch `feat/pb03-la-poi-repository`):**
  - Skema final dicatat di PRD §15.3, termasuk tabel aturan validasi dan nilai enum `category`.
  - `assets/data/pois.json`: 10 POI dari PRD §9.1 (id, nama, alias, kategori, koordinat, radius 15 m). Teks dan media berlabel `PLACEHOLDER`, `entrances` kosong, `trailOrder` null, metadata belum disetujui. Didaftarkan di `pubspec.yaml`.
  - `lib/logic/data/poi_codec.dart`: validasi per dokumen; dokumen tidak valid diabaikan satu per satu beserta alasannya (`PoiDecodeIssue`).
  - `lib/logic/data/poi_sources.dart`: `BundledDataset`, `DatasetCache` (`FileDatasetCache` dan `InMemoryDatasetCache`), serta `RemoteDatasetSource` dengan `UnavailableRemoteSource` selama project Firebase belum ada.
  - `lib/logic/data/poi_repository_impl.dart`: `PoiRepository` asli dengan urutan cache → bawaan, `refresh()` yang tidak pernah melempar, dan dataset tanpa POI valid tidak dipakai maupun di-cache.
- **Pemeriksaan (lokal, Flutter 3.47.9 via FVM):** `dart format --set-exit-if-changed` tanpa perubahan; `flutter analyze` tanpa issue; `flutter test` 67 test lulus (56 baru + 11 test kontrak). Test dataset bawaan diverifikasi benar-benar menangkap kesalahan dengan sengaja mengubah satu koordinat, lalu dipulihkan.
- **Sisa saat itu (3 November 2026):** sinkronisasi Firestore menunggu project Firebase; direktori cache menunggu package penyedia path (diselesaikan 10 November 2026). Sisa terkini ada di bawah.
- **Done:** data 10 POI terbaca dari server dan dari cache lokal; dokumen tidak valid diabaikan; aplikasi berjalan saat offline.
- **Pembaruan 10 November 2026:** `path_provider` ^2.1.6 ditambahkan; `lib/logic/la_bootstrap.dart` memakai `getApplicationSupportDirectory()` untuk `FileDatasetCache`.
- **Firestore (15 November 2026, branch `feat/pb03-firestore-setup`):**
  - FlutterFire CLI mendaftarkan `site.agam` ke `agam-9e704` (`lib/firebase_options.dart`, `android/app/google-services.json`, plugin Gradle Google Services); `Firebase.initializeApp` di `lib/main.dart`; izin `INTERNET` di manifest.
  - `lib/logic/data/firestore_dataset_source.dart`: `FirestoreDatasetSource` membaca `pois` dan `facilities` dari server; `la_bootstrap.dart` memasangnya dan menjalankan `refresh()` di latar setelah data lokal dimuat. Sebelumnya `refresh()` tidak dipanggil di mana pun.
  - `firestore.rules` (PRD §15.4–§15.5) dengan 21 test emulator di `tools/firestore/rules.test.mjs`; sudah di-deploy ke `agam-9e704`.
  - Seed `tools/firestore/seed_pois.mjs` dan workflow `.github/workflows/seed-firestore.yml` (PRD §15.2); diuji di emulator.
- **Seed pertama (15 November 2026):** dari `pois.json` `dev` `d602fed` memakai service account `agam-seed` (Cloud Datastore User); 10 dokumen `pois`, 0 `facilities`. Pemeriksaan REST: `pois` terbaca tanpa login, `users` ditolak (HTTP 403).
- **Sisa:** build APK dan uji perangkat (membaca dari server, cache, offline). Seed otomatis lewat `.github/workflows/seed-firestore.yml` berjalan sukses pada 24 November 2026 (run untuk `9faf7f4` dan `80add99`), sehingga secret dan Actions sudah tersedia. Usulan untuk LA: pembanding versi dataset agar cache lama tidak menutupi JSON bawaan yang lebih baru (PRD §15.2).
- **Status:** `in_progress` — JSON bawaan, validasi, cache, fallback, dan sumber Firestore tersedia; repository yang sama dipakai oleh demo untuk marker/trigger/detail. Uji pada perangkat Android terhadap tree gabungan belum dijalankan.

### PB04 — Explore Map dengan tile vektor dibundel

- Paket LB pada 24 November 2026 menyiapkan style peta jalan kaki dengan
  kedalaman skematis, tile native z12–18, PNG 512 px dan bounds yang dapat
  dipakai kamera FE. PB04 tetap `in_progress`.

- **Penyesuaian APK (16 November 2026):** kontrol utara/pusat lokasi/lapisan POI kini berfungsi pada peta lokal; bentuk/posisi FE dipertahankan. Watermark mode uji 8 px dan kredit peta 9 px dipisah dari kanvas/header ke footer. Regresi kontrol, footer 320/430 px dan pencarian-ke-peta lulus; 257 test, analyze, build demo/audit/signature lulus. APK `d54d2b51…24b515` terpasang di OPPO, hash perangkat cocok, cold start command sukses. Visual/playback/manual dan field belum terkonfirmasi; bukan completion PB04.

- **Perapian UI demo (16 November 2026):** chip Mode uji di header, kredit OSM/ODbL dan OpenMapTiles tetap terlihat/bertautan, kontrol kanan dikembalikan langsung ke FE `5db4dd4` (39/42 px, gap 7 px, inset 12 px). Copy dummy diringkas dengan label tetap. Format/analyze, 257 test Flutter serta regresi UI 320/430 px lulus; build demo dan audit APK lulus. Runtime Android terbaru belum diuji; status PBI tetap `in_progress`. Evidence/hash ada di [rencana demo §6](demo-apk-temporary-plan.md#6-progress-log).

- **Verifikasi source gabungan (16 November 2026):** APK source gabungan `046b646` + perubahan lokal dibangun/diaudit; cold start mode pesawat menampilkan peta/atribusi/penanda/posisi simulasi pada emulator API 36. Counter UID online IPv4/IPv6 0 paket/0 byte; belum audit HP/field.

- **Runtime APK (15 November 2026):** cold start mode pesawat (Wi-Fi/data mati, GPS aktif) pada OPPO Android 16; pengguna mengonfirmasi basemap/atribusi/P01 serta pan/zoom tampil dan bisa diinteraksi. Emulator juga lulus cold start offline dan perubahan posisi simulasi. Bundling tiga aset APK final diaudit ulang; marker GPS HP terlihat setelah Pusatkan di luar coverage, gerak di atas tile lokal dan batas layanan produk tetap belum terbukti.
- **Lanjutan build/audit (15 November 2026):** SDK dipasang; build internal **berhasil** setelah incremental Kotlin dinonaktifkan pada Gradle user home khusus di luar repo. Audit `--apk` memastikan tiga aset peta identik dengan source, signature APK valid. Tidak mengubah source/kontrak/config tracked. Runtime pan/zoom/offline/perangkat tetap belum diuji; `in_progress` dipertahankan. Catatan SDK gagal di bawah adalah percobaan sebelumnya.
- **Verifikasi demo (15 November 2026):** audit aset sumber dan 21 test pipeline lulus ulang. Build demo gagal sebelum Gradle (`No Android SDK found`); APK target tidak ada, sehingga audit `--apk`, pan/zoom/marker/atribusi/offline pada Android tetap tertunda. Hash aset bukan hash APK; `in_progress` tetap berlaku.
- **Track:** LB (pipeline tile, style, `MapConfig`), FE (UI02) · **Requirement:** F01, A03
- **Brief:** [PB04-LB-01 — pipeline OSM ke PMTiles](../task-implementation/backend/PB04-LB-01-tile-pipeline.md).
- **Ada di source (4 November 2026):** pipeline PowerShell/Python di `tools/tiles/`, generator Planetiler v0.10.2 terverifikasi SHA-256, snapshot batas OSM `way/177629384`, coverage kampus + 200 m, validator arsip dan manifest. Tidak mengubah kontrak, UI, atau dependency Flutter.
- **Verifikasi lokal:** 18 test tooling lulus; dua build data nyata/cache menghasilkan PMTiles identik (1.035.927 bytes, 13 tile zoom 12–16); validator penuh dan CLI resmi `pmtiles verify` lulus. Manifest di `assets/map/ganesha.manifest.json`; command, checksum, peringatan sumber, dan batas evidence di handoff.
- **Sisa terkini:** smoke peta APK terbaru, pergerakan GPS fisik di atas tile dan field acceptance. Style, konfigurasi engineering demo, aset dan renderer sudah terintegrasi. Batas layanan produk ditetapkan 24 November 2026: `AgamMapConfig.campus()` = bounds engineering OSM + 200 m (PRD §9.3), belum diverifikasi lapangan.
- **UI02 FE (14 November 2026):** kerangka Explore Map dengan penanda POI dan posisi; peta masih ilustrasi skematis berlabel, belum merender PMTiles.
- **Done:** peta tampil offline setelah login pertama; 10 POI dan posisi pengguna yang bergerak terlihat; script tile dapat dijalankan ulang; ukuran tile tercatat.
- **Integrasi demo lokal (14 November 2026):** WIP `AgamMapConfig`, style, test, dan audit LB disalin ke checkout integrasi tanpa mengubah worktree LB. Pipeline kini melakukan clustering deterministik; PMTiles 1.022.885 byte, SHA-256 `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`, seluruh 13 payload/metadata tetap sama dengan arsip awal. `OfflineMapTiles` + `OfflineCampusMap` merender vektor ke memori dengan `flutter_map 7.0.2`, `vector_tile_renderer 5.2.0`, `pmtiles 1.3.0`; tidak memakai layer/cache disk `vector_map_tiles`. Aset terdaftar, atribusi bertautan, marker repository, pan dan overzoom 19 lulus widget. 233 test Flutter, 21 test pipeline, analyze, audit aset tanpa APK, dan CLI verify lulus. Batas layanan produk tetap TBD; demo eksplisit memakai coverage engineering bersumber sesuai PRD §9.3.
- **Status:** `in_progress` — build/install/peta offline Android diuji; batas layanan produk ditetapkan (24 November 2026); pergerakan GPS di atas tile lokal dan field test belum terbukti


## 6. Sprint 2 — Geofence, Sesi, Trigger, Kartu POI, dan Audio

| Track | Langkah |
| --- | --- |
| FE | 1. Tombol mulai/akhiri sesi Explore dan indikator sesi aktif (PB06). 2. UI03 tampilan trigger: Dengarkan/Lihat/Lewati, notifikasi ringkas (PB06). 3. UI04 Kartu POI: foto, fungsi, fasilitas, trivia, sumber, pemutar video GKUB/GKUT; dibuka dari trigger dan dari peta (PB07). 4. Kontrol pemutar narasi di kartu (PB08). |
| LA | 1. Engine geofence: haversine, dwell, cooldown, histeresis, filter akurasi, interval adaptif, beserta unit test (PB05). 2. `SessionController`: foreground service tipe `location`, notifikasi tetap, trigger saat layar mati, tombol Akhiri, auto-end 30 menit, respons per mode (PB06). 3. Notifikasi trigger dan getar (PB06). 4. `AudioService`: narasi, prompt, kontrol dari notifikasi dan lock screen, auto-play (PB08). 5. Format aset konten dan validasi metadata A02 untuk tim konten (PB09). |
| LB | 1. Bangun graf jalur kampus (GeoJSON) dari data OSM; tandai bagian yang perlu dikoreksi survei (persiapan PB11). 2. `RoutingService`: Dijkstra/A* atas graf, beserta unit test (persiapan PB11). 3. `SearchService`: normalisasi, Arab ↔ Romawi, alias, filter kategori, beserta unit test (persiapan PB10). |

**Integrasi akhir sprint:** di perangkat fisik, memulai Explore lalu berjalan ke POI memunculkan trigger (juga saat layar mati), kartu POI terbuka, dan narasi dapat diputar.

LB mengerjakan persiapan Sprint 3 di Sprint 2 karena tidak ada PBI Sprint 2 yang menjadi milik LB.

### PB05 — Engine geofence in-app

- **Pembaruan area kontak (16 November 2026):** titik trigger diperluas menjadi lingkaran 5 m, jarak pendekatan per POI tetap 15 m pada dataset; engine masuk efektif ≤20 m dan keluar >25 m dari pusat. Dwell/cooldown/pengunci/akurasi dipertahankan. Status tetap `in_progress`; kalibrasi fisik belum. Verifikasi: 290 test lulus, analyze bersih, APK demo berhasil dibangun dan audit tiga aset peta lulus. Instalasi update OPPO CPH2739 sukses; setelah USB/debugging dipulihkan, cold start ok 2405 ms, hash APK perangkat cocok, proses aktif dan tanpa crash/unhandled error pada pemeriksaan terbatas. Publikasi source LB b5c6938 → dev 096b940 berhasil; 290 test lulus ulang hasil merge. Bukan evidence lapangan.

- **Mode demo/trial developer (16 November 2026):** pengunci kunjungan tetap
  mencegah trigger berulang walaupun diam >10 menit. Sakelar Pengaturan pada
  build internal mereset/melewati cooldown selama aktif; tetap membutuhkan
  exit histeresis lalu re-entry dan dwell. Default mati, hanya di memori,
  controller produk tidak dapat mengaktifkannya. PB05/PB06 tetap `in_progress`;
  acceptance fisik belum berubah. Perilaku uji dicatat di PRD §9.2/§23.

- **Perbaikan trigger (16 November 2026):** snapshot ID aktif engine kini
  diteruskan oleh sesi melalui kemampuan opsional LA `PoiTriggerLifecycle` untuk
  menonaktifkan kartu/notifikasi saat keluar histeresis, keluar kampus,
  perubahan dataset atau akhir sesi. Input buruk tidak melepas pengunci;
  cooldown 10 menit/dwell 5 detik/radius tetap. Regresi sesi dan widget
  exit/re-entry lulus; bukan evidence GPS fisik. Status tetap `in_progress`.

- **Verifikasi source gabungan (16 November 2026):** Suite 254 test lulus; APK emulator P01 dwell → UI03/UI04 dan background P02 → notifikasi native → kartu benar, tanpa perubahan threshold. Belum GPS fisik P01; pengguna belum dapat field test.

- **Perbaikan/verifikasi runtime (15 November 2026):** kehilangan GPS kini memutus dwell lewat `interruptDwell()` tanpa menghapus pengunci kunjungan/cooldown atau mengarang fix. Regression mencakup dwell terputus dan tidak terpicu ulang setelah hilang GPS walau cooldown telah lewat. Suite total 246 lulus; APK emulator memicu P01 setelah dwell, tidak pada pemeriksaan 4,05 detik, dan tidak mengulang saat tetap di area/reentry selama cooldown. Semua nilai PRD dipertahankan; ini **simulasi**, belum trigger/kalibrasi GPS fisik Labtek V.
- **Verifikasi demo (15 November 2026):** seluruh 233 test Flutter lulus ulang, termasuk engine dan alur simulasi P01. Radius 15 m / akurasi maksimal 20 m / dwell 5 detik / cooldown 10 menit dipertahankan. Build terhalang SDK; belum ada bukti trigger GPS fisik atau kalibrasi, tetap `in_progress`.
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

- **Pembaruan visibilitas (16 November 2026):** Explore/Trail saat resumed memakai kartu otomatis + audio; notifikasi sistem dipakai di latar belakang/layar mati. Navigasi tetap ringkas tanpa audio/kartu otomatis. Status tetap `in_progress`; uji HP terbaru belum.

- **Perbaikan trigger (16 November 2026):** exit menghapus notifikasi,
  menghentikan prompt terkait dan menutup panel otomatis. Revisi per POI
  membatalkan respons terlambat sesudah Dengarkan/Lihat/Lewati/exit; guard
  membatalkan aksi async setelah akhir sesi. Narasi yang dipilih pengguna
  tetap berjalan saat keluar; panel manual tetap dapat dipakai. Seluruh
  282 test proyek lulus termasuk regresi ini; retest HP/field belum dilakukan.

- **Audit interaksi (16 November 2026):** aksi kartu Lihat/Lewati/Dengarkan tersambung ke `TriggerResponder.handleAction` yang sama dengan notifikasi Android, melalui callback UI tanpa perubahan kontrak. Lihat menghapus notifikasi POI sebelum membuka detail; Lewati menutupnya dan menghentikan prompt yang cocok. Respons native yang masih pending setelah Akhiri tidak boleh memulai prompt/notifikasi terlambat (regresi deterministik). Izin notifikasi/pengaturan baterai dapat dibuka dari Pengaturan. Bukan bukti trigger/notifikasi fisik terbaru.

- **Verifikasi source gabungan (16 November 2026):** Explore/service lokasi tipe 0x8, P01 foreground dan native Lihat P02 dari background lulus emulator. Akhiri + Home: registrasi lokasi 0/service lokasi tidak ada. Service media tipe 0x2 masih ada setelah prompt; bukan semua service berhenti. Trafik UID online 0 paket/0 byte, audit HP belum.

- **Native/perangkat (15 November 2026):** APK final diuji pada emulator Android 16 dan OPPO CPH2739 Android 16. Emulator P01→UI03/UI04 dan native Lihat dari background cocok; P02 terpicu ketika Dozing dan native Lihat cocok. Pada HP di luar kampus, Explore menunjukkan request/service/notifikasi sesi aktif; dua snapshot layar benar-benar Dozing tetap aktif. Akhiri saat peta tampil menghilangkan service sesi, kemudian Android Home menghasilkan request/service/notifikasi 0. Pencabutan izin melalui Settings saat Explore juga menghasilkan semuanya 0; `pm revoke` ditolak OEM dan tidak diakali. Cabang GPS off→on di background tidak diklaim pulih otomatis (restart menunggu foreground). Trigger/notifikasi P01 **fisik** belum diuji; audit jaringan fisik lengkap belum tersedia.
- **Verifikasi demo (15 November 2026):** alur P01→UI03→UI04, view P02, GPS mati dan akhir sesi lulus ulang dalam suite widget. Belum ada APK/emulator/perangkat Android yang siap dipakai; service native, izin/lifecycle Android, background/cold start, notifikasi/layar mati dan audit privasi runtime tetap belum diuji. Tahap 3 dan status `in_progress` dipertahankan.
- **Track:** LA (`SessionController`, notifikasi), FE (UI03, kontrol sesi) · **Requirement:** F02, F04, A01
- **Done:** notifikasi dan prompt muncul ≤10 detik setelah masuk radius, termasuk saat layar mati di perangkat fisik; tidak ada pembacaan lokasi di luar sesi kecuali mode peta biasa di layar.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/session/device_session_controller.dart`: `SessionController` asli. Foreground service tipe `location` lewat geolocator; ganti mode tanpa memulai ulang service; `end()` menghentikan lokasi dan service; auto-end 30 menit di luar kampus (memakai `MapConfig.isInsideCampus` dari LB); izin dicabut → `permissionRevoked`; trigger nonaktif di luar area; Navigasi → `brief`, Explore/Trail → `full`; cooldown bertahan antar-sesi.
  - `lib/logic/session/trigger_notifier.dart`: notifikasi trigger (getar, prioritas tinggi, tombol Dengarkan/Lihat/Lewati, terlihat di lock screen) dan notifikasi ringkas tanpa suara. Tombol tanpa membuka aplikasi diteruskan dari isolate latar belakang plugin ke isolate utama lewat `IsolateNameServer`.
  - `lib/logic/session/trigger_responder.dart`: respons per mode; prompt audio atau narasi langsung bila auto-play aktif; `viewRequests` untuk FE membuka kartu POI.
- **UI03 FE (14 November 2026):** kartu trigger Dengarkan/Lihat/Lewati di atas UI02 dan kontrol sesi.
- **Sisa terkini:** smoke APK terbaru, trigger/notifikasi GPS fisik P01 dan audit privasi HP; simulasi native serta service/lifecycle OPPO terdahulu sudah diuji sebagaimana evidence di atas. Teks notifikasi masih rumusan developer dari skenario PRD §5.
- **Integrasi (14 November 2026):** `DeviceSessionController`/`TriggerResponder` memakai MapConfig demo engineering OSM. `viewRequests` diteruskan dari `main.dart` melalui parameter widget ke UI04 tanpa perubahan kontrak. Uji widget memakai controller/lokasi/repository asli dengan sumber GPS simulasi: menolak akurasi 30 m, tidak trigger sebelum dwell 5 detik, P01 membuka detail P01, permintaan notifikasi P02 membuka detail P02, Akhiri mengakhiri service sesi, dan GPS mati menghapus marker.
- **Status:** `in_progress` — native emulator dan service/lifecycle/izin OPPO diuji; trigger/notifikasi/kartu GPS fisik P01 dan field acceptance belum

### PB07 — Kartu POI

- **Pembaruan kartu otomatis (16 November 2026):** kartu memilih POI terdekat di antara trigger aktif, membuka tab Jelajah dari tab lain, dan tampil saat kembali dari latar belakang bila trigger masih aktif. Exit/akhir sesi menutup panel otomatis; Lewati/Back menutup sampai kunjungan berikutnya. Status tetap `in_progress`.

- **Audit interaksi (16 November 2026):** handle kini bisa ditap/ditarik; panel native memiliki extent 35/65/90%, scroll konten dan scrollbar interaktif memakai controller sama. Panel tetap menempel navigasi bawah; Back menutupnya lebih dulu. Transisi enter/exit dan tab mempertahankan state; panel keluar tidak menangkap sentuhan. Regresi gesture/scroll offset, reduced motion dan alur Explore tetap tersedia. Tidak ada label sistem tambahan atau konten baru.

- **Perapian UI (16 November 2026):** panel POI di peta kini full-width dan bottom 0, menempel langsung ke navigasi utama. Mode uji dipindah ke header 8 px, kredit peta bertautan ke atas kanvas 9 px; tidak ada footer di bawah panel. Catatan teknis/label placeholder tambahan di layar demo dihapus sesuai instruksi PM, sementara data belum approved tetap disembunyikan dan aksi tanpa layanan nonaktif. Regresi 320/430 px membuktikan batas bawah panel = batas atas navigasi; status PBI tetap `in_progress`.

- **Verifikasi source gabungan (16 November 2026):** APK emulator membuka kartu P01/P02 sesuai trigger/notifikasi. Foto P01 memakai aset tim yang sudah approved di dataset; regression UI memeriksa foto tersebut dan fixture placeholder terpisah. Tidak mengubah persetujuan konten; trigger GPS nyata belum.

- **APK Android (15 November 2026):** emulator P01 dari trigger/UI03 dan native Lihat membuka UI04 P01; P02 dari native juga benar. Pada HP OPPO Android 16, marker P01→Lihat membuka Labtek V dengan PLACEHOLDER, termasuk saat mode pesawat/Wi-Fi/data mati. Ini kartu manual dari repository yang sama, **bukan** bukti kartu dari trigger GPS fisik. Konten/media final belum tersedia.
- **Verifikasi demo (15 November 2026):** kartu P01/P02 lulus ulang dalam simulasi widget; APK build terhalang SDK, sehingga kartu dari trigger GPS fisik belum terbukti. Placeholder dan status `in_progress` dipertahankan.
- **Pemutar video (24 November 2026, branch `feat/poi-video-player`):** UI04 kini menampilkan bagian "Video" di bawah Narasi bila POI approved dan `media.video` terisi (saat ini hanya P06 GKUB; video GKUT tidak dipakai). Widget `lib/ui/widgets/agam_video_player.dart` memakai `video_player` 2.14.1 (aset APK): controller baru dibuat saat diketuk (tanpa autoplay), putar/jeda, progres yang dapat digeser, layar penuh dengan controller yang sama, pesan galat + "Coba lagi"; video menjeda audio POI yang sedang diputar dan audio POI yang mulai diputar menjeda video; jeda otomatis saat aplikasi ke latar belakang ditangani `video_player`. Status: **ada di source + automated test lulus** (analyze bersih, 398 test). Belum diuji di APK/perangkat (Mac ini tanpa Android SDK), sehingga syarat "video dapat diputar" belum terbukti.
- **Track:** FE (UI04); data dari `PoiRepository` (LA) · **Requirement:** F03
- **Done:** kartu terbuka dari trigger dan dari peta dengan konten sesuai; video GKUB/GKUT dapat diputar.
- **Status:** `in_progress` — UI04 memakai ID repository yang sama; kartu manual HP terdahulu dan kartu emulator teruji. P01/P02 approved pada JSON, P03–P10 placeholder/unapproved; pengakuan P02 sebagai konten final masih perlu rekonsiliasi pemilik konten. Video GKUB/GKUT dan kartu dari trigger GPS fisik belum; navigasi demo nonaktif.

### PB08 — Pemutar narasi audio

- **Perbaikan playback (16 November 2026):** intent klip tersedia sebelum
  lookup async; stop/load/restart lama tidak menimpa klip/intent baru. Handler
  pause sebelum mengganti sumber, memuat dari nol dan mengulang dari awal
  saat play media ditekan pada completed. Regresi dengan player sintetis
  lulus dalam 282 test proyek; playback/notifikasi/lock screen HP perlu retest.

- **Audit interaksi (16 November 2026):** UI04 memakai playback aktual untuk play/pause/resume, ulang, stop, slider seek dan lompat ±10 detik; auto-play memakai SettingsStore yang sama dengan Pengaturan. Seek dibatasi durasi dan menjaga intent terbaru; jeda saat load/seek/replay tidak boleh tertimpa penyelesaian async lama. Layanan audio menolak metadata belum approved meskipun path aset ada. Widget/unit regression lulus; playback/lock screen fisik terbaru tetap perlu pengujian.

- **Track:** LA (`AudioService`), FE (kontrol di kartu) · **Requirement:** F03, F04
- **Done:** narasi dapat dikendalikan dari kartu dan notifikasi.
- **Ada di source (10 November 2026, LA):** `lib/logic/audio/device_audio_service.dart` (`AudioService` asli; path dari `Poi.media`; konten placeholder → `PlaybackStatus.error` tanpa crash) dan `lib/logic/audio/agam_audio_handler.dart` (`just_audio` + `audio_service`; putar/jeda/berhenti dari notifikasi media dan lock screen). `MainActivity` diturunkan dari `AudioServiceActivity`.
- **Kontrol di kartu (FE, 14 November 2026):** UI04 memanggil `AudioService`; kontrol aktif bila file narasi POI tersedia.
- **Audit source (16 November 2026):** file narasi/prompt/tiba tersedia untuk P01–P10 (30 file `.m4a`), dengan path dalam JSON. P01/P02 `approved: true`, P03–P10 `isPlaceholder: true`/unapproved. Kehadiran file bukan bukti durasi 45–90 detik, hak penggunaan, persetujuan isi atau playback Android. UI04 menjaga audio dengan metadata approval; rekonsiliasi P02 tetap pada pemilik konten/PM.
- **Sisa:** playback/jeda/ulang dan kontrol notifikasi/lock screen pada APK terbaru di HP; audit durasi/konten/hak dan approval seluruh POI (PB09).
- **Integrasi (14 November 2026):** `DeviceAudioService` tersambung ke kontrol UI04 lewat `lib/main.dart`.
- **Status:** `in_progress` — logic LA, kontrol UI04 dan aset audio tersedia; kelengkapan/approval konten dan playback perangkat terbaru belum selesai

### PB09 — Produksi konten 10 POI

- **Track:** di luar track developer; LA menyiapkan format dan validasi · **Requirement:** F03, A02
- **Catatan:** agent dilarang membuat konten ini.
- **Bagian LA (10 November 2026):** format aset dan aturan validasi untuk tim konten di [PB09-LA-01](../task-implementation/backend/PB09-LA-01-content-format.md); pemeriksaan otomatis `test/logic/data/content_assets_test.dart`.
- **Done:** konten 10 POI lengkap, sumber tercatat, hak penggunaan media aman, disetujui tim.
- **Audit source (16 November 2026):** 10 POI; 30 file audio; enam foto pada P01/P02/P06 (dua per POI); field video seluruh POI kosong. JSON menandai P01/P02 approved/non-placeholder dan P03–P10 placeholder/unapproved. Ini inventaris source, bukan persetujuan baru dari agent. P02 belum disebut pada catatan approval PRD sebelumnya; pemilik konten/PM perlu merekonsiliasi sebelum klaim final. Konten/metadata tidak diubah.
- **Pembaruan 23 November 2026 (pemilik konten):** foto P03 (Labtek VII) dan P04 (Labtek VIII) oleh Noeriza Aqila Wibawa; foto P05 (Labtek X & XI) dari situs resmi ITB, dicantumkan "Foto: Institut Teknologi Bandung (itb.ac.id)"; pemilik konten menyatakan penggunaan foto publik situs ITB diperbolehkan untuk proyek ini (belum ada keputusan PM tertulis). Foto dikonversi ke JPG tanpa data GPS. P03–P05 disetujui pemilik konten dan ditandai approved/non-placeholder. Sisa: foto P07 GKUT, P08 Oktagon, P09 TVST, P10 Labtek I; video GKUB/GKUT; nama GKUT tidak konsisten ("Paragon Innovation" di deskripsi, "Paragon Foundation" di trivia).
- **Keputusan PM 23 November 2026 (disampaikan pemilik konten):** video GKUB/GKUT opsional; konten boleh disetujui tanpa video (PRD F03, §9.1, §23). P06 GKUB disetujui pemilik konten.
- **Media tambahan 23 November 2026 (pemilik konten):** foto P08 Oktagon, P09 TVST, P10 Labtek I dari Google Maps dan video P06 GKUB dari TikTok; pemilik konten memutuskan memakainya dengan kredit eksplisit ("Foto: Google Maps", "Video: TikTok"). Foto GKUT (screenshot Street View) dan video GKUT tidak dipakai. Foto P10 memperlihatkan papan "SPITM"; pemilik konten memastikan itu Labtek I dari sisi lain. P08–P10 disetujui pemilik konten.
- **GKUT (23 November 2026):** foto P07 dari Google Maps Street View ("Foto: Google Maps (Street View)"), papan gedung bertuliskan "Gedung Kuliah Umum Timur Paragon Innovation"; atas persetujuan pemilik konten, trivia P07 dikoreksi dari "Paragon Foundation" menjadi "Paragon Innovation". P07 disetujui pemilik konten; 10/10 POI approved.
- **Status:** `in_progress` — 10/10 POI approved di JSON; seed Firestore otomatis sudah berjalan (24 November 2026); video P06 GKUB ada di kartu; keputusan video opsional tercatat di PRD §23. Tersisa uji tampilan/playback di perangkat dan pencatatan oleh PM di Change Log PRD resmi

## 7. Sprint 3 — Pencarian, Navigasi, dan Akun

| Track | Langkah |
| --- | --- |
| FE | 1. UI05 Pencarian dan filter kategori (PB10). 2. UI06 Navigasi: garis rute, jarak, ETA, langkah berikutnya, keadaan menyimpang/rerouting (PB11). 3. Tampilan tiba (bagian awal UI07) (PB12). 4. Rapikan UI01–UI06 untuk Major Progress Review. 5. UI10 Daftar & Login, gerbang login sebelum UI01, info akun, logout, dan hapus akun di UI09 (PB21). 6. Event `featureUsed` untuk kartu POI, narasi, dan fasilitas (PB22). |
| LA | 1. `VoiceGuidance`: TTS `id-ID`, deteksi ketersediaan suara, fallback visual (PB12). 2. Putar audio pengumuman tiba saat `NavigationState` tiba (PB12). 3. Mode Navigasi di `SessionController`: POI lain hanya notifikasi ringkas tanpa audio (PB06/PB11). 4. Usulan kontrak v1.1 (§3.3). 5. Setup Firebase di aplikasi, `AuthService`, profil `users/{uid}`, penyimpanan lokal per akun, rules Firestore beserta test (PB21). 6. `ActivityLogger` serta event akun, `appOpen`, dan mode (PB22). |
| LB | 1. `NavigationController`: posisi → `NavigationState`, reroute >25 m, tiba ≤15 m (PB11). 2. Koreksi graf jalur dan titik pintu masuk dari survei bila sudah tersedia; jika belum, pakai titik tengah gedung berlabel placeholder (PB11). 3. Integrasi `SearchService` dengan data asli (PB10). 4. Event `featureUsed` pencarian dan `trailCompleted` saat `SearchService` dan `TrailService` asli dibuat; progres trail disimpan per akun (PB22). |

**Syarat akun di Sprint 3:** project Firebase dengan Firestore dan Authentication sudah dibuat di awal minggu, dan kontrak v1.1 disepakati ketiga track sebelum FE dan LB memakainya. Gerbang login hanya di-merge ke `dev` setelah lengkap, supaya demo Major Progress Review tidak terhalang login yang setengah jadi.

**Integrasi akhir sprint:** mencari "labtek 5", menavigasi ke Labtek V dengan arahan suara, dan menerima pengumuman tiba di perangkat fisik. Hasilnya dipakai untuk Major Progress Review. Jika PB21 sudah lengkap, alur dimulai dari daftar/login.

### PB10 — Pencarian dengan alias dan filter kategori

- **Audit interaksi (16 November 2026):** ikon filter membuka pemilih kategori nyata yang mengubah query/filter layanan; tombol hapus mereset query/tujuan. Transisi tab memakai package resmi Flutter animations, state query dan layanan dipertahankan. Regresi kategori → hasil dan clear query tersedia; tidak mengaktifkan routing/fasilitas fake.

- **Penyesuaian APK (16 November 2026):** hasil POI demo memakai kartu PMTiles nyata; Tampilkan di peta memusatkan/menyorot ID repository yang sama di Jelajah, tanpa memulai navigasi atau mengganti Explore. CTA detail/audio tetap ada; dummy ilustrasi rute diganti. Regresi P02/kamera dan isolasi sesi lulus. Graf/routing/fasilitas tetap tertunda; bukan completion PB10/PB11.

- **Track:** LB (`SearchService`), FE (UI05) · **Requirement:** F05
- **Done:** "labtek 5", "Labtek V", "lab 5" → Labtek V teratas; respons ≤1 detik.
- **Integrasi layanan produk (19 November 2026):** `PoiSearchService` mencari POI dan fasilitas dengan metadata approved, filter kategori, normalisasi angka Romawi, dan hasil stabil. Dataset bawaan berisi 10 POI. Test lokal mencakup alias, keadaan fasilitas kosong, fasilitas placeholder, dan batas respons ≤1 detik. Dataset fasilitas versi pertama (26 item, disetujui 24 November 2026) kini di `assets/data/pois.json`; letak persis dan verifikasi lapangan tetap tertunda.
- **Status:** `in_progress` — logic pencarian produk tersedia di `SearchService`; pengujian UI lintas branch dan acceptance fasilitas masih menunggu integrasi FE/data tim konten.

### PB11 — Navigasi jalan kaki di perangkat

- Paket LB pada 24 November 2026 menyiapkan graf draf dari layer jalur putih,
  Dijkstra yang dibatasi ruas graf dan deteksi tiba di ujung rute demo.
  Integrasi bootstrap dan verifikasi lapangan tertunda. PB11 tetap `in_progress`.

- **Titik akses (24 November 2026, branch `feat/access-points-trail-data`):** tujuan rute kini *titik akses* (pintu atau sisi lantai 1 yang terbuka), [CL] di PRD F06/§11. `tools/routing/plan_access_points.py` menghitung satu kandidat per gedung dari jaringan utama graf draf dan mengisi `entrances[]` dengan `verified: false`; daftar cek lapangan di `task-implementation/backend/PB11-access-point-field-check.md`. Kontrak `PoiEntrance.verified` ditambahkan: `hasSurveyedEntrance` hanya benar untuk titik terverifikasi, sedangkan `navigationPoint` memakai kandidat. Temuan: graf draf terdiri atas 17 potongan; titik terdekat Labtek V berada di potongan terisolasi (4 simpul) dan GKUT berjarak 26 m dari jaringan utama (di atas batas snap 25 m), sehingga perangkaian routing harus memakai jaringan utama atau titik akses.
- **Track:** LB (graf, `RoutingService`, `NavigationController`), FE (UI06), LA (sesi Navigasi) · **Requirement:** F06, A01
- **Dependency eksternal:** verifikasi titik akses di lapangan.
- **Done:** rute tampil ke titik akses tujuan yang sudah diverifikasi; rerouting berjalan; tidak ada request routing ke server.
- **Status:** `in_progress` — `CampusRoutingService` dan `DeviceNavigationController` asli tersedia. Dijkstra, langkah, ETA, reroute >25 m, tiba ≤15 m, serta pembatalan perhitungan tertunda lulus test fixture sintetis. Integrasi UI/LA dan verifikasi lapangan belum selesai. Aktivasi rute produk menunggu graf jalan bersumber dan koordinat pintu masuk hasil survei; batas layanan produk ditetapkan 24 November 2026 (PRD §9.3).

### PB12 — Arahan suara navigasi dan deteksi tiba

- **Track:** LA (`VoiceGuidance`, audio tiba), LB (event tiba), FE (tampilan tiba) · **Requirement:** F04, F06
- **Done:** arahan suara di setiap belokan; pengumuman tiba saat ≤15 m dari tujuan.
- **Ada di source (10 November 2026, LA):**
  - `lib/logic/audio/device_voice_guidance.dart`: `VoiceGuidance` asli dengan `flutter_tts` ^4.2.5, locale `id-ID`. Dianggap tersedia hanya jika suara `id-ID` **offline** terpasang (`isLanguageInstalled`); jika tidak, diam dan UI memakai arahan visual. Arahan baru menggantikan ucapan lama (QUEUE_FLUSH). Manifest menambah query `TTS_SERVICE` sesuai README plugin.
  - `lib/logic/audio/navigation_announcer.dart`: mendengarkan `NavigationState` (LB); membacakan `RouteStep.instruction` sekali per langkah dan saat rute baru setelah rerouting; langkah `arrive` tidak dibacakan; saat tiba, TTS dihentikan lalu file audio tiba POI diputar lewat `AudioService`.
  - Mode Navigasi di `SessionController` (POI lain hanya notifikasi ringkas) sudah selesai di PB06.
- **Keputusan 24 November 2026:** tiba di fasilitas diumumkan dengan TTS runtime ("Anda telah tiba di {nama fasilitas}"), fallback visual bila suara `id-ID` tidak tersedia ([CL] PRD §10/§23). **Belum:** implementasi pengumuman tersebut, tampilan tiba di layar Cari & Rute (saat ini baru di layar Trail), integrasi dengan routing asli (PB11), dan uji perangkat.
- **Status:** `in_progress` — logic LA selesai dan teruji unit dengan navigasi palsu

### PB21 — Akun dan login wajib

- **Asal:** tidak ada di PRD resmi; ditambahkan atas keputusan PM (6 dan 14 November 2026). Wajib dicatat di Change Log PRD resmi (PRD §23).
- **Track:** LA (`AuthService`, profil `users/{uid}`, penyimpanan lokal per akun, rules Firestore dan test-nya, setup Firebase, DI), FE (UI10, gerbang login, akun di UI09), LB (penyimpanan progres trail per akun) · **Requirement:** A01 · **[CL]**
- **Scope:** daftar dengan email, password, pilihan role, dan persetujuan pemberitahuan privasi; login; lupa password lewat email reset; logout; hapus akun (profil, log, data lokal milik akun, akun Auth); pesan offline saat login pertama; sesi login bertahan setelah aplikasi ditutup; progres lokal per akun (PRD §15.1). Tanpa verifikasi email.
- **Dependency:** project Firebase (Firestore + Authentication Email/Password); kontrak v1.1 (§3.3); teks pemberitahuan privasi disetujui PM; desain UI10.
- **Done:** pengguna baru tidak dapat masuk tanpa daftar/login; setelah login pertama aplikasi dapat dipakai dalam mode pesawat; logout kembali ke UI10 tanpa menghapus progres, dan login kembali dengan akun yang sama memulihkan progres; akun lain di perangkat yang sama tidak melihat progres akun pertama; hapus akun menghapus profil, log, dan data lokalnya; test rules dengan emulator menolak akses ke profil pengguna lain.
- **Ada di source LA (17 November 2026, branch `LA` commit "feat: PB21 PB22 add Firebase account…", belum di-push):**
  - `lib/logic/account/auth_gateway.dart`: `FirebaseAuthGateway` (firebase_auth ^7.1.0) dan pemetaan kode error ke `AuthErrorCode`; email/password salah tidak dibedakan.
  - `lib/logic/account/profile_store.dart`: `FirestoreProfileStore` (`users/{uid}`: `role`, `createdAt` server timestamp) dan `LocalAccountStore` (salinan role per `uid` agar sesi yang dipulihkan berjalan dalam mode pesawat).
  - `lib/logic/account/device_auth_service.dart`: `DeviceAuthService` (`AuthService` asli): daftar membatalkan akun Auth bila profil gagal dibuat; login tanpa profil ditolak; `restore()` memulihkan sesi saat cold start; logout mengakhiri sesi, mencatat `logout`, menunggu log terkirim (maks. 3 detik), lalu keluar; hapus akun: autentikasi ulang → akhiri sesi tanpa log → hapus log → profil → data lokal → akun Auth.
  - `lib/logic/settings/device_settings_store.dart`: pengaturan per `uid` (`switchAccount`, `clearAccount`); sebelum akun dipakai tetap memakai kunci perangkat agar demo tidak berubah.
  - `lib/logic/account/account_bootstrap.dart`: `createLaAccountServices(la)`; pengaturan mengikuti akun, akun yang keluar dari luar aplikasi ikut mengakhiri sesi.
  - Test: `test/logic/account/device_auth_service_test.dart`, tambahan per akun di `test/logic/settings/device_settings_store_test.dart`.
- **Pembaruan 24 November 2026:** jalur produk `lib/main.dart` memakai `createLaAccountServices` (akun asli); UI10 `lib/ui/auth_screen.dart` dan gerbang login di `lib/ui/app.dart` tersambung (`test/ui/auth_gate_test.dart`). **Belum:** tombol hapus akun di UI09, progres trail per akun dalam perangkaian produk (PB15), test rules emulator (`tools/firestore/rules.test.mjs`, Firebase CLI tidak terpasang di mesin ini), dan uji perangkat dengan project `agam-9e704`.
- **Status:** `in_progress` — login wajib tersambung di jalur produk; hapus akun di UI09, test rules emulator, dan uji perangkat belum

### PB22 — Log aktivitas internal

- **Asal:** tidak ada di PRD resmi; ditambahkan atas keputusan PM (6 dan 14 November 2026). Wajib dicatat di Change Log PRD resmi (PRD §23).
- **Track:** LA (`ActivityLogger`, event `signUp`/`login`/`logout`/`appOpen`/`modeStart`/`modeEnd`, rules `hasOnly`), FE (event `featureUsed` untuk kartu POI, narasi, fasilitas), LB (event `featureUsed` pencarian dan `trailCompleted`) · **Requirement:** A01 · **[CL]**
- **Scope:** seluruh event PRD §15.5 dengan field yang diizinkan saja; antrean offline; `appOpen` hanya saat cold start; event mode dan trail selesai hanya bertanggal.
- **Dependency:** PB21; `SearchService` dan `TrailService` asli (LB) untuk event LB. Jika belum tersedia di Sprint 3, bagian LB pindah ke Sprint 4, tetap sebelum Feature Freeze.
- **Done:** setiap event PRD §15.5 tercatat dengan field yang benar; test rules dengan emulator menolak dokumen berfield tambahan (mis. `lat`) dan dokumen dengan `uid` milik orang lain; pemeriksaan lalu lintas jaringan menunjukkan tidak ada koordinat, ID POI, atau tujuan yang terkirim.
- **Ada di source LA (17 November 2026, branch `LA` commit "feat: PB21 PB22 add Firebase account…", belum di-push):**
  - `lib/logic/account/firestore_activity_logger.dart`: `FirestoreActivityLogger` (`activity_logs`, tidak ditunggu dan tidak melempar; antrean offline dari cache Firestore; event tanpa akun diabaikan; `flush`, `deleteAllFor`). `activityLogDocument` membentuk dokumen persis seperti `hasExactly` di `firestore.rules`; `date` memakai tanggal lokal perangkat.
  - `lib/logic/account/activity_recorders.dart`: `SessionActivityRecorder` (`modeStart`/`modeEnd` dari `SessionController`, ganti mode = akhir lama + awal baru, tanpa alasan berakhir) dan `AppOpenRecorder` (sekali per proses; bila belum login dicatat saat login pertama; tidak dicatat bila aplikasi dibuka dari notifikasi trigger). Info perangkat dari package_info_plus ^10.2.2 dan device_info_plus ^13.3.0, dipotong 1–64 karakter.
  - Test: `test/logic/account/activity_log_test.dart` (field per event dibandingkan dengan daftar rules; uji mutasi: menyisipkan `lat` menggagalkan 8 test).
- **Belum:** event `featureUsed` (pencarian, kartu POI, narasi, fasilitas) dan `trailCompleted` belum dipanggil di mana pun; test rules emulator dan pemeriksaan lalu lintas jaringan di perangkat. Event akun, `appOpen`, dan mode sudah dicatat di jalur produk lewat `createLaAccountServices`.
- **Status:** `in_progress` — bagian LA tersedia dan teruji unit

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
- **Urutan trail (24 November 2026):** keliling terpendek antar-titik akses (1.536 m pada graf draf) diisi ke `trailOrder` 1–10: Labtek V → Labtek VIII → Labtek VII → GKU Timur → Labtek I → Oktagon → Labtek X & XI → TVST → Labtek VI → GKU Barat. Trail dimulai dari POI terdekat dengan pengguna lalu searah putaran ([CL] PRD F08/§12). **Belum:** rotasi urutan dan penyimpanan titik awal per akun di `DeviceTrailService`, perangkaian di `main.dart` (masih `UnavailableTrailService`), dan `_canRoute` yang kini menolak titik akses kandidat (`hasSurveyedEntrance` false) sehingga trail tidak dapat dimulai sebelum verifikasi.
- **Dependency eksternal:** verifikasi titik akses di lapangan.
- **Done:** progres tersimpan setelah aplikasi ditutup; lencana muncul saat 10/10.
- **Status:** `in_progress` — UI08 FE tersedia. Demo membaca POI repository dengan urutan contoh sintetis dan progres kosong, tanpa berlangganan progres/navigation fake. Aksi Mulai/Pilih rute hanya menjelaskan dependency; test membuktikan Explore aktif tidak diganti. Trail resmi, penyimpanan progres, check-in, lencana dan acceptance belum selesai.

### PB16 — Fasilitas terdekat

- **Pengaturan developer (16 November 2026):** satu sakelar Mode demo/trial
  tersambung ke controller asli, hanya pada build internal; default mati dan
  tidak disimpan. Reset/melewati cooldown untuk uji re-entry tanpa menghapus
  pengunci saat diam atau validasi dwell/lokasi. Seluruh 286 test lulus,
  termasuk wiring Pengaturan → sesi → re-entry dan pemisahan UI produk.
  Tidak menambah fasilitas atau mengubah status PBI; retest HP belum.

- **Track:** LB (`FacilityService`), FE (UI09), LA (data fasilitas di `PoiRepository`) · **Requirement:** F05, F07 · **Prioritas:** Should
- **Dependency eksternal:** dataset fasilitas.
- **Status:** `in_progress` — kategori fasilitas dan placeholder FE tampil; UI09 auto-play/Akhiri tersambung SettingsStore/SessionController LA dan diuji widget. Dataset fasilitas/layanan terdekat serta acceptance F05/F07 belum tersedia.

### PB17 — Verifikasi akses offline

- **Track:** semua · **Requirement:** A03 · **Prioritas:** Could
- **Done:** trigger, kartu POI, peta, dan navigasi berfungsi dalam mode pesawat tanpa crash.
- **Evidence parsial:** cold start mode pesawat pada HP 15 November membuktikan peta/atribusi/marker/kartu manual APK lama; emulator 16 November membuktikan peta/posisi simulasi APK sebelum frontend terbaru. Demo terbaru menggunakan JSON bawaan + memori dan aset peta/media lokal, tanpa refresh Firestore dari Dart; regression bootstrap tersedia. Bukti ini tidak menguji login/cache produk atau navigasi nyata.
- **Status:** `in_progress` — koreksi pencatatan pekerjaan offline yang sudah dimulai; smoke offline APK terbaru, playback, trigger fisik, login pertama/cache produk dan navigasi offline masih tertunda

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
| Project Firebase (Firestore + Authentication Email/Password) | PB03, PB21, PB22 (LA) | Dibuat 15 November 2026 (`agam-9e704`) |
| Desain UI10 Daftar & Login dan teks pemberitahuan privasi | PB21 (FE) | Implementasi awal tersedia; teks pemberitahuan privasi wajib disetujui PM |
| Success metric | PB22 (finalisasi daftar event) | Belum ditetapkan |
| Konten P01–P10 (teks, foto, audio, video, metadata) | PB07, PB08, PB09 | Sebagian tersedia; P01/P02 approved pada JSON, P03–P10 placeholder/unapproved; video belum ada. Approval P02 perlu rekonsiliasi pemilik konten/PM; kelengkapan dan hak seluruh konten belum diterima |
| Koordinat pintu masuk | PB11, PB12 (LB) | Menunggu survei |
| Urutan Orientation Trail | PB15 (LB) | Belum ditetapkan |
| Dataset fasilitas | PB16 (LB) | Akan dikumpulkan |
| Perangkat uji Android | PB02, PB06, PB18 | OPPO CPH2739 Android 16 tersedia untuk demo; komposisi perangkat acceptance belum ditetapkan, akses field Labtek V belum tersedia |

Jika dependency belum tersedia, kerjakan bagian yang independen dengan fake atau placeholder berlabel, dan catat status `blocked` untuk bagian yang bergantung padanya. Track lain tidak boleh ikut berhenti karena dependency milik satu track.

## 12. Pencatatan Progres

Saat status PBI berubah, perbarui tabel sprint di §4, status di bagian PBI terkait, dan `.agent/sessionHandoff.md`. Untuk Major Progress Review Week 12, laporkan: sprint goal, PBI yang direncanakan, selesai, dan belum selesai, evidence, blocker, serta rencana tindak lanjut.

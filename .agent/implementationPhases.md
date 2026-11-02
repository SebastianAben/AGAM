# Implementation Phases — AGAM v1

| Atribut | Nilai |
| --- | --- |
| Status dokumen | Rencana awal; seluruh PBI `planned` |
| Tanggal | 2 November 2026 |
| Kontrak produk | `.agent/PRD.md`; aturan kerja di `.agent/rules.md` |
| Model kerja | 5 sprint × 1 minggu (Week 10–14), deliverable final Week 15 |
| Pembagian kerja | Tiga track paralel: 1 developer frontend, 2 developer logic aplikasi (lihat §2) |
| Desain layar | UI01–UI09 sudah selesai; frontend tinggal mengimplementasikan |
| Backlog | PB01–PB20 dari PRD resmi; ID tidak boleh diubah atau dinomori ulang |
| Current focus | Belum dimulai; langkah pertama adalah Sprint 1 Hari 1–2 (§5) |

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

AGAM tidak memiliki server. "Logic" berarti lapisan logika dan data **di dalam aplikasi**.

| Track | Developer | Tanggung jawab |
| --- | --- | --- |
| **FE** — Frontend | 1 | Seluruh layar UI01–UI09, navigasi antarlayar, state UI, dan penyambungan ke antarmuka logic |
| **LA** — Logic A: lokasi, sesi, data, audio | 1 | Project & CI, izin dan layanan lokasi, data POI/Firestore, geofence, sesi & foreground service, notifikasi, audio, TTS, pengaturan |
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

Untuk menghindari konflik merge, setiap track hanya mengubah foldernya sendiri. Struktur final ditetapkan saat PB01; usulan awal:

| Folder | Pemilik |
| --- | --- |
| `lib/contracts/` (model, antarmuka, fake) | Bersama; perubahan mengikuti §2.4 |
| `lib/ui/` | FE |
| `lib/logic/location/`, `lib/logic/session/`, `lib/logic/data/`, `lib/logic/audio/`, `lib/logic/settings/` | LA |
| `lib/logic/map/`, `lib/logic/routing/`, `lib/logic/search/`, `lib/logic/trail/` | LB |
| `lib/main.dart`, dependency injection, `pubspec.yaml`, `android/`, `.github/` | LA; perubahan oleh track lain lewat PR yang direview LA |
| `tools/tiles/`, `assets/map/`, `assets/routing/` | LB |
| `assets/data/`, `assets/media/` | LA (isi konten dari tim konten) |
| `test/` | Mengikuti folder yang diuji |

### 2.4 Perubahan kontrak

- Perubahan pada `lib/contracts/` dilakukan lewat PR tersendiri yang **disetujui oleh kedua track lain** sebelum di-merge.
- Perubahan yang merusak (mengganti nama, menghapus field/metode, mengubah perilaku) wajib memperbarui fake dan semua pemakai dalam PR yang sama.
- Menambah field atau metode baru boleh dilakukan selama tidak merusak pemakai yang sudah ada.
- Jika kontrak ternyata tidak cukup di tengah sprint, track terkait berdiskusi dulu, bukan mengubah sepihak.

### 2.5 Alur kerja per PBI

Setiap developer mengikuti langkah yang sama untuk setiap bagian PBI:

1. Tarik `main` terbaru.
2. Baca `.agent/rules.md`, `.agent/sessionHandoff.md`, dan bagian PBI terkait di dokumen ini serta PRD.
3. Buat branch dari `main` dengan pola `<jenis>/pbXX-<track>-<topik>`, misalnya `feat/pb05-la-geofence` atau `feat/pb07-fe-poi-card`.
4. Kerjakan hanya di folder milik track sendiri (§2.3). Jika butuh perubahan kontrak, ikuti §2.4.
5. Jalankan `flutter analyze` dan test yang relevan.
6. Buka PR ke `main` dengan deskripsi: PBI, apa yang berubah, cara menguji, dan keterbatasan.
7. PR direview minimal oleh satu developer lain sebelum di-merge.
8. Perbarui status PBI di dokumen ini dan catatan di `.agent/sessionHandoff.md`.

### 2.6 Integrasi akhir sprint

Pada hari terakhir setiap sprint:

1. Semua PR sprint tersebut di-merge ke `main`.
2. FE mengganti fake dengan implementasi asli untuk fitur sprint itu.
3. Ketiga developer menguji alur sprint di perangkat fisik.
4. Defect integrasi dicatat; yang tidak selesai pindah ke sprint berikutnya dengan status yang jujur.
5. APK hasil integrasi dibangun oleh CI sebagai bukti sprint.

## 3. Kontrak Awal

Nama dan bentuk final ditetapkan pada Sprint 1 Hari 1–2 dan dicatat di sini. Daftar di bawah adalah titik awal.

### 3.1 Model data

| Model | Isi utama | Pemilik |
| --- | --- | --- |
| `GeoPoint` | lat, lng | Bersama |
| `LocationFix` | posisi, akurasi (m), waktu | LA |
| `Poi` | id, nama, alias, kategori, posisi, radius, pintu masuk, teks, fasilitas, path media, metadata A02 | LA |
| `Facility` | id, nama, kategori, posisi, gedung terkait, metadata | LA |
| `SessionState` | mode (`none`, `explore`, `navigation`, `trail`), aktif/tidak, alasan berakhir | LA |
| `PoiTriggerEvent` | id POI, mode saat trigger, jenis respons (penuh / ringkas tanpa audio) | LA |
| `Route`, `RouteStep` | garis rute, jarak, ETA, langkah belokan | LB |
| `NavigationState` | di rute / menyimpang / rerouting / tiba, sisa jarak, langkah berikutnya | LB |
| `SearchResult` | POI atau fasilitas, skor | LB |
| `Recommendation` | 1–3 POI dan fasilitas terdekat | LB |
| `TrailProgress` | urutan, POI dikunjungi, x/10, lencana | LB |
| `AppSettings` | auto-play narasi, dsb. | LA |

### 3.2 Antarmuka layanan

| Antarmuka | Fungsi untuk FE | Pemilik |
| --- | --- | --- |
| `PermissionService` | Status dan permintaan izin lokasi akurat & notifikasi; deteksi izin perkiraan | LA |
| `LocationService` | Aliran posisi untuk mode peta biasa (hanya saat layar tampil) | LA |
| `PoiRepository` | Daftar POI dan fasilitas (bawaan + Firestore + cache) | LA |
| `SessionController` | Mulai/akhiri sesi per mode, aliran `SessionState` dan `PoiTriggerEvent`, auto-end 30 menit | LA |
| `AudioService` | Putar/jeda/ulang narasi, prompt, pengumuman tiba; kontrol dari notifikasi | LA |
| `VoiceGuidance` | Membacakan arahan navigasi (TTS `id-ID`), status ketersediaan suara | LA |
| `SettingsStore` | Baca/simpan pengaturan; hapus progres lokal | LA |
| `MapConfig` | Sumber tile dan style, batas area kampus, cek di dalam/luar area | LB |
| `RoutingService` | Hitung rute dari posisi ke tujuan | LB |
| `NavigationController` | Mulai/berhenti navigasi, aliran `NavigationState`, reroute >25 m, tiba ≤15 m | LB |
| `SearchService` | Pencarian dengan alias dan filter kategori | LB |
| `RecommendationService` | Rekomendasi setelah kartu ditutup/tiba | LB |
| `TrailService` | Mulai trail, POI berikutnya, progres, lencana; check-in dari `PoiTriggerEvent` | LB |
| `FacilityService` | Fasilitas terdekat per kategori | LB |

Titik sambung antar-logic: `TrailService` (LB) mendengarkan `PoiTriggerEvent` dari `SessionController` (LA); `NavigationController` (LB) memakai posisi dari layanan lokasi LA; `VoiceGuidance` (LA) membacakan langkah dari `NavigationState` (LB).

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
| S1 — Week 10 | Kontrak, fondasi aplikasi, lokasi, peta | PB01, PB02, PB03, PB04 | `planned` |
| S2 — Week 11 | Geofence, sesi, trigger, kartu POI, audio | PB05, PB06, PB07, PB08, PB09 | `planned` |
| S3 — Week 12 | Pencarian dan navigasi | PB10, PB11, PB12 | `planned` |
| S4 — Week 13 | Eyes-free, rekomendasi, trail, fasilitas, offline; Feature Freeze | PB13, PB14, PB15, PB16, PB17 | `planned` |
| S5 — Week 14 | Uji acceptance, perbaikan, rilis v1.0 | PB18, PB19, PB20 | `planned` |

## 5. Sprint 1 — Kontrak, Fondasi, Lokasi, dan Peta

**Hari 1–2 (bersama, wajib sebelum kerja paralel):**

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
- **Verifikasi saat setup:** versi Flutter/Dart, minSdk yang didukung, `targetSdk`.
- **Done:** APK debug terpasang dan dibuka tanpa crash di perangkat uji; workflow CI membangun APK dan mengunggahnya ke Releases.
- **Status:** `planned`

### PB02 — Onboarding privasi, izin, dan pembacaan lokasi

- **Track:** FE (UI01), LA (`PermissionService`, `LocationService`) · **Requirement:** F01, A01
- **Scope:** layar penjelasan privasi; izin lokasi akurat "saat aplikasi digunakan" dan notifikasi; penanganan izin perkiraan/ditolak; panduan pengaturan baterai pabrikan; pembacaan lokasi mode peta biasa.
- **Done:** izin diminta setelah layar penjelasan; lokasi terbaca dan diperbarui; pembacaan berhenti saat aplikasi diminimalkan.
- **Status:** `planned`

### PB03 — Dataset 10 POI (Firestore + JSON bawaan)

- **Track:** LA · **Requirement:** F01, F02, F05, A02
- **Scope:** skema final (PRD §15.3); JSON bawaan; validasi dokumen; sinkronisasi Firestore → cache lokal; fallback ke salinan lokal.
- **Dependency eksternal:** project Firebase (belum dibuat).
- **Done:** data 10 POI terbaca dari server dan dari cache lokal; dokumen tidak valid diabaikan; aplikasi berjalan saat offline.
- **Status:** `planned`

### PB04 — Explore Map dengan tile vektor dibundel

- **Track:** LB (pipeline tile, style, `MapConfig`), FE (UI02) · **Requirement:** F01, A03
- **Done:** peta tampil offline sejak instalasi; 10 POI dan posisi pengguna yang bergerak terlihat; script tile dapat dijalankan ulang; ukuran tile tercatat.
- **Status:** `planned`

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
- **Done:** unit test lulus dengan nilai yang dihitung independen; trigger tepat pada POI uji.
- **Status:** `planned`

### PB06 — Sesi lokasi, notifikasi, getar, dan prompt saat trigger

- **Track:** LA (`SessionController`, notifikasi), FE (UI03, kontrol sesi) · **Requirement:** F02, F04, A01
- **Done:** notifikasi dan prompt muncul ≤10 detik setelah masuk radius, termasuk saat layar mati di perangkat fisik; tidak ada pembacaan lokasi di luar sesi kecuali mode peta biasa di layar.
- **Status:** `planned`

### PB07 — Kartu POI

- **Track:** FE (UI04); data dari `PoiRepository` (LA) · **Requirement:** F03
- **Done:** kartu terbuka dari trigger dan dari peta dengan konten sesuai; video GKUB/GKUT dapat diputar.
- **Status:** `planned`

### PB08 — Pemutar narasi audio

- **Track:** LA (`AudioService`), FE (kontrol di kartu) · **Requirement:** F03, F04
- **Done:** narasi dapat dikendalikan dari kartu dan notifikasi.
- **Status:** `planned`

### PB09 — Produksi konten 10 POI

- **Track:** di luar track developer; LA menyiapkan format dan validasi · **Requirement:** F03, A02
- **Catatan:** agent dilarang membuat konten ini.
- **Done:** konten 10 POI lengkap, sumber tercatat, hak penggunaan media aman, disetujui tim.
- **Status:** `planned`

## 7. Sprint 3 — Pencarian dan Navigasi

| Track | Langkah |
| --- | --- |
| FE | 1. UI05 Pencarian dan filter kategori (PB10). 2. UI06 Navigasi: garis rute, jarak, ETA, langkah berikutnya, keadaan menyimpang/rerouting (PB11). 3. Tampilan tiba (bagian awal UI07) (PB12). 4. Rapikan UI01–UI06 untuk Major Progress Review. |
| LA | 1. `VoiceGuidance`: TTS `id-ID`, deteksi ketersediaan suara, fallback visual (PB12). 2. Putar audio pengumuman tiba saat `NavigationState` tiba (PB12). 3. Mode Navigasi di `SessionController`: POI lain hanya notifikasi ringkas tanpa audio (PB06/PB11). |
| LB | 1. `NavigationController`: posisi → `NavigationState`, reroute >25 m, tiba ≤15 m (PB11). 2. Koreksi graf jalur dan titik pintu masuk dari survei bila sudah tersedia; jika belum, pakai titik tengah gedung berlabel placeholder (PB11). 3. Integrasi `SearchService` dengan data asli (PB10). |

**Integrasi akhir sprint:** mencari "labtek 5", menavigasi ke Labtek V dengan arahan suara, dan menerima pengumuman tiba di perangkat fisik. Hasilnya dipakai untuk Major Progress Review.

### PB10 — Pencarian dengan alias dan filter kategori

- **Track:** LB (`SearchService`), FE (UI05) · **Requirement:** F05
- **Done:** "labtek 5", "Labtek V", "lab 5" → Labtek V teratas; respons ≤1 detik.
- **Status:** `planned`

### PB11 — Navigasi jalan kaki di perangkat

- **Track:** LB (graf, `RoutingService`, `NavigationController`), FE (UI06), LA (sesi Navigasi) · **Requirement:** F06, A01
- **Dependency eksternal:** koordinat pintu masuk (survei).
- **Done:** rute tampil ke pintu masuk tujuan; rerouting berjalan; tidak ada request routing ke server.
- **Status:** `planned`

### PB12 — Arahan suara navigasi dan deteksi tiba

- **Track:** LA (`VoiceGuidance`, audio tiba), LB (event tiba), FE (tampilan tiba) · **Requirement:** F04, F06
- **Done:** arahan suara di setiap belokan; pengumuman tiba saat ≤15 m dari tujuan.
- **Status:** `planned`

## 8. Sprint 4 — Eyes-free, Rekomendasi, Trail, Fasilitas; Feature Freeze

| Track | Langkah |
| --- | --- |
| FE | 1. UI07 Rekomendasi setelah kartu ditutup/tiba, navigasi satu ketukan (PB14). 2. UI08 Orientation Trail: urutan, progres x/10, lencana (PB15). 3. UI09 Fasilitas & pengaturan: daftar fasilitas, auto-play, akhiri sesi, hapus progres (PB16). 4. Mode eyes-free: tombol besar dan alur tanpa membaca layar (PB13). 5. Keadaan offline yang jelas di semua layar (PB17). |
| LA | 1. Kontrol eyes-free dari notifikasi dan lock screen; auto-play (PB13). 2. `SettingsStore` dan hapus progres lokal (PB16/A01). 3. Mode Trail di `SessionController` (PB15). 4. Uji offline: mode pesawat untuk data, media, trigger (PB17). |
| LB | 1. `RecommendationService` (PB14). 2. `TrailService`: urutan, navigasi berantai, check-in dari `PoiTriggerEvent` termasuk di luar urutan, progres tersimpan, lencana (PB15). 3. `FacilityService` (PB16; bergantung pada dataset fasilitas). 4. Uji offline peta dan navigasi (PB17). |

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
- **Status:** `planned`

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
| A01 Privacy & Session Control | PB02, PB06, PB11 | Pemeriksaan penyimpanan dan lalu lintas jaringan |
| A02 Content Traceability | PB03, PB07, PB09 | Metadata lengkap pada 10 POI |
| A03 Offline Information Access | PB03, PB04, PB17 | Uji mode pesawat |

## 11. Dependency Eksternal

| Dependency | Dibutuhkan oleh | Status |
| --- | --- | --- |
| Project Firebase | PB03 (LA) | Belum dibuat |
| Konten P01–P10 (teks, foto, audio, video, metadata) | PB07, PB08, PB09 | Belum tersedia |
| Koordinat pintu masuk | PB11, PB12 (LB) | Menunggu survei |
| Urutan Orientation Trail | PB15 (LB) | Belum ditetapkan |
| Dataset fasilitas | PB16 (LB) | Akan dikumpulkan |
| Perangkat uji Android | PB02, PB06, PB18 | Belum ditetapkan |

Jika dependency belum tersedia, kerjakan bagian yang independen dengan fake atau placeholder berlabel, dan catat status `blocked` untuk bagian yang bergantung padanya. Track lain tidak boleh ikut berhenti karena dependency milik satu track.

## 12. Pencatatan Progres

Saat status PBI berubah, perbarui tabel sprint di §4, status di bagian PBI terkait, dan `.agent/sessionHandoff.md`. Untuk Major Progress Review Week 12, laporkan: sprint goal, PBI yang direncanakan, selesai, dan belum selesai, evidence, blocker, serta rencana tindak lanjut.

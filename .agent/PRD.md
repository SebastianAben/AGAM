# Product Requirements Document (PRD): AGAM — Aplikasi Ganesha Map

| Atribut | Nilai |
| --- | --- |
| Status dokumen | **Kontrak produk kerja v1.0** untuk tim dan coding agent; diturunkan dari PRD resmi dan diperbarui dengan keputusan tim |
| Status implementasi | Belum ada implementasi. Repository baru berisi dokumentasi (2 November 2026) |
| Tanggal | 2 November 2026 |
| Sumber resmi | Draft PRD W9 (`Kelompok 03_Draft PRD.docx.pdf`, bagian 1–4) dan presentasi PRD lengkap (`Transformasi Digital-PRD-Kel.Warung.pdf`, halaman 1–23). Keduanya berada di luar repository |
| Mata kuliah | II4011 Transformasi Digital — Prof. Ir. Kridanto Surendro, M.Sc., Ph.D. |
| Tim | Kelompok 03 / Warung; keputusan produk dipegang Project Manager |
| Platform | Aplikasi mobile Android (APK) |
| Stack | Flutter / Dart, Fused Location Provider (`geolocator`), OpenStreetMap (tile vektor dibundel), Firebase Firestore + JSON bawaan, `flutter_tts` |

Kata **wajib**, **dilarang**, **sebaiknya**, dan **dapat** bersifat normatif. Requirement di dokumen ini adalah **target**; tidak ada yang boleh dilaporkan sebagai selesai tanpa evidence (lihat `.agent/rules.md`).

**Hubungan dengan PRD resmi.** Dokumen ini adalah satu-satunya acuan kerja di repository. Jika berbeda dengan PDF/PPT resmi, dokumen ini yang berlaku. Setiap perbedaan terhadap baseline W9 ditandai **[CL]** dan dirangkum di [§23](#23-perbedaan-terhadap-prd-baseline-w9); perbedaan tersebut wajib dicatat oleh PM pada Change Log PRD resmi.

**Peta baca:** [mode & sesi](#6-mode-aplikasi-dan-sesi-lokasi), [requirement](#7-functional-requirements-f01f08), [POI & trigger](#9-poi-dan-location-trigger), [konten](#10-konten-dan-media), [navigasi](#11-navigasi-dan-routing), [peta](#14-peta), [data](#15-data-dan-penyimpanan), [arsitektur](#17-arsitektur-teknis), [hal tertunda](#22-hal-tertunda-tbd).

---

## 1. Ringkasan

AGAM adalah aplikasi pemandu kampus berbasis lokasi untuk **ITB Kampus Ganesha**. Berbeda dari aplikasi peta umum, AGAM berfokus pada **Point of Interest (POI)**: ketika pengguna mendekati gedung, aplikasi otomatis memberi tahu dan menyajikan informasi gedung tersebut (foto, teks, narasi audio). AGAM juga menyediakan pencarian gedung/fasilitas dengan alias, navigasi jalan kaki, rekomendasi POI berikutnya, dan Orientation Trail untuk mahasiswa baru.

Seluruh perhitungan (lokasi, geofence, rute, pencarian, rekomendasi) dilakukan **di perangkat**. Posisi pengguna tidak pernah dikirim ke server mana pun.

## 2. Masalah dan Peluang

- Kampus Ganesha memiliki banyak gedung dengan nama/nomor mirip (Labtek V–VIII, Labtek X–XI, GKU Barat/Timur).
- Peta statis dan papan petunjuk terbatas; aplikasi peta umum tidak mengenali nama internal kampus dan tidak menjelaskan fungsi gedung.
- Informasi gedung, layanan, dan fasilitas (toilet, musala, kantin, ATM, perpustakaan, layanan akademik) tersebar dan tidak tersedia saat pengguna berada di dekat gedung.
- Dampak: pengguna tersesat, terlambat, dan berulang kali bertanya atau mencari di internet. Setiap awal tahun akademik ribuan mahasiswa baru harus beradaptasi dalam waktu singkat.

**Peluang transformasi digital:** dari *pengguna mencari informasi* menjadi *informasi datang sesuai posisi pengguna*.

## 3. Target Pengguna

| Pengguna | Karakteristik | Kebutuhan utama |
| --- | --- | --- |
| Mahasiswa baru / yang belum familiar dengan Ganesha | Belum mengenal tata letak kampus; berpindah gedung antarkelas dengan waktu sempit | Menemukan gedung/ruang kuliah dengan cepat, memahami fungsi gedung, mengetahui fasilitas terdekat |
| Pengunjung (calon mahasiswa, orang tua, tamu acara/seminar) | Datang sesekali dengan waktu terbatas | Menuju gedung tujuan tanpa banyak bertanya dan memperoleh informasi fasilitas gedung |

## 4. Tujuan dan Non-Tujuan

| ID | Tujuan |
| --- | --- |
| G01 | Memberikan informasi gedung secara otomatis dan kontekstual ketika pengguna mendekati POI |
| G02 | Membantu pengguna mencari dan menuju gedung atau fasilitas dengan rute jalan kaki |
| G03 | Menyediakan pengalaman eksplorasi melalui prompt suara dan narasi audio |
| G04 | Membantu mahasiswa baru mengenal kampus melalui Orientation Trail dan rekomendasi POI berikutnya |

| ID | Non-tujuan |
| --- | --- |
| NG01 | Tidak menyediakan navigasi indoor sampai ruang kelas |
| NG02 | Tidak menggantikan sistem informasi akademik (jadwal, peminjaman ruang, presensi) |
| NG03 | Versi awal tidak menyediakan augmented reality |
| NG04 | Tidak mengirim, menyimpan di server, atau membagikan riwayat lokasi pengguna kepada pihak lain |

Di luar lingkup v1 (keputusan tim): **login/akun/role pengguna**, **bahasa selain Bahasa Indonesia**, dan **backend milik tim**.

## 5. Skenario Utama

Raka (18 tahun, mahasiswa baru S1 Teknik Informatika) datang pertama kali ke Ganesha:

1. **Onboarding.** Membuka AGAM; aplikasi menjelaskan bahwa lokasi hanya diproses di ponsel, lalu meminta izin lokasi (akurat) dan notifikasi.
2. **Peta.** Peta kampus, posisi Raka, dan penanda 10 POI tampil.
3. **Mulai sesi.** Raka memilih Orientation Trail (atau Explore) dan mulai berjalan.
4. **Trigger.** Saat masuk radius 15 m dari GKUT dan bertahan ≥5 detik, ponsel bergetar dan terdengar prompt: *"Anda mendekati Gedung Kuliah Umum Timur. Apakah Anda ingin mendengarkan ceritanya?"*
5. **Eksplorasi.** Raka mengetuk tombol besar **Dengarkan**; kartu POI terbuka (foto, fungsi, fasilitas, trivia) dan narasi diputar. POI tercatat "dikunjungi"; selama Raka masih di area, trigger tidak berulang.
6. **Pencarian.** Raka mengetik "labtek 5"; aplikasi mengenali alias sebagai Labtek V.
7. **Navigasi.** Rute jalan kaki, jarak, ETA, dan arahan suara di setiap belokan tampil. POI lain yang dilewati hanya memunculkan notifikasi ringkas tanpa audio.
8. **Tiba.** Dalam jarak ≤15 m dari pintu masuk Labtek V, aplikasi mengumumkan *"Anda telah tiba di Labtek V"*, menawarkan kartu informasi, merekomendasikan POI berikutnya yang terdekat dan belum dikunjungi, serta fasilitas terdekat.
9. **Progres.** Progres trail (mis. 3/10) tersimpan di ponsel dan dapat dilanjutkan di hari lain.

## 6. Mode Aplikasi dan Sesi Lokasi

AGAM memiliki empat mode. **Sesi** adalah mode Explore, Navigasi, atau Orientation Trail yang dimulai pengguna.

| Mode | Fungsi | Pembacaan lokasi | Trigger POI |
| --- | --- | --- | --- |
| **Peta biasa** (aplikasi dibuka, tanpa sesi) | Melihat peta, posisi pengguna, kartu POI, pencarian | Hanya saat aplikasi tampil di layar; berhenti saat aplikasi diminimalkan, ditutup, atau layar mati | **Tidak ada** |
| **Explore** | Jelajah bebas; POI terpicu saat didekati | Sesi aktif; tetap berjalan saat layar mati (foreground service + notifikasi tetap) | Ya |
| **Navigasi** (F06) | Diarahkan ke **satu** tujuan (gedung/fasilitas) | Sesi aktif otomatis saat navigasi dimulai | Ya; POI lain yang dilewati hanya notifikasi ringkas tanpa audio |
| **Orientation Trail** (F08) | Diarahkan berantai ke 10 POI; check-in, progres, lencana | Sesi aktif otomatis | Ya |

Aturan sesi:

- Sesi berakhir saat pengguna menekan **Akhiri** atau **otomatis setelah 30 menit berada di luar area kampus**.
- Mengakhiri sesi wajib menghentikan permintaan lokasi dan foreground service.
- Izin yang diminta hanya **"saat aplikasi digunakan"**. Dilarang meminta izin lokasi "sepanjang waktu" (`ACCESS_BACKGROUND_LOCATION`).
- Dilarang membaca lokasi di luar aturan tabel di atas (mis. otomatis aktif saat boot, atau geofencing OS yang selalu menyala).
- **[CL]** Rumusan A01 diperjelas: *"Lokasi dibaca hanya saat aplikasi tampil di layar, atau selama sesi (Explore/Navigasi/Trail) yang dimulai pengguna. Pembacaan di latar belakang dan trigger POI hanya berjalan selama sesi."*

## 7. Functional Requirements (F01–F08)

Semua berprioritas **Must**.

| ID | Requirement | Deskripsi | Acceptance criteria |
| --- | --- | --- | --- |
| F01 | Location Awareness | Membaca posisi melalui Fused Location Provider (GPS + Wi-Fi/seluler) setiap ±3 detik atau 5 m perpindahan dan menampilkannya di peta kampus | Posisi tampil ≤10 detik setelah izin diberikan dan diperbarui saat berjalan; akurasi yang dilaporkan ≤20 m di area terbuka kampus pada perangkat uji |
| F02 | Location-Based Trigger | Geofence lingkaran per POI **radius 15 m [CL]** dihitung in-app dengan haversine; trigger saat masuk area dan bertahan ≥5 detik; cooldown 10 menit per POI; berjalan di foreground dan background **selama sesi** | Notifikasi dan prompt suara POI yang benar muncul ≤10 detik setelah masuk radius; tidak terpicu ulang selama pengguna tetap di area; berhasil pada ≥8 dari 10 POI saat field test |
| F03 | Multimodal Exploration | Kartu POI memuat foto, deskripsi fungsi gedung, fasilitas di dalam gedung, trivia/sejarah singkat, dan narasi audio 45–90 detik; video narasi untuk GKUB dan GKUT | Seluruh 10 POI memiliki minimal 1 foto, teks, dan narasi audio yang dapat diputar, dijeda, dan diulang **[CL: termasuk P01–P05]**; video GKUB/GKUT dapat diputar di kartu; sumber konten dicantumkan pada setiap kartu |
| F04 | Eyes-Free Interaction | Prompt suara dan getar saat trigger; tombol aksi besar (Dengarkan/Lewati); opsi auto-play narasi; arahan navigasi suara; kontrol dari notifikasi saat layar terkunci | Pengguna dapat menerima trigger, memutar narasi, dan mengikuti navigasi sampai tujuan tanpa membaca teks layar (diuji ≥3 penguji) |
| F05 | Search & Destination | Pencarian gedung, fasilitas, dan ruang/unit penting dengan alias (angka Arab/Romawi, singkatan seperti "GKUT", "Labtek Biru") dan filter kategori | "labtek 5", "Labtek V", atau "lab 5" menampilkan Labtek V di urutan teratas; seluruh 10 POI dan kategori fasilitas dapat ditemukan; respons ≤1 detik |
| F06 | Navigation | Rute jalan kaki dari posisi pengguna ke **pintu masuk** gedung/fasilitas tujuan: garis rute, jarak, ETA, arahan belokan visual + suara; rerouting bila menyimpang >25 m; deteksi tiba pada radius 15 m | Penguji mencapai ≥4 dari 5 tujuan acak hanya dengan panduan aplikasi; pengumuman tiba muncul saat pengguna ≤15 m dari titik tujuan |
| F07 | Contextual Recommendation | Setelah kartu POI ditutup atau tiba di tujuan, merekomendasikan 1–3 POI berikutnya berdasarkan jarak terdekat, status belum dikunjungi, dan urutan trail, serta fasilitas terdekat | Rekomendasi muncul setelah kartu ditutup atau setelah tiba; rekomendasi dapat langsung dinavigasikan dengan satu ketukan |
| F08 | Orientation Trail | Rute tur berurutan yang menghubungkan 10 POI, check-in otomatis saat trigger, progres kunjungan, dan lencana penyelesaian, dilengkapi informasi layanan dan fasilitas per gedung | Pengguna dapat memulai trail; setiap POI tercatat "dikunjungi" otomatis saat trigger; progres (x/10) tetap tersimpan setelah aplikasi ditutup; lencana muncul saat seluruh POI selesai |

## 8. Additional Requirements (A01–A03)

| ID | Requirement | Deskripsi | Prioritas | Acceptance criteria |
| --- | --- | --- | --- | --- |
| A01 | Privacy & Session Control | Tidak menyimpan lintasan koordinat atau mengirim posisi ke server mana pun. Yang disimpan hanya ID POI yang dikunjungi, progres, dan pengaturan lokal. Pembacaan lokasi mengikuti aturan [§6](#6-mode-aplikasi-dan-sesi-lokasi) | Must | Pemeriksaan penyimpanan dan lalu lintas jaringan tidak menemukan riwayat perjalanan atau pengiriman posisi. Tombol Akhiri menghentikan permintaan lokasi dan layanan sesi. Progres lokal dapat dihapus |
| A02 | Content Traceability | Metadata konten memuat sumber, tanggal verifikasi, penanggung jawab, dan atribusi aset | Must | Konten P01–P10 tidak berstatus siap rilis sebelum seluruh konten wajib memiliki metadata dan persetujuan verifikasi tim |
| A03 | Offline Information Access | Kartu teks, metadata, media, peta, dan progres tersedia tanpa jaringan | Should | Komponen yang tidak tersedia menampilkan keadaan yang jelas tanpa crash |

## 9. POI dan Location Trigger

### 9.1 Dataset POI

Koordinat dalam derajat desimal (lintang selatan bernilai negatif). Koordinat adalah titik tengah gedung dari PRD; **koordinat pintu masuk belum tersedia** (lihat [§22](#22-hal-tertunda-tbd)).

| ID | Nama | Alias awal | Kategori | Lat | Lng | Radius | Konten |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | Labtek V | labtek 5, lab 5 | Gedung laboratorium dan perkuliahan | -6.8905811 | 107.6097754 | 15 m | foto, teks, audio |
| P02 | Labtek VI | labtek 6, lab 6 | Gedung laboratorium dan perkuliahan | -6.8901358 | 107.6097167 | 15 m | foto, teks, audio |
| P03 | Labtek VII | labtek 7, lab 7 | Gedung laboratorium dan perkuliahan | -6.8901169 | 107.6105714 | 15 m | foto, teks, audio |
| P04 | Labtek VIII | labtek 8, lab 8 | Gedung laboratorium dan perkuliahan | -6.8905954 | 107.6105760 | 15 m | foto, teks, audio |
| P05 | Labtek X & XI | Labtek Biru, labtek 10, labtek 11 | Gedung laboratorium dan perkuliahan | -6.8889940 | 107.6095767 | 15 m | foto, teks, audio |
| P06 | Gedung Kuliah Umum Barat | GKUB | Gedung perkuliahan | -6.89053 | 107.60890 | 15 m | foto, teks, audio, video |
| P07 | Gedung Kuliah Umum Timur | GKUT | Gedung perkuliahan | -6.8903881 | 107.6119990 | 15 m | foto, teks, audio, video |
| P08 | Oktagon | — | Gedung perkuliahan | -6.8890603 | 107.6100470 | 15 m | foto, teks, audio |
| P09 | TVST | — | Gedung perkuliahan | -6.8895043 | 107.6100594 | 15 m | foto, teks, audio |
| P10 | Labtek I | Mektan, labtek 1 | Gedung laboratorium dan perkuliahan | -6.8892078 | 107.6111876 | 15 m | foto, teks, audio |

Jarak antar-POI terdekat ±49 m (P08–P09) dan ±50 m (P01–P02), sehingga radius 15 m tidak tumpang tindih. Alias dapat ditambah oleh tim konten.

### 9.2 Logika trigger

1. Posisi diperoleh dari Fused Location Provider (plugin `geolocator`). POI tidak membutuhkan perangkat keras; cukup koordinat tersimpan.
2. Pembacaan dengan akurasi lebih buruk dari **20 m diabaikan** untuk trigger (tetap boleh ditampilkan di peta).
3. Setiap pembaruan, jarak haversine ke seluruh POI dihitung.
4. Pengguna dianggap **masuk** jika jarak ≤ radius POI dan bertahan **≥5 detik** (dwell).
5. **Histeresis:** pengguna dianggap keluar hanya jika jarak > radius + margin. Nilai margin adalah pilihan engineering, dikalibrasi saat field test, dan dicatat di dokumen ini.
6. **Cooldown 10 menit** per POI setelah trigger; trigger tidak berulang selama pengguna tetap di area.
7. Respons trigger bergantung pada mode: Explore/Trail → getar + prompt audio + notifikasi + tombol Dengarkan/Lihat/Lewati; Navigasi → notifikasi ringkas tanpa audio untuk POI yang bukan tujuan.
8. Trigger di dalam sesi otomatis mencatat POI sebagai **dikunjungi** (check-in trail).
9. **Efisiensi baterai:** interval pembaruan diperlambat (±10 detik) bila pengguna diam atau berada >200 m dari POI terdekat.
10. Radius disimpan per POI di data sehingga dapat dikalibrasi lewat Firestore tanpa membangun ulang aplikasi.

### 9.3 Area kampus

- Area layanan: Kampus Ganesha + ±200 m (termasuk Jl. Ganesha, Tamansari, dan gerbang).
- Di luar area: tampil pesan *"Anda berada di luar area Kampus Ganesha"*; trigger dan navigasi tidak aktif.
- Batas poligon/bounding box ditetapkan saat PB04 dan dicatat di dokumen ini.

## 10. Konten dan Media

| Jenis | Sumber | Penyimpanan |
| --- | --- | --- |
| Teks POI/fasilitas (deskripsi, fungsi, fasilitas, trivia, sumber) | Tim konten | Firestore + JSON bawaan di APK |
| Foto gedung | Tim konten (hak penggunaan jelas) | Dibundel di APK |
| Narasi POI 45–90 detik (P01–P10) | File audio jadi: rekaman atau TTS berkualitas yang dibuat sebelumnya | Dibundel di APK |
| Prompt trigger & pengumuman tiba per POI | File audio jadi | Dibundel di APK |
| Video narasi GKUB & GKUT | Disiapkan tim konten; ditampilkan di kartu POI | Dibundel di APK |
| Arahan navigasi belokan | TTS runtime (`flutter_tts`, mesin TTS Android, locale `id-ID`) | Tidak disimpan |

Aturan konten:

- **Dilarang mengarang** teks, trivia, sejarah, foto, audio, alias resmi, atau koordinat. Jika konten belum tersedia, gunakan placeholder yang jelas berlabel `PLACEHOLDER` dan jangan tampilkan sebagai konten final.
- Setiap konten wajib memiliki metadata A02 (sumber, tanggal verifikasi, penanggung jawab, atribusi aset) sebelum dinyatakan siap rilis.
- Jika suara TTS Bahasa Indonesia tidak tersedia di perangkat, arahan navigasi tetap tampil visual dan pengguna diberi tahu cara memasang data suara.
- Seluruh konten berbahasa Indonesia.

## 11. Navigasi dan Routing

- Routing dihitung **di perangkat**. Server routing (OSRM, GraphHopper, Google Directions, dsb.) **dilarang** karena titik awal rute adalah lokasi pengguna (A01, NG04).
- Data rute: **graf jalur pejalan kaki kampus** (GeoJSON) yang diturunkan dari data OSM lalu dikoreksi dengan survei lapangan, dibundel di APK.
- Algoritma: Dijkstra/A* pada graf tersebut. Pilihan detail adalah keputusan engineering.
- Tujuan rute adalah **pintu masuk** gedung/fasilitas. Selama koordinat pintu masuk belum tersedia, titik tengah gedung dipakai dengan label sementara dan tidak boleh dianggap memenuhi F06.
- Rerouting bila pengguna menyimpang >25 m dari rute; deteksi tiba ≤15 m dari titik tujuan.
- Output: garis rute, jarak, ETA, arahan belokan visual + suara.

## 12. Orientation Trail

- Trail adalah mode yang memandu pengguna secara berantai ke 10 POI dengan urutan rekomendasi.
- Trail memakai mesin navigasi F06 untuk menuju POI berikutnya.
- POI yang dikunjungi **di luar urutan tetap dihitung** sebagai check-in.
- Setelah kartu POI ditutup, POI berikutnya dalam urutan ditawarkan (sekaligus rekomendasi F07).
- Progres x/10 disimpan lokal dan dapat dilanjutkan di hari lain; lencana muncul saat 10/10 selesai.
- **Urutan trail belum ditetapkan tim.** Usulan: rute jalan kaki paling efisien dari gerbang depan. Jangan menetapkan urutan final tanpa keputusan tim.

## 13. Pencarian dan Rekomendasi

- Pencarian bekerja lokal atas data POI dan fasilitas: normalisasi huruf kecil, spasi, tanda baca, serta konversi angka Arab ↔ Romawi; pencocokan alias dan singkatan; filter kategori.
- Rekomendasi (F07) memprioritaskan POI terdekat yang belum dikunjungi dan urutan trail; menampilkan fasilitas terdekat bila dataset fasilitas tersedia.

## 14. Peta

- Peta memakai **tile vektor buatan sendiri** dari data OpenStreetMap (format PMTiles), mencakup area kampus + ±200 m, **dibundel di APK** sejak Sprint 1.
- **Dilarang** memakai server tile publik OSM (`tile.openstreetmap.org`) maupun mengunduh tile darinya secara massal.
- Pipeline pembuatan tile (unduh data OSM → konversi, mis. Planetiler/tilemaker → `.pmtiles`) wajib berupa script yang dapat dijalankan ulang.
- Tampilan peta memakai file style (mis. turunan OSM Liberty/Protomaps) yang disesuaikan untuk AGAM; POI ditonjolkan.
- Renderer Flutter (mis. `flutter_map` + `vector_map_tiles`) adalah pilihan engineering yang diverifikasi saat PB04.
- **Atribusi OpenStreetMap (ODbL) wajib ditampilkan** di peta.

## 15. Data dan Penyimpanan

### 15.1 Pembagian data

| Data | Lokasi |
| --- | --- |
| Database informasi POI & fasilitas (teks/terstruktur) | Firestore (sumber remote) + JSON bawaan di APK |
| Media (foto, audio, video) | Dibundel di APK; **tidak** disimpan di Firestore/Firebase Storage |
| Tile peta, graf jalur | Dibundel di APK |
| Progres trail, POI dikunjungi, pengaturan | Penyimpanan lokal perangkat |
| Posisi pengguna | Hanya di memori selama dibutuhkan; tidak pernah disimpan sebagai riwayat atau dikirim |

### 15.2 Alur sinkronisasi

1. Saat pertama dibuka, aplikasi memakai JSON bawaan.
2. Jika ada koneksi, aplikasi mengambil data dari Firestore dan menyimpannya ke cache lokal.
3. Dokumen Firestore **divalidasi** di aplikasi (tipe, rentang koordinat, radius positif, field wajib). Dokumen tidak valid diabaikan dan nilai dari salinan lokal dipakai.
4. Jika gagal (offline/error), aplikasi tetap memakai salinan terakhir.

### 15.3 Skema konseptual

Nama field final ditetapkan pada PB03 dan dicatat di sini.

- `pois/{id}`: `id`, `name`, `aliases[]`, `category`, `lat`, `lng`, `radiusM`, `entrances[]` (lat, lng, label — TBD), `description`, `function`, `facilities[]`, `trivia`, `media` (path aset di APK: foto, narasi, prompt, tiba, video), `trailOrder` (TBD), `metadata` (sumber, tanggal verifikasi, penanggung jawab, atribusi aset, status persetujuan).
- `facilities/{id}`: `id`, `name`, `category` (toilet, musala, kantin, ATM, perpustakaan, layanan akademik), `lat`, `lng`, `buildingId` (opsional), `description`, `metadata`.

### 15.4 Firestore

- Security rules: **baca publik, tulis hanya akun tim yang terautentikasi**.
- Pengeditan konten dilakukan tim lewat Firebase Console.
- Aplikasi tidak menulis apa pun ke Firestore.
- Project Firebase **belum dibuat**.

## 16. Privasi

- Tidak ada login, akun, atau role pengguna di aplikasi.
- Tidak ada analytics, crash reporting, atau logging yang membawa koordinat pengguna. Penambahan SDK pihak ketiga yang dapat mengirim lokasi memerlukan keputusan PM.
- Request jaringan yang diperbolehkan hanya pengambilan data Firestore (tanpa parameter lokasi).
- Pengguna dapat menghapus progres lokal.

## 17. Arsitektur Teknis

| Komponen | Teknologi | Catatan |
| --- | --- | --- |
| Aplikasi | Flutter 3.47.9 / Dart 3.13.7 → APK Android | Versi dikunci dengan FVM (`.fvmrc`); application ID `site.agam`; minSdk 24 (Android 7.0), targetSdk dan compileSdk 36 (default Flutter 3.47.9) |
| Lokasi | Fused Location Provider (`geolocator`) + foreground service tipe `location` | Fallback LocationManager untuk perangkat tanpa Google Play Services |
| Geofence | Logika in-app (haversine, dwell, cooldown, histeresis, filter akurasi) | Diuji unit |
| Peta | Tile vektor OSM (PMTiles) dibundel + renderer Flutter | Lihat §14 |
| Routing | Graf jalur kampus (GeoJSON) + Dijkstra/A* di perangkat | Lihat §11 |
| Data | Firestore (`cloud_firestore`) + JSON bawaan + cache lokal | Lihat §15 |
| Audio | Pemutar audio untuk file narasi/prompt; `flutter_tts` untuk arahan navigasi | Kontrol dari notifikasi |
| Video | Pemutar video di kartu POI | GKUB, GKUT |
| Penyimpanan lokal | Pilihan engineering (mis. shared_preferences/SQLite) | Hanya progres & pengaturan |
| CI/CD | GitHub Actions → build APK → GitHub Releases | Repo `SebastianAben/AGAM` |
| Tools | Figma, GitHub, Flutter DevTools, `flutter_test`, `integration_test`, Android Emulator, perangkat Android fisik | |
| AI development tools | ChatGPT/Codex, Claude/Claude Code, Gemini | Output ditinjau, diuji, dan dicatat tim |

Versi Flutter/Dart, application ID, dan SDK Android sudah ditetapkan saat PB01 (2 November 2026). Hal yang masih **wajib diverifikasi**, bukan diasumsikan: versi package yang ditambahkan, kompatibilitas renderer tile vektor, serta ukuran akhir APK.

## 18. Layar (Screen/State)

| ID | Screen/State | Tujuan | Requirement |
| --- | --- | --- | --- |
| UI01 | Onboarding & Izin Lokasi | Menjelaskan penggunaan data lokasi; meminta izin lokasi akurat dan notifikasi; panduan pengaturan baterai | F01, A01 |
| UI02 | Explore Map | Peta kampus, posisi pengguna, penanda 10 POI, jarak ke POI terdekat, tombol mulai sesi | F01, F02 |
| UI03 | POI Trigger Notification | Visual, getar, suara saat memasuki area POI; pilihan Dengarkan/Lihat/Lewati | F02, F04 |
| UI04 | POI Detail | Foto, fungsi, fasilitas, trivia, sumber, pemutar narasi, video (GKUB/GKUT) | F03, F04 |
| UI05 | Search & Destination | Pencarian dengan alias dan filter kategori | F05 |
| UI06 | Navigation | Rute, jarak, ETA, arahan visual & suara | F06, F04 |
| UI07 | Arrival & Recommendation | Konfirmasi tiba, rekomendasi POI berikutnya, fasilitas terdekat | F06, F07 |
| UI08 | Orientation Trail | Urutan 10 POI, progres, lencana | F08 |
| UI09 | Fasilitas & Pengaturan | Daftar fasilitas per kategori, auto-play audio, akhiri sesi, hapus progres | A01, A03, F04, F07 |

## 19. Kompatibilitas Android dan Perangkat Uji

| Constraint | Dampak | Penanganan |
| --- | --- | --- |
| Tanpa Google Play Services (mis. Huawei dengan HMS) | FLP tidak tersedia; akurasi lebih rendah | Fallback LocationManager; bukan perangkat uji utama |
| Izin lokasi "Perkiraan" (Android 12+) | Akurasi ±1–3 km; trigger tidak mungkin | Deteksi dan minta "Lokasi akurat" |
| Izin notifikasi ditolak (Android 13+) | Notifikasi trigger dan kontrol lock screen tidak muncul | Suara/getar tetap; jelaskan dampaknya |
| Optimasi baterai pabrikan (Xiaomi/HyperOS, Oppo, Realme, Vivo, sebagian Samsung) | Foreground service dimatikan saat layar mati | Panduan "Tanpa batasan"/autostart di onboarding; uji per merek |
| Data suara TTS `id-ID` tidak ada | Arahan suara navigasi tidak keluar | Arahan visual tetap; arahkan memasang Google TTS |
| Perangkat low-end (RAM ≤3 GB) | Render peta vektor patah-patah | Uji di minimal satu perangkat kelas bawah |
| Tanpa sensor kompas | Arah hadap tidak tersedia | Arah dari pergerakan GPS |
| Android 14+ | Foreground service lokasi wajib dideklarasikan dengan tipe `location` | Deklarasi manifest dan izin yang sesuai |

Komposisi perangkat uji yang disarankan: satu Samsung/Pixel, satu Xiaomi/Oppo, satu perangkat kelas bawah. Daftar perangkat uji **belum ditetapkan**.

## 20. Distribusi

- APK dibangun oleh GitHub Actions dan dirilis melalui GitHub Releases. Link/QR Releases dipakai untuk deliverable *Final Working Product*.
- Tidak ada server backend milik tim.

## 21. Bahasa dan Aksesibilitas

- Seluruh antarmuka dan konten berbahasa Indonesia.
- Mode eyes-free (F04): tombol besar, prompt suara, auto-play opsional, kontrol dari notifikasi.

## 22. Hal Tertunda (TBD)

Item berikut **belum diputuskan atau belum tersedia**. Agent dilarang mengisinya dengan nilai karangan; gunakan placeholder berlabel dan laporkan sebagai blocker bila dibutuhkan.

| Item | Status | Pemilik |
| --- | --- | --- |
| Koordinat pintu masuk tiap gedung | Menunggu survei lapangan | Tim |
| Dataset fasilitas (toilet, musala, kantin, ATM, perpustakaan, layanan akademik) | Akan dikumpulkan | Tim konten |
| Urutan Orientation Trail | Belum ditetapkan | Tim |
| Project Firebase | Belum dibuat | PM / Backend |
| Konten teks, foto, audio, video P01–P10 | Belum tersedia di repository | Tim konten |
| Daftar perangkat uji | Belum ditetapkan | QA |
| Margin histeresis dan kalibrasi radius per POI | Ditentukan saat implementasi/field test | Developer / QA |
| Batas area kampus (poligon/bounding box) | Ditetapkan saat PB04 | Developer |

## 23. Perbedaan terhadap PRD Baseline W9

Perubahan berikut wajib dicatat PM pada Change Log PRD resmi.

| Area | Baseline W9 | Keputusan berlaku | Alasan |
| --- | --- | --- | --- |
| F02 / tabel POI — radius | 30–50 m (F02) vs 10 m (tabel POI) | 15 m untuk semua POI | Menyatukan nilai yang bertentangan; jarak antar-POI ±49 m membuat 30–50 m tumpang tindih |
| Stack (Draft PRD §8.1) | Kotlin, Google Maps SDK, Media3 | Flutter, OSM, `flutter_tts` sesuai presentasi PRD | Presentasi adalah versi terbaru |
| F03 / tabel POI — audio | P01–P05 hanya teks & gambar | Semua POI memiliki narasi audio | Kekeliruan penulisan; F03 mewajibkan audio |
| A01 — rumusan sesi | "Pembacaan lokasi dibatasi pada sesi yang dimulai pengguna" | Rumusan diperjelas (lihat §6) | Peta biasa menampilkan posisi saat aplikasi terbuka |
| Peta | OSM (tanpa rincian) | Tile vektor buatan sendiri, dibundel | Offline penuh (A03), tanpa request ke server tile, sesuai kebijakan tile OSM |
| Routing | Tidak dirinci | Di perangkat dengan graf jalur kampus | Server routing menerima lokasi pengguna (A01, NG04) |
| Media | Firestore + JSON lokal (tidak dirinci) | Media dibundel di APK; Firestore hanya data teks | Offline dan bebas ketergantungan penyimpanan cloud |
| Sumber suara | `flutter_tts` untuk narasi, prompt, arahan | Narasi & prompt = file audio; TTS hanya arahan navigasi | Konsistensi suara dan kemandirian dari data TTS perangkat |
| Mode aplikasi | Tidak dirinci | Empat mode (§6) dan auto-end 30 menit | Memperjelas kapan lokasi dibaca dan trigger aktif |
| PB17 | Cache konten & tile peta saat offline | Tile sudah dibundel sejak S1; PB17 menjadi verifikasi offline konten | Keputusan tile |

## 24. Koreksi Minor terhadap Dokumen Resmi

| Lokasi | Sebelumnya | Koreksi |
| --- | --- | --- |
| Koordinat P06 GKUB | `6,89053° S, 107,60890° E` | `-6.89053, 107.60890` |
| Kategori P06 GKUB, P07 GKUT | Gedung laboratorium dan perkuliahan | Gedung perkuliahan |
| UI01 — requirement | F01, A02 | F01, A01 |
| UI05 — requirement | F05, A01 | F05 |
| UI07 — requirement | F06, F07, A01 | F06, F07 |
| UI09 — requirement | A01, A02, A03, F04 | A01, A03, F04, F07 |
| PB02 — requirement | F01, A02 | F01, A01 |
| PB16 — requirement | A01 | F05, F07 |
| F03 | "45-90 deti" | "45-90 detik" |

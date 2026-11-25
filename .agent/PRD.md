# Product Requirements Document (PRD): AGAM — Aplikasi Ganesha Map

| Atribut | Nilai |
| --- | --- |
| Status dokumen | **Kontrak produk kerja v1.0** untuk tim dan coding agent; diturunkan dari PRD resmi dan diperbarui dengan keputusan tim |
| Status implementasi | Source tersedia sebagian (16 November 2026): demo empat tab FE terintegrasi dengan peta/lokasi/Explore/trigger/detail/audio/pencarian repository. Trail/rute/fasilitas/akun tetap dibatasi sesuai dependency; pengaturan auto-play/Akhiri memakai LA. Source `046b646` + WIP lulus analyze, 271 test Flutter terbaru, 21 test pipeline terdahulu; APK demo fungsional terbaru terpasang di OPPO, hash perangkat cocok, cold start command sukses; kontrol peta dan pencarian-ke-peta aktif, watermark kecil di header/atas peta, panel POI interaktif menempel navigasi. Smoke visual/playback terbaru dan field belum terbukti. Rekap: 15 PBI in_progress, 7 planned, 0 done; lihat implementationPhases/handoff. Login produk, routing/trail asli dan acceptance lapangan belum selesai. |
| Tanggal | 2 November 2026 |
| Sumber resmi | Draft PRD W9 (`Kelompok 03_Draft PRD.docx.pdf`, bagian 1–4) dan presentasi PRD lengkap (`Transformasi Digital-PRD-Kel.Warung.pdf`, halaman 1–23). Keduanya berada di luar repository |
| Mata kuliah | II4011 Transformasi Digital — Prof. Ir. Kridanto Surendro, M.Sc., Ph.D. |
| Tim | Kelompok 03 / Warung; keputusan produk dipegang Project Manager |
| Platform | Aplikasi mobile Android (APK) |
| Stack | Flutter / Dart, Fused Location Provider (`geolocator`), OpenStreetMap (tile vektor dibundel), Firebase Firestore + JSON bawaan, Firebase Auth (email + password), `flutter_tts` |

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

**[CL] Role akun.** Saat daftar, pengguna memilih salah satu role yang mewakili kelompok target di atas: **Mahasiswa ITB** (`mahasiswaItb`) atau **Pengunjung** (`pengunjung`). Role diisi sendiri, tidak diverifikasi, dan tidak membedakan fitur; role hanya dipakai tim untuk memisahkan statistik.

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

Di luar lingkup v1 (keputusan tim): **bahasa selain Bahasa Indonesia** dan **backend/server milik tim**. Akun pengguna memakai layanan terkelola Firebase (Auth + Firestore), bukan server milik tim.

**[CL] Akun wajib (keputusan PM 6 November 2026).** Pengguna wajib daftar atau login sebelum memakai aplikasi. Login tidak membuka fitur tambahan. Data akun dipakai internal oleh tim developer untuk menghitung jumlah pengguna, success metric, dan log aktivitas ([§15.5](#155-log-aktivitas)). Seluruh batas privasi NG04 dan A01 tetap berlaku.

**Pengecualian demo internal (instruksi PM 14 November 2026):** login boleh
dilewati sementara untuk integrasi peta/lokasi/Explore/trigger/kartu POI, dengan
Labtek V (P01) sebagai POI uji pertama. Pengecualian hanya diaktifkan lewat
`--dart-define=AGAM_INTERNAL_DEMO=true` dan terlihat pada UI. Default flag false;
selama PB21 belum tersedia, build biasa menampilkan gerbang login belum tersedia.
Tidak membuat akun tamu, tidak menambahkan log/server, dan tidak mengganti
keputusan login wajib produk. Sesuai instruksi PM 16 November 2026, seluruh
layar FE dipertahankan pada demo: fitur yang belum memiliki logic/data nyata
tampil sebagai pratinjau, tanpa menjalankan sesi Trail, rute, check-in atau akun
palsu. Instruksi UI PM terbaru 16 November 2026 menghapus banner/catatan teknis
dan label placeholder tambahan: data belum tersedia memakai keadaan kosong
ringkas dan aksi yang belum didukung nonaktif. Metadata approval tetap
dipertahankan; ini tidak memberi approval konten atau mengubah scope produk.

## 5. Skenario Utama

Raka (18 tahun, mahasiswa baru S1 Teknik Informatika) datang pertama kali ke Ganesha:

1. **Onboarding.** Membuka AGAM; aplikasi menjelaskan bahwa lokasi hanya diproses di ponsel, lalu meminta izin lokasi (akurat) dan notifikasi.
2. **Peta.** Peta kampus, posisi Raka, dan penanda 10 POI tampil.
3. **Mulai sesi.** Raka memilih Orientation Trail (atau Explore) dan mulai berjalan.
4. **Trigger.** Saat mendekati ≤15 m dari area kontak radius 5 m GKUT dan bertahan ≥5 detik, ponsel bergetar dan terdengar prompt: *"Anda mendekati Gedung Kuliah Umum Timur. Apakah Anda ingin mendengarkan ceritanya?"*
5. **Eksplorasi.** Raka mengetuk tombol besar **Dengarkan**; kartu POI terbuka (foto, fungsi, fasilitas, trivia) dan narasi diputar. POI tercatat "dikunjungi"; selama Raka masih di area, trigger tidak berulang.
6. **Pencarian.** Raka mengetik "labtek 5"; aplikasi mengenali alias sebagai Labtek V.
7. **Navigasi.** Rute jalan kaki, jarak, ETA, dan arahan suara di setiap belokan tampil. POI lain yang dilewati hanya memunculkan notifikasi ringkas tanpa audio.
8. **Tiba.** Dalam jarak ≤15 m dari titik akses Labtek V, aplikasi mengumumkan *"Anda telah tiba di Labtek V"*, menawarkan kartu informasi, merekomendasikan POI berikutnya yang terdekat dan belum dikunjungi, serta fasilitas terdekat.
9. **Progres.** Progres trail (mis. 3/10) tersimpan di ponsel dan dapat dilanjutkan di hari lain.

## 6. Mode Aplikasi dan Sesi Lokasi

AGAM memiliki empat mode. **Sesi** adalah mode Explore, Navigasi, atau Orientation Trail yang dimulai pengguna.

**[CL] Prasyarat login.** Seluruh mode hanya tersedia setelah pengguna login. Alur pertama kali: Daftar/Login (UI10) → Onboarding & Izin Lokasi (UI01). UI10 tampil sebelum seluruh UI01; UI01 tidak dipecah. Logout mengakhiri sesi aktif dan kembali ke UI10.

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
| F02 | Location-Based Trigger | Area kontak trigger **radius 5 m** dengan jarak pendekatan POI **15 m [CL]** dihitung in-app dengan haversine; trigger saat masuk area dan bertahan ≥5 detik; cooldown 10 menit per POI; berjalan di foreground dan background **selama sesi** | Kartu saat foreground atau notifikasi saat background, disertai prompt suara POI yang benar, muncul ≤10 detik setelah masuk area pendekatan; tidak terpicu ulang selama pengguna tetap di area; berhasil pada ≥8 dari 10 POI saat field test |
| F03 | Multimodal Exploration | Kartu POI memuat foto, deskripsi fungsi gedung, fasilitas di dalam gedung, trivia/sejarah singkat, dan narasi audio 45–90 detik; video narasi untuk GKUB dan GKUT bila tersedia **[CL: keputusan PM 23 November 2026 — video opsional]** | Seluruh 10 POI memiliki minimal 1 foto, teks, dan narasi audio yang dapat diputar, dijeda, dan diulang **[CL: termasuk P01–P05]**; video GKUB/GKUT, bila tersedia, dapat diputar di kartu; sumber konten dicantumkan pada setiap kartu |
| F04 | Eyes-Free Interaction | Prompt suara dan getar saat trigger; tombol aksi besar (Dengarkan/Lewati); opsi auto-play narasi; arahan navigasi suara; kontrol dari notifikasi saat layar terkunci | Pengguna dapat menerima trigger, memutar narasi, dan mengikuti navigasi sampai tujuan tanpa membaca teks layar (diuji ≥3 penguji) |
| F05 | Search & Destination | Pencarian gedung, fasilitas, dan ruang/unit penting dengan alias (angka Arab/Romawi, singkatan seperti "GKUT", "Labtek Biru") dan filter kategori | "labtek 5", "Labtek V", atau "lab 5" menampilkan Labtek V di urutan teratas; seluruh 10 POI dan kategori fasilitas dapat ditemukan; respons ≤1 detik |
| F06 | Navigation | Rute jalan kaki dari posisi pengguna ke **titik akses** gedung/fasilitas tujuan, yaitu pintu masuk atau sisi lantai 1 yang terbuka ke jalur pejalan kaki **[CL: keputusan 24 November 2026]**: garis rute, jarak, ETA, arahan belokan visual + suara; rerouting bila menyimpang >25 m; deteksi tiba pada radius 15 m | Penguji mencapai ≥4 dari 5 tujuan acak hanya dengan panduan aplikasi; pengumuman tiba muncul saat pengguna ≤15 m dari titik tujuan |
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

Koordinat dalam derajat desimal (lintang selatan bernilai negatif). Koordinat adalah titik tengah gedung dari PRD. Titik akses tiap gedung disimpan di `entrances[]`; saat ini berupa kandidat hasil perhitungan dari graf jalan kaki yang belum diverifikasi di lapangan (lihat [§11](#11-navigasi-dan-routing) dan [§22](#22-hal-tertunda-tbd)).

| ID | Nama | Alias awal | Kategori | Lat | Lng | Radius | Konten |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | Labtek V | labtek 5, lab 5 | Gedung laboratorium dan perkuliahan | -6.8905811 | 107.6097754 | 15 m | foto, teks, audio |
| P02 | Labtek VI | labtek 6, lab 6 | Gedung laboratorium dan perkuliahan | -6.8901358 | 107.6097167 | 15 m | foto, teks, audio |
| P03 | Labtek VII | labtek 7, lab 7 | Gedung laboratorium dan perkuliahan | -6.8901169 | 107.6105714 | 15 m | foto, teks, audio |
| P04 | Labtek VIII | labtek 8, lab 8 | Gedung laboratorium dan perkuliahan | -6.8905954 | 107.6105760 | 15 m | foto, teks, audio |
| P05 | Labtek X & XI | Labtek Biru, labtek 10, labtek 11 | Gedung laboratorium dan perkuliahan | -6.8889940 | 107.6095767 | 15 m | foto, teks, audio |
| P06 | Gedung Kuliah Umum Barat | GKUB | Gedung perkuliahan | -6.89053 | 107.60890 | 15 m | foto, teks, audio, video (opsional) |
| P07 | Gedung Kuliah Umum Timur | GKUT | Gedung perkuliahan | -6.8903881 | 107.6119990 | 15 m | foto, teks, audio, video (opsional) |
| P08 | Oktagon | — | Gedung perkuliahan | -6.8890603 | 107.6100470 | 15 m | foto, teks, audio |
| P09 | TVST | — | Gedung perkuliahan | -6.8895043 | 107.6100594 | 15 m | foto, teks, audio |
| P10 | Labtek I | Mektan, labtek 1 | Gedung laboratorium dan perkuliahan | -6.8892078 | 107.6111876 | 15 m | foto, teks, audio |

Jarak antar-POI terdekat ±49 m (P08–P09) dan ±50 m (P01–P02), sehingga radius 15 m tidak tumpang tindih. Alias dapat ditambah oleh tim konten.

### 9.2 Logika trigger

1. Posisi diperoleh dari Fused Location Provider (plugin `geolocator`). POI tidak membutuhkan perangkat keras; cukup koordinat tersimpan.
2. Pembacaan dengan akurasi lebih buruk dari **20 m diabaikan** untuk trigger (tetap boleh ditampilkan di peta).
3. Setiap pembaruan, jarak haversine ke seluruh POI dihitung.
4. **[CL — instruksi PM 16 November 2026]** Koordinat trigger menjadi area kontak lingkaran radius **5 m**. Radius pendekatan per POI tetap **15 m** pada dataset; jarak ke area kontak = max(0, jarak haversine ke pusat − 5 m). Pengguna dianggap **masuk** jika jarak ke area kontak ≤ radius POI dan bertahan **≥5 detik** (dwell). Dengan data default, batas efektif masuk adalah ≤20 m dari pusat. Tidak mengubah koordinat/data POI atau radius tiba navigasi 15 m.
5. **Histeresis:** pengguna dianggap keluar hanya jika jarak ke area kontak > radius + margin (default >25 m dari pusat). Nilai margin adalah pilihan engineering, dikalibrasi saat field test, dan dicatat di dokumen ini.
6. **Cooldown 10 menit** per POI setelah trigger; trigger tidak berulang selama pengguna tetap di area.
7. Respons trigger bergantung pada mode dan visibilitas: Explore/Trail saat aplikasi tampil (`resumed`) → kartu POI otomatis + prompt audio (atau narasi sesuai auto-play); latar belakang/layar mati → notifikasi + getar + audio. Kartu menampilkan POI terdekat di antara trigger yang masih aktif dan membuka tab Jelajah, termasuk setelah kembali dari latar belakang; keluar area/akhir sesi menutup kartu otomatis. Lewati/Back menutup kartu sampai kunjungan berikutnya. Navigasi di latar belakang tetap notifikasi ringkas tanpa audio untuk POI yang bukan tujuan dan tidak membuka kartu otomatis. Tidak ada trigger tanpa sesi; aplikasi yang dimatikan paksa tidak dijamin berjalan.
8. Trigger di dalam sesi otomatis mencatat POI sebagai **dikunjungi** (check-in trail).
9. **Efisiensi baterai:** interval pembaruan diperlambat (±10 detik) bila pengguna diam atau berada >200 m dari POI terdekat.
10. Radius disimpan per POI di data sehingga dapat dikalibrasi lewat Firestore tanpa membangun ulang aplikasi.

**Parameter engineering PB05-LA-01 (4 November 2026):** engine sinkron menggunakan default margin histeresis **5 m** dan jeda sampel maksimum **10 detik**, keduanya configurable dan **telah diterapkan, belum dikalibrasi di lapangan**. Jeda yang lebih besar membatalkan kontinuitas dwell; jeda tepat 10 detik diterima. Sampel invalid membatalkan kandidat dwell tetapi tidak membuktikan keluar dan tidak menghapus cooldown. Timestamp sama/mundur diabaikan. Saat engine dinonaktifkan, dwell/pengunci kunjungan dibersihkan tetapi cooldown dipertahankan. Setelah keluar dan masuk kembali selama cooldown, dwell dapat berjalan; trigger berikutnya hanya muncul pada sampel valid setelah dwell dan cooldown terpenuhi. Ini bukan perubahan radius produk, pengaturan interval GPS, atau evidence acceptance F02. Rincian ada pada [brief PB05-LA-01](../task-implementation/backend/PB05-LA-01-geofence-engine.md); integrasi sesi dan kalibrasi masih tertunda.

**Uji developer (instruksi PM 16 November 2026):** Pengaturan pada build internal
`AGAM_INTERNAL_DEMO=true` menyediakan satu sakelar **Mode demo/trial**, default
mati. Mengaktifkannya mereset cooldown di memori dan melewati jeda cooldown
selama aktif agar keluar–masuk POI dapat diuji berulang. Pengunci kunjungan,
radius, histeresis, akurasi, dwell dan prasyarat sesi/area tetap berlaku:
diam di POI tidak memicu ulang walaupun sudah lewat 10 menit. Mematikannya
mengembalikan pemeriksaan cooldown normal sejak trigger terakhir; perubahan
tidak disimpan dan kembali mati saat aplikasi dimulai ulang. Ini alat uji
developer, bukan tambahan mode sesi §6 atau perubahan cooldown produk.

**Parameter engineering lokasi dan sesi LA Sprint 1–2 (10 November 2026)** — **telah diterapkan, belum dikalibrasi**; tidak mengubah keputusan produk:

| Parameter | Nilai | Keterangan |
| --- | --- | --- |
| Interval normal / lambat | 3 detik / 10 detik | Dari butir 1 dan 9 |
| Jarak "jauh dari POI" | >200 m dari titik tengah POI terdekat | Dari butir 9 |
| Zona dekat POI | radius POI + 30 m | Di zona ini interval **tidak** diperlambat, karena jeda sampel >10 detik membatalkan dwell |
| Status diam | perpindahan <10 m selama ≥30 detik, dihitung dari satu titik jangkar di memori (bukan riwayat) | Pembacaan berakurasi >20 m diabaikan |
| Filter jarak FLP | 0 m | Agar dwell tetap mendapat sampel saat pengguna diam di dalam radius |
| Area kampus untuk sesi | hanya diperbarui dari pembacaan berakurasi ≤20 m | Pembacaan buruk tidak memulai hitungan auto-end 30 menit |

Keterbatasan yang diketahui: geolocator (5.2.1) menghentikan foreground service saat langganan dibatalkan, sehingga pergantian interval adaptif hanya diterapkan **saat aplikasi tampil di layar**. Selama layar mati, interval terakhir dipertahankan. Penghematan baterai saat layar mati perlu diukur di perangkat fisik (PB18/PB19).

### 9.3 Area kampus

- Area layanan: Kampus Ganesha + ±200 m (termasuk Jl. Ganesha, Tamansari, dan gerbang).
- Di luar area: tampil pesan *"Anda berada di luar area Kampus Ganesha"*; trigger dan navigasi tidak aktif.
- Batas poligon/bounding box ditetapkan saat PB04 dan dicatat di dokumen ini.

**Coverage tile PB04-LB-01 (4 November 2026):** menggunakan envelope poligon
[OSM way/177629384](https://www.openstreetmap.org/way/177629384), versi 19
(timestamp objek `2026-07-24T05:11:05Z`), snapshot API diambil dan diperiksa pada
4 November 2026. Seluruh 10 POI PRD berada di dalam poligon sumber. Envelope
diperluas 200 m dengan pendekatan spherical dan pembulatan keluar; bounds tile
`west=107.60635935`, `south=-6.89545535`, `east=107.61454265`,
`north=-6.88552795`. Provenance, checksum snapshot, dan metode ada di
`tools/tiles/campus-boundary.json` serta [brief pipeline](../task-implementation/backend/PB04-LB-01-tile-pipeline.md).
Ini batas cakupan aset tile, bukan hasil survei batas resmi. Poligon area layanan
pada `MapConfig` dan perilaku di luar area belum diimplementasikan oleh task ini.

**Area demo internal (14 November 2026):** dalam mandat PM untuk menyesuaikan
kebutuhan integrasi demo, `AgamMapConfig.internalDemo()` memakai empat sudut
bounds engineering di atas sebagai area demo sementara. UI memberi label
engineering OSM dan belum diverifikasi lapangan. Ini hanya dipakai oleh flag
demo, bukan penetapan batas layanan produk. `pendingServiceArea()` tetap
menolak semua titik selama batas produk TBD; tidak ada koordinat baru yang
dikira sebagai hasil survei. Radius, dwell, cooldown, dan filter akurasi §9.2
tidak berubah.

**Batas layanan produk (24 November 2026):** atas keputusan tim, build produk
memakai empat sudut bounds engineering yang sama sebagai batas layanan resmi
(`AgamMapConfig.campus()`), sesuai rumusan "Kampus Ganesha + ±200 m" di atas.
Batas ini berasal dari coverage OSM, belum diverifikasi lapangan, dan sedikit
lebih longgar dari kampus pada sisi jalan sekitar. Trigger tetap hanya dalam
radius POI §9.2, sehingga kelonggaran batas tidak memicu POI di luar kampus.
Bila survei batas tersedia, poligon diganti dan dicatat ulang di sini.


## 10. Konten dan Media

| Jenis | Sumber | Penyimpanan |
| --- | --- | --- |
| Teks POI/fasilitas (deskripsi, fungsi, fasilitas, trivia, sumber) | Tim konten | Firestore + JSON bawaan di APK |
| Foto gedung | Tim konten (hak penggunaan jelas) | Dibundel di APK |
| Narasi POI 45–90 detik (P01–P10) | File audio jadi: rekaman atau TTS berkualitas yang dibuat sebelumnya | Dibundel di APK |
| Prompt trigger & pengumuman tiba per POI | File audio jadi | Dibundel di APK |
| Video narasi GKUB & GKUT | Disiapkan tim konten; ditampilkan di kartu POI | Dibundel di APK |
| Arahan navigasi belokan | TTS runtime (`flutter_tts`, mesin TTS Android, locale `id-ID`) | Tidak disimpan |
| Pengumuman tiba di fasilitas | TTS runtime: *"Anda telah tiba di {nama fasilitas}"* **[CL: keputusan 24 November 2026]**; fasilitas tidak memiliki file audio tiba | Tidak disimpan |

Aturan konten:

- **Dilarang mengarang** teks, trivia, sejarah, foto, audio, alias resmi, atau koordinat. Jika konten belum tersedia, gunakan placeholder yang jelas berlabel `PLACEHOLDER` dan jangan tampilkan sebagai konten final.
- Setiap konten wajib memiliki metadata A02 (sumber, tanggal verifikasi, penanggung jawab, atribusi aset) sebelum dinyatakan siap rilis.
- Jika suara TTS Bahasa Indonesia tidak tersedia di perangkat, arahan navigasi dan pengumuman tiba di fasilitas tetap tampil visual dan pengguna diberi tahu cara memasang data suara.
- Seluruh konten berbahasa Indonesia.

## 11. Navigasi dan Routing

- Routing dihitung **di perangkat**. Server routing (OSRM, GraphHopper, Google Directions, dsb.) **dilarang** karena titik awal rute adalah lokasi pengguna (A01, NG04).
- Data rute: **graf jalur pejalan kaki kampus** (GeoJSON) yang diturunkan dari data OSM lalu dikoreksi dengan survei lapangan, dibundel di APK.
- Algoritma: Dijkstra/A* pada graf tersebut. Pilihan detail adalah keputusan engineering.
- Tujuan rute adalah **titik akses** gedung: tempat orang masuk dari jalur pejalan kaki, berupa pintu atau sisi lantai 1 yang terbuka. Sebagian besar gedung kampus tidak memiliki pintu masuk tunggal, sehingga istilah "pintu masuk" diganti **[CL: keputusan 24 November 2026]**. Gedung boleh memiliki beberapa titik akses; rute menuju yang terdekat.
- Kandidat titik akses dihitung oleh `tools/routing/plan_access_points.py` dari data OSM yang juga digambar di peta: setiap ruas jaringan utama graf jalan kaki yang berjarak ≤4 m dari dinding poligon gedung (8 m bila tidak ada yang sedekat itu) memberi satu titik, yaitu titik pada ruas yang paling dekat ke dinding; titik yang berjarak <5 m digabung. Satu POI boleh terdiri atas beberapa poligon (Labtek X & XI). Ruas pada potongan graf yang terpisah, misalnya selasar antar-gedung, tidak dipakai karena tidak dapat dijangkau rute. Kandidat disimpan dengan `verified: false` dan baru diubah menjadi `true` setelah dicek di lapangan; menjalankan ulang script tidak menimpa titik yang sudah `verified: true`.
- Koreksi dari peninjauan peta disimpan di `tools/routing/access_overrides.json` (titik yang ditambah dan kandidat yang dihapus per POI) dan selalu diterapkan script. Titik tambahan yang berjarak >25 m dari jalur rute disambungkan lewat lorong kandidat ke simpul jaringan terdekat.
- **Lorong tembus gedung** **[CL: keputusan 24 November 2026]**: selasar antar-gedung yang terputus dari jaringan disambungkan lewat lorong lantai 1 bila selasar menunjuk lurus (≤20°, ≤60 m, seluruhnya di dalam gedung) ke jalur di dinding seberang. Lorong disimpan di `assets/routing/passages.geojson` sebagai ruas tambahan; satu ujungnya selalu simpul graf, ujung lainnya simpul graf atau titik akses POI yang ditambahkan routing sebagai simpul baru. Lorong bernilai `verified: false` sampai dicek di lapangan; graf OSM tidak diubah. Arahan rute yang melewati lorong kandidat menyebut bahwa lorong belum diverifikasi.
- Navigasi ke kandidat yang belum diverifikasi diberi label sementara dan tidak boleh dianggap memenuhi F06. Bila sebuah gedung belum memiliki titik akses sama sekali, titik tengah gedung dipakai dengan label yang sama.
- Rerouting bila pengguna menyimpang >25 m dari rute; deteksi tiba ≤15 m dari titik tujuan.
- Output: garis rute, jarak, ETA, arahan belokan visual + suara.

## 12. Orientation Trail

- Trail adalah mode yang memandu pengguna secara berantai ke 10 POI dengan urutan rekomendasi.
- Trail memakai mesin navigasi F06 untuk menuju POI berikutnya.
- POI yang dikunjungi **di luar urutan tetap dihitung** sebagai check-in.
- Setelah kartu POI ditutup, POI berikutnya dalam urutan ditawarkan (sekaligus rekomendasi F07).
- Progres x/10 disimpan lokal dan dapat dilanjutkan di hari lain; lencana muncul saat 10/10 selesai.
- **Urutan trail ditetapkan 24 November 2026** **[CL]**: keliling terpendek yang menghubungkan 10 POI, dengan jarak antar-POI = jalan kaki terpendek di antara titik akses mana pun milik kedua gedung (`tools/routing/plan_access_points.py`): Labtek V → Labtek VIII → GKU Timur → Labtek VII → Labtek I → Oktagon → Labtek X & XI → TVST → Labtek VI → GKU Barat → kembali ke Labtek V. Nilai `trailOrder` 1–10 di dataset mengikuti urutan ini.
- Karena urutan berbentuk keliling, trail **dimulai dari POI terdekat dengan posisi pengguna** saat trail pertama kali dimulai, lalu berlanjut searah putaran. Titik awal disimpan per akun bersama progres; menghapus progres memilih ulang titik awal.

## 13. Pencarian dan Rekomendasi

- Pencarian bekerja lokal atas data POI dan fasilitas: normalisasi huruf kecil, spasi, tanda baca, serta konversi angka Arab ↔ Romawi; pencocokan alias dan singkatan; filter kategori.
- Rekomendasi (F07) memprioritaskan POI terdekat yang belum dikunjungi dan urutan trail; menampilkan fasilitas terdekat bila dataset fasilitas tersedia.

## 14. Peta

- Peta memakai **tile vektor buatan sendiri** dari data OpenStreetMap (format PMTiles), mencakup area kampus + ±200 m, **dibundel di APK** sejak Sprint 1.
- **Dilarang** memakai server tile publik OSM (`tile.openstreetmap.org`) maupun mengunduh tile darinya secara massal.
- Pipeline pembuatan tile (unduh data OSM → konversi, mis. Planetiler/tilemaker → `.pmtiles`) wajib berupa script yang dapat dijalankan ulang.
- Tampilan peta memakai file style (mis. turunan OSM Liberty/Protomaps) yang disesuaikan untuk AGAM; POI ditonjolkan.
- Renderer Flutter (mis. `flutter_map` + `vector_map_tiles`) adalah pilihan engineering yang diverifikasi saat PB04.
- **Atribusi OpenStreetMap (ODbL) wajib ditampilkan** di peta. Profil OpenMapTiles yang dipakai pipeline PB04-LB-01 juga memerlukan kredit OpenMapTiles bertautan ke `https://openmaptiles.org/`; HTML atribusi lengkap dipertahankan dalam metadata arsip/manifest.

**Implementasi demo 14 November 2026:** `flutter_map 7.0.2` dan
`vector_tile_renderer 5.2.0`, pembaca `pmtiles 1.3.0` serta `latlong2 0.9.1`.
`url_launcher` ^6.3.2 (lockfile 6.3.3) hanya membuka tautan atribusi statis atas
ketukan pengguna. Seluruh 13 tile vektor dibaca dari APK dan dirender ke PNG
di memori sebelum dipakai peta; tidak ada fallback jaringan, cache tile ke disk,
glyph/sprite remote, atau penyimpanan viewport/posisi. Native zoom 12–16,
overzoom sampai 20. `VectorTileLayer` dari `vector_map_tiles` tidak dipakai
karena source package tetap menulis cache filesystem saat TTL nol. Pipeline
menjalankan clustering deterministik sebelum validasi/publikasi; format
unclustered Planetiler tidak didukung pembaca Dart yang dipakai. Detail teknis
dan perintah audit ada di `tools/tiles/README.md`. Bukti widget bukan acceptance
Android/offline pada perangkat.

## 15. Data dan Penyimpanan

### 15.1 Pembagian data

| Data | Lokasi |
| --- | --- |
| Database informasi POI & fasilitas (teks/terstruktur) | Firestore (sumber remote) + JSON bawaan di APK |
| Media (foto, audio, video) | Dibundel di APK; **tidak** disimpan di Firestore/Firebase Storage |
| Tile peta, graf jalur | Dibundel di APK |
| Progres trail, POI dikunjungi, pengaturan | Penyimpanan lokal perangkat, dipisahkan per akun (lihat di bawah); tidak disinkronkan ke server |
| Akun (email, password) | Firebase Auth; password tidak pernah disimpan atau dicatat aplikasi |
| Profil (role, tanggal daftar) | Firestore `users/{uid}`; hanya pemilik yang dapat membaca dan menulis |
| Log aktivitas | Firestore `activity_logs`; pengguna hanya membuat log miliknya, tim membaca lewat Console ([§15.5](#155-log-aktivitas)) |
| Posisi pengguna | Hanya di memori selama dibutuhkan; tidak pernah disimpan sebagai riwayat atau dikirim |

**[CL] Progres lokal per akun.** Progres trail, POI dikunjungi, dan pengaturan disimpan di perangkat dengan kunci `uid`. Logout tidak menghapus data tersebut, hanya menyembunyikannya; login kembali dengan akun yang sama di perangkat yang sama memulihkannya. Akun lain di perangkat yang sama memiliki progres sendiri. Data ini tidak dikirim ke server, sehingga berganti perangkat berarti progres dimulai dari awal. Hapus akun ikut menghapus data lokal milik akun tersebut.

### 15.2 Alur sinkronisasi

1. Setelah login pertama, aplikasi memakai JSON bawaan; konten tidak memerlukan jaringan.
2. Jika ada koneksi, aplikasi mengambil data dari Firestore dan menyimpannya ke cache lokal.
3. Dokumen Firestore **divalidasi** di aplikasi (tipe, rentang koordinat, radius positif, field wajib). Dokumen tidak valid diabaikan dan nilai dari salinan lokal dipakai.
4. Jika gagal (offline/error), aplikasi tetap memakai salinan terakhir.

**[CL] Sumber konten (keputusan PM, 15 November 2026).** `assets/data/pois.json` di repository adalah satu-satunya sumber konten POI dan fasilitas; Firestore hanya salinannya. Perubahan konten dilakukan lewat PR ke `dev`. Setiap push ke `dev` yang mengubah file itu menjalankan workflow `seed-firestore.yml`: test dataset lebih dulu, lalu script `tools/firestore/` menulis satu dokumen per item dan menghapus dokumen yang tidak ada di JSON. Konten tidak diedit di Firebase Console. Firestore mengikuti `dev` sampai rilis v1.0, lalu mengikuti `main` mulai PB19. Media tetap memerlukan APK baru karena dibundel.

Risiko yang diketahui: aplikasi memakai cache lebih dulu daripada JSON bawaan dan belum membandingkan versi. Jika `pois.json` diperbarui di APK tetapi Firestore tidak di-seed ulang, cache dari Firestore yang lebih lama menutupi konten baru. Karena itu seed setelah setiap perubahan bersifat wajib; pembanding versi dataset diusulkan untuk PB03.

### 15.3 Skema konseptual

Nama field final ditetapkan pada PB03 (2 November 2026). Bentuk ini dipakai sama untuk dokumen Firestore dan JSON bawaan `assets/data/pois.json`; parser dan validatornya di `lib/logic/data/poi_codec.dart`.

- `pois/{id}`: `id`, `name`, `aliases[]`, `category`, `lat`, `lng`, `radiusM`, `entrances[]` (`lat`, `lng`, `label`, `verified`), `description`, `function`, `facilities[]`, `trivia`, `media` (`photos[]`, `narrationAudio`, `promptAudio`, `arrivalAudio`, `video` — path aset di APK), `trailOrder`, `metadata`.
- `facilities/{id}`: `id`, `name`, `category`, `lat`, `lng`, `buildingId` (opsional), `description`, `metadata`.
- `metadata`: `sources[]`, `verifiedAt` (ISO 8601), `owner`, `assetAttribution[]`, `approved`, `isPlaceholder`.
- `users/{uid}`: `role` (`mahasiswaItb` | `pengunjung`), `createdAt` (timestamp). Email tidak diduplikasi di Firestore karena sudah ada di Firebase Auth.
- `activity_logs/{autoId}`: lihat [§15.5](#155-log-aktivitas).

Nilai `category` ditulis persis seperti nama enum kontrak: POI `laboratoryAndLecture` atau `lecture`; fasilitas `toilet`, `musala`, `kantin`, `atm`, `perpustakaan`, `layananAkademik`.

Aturan validasi (PB03, menerapkan [§15.2](#152-alur-sinkronisasi) butir 3):

| Field | Aturan | Jika dilanggar |
| --- | --- | --- |
| `id`, `name` | Teks wajib, tidak kosong | Dokumen diabaikan |
| `lat`, `lng` | Angka dalam rentang WGS84 (−90..90, −180..180) | Dokumen diabaikan |
| `category` | Harus salah satu nilai enum di atas | Dokumen diabaikan |
| `radiusM` | Angka > 0; jika tidak ada, memakai default 15 m | Dokumen diabaikan |
| `entrances[]` | Daftar titik akses dengan `lat`/`lng` valid; boleh kosong. `verified` hanya bernilai benar bila `true` eksplisit (titik sudah dicek di lapangan); selain itu titik dianggap kandidat | Dokumen diabaikan |
| `trailOrder` | Boleh tidak ada; jika ada wajib bilangan bulat positif | Dokumen diabaikan |
| `id` ganda dalam satu dataset | Hanya dokumen pertama dipakai | Duplikat diabaikan |
| `metadata` tidak lengkap (tanpa `sources`, `owner`, atau `verifiedAt` yang valid) | Konten diperlakukan sebagai placeholder dan `approved` dipaksa `false` | Tidak siap rilis (A02) |

Dokumen yang diabaikan tidak menggagalkan dataset lain. Dataset yang tidak menyisakan satu pun POI valid tidak dipakai; aplikasi tetap memakai salinan sebelumnya atau JSON bawaan.

### 15.4 Firestore

Security rules:

- `pois/` dan `facilities/`: baca publik dan tidak dapat ditulis dari aplikasi. Isinya ditulis script seed dengan Admin SDK (tidak melewati security rules) sesuai [§15.2](#152-alur-sinkronisasi), bukan diedit di Console.
- `users/{uid}`: hanya pengguna dengan `uid` yang sama yang dapat membaca, membuat, mengubah `role`, dan menghapus dokumennya.
- `activity_logs/`: pengguna yang login hanya dapat **membuat** log dengan `uid` miliknya; rules menolak field di luar daftar §15.5 (`hasOnly`). Pengguna dapat membaca dan menghapus log miliknya untuk keperluan hapus akun; konsekuensinya, pengguna juga dapat menghapus log tanpa menghapus akun karena rules tidak dapat membedakan keduanya (diterima PM, 14 November 2026). Tim membaca log lewat Firebase Console.
- Aplikasi tidak menulis ke koleksi lain.

Project Firebase `agam-9e704` dibuat PM pada 15 November 2026: Firestore (Standard, `asia-southeast2`, production mode) dan Authentication metode Email/Password; Analytics, Crashlytics, dan Storage tidak diaktifkan. Aplikasi Android `site.agam` terdaftar lewat FlutterFire CLI. Rules ada di `firestore.rules`, diuji di emulator (`tools/firestore/rules.test.mjs`), dan di-deploy lewat Firebase CLI.

### 15.5 Log aktivitas

**[CL]** Daftar event tertutup. Event baru hanya boleh ditambahkan dengan keputusan PM dan pemeriksaan privasi yang sama.

| `type` | Field tambahan | Catatan |
| --- | --- | --- |
| `signUp` | `role` | |
| `login`, `logout` | — | |
| `appOpen` | `appVersion`, `androidVersion`, `deviceModel` | Hanya saat aplikasi dibuka dari keadaan tertutup (cold start), bukan setiap kembali ke foreground. Membuka aplikasi dari notifikasi trigger tidak boleh meninggalkan jejak waktu trigger |
| `modeStart`, `modeEnd` | `mode` (`explore` \| `navigation` \| `trail`); `modeEnd` ditambah `durationMin` (dibulatkan ke 5 menit) | Tanggal saja, tanpa jam, dan tanpa alasan berakhir. Jam selesai Trail sama dengan jam tiba di POI terakhir; alasan auto-end mengungkap bahwa pengguna keluar kampus |
| `featureUsed` | `feature` (`search` \| `poiCard` \| `narration` \| `facilities`) | Tanpa ID POI, kata kunci pencarian, atau tujuan. Tidak dicatat untuk aksi yang berasal dari trigger POI atau dari kartu tiba (Lihat/Dengarkan, autoplay), karena waktunya bertepatan dengan kedatangan di POI (rules §5.1; keputusan 25 November 2026) |
| `trailCompleted` | — | Tanggal saja, tanpa jam, karena waktu selesai trail sama dengan waktu tiba di POI terakhir |

Field umum: `uid`, `type`, dan waktu. Waktu berupa `at` (timestamp perangkat) untuk `signUp`, `login`, `logout`, `appOpen`, dan `featureUsed`; berupa `date` (YYYY-MM-DD, tanpa jam) untuk `modeStart`, `modeEnd`, dan `trailCompleted`. Event yang waktunya dapat bertepatan dengan kedatangan di POI tertentu hanya boleh membawa tanggal.

**Dilarang dicatat dalam bentuk apa pun:** koordinat atau posisi, ID atau nama POI, tujuan navigasi, titik awal rute, urutan kunjungan, kata kunci pencarian, dan alasan sesi berakhir. Statistik per POI, jika kelak dibutuhkan, hanya berupa penghitung agregat tanpa `uid` dan tanpa waktu, dan memerlukan keputusan PM.

Log yang dibuat saat offline disimpan dalam antrean Firestore di perangkat dan terkirim saat online. Log dihapus tim paling lambat setelah penilaian akhir mata kuliah; tanggal pastinya tercatat di [§22](#22-hal-tertunda-tbd).

## 16. Privasi

- **[CL]** Login wajib dengan email dan password (Firebase Auth). Data akun hanya untuk keperluan internal tim ([§4](#4-tujuan-dan-non-tujuan)). Verifikasi email tidak diwajibkan; lupa password memakai email reset dari Firebase Auth.
- Layar daftar wajib menampilkan pemberitahuan tentang data yang dicatat, tujuannya, dan pernyataan bahwa posisi tidak pernah dikirim. Pengguna harus menyetujuinya sebelum akun dibuat. Teks pemberitahuan disusun FE dan wajib disetujui PM sebelum rilis.
- Log aktivitas mengikuti daftar tertutup [§15.5](#155-log-aktivitas). Tidak ada analytics pihak ketiga, crash reporting, atau logging yang membawa koordinat pengguna. Penambahan SDK pihak ketiga yang dapat mengirim lokasi atau data perangkat memerlukan keputusan PM.
- Request jaringan yang diperbolehkan: Firebase Auth, pengambilan data Firestore (tanpa parameter lokasi), serta penulisan `users/{uid}` dan `activity_logs` sesuai [§15.4](#154-firestore) dan §15.5.
- Pengguna dapat menghapus progres lokal.
- Pengguna dapat menghapus akun dari Pengaturan. Hapus akun menghapus profil `users/{uid}`, seluruh log miliknya, data lokal milik akun tersebut, lalu akun Firebase Auth.

## 17. Arsitektur Teknis

| Komponen | Teknologi | Catatan |
| --- | --- | --- |
| Aplikasi | Flutter 3.47.9 / Dart 3.13.7 → APK Android | Versi dikunci dengan FVM (`.fvmrc`); application ID `site.agam`; minSdk 24 (Android 7.0), targetSdk dan compileSdk 36 (default Flutter 3.47.9) |
| Lokasi | Fused Location Provider (`geolocator`) + foreground service tipe `location` | Fallback LocationManager untuk perangkat tanpa Google Play Services |
| Geofence | Logika in-app (haversine, dwell, cooldown, histeresis, filter akurasi) | Diuji unit |
| Peta | Tile vektor OSM (PMTiles) dibundel + renderer Flutter | Lihat §14 |
| Routing | Graf jalur kampus (GeoJSON) + Dijkstra/A* di perangkat | Lihat §11 |
| Data | Firestore (`cloud_firestore`) + JSON bawaan + cache lokal | Lihat §15 |
| Akun | Firebase Auth (email + password) | Sesi login tersimpan di perangkat sehingga aplikasi tetap dapat dipakai offline setelah login pertama |
| Log aktivitas | Firestore (`activity_logs`) | Bukan Firebase Analytics; lihat §15.5 |
| Audio | `just_audio` + `audio_service` untuk file narasi/prompt/tiba; `flutter_tts` untuk arahan navigasi | Kontrol dari notifikasi dan lock screen |
| Notifikasi trigger | `flutter_local_notifications` | Getar, prompt, tombol Dengarkan/Lihat/Lewati |
| Video | `video_player` untuk pemutar video di kartu POI (aset APK) | GKUB, GKUT |
| Penyimpanan lokal | `shared_preferences` (pengaturan); `path_provider` untuk direktori cache data POI | Hanya progres & pengaturan |
| CI/CD | GitHub Actions → build APK → GitHub Releases | Repo `SebastianAben/AGAM` |
| Tools | Figma, GitHub, Flutter DevTools, `flutter_test`, `integration_test`, Android Emulator, perangkat Android fisik | |
| AI development tools | ChatGPT/Codex, Claude/Claude Code, Gemini | Output ditinjau, diuji, dan dicatat tim |

Versi Flutter/Dart, application ID, dan SDK Android sudah ditetapkan saat PB01 (2 November 2026).

Package LA yang ditambahkan 10 November 2026 (versi diperiksa di pub.dev dan dikunci `pubspec.lock`): `geolocator` ^14.1.2, `flutter_local_notifications` ^22.3.3 (bukan 23.0.0 yang baru dirilis 6 November 2026), `just_audio` ^0.10.6, `audio_service` ^0.18.19, `shared_preferences` ^2.5.6, `path_provider` ^2.1.6; dev: `fake_async` ^1.3.3. Untuk PB12 ditambahkan `flutter_tts` ^4.2.5 (sudah tercantum di stack). `audio_service` membawa `flutter_cache_manager` (http, sqflite) secara transitif untuk gambar sampul; AGAM tidak memberi URL gambar sehingga tidak ada request jaringan dari jalur ini. Sampai 14 November 2026 manifest utama aplikasi tidak mendeklarasikan `INTERNET`; manifest juga secara eksplisit menghapus `ACCESS_BACKGROUND_LOCATION`. Manifest hasil merge build debug (10 November 2026) tidak memuat `ACCESS_BACKGROUND_LOCATION`; `INTERNET` di sana berasal dari manifest debug bawaan Flutter (alat pengembangan) dan `ACCESS_NETWORK_STATE` dari `androidx.media3` (backend `just_audio`). Manifest build rilis belum diperiksa. Sejak 15 November 2026 manifest utama mendeklarasikan `INTERNET` untuk Firebase (PB03). Hal yang masih **wajib diverifikasi**, bukan diasumsikan: versi package yang ditambahkan, kompatibilitas renderer tile vektor, serta ukuran akhir APK.

Untuk Firestore (PB03, 15 November 2026) ditambahkan `firebase_core` ^5.1.0 dan `cloud_firestore` ^7.1.0 (diselesaikan `pub add`), dev: `fake_cloud_firestore` ^4.5.0; Gradle plugin `com.google.gms.google-services` 4.4.4 dipasang FlutterFire CLI dan kompatibilitasnya dengan AGP 9.1.0 telah diverifikasi lewat build APK debug demo 16 November 2026 (bukan rilis). Untuk akun dan log aktivitas (PB21–PB22) masih diperlukan `firebase_auth` dan `device_info_plus` (untuk `deviceModel` dan `androidVersion`). Versinya wajib diverifikasi sebelum ditambahkan (`rules.md` §4.2).

**Interaksi UI (16 November 2026):** package resmi Flutter `animations` **3.0.0**
(versi/API diperiksa di pub.dev dan source package) digunakan untuk transisi tab.
Dependency baru murni Dart/UI: `material_ui` 1.11.0, `cupertino_ui` 1.1.6 dan
`flutter_localizations` dari SDK, seluruhnya dikunci di lockfile tanpa upgrade
package existing. SDK package memerlukan Flutter ≥3.47.0 dan kompatibel dengan
3.47.9 proyek. Tidak menambah plugin lokasi, analytics, logging atau request
jaringan runtime. Panel memakai DraggableScrollableSheet/Scrollbar native;
pressed feedback 140 ms, tab 180 ms, panel/kamera 220 ms (exit 160 ms), dengan
reduced motion. Aksi kartu dan notifikasi memakai TriggerResponder yang sama;
auto-play kartu memakai SettingsStore aktif. AudioService kontrak tetap; kemampuan
seek opsional ada pada implementasi LA. Media belum approved ditolak pada layanan
audio, termasuk jalur prompt/narasi otomatis. Ini implementasi parsial, bukan
acceptance F04 atau penyelesaian PBI.

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
| UI09 | Fasilitas & Pengaturan | Daftar fasilitas per kategori, auto-play audio, akhiri sesi, hapus progres; **[CL]** info akun (email, role), logout, hapus akun | A01, A03, F04, F07 |
| UI10 | **[CL]** Daftar & Login | Daftar (email, password, pilih role, persetujuan pemberitahuan privasi), login, lupa password, pesan offline "Butuh koneksi internet untuk login pertama kali" | A01 |

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
- Tidak ada server backend milik tim. Akun dan log memakai layanan terkelola Firebase.

## 21. Bahasa dan Aksesibilitas

- Seluruh antarmuka dan konten berbahasa Indonesia.
- Mode eyes-free (F04): tombol besar, prompt suara, auto-play opsional, kontrol dari notifikasi.

## 22. Hal Tertunda (TBD)

Item berikut **belum diputuskan atau belum tersedia**. Agent dilarang mengisinya dengan nilai karangan; gunakan placeholder berlabel dan laporkan sebagai blocker bila dibutuhkan.

| Item | Status | Pemilik |
| --- | --- | --- |
| Titik akses tiap gedung | 41 kandidat titik akses untuk 10 gedung dan 4 kandidat lorong tembus (Labtek V, VII, VIII, Labtek X & XI) dari poligon gedung OSM dan graf jalan kaki draf (24 November 2026), dikoreksi lewat peninjauan peta oleh pengguna 25 November 2026 (8 titik ditambah, 6 dihapus; `tools/routing/access_overrides.json`); semuanya `verified: false`; daftar cek di `task-implementation/backend/PB11-access-point-field-check.md`. Verifikasi lapangan, penghapusan titik yang bukan jalan masuk, dan penambahan yang belum ada tertunda | Tim |
| Dataset fasilitas (toilet, musala, kantin, ATM, perpustakaan, layanan akademik) | Versi pertama 26 item disetujui SebastianAben 24 November 2026: toilet/musala/kantin dari daftar fasilitas tiap POI (titik gedung), ATM/perpustakaan/layanan akademik dari informasi pengguna (titik ditandai di peta AGAM). Letak persis dan verifikasi lapangan tetap tertunda | Tim konten |
| Urutan Orientation Trail | Ditetapkan 24 November 2026 (§12); jarak dihitung dari graf draf dan dapat berubah setelah graf dikoreksi | Tim |
| Project Firebase (Firestore + Authentication Email/Password) | Dibuat 15 November 2026 (`agam-9e704`); seed pertama 15 November 2026; seed otomatis lewat GitHub Actions berjalan sukses sejak 24 November 2026 (push `pois.json` ke `dev`) | PM / Backend |
| Konten teks, foto, audio, video P01–P10 | 10/10 POI disetujui pemilik konten dan ditandai approved di JSON (23 November 2026, rincian di implementationPhases PB09); video hanya P06 GKUB (opsional, §23). Pencatatan keputusan di Change Log PRD resmi, hak aset, durasi narasi, dan playback di perangkat tetap perlu audit/uji | Tim konten / PM |
| Daftar perangkat uji | Belum ditetapkan | QA |
| Margin histeresis, kalibrasi radius per POI, dan parameter interval adaptif | Default engineering margin 5 m dan jeda sampel maksimum 10 detik (PB05-LA-01) serta parameter interval adaptif [§9.2](#92-logika-trigger) diterapkan; kalibrasi lapangan tetap tertunda | Developer / QA |
| Batas area kampus (poligon/bounding box) | Diputuskan 24 November 2026: batas produk = bounds engineering OSM + 200 m (§9.3). Verifikasi lapangan dan poligon presisi tetap tertunda | Developer |
| Success metric | Belum ditetapkan. Log §15.5 disusun agar dapat dipakai metrik umum (pengguna aktif, pemakaian mode dan fitur, trail selesai); event yang tidak dipakai metrik mana pun dihapus setelah metrik ditetapkan | PM |
| Tanggal penghapusan log aktivitas | Paling lambat setelah penilaian akhir mata kuliah; tanggal pasti belum ditetapkan | PM |
| Teks pemberitahuan privasi layar daftar (UI10) | Disusun FE, wajib disetujui PM | FE / PM |

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
| F03 / tabel POI — video GKUB & GKUT | Video narasi wajib untuk GKUB dan GKUT | Video opsional; konten GKUB/GKUT boleh disetujui tanpa video dan video ditampilkan bila tersedia | Keputusan PM 23 November 2026 (disampaikan pemilik konten) |
| Sumber suara | `flutter_tts` untuk narasi, prompt, arahan | Narasi & prompt = file audio; TTS untuk arahan navigasi dan pengumuman tiba di fasilitas (24 November 2026) | Konsistensi suara dan kemandirian dari data TTS perangkat |
| Mode aplikasi | Tidak dirinci | Empat mode (§6) dan auto-end 30 menit | Memperjelas kapan lokasi dibaca dan trigger aktif |
| PB17 | Cache konten & tile peta saat offline | Tile sudah dibundel sejak S1; PB17 menjadi verifikasi offline konten | Keputusan tile |
| Akun pengguna | Tidak disebut di requirement, backlog, maupun sprint plan | Login wajib (email + password), role Mahasiswa ITB/Pengunjung, hapus akun (§4, §16) | Pencatatan jumlah pengguna dan success metric oleh tim (keputusan PM 6 November 2026) |
| Demo internal sementara | Tidak dirinci | Flag eksplisit melewati login untuk demo integrasi dengan P01; area demo memakai coverage engineering OSM berlabel. Keputusan produk login wajib/batas layanan final tetap berlaku | Instruksi PM 14 November 2026 untuk memprioritaskan integrasi FE/logic, menyesuaikan kebutuhan demo, dan skip login sementara |
| Area kontak dan visual trigger | Tidak dirinci | Titik POI menjadi area kontak radius 5 m; radius pendekatan dataset tetap 15 m (efektif masuk 20 m, keluar >25 m). Explore/Trail menampilkan kartu terdekat + audio saat resumed, notifikasi + audio di latar belakang | Instruksi PM 16 November 2026 untuk memperluas kontak dan memperjelas respons di layar |
| Uji developer trigger | Tidak dirinci | Sakelar Mode demo/trial di Pengaturan build internal mereset/melewati cooldown; pengunci saat tetap di POI dan validasi lokasi/dwell dipertahankan | Instruksi PM 16 November 2026 agar pengujian ulang tidak menunggu 10 menit; default mati, hanya memori |
| Log aktivitas | Tidak disebut | Daftar event tertutup tanpa data lokasi (§15.5) | Success metric; tetap mematuhi NG04/A01 |
| Batas area layanan produk | Kampus Ganesha + ±200 m, poligon ditetapkan saat PB04 | Bounds engineering OSM way/177629384 v19 + 200 m dipakai sebagai batas produk (§9.3); belum diverifikasi lapangan | Keputusan tim 24 November 2026 agar trigger dan navigasi aktif di build produk |
| Backlog | PB01–PB20 | Ditambah PB21 (akun dan login wajib) dan PB22 (log aktivitas) pada Sprint 3; nomor PB01–PB20 tidak berubah | Fitur akun sebelum Feature Freeze |
| Layar | UI01–UI09 | Ditambah UI10 Daftar & Login; UI09 memuat akun, logout, dan hapus akun | Akun |
| Offline (A03) | Informasi tersedia tanpa jaringan | Tetap, tetapi login pertama memerlukan internet | Konsekuensi login wajib; A03 berprioritas Should |
| Firestore | Sumber data konten | Ditambah profil pengguna dan log aktivitas | Akun |
| Progres trail | Disimpan lokal | Tetap lokal, dipisahkan per akun di perangkat; tidak disinkronkan | Pergantian akun di perangkat yang sama |
| F06 / §11 — tujuan rute | Pintu masuk gedung/fasilitas | Titik akses: pintu masuk atau sisi lantai 1 yang terbuka ke jalur; boleh lebih dari satu per gedung; kandidat dihitung dari graf lalu diverifikasi di lapangan (`verified`). Rute boleh melewati lorong lantai 1 yang menyambung selasar antar-gedung | Sebagian besar gedung kampus tidak memiliki pintu masuk tunggal (keputusan 24 November 2026) |
| §10 — pengumuman tiba fasilitas | Tidak dirinci; TTS hanya untuk arahan navigasi | TTS runtime mengumumkan tiba di fasilitas; fallback visual bila suara `id-ID` tidak tersedia | Fasilitas tidak memiliki file audio tiba (keputusan 24 November 2026) |
| F08 / §12 — urutan dan awal trail | Urutan belum ditetapkan; usulan dari gerbang depan | Keliling terpendek antar-titik akses; trail dimulai dari POI terdekat dengan pengguna lalu searah putaran | Trail dapat dimulai dari mana saja tanpa menyeberang kampus dulu (keputusan 24 November 2026) |

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

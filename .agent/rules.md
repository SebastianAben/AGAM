# Aturan Coding Agent — AGAM

| Atribut | Nilai |
| --- | --- |
| Status | Aktif untuk seluruh pekerjaan di repository |
| Tanggal | 2 November 2026 |
| Tujuan | Menjaga konsistensi keputusan produk, implementasi, verifikasi, dan handoff antar-sesi serta antar-anggota tim |
| Cakupan | Source, test, data, konten, dokumentasi, CI/CD, dan rilis AGAM |

Kata **wajib**, **dilarang**, **sebaiknya**, dan **dapat** menetapkan tingkat kewajiban. Instruksi eksplisit pengguna berlaku di atas aturan ini. Jika instruksi pengguna bertentangan dengan `.agent/PRD.md` dalam hal scope, privasi, atau keputusan produk, jelaskan konfliknya dan minta keputusan sebelum melanjutkan pekerjaan yang bergantung padanya.

## 1. Tujuan Folder `.agent/`

Folder ini menyimpan kontrak produk dan konteks kerja lintas sesi agar setiap agent dan anggota tim bekerja dari fakta yang sama, bukan dari tebakan.

| File | Isi |
| --- | --- |
| `.agent/rules.md` | Aturan kerja (dokumen ini) |
| `.agent/PRD.md` | Kontrak produk: requirement, acceptance, keputusan, dan hal tertunda |
| `.agent/implementationPhases.md` | Rencana sprint, backlog PB01–PB20, dependency, dan status |
| `.agent/sessionHandoff.md` | Keadaan terkini, pekerjaan terakhir, blocker, dan langkah berikutnya |

Folder ini **bukan** tempat output sementara, credential, file media, atau salinan dokumentasi lain.

`AGENTS.md` di root adalah satu-satunya file instruksi agent. **Dilarang** menambahkan `CLAUDE.md`, karena keberadaannya membuat Claude Code mengabaikan `AGENTS.md`. Instruksi untuk tool lain ditambahkan dengan cara yang tetap merujuk ke `AGENTS.md` (mis. `context.fileName` di `.gemini/settings.json` untuk Gemini CLI).

## 2. Urutan Membaca Konteks

Sebelum mengerjakan apa pun, setiap agent **wajib**:

1. Membaca `.agent/rules.md` (dokumen ini) seluruhnya.
2. Membaca `.agent/sessionHandoff.md` untuk keadaan terkini.
3. Membaca bagian `.agent/PRD.md` yang relevan dengan tugas, termasuk requirement, acceptance criteria, dan [§22 Hal Tertunda](PRD.md#22-hal-tertunda-tbd).
4. Membaca bagian `.agent/implementationPhases.md` untuk PBI yang dikerjakan.
5. Memeriksa source, konfigurasi, dan test di area yang akan diubah jika sudah ada.

Jangan mulai menulis kode, konten, atau dokumentasi sebelum langkah 1–4 selesai. Jika file yang dirujuk belum ada, itu bukan bukti bahwa prosesnya sudah berjalan.

## 3. Otoritas Informasi

| Area | Sumber yang berlaku |
| --- | --- |
| Scope, fitur, mode, privasi, data, acceptance | `.agent/PRD.md` dan keputusan eksplisit PM |
| Urutan pekerjaan dan status PBI | `.agent/implementationPhases.md` |
| Keadaan terkini dan blocker | `.agent/sessionHandoff.md` |
| Perilaku aplikasi saat ini | Source, konfigurasi, dan hasil pemeriksaan yang benar-benar dijalankan |
| Dokumen PRD resmi (PDF/PPT, di luar repo) | Referensi historis; jika berbeda, `.agent/PRD.md` yang berlaku |

- Rencana bukan bukti implementasi. Kode yang ada tidak otomatis menggantikan target produk.
- Keputusan yang sudah dikunci di PRD (stack, radius, mode, privasi, peta, routing, bahasa, tanpa login) **dilarang** diubah diam-diam. Usulkan perubahan dengan alasan dan tunggu keputusan PM.
- Laporkan status secara terpisah: **ada di source**, **build berhasil**, **berjalan di emulator**, **berjalan di perangkat fisik**, **automated test lulus**, **lulus field test**. Jangan menaikkan status tanpa bukti.

## 4. Aturan Anti-Halusinasi

Ini adalah aturan terpenting di proyek ini.

### 4.1 Konten dan data

- **Dilarang mengarang** teks POI, trivia, sejarah, fungsi gedung, daftar fasilitas, foto, audio, video, alias resmi, atau atribusi sumber.
- **Dilarang mengarang** koordinat, termasuk koordinat pintu masuk, fasilitas, atau batas area kampus.
- Item di [PRD §22](PRD.md#22-hal-tertunda-tbd) (pintu masuk, dataset fasilitas, urutan trail, project Firebase, konten, perangkat uji) **belum tersedia**. Jangan mengisinya dengan nilai karangan.
- Jika kode membutuhkan data yang belum ada, gunakan placeholder yang jelas, misalnya teks `PLACEHOLDER — menunggu tim konten` atau field `"status": "placeholder"`, dan laporkan sebagai blocker. Placeholder dilarang terlihat seperti konten final.
- Data uji (fixture) untuk test boleh sintetis, tetapi wajib diberi label sintetis dan tidak boleh masuk ke dataset produksi.

### 4.2 Teknis

- **Dilarang mengarang** versi Flutter/Dart, versi package, versi minimum Android, API package, atau perilaku plugin. Periksa `pubspec.yaml`, `pubspec.lock`, dokumentasi resmi, atau source package sebelum memakai API.
- Jangan mengklaim command, script, test suite, atau workflow CI ada sebelum benar-benar dibuat dan diperiksa.
- Jika tidak yakin, katakan tidak yakin dan sebutkan cara memverifikasinya.

## 5. Batas Produk dan Engineering

### 5.1 Privasi (A01, NG04) — tidak dapat ditawar

- Posisi pengguna **dilarang** dikirim ke server mana pun: server tim, Firestore, server routing, server tile, analytics, crash reporting, atau API pihak ketiga.
- Posisi pengguna **dilarang** disimpan sebagai riwayat. Yang boleh disimpan lokal hanya ID POI dikunjungi, progres trail, dan pengaturan.
- Pembacaan lokasi mengikuti empat mode di [PRD §6](PRD.md#6-mode-aplikasi-dan-sesi-lokasi). Dilarang meminta izin lokasi "sepanjang waktu".
- Menambah SDK pihak ketiga yang berpotensi mengakses lokasi atau mengirim data perangkat memerlukan keputusan PM.

### 5.2 Stack yang dipertahankan

| Layer | Keputusan |
| --- | --- |
| Aplikasi | Flutter / Dart, target Android (APK) |
| Lokasi | `geolocator` (Fused Location Provider) + foreground service tipe `location` |
| Peta | Tile vektor OSM buatan sendiri (PMTiles), dibundel di APK |
| Routing | Graf jalur kampus (GeoJSON) + Dijkstra/A* di perangkat |
| Data | Firestore (baca saja dari aplikasi) + JSON bawaan + cache lokal |
| Audio | File audio untuk narasi/prompt/tiba; `flutter_tts` hanya untuk arahan navigasi |
| CI/CD | GitHub Actions → GitHub Releases |

Dilarang menambahkan tanpa keputusan PM:

- Backend/server milik tim, atau server routing.
- Google Maps SDK, Mapbox, atau server tile publik OSM.
- Firebase Storage untuk media, Firebase Auth untuk pengguna, Analytics, atau Crashlytics.
- Login atau akun pengguna, dan bahasa selain Bahasa Indonesia.
- iOS sebagai target rilis.

Pilihan engineering di dalam stack (state management, struktur folder, package penyimpanan lokal, renderer peta, library audio/video) dapat diputuskan developer, lalu dicatat di PRD atau handoff jika material.

### 5.3 Konten (A02)

- Setiap konten wajib memiliki metadata: sumber, tanggal verifikasi, penanggung jawab, atribusi aset.
- Konten tanpa metadata atau persetujuan tim dilarang ditandai siap rilis.
- Media hanya boleh masuk repository jika hak penggunaannya jelas. Atribusi OpenStreetMap (ODbL) wajib tampil di peta.

### 5.4 Secrets

- Dilarang meng-commit credential, service account, keystore, atau password.
- File konfigurasi Firebase klien (`google-services.json`) bukan secret, tetapi keamanannya bergantung pada Firestore security rules (baca publik, tulis hanya akun tim).
- Keystore rilis dan password-nya disimpan di GitHub Secrets.

## 6. Verifikasi

### 6.1 Memilih pemeriksaan

Pemeriksaan di bawah adalah **target** yang tersedia setelah PB01. Periksa dulu bahwa project, script, dan suite-nya benar-benar ada.

| Perubahan | Pemeriksaan |
| --- | --- |
| Dokumentasi | Konsistensi isi, link/anchor, tabel, dan `git diff --check` |
| Kode Dart | `flutter analyze` dan `flutter test` untuk area terdampak |
| Geofence, haversine, routing, pencarian | Unit test dengan nilai yang dihitung secara independen (bukan menyalin rumus implementasi) |
| Alur layar | Widget test / `integration_test`; uji manual di emulator |
| Lokasi, background, trigger | Uji di **perangkat fisik**; emulator dengan mock location hanya bukti awal |
| Data Firestore / JSON | Validasi skema; uji fallback saat offline dan saat dokumen tidak valid |
| Build / rilis | `flutter build apk` dan workflow GitHub Actions |
| Acceptance F01–F08 | Field test di Kampus Ganesha dengan evidence (video, log, catatan penguji) |

### 6.2 Kejujuran evidence

- Catat command, cakupan, hasil, dan keterbatasan. Test yang tidak dijalankan dilaporkan sebagai tidak dijalankan, bukan PASS.
- Dilarang menurunkan threshold, menghapus assertion, atau melewati test agar terlihat lulus.
- Hasil di emulator atau dengan mock location bukan bukti acceptance field test.
- Acceptance yang membutuhkan penguji manusia (mis. F04 ≥3 penguji, F06 4 dari 5 tujuan) hanya berstatus selesai jika pengujian nyata sudah dilakukan dan hasilnya tercatat.

## 7. Memperbarui Dokumentasi

Perbarui dokumen yang terdampak jika ada perubahan material pada:

- Scope, fitur, mode, acceptance criteria, atau privasi → `.agent/PRD.md`. Jika berbeda dari baseline W9, tambahkan ke [PRD §23](PRD.md#23-perbedaan-terhadap-prd-baseline-w9) agar PM mencatatnya di Change Log resmi.
- Skema data, nilai kalibrasi (radius, histeresis), atau batas area → `.agent/PRD.md`.
- Status PBI atau dependency → `.agent/implementationPhases.md`.
- Keadaan kerja di akhir sesi → `.agent/sessionHandoff.md`.

Jangan menulis riwayat percakapan ke PRD. Dokumentasi saja tidak menaikkan status implementasi.

## 8. Git dan Delivery

- Periksa branch, diff, dan working tree sebelum mengedit. Pertahankan perubahan anggota tim lain.
- Pekerjaan dibagi ke tiga track paralel (FE, LA, LB). Ikuti alur kerja, kepemilikan folder, dan aturan perubahan kontrak di `.agent/implementationPhases.md` §2. Jangan mengubah folder milik track lain atau `lib/contracts/` secara sepihak.
- Setiap bagian PBI dikerjakan di branch sendiri (`<jenis>/pbXX-<track>-<topik>`) dan masuk ke `main` lewat PR yang direview minimal satu developer lain.
- Dilarang commit, push, merge, membuat rilis, atau publish tanpa instruksi pengguna.
- Hindari operasi Git destruktif (force push, reset hard, menghapus pekerjaan yang belum di-commit).
- Stage hanya file yang terkait tugas.
- Gunakan conventional commit: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `ci:`, `build:`, `chore:`. Subject singkat, imperatif, dan menjelaskan perilaku. Contoh:

```text
feat: add in-app geofence engine with dwell and cooldown
fix: ignore location fixes worse than 20 m accuracy
docs: record calibrated POI radius values
```

- Jangan mencantumkan nomor sprint atau riwayat percakapan sebagai subject commit.

## 9. Kolaborasi dan Bahasa

- Dokumentasi memakai Bahasa Indonesia yang mudah dipahami; identifier, kode, dan istilah teknis boleh dalam English.
- Teks antarmuka aplikasi wajib Bahasa Indonesia.
- Ajukan pertanyaan hanya jika jawabannya memengaruhi scope, privasi, konten, atau keputusan yang belum ditetapkan. Jangan menanyakan ulang keputusan yang sudah ada di PRD.
- Penggunaan AI wajib dapat dipertanggungjawabkan: tim tetap memahami, memverifikasi, menguji, dan mendemonstrasikan setiap fitur. Catat penggunaan AI yang material untuk AI & Tools Disclosure (PB20).

## 10. Penyelesaian Sesi

Sebelum mengakhiri pekerjaan:

1. Periksa diff akhir; pastikan perubahan sesuai tugas.
2. Jalankan pemeriksaan yang relevan; catat yang tidak dijalankan beserta alasannya.
3. Perbarui `.agent/implementationPhases.md` jika status PBI berubah.
4. Perbarui `.agent/sessionHandoff.md` untuk pekerjaan lintas sesi: tujuan, file yang berubah, selesai/belum, keputusan, blocker, pemeriksaan, dan langkah berikutnya.
5. Laporkan hasil, lokasi file penting, verifikasi nyata, serta blocker secara ringkas.

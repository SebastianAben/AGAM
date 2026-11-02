# Session Handoff — AGAM

## Current — setup dokumentasi agent, 2 November 2026

**Tujuan sesi:** menyusun kontrak produk dan aturan kerja untuk tim dan coding agent sebelum pengembangan dimulai.

**Keadaan repository:**

- Branch `main`, remote `git@github.com:SebastianAben/AGAM.git`.
- Hanya berisi dokumentasi: `README.md`, `AGENTS.md`, dan `.agent/`.
- `AGENTS.md` adalah satu-satunya file instruksi agent; dibaca otomatis oleh Codex, Claude Code (≥ v2.1.277), Cursor, GitHub Copilot, dan Antigravity. Jangan menambahkan `CLAUDE.md` karena akan membuat Claude Code mengabaikan `AGENTS.md`. Gemini CLI memerlukan `.gemini/settings.json` (`context.fileName`) jika dipakai.
- **Belum ada kode aplikasi**, project Flutter, workflow CI, atau test. Seluruh PBI berstatus `planned`.

**Keputusan yang dikunci sesi ini** (rincian di `.agent/PRD.md`):

- Radius trigger 15 m untuk semua POI; filter akurasi 20 m; dwell 5 detik; cooldown 10 menit.
- Stack mengikuti presentasi PRD: Flutter, `geolocator`, OSM, Firestore, `flutter_tts`.
- Semua POI memiliki narasi audio; video GKUB/GKUT masuk lingkup.
- Empat mode: peta biasa, Explore, Navigasi, Orientation Trail; sesi berakhir manual atau otomatis 30 menit di luar area.
- Semua perhitungan di perangkat; routing di perangkat dengan graf jalur kampus; lokasi tidak pernah dikirim.
- Tile vektor OSM buatan sendiri dibundel di APK sejak Sprint 1.
- Firestore hanya untuk data teks; media dibundel di APK.
- Narasi/prompt/tiba = file audio; TTS runtime hanya untuk arahan navigasi.
- Bahasa Indonesia saja; tanpa login; tanpa backend milik tim; distribusi via GitHub Releases.

**Tindakan PM yang tertunda:**

- Mencatat perbedaan terhadap baseline W9 ([PRD §23](PRD.md#23-perbedaan-terhadap-prd-baseline-w9)) di Change Log PRD resmi.

**Blocker / data yang belum tersedia** ([PRD §22](PRD.md#22-hal-tertunda-tbd)):

- Project Firebase belum dibuat.
- Konten P01–P10 belum tersedia.
- Koordinat pintu masuk menunggu survei.
- Urutan Orientation Trail belum ditetapkan.
- Dataset fasilitas akan dikumpulkan.
- Perangkat uji belum ditetapkan.

**Hal yang wajib diverifikasi saat PB01** (jangan diasumsikan): versi Flutter/Dart terpasang, minSdk yang didukung, versi package, renderer tile vektor, ukuran APK.

**Pemeriksaan yang dijalankan:** hanya pemeriksaan konsistensi dokumentasi. Tidak ada build atau test karena belum ada kode.

**Model kerja:** tiga track paralel dengan satu developer per track — FE (frontend), LA (lokasi/sesi/data/audio), LB (peta/rute/pencarian/trail). Track tidak terikat pada orang tertentu. Kerja paralel bergantung pada kontrak di `lib/contracts/` beserta fake; lihat `.agent/implementationPhases.md` §2–3. Desain layar UI01–UI09 sudah selesai.

**Langkah berikutnya:** Sprint 1 Hari 1–2 — LA menginisialisasi project Flutter dan CI (PB01), lalu ketiga developer menyusun kontrak dan fake sebelum bekerja paralel.

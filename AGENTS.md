# AGAM — Instruksi untuk Coding Agent

**Wajib dibaca sebelum melakukan apa pun di repository ini.**

AGAM (Aplikasi Ganesha Map) adalah aplikasi Android (Flutter) pemandu Kampus ITB Ganesha berbasis POI dan geofencing. Aturan, kontrak produk, backlog, dan handoff ada di folder `.agent/`. Brief implementasi ada di `task-implementation/`, sejajar dengan `.agent/`; brief logic LA/LB berada di `task-implementation/backend/`.

Sebelum menulis kode, konten, atau dokumentasi, baca secara berurutan:

1. `.agent/rules.md` — aturan kerja dan aturan anti-halusinasi (baca seluruhnya).
2. `.agent/sessionHandoff.md` — keadaan terkini dan langkah berikutnya.
3. `.agent/PRD.md` — bagian yang relevan dengan tugas, termasuk §22 Hal Tertunda.
4. `.agent/implementationPhases.md` — PBI yang sedang dikerjakan.

Aturan inti (rincian di `.agent/rules.md`):

- `.agent/` adalah sumber kebenaran. Jika ada konflik dengan dokumen lain atau asumsi Anda, `.agent/` yang berlaku.
- Jangan mengarang konten POI, koordinat, versi package, atau data yang ditandai TBD. Gunakan placeholder berlabel dan laporkan.
- Posisi pengguna tidak pernah boleh dikirim ke server mana pun atau disimpan sebagai riwayat. Log aktivitas akun hanya boleh berisi event di `.agent/PRD.md` §15.5.
- Jangan mengubah keputusan yang sudah dikunci (stack, radius, mode, peta, routing, bahasa, login wajib, daftar log aktivitas) tanpa persetujuan PM.
- Jangan commit, push, atau merilis tanpa instruksi pengguna.
- Di akhir sesi, perbarui `.agent/sessionHandoff.md` dan status PBI di `.agent/implementationPhases.md`.

# Brief Implementasi AGAM

## Fungsi

Brief memperinci pekerjaan developer/agent menjadi hasil yang dapat diimplementasikan, diperiksa, dan diintegrasikan. Brief tidak menggantikan [aturan](../rules.md), [PRD](../PRD.md), [implementation phases](../implementationPhases.md), atau kontrak pada `lib/contracts/`.

## Urutan baca

1. Ikuti urutan baca wajib pada `AGENTS.md`.
2. Baca brief pekerjaan yang dipilih.
3. Baca kontrak, source, dan test yang disebutkan brief.
4. Periksa branch, working tree, serta perubahan yang sudah ada.

Task dikerjakan pada branch tetap sesuai track (`LA`, `LB`, atau `FE`), bukan branch per task. PR integrasi ditujukan ke `dev`; versi stabil dipromosikan melalui PR `dev` ke `main`. Model branch lengkap mengikuti [implementation phases §2.5](../implementationPhases.md#25-alur-kerja-per-pbi). Nama file brief dan ID PBI tetap digunakan untuk scope serta pelacakan pekerjaan, bukan untuk membuat branch tambahan.

Jangan menganggap kondisi source dalam brief selalu mutakhir. Jika ditemukan perbedaan material, catat sebelum implementasi.

## Identitas pekerjaan

Nama file: `PBXX-TRACK-NN-topik.md`, misalnya [PB05-LA-01-geofence-engine.md](PB05-LA-01-geofence-engine.md). NN adalah urutan bagian pekerjaan, bukan nomor PBI baru. ID PB01–PB20 pada backlog tetap dipertahankan.

## Status dan evidence

- Status PBI: `implementationPhases.md`.
- Spesifikasi task: file brief masing-masing.
- Hasil sesi, blocker, dan command: `sessionHandoff.md`.

Menyelesaikan satu brief tidak otomatis menyelesaikan PBI induk. Test dengan fixture sintetis tidak membuktikan acceptance lapangan.

## Perubahan keputusan

Requirement tetap merujuk PRD dan konstanta kontrak. Jangan menyalin nilainya menjadi konstanta produksi yang berbeda.

Pilihan engineering baru harus diberi label:

- usulan;
- telah diterapkan, belum dikalibrasi; atau
- telah diverifikasi, dengan evidence.

Perubahan kontrak mengikuti persetujuan lintas track. Keputusan produk yang dikunci tetap membutuhkan keputusan PM.

## Ukuran task

Satu task harus menghasilkan perubahan yang dapat direview sebagai satu kesatuan. Pisahkan pekerjaan jika dependency eksternalnya berbeda, membutuhkan pemilik folder berbeda, dapat diterima secara independen, atau diff sulit diperiksa sebagai satu perubahan. Jangan memecah perubahan yang harus atomik untuk menjaga kompatibilitas.

# PB09-LA-01 — Format Aset Konten dan Validasi Metadata

| Atribut | Nilai |
| --- | --- |
| PBI | PB09 — Produksi konten 10 POI (bagian LA: format dan validasi) |
| Track | LA (format, validasi); isi konten oleh tim konten |
| Requirement | F03, A02, A03 |
| Status bagian ini | Format dan validasi otomatis tersedia; konten belum ada |

Dokumen ini untuk **tim konten**: cara menaruh teks, foto, audio, dan video POI agar terbaca aplikasi dan lolos pemeriksaan. Agent dan developer **dilarang** mengisi konten ini ([PRD §10](../../.agent/PRD.md#10-konten-dan-media)).

## 1. Teks dan metadata — `assets/data/pois.json`

Skema dan aturan validasi mengikuti [PRD §15.3](../../.agent/PRD.md#153-skema-konseptual). Untuk setiap POI, tim konten mengisi:

| Field | Isi | Contoh bentuk (bukan konten) |
| --- | --- | --- |
| `description` | Deskripsi gedung | teks Bahasa Indonesia |
| `function` | Fungsi gedung | teks |
| `facilities[]` | Fasilitas di dalam gedung | daftar teks |
| `trivia` | Trivia/sejarah singkat | teks |
| `aliases[]` | Alias tambahan (opsional) | `"labtek biru"` |
| `media` | Path aset (lihat §2) | `"assets/media/P01/narasi.mp3"` |
| `metadata.sources[]` | Sumber konten | daftar teks/URL |
| `metadata.verifiedAt` | Tanggal verifikasi, ISO 8601 | `"2026-11-20"` |
| `metadata.owner` | Penanggung jawab | nama anggota tim |
| `metadata.assetAttribution[]` | Atribusi setiap foto/audio/video | daftar teks |
| `metadata.approved` | `true` hanya setelah tim menyetujui | `false` sampai disetujui |
| `metadata.isPlaceholder` | Hapus atau `false` saat konten final | — |

`id`, `name`, `category`, `lat`, `lng`, dan `radiusM` **tidak diubah** tim konten; nilainya dikunci test terhadap [PRD §9.1](../../.agent/PRD.md#91-dataset-poi).

Metadata yang tidak lengkap membuat aplikasi memperlakukan POI sebagai placeholder dan memaksa `approved: false` (A02).

## 2. Media — `assets/media/<ID POI>/`

Satu folder per POI, misalnya `assets/media/P07/`. Path di `pois.json` ditulis lengkap dari root repository.

| Field `media` | Jenis | Format yang diterima | Catatan |
| --- | --- | --- | --- |
| `photos[]` | Foto gedung | `.jpg`, `.jpeg`, `.png`, `.webp` | Minimal 1 foto (F03) |
| `narrationAudio` | Narasi 45–90 detik | `.mp3`, `.m4a`, `.aac`, `.ogg` | Wajib untuk P01–P10 |
| `promptAudio` | Prompt trigger, mis. *"Anda mendekati …"* | sama dengan narasi | Diputar saat trigger Explore/Trail |
| `arrivalAudio` | Pengumuman tiba, mis. *"Anda telah tiba di …"* | sama dengan narasi | Dipakai PB12 |
| `video` | Video narasi | `.mp4` | Hanya P06 (GKUB) dan P07 (GKUT) |

Saran penamaan (tidak diwajibkan validator): `foto-1.jpg`, `narasi.mp3`, `prompt.mp3`, `tiba.mp3`, `video.mp4`.

Setiap folder POI yang berisi media wajib didaftarkan di `pubspec.yaml` oleh LA (folder `assets/media/` milik LA):

```yaml
flutter:
  assets:
    - assets/data/pois.json
    - assets/media/P07/
```

Media hanya boleh masuk repository jika hak penggunaannya jelas ([rules §5.3](../../.agent/rules.md#53-konten-a02)). Ukuran file memengaruhi ukuran APK; ukuran akhir APK belum diukur.

## 3. Perilaku aplikasi selama konten belum ada

- Path `null`/kosong → pemutar audio melaporkan `PlaybackStatus.error` tanpa crash. Trigger tetap memunculkan notifikasi dan getar.
- Teks berlabel `PLACEHOLDER — menunggu tim konten` dan `metadata.isPlaceholder: true` tidak boleh ditampilkan UI sebagai konten final.

## 4. Pemeriksaan otomatis

`test/logic/data/content_assets_test.dart` (dijalankan `fvm flutter test` dan CI):

1. Nama field `media` hanya yang ada di tabel §2.
2. Setiap path berada di `assets/media/<ID POI>/`, berekstensi yang didukung, dan file-nya ada.
3. Folder media setiap POI terdaftar di `pubspec.yaml`.
4. POI dengan `approved: true` wajib: bukan placeholder; `sources`, `owner`, `verifiedAt`, dan `assetAttribution` terisi; minimal 1 foto; narasi, prompt, dan audio tiba; teks tanpa `PLACEHOLDER`; video untuk P06/P07.

Validasi per dokumen saat runtime tetap dilakukan `lib/logic/data/poi_codec.dart` (PB03).

Test ini **tidak** memeriksa durasi narasi (45–90 detik), kualitas audio, kebenaran isi, maupun hak penggunaan. Hal tersebut diverifikasi tim sebelum `approved: true`.

## 5. Acceptance PB09

PB09 selesai hanya jika konten 10 POI lengkap, sumber tercatat, hak media aman, dan disetujui tim ([implementation phases PB09](../../.agent/implementationPhases.md#pb09--produksi-konten-10-poi)). Bagian LA ini tidak menutup PB09.

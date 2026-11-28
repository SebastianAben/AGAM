# PB04-LB-01 — Pipeline OSM ke PMTiles

## Identitas dan target

| Atribut | Nilai |
| --- | --- |
| PBI induk | PB04 — Explore Map dengan tile vektor dibundel |
| Track / branch | LB / `LB` |
| Requirement | F01, A03; privasi A01 |
| Status brief | Diadopsi 4 November 2026; evidence aktual di handoff |
| Status implementasi | Selesai secara teknis dan terverifikasi lokal; PB04 tetap `in_progress` |
| Output | Pipeline build-time yang dapat diulang, PMTiles, manifest, dan test |
| Dependency | Python 3.11+, Java 21+, internet untuk bootstrap/data yang belum di-cache |

Menghasilkan tile vektor kampus dan margin 200 m dari data OSM, untuk integrasi
offline berikutnya. Keberhasilan generator tidak menyelesaikan PB04 atau acceptance
Android/field test.

## Konteks wajib

Ikuti [AGENTS.md](../../AGENTS.md), [rules](../../.agent/rules.md), dan
[handoff](../../.agent/sessionHandoff.md). Baca [PRD](../../.agent/PRD.md) §9.3,
§14, §16, §22; [implementation phases](../../.agent/implementationPhases.md) §2
dan PB04; [panduan brief](../README.md). Periksa kontrak `MapConfig`,
`MapStyleSource`, dan fake yang masih memakai batas sintetis.

## Ownership dan batas task

- Implementasi, snapshot batas, dan test berada di `tools/tiles/`; aset di `assets/map/`.
- Tidak mengubah `lib/contracts/`, UI, Android, dependency Flutter, atau `pubspec.yaml`.
- Style AGAM, `MapConfig` asli, pendaftaran aset APK, renderer, dan uji perangkat
  adalah task lanjutan. PMTiles tidak otomatis dibundel sampai didaftarkan.
- Tidak mengirim atau menyimpan posisi pengguna. Network hanya pada build-time
  untuk sumber geografi publik dan tooling; tidak memakai server tile publik OSM.

## Input dan output

- Entry point: `tools/tiles/build-tiles.ps1`; helper stdlib Python `tile_pipeline.py`.
- Generator dikunci Planetiler **v0.10.2**, profil OpenMapTiles bawaan, MVT dalam
  PMTiles v3, zoom **12–16**, heap 4 GiB, empat thread. JAR diperiksa terhadap
  SHA-256 dari release resmi; JAR corrupt di cache ditolak, tidak dipercaya ulang.
- Input default extract Geofabrik Jawa. Operator dapat memberikan `.osm.pbf`
  lokal, URL asal untuk manifest, dan SHA-256 expected opsional. Checksum aktual
  selalu dicatat, termasuk saat expected tidak diberikan.
- Batas: snapshot API OSM `way/177629384`, versi 19. Identitas/nama/lokasi
  Ganesha diperiksa; ini sumber engineering, **bukan survei batas resmi**.
  Konfigurasi provenance dan SHA-256 snapshot disimpan bersama script.
- Coverage tile menggunakan envelope poligon dengan margin spherical 200 m
  (`R=6371008.8 m`), longitude dihitung konservatif pada lintang absolut maksimum;
  hasil dibulatkan keluar delapan desimal. Ini belum menetapkan perilaku
  `MapConfig.isInsideCampus`.
- Output default `assets/map/ganesha.pmtiles` dan `ganesha.manifest.json`:
  sumber/checksum input, provenance batas, generator/checksum JAR, waktu build,
  bounds/zoom, ukuran/checksum output, jumlah tile/feature, dan atribusi ODbL.
  Profil OpenMapTiles juga membutuhkan kredit OpenMapTiles; HTML atribusi asli
  dipertahankan pada manifest untuk integrasi renderer.
  ZIP sumber pendukung juga dicatat checksum dan URL retrieval konfigurasinya.
  `-WaterPolygonsUrl` mendukung mirror HTTPS bertanggal jika upstream tidak terjangkau;
  ini tidak mengganti profil atau menganggap cache manual berasal dari URL tersebut.
- Cache, scratch, dan log berada di `tools/tiles/.cache/`, diabaikan Git.

Jika status batas bukan `verified_osm_snapshot`, snapshot berubah checksum, atau
geometrinya invalid, hentikan sebelum unduhan/generator dan laporkan blocker.
Jangan memakai batas fake atau data sintetis untuk menghasilkan aset produksi.

## Prosedur dan kegagalan

Jalankan command pada [panduan pipeline](../../tools/tiles/README.md) dari root.
`-BoundsOnly` menampilkan coverage/provenance tanpa build. Script mendukung path
berspasi; argumen diberikan sebagai array, tanpa menyusun perintah shell.

Unduhan memakai file `.part` unik, memeriksa panjang dan checksum jika tersedia.
Unduhan dilakukan streaming ke disk tanpa memuat keseluruhan input ke memori.
Cache yang lengkap dipakai ulang;
untuk memperbarui extract latest, singkirkan salinan cache lama secara eksplisit.

Generator menulis pada staging di filesystem tujuan. Validator membaca seluruh
directory dan payload MVT: header/section bounds, zoom, metadata/atribusi,
pointer/count tile, serta feature geometri pada layer `building` dan
`transportation`. Hanya compression none/gzip yang diterima; format lain gagal
secara eksplisit.

Output existing ditolak kecuali `-Force`. Publikasi pasangan tile/manifest
memakai backup dan rollback jika pemindahan gagal. Ini bukan transaksi filesystem
dua-file yang tahan power loss; hentikan build paralel ke output yang sama dan
periksa backup bila proses dihentikan paksa.

## Pengujian dan penerimaan

1. Unit test stdlib Python, fixture berlabel **SINTETIS — bukan data kampus**:
   bounds, checksum, input hilang, download terpotong/gagal, generator gagal,
   archive invalid, path berspasi, output existing, dan rollback publikasi.
2. Wrapper PowerShell: parse dan jalankan `-BoundsOnly`, termasuk Windows
   PowerShell 5.1. Pemeriksaan ini tidak mengunduh data atau mengubah aset.
3. Build nyata, validasi seluruh tile/layer, lalu build ulang memakai PBF/cache sama;
   catat command, ukuran, hash, dan keterbatasan aktual.
4. Periksa link dokumentasi, diff, dan `git diff --check`. Perubahan Dart tidak ada;
   Flutter/build APK/perangkat bukan bukti yang diminta untuk task pipeline ini.

Task selesai secara teknis bila pipeline, aset nyata, manifest, dan verifikasi
rerun tersedia. Jika sumber/tooling gagal, laporkan bagian yang belum terverifikasi;
jangan mengganti dengan archive sintetis. PB04 tetap `in_progress` sampai style,
renderer, bundling, UI, dan acceptance perangkat selesai.

## Delivery

Implementasi ini tetap lokal pada `LB`, tanpa commit/push tambahan. Pembaruan
lintas branch sebelumnya hanya migrasi brief. Perbarui status PB04 dan handoff
dengan evidence nyata serta penggunaan AI material untuk PB20. Tanpa PR, merge
fitur, atau rilis.

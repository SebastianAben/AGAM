# Pipeline tile AGAM (PB04-LB-01)

Bagian [paket peta jalan kaki](#paket-peta-jalan-kaki-agam) berisi langkah
regenerasi aset aplikasi. Langkah Planetiler di bawah membuat arsip pembanding.

Jalankan dari root repository, menggunakan Python **3.11+** dan Java **21+**.
PowerShell **5.1+** adalah entry point; Docker/FVM tidak diperlukan untuk pipeline.

```powershell
# Periksa sumber batas dan coverage, tanpa unduhan/build.
./tools/tiles/build-tiles.ps1 -BoundsOnly

# Bootstrap JAR terverifikasi, unduh PBF Jawa, lalu buat PMTiles dan manifest.
./tools/tiles/build-tiles.ps1

# PBF existing, termasuk path dengan spasi. SHA expected bersifat opsional.
./tools/tiles/build-tiles.ps1 -OsmPbf 'D:/data peta/java.osm.pbf' -SourceUrl 'https://download.geofabrik.de/asia/indonesia/java-latest.osm.pbf'

# Ganti pasangan aset/manifest existing hanya setelah output baru lulus validasi.
./tools/tiles/build-tiles.ps1 -Force

# Test offline memakai fixture sintetis, tidak menyentuh aset produksi.
python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -v
```

Parameter lain: `-OsmSha256`, `-Output`, `-Cache`, `-Java`, `-Python`, `-Boundary`,
`-WaterPolygonsUrl`.
Path relatif untuk parameter operator dihitung dari working directory. Default
path dihitung dari lokasi script sehingga tetap benar bila dipanggil dari lokasi lain.

Setelah Planetiler selesai, pipeline memvalidasi arsip, menjalankan clustering
deterministik lokal (`cluster_pmtiles.py` v1), lalu memvalidasi hasil sebelum
menerbitkan pasangan arsip/manifest. Metadata dan payload MVT tidak diganti;
payload disusun menurut tile ID, directory/metadata memakai kompresi `none`.
Clustering diperlukan karena pembaca Dart `pmtiles 1.3.0` menolak arsip
unclustered. Implementasi ini dibatasi flat root ≤16 KiB dan menolak arsip
lebih besar; bukan pengganti CLI clustering untuk peta wilayah besar.
Manifest mencatat postprocess dan checksum output akhirnya.

Demo internal memakai `flutter_map 7.0.2` + `vector_tile_renderer 5.2.0` dan
`pmtiles 1.3.0`. `OfflineMapTiles` membaca arsip APK, merender seluruh tile kecil
AGAM ke PNG di memori, lalu `TileProvider` lokal memasoknya ke peta. Tidak ada
cache tile ke filesystem atau fallback jaringan. Paket jalan kaki memiliki
zoom native 12–18. Layer `VectorTileLayer` bawaan `vector_map_tiles` tidak dipakai
karena tetap menulis cache ke disk meskipun TTL nol.

```powershell
# Build demo dengan pengecualian login yang diizinkan PM, bukan build produk.
fvm flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true
python -X utf8 tools/tiles/audit_assets.py --apk build/app/outputs/flutter-apk/app-debug.apk
```

Demo menampilkan label internal dan fokus Explore/Labtek V. Cakupan peta
mengikuti bounds engineering OSM pada PRD §9.3. Aktivasi routing mengikuti
bootstrap dan konfigurasi area layanan pada build terintegrasi.

Unduhan pertama mencakup PBF Jawa (~899 MB saat inspeksi 4 November 2026),
JAR (~93 MB), serta sumber ocean/Natural Earth/lake centerline (~1,45 GB pada sesi ini) untuk profil OpenMapTiles.
Sediakan ruang disk untuk cache, input, dan scratch; jangan menyamakan ukuran
unduhan dengan ukuran tile APK. Heap dibatasi 4 GiB, concurrency empat thread.
Log generator: `tools/tiles/.cache/last-build.log`.

Jika penyedia poligon laut tidak terjangkau, gunakan mirror bertanggal yang
disebut pada [issue upstream Planetiler](https://github.com/onthegomap/planetiler/issues/1642).
Contoh sumber nyata yang digunakan pada sesi ini:

```powershell
./tools/tiles/build-tiles.ps1 -WaterPolygonsUrl 'https://ftp.fau.de/mirrors/openstreetmapdata.com-archive/2026-10-31/water-polygons-split-3857.zip'
```

Opsi tersebut diteruskan ke Planetiler; tidak mengganti profil atau memakai sumber
uji Monaco. Manifest menyimpan checksum semua ZIP pendukung dan URL retrieval
yang dikonfigurasi. Jika cache diisi manual, URL konfigurasi belum membuktikan
asal file tersebut; identitas yang dapat diperiksa adalah checksum. Cache ZIP
existing juga tidak di-refresh otomatis saat URL override berubah.

Arsip dan manifest Planetiler default berada di `tools/tiles/.cache/baseline/`.
Cache diabaikan Git; aset final dan provenance batas dapat direview. Default
extract bernama `latest` **tidak di-refresh otomatis** bila cache sudah ada.
Untuk hasil yang dapat diaudit, simpan PBF sumber sesuai checksum manifest;
download baru dari URL yang sama tidak dijamin memiliki isi yang sama.

## Paket peta jalan kaki AGAM

Peta aplikasi memakai `ganesha.gpkg` sebagai sumber layer `walk` untuk
PMTiles dan graf demo. Jalankan dari root repository.

```powershell
python -m pip install -r tools/tiles/requirements-campus.txt
python -X utf8 tools/tiles/export_campus.py
python -X utf8 tools/tiles/audit_assets.py
python -m unittest discover -s tools/tiles
```

`build_campus.py --source <snapshot.osm.pbf>` membangun ulang master dari
snapshot PBF terkunci. `build-tiles.ps1` menghasilkan arsip pembanding di
`tools/tiles/.cache/baseline/`. Paket aplikasi mencakup zoom native 12–18
dan rasterisasi 512 px. Atap, dinding dan bayangan diturunkan dari tapak
OSM sebagai efek visual. Graf demo berisi ruas jalan kaki dua arah dari
layer yang sama dengan garis putih peta dan berstatus draf.

`audit_assets.py --apk <file.apk>` memeriksa tiga aset peta dalam APK dan
memverifikasi byte graf demo bila ikut dibundel. Daftar `bundledEntries`
menunjukkan aset yang diperiksa. Pendaftaran graf dan bootstrap demo
mengikuti integrasi LA. Kontrol kamera dan penanda area mengikuti FE.

## Batas dan lisensi

Snapshot `campus-boundary.osm.json` berasal dari
[API OSM way/177629384](https://www.openstreetmap.org/api/0.6/way/177629384/full.json),
diambil 4 November 2026. Identitas kampus cocok dengan nama dan 10 posisi POI PRD;
ini tidak menggantikan survei lapangan. Konfigurasi dan checksum ada di
`campus-boundary.json`. Jangan mengedit geometri tanpa sumber yang diverifikasi.

Pipeline menolak batas placeholder atau snapshot dengan checksum berbeda.
Margin 200 m menghasilkan **coverage tile**; logic batas area layanan dan renderer
belum diimplementasikan dalam task ini.

Data: **© OpenStreetMap contributors**, [ODbL](https://www.openstreetmap.org/copyright).
Profil kartografi/schema OpenMapTiles memakai CC-BY dan meminta kredit
[© OpenMapTiles](https://github.com/openmaptiles/openmaptiles#license) dengan
tautan ke `https://openmaptiles.org/`. Renderer berikutnya wajib menampilkan
kedua kredit; HTML atribusi lengkap tersedia dalam metadata arsip/manifest.
Arsip berformat MVT mengikuti
profil OpenMapTiles; gunakan style yang cocok dengan schema tersebut.

Referensi: [Planetiler v0.10.2](https://github.com/onthegomap/planetiler/tree/v0.10.2),
[PMTiles v3](https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md),
[MVT 2.1](https://github.com/mapbox/vector-tile-spec/tree/master/2.1).

## Pemulihan kegagalan

Output final existing dipertahankan saat unduhan, generator, atau validasi gagal.
Jangan jalankan dua build ke output yang sama. `-Force` melakukan backup dan
rollback pasangan tile/manifest untuk exception biasa; pemadaman atau penghentian
paksa di tengah publikasi membutuhkan pemeriksaan manual file `.bak`.
File `.part` dari proses yang dihentikan paksa bukan cache valid dan boleh dihapus
setelah memastikan proses unduh sudah berhenti.

Status integrasi dan hasil verifikasi ada di
[handoff](../../.agent/sessionHandoff.md).

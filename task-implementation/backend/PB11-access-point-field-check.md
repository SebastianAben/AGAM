# PB11 — Daftar cek titik akses di lapangan

Dibuat oleh `tools/routing/plan_access_points.py` dari graf jalan kaki draf (`assets/routing/ganesha-walk-demo.geojson`) dan titik tengah gedung di `assets/data/pois.json`. Setiap titik adalah **kandidat**: proyeksi titik tengah gedung ke ruas jalur terdekat pada jaringan utama graf. Belum ada yang diverifikasi di lapangan (`verified: false`).

## Cara cek

1. Buka link peta tiap baris, lalu berdiri di titik tersebut.
2. Tandai **Cocok** bila dari titik itu orang memang masuk ke gedung (pintu atau sisi lantai 1 yang terbuka) dari jalur pejalan kaki.
3. Bila tidak cocok, berdiri di tempat orang masuk yang sebenarnya dan catat koordinatnya (Google Maps: tekan lama titik biru, salin angka). Bila gedung punya beberapa sisi masuk yang sering dipakai, catat juga sisi lainnya beserta arahnya.
4. Setelah dicek, koordinat di `pois.json` dikoreksi dan `verified` diubah menjadi `true` per titik.

## Kandidat

| POI | Gedung | Sisi | Lat | Lng | Jarak dari titik tengah | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P01 | Labtek V | barat daya | -6.8907403 | 107.6096439 | 23 m | [buka](https://www.google.com/maps?q=-6.8907403,107.6096439) | ☐ Cocok ☐ Koreksi: |
| P02 | Labtek VI | timur laut | -6.8900219 | 107.6098787 | 22 m | [buka](https://www.google.com/maps?q=-6.8900219,107.6098787) | ☐ Cocok ☐ Koreksi: |
| P03 | Labtek VII | barat | -6.8901175 | 107.6104257 | 16 m | [buka](https://www.google.com/maps?q=-6.8901175,107.6104257) | ☐ Cocok ☐ Koreksi: |
| P04 | Labtek VIII | barat daya | -6.8906368 | 107.6105083 | 9 m | [buka](https://www.google.com/maps?q=-6.8906368,107.6105083) | ☐ Cocok ☐ Koreksi: |
| P05 | Labtek X & XI | timur | -6.8889175 | 107.6097767 | 24 m | [buka](https://www.google.com/maps?q=-6.8889175,107.6097767) | ☐ Cocok ☐ Koreksi: |
| P06 | Gedung Kuliah Umum Barat | selatan | -6.8906646 | 107.608897 | 15 m | [buka](https://www.google.com/maps?q=-6.8906646,107.608897) | ☐ Cocok ☐ Koreksi: |
| P07 | Gedung Kuliah Umum Timur | barat daya | -6.8905032 | 107.6117897 | 26 m | [buka](https://www.google.com/maps?q=-6.8905032,107.6117897) | ☐ Cocok ☐ Koreksi: |
| P08 | Oktagon | barat laut | -6.8888957 | 107.6099707 | 20 m | [buka](https://www.google.com/maps?q=-6.8888957,107.6099707) | ☐ Cocok ☐ Koreksi: |
| P09 | TVST | barat daya | -6.8896356 | 107.6099737 | 17 m | [buka](https://www.google.com/maps?q=-6.8896356,107.6099737) | ☐ Cocok ☐ Koreksi: |
| P10 | Labtek I | barat | -6.8892101 | 107.6110291 | 18 m | [buka](https://www.google.com/maps?q=-6.8892101,107.6110291) | ☐ Cocok ☐ Koreksi: |

## Urutan trail (keliling)

Keliling terpendek di atas graf: 1536 m (~20 menit jalan kaki). Aplikasi memutar urutan ini agar dimulai dari POI terdekat dengan pengguna, lalu berlanjut searah putaran.

| Urutan | POI | Gedung | Ke berikutnya |
| --- | --- | --- | --- |
| 1 | P01 | Labtek V | 177 m ke Labtek VIII |
| 2 | P04 | Labtek VIII | 72 m ke Labtek VII |
| 3 | P03 | Labtek VII | 247 m ke Gedung Kuliah Umum Timur |
| 4 | P07 | Gedung Kuliah Umum Timur | 226 m ke Labtek I |
| 5 | P10 | Labtek I | 212 m ke Oktagon |
| 6 | P08 | Oktagon | 34 m ke Labtek X & XI |
| 7 | P05 | Labtek X & XI | 107 m ke TVST |
| 8 | P09 | TVST | 50 m ke Labtek VI |
| 9 | P02 | Labtek VI | 204 m ke Gedung Kuliah Umum Barat |
| 10 | P06 | Gedung Kuliah Umum Barat | 206 m ke Labtek V |

## Catatan graf

Graf draf berisi 1170 simpul dalam 17 potongan terpisah; jaringan utama 985 simpul. Kandidat hanya memakai jaringan utama, karena titik di potongan terpisah tidak dapat dijangkau rute. Saat cek lapangan, catat juga jalur nyata yang tidak ada di peta rute (misalnya selasar yang menghubungkan gedung).

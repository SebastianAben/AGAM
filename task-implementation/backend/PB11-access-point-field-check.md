# PB11 — Daftar cek titik akses di lapangan

Dibuat oleh `tools/routing/plan_access_points.py` dari data OSM yang juga digambar di peta: poligon gedung (`tools/tiles/ganesha.gpkg`) dan graf jalan kaki (`assets/routing/ganesha-walk-demo.geojson`). Titik akses adalah titik pada jalur yang menempel ke gedung (≤4 m dari dinding; 8 m bila tidak ada yang sedekat itu), digabung bila berjarak <5 m. Totalnya 35 kandidat untuk 10 gedung; semuanya belum diverifikasi (`verified: false`). Navigasi akan menuju titik akses terdekat milik gedung tujuan.

## Cara cek

1. Buka link peta tiap baris, lalu berdiri di titik tersebut.
2. Tandai **Cocok** bila dari titik itu orang memang masuk ke gedung (pintu atau sisi lantai 1 yang terbuka).
3. Tandai **Hapus** bila titik itu bukan jalan masuk (misalnya pagar, jendela, atau tembok tertutup).
4. Bila ada jalan masuk yang tidak tercantum, berdiri di sana dan catat koordinatnya (Google Maps: tekan lama titik biru, salin angka) beserta sisi gedungnya.
5. Setelah dicek, `pois.json` dikoreksi dan `verified` diubah menjadi `true` per titik.

## P01 — Labtek V

Poligon OSM: Labtek V (way/119419735).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur 1 | -6.8906313 | 107.6102478 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8906313,107.6102478) | ☐ Cocok ☐ Hapus |
| Titik akses sisi timur 2 | -6.8907117 | 107.6102482 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8907117,107.6102482) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat daya | -6.8907403 | 107.6096439 | 2.9 m | [buka](https://www.google.com/maps?q=-6.8907403,107.6096439) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 1 | -6.8906329 | 107.6093209 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8906329,107.6093209) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 2 | -6.890466 | 107.6093201 | 0.0 m | [buka](https://www.google.com/maps?q=-6.890466,107.6093201) | ☐ Cocok ☐ Hapus |
| Jalur terputus dari jaringan rute (tidak dipakai) | -6.8904645 | 107.6096411 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8904645,107.6096411) | ☐ Jalur nyata, perlu disambung ☐ Abaikan |

## P02 — Labtek VI

Poligon OSM: Labtek VI (way/119419729).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur laut | -6.8900219 | 107.6098787 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8900219,107.6098787) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 1 | -6.8902862 | 107.6093147 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8902862,107.6093147) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 2 | -6.890023 | 107.6093731 | 0.0 m | [buka](https://www.google.com/maps?q=-6.890023,107.6093731) | ☐ Cocok ☐ Hapus |
| Jalur terputus dari jaringan rute (tidak dipakai) | -6.8902856 | 107.6095855 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8902856,107.6095855) | ☐ Jalur nyata, perlu disambung ☐ Abaikan |

## P03 — Labtek VII

Poligon OSM: School of Pharmacy ITB (way/119414691).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur laut | -6.8900025 | 107.6110473 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8900025,107.6110473) | ☐ Cocok ☐ Hapus |
| Titik akses sisi timur | -6.8901188 | 107.611455 | 0.1 m | [buka](https://www.google.com/maps?q=-6.8901188,107.611455) | ☐ Cocok ☐ Hapus |
| Jalur terputus dari jaringan rute (tidak dipakai) | -6.8902538 | 107.6110458 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8902538,107.6110458) | ☐ Jalur nyata, perlu disambung ☐ Abaikan |

## P04 — Labtek VIII

Poligon OSM: Labtek VIII (way/119422837).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur | -6.8905532 | 107.6114021 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8905532,107.6114021) | ☐ Cocok ☐ Hapus |
| Titik akses sisi tenggara | -6.8907099 | 107.6111297 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8907099,107.6111297) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 1 | -6.8907161 | 107.6105091 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8907161,107.6105091) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 2 | -6.8906368 | 107.6105083 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8906368,107.6105083) | ☐ Cocok ☐ Hapus |
| Jalur terputus dari jaringan rute (tidak dipakai) | -6.8904501 | 107.6110471 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8904501,107.6110471) | ☐ Jalur nyata, perlu disambung ☐ Abaikan |

## P05 — Labtek X & XI

Poligon OSM: Labtek X (way/119419842), Labtek XI (way/119419843).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur laut 1 | -6.8887142 | 107.6096741 | 2.8 m | [buka](https://www.google.com/maps?q=-6.8887142,107.6096741) | ☐ Cocok ☐ Hapus |
| Titik akses sisi timur laut 2 | -6.8889175 | 107.6097767 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8889175,107.6097767) | ☐ Cocok ☐ Hapus |
| Titik akses sisi tenggara | -6.8896134 | 107.6097832 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8896134,107.6097832) | ☐ Cocok ☐ Hapus |
| Titik akses sisi selatan | -6.8897748 | 107.6093745 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8897748,107.6093745) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat laut | -6.8887148 | 107.6092416 | 3.1 m | [buka](https://www.google.com/maps?q=-6.8887148,107.6092416) | ☐ Cocok ☐ Hapus |
| Titik akses sisi utara | -6.8887136 | 107.6093865 | 3.1 m | [buka](https://www.google.com/maps?q=-6.8887136,107.6093865) | ☐ Cocok ☐ Hapus |

## P06 — Gedung Kuliah Umum Barat

Poligon OSM: GKU barat (way/119419737).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi barat laut | -6.890139 | 107.6087204 | 3.2 m | [buka](https://www.google.com/maps?q=-6.890139,107.6087204) | ☐ Cocok ☐ Hapus |

## P07 — Gedung Kuliah Umum Timur

Poligon OSM: GKU Timur (way/119424003).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur | -6.8904699 | 107.612408 | 3.0 m | [buka](https://www.google.com/maps?q=-6.8904699,107.612408) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat daya | -6.8905032 | 107.6117897 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8905032,107.6117897) | ☐ Cocok ☐ Hapus |
| Jalur terputus dari jaringan rute (tidak dipakai) | -6.8905201 | 107.6119298 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8905201,107.6119298) | ☐ Jalur nyata, perlu disambung ☐ Abaikan |

## P08 — Oktagon

Poligon OSM: Oktagon (way/119419840).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur 1 | -6.8890511 | 107.6102704 | 1.8 m | [buka](https://www.google.com/maps?q=-6.8890511,107.6102704) | ☐ Cocok ☐ Hapus |
| Titik akses sisi timur 2 | -6.8891131 | 107.6102691 | 1.6 m | [buka](https://www.google.com/maps?q=-6.8891131,107.6102691) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat | -6.8889882 | 107.60986 | 2.8 m | [buka](https://www.google.com/maps?q=-6.8889882,107.60986) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat laut | -6.8888957 | 107.6099707 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8888957,107.6099707) | ☐ Cocok ☐ Hapus |

## P09 — TVST

Poligon OSM: TVST (way/119419841).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi timur 1 | -6.8894072 | 107.6102802 | 3.4 m | [buka](https://www.google.com/maps?q=-6.8894072,107.6102802) | ☐ Cocok ☐ Hapus |
| Titik akses sisi timur 2 | -6.8895149 | 107.6102835 | 2.5 m | [buka](https://www.google.com/maps?q=-6.8895149,107.6102835) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat daya | -6.8896356 | 107.6099737 | 0.0 m | [buka](https://www.google.com/maps?q=-6.8896356,107.6099737) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 1 | -6.8895544 | 107.6098592 | 2.5 m | [buka](https://www.google.com/maps?q=-6.8895544,107.6098592) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat 2 | -6.8894129 | 107.6098605 | 0.9 m | [buka](https://www.google.com/maps?q=-6.8894129,107.6098605) | ☐ Cocok ☐ Hapus |
| Titik akses sisi utara | -6.8892786 | 107.6099849 | 2.0 m | [buka](https://www.google.com/maps?q=-6.8892786,107.6099849) | ☐ Cocok ☐ Hapus |

## P10 — Labtek I

Poligon OSM: Labtek I - Mekanika Tanah (way/119423377).

| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |
| --- | --- | --- | --- | --- | --- |
| Titik akses sisi selatan | -6.8895553 | 107.6110389 | 1.7 m | [buka](https://www.google.com/maps?q=-6.8895553,107.6110389) | ☐ Cocok ☐ Hapus |
| Titik akses sisi barat | -6.88927 | 107.61103 | 2.6 m | [buka](https://www.google.com/maps?q=-6.88927,107.61103) | ☐ Cocok ☐ Hapus |

## Urutan trail (keliling)

Jumlah jarak jalan antar-gedung ±592 m, diukur dari titik akses terdekat ke titik akses terdekat; jalan menembus atau mengitari gedung untuk berpindah sisi tidak dihitung, jadi jarak tempuh nyata lebih panjang. Aplikasi memutar urutan ini agar dimulai dari POI terdekat dengan pengguna, lalu berlanjut searah putaran.

| Urutan | POI | Gedung | Ke berikutnya |
| --- | --- | --- | --- |
| 1 | P01 | Labtek V | 29 m ke Labtek VIII |
| 2 | P04 | Labtek VIII | 48 m ke Gedung Kuliah Umum Timur |
| 3 | P07 | Gedung Kuliah Umum Timur | 80 m ke Labtek VII |
| 4 | P03 | Labtek VII | 49 m ke Labtek I |
| 5 | P10 | Labtek I | 92 m ke TVST |
| 6 | P09 | TVST | 39 m ke Oktagon |
| 7 | P08 | Oktagon | 17 m ke Labtek X & XI |
| 8 | P05 | Labtek X & XI | 111 m ke Gedung Kuliah Umum Barat |
| 9 | P06 | Gedung Kuliah Umum Barat | 106 m ke Labtek VI |
| 10 | P02 | Labtek VI | 20 m ke Labtek V |

## Catatan graf

Graf berisi 1170 simpul dalam 17 potongan terpisah; jaringan utama 985 simpul. Hanya jaringan utama yang dapat dipakai rute. Jalur yang terputus, misalnya selasar antar-gedung, tercantum di tabel per gedung untuk dicek.

# AGAM (Aplikasi Ganesha Map)

AGAM adalah aplikasi Android pemandu Kampus ITB Ganesha yang berfokus pada titik-titik penting (Point of Interest/POI) di dalam kampus. Saat pengguna berjalan mendekati sebuah gedung, aplikasi akan memberi tahu pengguna dan menampilkan informasi gedung tersebut dalam bentuk foto, teks singkat, dan narasi audio.

Proyek ini dikerjakan sebagai Tugas Besar mata kuliah II4011 Transformasi Digital, Program Studi Sistem dan Teknologi Informasi, Institut Teknologi Bandung.

## Latar Belakang

Kampus Ganesha memiliki banyak gedung dengan nama dan nomor yang mirip, seperti Labtek V sampai VIII serta Gedung Kuliah Umum Barat dan Timur. Mahasiswa baru dan pengunjung sering kesulitan menemukan gedung yang dituju karena papan petunjuk terbatas, sementara aplikasi peta umum tidak mengenali nama internal kampus dan tidak menjelaskan fungsi setiap gedung. Informasi mengenai gedung dan fasilitas juga tersebar di berbagai sumber.

AGAM mengubah cara pengguna memperoleh informasi tersebut. Pengguna tidak perlu lagi mencarinya, karena informasi muncul sesuai dengan posisi pengguna di dalam kampus.

## Fitur Utama

| Fitur | Keterangan |
| --- | --- |
| Pemicu berbasis lokasi | Aplikasi mendeteksi ketika pengguna berada dalam radius 15 meter dari sebuah gedung, lalu memberikan notifikasi, getaran, dan prompt suara |
| Informasi multimodal | Setiap gedung memiliki kartu informasi berisi foto, fungsi gedung, fasilitas, trivia singkat, dan narasi audio |
| Interaksi tanpa melihat layar | Prompt suara, tombol berukuran besar, dan kontrol dari notifikasi memungkinkan aplikasi digunakan sambil berjalan |
| Pencarian | Gedung dan fasilitas dapat dicari dengan nama tidak resmi, misalnya "labtek 5", "GKUT", atau "Labtek Biru" |
| Navigasi jalan kaki | Rute menuju pintu masuk gedung atau fasilitas, lengkap dengan jarak, perkiraan waktu tempuh, dan arahan suara |
| Rekomendasi | Setelah mengunjungi sebuah gedung, pengguna mendapatkan saran gedung berikutnya dan fasilitas terdekat |
| Orientation Trail | Tur berurutan ke 10 gedung untuk mahasiswa baru, dengan pencatatan kunjungan otomatis, progres, dan lencana penyelesaian |

Aplikasi memiliki empat mode, yaitu peta biasa, Explore, Navigasi, dan Orientation Trail. Pemicu POI hanya aktif selama pengguna berada dalam mode Explore, Navigasi, atau Orientation Trail, dan tetap berjalan ketika layar ponsel dimatikan.

## Cakupan POI

Versi pertama AGAM mencakup 10 gedung di Kampus Ganesha:

1. Labtek V
2. Labtek VI
3. Labtek VII
4. Labtek VIII
5. Labtek X & XI (Labtek Biru)
6. Gedung Kuliah Umum Barat (GKUB)
7. Gedung Kuliah Umum Timur (GKUT)
8. Oktagon
9. TVST
10. Labtek I (Mektan)

## Privasi

Seluruh pemrosesan lokasi dilakukan di perangkat pengguna, termasuk perhitungan rute navigasi. AGAM tidak menyimpan riwayat perjalanan dan tidak mengirimkan posisi pengguna ke server mana pun. Data yang tersimpan hanya daftar gedung yang sudah dikunjungi, progres Orientation Trail, dan pengaturan aplikasi. Aplikasi juga dapat digunakan tanpa membuat akun.

## Teknologi

| Komponen | Teknologi |
| --- | --- |
| Aplikasi | Flutter (Dart), target Android |
| Lokasi | Fused Location Provider melalui `geolocator` |
| Peta | Tile vektor OpenStreetMap yang disertakan di dalam aplikasi |
| Data konten | Firebase Firestore dengan salinan lokal di dalam aplikasi |
| Audio | File narasi audio dan `flutter_tts` untuk arahan navigasi |

## Tim

Kelompok 03 / Warung

| Nama | NIM | Peran |
| --- | --- | --- |
| Sebastian Albern Nugroho | 18223074 | Project Manager / Scrum Master |
| Naura Ayurachmani | 18223061 | UI/UX & Content Lead |
| Noeriza Aqila Wibawa | 18223095 | UI/UX & Content Lead |
| Aliya Harta Ary Utama | 18223081 | Mobile / Frontend Developer |
| I Nyoman Rai Dharma | 18223083 | Backend Developer, QA, Content |

Dosen pengampu: Prof. Ir. Kridanto Surendro, M.Sc., Ph.D.

## Atribusi

Data peta bersumber dari © kontributor [OpenStreetMap](https://www.openstreetmap.org/copyright) dan tersedia di bawah lisensi Open Database License (ODbL).

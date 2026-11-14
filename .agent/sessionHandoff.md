# Session Handoff — AGAM

## Current — Keputusan akun, login, dan log aktivitas, 14 November 2026

**Tujuan:** mendokumentasikan fitur akun atas keputusan PM. Hanya dokumen; tidak ada perubahan kode. Atas instruksi PM, perubahan di-commit pada branch `chore/integration-fe-la-lb` yang dibuat dari `dev` (`a1775f7`); branch yang sama dipakai untuk integrasi berikutnya. Belum di-push.

**Keputusan PM:**

- 6 November 2026: login **wajib**, tidak membuka fitur tambahan; data akun hanya untuk keperluan internal tim (jumlah pengguna, success metric, log aktivitas). Keputusan 4 November (login opsional, opsi sinkron progres) tidak berlaku lagi.
- 14 November 2026: role Mahasiswa ITB dan Pengunjung sebagai label statistik; daftar event log tertutup (PRD §15.5); hapus akun tersedia; log dihapus paling lambat setelah penilaian akhir; tanpa verifikasi email, lupa password lewat email reset; teks pemberitahuan privasi disusun FE dan disetujui PM; progres lokal dipisahkan per akun dan tidak dihapus saat logout; PB21–PB22 dijadwalkan di Sprint 3; tugas utama dipegang LA.
- Pemeriksaan PDF PRD resmi (draft W9 dan presentasi), laporan Sprint 1–2, dan catatan asistensi 4 November: tidak ada fitur login di requirement, backlog, maupun sprint plan. Fitur akun adalah scope baru dan tercatat di PRD §23.

**File yang diubah:** `.agent/PRD.md` (header, §3, §4, §6, §15.1–§15.5, §16, §17, §18, §20, §22, §23), `.agent/rules.md` (§3, §5.1, §5.2, §5.4), `.agent/implementationPhases.md` (header, §2.1, §2.3, §3.3 baru, §4, §5 PB04, §7 beserta PB21/PB22, §10, §11), `AGENTS.md`, dan catatan ini.

**Rancangan privasi log:** event mode dan trail selesai hanya bertanggal karena jamnya dapat bertepatan dengan kedatangan di POI tertentu; `appOpen` hanya saat cold start supaya membuka aplikasi dari notifikasi trigger tidak meninggalkan jejak waktu trigger; rules Firestore memakai `hasOnly` untuk menolak field di luar daftar.

**Belum/terbuka:** project Firebase (Firestore + Authentication) belum dibuat; kontrak v1.1 (§3.3) belum disepakati ketiga track; desain UI10 dan teks pemberitahuan privasi belum ada; success metric dan tanggal penghapusan log belum ditetapkan. PM perlu mencatat perubahan §23 di Change Log PRD resmi.

**Pemeriksaan:** `git diff --check` dan pemeriksaan anchor tautan internal. Tidak ada build atau test karena tidak ada perubahan kode.

**Berikutnya:** PM meninjau diff dan menentukan commit; PM membuat project Firebase; integrasi `LA`/`LB`/`FE` ke `dev` (ditunda atas instruksi PM sampai dokumen akun selesai); usulan kontrak v1.1; PB21–PB22.

---

## Sebelumnya — Bagian LA PB12, 10 November 2026

**Lanjutan sesi yang sama**, setelah commit `38c54a0` di-push ke `origin/LA` atas instruksi pengguna (tanpa PR). Pengguna meminta pesan commit cukup `feat:` + PB, tanpa nomor sprint dan tanpa baris atribusi AI.

**Dibuat:** `lib/logic/audio/device_voice_guidance.dart` (`VoiceGuidance`, `flutter_tts` ^4.2.5, suara `id-ID` offline), `lib/logic/audio/navigation_announcer.dart` (arahan per langkah + audio tiba), query `TTS_SERVICE` di manifest, `createLaServices` kini menerima `navigation` (LB) dan membuat `voice` serta `navigationAnnouncer`. Test: `test/logic/audio/device_voice_guidance_test.dart`, `navigation_announcer_test.dart` (termasuk dengan `FakeNavigationController` kontrak).

**Pemeriksaan:** `fvm flutter analyze` tanpa issue; `fvm flutter test` **225 lulus**; `fvm flutter build apk --debug` berhasil dengan `flutter_tts`. Tidak ada uji perangkat.

**Keputusan terbuka (PM):** pengumuman tiba untuk fasilitas atau fallback TTS saat audio POI belum ada — tidak diterapkan karena PRD §10 membatasi TTS untuk arahan navigasi.

**Berikutnya:** sama dengan catatan di bawah; ditambah integrasi `NavigationAnnouncer` dengan `NavigationController` asli LB.

---

## Sebelumnya — Logic LA Sprint 1–2, 10 November 2026

**Tujuan:** atas permintaan pengguna, mengerjakan seluruh tugas track LA Sprint 1–2 (PB01 CI, PB02, PB03 sisa, PB05 sisa, PB06, PB08, bagian LA PB09). **Branch:** `LA` (dasar `accddc1`, sama dengan `main`/`dev`/`FE`). **Mesin:** macOS, FVM 4.3.2 + Flutter 3.47.9 / Dart 3.13.7 (`fvm flutter`). Belum ada commit, push, PR, atau rilis.

**Package ditambahkan** (versi diperiksa di pub.dev, dikunci `pubspec.lock`): `geolocator` ^14.1.2, `flutter_local_notifications` ^22.3.3 (sengaja bukan 23.0.0 yang dirilis 6 November 2026), `just_audio` ^0.10.6, `audio_service` ^0.18.19, `shared_preferences` ^2.5.6, `path_provider` ^2.1.6; dev `fake_async` ^1.3.3. Perilaku plugin yang dipakai diperiksa dari source di pub cache.

**Yang dibuat/diubah:**

- Android (`android/`): manifest (izin lokasi akurat, foreground service `location`/`mediaPlayback`, notifikasi/getar, `ACCESS_BACKGROUND_LOCATION` dihapus eksplisit, service/receiver audio_service, receiver aksi notifikasi); `MainActivity` turunan `AudioServiceActivity` + channel `site.agam/battery`; desugaring `desugar_jdk_libs` 2.1.4 (README plugin notifikasi); `.kotlin/` di `android/.gitignore`.
- `lib/logic/location/`: `position_source.dart` (geolocator, filter jarak 0), `adaptive_interval.dart`, `device_location_service.dart` (`LocationService`), `device_permission_service.dart` (`PermissionService`); `geofence_engine.dart` + `suspend()` dan `updatePois()`.
- `lib/logic/session/`: `device_session_controller.dart` (`SessionController`), `trigger_notifier.dart`, `trigger_responder.dart`.
- `lib/logic/audio/`: `audio_backend.dart`, `device_audio_service.dart` (`AudioService`), `agam_audio_handler.dart`.
- `lib/logic/settings/device_settings_store.dart` (`SettingsStore`; sebenarnya PB16, dibuat karena auto-play dipakai trigger/PB08).
- `lib/logic/la_bootstrap.dart`: `createLaServices(map:)` merangkai layanan LA asli. **Belum dipanggil** dari `main.dart`.
- CI: `checkout@v7`, `setup-java@v6`, `upload-artifact@v7`, `action-gh-release@v3`; CI juga pada push ke `dev`; `release.yml` menjalankan format + analyze.
- Brief/format konten: `task-implementation/backend/PB09-LA-01-content-format.md`.
- Test baru: `test/logic/{location,session,audio,settings,support}/`, `test/logic/data/content_assets_test.dart`, `test/android/manifest_privacy_test.dart`.
- Dokumen: PRD (header status, §9.2 parameter adaptif + keterbatasan, §17 package, §22), implementation phases (PB01–PB09).

**Keputusan engineering (belum dikalibrasi; tercatat di PRD §9.2):** zona dekat POI = radius + 30 m tanpa perlambatan; diam = <10 m selama ≥30 detik; area kampus hanya dari pembacaan ≤20 m. Interval adaptif hanya diterapkan saat aplikasi tampil karena geolocator memulai ulang foreground service saat langganan diganti. Tombol notifikasi Dengarkan/Lewati diteruskan dari isolate latar belakang ke isolate utama via `IsolateNameServer`.

**Pemeriksaan nyata (mesin ini):**

| Command | Hasil |
| --- | --- |
| `fvm dart format lib test` | Diterapkan; `dart fix --apply` untuk lint initializing formals |
| `fvm flutter analyze` | No issues found |
| `fvm flutter test` | **210 test lulus** (113 lama + 97 baru) |
| `fvm flutter build apk --debug` | Berhasil (`app-debug.apk` ±167 MB debug); Gradle mengunduh Android SDK Platform 35 |
| Manifest merge debug | Tanpa `ACCESS_BACKGROUND_LOCATION`; `INTERNET` dari manifest debug Flutter; `ACCESS_NETWORK_STATE` dari media3 |
| `git diff --check` | Lulus |

**Tidak dijalankan:** emulator, perangkat fisik, build rilis, workflow GitHub, field test. Catatan test: dalam `fakeAsync`, future `cancel()` bawaan Dart terjadwal di zona root sehingga penghentian langganan pada auto-end diverifikasi lewat jalur `_end` di test non-fakeAsync.

**Status:** PB02, PB06, PB08, PB09 → `in_progress` (logic LA selesai, belum terintegrasi/diuji perangkat). PB01/PB03/PB05 tetap `in_progress`. Tidak ada yang `done`.

**Blocker/tertunda:** Firestore (project Firebase belum ada); konten/audio P01–P10; perangkat uji; urutan trail. `VoiceGuidance` (PB12, Sprint 3) belum dibuat.

**Berikutnya:**

1. Review diff; commit di `LA` hanya dengan instruksi pengguna (disarankan dipisah: Android+package, lokasi/izin, sesi/notifikasi, audio/pengaturan, CI, dokumentasi).
2. Integrasi bersama FE/LB: panggil `createLaServices(map: <MapConfig LB>)` di `main.dart`, rangkai `AppServices` (sementara `FakeVoiceGuidance`). `TriggerResponder.viewRequests` belum ada di `AppServices` v1.0 → perlu kesepakatan FE (usulan kontrak §2.4) atau penyambungan di `main.dart`.
3. Uji perangkat fisik: izin (termasuk perkiraan), trigger saat layar mati, notifikasi + tombol di lock screen, narasi dari notifikasi, auto-end, optimasi baterai per merek, dan ikon notifikasi (saat ini memakai `ic_launcher`; ikon monokrom mungkin diperlukan).
4. Verifikasi CI baru berjalan di GitHub setelah push/PR.

---

## Sebelumnya — Bagian LB PB04-LB-01 pipeline tile, 4 November 2026

**Otorisasi dan publikasi:** rencana pengguna diimplementasikan berurutan. Migrasi folder brief di-commit sebagai `accddc1` (`docs: relocate implementation briefs to root directory`) dan di-push atomik melalui `git push --atomic -u origin main dev LA LB FE`. Hasil `git ls-remote --heads origin` memastikan kelima branch menunjuk `accddc1090d38338a558e396d8ecb19e88aa003f`; tree `task-implementation` semuanya `20b312a28580ab0178c166165d2cc13c8b0f9da1`. `LB`/`FE` dibuat dari `dev` yang telah diselaraskan. Branch historis PB03 lokal/remote tetap `b1b165b`. Checkout akhir pekerjaan ini adalah `LB`; implementasi di bawah **lokal, belum di-commit/push**. Tanpa PR, merge fitur, atau rilis.

**Perubahan LB:** [brief PB04-LB-01](../task-implementation/backend/PB04-LB-01-tile-pipeline.md), entry PowerShell/Python, validator seluruh directory/payload MVT, test offline, snapshot/provenance batas, dan [panduan](../tools/tiles/README.md). Cache unduhan/scratch/log di `tools/tiles/.cache/` diabaikan Git. Tidak mengubah kontrak, UI, Android, `pubspec.yaml`, atau dependency Flutter. PRD §9.3 mencatat coverage tile; PB04 `in_progress`, bukan acceptance peta Android.

**Batas terverifikasi:** snapshot API `way/177629384` versi 19, timestamp objek `2026-07-24T05:11:05Z`, diambil 4 November 2026; checksum `253567b5d47f8f5cebc492cbec0d4760fcaffd2f6e3ab5cb195701a6070c0b2b`. Seluruh 10 POI existing berada dalam poligon sumber. Envelope + 200 m menghasilkan west/south/east/north `107.60635935,-6.89545535,107.61454265,-6.88552795`. Ini coverage engineering OSM, bukan survei batas resmi atau implementasi `MapConfig`.

**Tooling/sumber nyata:** Python 3.13.14 lokal, Windows PowerShell 5.1.26100.9818, Java 21.0.12, Planetiler v0.10.2 (JAR 93.278.824 bytes; SHA-256 resmi `f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d`). Extract Jawa Geofabrik 899.224.839 bytes, checksum `091e9183554ac4a91b399726dd85e6d1050ea4fe4b1f0b772962c3764a195d3c`. Tidak mengubah Java/PATH sistem atau menambahkan package Python. Verifier independen `pmtiles` v1.31.2 di cache, binary dari release resmi (ZIP dicek terhadap digest GitHub).

**Kegagalan dan pemulihan:** percobaan unduhan byte-range PBF gagal HTTP 502, kemudian strategi streaming berhasil. Build pertama gagal saat Planetiler mendapat timeout dari `osmdata.openstreetmap.de` untuk poligon laut. Natural Earth dan lake centerline berhasil di-cache. Mirror FAU bertanggal 31 Oktober 2026 dirujuk issue upstream #1642; akses Python ke mirror menolak chain sertifikat, sehingga pengambilan memakai `curl.exe` Schannel dengan validasi TLS normal (tanpa `--insecure`). Opsi `-WaterPolygonsUrl` mencatat URL konfigurasi mirror. Masalah default path wrapper Windows PowerShell 5.1 ditemukan lewat smoke test lalu diperbaiki dan diuji ulang.

**Hasil task:** PB04-LB-01 **selesai secara teknis dan terverifikasi lokal**. `assets/map/ganesha.pmtiles` berukuran **1.035.927 bytes** (sekitar 1,04 MB), SHA-256 `8501f70bcc5d8b2624a4eaa12074006b99a4631d9deba21a5b91496087e844f3`. Dua build nyata menghasilkan arsip **identik byte demi byte**, 13 tile (zoom 12–16), layer `building` dan `transportation` bergeometri. Hitungan feature agregat pada tile unik: 99 building dan 5.703 transportation; ini **bukan** jumlah bangunan/jalan unik di kampus. Manifest mencatat sumber/checksum, ZIP pendukung, bounds, generator, statistik, dan HTML atribusi OpenMapTiles/OSM. Ukuran ini ukuran arsip, bukan ukuran akhir APK.

| Command/check aktual | Hasil | Batas evidence |
| --- | --- | --- |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -v` | 18 test lulus; pemeriksaan terakhir setelah penyelarasan validator/atribusi juga 18 lulus | Offline/sintetis, kecuali regression snapshot coverage 10 POI existing |
| `./tools/tiles/build-tiles.ps1 -BoundsOnly` dan pemanggilan melalui `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ... -BoundsOnly` | Lulus setelah perbaikan default path | Tidak membuat/mengunduh aset |
| Build pertama: `./tools/tiles/build-tiles.ps1 -WaterPolygonsUrl <mirror>` | Lulus pada data nyata; validasi seluruh directory/payload MVT sebelum publikasi | PBF default Geofabrik; sumber pendukung sudah di-cache saat pemulihan |
| Build kedua: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/tiles/build-tiles.ps1 -OsmPbf tools/tiles/.cache/java-latest.osm.pbf -OsmSha256 <sha-pbf> -SourceUrl <geofabrik> -WaterPolygonsUrl <mirror> -Force` | Lulus; hash, ukuran, bounds, dan jumlah feature sama dengan build pertama | Membuktikan rerun dengan input/cache identik, bukan URL `latest` di masa mendatang |
| `tools/tiles/.cache/pmtiles.exe verify assets/map/ganesha.pmtiles` | Lulus untuk kedua build | Verifier independen resmi v1.31.2; bukan render visual |
| `pmtiles.exe show ... --header-json` dan `--metadata` | MVT, gzip, zoom 12–16, bounds sesuai; kredit OSM/OpenMapTiles tersedia | Presisi bounds PMTiles tersimpan 7 desimal sesuai format |
| Pemanggilan wrapper tanpa `-Force` setelah output ada | Ditolak seperti diharapkan; SHA tile dan manifest tidak berubah | Dijalankan melalui Windows PowerShell 5.1; failure yang disengaja |
| Pemeriksaan file/anchor Markdown, `git diff --check`, cache/staging ignore, cleanup staging/backup | Lulus | Tidak ada staging atau `.bak` tertinggal setelah rerun |

Dalam tabel: `<mirror>` = `https://ftp.fau.de/mirrors/openstreetmapdata.com-archive/2026-10-31/water-polygons-split-3857.zip`; `<geofabrik>` = `https://download.geofabrik.de/asia/indonesia/java-latest.osm.pbf`; `<sha-pbf>` adalah checksum PBF pada paragraf tooling di atas. Command dijalankan dari root repository yang path-nya mengandung spasi. Manifest/log build pertama dan pemeriksaan no-force disimpan lokal pada `.cache/`; log terbaru `last-build.log` akan ditimpa oleh build berikutnya.

**Peringatan generator yang teramati:** poligon US/IE/GB tidak tersedia untuk inferensi atribut regional; relasi OSM `304751` tidak dapat membentuk poligon tertutup. Inspeksi API OSM mengidentifikasi relasi tersebut sebagai batas administratif Indonesia (level 2), bukan way batas kampus `177629384`. Arsip lulus verifikasi struktur, bounds, dan layer; kualitas tampilan akhir dan kelengkapan data OSM tetap memerlukan inspeksi renderer/perangkat. Tidak mengklaim bahwa seluruh geometri sumber sudah lulus survei.

**Langkah berikutnya:** review perubahan lokal LB; lanjutkan task style AGAM dan `MapConfig`, kemudian integrasi renderer/pendaftaran aset melalui review LA/FE sesuai ownership. Jangan meng-commit/push implementasi ini tanpa instruksi baru.

**Sisa PB04:** style AGAM, `MapConfig`/batas layanan asli, pendaftaran aset APK dan renderer bersama FE, UI02, uji offline/emulator/perangkat/field test. Flutter analyze/test/build tidak dijalankan karena perubahan task berupa tooling dan data peta; bukan perubahan Dart atau bukti acceptance Android.

**AI & Tools Disclosure (PB20):** agent membantu migrasi dokumentasi, menulis pipeline/validator/test/brief, memeriksa sumber publik, dan menjalankan verifikasi. Tim tetap perlu review serta memahami kode dan mendemonstrasikan integrasi perangkat.

---

## Sebelumnya — Bagian FE, Preview UI Profil pada tab Pengaturan, 10 November 2026

**Perubahan FE:** tab Pengaturan menampilkan preview statis Profil Pengguna dengan detail akun sesuai referensi. Header menampilkan logo saja; navbar utama tetap berada di shell dan menandai Pengaturan aktif. Tombol Logout hanya menampilkan snackbar preview dan tidak mengubah status akun/sesi. Foto profil memakai ikon placeholder karena aset portrait tidak tersedia terpisah.

**Batas kontrak:** tidak ada autentikasi, akun, role, penyimpanan profil, atau logout sungguhan yang ditambahkan. Konten preview diambil dari gambar yang diberikan pengguna. PRD tanpa login tetap berlaku; PB16 fasilitas/pengaturan belum selesai.

**Pemeriksaan aktual:** `dart format` dan `flutter analyze` untuk `app.dart`, `agam_bottom_navigation.dart`, dan `profile_preview_screen.dart` lulus (No issues found); `git diff --check` lulus; APK debug dibangun dan dipasang ke `emulator-5554`; halaman preview dibuka melalui tab Pengaturan. Automated test, perangkat fisik, dan field test tidak dijalankan.

**Berikutnya:** jika dibutuhkan, ganti ikon placeholder dengan aset foto berizin; integrasi fitur UI09/PB16 tetap mengikuti kontrak produk.

---

## Sebelumnya — Bagian FE, UI05 Cari & Rute dan pratinjau UI06, 9 November 2026

**Perubahan FE:** tab `Cari & Rute` kini membuka halaman UI05 dalam shell utama; header logo dan navbar tetap tersedia. Halaman menyediakan pencarian dari `SearchService`, filter kategori, daftar gedung yang berasal dari repository, pemilihan tujuan, dan panel pratinjau UI06. Tombol mulai navigasi memulai sesi foreground, menunggu pembacaan lokasi bila belum ada, lalu memanggil `NavigationController`.

**Batas dan anti-halusinasi:** map preview, rute, langkah, serta fasilitas di shell saat ini tetap bergantung pada service fake/sintetis. Titik masuk gedung belum disurvei; lokasi fasilitas dan konten yang belum disetujui tidak ditampilkan sebagai fakta. Seluruh tujuan tanpa pintu masuk diberi label placeholder. Voice guidance, graf jalan, rerouting, rekomendasi/riwayat, SearchService produksi, dan dataset fasilitas masih belum terintegrasi.

**Pemeriksaan aktual:** `dart format` tanpa perubahan; `flutter analyze lib/ui/app.dart lib/ui/search_route_screen.dart` **No issues found**; `git diff --check` lulus; APK debug dibangun dan dipasang ke `emulator-5554`. Setelah melewati UI01, tap pada tab Cari & Rute membuka UI05 dan navbar menandai tab aktif. Ini pemeriksaan manual emulator; perangkat fisik/field test dan automated test tidak dijalankan.

**Berikutnya:** integrasi LB untuk PB10/PB11 dan LA untuk sesi/voice tetap diperlukan; PB10/PB11 `in_progress`, bukan selesai.

---

## Sebelumnya — Bagian FE, UI04 Detail Lokasi dari Orientation Trail, 9 November 2026

**Perubahan FE:** pada UI08, kartu POI yang sudah tercatat check-in otomatis atau berstatus tiba menampilkan tombol `Check-in` dan `Details`. `Details` membuka UI04 melalui route halaman penuh. UI04 menyediakan AppBar kembali, hero foto (memakai aset POI yang disetujui bila tersedia; selain itu placeholder gambar), kartu narasi dengan playback melalui `AudioService` jika aset disetujui tersedia, transkrip, fungsi/deskripsi, fasilitas, trivia, sumber/atribusi, serta CTA navigasi dan status check-in. Tombol check-in hanya mengonfirmasi status otomatis kontrak Trail; tidak menambah check-in manual baru. Konten yang belum diverifikasi berlabel `PLACEHOLDER`.

**Batas:** foto, teks konten, fasilitas, trivia, atribusi, dan audio P01–P10 belum tersedia; seluruhnya tetap jelas sebagai placeholder. `AudioService`, TrailService, dan navigasi yang tersedia selain adapter lokasi masih fake, sehingga halaman ini belum menjadi UI04 acceptance final.

**Pemeriksaan aktual:** `fvm dart format` tanpa perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. APK dibangun/dipasang ke `emulator-5554`; dengan koordinat sintetis emulator pada P06, check-in otomatis tampil dan tombol Details membuka UI04. Ini hanya pemeriksaan emulator; test dan field test tidak dijalankan.

**Berikutnya:** tim konten memasok media/teks bersumber dan metadata; LA mengintegrasikan audio; LB/LA menyelesaikan check-in/navigation produksi. PB07 dan bagian FE PB08 tetap `in_progress`.

---

## Sebelumnya — Bagian FE, Izin dan lokasi perangkat nyata, serta header shell, 9 November 2026

**Perubahan FE:** tombol izin UI01 sekarang meminta izin lokasi Android foreground dengan `geolocator`; ketika diizinkan, UI02 membaca stream posisi perangkat dan menampilkan koordinat/akurasi pada peta/status. `DeviceLocationService` menghentikan stream saat tidak ada listener atau aplikasi masuk background, lalu memulai ulang saat foreground. Shell memakai `AgamAppHeader` sebagai `Scaffold.appBar`, sehingga logo tampil sejak pertama membuka Jelajah tanpa perlu berpindah ke Trail. Saat mulai Trail, fake session/navigation yang masih ada memakai `LocationService` yang sama; peta/routing/trail selain pembacaan posisi tetap implementasi contoh.

**Privasi dan batas integrasi:** manifest hanya meminta coarse/fine foreground; tidak meminta `ACCESS_BACKGROUND_LOCATION`, tidak menyimpan koordinat, dan tidak mengirimkannya. Implementasi sesi foreground/service, notifikasi, battery settings, serta acceptance perangkat fisik PB02/PB06/PB15 masih tertunda. File `pubspec.yaml` dan `android/app/src/main/AndroidManifest.xml` milik LA sesuai aturan track dan perlu review LA sebelum integrasi branch.

**Pemeriksaan aktual:** package `geolocator: ^14.1.2` dipasang; `fvm dart format --set-exit-if-changed` tanpa perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. APK berhasil dibangun/dipasang ke `emulator-5554`; dialog izin Android foreground tampil, setelah diberi izin status peta memperlihatkan pembacaan GPS (`±5m` pada emulator), dan halaman Trail dapat memulai sesi yang memakai stream lokasi. Ini bukti emulator, bukan perangkat fisik/field test. Test tidak dijalankan.

**Berikutnya:** LA review perubahan manifest/dependency dan pindahkan adapter ke implementasi logic milik LA; uji alur izin serta pembacaan lokasi di perangkat Android fisik. PBI tetap `in_progress`.

---

## Sebelumnya — Bagian FE, Shell tetap, logo, dan batas scroll UI Jelajah/Trail, 9 November 2026

**Perbaikan lanjutan:** UI02 dan UI08 sekarang berada dalam `AgamMainShell` dengan `IndexedStack`; header bersama (`AgamAppHeader`) dan satu `AgamBottomNavigation` berada di luar konten halaman. Berpindah tab mempertahankan widget/posisi scroll dan tidak menumpuk route. Logo header memakai `assets/media/logo.png`. Jelajah, Trail, filter Trail, dan isi kartu Jelajah mengatur `ClampingScrollPhysics` secara eksplisit; daftar Trail dan filter juga di-clip ke viewport. Status PBI tidak berubah.

**Pemeriksaan aktual:** `fvm flutter pub get` berhasil; format Dart tidak menemukan perubahan; `fvm flutter analyze` **No issues found**; `git diff --check` lulus. `fvm flutter run -d emulator-5554 --no-resident` membangun dan memasang APK. Header logo dan perpindahan ke tab Trail diperiksa melalui emulator; navbar terlihat sama. Test tidak dijalankan dan drag overscroll manual belum diukur.

**Berikutnya:** periksa drag scroll di emulator setelah pengguna menjalankan build terbaru. Bagian UI FE tetap belum menutup acceptance/integrasi PBI terkait.

---

## Sebelumnya — Bagian FE, Penyelarasan UI Jelajah dan Trail, 9 November 2026

**Perubahan FE:** navigasi bawah UI02 Jelajah dan UI08 Trail kini memakai `AgamBottomNavigation` bersama dengan ukuran, ikon, label, warna, serta inset sistem yang seragam; halaman aktif ditandai. Seluruh aplikasi memakai font Plus Jakarta Sans dari aset lokal di `assets/fonts/`, dengan lisensi OFL disertakan. `AgamScrollBehavior` memakai clamping dan meniadakan overscroll indicator, termasuk pada daftar Trail, filter horizontal, dan isi kartu Jelajah. Tombol pada kartu UI04 menutup panel sehingga hanya peta tersisa; saat panel diperluas, tombol tetap dapat menciutkannya.

**Pemeriksaan aktual:** `fvm flutter pub get` berhasil; `fvm dart format` pada file UI/widgets yang diubah; `fvm flutter analyze` **No issues found**. Test tidak dijalankan. Tidak ada commit/push.

**Berikutnya:** jalankan ulang aplikasi/emulator untuk pemeriksaan visual perangkat; status PB02/PB04/PB06/PB07/PB15 tetap `in_progress` sesuai integrasi layanan dan acceptance yang belum selesai.

---

## Sebelumnya — Bagian FE, UI08 Orientation Trail, 8 November 2026

**Pemetaan kode UI:** layar utama adalah **UI08 Orientation Trail** (PRD §18 / PB15). Panel progres, filter daftar, urutan POI, lencana, dan CTA tetap dalam UI08. Mini peta adalah pratinjau komponen UI02; CTA menginisiasi rute UI06. Callout pada contoh pengguna bukan hasil rekomendasi UI07; implementasi UI07 tetap terpisah.

**Perubahan FE:** `lib/ui/orientation_trail_screen.dart` menambahkan layout panjang scrollable dengan header/progres 0/10, statistik, badge, notice urutan TBD, filter semua/belum dikunjungi/selesai, kartu seluruh POI, peta skematis, CTA tetap di bawah, dan navigation bar. `lib/ui/explore_map_screen.dart` membuka UI08 dari tab Trail. Aksi mulai menggunakan `TrailService`, `SessionController`, dan `NavigationController` dari AppServices fake.

**Batas data:** daftar POI memakai nama P01–P10 dari PRD; urutan diambil dari `FakeTrailService` dan diberi label sintetis. Deskripsi, rute/jarak, media, dan progres tersimpan belum tersedia; UI mempertahankan placeholder dan tidak mengarang fasilitas/deskripsi. Mini peta dilabel ilustrasi karena tile/graf rute LB belum tersedia.

**Status PBI:** PB15 `in_progress` pada bagian FE. Urutan final masih TBD; penyimpanan progres lokal, sesi Trail asli LA, check-in terintegrasi LB, lencana acceptance, dan field test belum selesai.

**Pemeriksaan aktual:** `fvm dart format lib/ui/explore_map_screen.dart lib/ui/orientation_trail_screen.dart`; `fvm flutter analyze` **No issues found**; `fvm flutter run -d emulator-5554 --no-resident` membangun/memasang APK. Membuka tab Trail dan scroll sampai peta bawah diperiksa pada emulator; tidak ada exception Flutter baru pada log. Test tidak dijalankan.

**Berikutnya:** tinjau visual dengan tim; ganti urutan sintetis saat PM/tim menetapkan urutan resmi; integrasikan layanan LB/LA persisten dan navigation state sesudah tersedia.

---

## Sebelumnya — Bagian FE, UI02 Explore Map dengan UI03/UI04, 8 November 2026

**Definisi layar:** contoh pengguna menunjukkan gabungan tiga layar/state yang sudah didefinisikan PRD §18: UI02 Explore Map sebagai layar induk, UI03 trigger POI yang muncul di atas peta, dan UI04 kartu detail POI sebagai panel bawah. Bukan kode UI baru di luar UI01–UI09.

**Implementasi FE:** `lib/ui/explore_map_screen.dart` memakai `AppServices` dan fake contracts. Peta ilustratif, status posisi, penanda POI, kontrol sesi, bottom navigation, trigger, dan panel detail dibuat. Data ilustrasi diberi label; fasilitas fake menyebut contoh; foto/narasi tetap placeholder karena aset/konten resmi belum tersedia. `lib/ui/app.dart` meneruskan dari UI01 ke UI02 setelah izin fake berhasil.

**Status PBI:** PB02, PB04, PB06, dan PB07 `in_progress` pada bagian FE. Implementasi asli LA/LB, tile peta/routing, konten dan media, serta uji penerimaan belum selesai. Tidak mengubah kontrak bersama atau source track LA/LB.

**Pemeriksaan aktual:** format Dart untuk `app.dart`, `onboarding_screen.dart`, dan `explore_map_screen.dart`; `fvm flutter analyze` **No issues found**; `fvm flutter run -d emulator-5554 --no-resident` membangun dan memasang APK debug, UI02 terbuka setelah alur izin, log setelah perbaikan navigasi/layout tidak menunjukkan exception baru. `git diff --check` diperiksa. Test tidak dijalankan.

**Catatan keterbatasan:** SDK dan Android komponen pertama kali diunduh pada mesin ini; build pertama lama. Peta yang ditampilkan adalah skematis, bukan data jalan kampus atau tile offline. Logo, foto, narasi, dan fasilitas final belum tersedia.

**Berikutnya:** bandingkan visual pada emulator; koordinasikan konten/logo dengan tim terkait; integrasikan `MapConfig`, sesi, dan trigger asli saat LA/LB menyerahkan implementasinya.

---

## Sebelumnya — Bagian FE, Implementasi awal UI01 oleh FE, 8 November 2026

**Tujuan:** mulai mengimplementasikan layar Onboarding & Izin sesuai referensi visual yang dilampirkan pengguna dan PB02.

**Branch/keadaan:** `FE`; working tree sebelumnya bersih. Tidak ada commit, push, merge, atau rilis.

**Perubahan:** `lib/ui/onboarding_screen.dart` menambahkan tampilan onboarding responsif dengan kartu manfaat, pemberitahuan penggunaan lokasi, tombol izin, serta penanganan izin lokasi ditolak/perkiraan/permanen/layanan mati dan izin notifikasi opsional. `lib/ui/app.dart` menghubungkan layar ke `PermissionService` dari `AppServices.fake()` (dapat diinjeksi lewat konstruktor untuk integrasi berikutnya). Logo masih berupa mark ikon sementara karena aset logo resmi belum tersedia. Saat dijalankan, ukuran layar awal emulator sempat menghasilkan tinggi minimum negatif; batas layout diperbaiki agar aman ketika tinggi constraint belum tersedia.

**Status saat pencatatan awal:** UI01 FE baru mulai; PB02 `in_progress`. Handoff Current paling atas mencatat kemajuan sesudahnya.

**Pemeriksaan pada sesi awal:** format file UI01 dan build UI01 di emulator berhasil setelah memperbaiki tinggi layout awal. Analyzer dijalankan pada sesi UI02 berikutnya. Flutter 3.47.9/Dart 3.13.7 dan FVM 4.3.2 dipasang di mesin; Android SDK otomatis memasang NDK 28.2.13676358, Build Tools 36.0.0, dan CMake 3.22.1 selama build.

**Langkah berikutnya saat itu:** jalankan analyzer; lanjutkan layout dengan aset logo resmi bila tim menyediakannya; koordinasikan layanan izin asli dengan LA. UI02 kini tersedia sebagaimana catatan Current.

---

## Sebelumnya — Penyelarasan lokasi brief, 4 November 2026

**Otorisasi:** pengguna meminta satu commit dokumentasi diselaraskan dan di-push ke lima branch tetap (`main`, `dev`, `LA`, `LB`, `FE`), kemudian PB04-LB-01 dikerjakan lokal pada `LB`. Branch historis PB03 tidak diubah; tanpa PR, merge fitur, atau rilis. Instruksi ini menggantikan pembatasan publikasi sesi sebelumnya khusus migrasi dokumentasi ini.

**Struktur aktif:** panduan di `task-implementation/README.md`; brief logic LA/LB di `task-implementation/backend/`. Brief PB05 dipindahkan dari `.agent/tasks/`; seluruh penyebutan path lama di catatan historis di bawah menggambarkan lokasi pada waktu sesi tersebut, bukan lokasi aktif.

**Dasar pemeriksaan:** working tree bersih di `dev`; `main`, `dev`, dan `LA` lokal/remote sama-sama `29db871`; `LB`/`FE` belum ada. Pembuatan kedua branch dari `dev` dan publikasi eksplisit dilakukan setelah pemeriksaan dokumentasi. Hasil publikasi diverifikasi sebelum mulai implementasi LB dan dicatat dalam handoff lokal LB berikutnya.

**Verifikasi dokumentasi:** pemeriksaan target tautan relatif, referensi lokasi aktif, dan `git diff --check`. Status PBI tidak berubah oleh migrasi. Flutter/build/perangkat tidak diperlukan untuk perubahan dokumentasi ini.

---

## Sebelumnya — Migrasi progres LA dan publikasi GitHub, 4 November 2026

**Instruksi pengguna:** lanjutkan progres PB03/PB05 pada `LA`, biarkan branch PB03 lama, jangan push branch PB05 terpisah, dan push pekerjaan ke GitHub. Instruksi ini mengotorisasi commit/push untuk perubahan yang disiapkan; tidak mencakup merge ke `dev`/`main`, penghapusan branch PB03, atau rilis.

**Migrasi aktual:** branch lokal `feat/pb05-la-geofence-engine` diganti menjadi `LA` tanpa kehilangan perubahan. Dasarnya `b1b165b` sudah mencakup PB03 (`1344c21` dan `b1b165b`). Branch `feat/pb03-la-poi-repository` lokal/remote dipertahankan. Sebelum publikasi, remote `LA` maupun branch PB05 belum ada; remote `dev`/PB03 masih menunjuk `b1b165b` dan `main` menunjuk `fbef32c`. Branch LB/FE tidak dibuat dalam sesi ini.

**Commit:** `5256ec0` — `feat: add synchronous geofence engine with deterministic tests` (engine dan test PB05). Dokumentasi brief, parameter PRD, progres, serta aturan branch tetap disiapkan dalam commit terpisah pada `LA`. Catatan branch lama di bawah adalah riwayat sesi sebelumnya, bukan branch aktif.

**Verifikasi ulang sebelum publikasi:** SDK terkunci Flutter 3.47.9 / Dart 3.13.7 pada path absolut yang tercatat di sesi PB05 digunakan untuk `dart format --output=none --set-exit-if-changed lib test` (31 file, 0 perubahan), `flutter analyze` (tanpa issue), dan `flutter test --reporter compact` (**113 test lulus**). `git diff --check` lulus. Tidak ada perubahan dependency, UI, Android, atau CI. PB03 dan PB05 tetap `in_progress`; hasil ini bukan acceptance perangkat/field test.

**Publikasi:** hanya target `origin/LA` melalui `git push -u origin LA`. Hasil push dan kesamaan hash remote diperiksa setelah commit dokumentasi; hasil akhirnya dilaporkan pada chat. Jangan push semua branch, branch PB05, atau mengubah branch PB03 lama.

**Berikutnya:** pekerjaan LA menggunakan `LA`; integrasi berikutnya melalui PR `LA` → `dev`, bukan push langsung ke `dev`/`main`. Penyesuaian CI untuk push ke `dev` tetap tindak lanjut terpisah. LA-01 selesai secara teknis; integrasi PB06, interval adaptif, dan kalibrasi tetap tertunda.

---

## Pembaruan aturan branch tetap — 4 November 2026

**Permintaan:** mengganti model branch per task menjadi lima branch tetap `main`, `dev`, `LA`, `LB`, dan `FE`. `dev` menjadi pusat integrasi; `main` untuk versi stabil. Alur PR: branch track → `dev`, kemudian `dev` → `main` setelah verifikasi integrasi. Review, ownership, persetujuan perubahan kontrak, dan larangan commit/push/merge tanpa instruksi tetap berlaku.

**Perubahan sesi ini:** hanya `.agent/rules.md`, bagian alur kerja pada `.agent/implementationPhases.md`, `.agent/tasks/README.md`, dan catatan handoff ini. Tidak mengubah kode, workflow CI, status PBI, branch Git, atau pekerjaan PB05 yang sudah ada. Nama branch lama di catatan historis dipertahankan.

**Keadaan checkout saat pemeriksaan:** masih `feat/pb05-la-geofence-engine`, dengan perubahan implementasi/dokumentasi PB05 yang belum di-commit. Tidak dilakukan switch, rename, merge, maupun penghapusan branch agar pekerjaan sesi utama tidak terganggu. Migrasi checkout ke model baru memerlukan instruksi pengguna tersendiri.

**Verifikasi:** pemeriksaan konsistensi aturan branch aktif dan `git diff --check`; tidak menjalankan ulang test/build karena perubahan sesi ini hanya dokumentasi. Evidence test PB05 pada catatan sebelumnya tetap merupakan hasil sesi implementasi tersebut.

**Tindak lanjut:** siapkan/sinkronkan branch tetap sesuai instruksi pengguna; LA menyesuaikan CI agar push ke `dev` juga diperiksa. CI saat ini sudah mencakup PR, tetapi push hanya ke `main`. Ini belum mengubah konfigurasi atau branch protection GitHub.

---

## Current — PB05-LA-01 engine geofence dan brief task, 4 November 2026

**Tujuan:** mengadopsi brief task dan mengimplementasikan engine geofence murni sesuai rencana pengguna. **Branch:** `feat/pb05-la-geofence-engine`, dibuat dari checkout `dev` pada `b1b165b`. Perubahan review sebelumnya pada file ini dipertahankan. Tidak ada commit, push, merge, atau rilis.

**Perubahan:**

- `.agent/tasks/README.md`: tata cara brief, penamaan, konteks, ownership, dan evidence.
- `.agent/tasks/PB05-LA-01-geofence-engine.md`: spesifikasi diadopsi, API, state machine, validasi, matriks test, batas PB06, acceptance, dan contoh instruksi agent.
- `lib/logic/location/geofence_engine.dart`: engine sinkron memakai model/konstanta existing; snapshot POI, dwell/cooldown/histeresis, validasi input, timestamp monoton, dan kalkulator jarak terinjeksi. State pengguna hanya waktu/flag per POI; tanpa riwayat koordinat, jaringan, timer, atau penyimpanan.
- `test/logic/location/geofence_engine_test.dart`: 46 test deterministik; fixture sintetis, batas numerik, multi-POI, kualitas input, aktivasi, cooldown, snapshot, konfigurasi invalid, dan haversine default dengan acuan existing independen.
- PRD §9.2/§22: margin default 5 m serta jeda sampel maksimum 10 detik **diterapkan, belum dikalibrasi**. Implementation phases menautkan brief dan mencatat PB05/Sprint 2 `in_progress`; Sprint 1 belum dianggap selesai.

**Lingkungan dan command nyata:** pada awal sesi `fvm dart format ...`, `fvm flutter analyze`, serta kedua command test gagal dimulai karena `fvm` tidak ada di PATH. Flutter/Dart global juga tidak ditemukan. SDK resmi tag `3.47.9` (`c197ca5199e9ee5661e865596c9c07294dfab51c`) di-clone ke `C:\Users\ASUS\.cache\tooling\flutter-3.47.9`, di luar repo; bootstrap memastikan Flutter 3.47.9 / Dart 3.13.7. Metadata archive awal memberi HTTP NoSuchKey; unduhan SDK lewat bootstrap resmi kemudian berhasil. FVM 4.3.2 juga dipasang lewat `dart pub global activate fvm`, tetapi PATH sistem tidak diubah dan pemeriksaan berikut memakai SDK terkunci langsung. Tidak ada perubahan pubspec atau lockfile.

Dalam tabel, `<sdk>` = `C:\Users\ASUS\.cache\tooling\flutter-3.47.9`; command dijalankan dari root repo dengan operator PowerShell `&` dan path executable berpetik.

| Command/check | Hasil aktual | Cakupan/keterbatasan |
| --- | --- | --- |
| `<sdk>\bin\flutter.bat --version` | Flutter 3.47.9 / Dart 3.13.7 | SDK sama dengan `.fvmrc`; bukan Flutter global |
| `<sdk>\bin\flutter.bat pub get` | Lulus | Dependency existing, tanpa upgrade requirement/lockfile |
| `<sdk>\bin\cache\dart-sdk\bin\dart.exe format lib/logic/location/geofence_engine.dart test/logic/location/geofence_engine_test.dart` | Dua file diformat | Awalnya peringatan lint include belum ter-resolve sebelum pub get |
| `<sdk>\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test` | 31 file, 0 perubahan | Check setelah pub get |
| `<sdk>\bin\flutter.bat analyze` | No issues found | Analisis statis seluruh proyek |
| `<sdk>\bin\flutter.bat test test/logic/location/geofence_engine_test.dart` | 46 test lulus | Logic murni, bukan GPS/perangkat |
| `<sdk>\bin\flutter.bat test` | 113 test lulus | 67 existing + 46 geofence |
| `git diff --check` dan pemeriksaan tautan file lokal brief | Lulus | Tidak menggantikan review kode/manusia |

**Status:** LA-01 selesai secara teknis dan teruji lokal. PB05 tetap `in_progress`; acceptance F02/perangkat/lapangan belum diverifikasi. Tidak menjalankan APK build, emulator, perangkat fisik, CI remote, atau field test. UI, Android, kontrak bersama, fake, dan package tidak diubah. Penggunaan AI material sesi ini perlu dicakup PB20 oleh tim.

**Berikutnya:** review perubahan; lanjutkan PB02/PB04 dan integrasi Sprint 1. Sebelum PB06 memakai engine, tetapkan lifecycle instance, pembaruan dataset tanpa kehilangan cooldown, pemetaan enabled dari sesi/area, dan pemetaan kandidat menjadi respons per mode. Interval GPS adaptif tetap belum dikerjakan. Kalibrasi margin/jeda perlu perangkat fisik dan field test; daftar perangkat tetap menunggu tim.

---

## Review dokumentasi dan keadaan checkout — 4 November 2026

**Tujuan sesi:** memeriksa dan menjelaskan cara pengembangan proyek berdasarkan seluruh dokumen `.agent/`, disertai pemeriksaan terbatas terhadap source dan konfigurasi.

**Temuan:** checkout berada di branch `dev`; working tree bersih sebelum pencatatan ini. Commit terbaru `b1b165b` (dokumentasi PB03) dan `1344c21` (dataset dan repository POI) menunjukkan pekerjaan PB03 sudah di-commit pada checkout ini. Keterangan belum di-commit pada sesi sebelumnya merupakan catatan historis. Status implementasi pada header PRD (repository hanya berisi dokumentasi) sudah usang; source sudah memiliki scaffolding, kontrak/fake, dan lapisan data PB03. `lib/ui/app.dart` masih menampilkan placeholder "AGAM" dan dependency di `pubspec.yaml` belum mencakup plugin lokasi atau Firestore.

**Perubahan sesi:** hanya catatan review ini; tidak mengubah kode, keputusan produk, atau status PBI. PB01 dan PB03 tetap `in_progress`; blocker dan langkah implementasi pada sesi sebelumnya tetap berlaku. Status merge PB03 ke `main` tidak diverifikasi.

**Verifikasi:** membaca empat dokumen `.agent/`, memeriksa daftar source/test/aset, `lib/ui/app.dart`, `pubspec.yaml`, `.fvmrc`, serta branch, status, dan tiga commit terbaru. `git diff --check` dijalankan setelah pencatatan. Build, analyze, test Flutter, CI remote, dan uji perangkat tidak dijalankan; hasil 67 test dan CI pada sesi sebelumnya adalah evidence historis.

**Langkah berikutnya:** selaraskan catatan status dokumen dengan checkout saat pekerjaan implementasi berikutnya; lanjutkan sisa PB01, PB02, PB03, dan PB04 sesuai pembagian track. Panduan instalasi FVM lewat Homebrew pada dokumen berasal dari mesin sesi sebelumnya, bukan instruksi yang telah diverifikasi untuk Windows.

**Pemeriksaan lanjutan CI/CD:** membaca `.github/workflows/ci.yml`, `release.yml`, widget test placeholder, dan sebagian test repository. CI pada PR dan push ke `main` menjalankan format, analyze, test, build APK debug, lalu upload artifact. Release pada tag `v*` menjalankan test, build APK release, lalu menerbitkan GitHub Release; belum menjalankan format/analyze dalam workflow tersebut. Workflow belum menjalankan aplikasi di emulator/perangkat atau integration test. Push ke `dev` saja tidak memicu CI kecuali ada PR yang sesuai. Pemeriksaan ini hanya membaca konfigurasi lokal; tidak menjalankan test/build atau memverifikasi run GitHub terbaru. Tidak ada perubahan status PBI.

---

## Current — PB03 dataset dan PoiRepository (track LA), 3 November 2026

**Tujuan sesi:** mengerjakan bagian PB03 yang tidak bergantung pada project Firebase.

**Branch:** `feat/pb03-la-poi-repository` (dari `main` fbef32c). Perubahan belum di-commit.

**Yang dibuat:**

- `assets/data/pois.json` — dataset bawaan 10 POI. Id, nama, alias, kategori, koordinat, dan radius 15 m diambil dari [PRD §9.1](PRD.md#91-dataset-poi); seluruh teks dan media berlabel `PLACEHOLDER`, `entrances` kosong, `trailOrder` null, metadata belum disetujui. Didaftarkan di `pubspec.yaml` (folder `assets/data/` milik LA).
- `lib/logic/data/poi_codec.dart` — validasi per dokumen (tipe, rentang koordinat, radius > 0, field wajib, id ganda, kelengkapan metadata A02). Dokumen tidak valid diabaikan satu per satu beserta alasannya, bukan menggagalkan seluruh dataset.
- `lib/logic/data/poi_sources.dart` — `BundledDataset`, `DatasetCache` (`FileDatasetCache`, `InMemoryDatasetCache`), dan `RemoteDatasetSource`. Selama project Firebase belum ada, defaultnya `UnavailableRemoteSource` sehingga aplikasi menempuh jalur fallback [PRD §15.2](PRD.md#152-alur-sinkronisasi).
- `lib/logic/data/poi_repository_impl.dart` — `PoiRepository` asli: urutan cache → JSON bawaan, `refresh()` yang tidak pernah melempar error jaringan, dan dataset tanpa POI valid tidak dipakai maupun disimpan ke cache.
- `lib/logic/data/data.dart` — barrel export lapisan data.
- Test di `test/logic/data/`: validasi dokumen, alur sumber data, dan penguncian dataset bawaan terhadap PRD §9.1.
- [PRD §15.3](PRD.md#153-skema-konseptual) diperbarui: nama field final, nilai enum `category`, dan tabel aturan validasi.

**Pemeriksaan yang dijalankan (lokal, Flutter 3.47.9 via FVM):** `fvm dart format --set-exit-if-changed lib test` tanpa perubahan; `fvm flutter analyze` tanpa issue; `fvm flutter test` **67 test lulus** (56 baru + 11 test kontrak). Test dataset bawaan diuji benar-benar menangkap kesalahan: satu koordinat P01 sengaja diubah → test gagal; dataset dipulihkan → lulus kembali.

**Catatan lingkungan:** FVM belum ada di mesin ini dan dipasang sesi ini (`brew install leoafarias/fvm/fvm`, FVM 4.3.2) lalu `fvm install` mengambil Flutter 3.47.9 / Dart 3.13.7. Flutter global di mesin ini 3.35.7 (Dart 3.9.2) dan **tidak dapat** dipakai: `pubspec.yaml` mensyaratkan `sdk: ^3.13.7`. Gunakan `fvm flutter`, bukan `flutter`.

**Belum diverifikasi / blocked:**

- Sinkronisasi Firestore belum dibuat: project Firebase belum ada ([PRD §22](PRD.md#22-hal-tertunda-tbd)), `cloud_firestore` belum ditambahkan ke `pubspec.yaml`.
- Direktori cache untuk `FileDatasetCache` saat integrasi masih butuh package penyedia path; versinya wajib diverifikasi sebelum ditambahkan.
- PB03 belum terintegrasi dengan UI dan belum diuji di perangkat fisik, sehingga statusnya `in_progress`, bukan `done`.

**Temuan tentang PB01 (memperbaiki catatan sesi sebelumnya):** branch `chore/pb01-la-scaffolding` sudah di-merge ke `main` lewat PR #1 (fbef32c). Workflow CI **sudah berjalan dan sukses** dua kali (run 41424657609 pada PR dan 41424686250 pada `main`), masing-masing menghasilkan artifact `agam-debug-apk`. Jadi sisa PB01 tinggal memasang APK debug di perangkat fisik. Catatan "1 test lulus" di PB01 sudah usang; suite sekarang 67 test. CI memberi peringatan deprecation: `actions/checkout@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4` dipaksa ke Node.js 24, dan `ubuntu-latest` akan pindah ke Ubuntu 26 pada 19 Oktober 2026.

**Langkah berikutnya:**

1. Review dan merge PR PB03 (hanya menyentuh folder milik LA, `assets/data/`, `pubspec.yaml`, dan `.agent/`).
2. Pasang APK debug dari artifact CI di perangkat Android untuk menutup PB01.
3. LA melanjutkan PB02: `PermissionService` dan `LocationService` asli. Butuh menambah `geolocator` (dan package izin) dengan versi yang diverifikasi lebih dulu, plus perubahan di `android/`.
4. Saat project Firebase tersedia, implementasikan `RemoteDatasetSource` untuk Firestore dan ganti `UnavailableRemoteSource`; test alur fallback sudah tersedia.
5. Pertimbangkan memperbarui versi action di `.github/workflows/` (perubahan `.github/` milik LA).

---

## Sebelumnya — PB01 scaffolding dan kontrak v1.0, 2 November 2026

**Tujuan sesi:** membuat scaffolding project Flutter (PB01) agar ketiga track dapat mulai bekerja.

**Branch:** `chore/pb01-la-scaffolding` (dari `main` 3dff0f7). Perubahan belum di-commit.

**Yang dibuat:**

- Project Flutter khusus Android: application ID `site.agam`, label "AGAM", minSdk 24, targetSdk/compileSdk 36.
- Flutter 3.47.9 / Dart 3.13.7 dikunci dengan FVM (`.fvmrc`). FVM dipasang lewat Homebrew; developer menjalankan `fvm install` lalu memakai `fvm flutter`.
- Struktur folder per track (`.agent/implementationPhases.md` §2.3) dengan `.gitkeep`.
- Kerangka aplikasi: `lib/main.dart` → `lib/ui/app.dart` (`AgamApp`, layar placeholder bertuliskan "AGAM"); test `test/ui/app_test.dart`.
- `.github/workflows/ci.yml`: format, analyze, test, build APK debug (artifact) pada PR dan push ke `main`.
- `.github/workflows/release.yml`: tag `v*` → build APK rilis → GitHub Releases.
- `.gitignore` standar Flutter + `.fvm/`.

- Kontrak v1.0 di `lib/contracts/`: konstanta produk, model data, antarmuka layanan LA dan LB, fake yang saling terhubung, dan `AppServices.fake()`. Rincian di `.agent/implementationPhases.md` §3. **Disepakati ketiga track pada 2 November 2026**; perubahan berikutnya wajib mengikuti §2.4.
- Test kontrak di `test/contracts/`: jarak haversine dengan nilai acuan yang dihitung terpisah (Python), poligon kampus, progres trail, serta alur fake (pencarian alias, trigger, check-in, respons ringkas saat Navigasi, tiba ≤15 m).

**Pemeriksaan yang dijalankan (lokal, Flutter 3.47.9):** `dart format` tanpa perubahan; `flutter analyze` tanpa issue; `flutter test` 11 test lulus.

**Belum diverifikasi:**

- Build APK lokal: Android SDK belum terpasang di mesin setup (`flutter doctor`: "Unable to locate Android SDK"). JDK lokal adalah versi 27; CI memakai JDK 17.
- Workflow CI dan rilis belum pernah berjalan di GitHub.
- APK belum dipasang di perangkat fisik.

**Keputusan sesi ini:** kontrak v1.0 disepakati ketiga track; application ID `site.agam`; Flutter 3.47.9 via FVM (Homebrew); keystore rilis ditunda ke PB19. Selama itu APK rilis memakai debug key runner CI yang berbeda setiap run, sehingga penguji harus uninstall sebelum memasang versi baru.

**Blocker / data yang belum tersedia** ([PRD §22](PRD.md#22-hal-tertunda-tbd)): project Firebase, konten P01–P10, koordinat pintu masuk, urutan trail, dataset fasilitas, perangkat uji.

**Tindakan PM yang tertunda:** mencatat perbedaan terhadap baseline W9 ([PRD §23](PRD.md#23-perbedaan-terhadap-prd-baseline-w9)) di Change Log PRD resmi.

**Model kerja:** tiga track paralel dengan satu developer per track — FE (frontend), LA (lokasi/sesi/data/audio), LB (peta/rute/pencarian/trail). Track tidak terikat pada orang tertentu. `AGENTS.md` adalah satu-satunya file instruksi agent; jangan menambahkan `CLAUDE.md`.

**Langkah berikutnya:**

1. Commit dan push, buka PR, pastikan workflow CI lulus (termasuk build APK). Disarankan dua commit/PR terpisah: scaffolding PB01 dan kontrak v1.0.
2. Pasang APK debug dari artifact CI di perangkat Android untuk menutup PB01.
3. Kerja paralel Sprint 1 dimulai sesuai `.agent/implementationPhases.md` §5 (PB02–PB04).
4. FE menyambungkan `AppServices.fake()` ke `AgamApp` (saat ini `lib/ui/app.dart` belum memakai layanan apa pun).

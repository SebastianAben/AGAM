# Rencana Sementara Demo APK — Peta Offline dan Trigger POI

> **Status:** dokumen sementara untuk target demo vertikal. Dokumen ini bukan pengganti PRD, status PBI, atau acceptance produk.
> **Dibuat:** 14 November 2026.
> **Aturan utama:** pekerjaan demo belum boleh dinyatakan selesai sebelum kriteria demo terpenuhi dan dokumen ini dihapus sesuai bagian “Penghapusan wajib”.

## 1. Target demo

Pengguna memasang APK debug, memakai flag internal demo, lalu membuka peta kampus offline, melihat posisi/penanda POI, memulai Explore, menerima trigger, dan membuka kartu POI. UI05 memberi jalur kedua: pencarian alias pada repository aktif membuka UI04 dan audio POI.

Target ini membuktikan satu vertical slice demo dengan dua jalur masuk ke kartu POI. Target ini **tidak** menandai F01/F02, PB04–PB09, atau acceptance lapangan sebagai selesai.

## 2. Kondisi awal dan progres yang sudah ada

Snapshot terakhir yang dapat diperiksa pada 14 November 2026:

| Bagian | Progres | Yang belum terbukti |
| --- | --- | --- |
| Android/Flutter | Project Flutter menargetkan APK Android; FVM mengunci Flutter 3.47.9 / Dart 3.13.7. | APK dari integrasi terbaru belum berhasil dibangun dan dipasang. Build lama pada branch LA bukan bukti untuk versi integrasi terbaru. |
| Tile peta | PB04-LB-01 membuat `assets/map/ganesha.pmtiles` dan manifest. Pipeline dan 18 test tooling pernah lulus; arsip memiliki 13 tile pada zoom 12–16. Commit pipeline `ed2e7c0` sudah masuk integrasi `dev` melalui `86480da`. | Renderer belum dipasang; UI02 masih peta skematis. |
| Lanjutan PB04 | Worktree `AGAM-LB-PB04` di branch lokal `LB` pada `d602fed` memiliki WIP `AgamMapConfig`, kandidat style, test, dan audit aset. | WIP itu belum menjadi commit dan tidak berada di checkout root `dev` (`089883c`, satu commit di belakang `origin/dev` `d602fed`). Jangan menganggap perubahan itu sudah terintegrasi atau menimpanya saat sinkronisasi. |
| Lokasi/sesi/geofence | Layanan LA, `PoiRepository` dengan JSON bawaan/cache, engine geofence, dan sesi lokasi tersedia di source. Pada pemeriksaan WIP terakhir, `flutter analyze` bersih dan 230 test lulus. | Build APK terbaru, penggunaan pada perangkat fisik, dan alur trigger→kartu POI belum dibuktikan end-to-end. `MapConfig` yang dipakai integrasi masih fake; konfigurasi area TBD menolak semua trigger. |
| UI | Kerangka UI02, UI03, dan UI04 tersedia. UI03 menampilkan aksi trigger; UI04 menyediakan halaman detail POI. | UI02 belum merender PMTiles. Jalur event trigger ke tampilan detail perlu diuji dan dirapikan. |
| Batas area | Tile mencakup area berdasarkan snapshot OSM dan margin sekitar kampus. | Coverage tile bukan batas layanan. Geometri dan sumber batas layanan masih perlu ditetapkan tim; jangan memakai `FakeMapConfig` atau mengubah coverage tile menjadi batas layanan tanpa keputusan. |
| Login | PRD menetapkan login wajib. | Project Firebase/Auth belum tersedia dan alur login belum diimplementasikan. Perlu keputusan/demo setup sebelum APK dapat mengikuti gerbang login produk. |

## 3. Batas scope demo

- Gunakan koordinat dan radius POI yang sudah ada di PRD/dataset resmi. Untuk isi yang belum disetujui, gunakan teks seperti `PLACEHOLDER — menunggu tim konten` dan metadata `isPlaceholder: true`, `approved: false`.
- Gunakan JSON POI bawaan APK untuk demo. Firestore tidak diperlukan untuk membuktikan alur peta dan trigger; login wajib tetap mengikuti PRD kecuali PM memberi persetujuan eksplisit untuk pengecualian khusus build demo.
- Tile, style, glyph/sprite, dan provider peta harus lokal. Tidak boleh ada server tile publik atau request yang membawa posisi pengguna.
- Posisi hanya dipakai di perangkat selama pembacaan lokasi yang diizinkan; jangan menulis koordinat ke log, cache, Firestore, atau riwayat.
- Pencarian POI lokal menjadi jalur UI sementara, bukan acceptance PB10. Routing, pencarian fasilitas, rekomendasi, Orientation Trail, log aktivitas, dan rilis tidak menjadi syarat target demo ini.

### Alur FE internal sementara

1. UI01 memakai izin lokasi/notifikasi asli.
2. Shell demo menampilkan Jelajah dan Cari POI; Trail, fasilitas, rute, Pengaturan/profil tidak ditampilkan karena service/data nyata belum tersedia atau masih TBD.
3. Jelajah memakai PMTiles, `LocationService`, `SessionController`, geofence, notifikasi dan `PoiRepository` yang sudah terhubung. Marker/trigger membuka UI04 dengan POI dari repository yang sama.
4. UI05 memakai `PoiSearchService` atas `PoiRepository` bundled-only, mendukung alias Arab/Romawi, lalu membuka UI04 dan `AudioService` untuk POI yang dipilih.
5. UI04 tetap menentukan tampilan konten dari metadata repository. Status approved P01 masih memiliki konflik tercatat pada §6; jangan menyebut konten final sampai sumber kebenaran diselaraskan.

Perubahan shell hanya aktif saat `AGAM_INTERNAL_DEMO=true`; mode lain mempertahankan alur sebelumnya. Search POI ini bukan penyelesaian PB10.

## 4. Tahapan implementasi

### Tahap 0 — Putuskan prasyarat demo

- [x] POI pertama ditetapkan pengguna pada 14 November 2026: **P01 Labtek V / labtek 5**; kamera demo memakai koordinat PRD, radius tetap 15 m. Marker lain tetap dari repository yang sama.
- [x] Area sementara **demo internal** disesuaikan dalam mandat pengguna “sesuaikan kebutuhan lainnya”: empat sudut coverage engineering OSM + 200 m dari PRD §9.3, sumber snapshot 4 November 2026, dipakai lewat `AgamMapConfig.internalDemo()` dan berlabel pada UI. Ini bukan persetujuan geometri layanan produk atau hasil survei; batas produk tetap TBD dan `pendingServiceArea()` tetap menolak semua titik.
- [x] Pengguna mengizinkan **skip login sementara** pada 14 November 2026. Pengecualian hanya melalui flag `AGAM_INTERNAL_DEMO=true`, UI berlabel internal; default false menampilkan gerbang login belum tersedia. Tidak membuat akun tamu atau log aktivitas.
- Tidak berlaku untuk demo tanpa login/akun uji ini. Teks pemberitahuan privasi UI10 tetap diperlukan untuk PB21 produk.
- [ ] Perangkat telah ditetapkan: OPPO CPH2739 / Android 16 (15 November 2026), pengujian Android dilakukan di luar kampus. Lokasi/sesi field test P01 Labtek V dan uji berjalan belum tersedia.

**Hasil tahap:** keputusan dan prasyarat tercatat di checklist ini; belum ada klaim APK siap.

### Tahap 1 — Render peta vektor offline (PB04, LB + FE)

- [x] Renderer terpasang: `flutter_map 7.0.2` + `vector_tile_renderer 5.2.0`, pembaca `pmtiles 1.3.0`, `latlong2 0.9.1`. Hasil probe awal direvisi setelah audit privasi: `vector_map_tiles`/provider eksternalnya tidak dipasang karena layer bawaan menyimpan cache disk. `OfflineMapTiles` merender seluruh arsip kecil ke memori dan `TileProvider` lokal mengembalikan `MemoryImage`.
- [x] Pipeline menjalankan clustering deterministik dan validasi sebelum/sesudah transformasi. Metadata dan 13 payload tetap identik; manifest/hash output diperbarui bersama aset. Tidak hanya mengganti flag header.
- [x] Style lokal dibaca sebagai source `openmaptiles`; tile vektor dibundel dan dirender lokal, tanpa glyph/sprite/network provider.
- [x] PMTiles, style, dan manifest didaftarkan langsung di pubspec integrasi; patch WIP lama tidak diterapkan paksa.
- [x] Atribusi OSM/ODbL dan OpenMapTiles bertautan tampil dan terbaca pada render widget; evidence Android tetap belum ada.
- [x] Marker POI dari repository bawaan, pan dan overzoom 19 lulus widget; renderer lokal lulus dengan HTTP ditolak. Runtime pan/zoom offline pada Android belum diuji.
- [x] Audit aset APK lulus pada 15 November 2026: PMTiles, style dan manifest di ZIP identik dengan source; bukan bukti render/perangkat.

**Hasil tahap:** basemap nyata dan marker POI tampil dari aset APK, bukan ilustrasi atau layanan tile jaringan.

### Tahap 2 — Posisi perangkat di peta (PB02, FE + LA)

- [x] Stream `LocationService` asli tersambung ke marker posisi; uji widget memakai `DeviceLocationService` dengan source GPS simulasi, bukan sensor fisik.
- [x] Onboarding dan Mulai Explore meminta izin akurat saat aplikasi digunakan; GPS/izin bermasalah ditampilkan dan marker lama dihapus. Kasus GPS mati diuji widget; dialog Android belum diuji perangkat.
- [ ] Posisi bergerak pada emulator sudah PASS (SIMULASI); GPS fisik terbaca ±4–14 m dan marker terlihat setelah Pusatkan. Pengguna belum bisa berjalan; gerak GPS fisik di atas tile lokal tetap BELUM DIUJI.
- [x] UI berlangganan peta saat aktif/tampil dan membatalkannya saat disembunyikan; layanan LA mengatur lifecycle aplikasi/sesi. Akhiri berpindah ke pembacaan peta tanpa service sesi; setelah widget ditutup tidak ada langganan, teruji. Bukti background Android tetap tertunda.
- [ ] Izin akurat/perkiraan/ditolak + pemulihan Settings, GPS mati/aktif dan lifecycle diuji pada APK terbaru di emulator dan HP OPPO Android 16; gerak marker fisik belum diuji. Rincian/batas evidence pada matriks terbaru §6.

**Hasil tahap:** marker posisi nyata bergerak di atas tile lokal. Tahap ini belum membuktikan trigger.

### Tahap 3 — Trigger lokal membuka POI yang benar (PB05–PB07, LA + FE)

- [x] Fake area diganti konfigurasi engineering bersumber **khusus flag demo**, sesuai keputusan penyesuaian Tahap 0 dan PRD §9.3. Produk tetap memakai area pending sampai geometri final ditetapkan.
- [x] Controller/engine LA asli dan marker/detail memakai `PoiRepository` yang sama; jalur ini diuji widget memakai dataset bawaan.
- [x] Aturan PRD tetap 15 m / 20 m / 5 detik / 10 menit; engine tidak dilonggarkan. Widget menolak akurasi 30 m dan belum memicu pada dwell <5 detik; boundary/cooldown tetap dicakup suite engine existing.
- [x] Trigger P01 menampilkan UI03 dan “Lihat” membuka UI04 P01. `TriggerResponder.viewRequests` disambungkan melalui widget dari main tanpa perubahan kontrak; permintaan P02 membuka P02 pada uji widget. Tombol notifikasi native, background/cold start belum diuji.
- [ ] Pada build terbaru, status konten P01 belum dapat diterima: dataset menandai P01 approved/non-placeholder dan UI04 menampilkan media, sedangkan PRD §22 menyatakan konten P01–P10 belum tersedia. Bukti placeholder dari source sebelumnya bersifat historis; selaraskan sumber kebenaran dengan PM/tim konten.
- [x] Akhiri mengakhiri sesi/service; selama peta tampil pembacaan foreground tetap boleh berjalan. Setelah layar dilepas tidak ada langganan lokasi; teruji widget. Penghentian service native tetap perlu perangkat.
- [ ] Buktikan trigger P01 → kartu Labtek V pada APK dengan GPS fisik di lokasi, akurasi ≤20 m, radius 15 m, dwell ≥5 detik, dan cooldown 10 menit; periksa akhir sesi/service native, izin/lifecycle, notifikasi/layar mati, jaringan dan penyimpanan. Belum dijalankan pada 15 November 2026.

**Hasil tahap:** posisi nyata di area uji memicu kartu POI yang cocok tanpa menghitung rute atau mengirim koordinat.

### Tahap 4 — APK debug dan uji demo (integrasi FE/LA/LB)

- [ ] Sinkronkan pekerjaan melalui branch track tetap (`LB`, `LA`, `FE`) dan integrasi ke `dev` sesuai aturan review. `LB` lokal kini fast-forward ke HEAD `dev` `046b646`, tetapi belum ada PR/review integrasi dari track; perubahan kontrak memerlukan persetujuan track lain.
- [ ] Pemeriksaan terbaru 16 November: format 78 file dan `flutter analyze --no-pub` lulus; suite Flutter **251 lulus, 1 gagal** pada assertion placeholder P01 di `test/ui/demo_explore_test.dart:187`. Hasil 233/246 lulus 15 November adalah evidence source sebelumnya.
- [x] Build demo terbaru dari `LB` HEAD `046b646` dengan `flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` berhasil 16 November 2026; audit `--apk` lulus. APK: 185.500.958 byte, SHA-256 `162edfa6c98d805e30ae0d356846c68829c4f8b800ef75a174817441026c1329`.
- [x] Lokasi APK, ukuran/hash, versi, HEAD, hasil command dan konfigurasi lokal dicatat. Build ini berasal dari HEAD `046b646`; perubahan dokumentasi lokal tidak mengubah source APK.
- [ ] APK terbaru 16 November belum dipasang pada OPPO CPH2739. APK dari source sebelum sinkronisasi pernah dipasang/dikonfirmasi 15 November; bukti lama tidak mencakup hash build terbaru.
- [ ] Cold start offline pada HP belum diulang untuk APK terbaru. Build terbaru diuji di AVD API 36 dengan Wi-Fi/data mati: basemap, atribusi, POI, posisi simulasi, Explore, dan trigger→UI03/UI04 tampil. Ini bukti emulator, bukan HP.
- [ ] Lakukan uji berjalan di lokasi POI fisik: akurasi, dwell, trigger, POI yang tampil, akhir sesi, dan tidak ada pengiriman/penyimpanan koordinat.
- [x] Evidence versi/hash APK, perangkat, command/skenario/hasil dan keterbatasan disimpan di §6; simulasi emulator, hasil HP di luar kampus dan field acceptance dipisahkan.
- [x] Source shell demo memakai ulang UI FE Jelajah/Cari POI dan layanan/repository nyata; routing, trail, fasilitas dan profil tidak diekspos.
- [x] `dart format`, `flutter analyze --no-pub`, build APK internal, dan audit aset APK lulus untuk perubahan shell/SearchService pada branch `LB`.
- [ ] Test Flutter tidak dijalankan setelah perubahan ini; runtime UI Cari POI pada emulator/HP belum dijalankan. APK baru belum di-install.

## 5. Kriteria target demo tercapai

Target sementara ini dianggap tercapai hanya bila semua butir berikut terbukti:

- [x] APK debug dari `LB` HEAD `046b646` + perubahan shell FE berhasil dibangun 16 November 2026 dengan flag demo internal: 185.500.958 byte, SHA-256 `9bf687a32fa492c4cae0e638eadd26e5211087fcdd39baf3903a97d0c37014d6`.
- [ ] APK terbaru berhasil dipasang dan dibuka pada OPPO CPH2739 / Android 16; APK build 16 November belum dipasang di perangkat fisik.
- [ ] Basemap PMTiles, atribusi, penanda POI, dan posisi perangkat tampil; peta tidak bergantung pada server tile.
- [ ] Sesi Explore dapat dimulai; posisi valid di radius POI selama dwell yang ditetapkan memicu UI03/UI04 untuk POI yang benar.
- [ ] Status konten P01 belum dapat diterima: `pois.json` menandai P01 approved/non-placeholder, tetapi PRD §22 menyatakan konten P01–P10 belum tersedia. Jangan mengklaim placeholder atau konten final sebelum PM/tim konten menyelaraskan sumber kebenaran.
- [ ] Pemeriksaan tidak menemukan koordinat pengguna dikirim atau disimpan sebagai riwayat.
- [ ] Cari alias POI dari UI05 memakai repository nyata, lalu membuka UI04/audio tanpa rute sintetis; belum dijalankan setelah perubahan ini.
- [x] Evidence build dan uji terbaru dicatat: HEAD `046b646`, hash/ukuran/versi, emulator/skenario/hasil dan batas verifikasi. APK ini bukan hasil field test atau commit track yang dipublikasikan.

Kriteria ini khusus demo vertikal. Capaian ini tidak mengubah status PBI/acceptance PRD secara otomatis.

## 6. Progress log

Perbarui tabel ini setiap tahap selesai. Catat tanggal, commit, file penting, command, hasil, serta keterbatasan. Jangan menyalin rencana ini ke dokumen kedua.

| Tahap | Status | Evidence/catatan |
| --- | --- | --- |
| Tahap 0 — prasyarat | Keputusan demo tersedia; field test tertunda | AVD API 36 tersedia. OPPO CPH2739 terhubung pada sesi 15 November, tetapi tidak terdeteksi saat pemeriksaan 16 November; pengguna belum berada di lokasi uji Labtek V. |
| Tahap 1 — peta offline | PASS pada APK terbaru di emulator; perangkat fisik terbaru belum diuji | HEAD `046b646`: PMTiles, atribusi, POI, dan posisi simulasi tampil di AVD dengan Wi-Fi/data mati. Bukti HP 15 November berasal dari APK/source sebelumnya. Batas layanan produk tetap TBD. |
| Tahap 2 — posisi | Simulasi terbaru lulus; gerak GPS fisik di atas tile belum | Mock location emulator ke P01 menggerakkan posisi dan menghasilkan trigger. GPS HP ±4–14 m serta lifecycle adalah evidence 15 November; bukan uji build terbaru. |
| Tahap 3 — trigger→POI | SIMULASI build terbaru lulus; trigger lapangan belum | AVD offline: Explore → mock P01 → UI03 → Lihat → UI04. Tidak ada GPS fisik atau acceptance lapangan pada sesi ini. |
| Tahap 4 — APK/uji | APK shell FE baru dibangun dan diaudit; runtime Cari POI, install HP dan field test belum | 185.500.958 byte, SHA-256 `9bf687a3…014d6`; analyze/build/audit lulus. Test Flutter tidak dijalankan setelah update; hasil lama 251/1 gagal mengacu source sebelum shell FE baru. APK belum diuji runtime setelah perubahan ini. |

### Verifikasi ulang branch `LB` setelah sinkronisasi — 16 November 2026

**Source:** branch lokal `LB`, HEAD `046b646`, sama dengan HEAD lokal/remote `dev` saat pemeriksaan. Tidak ada perubahan source atau dependency oleh sesi ini. Perubahan lokal yang sudah ada pada `.agent/PRD.md`, `.agent/sessionHandoff.md`, `tools/tiles/PB04-integration.md`, dan `tools/tiles/pubspec-map-assets.patch` dipertahankan.

| Pemeriksaan | Hasil aktual |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Lulus; dependency mengikuti lockfile. |
| `dart format --output=none --set-exit-if-changed lib test` | 78 file, 0 perubahan. |
| `flutter analyze --no-pub` | Lulus, tanpa issue. |
| `flutter test --reporter compact` | **251 lulus, 1 gagal.** Assertion gagal di `test/ui/demo_explore_test.dart:187` karena mencari teks `PLACEHOLDER`; data P01 pada checkout ini memiliki `isPlaceholder: false` dan `approved: true`. PRD §22 masih menyatakan konten P01–P10 belum tersedia. Tidak mengubah test atau data karena konflik sumber kebenaran dan ownership FE/LA perlu diselesaikan dahulu. |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -q` | **21 lulus.** |
| `python -X utf8 tools/tiles/audit_assets.py` | Lulus; PMTiles 13 tile, 1.022.885 byte, hash `6af43dfb…34792`. Audit source saja. |
| Build demo internal | `flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` **lulus** (`assembleDebug` 348,5 detik). APK `build/app/outputs/flutter-apk/app-debug.apk`, 185.500.958 byte, SHA-256 `162edfa6c98d805e30ae0d356846c68829c4f8b800ef75a174817441026c1329`. |
| Audit APK | `audit_assets.py --apk` **lulus**; PMTiles, style, dan manifest dalam APK identik dengan source. Audit tidak membuktikan jaringan atau storage runtime. |
| AVD `agam_demo_api36` | APK terbaru terpasang dan dibuka pada emulator API 36 saat Wi-Fi/data mati. Basemap, atribusi OSM/OpenMapTiles, marker, posisi simulasi dan tombol Explore terlihat. Mock lokasi memakai koordinat P01 dari dataset; trigger UI03 dan aksi Lihat ke UI04 Labtek V berhasil. Ini simulasi, bukan GPS fisik. Emulator dihentikan setelah uji. |
| Perangkat fisik | `adb devices -l` sebelum boot AVD tidak menemukan perangkat; build terbaru belum dipasang pada OPPO dan trigger fisik/field test tidak dijalankan. |

**Status target:** belum selesai. Masih perlu perangkat di Kampus Ganesha untuk uji bergerak dan trigger P01 dengan GPS fisik, pemeriksaan privasi jaringan/storage pada perangkat, install/uji APK terbaru pada OPPO, serta penyelesaian konflik status konten dan assertion test. Dokumen ini dipertahankan sampai seluruh kriteria §5 terbukti; jangan hapus pointer handoff.

### Verifikasi Android lanjutan 15 November 2026 — APK diperbaiki, emulator dan HP

**Baseline diperiksa ulang:** `dev`, HEAD dasar
`089883c8d7d589eeb3fbabdc51b79808d86deccd` + WIP tracked/untracked dipertahankan.
APK existing `build/app/outputs/flutter-apk/app-debug.apk`, versi `1.0.0+1`,
171.972.503 byte, SHA-256
`e54997a3bd133d933fbbfb968e2a8e7e4696e1107f1563552391099bc305ffce` cocok.
137 file pada snapshot `D:\CodexRuntime\agam-android\source-before-build.json`
cocok byte per byte. Audit aset `--apk`, metadata/manifest dan signature v2
diulang: lulus. Ini memakai hasil build sebelumnya; bukan build baru.

**Persiapan runtime:** SDK Manager memasang emulator 37.2.13 dan Google APIs
x86_64 Android 16/API 36 revision 7 di SDK existing luar repo. `-accel-check`
menemukan WHPX usable. AVD baru `agam_demo_api36` disimpan di
`D:\CodexRuntime\agam-android\avd\agam_demo_api36.avd`; dibuat tanpa menghapus
AVD/data lain, memakai 2 GB RAM, 2 core dan renderer software headless.
Tidak mengubah BIOS atau konfigurasi Gradle existing. Perangkat emulator tetap
**simulasi**, bukan GPS fisik. Helper ADB lokal luar repo membatasi screenshot
ke serial emulator dan memverifikasi `ro.kernel.qemu=1`.

**Pendampingan fisik:** daftar ADB awal kosong. Pengguna telah diberi langkah
kabel data → Opsi pengembang → Debugging USB → setujui dialog RSA dan membalas
bahwa HP akan dihubungkan serta izin diberikan. Balasan ini bukan bukti HP
terhubung, install/launch, atau field test. Model/Android/lokasi uji belum
tersedia; jangan mencatat koordinat/lintasan/screenshot posisi pengguna.

Catatan baseline/persiapan di atas adalah keadaan **awal** sesi. Setelah itu HP
berhasil terhubung dan ditemukan defect runtime, sehingga source diperbaiki,
APK dibangun ulang dan pengujian berikut dijalankan. Data APK lama bukan APK final.

**APK terbaru yang diuji:** `build/app/outputs/flutter-apk/app-debug.apk`,
`site.agam` **1.0.0+1**, **199.109.003 byte**, SHA-256
`9373c5906d0f779bfa324c2048969e95f8deac0f7aa6f1437a690a5503f92873`.
`sha256sum` atas `base.apk` terpasang di emulator **dan HP** sama dengan hash
host ini. Source tetap `dev`, HEAD dasar `089883c8d7d589eeb3fbabdc51b79808d86deccd`
**+ WIP tracked/untracked**, bukan commit APK bersih. Tidak ada commit, push,
reset, clean, merge, rilis, perubahan dependency, `lib/contracts/`, titik P01,
radius/akurasi/dwell/cooldown, atau keputusan produk.

**Defect dan perubahan:**

- APK awal: menolak dialog opsional Google Location Accuracy menghasilkan
  pesan GPS mati meskipun lokasi Android aktif. `GeolocatorPositionSource`
  tetap memakai FLP terlebih dahulu, lalu fallback `LocationManager` melalui
  geolocator bila FLP menolak dan lokasi Android masih aktif. Tidak memaksa
  opt-in Google Accuracy. Pilihan fallback hanya di memori; parameter interval,
  filter jarak dan foreground service dipertahankan. `maxUpdateAge=0` mencegah
  FLP memberi fix awal historis. Ini bukan audit trafik layanan OS/GMS.
- GPS mati mengakhiri stream, tetapi request lama masih dianggap aktif dan GPS
  yang diaktifkan kembali belum memulihkan pembacaan. `DeviceLocationService`
  kini menghapus `lastFix` saat error, mengenali stream selesai, memantau status
  layanan lokasi, dan memulihkan pembacaan ketika GPS aktif/aplikasi tampil.
  Tidak memulai foreground service baru dari background; bila GPS terputus di
  background, pemulihan menunggu foreground/resume. Jangan mengklaim kasus
  GPS off→on di background telah lulus.
- Hilangnya GPS memutus kontinuitas dwell melalui `interruptDwell()` pada
  engine/controller sesi, tanpa dianggap keluar, tanpa menghapus cooldown atau
  pengunci kunjungan. Tidak memasukkan fix/koordinat sintetis ke runtime produk.
- Adapter memakai cancellation eksplisit `StreamIterator`, agar Akhiri/Home
  tidak menunggu fix berikutnya. Uji awal implementasi `async*` gagal pada
  cancellation tanpa fix; implementasi diperbaiki dan regression test dipertahankan.
- Perubahan source: `lib/logic/location/{position_source,device_location_service,
  geofence_engine}.dart`, `lib/logic/session/device_session_controller.dart`,
  `lib/logic/la_bootstrap.dart`; test adapter/lokasi/sesi serta helper sintetis.
  Tambahan 13 test; tidak mengubah UI/kontrak untuk melonggarkan pengujian.

| Verifikasi input terbaru | Hasil aktual |
| --- | --- |
| Format / analyzer | 75 file terformat; `flutter analyze`: tanpa issue. Dua info initializing-formal pada pemeriksaan awal sudah diperbaiki. |
| `flutter test --reporter expanded` | **246 lulus**; `D:\CodexRuntime\agam-android\demo-runtime-regression.log`. GPS/unit/widget tetap simulasi. |
| Pipeline | **21 lulus**; tidak ada perubahan pipeline/aset pada sesi ini. |
| Build demo | **Exit 0**, `assembleDebug` 18,4 detik pada build terakhir; flag `AGAM_INTERNAL_DEMO=true`, recipe SDK/JDK/Gradle user home existing. Peringatan KGP `flutter_tts` tetap ada. |
| Audit APK / signature / manifest | Audit `--apk` exit 0; tiga aset identik, signature v2 valid, versi 1.0.0+1, minSdk 24/target 36, tanpa `ACCESS_BACKGROUND_LOCATION`; izin INTERNET debug tetap ada. |
| Build antara | Setelah perbaikan fallback pertama: build 22,3 detik, audit lulus, APK 199.107.428 byte / `714410f203b012eb00841bbafdf1ab72ddf89aee4489d31d7a70fb6d127318e1`, diuji ulang lalu digantikan APK final setelah defect pemulihan GPS ditemukan. |

**Perangkat fisik:** OPPO **CPH2739** (nama perangkat Windows: Reno14 Pro 5G),
Android **16/API 36**. Install `adb install -r` berhasil tanpa uninstall/hapus
data; pengguna mengonfirmasi peta dan DEMO INTERNAL tampil. Pengguna berada
**di luar kampus**, belum dapat berjalan untuk uji marker, dan belum dapat
field test Labtek V. Tidak ada mock location pada HP, screenshot HP, koordinat
atau lintasan pengguna yang disimpan/dilaporkan. UI hanya dibaca sebagai
boolean/status/akurasi; dump lokasi Android diproses di memori untuk menghitung
registrasi terkait aplikasi lalu dibuang, bukan disimpan sebagai log mentah.

**Matriks Tahap 2/3 — status fisik dibedakan dari simulasi:**

| Skenario | Emulator Android 16 (**SIMULASI**) | HP OPPO Android 16 / batas evidence |
| --- | --- | --- |
| Install/launch APK terbaru | PASS; cold start, onboarding/peta tanpa crash teramati | PASS; hash APK terpasang cocok, launch + konfirmasi pengguna |
| Basemap/atribusi/P01/pan/zoom offline | PASS; cold start mode pesawat, Wi-Fi/data 0, GPS true; screenshot simulasi diperiksa | PASS; cold start dengan airplane=1/Wi-Fi=0/data=0/GPS=true; pengguna: semua tampil dan bisa diinteraksi |
| Posisi valid di peta | PASS; ±5 m, marker terlihat | PASS terbatas; pembacaan fisik ±4–14 m dan marker terlihat setelah Pusatkan. Di luar coverage tile kampus; bukan bukti posisi bergerak di atas tile lokal |
| Marker bergerak mengikuti perangkat | PASS; dua injeksi, perubahan marker diperiksa visual | **BELUM DIUJI**; pengguna belum bisa berjalan. Tidak digantikan mock di HP |
| Izin akurat | PASS | PASS; fine/coarse granted, GPS nyata terbaca |
| Penolakan izin / Pengaturan | PASS; dua penolakan, pesan + Buka Pengaturan, pemulihan native Settings | PASS; pencabutan melalui Settings saat Explore, alur kembali meminta izin/menolak, Buka Pengaturan dan pemulihan akurat. ADB `pm revoke` ditolak keamanan OEM; tidak diakali/root |
| Izin perkiraan | PASS; coarse-only, tetap perkiraan → Lokasi akurat diperlukan; Settings → precise pulih | PASS; fine=false/coarse=true diverifikasi, pilihan tetap perkiraan ditekan pada dialog native, `approximateRejected=true` pada pesan aplikasi; fine dipulihkan melalui Settings |
| GPS mati → aktif | PASS; marker dihapus, fix baru pulih | PASS; GPS false/marker tidak ada/request 0, lalu true/fix ±11 m/request peta kembali; tanpa service sesi |
| Peta biasa Home/resume | PASS | PASS; Home terverifikasi background: registrasi terkait aplikasi 0, service 0; kembali foreground membaca lagi |
| Explore/foreground service/notifikasi tetap | PASS; tipe location `0x8` | PASS; service 1, notifikasi sesi ada, registrasi lokasi terkait aplikasi ada. Di luar area tidak ada trigger |
| Di luar radius / sebelum dwell | PASS; tidak ada trigger di luar; pada 4,05 detik setelah injeksi P01 belum ada UI03 | **BELUM DIUJI di Labtek V**; batas area mencegah trigger pada lokasi fisik pengujian sekarang |
| Dwell P01 → UI03 → UI04 P01 | PASS; ±5 m, dwell tidak dilonggarkan; Labtek V dan alias/konten placeholder cocok | **BELUM DIUJI** dengan GPS fisik di radius P01 |
| Tombol Lihat native | PASS; dari background, notifikasi P01 membuka UI04 Labtek V; P02 juga cocok | **BELUM DIUJI** dengan trigger fisik P01 |
| Tetap di area / keluar-masuk dalam cooldown | PASS; tidak ada UI03 ulang; timestamp notifikasi P01 tidak berubah setelah reentry selama cooldown, tanpa mengubah jam | **BELUM DIUJI** fisik |
| Layar mati / resume | PASS; service tetap berjalan; uji tambahan P02 terpicu saat Dozing dan native Lihat membuka P02 | PASS terbatas; tombol fisik mematikan layar, dua snapshot Dozing tetap punya request/service/notifikasi sesi. Belum trigger P01 saat layar mati; perintah sleep ADB awal tidak mematikan layar dan tidak dihitung PASS |
| Akhiri saat peta tampil | PASS; foreground service sesi hilang, pembacaan peta tetap boleh | PASS; sesi idle/service 0, pembacaan peta masih 1, pesan luar kampus tetap benar |
| Akhiri → Home | PASS; request 0/service 0 | PASS; Android Home terverifikasi, request 0/service 0/notifikasi sesi tidak ada. Snapshot ketika AGAM masih foreground tidak dihitung sebagai bukti background |
| Cabut izin saat Explore | Unit/controller lulus; izin native juga diuji | PASS; sebelum: request 1/service 1/notifikasi ada; sesudah pencabutan lewat Settings: semuanya 0, izin fine/coarse false; OS boleh mematikan proses |
| Placeholder | PASS; UI03/UI04 dan native P01/P02 berlabel placeholder, media tidak dibuat | PASS; ketuk marker P01 → Lihat → UI04: Labtek V dan PLACEHOLDER terdeteksi di HP. Ini pembukaan manual, bukan trigger GPS fisik |

**Privasi runtime dan batasnya:** pada emulator rooted milik pengujian, rule
counter IPv4/IPv6 OUTPUT berdasarkan UID aplikasi 10216 dipasang sebelum launch.
Sepanjang pengujian **online** peta/lokasi/Explore/trigger/notifikasi/background,
keduanya tetap **0 paket / 0 byte**, sebelum uji mode pesawat. Ini bukan sekadar
uji offline. Tidak memasang/attach Flutter DevTools, `flutter run`, port forwarding
VM service atau proxy; ADB/shell merupakan proses/UID berbeda. Counter tidak
memblokir trafik. Hasil ini terbatas pada UID aplikasi dan skenario yang diuji,
bukan trafik layanan OS/GMS/delegasi di UID lain atau seluruh jalur masa depan.

Pada HP tanpa root, `dumpsys netstats --uid` dapat dibaca, tetapi tidak memberi
counter trafik lengkap yang dapat dipakai sebagai packet capture aplikasi.
Kemunculan UID pada mapping set foreground bukan bukti adanya/tiadanya paket.
**Audit jaringan fisik lengkap belum terbukti**; jangan menyatakan lulus A01
hanya dari manifest, source, mode pesawat, atau ketiadaan baris netstats.

Penyimpanan internal aplikasi diperiksa sebelum/sesudah pemakaian; file callback,
preferensi notifikasi/audio dan database image cache diperiksa di memori,
hasil yang disimpan hanya nama/ukuran/hash/schema/jumlah row/flag deteksi.
Pada snapshot HP yang telah diperiksa, database `cacheObject` kosong (0 row),
file data tersebut tidak berubah dan tidak ditemukan field/riwayat posisi.
Compiled Flutter assets dan shader `code_cache` dipisahkan sebagai kode/cache
driver; ini bukan pemeriksaan forensik seluruh OS atau aplikasi lain. Koordinat
POI statis pada JSON/compiled assets bukan koordinat pengguna. Snapshot akhir
setelah semua uji masih perlu dicocokkan sebelum menutup sesi.

Artefak engineering berada di `D:\CodexRuntime\agam-android\`: log build/test,
audit APK, snapshot hash source 138 file, `simulation-*.png` (**hanya emulator**),
`simulation-storage-*.json`, dan laporan `physical-state-*.json` /
`physical-privacy-*.json` tanpa koordinat/screenshot/lintasan pengguna. Ini bukan
dokumen rencana tambahan. Uji native Settings kadang perlu reobservasi ketika
UI belum idle/HP terkunci; kegagalan helper tidak dianggap defect aplikasi.

**Matriks §5 / gerbang penutupan:**

| Butir | Status | Evidence / batas |
| --- | --- | --- |
| 1. APK integrasi terbaru dibangun | PASS | Build demo 18,4 detik; hash final di atas; aset/signature/manifest diaudit |
| 2. Install/launch fisik | PASS | OPPO Android 16, `install -r`, hash terpasang cocok dan konfirmasi pengguna |
| 3. Basemap/atribusi/POI/posisi pada peta lokal | BELUM DIUJI (lengkap) | Basemap offline/pan/zoom/P01 lulus di HP; marker GPS fisik terlihat di luar coverage. Posisi bergerak di atas tile lokal belum dibuktikan |
| 4. Explore + dwell GPS nyata → UI03/UI04 P01 | BELUM DIUJI | Emulator lulus; pengguna belum berada di Labtek V, tidak memakai mock pada HP |
| 5. Placeholder jelas | PASS | UI03/UI04 emulator dan UI04 P01 dari marker pada HP |
| 6. Tidak ada pengiriman/riwayat posisi | BELUM DIUJI (cakupan lengkap) | Audit source, UID online emulator dan penyimpanan terbatas tidak menemukan pelanggaran; audit jaringan fisik lengkap belum tersedia |
| 7. Evidence/source APK dicatat | PASS | Versi/ukuran/hash/HEAD dasar + WIP, perangkat/skenario/hasil dan keterbatasan tercatat |

Tahap 2/3, target demo dan PBI tetap `in_progress`; rencana/pointer
**dipertahankan**. Tidak ada acceptance seluruh POI/PRD yang dinaikkan menjadi
done. Penggunaan AI material untuk perbaikan, pengujian dan audit ini perlu
dicakup PB20. Pengaturan jaringan awal HP (airplane=0, Wi-Fi=1, data=1), GPS
aktif dan izin akurat telah dipulihkan; tidak mengubah keystore atau data akun.

### Evidence build berhasil 15 November 2026 — APK internal dan audit ZIP

**Instruksi lanjutan pengguna:** selesaikan sampai APK dan audit APK menghasilkan
hasil dalam progres ini, termasuk penyiapan toolchain. Seluruh WIP dipertahankan;
tidak ada commit, push, merge, reset, clean atau rilis. Snapshot SHA-256 sebelum
dan sesudah build memastikan seluruh **137 file source di luar `.agent/` identik
byte per byte**, termasuk source, dependency/lockfile, konfigurasi tracked dan aset.

**Toolchain lokal (di luar repo):** Android SDK
`D:\CodexRuntime\agam-android\sdk`; command-line tools 22.0, platform-tools,
Platform 36, build-tools 36.0.0, NDK 28.2.13676358 dan CMake 3.22.1 dipasang lewat
SDK Manager. Platform 35 revision 2 dipasang otomatis oleh Gradle untuk dependency.
JDK existing `C:\Program Files\Java\jdk-21.0.12` dan Gradle 9.3.1 digunakan;
target bytecode source proyek tetap Java 17. `flutter doctor -v` kini meluluskan
Android toolchain dan lisensi. FVM belum di PATH; build memakai executable Flutter
3.47.9 absolut yang telah diverifikasi pada evidence sebelumnya.

Unduhan command-line tools bersumber
[Android Developers](https://developer.android.com/studio/), SHA-256
`90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a`
sesuai checksum resmi. Distribusi Gradle dari URL wrapper existing diverifikasi
dengan checksum resminya:
`17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43`.
Wrapper yang sebelumnya belum ada disalin dari cache Flutter ke file yang
diabaikan Git, tanpa menimpa file existing; `android/local.properties` yang
diabaikan Git kini memuat `sdk.dir`. PATH/konfigurasi Flutter global tidak diubah.

**Kegagalan dan pemulihan:** percobaan setelah SDK tersedia gagal pada
`:audio_session:compileDebugKotlin` dan `:flutter_tts:compileDebugKotlin`, karena
cache incremental Kotlin mencoba menghitung path relatif antara pub cache C:
dan proyek D: (`this and base files have different roots`). Solusi lokal:
`D:\CodexRuntime\agam-android\gradle\gradle.properties` berisi
`kotlin.incremental=false`. Tidak mengubah `android/gradle.properties` proyek,
package, threshold, atau source. Build ulang **exit 0**, `assembleDebug` 284,4 detik.
Peringatan KGP `flutter_tts` tentang kompatibilitas Flutter masa depan masih ada;
bukan kegagalan build saat ini. Log setup/build berada di luar repo pada direktori
toolchain tersebut (`demo-build.log`, `demo-build-retry.log`).

Cara mengulang build dari root dengan konfigurasi lokal yang sama:

```powershell
$env:ANDROID_HOME = 'D:\CodexRuntime\agam-android\sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.12'
$env:GRADLE_USER_HOME = 'D:\CodexRuntime\agam-android\gradle'
& 'C:\Users\ASUS\.cache\tooling\flutter-3.47.9\bin\flutter.bat' build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true
python -X utf8 tools/tiles/audit_assets.py --apk build/app/outputs/flutter-apk/app-debug.apk
```

| Pemeriksaan aktual | Hasil dan batas evidence |
| --- | --- |
| APK hasil build demo | `D:\Kuliah\Semester 7\Transformasi Digital\Tubes AGAM\AGAM\build\app\outputs\flutter-apk\app-debug.apk`, **171.972.503 byte (164,01 MiB)**. |
| SHA-256 APK | `e54997a3bd133d933fbbfb968e2a8e7e4696e1107f1563552391099bc305ffce` |
| Identitas source | Branch `dev`, HEAD dasar `089883c8d7d589eeb3fbabdc51b79808d86deccd` **+ WIP tracked/untracked**; bukan APK dari commit bersih tersebut. Source integrasi tidak diubah selama build. |
| Metadata APK (`aapt dump badging`) | `site.agam`, versionName `1.0.0`, versionCode `1`; minSdk 24, target/compileSdk 36, activity `site.agam.MainActivity`; ABI arm64-v8a / armeabi-v7a / x86_64. |
| Audit `--apk` | **Exit 0**; `ganesha.pmtiles`, `agam-style.json`, `ganesha.manifest.json` dalam `assets/flutter_assets/assets/map/` identik dengan source. PMTiles 13 tile, 1.022.885 byte, hash tetap `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`. Hash PMTiles berbeda dari hash APK. |
| `apksigner verify --verbose` | **Exit 0**, satu signer, signature scheme v2 valid (debug APK). |
| `aapt dump permissions` | Tidak ada `ACCESS_BACKGROUND_LOCATION`; lokasi fine/coarse, foreground service location/mediaPlayback, notifikasi/getar/wake lock tersedia. `INTERNET` debug Flutter dan `ACCESS_NETWORK_STATE` tetap ada; ini bukan audit lalu lintas runtime. |
| Regression/source | 137 file source di luar `.agent/` tetap identik; 233 test Flutter/21 pipeline/format/analyze dari pemeriksaan sesi sebelumnya tetap evidence untuk source yang sama. Tidak diulang tanpa perubahan source. `git diff --check` dan target tautan lokal diperiksa setelah dokumentasi. |
| Emulator/perangkat | `flutter emulators`: tidak ada sumber emulator; `adb devices -l`: daftar kosong setelah adb tersedia. Tidak ada install/launch APK, simulasi emulator atau GPS fisik baru. |

**Status:** target build + audit APK permintaan lanjutan tercapai. Target demo
vertikal keseluruhan, Tahap 2/3 GPS fisik, dialog/lifecycle Android, notifikasi/
layar mati, offline perangkat dan audit privasi runtime tetap tertunda. PBI
tetap `in_progress`; dokumen rencana tidak dihapus. Berikutnya install APK ini
di perangkat Android lalu lakukan field test P01 Labtek V sesuai threshold PRD.

### Evidence lanjutan 15 November 2026 — verifikasi mesin dan build ulang

**Source:** branch `dev`, HEAD dasar `089883c8d7d589eeb3fbabdc51b79808d86deccd`,
versi pubspec `1.0.0+1`, dengan perubahan lokal tracked/untracked yang belum
di-commit. HEAD ini **bukan commit APK**. Sesi ini hanya memperbarui tiga dokumen
status/rencana; source, aset, kontrak, flag login dan threshold tidak diubah.
Tidak melakukan reset, clean, commit, push, merge atau rilis.

**Lingkungan aktual:** `fvm` tidak tersedia di PATH. Perintah Flutter di bawah
memakai `C:\Users\ASUS\.cache\tooling\flutter-3.47.9\bin\flutter.bat`
secara langsung; `--version` membuktikan Flutter 3.47.9 / Dart 3.13.7,
framework `c197ca5199`. Tidak mengubah PATH atau konfigurasi global.

| Pemeriksaan aktual | Hasil dan batas evidence |
| --- | --- |
| `flutter doctor -v`, `flutter config --list`, environment dan `android/local.properties` | `Unable to locate Android SDK`; `ANDROID_HOME`/`ANDROID_SDK_ROOT` tidak disetel, tidak ada konfigurasi `android-sdk` Flutter atau `sdk.dir` lokal. Lokasi standar SDK/Android Studio tidak ditemukan. Pencarian tooling pada `D:\App`, `D:\Program Files`, `D:\CodexRuntime` dan direktori Google/Android terkait tidak menemukan adb/emulator/sdkmanager. Tidak menyatakan seluruh disk sudah dipindai. |
| `flutter devices`, `flutter emulators`, proses dan PnP Windows | Hanya Windows, Chrome, Edge; `Unable to find any emulator sources`. Tidak ditemukan proses adb/emulator/qemu, executable adb/emulator di PATH, atau entri PnP Android/ADB/MTP/USB Android yang cocok. Nama ponsel pada profil Bluetooth bukan koneksi debugging. `adb devices -l` tidak dapat dijalankan karena adb belum tersedia; perangkat fisik yang siap diuji belum terdeteksi. |
| `flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` | Exit 1: `No Android SDK found. Try setting the ANDROID_HOME environment variable.` Gagal sebelum Gradle; SDK tidak dipasang pada sesi ini. |
| APK / audit APK | Target `build/app/outputs/flutter-apk/app-debug.apk` tidak ada. Ukuran dan SHA-256 APK **tidak tersedia**; audit `--apk` tidak dijalankan karena input tidak ada. Hash PMTiles di bawah bukan hash APK. |
| `flutter pub get --enforce-lockfile` | Lulus memulihkan package cache. Percobaan test terarah sebelumnya gagal kompilasi karena cache flutter_map/latlong2/pmtiles/vector_tile_renderer/url_launcher hilang; tidak diselesaikan dengan perubahan source/versi. |
| `dart format --output=none --set-exit-if-changed lib test` | 74 file, 0 perubahan. |
| `flutter analyze` | No issues found. |
| Verifikasi dokumentasi | Diff akhir ditinjau, `git diff --check` lulus; rencana dan pointer handoff dipertahankan. |
| `flutter test --reporter expanded` | **233 lulus** setelah cache pulih; log lokal di `tools/tiles/.cache/demo-flutter-tests-2026-11-15.log`. Peta/marker/pan/overzoom, GPS mati, akurasi/dwell/P01→kartu, view P02, akhir sesi dan lifecycle tetap **simulasi widget**, bukan emulator atau GPS fisik. |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -q` | **21 lulus**. |
| `python -X utf8 tools/tiles/audit_assets.py` | Lulus atas aset sumber: 13 tile, 1.022.885 byte, SHA-256 PMTiles `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`; `apkChecked: null`, `bundledEntries: []`. |
| Inspeksi source privasi/login | Default `bool.fromEnvironment('AGAM_INTERNAL_DEMO')` menahan akses sebelum inisialisasi layanan; flag eksplisit tetap diperlukan. Jalur posisi/sesi tidak ditemukan menulis riwayat atau mengirim posisi. Peta memakai bundle/memori, tautan atribusi statis; `FileDatasetCache` menyimpan dataset konten POI, bukan posisi pengguna, dan remote default `UnavailableRemoteSource`. Ini inspeksi source terbatas; manifest test bukan audit merged APK, dan belum ada pemeriksaan lalu lintas/penyimpanan Android. |
| Emulator dan perangkat fisik | Tidak dijalankan: install/start APK, pan/zoom/marker P01 offline, dialog izin Android, GPS, Explore, trigger→kartu, service native, background/cold start/notifikasi/layar mati, serta audit runtime jaringan/penyimpanan. Tidak ada field test di Labtek V. |

**Status dan berikutnya:** Tahap 2/3 belum selesai; evidence baru tidak menaikkan
PBI menjadi `done`. Sediakan lokasi Android SDK yang valid atau pasang SDK,
platform-tools/build tools/platform yang dibutuhkan, lalu ulangi build berflag dan
audit `--apk`. Setelah itu jalankan emulator sebagai simulasi awal dan perangkat
fisik di Labtek V untuk GPS, trigger dan privasi. Lokasi/perangkat uji fisik tetap
perlu tim. Build biasa tetap terkunci login; coverage engineering bukan batas
layanan resmi. Target §5 belum tercapai; dokumen ini dipertahankan.

### Evidence lanjutan 14 November 2026 — integrasi demo Labtek V

**Instruksi pengguna:** “Ambil object labtek 5 terlebih dahulu, sesuaikan kebutuhan
lainnya untuk login bisa di skip terlebih dahulu fokus untuk integrasi dari fe
dan be yang terlibat pada fitur fitur app yang disebut”. Mandat ini diterapkan
pada source integrasi lokal `dev` `089883c` + working tree, tanpa commit/push,
merge Git, atau mengubah `lib/contracts/`. File WIP LB terkait disalin ke root
untuk integrasi; worktree LB asal tetap utuh. Login wajib produk tetap berlaku.

**Perubahan nyata:**

- `tools/tiles/cluster_pmtiles.py` + hook pipeline + tiga regression test:
  susun ulang payload berdasarkan tile ID, flatten root, simpan directory/metadata
  tanpa kompresi, validasi sebelum/sesudah. Output baru **1.022.885 byte**, SHA-256
  `6af43dfb1be0f854480ab45caa5dadc672e865134d50cddf43a316fc97934792`.
  Ini berbeda dari probe CLI awal karena encoding directory/metadata berbeda.
  Seluruh 13 payload terdekompresi dan metadata sama dengan arsip awal; rerun
  transformasi deterministik menghasilkan byte identik. Full build Planetiler
  tidak dijalankan ulang, input mentah tetap hasil pipeline sebelumnya.
- `lib/logic/map/agam_map_config.dart`, style lokal dan audit diadopsi dari WIP LB.
  `internalDemo()` memakai bounds engineering PRD, kamera P01; konfigurasi area
  pending produk tetap ada. Tidak mengarang geometri/pintu masuk baru.
- `lib/logic/map/offline_map_tiles.dart` membaca PMTiles APK dengan `fromBytes`,
  merender seluruh tile sebelum viewport dipakai dan menyimpan PNG hanya di
  memori. `lib/ui/widgets/offline_campus_map.dart` menyediakan pan/zoom/overzoom,
  marker repository, posisi perangkat, Pusatkan, dan dua tautan atribusi.
  Renderer dibatasi arsip kecil ≤256 addressed tile dan flat root; bukan reader
  umum untuk arsip wilayah besar. Tidak memakai cache disk `vector_map_tiles`.
- `lib/ui/explore_map_screen.dart`, `app.dart`, `poi_detail_screen.dart`, dan
  `main.dart`: layanan LA asli, marker/trigger/detail repository yang sama,
  Mulai/Akhiri Explore, GPS/izin dan lifecycle, serta kanal `viewRequests` dari
  responder ke UI04. Demo hanya menampilkan Explore; fitur lain yang masih fake
  tidak dibuka. Navigasi di detail demo dinonaktifkan. Flag eksplisit diperlukan
  untuk pengecualian login; default flag false menahan akses sampai PB21 tersedia.
- Pubspec/lock mendaftarkan aset dan dependency: `flutter_map 7.0.2`,
  `vector_tile_renderer 5.2.0`, `pmtiles 1.3.0`, `latlong2 0.9.1`, dan
  `url_launcher ^6.3.2` (resolved 6.3.3, hanya tautan statis atas ketukan).
  Kombinasi provider probe awal tidak dipasang pada aplikasi.
- CI menambah test pipeline, build demo berflag, audit aset APK, dan artifact
  `agam-internal-demo-debug-apk` setelah artifact debug biasa. Ini konfigurasi
  source saja, belum merupakan run GitHub atau APK yang tersedia.

| Pemeriksaan aktual | Hasil dan batas evidence |
| --- | --- |
| SDK Flutter terkunci dan `dart format --output=none --set-exit-if-changed lib test` | Flutter 3.47.9 / Dart 3.13.7; 74 file, 0 perubahan pada check akhir. |
| `flutter analyze` | No issues found. |
| `flutter test --reporter expanded` | **233 lulus**; log lokal `tools/tiles/.cache/demo-flutter-tests.log`. Termasuk render 13 tile saat HTTP ditolak dan widget controller/lokasi asli dengan **GPS simulasi**. |
| Uji widget `test/ui/demo_explore_test.dart` | Pan, overzoom 19, posisi stream, akurasi buruk, dwell, P01→UI03→UI04 P01, kanal view P02→P02, Akhiri/service, GPS mati, dan cleanup langganan lulus. Awal uji sempat gagal karena penjadwalan real engine/future pada zona fake tester; test menyelaraskan keduanya, tanpa mengubah engine/threshold produk. |
| Pratinjau `tools/tiles/.cache/demo-labtek-v-widget.png` | Dihasilkan dari widget dengan font aplikasi dan diperiksa visual: basemap bangunan/jalan nyata, sheet Labtek V, label placeholder, tombol sesi dan atribusi terbaca. **Bukan screenshot Android atau bukti GPS nyata.** |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -q` | **21 lulus**; 18 existing + 3 clustering. |
| Perbandingan arsip awal vs output | Seluruh 13 payload berdasarkan tile ID dan metadata identik setelah dekompresi. Backup build-time lokal di cache diabaikan Git; bukan riwayat posisi. |
| `python -X utf8 tools/tiles/audit_assets.py` dan CLI `pmtiles verify` | Lulus pada aset baru; audit tanpa `--apk`. |
| `flutter build apk --debug --dart-define=AGAM_INTERNAL_DEMO=true` | Gagal: **No Android SDK found**; tidak ada ukuran/hash APK baru. `flutter doctor -v` juga tidak menemukan Android toolchain/perangkat Android. |
| Pemeriksaan source privasi | Jalur runtime peta memakai bundle/memori; tidak ada tulis file/koordinat, tile HTTP, glyph/sprite, atau log posisi baru. Pemeriksaan lalu lintas/penyimpanan di Android belum dijalankan. |

**Sisa:** pasang/konfigurasikan Android SDK untuk build dan audit APK, atau
verifikasi CI setelah publikasi diotorisasi terpisah. Tetapkan perangkat,
install APK internal, uji mode pesawat, GPS fisik dan trigger di Labtek V,
notifikasi saat layar mati/background, serta akhir sesi. PBI/acceptance tetap
belum selesai; target §5 belum tercapai, rencana dan pointer tidak dihapus.


### Evidence awal 14 November 2026 — probe pemilihan renderer (historis)

**Batas pekerjaan:** checkout root tetap `dev` pada `089883c`. WIP di worktree
`../AGAM-LB-PB04` pada `LB` `d602fed` dibaca tanpa diubah. Tidak melakukan
sinkronisasi, commit, push, merge, perubahan kontrak, atau bypass login. Perubahan
repo sesi ini hanya dokumentasi; belum ada renderer yang terintegrasi.

**Sumber versi/API:** metadata versi dari API pub.dev dan source package hasil
`pub get`, bukan asumsi dari contoh README. Referensi:
[flutter_map 7.0.2](https://pub.dev/packages/flutter_map/versions/7.0.2),
[vector_map_tiles 8.0.0](https://pub.dev/packages/vector_map_tiles/versions/8.0.0),
[provider 1.5.0](https://pub.dev/packages/vector_map_tiles_pmtiles/versions/1.5.0),
[pmtiles 1.3.0](https://pub.dev/packages/pmtiles/versions/1.3.0).
`vector_map_tiles` stabil memerlukan `flutter_map ^7.0.2`; provider 1.5.2
memerlukan `vector_map_tiles ^9.0.0-beta.9`. Karena itu kombinasi versi terbaru
tidak disalin begitu saja.

Probe terisolasi berada di
`C:\Users\ASUS\AppData\Local\Temp\agam-renderer-probe-fafc9831bd3849d18e5c636f8c6e72a3`.
Pubspec proyek dan lockfile disalin ke sana, lalu dependency renderer ditambahkan
hanya pada salinan. File `test/provider_probe_test.dart` dan `compare_tiles.py`
adalah artefak pengujian lokal, bukan suite proyek atau rencana kedua. Direktori
temporer dapat hilang; evidence berikut tidak berarti pengujian sudah menjadi CI.

| Pemeriksaan aktual | Hasil dan batas evidence |
| --- | --- |
| Flutter SDK terkunci `--version` | Flutter 3.47.9 / Dart 3.13.7. |
| `flutter pub get` pada probe | Lulus; memilih kombinasi versi di checklist. `pubspec.yaml`/`pubspec.lock` repo tidak berubah. |
| `flutter test test/provider_probe_test.dart --reporter expanded` sebelum clustering | 1 lulus (seluruh 8 layer style terparse, sumber hanya `openmaptiles`, tanpa glyph/sprite), 1 gagal: `Unsupported operation: Unclustered archives`. Arsip asli tetap valid; ini batas dukungan package. Source `pmtiles 2.2.0` juga masih menolak arsip unclustered. |
| `tools/tiles/.cache/pmtiles.exe cluster <salinan-probe>/assets/map/ganesha.pmtiles` | Lulus dengan CLI existing v1.31.2. Hanya salinan di direktori probe yang dikonversi; aset produksi tidak berubah. |
| `pmtiles.exe verify <salinan-clustered>` dan `compare_tiles.py <root-repo> <salinan-clustered>` | Lulus; 13 payload tile berdasarkan tile ID identik setelah dekompresi, metadata identik, validator pipeline menerima arsip. Salinan clustered 1.019.776 byte, SHA-256 `ca1e38ea763a686c2524e63119e4062e35071fd5fddabc723318079866497946`. Hash ini **bukan** hash aset produksi. |
| Pengulangan dua test probe setelah clustering | **2 lulus**. Provider membaca file lokal dan MVT pada tile yang mencakup P08 di zoom 12–16; pada zoom 16 terdapat `building`/`transportation`. HTTP ditolak melalui `HttpOverrides` selama uji provider. Bukan bukti pan/zoom, widget render, marker, atau runtime Android. |
| `python -X utf8 -m unittest discover -s tools/tiles -p 'test_*.py' -q` pada root | **18 lulus**. |
| `python -X utf8 ../AGAM-LB-PB04/tools/tiles/audit_assets.py` | Lulus atas aset WIP LB; tanpa `--apk`. Arsip produksi masih 1.035.927 byte dengan hash `8501f70bcc5d8b2624a4eaa12074006b99a4631d9deba21a5b91496087e844f3`. |
| `git apply --check ../AGAM-LB-PB04/tools/tiles/pubspec-map-assets.patch` pada root | Gagal sesuai temuan: patch WIP tidak cocok dengan pubspec integrasi. Perlu diperbarui saat perubahan aset direview LA; tidak diterapkan paksa. |

**Jalur API yang diperiksa:** `PmTilesVectorTileProvider.fromSource(path-lokal)`
membaca file lokal, `provide(TileIdentity)` menghasilkan byte MVT terdekompresi,
`minimumZoom`/`maximumZoom` mengikuti header, dan `archive.close()` menutup
sumber. Style diparse dengan `ThemeReader().read(json)`; source `openmaptiles`
harus diikat secara eksplisit melalui `TileProviders`. Jangan memakai
`StyleReader` jaringan atau contoh tema Protomaps untuk arsip OpenMapTiles AGAM.
Saat integrasi, audit seluruh jalur cache/log agar tidak menyimpan jejak posisi
pengguna, dan uji overzoom dari tile maksimum 16.

**Berikutnya:** di track LB, implementasikan dan uji clustering sebagai bagian
pipeline yang dapat dijalankan ulang, termasuk validasi manifest, kesetaraan
payload, dan rerun deterministik. Lalu lanjutkan binding renderer/aset bersama
FE/LA sesuai ownership/review. Keputusan Tahap 0 tetap diperlukan sebelum
aktivasi trigger dan uji demo fisik. Analyze/test aplikasi utama, build APK,
emulator, perangkat fisik, dan field test tidak dijalankan pada sesi dokumentasi
dan probe ini. Target §5 belum tercapai; dokumen ini tetap dipertahankan.

## 7. Penghapusan wajib agar dokumen tidak tertinggal

Dokumen ini harus dihapus ketika kriteria §5 seluruhnya terpenuhi **atau** PM membatalkan target demo. Penghapusan menjadi gerbang penutupan pekerjaan:

1. Pada sesi yang sama ketika target selesai/dibatalkan, hapus file `.agent/demo-apk-temporary-plan.md` sebelum menyatakan pekerjaan tuntas.
2. Verifikasi file sudah tidak ada, misalnya dengan `Test-Path .agent/demo-apk-temporary-plan.md` yang menghasilkan `False`.
3. Hapus juga pointer ke dokumen ini dari `.agent/sessionHandoff.md` bila masih ada.
4. Jangan memindahkan atau menyalin rencana ini ke file sementara lain, PRD, atau implementation phases. PBI resmi tetap dilaporkan melalui dokumen resminya bila memang status PBI berubah.
5. Jika pekerjaan hanya dijeda, jangan hapus dokumen; perbarui tabel §6 dan alasan jeda. Saat pekerjaan dilanjutkan, periksa §5 terlebih dahulu: bila sudah lengkap, lakukan penghapusan sebelum pekerjaan lain.

Aturan ini adalah gerbang penutupan yang harus dijalankan oleh agent saat target tercapai; file tidak menghapus dirinya sendiri di background. Tidak dibuat script, hook, automation, atau dokumen sementara tambahan.

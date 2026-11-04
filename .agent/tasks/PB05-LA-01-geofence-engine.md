# PB05-LA-01 — Engine geofence sinkron

## Identitas

| Atribut | Nilai |
| --- | --- |
| PBI induk | PB05 — Engine geofence in-app |
| Bagian pekerjaan | LA-01 — Evaluasi posisi dan kandidat trigger |
| Owner-role | LA |
| Status dokumen | Spesifikasi diadopsi 4 November 2026; hasil aktual di handoff |
| Dasar inspeksi | Source lokal, 4 November 2026 |
| Output | Engine sinkron, state machine, dan automated test |
| Integrasi berikutnya | PB06 — `SessionController` |
| Dependency eksternal | Tidak ada; fixture sintetis |

## 1. Target

Menerima pembacaan lokasi dan menghasilkan kandidat trigger berdasarkan radius masing-masing POI, kualitas lokasi, dwell, histeresis, cooldown, dan urutan waktu. Engine sepenuhnya di memori, dapat diuji tanpa GPS, emulator, Firebase, audio, atau UI.

Task terbukti selesai secara teknis setelah perilaku pengujian terverifikasi. Keberhasilan pada POI nyata tetap membutuhkan integrasi dan uji perangkat; penyelesaian task tidak otomatis menyelesaikan PB05.

## 2. Kondisi source saat inspeksi awal

Kontrak existing menyediakan `Poi.id/position/radiusM`, `LocationFix.position/accuracyM/timestamp`, haversine `GeoPoint.distanceTo`, konstanta geofence, `PoiTriggerEvent`, dan `SessionController`. Engine asli belum ada sebelum task ini.

`PoiTriggerEvent` tidak menjadi output engine karena mode dan jenis respons ditentukan lapisan sesi. Source hasil task tercantum pada §4; kondisi awal ini bukan status implementasi terkini.

## 3. Konteks wajib

- [PRD §6](../PRD.md#6-mode-aplikasi-dan-sesi-lokasi): mode dan sesi.
- [PRD §9.2](../PRD.md#92-logika-trigger): trigger.
- [PRD §16](../PRD.md#16-privasi) dan [§22](../PRD.md#22-hal-tertunda-tbd): privasi dan TBD.
- [Implementation phases](../implementationPhases.md): §2 ownership, PB05, PB06.
- Kontrak: `lib/contracts/constants.dart`, model lokasi, geografi, POI, dan sesi.
- `test/contracts/models_test.dart`: acuan haversine independen existing.

Detail renderer, produksi media, dan routing tidak diperlukan untuk task ini.

## 4. Scope dan ownership

Termasuk evaluasi jarak, state per POI, validasi defensif, dwell/cooldown/histeresis, pengujian deterministik, dan pencatatan parameter engineering.

Di luar scope: izin/GPS, foreground service, notifikasi/getar/audio, progres/check-in, batas kampus, interval GPS adaptif, dan pemilihan respons per mode. Interval adaptif tetap pekerjaan integrasi lokasi/sesi; jangan dianggap selesai pada task ini.

File implementasi dan test:

- `lib/logic/location/geofence_engine.dart`
- `test/logic/location/geofence_engine_test.dart`

Helper kecil berada dalam test yang sama. Tidak menambah package. Tidak mengubah `lib/contracts/`, fake sesi, UI, Android, atau dataset produksi. Perubahan dokumentasi hanya keputusan, tautan brief, progres, dan handoff.

## 5. API internal LA

```dart
typedef GeofenceDistanceCalculator = double Function(
  GeoPoint from,
  GeoPoint to,
);

class GeofenceEntry {
  const GeofenceEntry({required this.poiId, required this.triggeredAt});
  final String poiId;
  final DateTime triggeredAt;
}

class GeofenceEngine {
  GeofenceEngine({
    required Iterable<Poi> pois,
    double hysteresisMarginM = 5,
    Duration maxSampleGap = const Duration(seconds: 10),
    GeofenceDistanceCalculator? distanceCalculator,
  });

  List<GeofenceEntry> evaluate(LocationFix fix, {required bool enabled});
}
```

API di atas adalah signature, bukan salinan implementasi. Evaluasi sinkron tanpa Future, stream, atau timer. Output kosong berarti tidak ada trigger baru. Kalkulator default memakai `GeoPoint.distanceTo`; injection memungkinkan batas numerik yang tepat dalam test.

Constructor mengambil snapshot ID, posisi, dan radius. Perubahan koleksi asal tidak memengaruhi engine. Urutan output mengikuti urutan POI saat konstruksi. Kontrak bersama tidak berubah.

Pergantian dataset aktif harus diputuskan pada brief PB06. Jangan membuat ulang engine setiap posisi karena cooldown akan hilang.

## 6. Parameter dan asal keputusan

| Parameter | Sumber/nilai | Status |
| --- | --- | --- |
| Radius | `Poi.radiusM` | Data POI |
| Radius default | Konstanta existing 15 m | Produk; bukan pengganti radius per POI |
| Akurasi maksimum | Konstanta existing 20 m | Produk |
| Dwell | Konstanta existing 5 detik | Produk |
| Cooldown | Konstanta existing 10 menit | Produk |
| Margin histeresis | Default 5 m, configurable | Diterapkan, belum dikalibrasi |
| Jeda sampel maksimum | Default 10 detik, configurable | Diterapkan, belum dikalibrasi |

Requirement produk menggunakan konstanta existing. Jeda mencegah sampel yang terpisah lama dianggap sebagai dwell kontinu. Nilai default bukan hasil pengukuran kampus; catat pada PRD saat diterapkan.

## 7. State internal dan privasi

Per POI: `enteredAt`, `lastInsideSampleAt`, `triggeredInside`, `lastTriggeredAt`. Secara global: timestamp input aktif terakhir yang diterima dalam urutan waktu.

Konfigurasi POI tersimpan untuk evaluasi. Posisi pengguna hanya dipakai selama pemanggilan; tidak menyimpan seluruh `LocationFix`, kumpulan koordinat, atau riwayat. Tidak ada penyimpanan persisten maupun jaringan.

## 8. Urutan evaluasi

### 8.1 Nonaktif

`enabled=false` menghasilkan output kosong, membersihkan kandidat dwell serta pengunci kunjungan seluruh POI, mempertahankan cooldown, tidak menghitung jarak, dan tidak memperbarui timestamp global. Aktivasi ulang wajib dwell baru. Pemanggil menentukan enabled dari sesi dan area.

### 8.2 Urutan waktu

Input aktif harus lebih baru daripada timestamp terakhir. Timestamp sama/mundur diabaikan tanpa mutasi. Timestamp lebih baru memperbarui penanda global sebelum validasi kualitas. Gunakan timestamp input, bukan jam sistem.

### 8.3 Validasi input

Koordinat harus finite dan dalam rentang WGS84; akurasi harus finite, tidak negatif, dan ≤ konstanta maksimum. Input invalid membatalkan semua kandidat dwell, mempertahankan pengunci dan cooldown. Lokasi buruk bukan bukti pengguna keluar.

### 8.4 Per POI

1. Hitung jarak. Jarak negatif/nonfinite membatalkan kandidat terkait tanpa menghapus pengunci/cooldown.
2. Jika terkunci: pertahankan sampai jarak > radius + margin. Sampel keluar melepas pengunci dan membersihkan kandidat, tanpa trigger.
3. Jika belum terkunci dan jarak > radius: batalkan kandidat.
4. Di dalam radius: mulai kandidat jika belum ada; mulai ulang jika jeda sampel di dalam sebelumnya > batas jeda.
5. Catat waktu sampel di dalam. Jika dwell atau cooldown belum terpenuhi, jangan trigger.
6. Jika keduanya terpenuhi: keluarkan satu entry, catat waktu trigger, kunci kunjungan, bersihkan kandidat.

Batas inklusif: radius tepat termasuk masuk, akurasi tepat maksimum diterima, dwell/cooldown tepat batas memenuhi, radius + margin tepat belum keluar, jeda tepat maksimum diterima.

Saat masuk kembali dalam cooldown, dwell tetap dihitung. Bila tetap di dalam sampai cooldown selesai, sampel valid berikutnya boleh trigger tanpa keluar lagi. Tidak ada trigger tanpa sampel baru.

## 9. Validasi konfigurasi

Constructor melempar `ArgumentError` untuk ID kosong/whitespace/duplikat, koordinat POI invalid, radius nonfinite atau ≤0, margin nonfinite atau negatif, dan jeda maksimum ≤0. Dataset kosong diperbolehkan. Ini pertahanan engine, bukan pengganti parser PB03.

## 10. Batas integrasi PB06

```text
LocationService
  → SessionController menentukan enabled
  → GeofenceEngine.evaluate
  → GeofenceEntry
  → SessionController menentukan mode/respons
  → PoiTriggerEvent
  → notifikasi/audio/trail
```

Engine tidak mengetahui tujuan navigasi, tidak memilih full/brief, tidak menyimpan progres atau memanggil service lain. PB06 harus menetapkan lifecycle engine, pembaruan dataset, dan start/end sesi sebelum integrasi.

## 11. Fixture

Fixture diberi label **SINTETIS — bukan data kampus**. State machine memakai kalkulator terinjeksi dengan jarak pasti untuk menghindari pembulatan. Integrasi kalkulator default memakai titik referensi existing dan acuan independen pada test kontrak: Oktagon–TVST 49,3895 m. Jangan menghitung expected memakai fungsi produksi yang diuji.

## 12. Matriks pengujian

Waktu t adalah waktu sintetis, tanpa delay.

| Skenario | Input | Hasil wajib |
| --- | --- | --- |
| Nonaktif | Sampel dalam selama ≥5 detik | Tidak terpicu; calculator tidak dipanggil |
| Dwell belum cukup | t=0 dan t=4,999 detik | Tidak terpicu |
| Dwell tepat | t=0 dan t=5 detik | Satu entry, timestamp input |
| Radius tepat | 15 m pada radius 15 m | Masuk |
| Di luar | 15,001 m | Kandidat batal |
| Akurasi batas | 20 m | Diterima |
| Akurasi buruk/invalid | >20, negatif, NaN, infinity | Dwell batal, tanpa kalkulasi |
| Posisi invalid | Di luar rentang/nonfinite | Dwell batal |
| Tetap di area | Lebih lama dari cooldown | Tidak berulang |
| Histeresis batas | Setelah trigger: 20 m | Tetap terkunci |
| Keluar | Setelah trigger: 20,001 m | Pengunci dilepas |
| Masuk saat cooldown | Keluar lalu masuk sebelum 10 menit | Tidak langsung terpicu |
| Cooldown batas | Dwell terpenuhi, tepat 10 menit sejak trigger | Satu trigger |
| Jeda berlebihan | t=0 lalu t=11 detik | Dwell ulang |
| Jeda batas | t=0 lalu t=10 detik | Dwell terpenuhi |
| Timestamp sama/mundur | Input di luar radius dengan waktu lama | Tidak mengubah kandidat |
| Nonaktif lalu aktif | Dwell belum selesai | Dwell baru wajib |
| Nonaktif setelah trigger | Aktif lagi | Cooldown tetap berlaku |
| Multi-POI | Dua kandidat memenuhi bersamaan | Urutan stabil, state independen |
| Radius berbeda | Radius berbeda pada jarak sama | Radius per POI dipakai |
| Snapshot | Koleksi asal diganti/dikosongkan | Konfigurasi tetap |
| Dataset kosong | Tanpa POI | Kosong |
| Konfigurasi invalid | ID/radius/posisi/margin/jeda invalid | ArgumentError |
| Jarak default | Acuan 49,3895 m dengan radius 49 dan 50 | Hanya radius 50 terpicu |
| Calculator invalid | Negatif/nonfinite | Kandidat terkait batal; pengunci tetap |
| Parameter custom | Margin nol, jeda 2 detik | Mengikuti konfigurasi |

## 13. Command verifikasi

```text
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test test/logic/location/geofence_engine_test.dart
fvm flutter test
git diff --check
```

Command adalah prosedur, bukan evidence PASS. Format ulang hanya file task jika diperlukan. APK tidak diperlukan untuk membuktikan logic murni. Catat command gagal/tidak tersedia dan alasan; jangan menurunkan requirement agar lulus.

## 14. Penerimaan

Engine/test tersedia, matriks terverifikasi, pemeriksaan relevan lulus, kontrak tetap, tanpa jaringan/riwayat lokasi/timer/SDK baru, parameter belum dikalibrasi tercatat, diff dapat direview, handoff diperbarui.

Jika SDK belum tersedia, implementasi boleh dilaporkan tersedia tetapi verifikasi teknis masih tertunda. PB05 tetap in_progress. Jangan mengklaim trigger nyata, foreground service, F02, atau margin optimal.

## 15. Laporan penyelesaian dan instruksi agent

Laporan menggunakan bagian: perubahan, tabel command/hasil/cakupan, keputusan engineering dan kalibrasi, integrasi siap/belum, status task/PB05/acceptance lapangan, serta langkah berikutnya. Evidence aktual ditulis di handoff, bukan disalin ke brief. Jangan menulis PASS sebelum menjalankan command.

Contoh instruksi:

```text
Kerjakan PB05-LA-01 berdasarkan brief ini. Ikuti urutan baca proyek,
periksa source, dan pertahankan perubahan anggota tim. Sampaikan
perbedaan source terhadap brief. Lanjutkan dalam batas task jika
tidak ada konflik. Gunakan kontrak/konstanta existing, jangan ubah
SessionController, UI, atau Android. Jalankan pemeriksaan, review
diff, dan perbarui handoff/status aktual. Pisahkan hasil logic,
automated test, integrasi, dan acceptance lapangan. Jangan commit,
push, merge, atau merilis.
```

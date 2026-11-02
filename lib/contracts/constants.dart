/// Nilai produk dari `.agent/PRD.md` yang dipakai bersama oleh semua track.
///
/// Ubah nilai di sini hanya jika PRD berubah. Radius per POI tetap disimpan
/// di data POI agar dapat dikalibrasi tanpa build ulang; nilai di bawah
/// hanyalah default.
library;

/// Radius geofence default per POI (PRD §9.1).
const double kDefaultPoiRadiusM = 15;

/// Pembacaan lokasi dengan akurasi lebih buruk dari ini diabaikan untuk
/// trigger (PRD §9.2).
const double kTriggerMaxAccuracyM = 20;

/// Lama pengguna harus berada di dalam radius sebelum trigger (PRD §9.2).
const Duration kTriggerDwell = Duration(seconds: 5);

/// Jeda sebelum POI yang sama boleh terpicu lagi (PRD §9.2).
const Duration kTriggerCooldown = Duration(minutes: 10);

/// Penyimpangan dari rute yang memicu rerouting (PRD §11).
const double kRerouteDistanceM = 25;

/// Jarak ke titik tujuan yang dianggap tiba (PRD §11).
const double kArrivalDistanceM = 15;

/// Sesi berakhir otomatis setelah pengguna berada di luar area kampus
/// selama ini (PRD §6).
const Duration kOutsideCampusAutoEnd = Duration(minutes: 30);

/// Margin area layanan di sekitar kampus (PRD §9.3).
const double kCampusMarginM = 200;

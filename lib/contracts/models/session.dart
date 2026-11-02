/// Mode aplikasi (PRD §6). Selain [none], setiap mode adalah sesi.
enum SessionMode {
  /// Peta biasa: lokasi hanya dibaca saat aplikasi tampil, tanpa trigger.
  none,
  explore,
  navigation,
  trail,
}

enum SessionEndReason {
  userEnded,

  /// Berada di luar area kampus lebih dari 30 menit.
  outsideCampusTimeout,

  permissionRevoked,
}

class SessionState {
  const SessionState({required this.mode, this.startedAt, this.lastEndReason});

  const SessionState.idle({this.lastEndReason})
    : mode = SessionMode.none,
      startedAt = null;

  final SessionMode mode;
  final DateTime? startedAt;

  /// Alasan sesi terakhir berakhir, untuk ditampilkan UI.
  final SessionEndReason? lastEndReason;

  bool get isActive => mode != SessionMode.none;
}

enum TriggerResponse {
  /// Getar, prompt audio, notifikasi, dan pilihan Dengarkan/Lihat/Lewati.
  full,

  /// Notifikasi ringkas tanpa audio; dipakai saat mode Navigasi untuk POI
  /// yang bukan tujuan.
  brief,
}

/// Dipancarkan setiap kali pengguna masuk dan bertahan di radius POI
/// selama sesi aktif.
class PoiTriggerEvent {
  const PoiTriggerEvent({
    required this.poiId,
    required this.mode,
    required this.response,
    required this.triggeredAt,
  });

  final String poiId;
  final SessionMode mode;
  final TriggerResponse response;
  final DateTime triggeredAt;
}

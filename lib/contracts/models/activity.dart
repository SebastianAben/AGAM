/// Event log aktivitas internal (PRD §15.5; PB22). Kontrak v1.1.
///
/// [ActivityEvent] adalah tipe tertutup: hanya event dan field di PRD §15.5
/// yang dapat dibuat. Tidak ada event bebas atau field tambahan, sehingga
/// koordinat, ID/nama POI, tujuan navigasi, kata kunci pencarian, dan alasan
/// sesi berakhir tidak dapat dicatat dari kode mana pun. Menambah event
/// memerlukan keputusan PM dan perubahan kontrak.
library;

import 'account.dart';
import 'session.dart';

/// Ketelitian waktu yang dicatat logger untuk sebuah event.
enum ActivityTimePrecision {
  /// Field `at`: timestamp perangkat.
  instant,

  /// Field `date`: `YYYY-MM-DD` tanpa jam. Untuk event yang waktunya dapat
  /// bertepatan dengan kedatangan di POI tertentu.
  dateOnly,
}

/// Mode sesi pada event `modeStart`/`modeEnd`. Peta biasa bukan sesi
/// sehingga tidak dicatat.
enum ActivityMode {
  explore,
  navigation,
  trail;

  /// `null` untuk [SessionMode.none].
  static ActivityMode? fromSession(SessionMode mode) => switch (mode) {
    SessionMode.none => null,
    SessionMode.explore => ActivityMode.explore,
    SessionMode.navigation => ActivityMode.navigation,
    SessionMode.trail => ActivityMode.trail,
  };
}

/// Fitur pada event `featureUsed`.
enum ActivityFeature { search, poiCard, narration, facilities }

/// Satu event log. Waktu tidak dibawa event; logger yang mencatatnya sesuai
/// [timePrecision]. Field umum `uid`, `type`, dan waktu ditambahkan logger.
sealed class ActivityEvent {
  const ActivityEvent();

  const factory ActivityEvent.signUp({required UserRole role}) = SignUpEvent;
  const factory ActivityEvent.login() = LoginEvent;
  const factory ActivityEvent.logout() = LogoutEvent;

  /// Hanya saat cold start, bukan setiap kembali ke foreground.
  const factory ActivityEvent.appOpen({
    required String appVersion,
    required String androidVersion,
    required String deviceModel,
  }) = AppOpenEvent;

  const factory ActivityEvent.modeStart({required ActivityMode mode}) =
      ModeStartEvent;

  /// [duration] dibulatkan ke kelipatan 5 menit terdekat.
  factory ActivityEvent.modeEnd({
    required ActivityMode mode,
    required Duration duration,
  }) = ModeEndEvent;

  const factory ActivityEvent.featureUsed({required ActivityFeature feature}) =
      FeatureUsedEvent;

  const factory ActivityEvent.trailCompleted() = TrailCompletedEvent;

  /// Nilai field `type` di Firestore.
  String get type;

  ActivityTimePrecision get timePrecision => ActivityTimePrecision.instant;

  /// Field tambahan khusus event ini, persis seperti PRD §15.5.
  Map<String, Object> get fields => const {};
}

final class SignUpEvent extends ActivityEvent {
  const SignUpEvent({required this.role});

  final UserRole role;

  @override
  String get type => 'signUp';

  @override
  Map<String, Object> get fields => {'role': role.name};
}

final class LoginEvent extends ActivityEvent {
  const LoginEvent();

  @override
  String get type => 'login';
}

final class LogoutEvent extends ActivityEvent {
  const LogoutEvent();

  @override
  String get type => 'logout';
}

final class AppOpenEvent extends ActivityEvent {
  const AppOpenEvent({
    required this.appVersion,
    required this.androidVersion,
    required this.deviceModel,
  });

  final String appVersion;
  final String androidVersion;
  final String deviceModel;

  @override
  String get type => 'appOpen';

  @override
  Map<String, Object> get fields => {
    'appVersion': appVersion,
    'androidVersion': androidVersion,
    'deviceModel': deviceModel,
  };
}

final class ModeStartEvent extends ActivityEvent {
  const ModeStartEvent({required this.mode});

  final ActivityMode mode;

  @override
  String get type => 'modeStart';

  @override
  ActivityTimePrecision get timePrecision => ActivityTimePrecision.dateOnly;

  @override
  Map<String, Object> get fields => {'mode': mode.name};
}

final class ModeEndEvent extends ActivityEvent {
  ModeEndEvent({required this.mode, required Duration duration})
    : durationMin = roundToFiveMinutes(duration);

  final ActivityMode mode;

  /// Durasi sesi dalam menit, kelipatan 5.
  final int durationMin;

  /// Dibulatkan ke kelipatan 5 menit terdekat; setengah dibulatkan ke atas.
  /// Durasi negatif dianggap 0.
  static int roundToFiveMinutes(Duration duration) {
    final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    const step = 5 * 60;
    return ((seconds + step ~/ 2) ~/ step) * 5;
  }

  @override
  String get type => 'modeEnd';

  @override
  ActivityTimePrecision get timePrecision => ActivityTimePrecision.dateOnly;

  @override
  Map<String, Object> get fields => {
    'mode': mode.name,
    'durationMin': durationMin,
  };
}

final class FeatureUsedEvent extends ActivityEvent {
  const FeatureUsedEvent({required this.feature});

  final ActivityFeature feature;

  @override
  String get type => 'featureUsed';

  @override
  Map<String, Object> get fields => {'feature': feature.name};
}

final class TrailCompletedEvent extends ActivityEvent {
  const TrailCompletedEvent();

  @override
  String get type => 'trailCompleted';

  @override
  ActivityTimePrecision get timePrecision => ActivityTimePrecision.dateOnly;
}

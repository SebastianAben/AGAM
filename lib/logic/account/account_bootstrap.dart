/// Merangkai akun dan log aktivitas asli (PB21–PB22, milik LA).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../contracts/contracts.dart';
import '../la_bootstrap.dart';
import '../settings/device_settings_store.dart';
import '../trail/account_visit_store.dart';
import 'activity_recorders.dart';
import 'auth_gateway.dart';
import 'device_auth_service.dart';
import 'firestore_activity_logger.dart';
import 'profile_store.dart';

class LaAccountServices {
  const LaAccountServices({
    required this.auth,
    required this.activity,
    required this.sessionActivity,
    required this.appOpen,
  });

  final DeviceAuthService auth;
  final FirestoreActivityLogger activity;
  final SessionActivityRecorder sessionActivity;
  final AppOpenRecorder appOpen;
}

/// Membuat akun asli di atas layanan LA [la]. Wajib dipanggil setelah
/// `Firebase.initializeApp()` dan sebelum layar pertama, karena sesi login
/// dipulihkan di sini.
///
/// Perangkaian:
/// - pengaturan mengikuti akun yang login (PRD §15.1);
/// - logout mencatat `modeEnd`, mengakhiri sesi aktif dan audio narasi,
///   kemudian keluar;
/// - hapus akun mengakhiri sesi dan audio narasi tanpa log baru, lalu menghapus
///   log, profil, dan data lokal milik akun;
/// - akun yang keluar dari luar aplikasi (mis. dinonaktifkan) ikut
///   mengakhiri sesi dan menghentikan audio narasi.
///
/// [trailVisits] is the trail store the app uses; deleting the account also
/// clears its visited POIs and trail start on this device (PRD §16).
Future<LaAccountServices> createLaAccountServices(
  LaServices la, {
  AccountVisitStore? trailVisits,
}) => wireLaAccountServices(
  session: la.session,
  audio: la.audio,
  settings: la.settings,
  launchedFromNotification: la.notifier.launchedFromNotification,
  gateway: FirebaseAuthGateway(),
  profiles: FirestoreProfileStore(),
  local: LocalAccountStore(),
  trailVisits: trailVisits,
);

/// Merangkai layanan akun dengan dependensi yang dapat disuntikkan untuk test.
Future<LaAccountServices> wireLaAccountServices({
  required SessionController session,
  required AudioService audio,
  required DeviceSettingsStore settings,
  required Future<bool> Function() launchedFromNotification,
  required AuthGateway gateway,
  required ProfileStore profiles,
  required LocalAccountStore local,
  FirebaseFirestore? firestore,
  Future<AppOpenInfo> Function()? appOpenInfo,
  AccountVisitStore? trailVisits,
}) async {
  late final DeviceAuthService auth;
  final activity = FirestoreActivityLogger(
    currentUid: () => auth.current.account?.uid,
    firestore: firestore,
  );
  final sessionActivity = SessionActivityRecorder(
    session: session,
    activity: activity,
  )..start();

  Future<void> stopAudioSafely() async {
    try {
      await audio.stop();
    } on Object {
      // Kegagalan backend audio tidak boleh menghalangi logout/hapus akun.
    }
  }

  auth = DeviceAuthService(
    gateway: gateway,
    profiles: profiles,
    local: local,
    activity: activity,
    beforeSignOut: () async {
      sessionActivity.closeOpenMode();
      await session.end();
      await stopAudioSafely();
    },
    flushLogs: activity.flush,
    beforeDelete: () async {
      sessionActivity.discardOpenMode();
      await session.end();
      await stopAudioSafely();
    },
    deleteRemoteLogs: activity.deleteAllFor,
    clearLocalData: (uid) async {
      await settings.clearAccount(uid);
      await trailVisits?.clear(uid);
    },
  );

  await auth.restore();
  await settings.switchAccount(auth.current.account?.uid);
  auth.state.listen((state) {
    unawaited(settings.switchAccount(state.account?.uid));
    if (!state.isSignedIn) {
      if (session.current.isActive) {
        sessionActivity.discardOpenMode();
        unawaited(session.end());
      }
      if (audio.current.status != PlaybackStatus.idle) {
        unawaited(stopAudioSafely());
      }
    }
  });

  final appOpen = AppOpenRecorder(
    auth: auth,
    activity: activity,
    info: appOpenInfo ?? deviceAppOpenInfo,
    launchedFromNotification: launchedFromNotification,
  );
  await appOpen.start();

  return LaAccountServices(
    auth: auth,
    activity: activity,
    sessionActivity: sessionActivity,
    appOpen: appOpen,
  );
}

/// Versi aplikasi, versi Android, dan model perangkat untuk `appOpen`.
Future<AppOpenInfo> deviceAppOpenInfo() async {
  String appVersion = 'unknown';
  String androidVersion = 'unknown';
  String deviceModel = 'unknown';
  try {
    appVersion = (await PackageInfo.fromPlatform()).version;
  } on Object {
    // Tetap 'unknown'.
  }
  try {
    final android = await DeviceInfoPlugin().androidInfo;
    androidVersion = android.version.release;
    deviceModel = android.model;
  } on Object {
    // Tetap 'unknown'.
  }
  return (
    appVersion: shortField(appVersion),
    androidVersion: shortField(androidVersion),
    deviceModel: shortField(deviceModel),
  );
}

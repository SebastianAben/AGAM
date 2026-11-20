/// Merangkai akun dan log aktivitas asli (PB21–PB22, milik LA).
library;

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../la_bootstrap.dart';
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
/// - logout mencatat `modeEnd` lalu mengakhiri sesi aktif, kemudian keluar;
/// - hapus akun mengakhiri sesi tanpa log baru, lalu menghapus log, profil,
///   dan data lokal milik akun;
/// - akun yang keluar dari luar aplikasi (mis. dinonaktifkan) ikut
///   mengakhiri sesi.
Future<LaAccountServices> createLaAccountServices(LaServices la) async {
  late final DeviceAuthService auth;
  final activity = FirestoreActivityLogger(
    currentUid: () => auth.current.account?.uid,
  );
  final sessionActivity = SessionActivityRecorder(
    session: la.session,
    activity: activity,
  )..start();

  auth = DeviceAuthService(
    gateway: FirebaseAuthGateway(),
    profiles: FirestoreProfileStore(),
    local: LocalAccountStore(),
    activity: activity,
    beforeSignOut: () async {
      sessionActivity.closeOpenMode();
      await la.session.end();
    },
    flushLogs: activity.flush,
    beforeDelete: () async {
      sessionActivity.discardOpenMode();
      await la.session.end();
    },
    deleteRemoteLogs: activity.deleteAllFor,
    clearLocalData: la.settings.clearAccount,
  );

  await auth.restore();
  await la.settings.switchAccount(auth.current.account?.uid);
  auth.state.listen((state) {
    unawaited(la.settings.switchAccount(state.account?.uid));
    if (!state.isSignedIn && la.session.current.isActive) {
      sessionActivity.discardOpenMode();
      unawaited(la.session.end());
    }
  });

  final appOpen = AppOpenRecorder(
    auth: auth,
    activity: activity,
    info: deviceAppOpenInfo,
    launchedFromNotification: la.notifier.launchedFromNotification,
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

/// Merangkai layanan asli track LA (dependency injection, milik LA).
///
/// Dipanggil dari `lib/main.dart`; layanan LB yang belum tersedia masih
/// memakai fake (`.agent/implementationPhases.md` §2.6).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';

import '../contracts/contracts.dart';
import 'audio/agam_audio_handler.dart';
import 'audio/device_audio_service.dart';
import 'audio/device_voice_guidance.dart';
import 'audio/navigation_announcer.dart';
import 'data/data.dart';
import 'location/device_location_service.dart';
import 'location/device_permission_service.dart';
import 'location/position_source.dart';
import 'session/device_session_controller.dart';
import 'session/trigger_notifier.dart';
import 'session/trigger_responder.dart';
import 'settings/device_settings_store.dart';

/// Seluruh layanan LA asli.
class LaServices {
  const LaServices({
    required this.permissions,
    required this.location,
    required this.pois,
    required this.session,
    required this.audio,
    required this.voice,
    required this.settings,
    required this.notifier,
    required this.triggerResponder,
    required this.navigation,
    required this.navigationAnnouncer,
  });

  final DevicePermissionService permissions;
  final DeviceLocationService location;
  final PoiRepositoryImpl pois;
  final DeviceSessionController session;
  final DeviceAudioService audio;
  final DeviceVoiceGuidance voice;
  final DeviceSettingsStore settings;
  final LocalTriggerNotifier notifier;
  final TriggerResponder triggerResponder;
  final NavigationController navigation;
  final NavigationAnnouncer navigationAnnouncer;
}

/// Membuat layanan LA. Dari track LB: [map] untuk cek area kampus (auto-end
/// 30 menit dan penonaktifan trigger di luar area) dan [navigation] untuk
/// arahan suara serta pengumuman tiba. [navigation] berupa factory karena
/// navigasi membaca posisi dari `LocationService` asli yang dibuat di sini.
///
/// Wajib dipanggil sekali setelah `WidgetsFlutterBinding.ensureInitialized()`
/// dan `Firebase.initializeApp()` untuk sumber Firestore. Demo [bundledOnly]
/// tidak memerlukan Firebase dan tidak membaca cache konten produksi.
Future<LaServices> createLaServices({
  bool bundledOnly = false,
  bool developerTrialAvailable = false,
  required MapConfig map,
  required NavigationController Function(LocationService location) navigation,
}) async {
  final pois = await createLaPoiRepository(bundledOnly: bundledOnly);

  final settings = DeviceSettingsStore();
  await settings.load();

  final notifier = LocalTriggerNotifier();
  await notifier.init();

  final location = DeviceLocationService(
    source: GeolocatorPositionSource(),
    serviceStatus: Geolocator.getServiceStatusStream().map(
      (status) => status == ServiceStatus.enabled,
    ),
  )..attachToAppLifecycle();

  final session = DeviceSessionController(
    location: location,
    pois: pois,
    isInsideCampus: map.isInsideCampus,
    trialModeAvailable: developerTrialAvailable,
  );

  final audio = DeviceAudioService(
    backend: await AgamAudioHandler.init(),
    pois: pois,
  );

  final responder = TriggerResponder(
    session: session,
    pois: pois,
    notifier: notifier,
    audio: audio,
    settings: settings,
    isAppVisible: () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
  )..start();

  final navigationController = navigation(location);
  final voice = DeviceVoiceGuidance();
  final announcer = NavigationAnnouncer(
    navigation: navigationController,
    voice: voice,
    audio: audio,
  )..start();

  return LaServices(
    permissions: DevicePermissionService(),
    location: location,
    pois: pois,
    session: session,
    audio: audio,
    voice: voice,
    settings: settings,
    notifier: notifier,
    triggerResponder: responder,
    navigation: navigationController,
    navigationAnnouncer: announcer,
  );
}

/// Memisahkan bootstrap dataset agar jalur demo dapat diverifikasi tanpa
/// inisialisasi Firebase maupun akses direktori/cache konten produksi.
Future<PoiRepositoryImpl> createLaPoiRepository({
  bool bundledOnly = false,
}) async {
  final pois = PoiRepositoryImpl(
    bundled: const BundledDataset(),
    cache: bundledOnly
        ? InMemoryDatasetCache()
        : FileDatasetCache(await getApplicationSupportDirectory()),
    remote: bundledOnly
        ? const UnavailableRemoteSource()
        : FirestoreDatasetSource(),
  );
  await pois.ensureLoaded();
  // Pembaruan dari Firestore berjalan di latar; aplikasi tidak menunggu
  // jaringan dan tetap memakai cache/dataset bawaan bila gagal (PRD §15.2).
  if (!bundledOnly) unawaited(pois.refresh());

  return pois;
}

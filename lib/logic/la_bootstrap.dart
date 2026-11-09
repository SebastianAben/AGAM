/// Merangkai layanan asli track LA (dependency injection, milik LA).
///
/// Belum dipanggil dari `lib/main.dart`: penyambungan ke `AppServices` dan
/// UI dilakukan saat integrasi akhir sprint bersama FE dan LB
/// (`.agent/implementationPhases.md` §2.6).
library;

import 'package:path_provider/path_provider.dart';

import '../contracts/contracts.dart';
import 'audio/agam_audio_handler.dart';
import 'audio/device_audio_service.dart';
import 'data/data.dart';
import 'location/device_location_service.dart';
import 'location/device_permission_service.dart';
import 'location/position_source.dart';
import 'session/device_session_controller.dart';
import 'session/trigger_notifier.dart';
import 'session/trigger_responder.dart';
import 'settings/device_settings_store.dart';

/// Seluruh layanan LA asli. `voice` (PB12, Sprint 3) belum ada.
class LaServices {
  const LaServices({
    required this.permissions,
    required this.location,
    required this.pois,
    required this.session,
    required this.audio,
    required this.settings,
    required this.notifier,
    required this.triggerResponder,
  });

  final DevicePermissionService permissions;
  final DeviceLocationService location;
  final PoiRepositoryImpl pois;
  final DeviceSessionController session;
  final DeviceAudioService audio;
  final DeviceSettingsStore settings;
  final LocalTriggerNotifier notifier;
  final TriggerResponder triggerResponder;
}

/// Membuat layanan LA. [map] dari track LB dipakai untuk cek area kampus
/// (auto-end 30 menit dan penonaktifan trigger di luar area).
///
/// Wajib dipanggil sekali setelah `WidgetsFlutterBinding.ensureInitialized()`.
Future<LaServices> createLaServices({required MapConfig map}) async {
  final cacheDir = await getApplicationSupportDirectory();
  final pois = PoiRepositoryImpl(
    bundled: const BundledDataset(),
    cache: FileDatasetCache(cacheDir),
  );
  await pois.ensureLoaded();

  final settings = DeviceSettingsStore();
  await settings.load();

  final notifier = LocalTriggerNotifier();
  await notifier.init();

  final location = DeviceLocationService(
    source: const GeolocatorPositionSource(),
  )..attachToAppLifecycle();

  final session = DeviceSessionController(
    location: location,
    pois: pois,
    isInsideCampus: map.isInsideCampus,
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
  )..start();

  return LaServices(
    permissions: DevicePermissionService(),
    location: location,
    pois: pois,
    session: session,
    audio: audio,
    settings: settings,
    notifier: notifier,
    triggerResponder: responder,
  );
}

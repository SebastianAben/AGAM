import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'contracts/contracts.dart';
import 'contracts/fakes/fake_la_services.dart';
import 'logic/la_bootstrap.dart';
import 'logic/map/agam_map_config.dart';
import 'logic/routing/campus_routing_service.dart';
import 'logic/routing/device_navigation_controller.dart';
import 'logic/search/poi_search_service.dart';
import 'logic/search/repository_facility_service.dart';
import 'logic/trail/account_visit_store.dart';
import 'ui/app.dart';
import 'logic/session/trigger_notifier.dart';
import 'firebase_options.dart';
import 'logic/account/account_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('AGAM_INTERNAL_DEMO');
  if (!demo) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final (services, views, actions) = await _createProductionAppServices();
    runApp(
      AgamApp(services: services, poiViewRequests: views, onPoiAction: actions),
    );
    return;
  }
  final (services, views, actions) = await _createAppServices();
  runApp(
    AgamApp(
      services: services,
      poiViewRequests: views,
      onPoiAction: actions,
      internalDemo: true,
    ),
  );
}

/// Build produk: Firebase, akun asli dengan gerbang login (UI10), batas
/// layanan Kampus Ganesha + 200 m (PRD §9.3), dan layanan asli LA/LB yang
/// sama dengan demo. Fitur yang datanya belum ada (graf jalur
/// kampus, urutan resmi trail, rekomendasi) memakai layanan berstatus "belum
/// tersedia", bukan data palsu.
///
/// Seperti demo, permintaan buka POI dan aksi dari notifikasi trigger
/// diteruskan ke UI; tanpa ini notifikasi POI tidak membuka kartunya.
Future<
  (AppServices, Stream<String>, Future<void> Function(String, TriggerAction))
>
_createProductionAppServices() async {
  final map = AgamMapConfig.campus();
  const routing = UnavailableCampusRouting();
  final la = await createLaServices(
    bundledOnly: false,
    developerTrialAvailable: false,
    map: map,
    navigation: (location, session) => DeviceNavigationController(
      location: location,
      routing: routing,
      map: map,
      session: session,
    ),
  );
  final account = await createLaAccountServices(la);

  final services = AppServices(
    permissions: la.permissions,
    location: la.location,
    pois: la.pois,
    session: la.session,
    audio: la.audio,
    voice: la.voice,
    settings: la.settings,
    auth: account.auth,
    activity: account.activity,
    map: map,
    routing: routing,
    navigation: la.navigation,
    search: PoiSearchService(pois: la.pois),
    recommendations: const UnavailableRecommendationService(),
    trail: const UnavailableTrailService(),
    facilities: RepositoryFacilityService(la.pois),
  );
  return (
    services,
    la.triggerResponder.viewRequests,
    (String id, TriggerAction action) => la.triggerResponder.handleAction(
      TriggerActionEvent(poiId: id, action: action),
    ),
  );
}

/// Demo memakai seluruh layanan asli LA dan LB. Fitur yang datanya belum ada
/// memakai layanan asli berstatus "belum tersedia", bukan data palsu: graf
/// jalur kampus (routing), urutan resmi trail, dan rekomendasi. Akun demo
/// tetap fake karena demo tidak menjalankan Firebase; gerbang login hanya
/// ada di build produk.
Future<
  (AppServices, Stream<String>, Future<void> Function(String, TriggerAction))
>
_createAppServices() async {
  final map = AgamMapConfig.internalDemo();
  const routing = UnavailableCampusRouting();
  final la = await createLaServices(
    bundledOnly: true,
    developerTrialAvailable: const bool.fromEnvironment('AGAM_INTERNAL_DEMO'),
    map: map,
    navigation: (location, session) => DeviceNavigationController(
      location: location,
      routing: routing,
      map: map,
      session: session,
    ),
  );
  // Akun asli (createLaAccountServices) dipasang di jalur produksi bersama
  // gerbang login FE; demo tetap fake.
  final activity = FakeActivityLogger();

  return (
    AppServices(
      permissions: la.permissions,
      location: la.location,
      pois: la.pois,
      session: la.session,
      audio: la.audio,
      voice: la.voice,
      settings: la.settings,
      auth: FakeAuthService(activity: activity),
      activity: activity,
      map: map,
      routing: routing,
      navigation: la.navigation,
      search: PoiSearchService(pois: la.pois),
      recommendations: const UnavailableRecommendationService(),
      trail: const UnavailableTrailService(),
      facilities: RepositoryFacilityService(la.pois),
    ),
    la.triggerResponder.viewRequests,
    (id, action) => la.triggerResponder.handleAction(
      TriggerActionEvent(poiId: id, action: action),
    ),
  );
}

import 'package:flutter/material.dart';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('AGAM_INTERNAL_DEMO');
  if (!demo) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Login wajib belum tersedia.\n'
              'Build demo internal harus diaktifkan secara eksplisit.',
            ),
          ),
        ),
      ),
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

/// Demo memakai seluruh layanan asli LA dan LB. Fitur yang datanya belum ada
/// memakai layanan asli berstatus "belum tersedia", bukan data palsu: graf
/// jalur kampus (routing), urutan resmi trail, dan rekomendasi. Akun masih
/// fake karena demo tidak menjalankan Firebase dan gerbang login (UI10)
/// belum ada.
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

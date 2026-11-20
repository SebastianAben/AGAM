import 'package:flutter/material.dart';

import 'contracts/contracts.dart';
import 'contracts/fakes/fake_la_services.dart';
import 'contracts/fakes/fake_lb_services.dart';
import 'logic/la_bootstrap.dart';
import 'logic/map/agam_map_config.dart';
import 'logic/search/poi_search_service.dart';
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

/// Demo menghubungkan layanan nyata dan mempertahankan layar FE yang belum
/// didukung sebagai pratinjau tanpa menjalankan routing/trail/fasilitas fake.
Future<
  (AppServices, Stream<String>, Future<void> Function(String, TriggerAction))
>
_createAppServices() async {
  final map = AgamMapConfig.internalDemo();
  final routing = FakeRoutingService();
  final la = await createLaServices(
    bundledOnly: true,
    developerTrialAvailable: const bool.fromEnvironment('AGAM_INTERNAL_DEMO'),
    map: map,
    navigation: (location) =>
        FakeNavigationController(location: location, routing: routing),
  );
  final trail = FakeTrailService(session: la.session);
  final facilities = FakeFacilityService();
  // Akun masih fake sampai implementasi Firebase Auth tersedia (PB21).
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
      recommendations: FakeRecommendationService(
        trail: trail,
        facilities: facilities,
      ),
      trail: trail,
      facilities: facilities,
    ),
    la.triggerResponder.viewRequests,
    (id, action) => la.triggerResponder.handleAction(
      TriggerActionEvent(poiId: id, action: action),
    ),
  );
}

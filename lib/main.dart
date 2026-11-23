import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'contracts/contracts.dart';
import 'contracts/fakes/fake_la_services.dart';
import 'contracts/fakes/fake_lb_services.dart';
import 'logic/la_bootstrap.dart';
import 'logic/map/agam_map_config.dart';
import 'logic/search/poi_search_service.dart';
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
    final services = await _createProductionAppServices();
    runApp(AgamApp(services: services));
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

Future<AppServices> _createProductionAppServices() async {
  final map = AgamMapConfig.pendingServiceArea();
  final routing = FakeRoutingService();
  final la = await createLaServices(
    bundledOnly: false,
    developerTrialAvailable: false,
    map: map,
    navigation: (location) =>
        FakeNavigationController(location: location, routing: routing),
  );
  final account = await createLaAccountServices(la);
  final trail = FakeTrailService(session: la.session);
  final facilities = FakeFacilityService();

  return AppServices(
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
    recommendations: FakeRecommendationService(
      trail: trail,
      facilities: facilities,
    ),
    trail: trail,
    facilities: facilities,
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

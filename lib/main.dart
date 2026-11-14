import 'package:flutter/material.dart';

import 'contracts/contracts.dart';
import 'contracts/fakes/fake_lb_services.dart';
import 'logic/la_bootstrap.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AgamApp(services: await _createAppServices()));
}

/// Layanan LA asli; layanan LB masih fake sampai implementasinya tersedia.
Future<AppServices> _createAppServices() async {
  final map = FakeMapConfig();
  final routing = FakeRoutingService();
  final la = await createLaServices(
    map: map,
    navigation: (location) =>
        FakeNavigationController(location: location, routing: routing),
  );
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
    map: map,
    routing: routing,
    navigation: la.navigation,
    search: FakeSearchService(),
    recommendations: FakeRecommendationService(
      trail: trail,
      facilities: facilities,
    ),
    trail: trail,
    facilities: facilities,
  );
}

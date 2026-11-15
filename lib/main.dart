import 'package:flutter/material.dart';

import 'contracts/contracts.dart';
import 'contracts/fakes/fake_lb_services.dart';
import 'logic/la_bootstrap.dart';
import 'logic/map/agam_map_config.dart';
import 'logic/search/poi_search_service.dart';
import 'ui/app.dart';

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
  final (services, views) = await _createAppServices();
  runApp(
    AgamApp(services: services, poiViewRequests: views, internalDemo: true),
  );
}

/// Demo menampilkan hanya alur dengan sumber data/layanan nyata. Navigation,
/// trail, rekomendasi, dan fasilitas belum tersedia, sehingga layarnya tidak
/// dimasukkan ke shell demo.
Future<(AppServices, Stream<String>)> _createAppServices() async {
  final map = AgamMapConfig.internalDemo();
  final routing = FakeRoutingService();
  final la = await createLaServices(
    bundledOnly: true,
    map: map,
    navigation: (location) =>
        FakeNavigationController(location: location, routing: routing),
  );
  final trail = FakeTrailService(session: la.session);
  final facilities = FakeFacilityService();

  return (
    AppServices(
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
      search: PoiSearchService(pois: la.pois),
      recommendations: FakeRecommendationService(
        trail: trail,
        facilities: facilities,
      ),
      trail: trail,
      facilities: facilities,
    ),
    la.triggerResponder.viewRequests,
  );
}

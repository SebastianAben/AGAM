import '../contracts/app_services.dart';
import '../contracts/fakes/fake_la_services.dart';
import '../contracts/fakes/fake_lb_services.dart';
import 'device_location_services.dart';

/// Keeps unfinished services fake while using real device permission/location.
AppServices createDeviceAppServices() {
  final location = DeviceLocationService();
  final pois = FakePoiRepository();
  final session = FakeSessionController(location: location);
  final routing = FakeRoutingService();
  final trail = FakeTrailService(session: session);
  final facilities = FakeFacilityService();

  return AppServices(
    permissions: DevicePermissionService(),
    location: location,
    pois: pois,
    session: session,
    audio: FakeAudioService(),
    voice: FakeVoiceGuidance(),
    settings: FakeSettingsStore(),
    map: FakeMapConfig(),
    routing: routing,
    navigation: FakeNavigationController(location: location, routing: routing),
    search: FakeSearchService(),
    recommendations: FakeRecommendationService(
      trail: trail,
      facilities: facilities,
    ),
    trail: trail,
    facilities: facilities,
  );
}

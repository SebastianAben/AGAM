import 'fakes/fake_la_services.dart';
import 'fakes/fake_lb_services.dart';
import 'services/la_services.dart';
import 'services/lb_services.dart';

/// Kumpulan seluruh layanan yang dipakai UI.
///
/// UI hanya bergantung pada antarmuka di sini, sehingga implementasi palsu
/// dapat diganti implementasi asli tanpa mengubah layar. Penggantian
/// dilakukan di `lib/main.dart` saat integrasi akhir sprint.
class AppServices {
  const AppServices({
    required this.permissions,
    required this.location,
    required this.pois,
    required this.session,
    required this.audio,
    required this.voice,
    required this.settings,
    required this.map,
    required this.routing,
    required this.navigation,
    required this.search,
    required this.recommendations,
    required this.trail,
    required this.facilities,
  });

  /// Seluruh layanan palsu yang saling terhubung. [tick] mengatur kecepatan
  /// simulasi; perkecil untuk test.
  factory AppServices.fake({Duration tick = const Duration(seconds: 1)}) {
    final location = FakeLocationService(tick: tick);
    final session = FakeSessionController(location: location);
    final routing = FakeRoutingService();
    final trail = FakeTrailService(session: session);
    final facilities = FakeFacilityService();
    return AppServices(
      permissions: FakePermissionService(),
      location: location,
      pois: FakePoiRepository(),
      session: session,
      audio: FakeAudioService(tick: tick),
      voice: FakeVoiceGuidance(),
      settings: FakeSettingsStore(),
      map: FakeMapConfig(),
      routing: routing,
      navigation: FakeNavigationController(
        location: location,
        routing: routing,
      ),
      search: FakeSearchService(),
      recommendations: FakeRecommendationService(
        trail: trail,
        facilities: facilities,
      ),
      trail: trail,
      facilities: facilities,
    );
  }

  // Track LA
  final PermissionService permissions;
  final LocationService location;
  final PoiRepository pois;
  final SessionController session;
  final AudioService audio;
  final VoiceGuidance voice;
  final SettingsStore settings;

  // Track LB
  final MapConfig map;
  final RoutingService routing;
  final NavigationController navigation;
  final SearchService search;
  final RecommendationService recommendations;
  final TrailService trail;
  final FacilityService facilities;
}

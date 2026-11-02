import 'content.dart';
import 'geo.dart';

enum Maneuver {
  depart,
  straight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  arrive,
}

class RouteStep {
  const RouteStep({
    required this.maneuver,
    required this.instruction,
    required this.distanceM,
    required this.position,
  });

  final Maneuver maneuver;

  /// Teks arahan berbahasa Indonesia; dibacakan oleh `VoiceGuidance`.
  final String instruction;

  /// Jarak dari langkah ini ke langkah berikutnya.
  final double distanceM;

  /// Titik tempat manuver dilakukan.
  final GeoPoint position;
}

/// Rute jalan kaki. Dinamai `WalkingRoute` agar tidak bentrok dengan
/// `Route` milik Flutter.
class WalkingRoute {
  const WalkingRoute({
    required this.path,
    required this.distanceM,
    required this.eta,
    required this.steps,
  });

  final List<GeoPoint> path;
  final double distanceM;
  final Duration eta;
  final List<RouteStep> steps;
}

enum NavigationTargetKind { poi, facility }

class NavigationTarget {
  const NavigationTarget({
    required this.id,
    required this.name,
    required this.kind,
    required this.point,
    required this.isPlaceholderPoint,
  });

  factory NavigationTarget.poi(Poi poi) => NavigationTarget(
    id: poi.id,
    name: poi.name,
    kind: NavigationTargetKind.poi,
    point: poi.navigationPoint,
    isPlaceholderPoint: !poi.hasSurveyedEntrance,
  );

  factory NavigationTarget.facility(Facility facility) => NavigationTarget(
    id: facility.id,
    name: facility.name,
    kind: NavigationTargetKind.facility,
    point: facility.position,
    isPlaceholderPoint: false,
  );

  final String id;
  final String name;
  final NavigationTargetKind kind;
  final GeoPoint point;

  /// `true` jika [point] adalah titik tengah gedung, bukan pintu masuk hasil
  /// survei. Navigasi ke titik ini belum memenuhi F06.
  final bool isPlaceholderPoint;
}

enum NavigationStatus {
  idle,
  calculating,
  onRoute,
  offRoute,
  rerouting,
  arrived,

  /// Rute tidak dapat dihitung, mis. pengguna di luar area kampus.
  error,
}

class NavigationState {
  const NavigationState({
    required this.status,
    this.target,
    this.route,
    this.currentStepIndex,
    this.remainingDistanceM,
    this.remainingEta,
  });

  const NavigationState.idle()
    : status = NavigationStatus.idle,
      target = null,
      route = null,
      currentStepIndex = null,
      remainingDistanceM = null,
      remainingEta = null;

  final NavigationStatus status;
  final NavigationTarget? target;
  final WalkingRoute? route;
  final int? currentStepIndex;
  final double? remainingDistanceM;
  final Duration? remainingEta;

  RouteStep? get currentStep {
    final index = currentStepIndex;
    final steps = route?.steps;
    if (index == null || steps == null || index >= steps.length) return null;
    return steps[index];
  }
}

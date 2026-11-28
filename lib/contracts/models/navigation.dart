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
    this.candidates = const [],
    this.locationHint,
  });

  factory NavigationTarget.poi(Poi poi) => NavigationTarget(
    id: poi.id,
    name: poi.name,
    kind: NavigationTargetKind.poi,
    point: poi.navigationPoint,
    isPlaceholderPoint: !poi.hasSurveyedEntrance,
    candidates: List.unmodifiable([
      for (final entrance in poi.entrances) entrance.position,
    ]),
  );

  /// Membuat tujuan navigasi untuk sebuah [Facility].
  ///
  /// Bila [building] disediakan dan cocok dengan `facility.buildingId` serta
  /// memiliki titik akses (`entrances`), navigasi diarahkan ke titik akses
  /// gedung tersebut (sehingga tiba ≤15 m dari pintu masuk gedung, PRD §11)
  /// dan [isPlaceholderPoint] bernilai `true` karena letak persis di dalam
  /// gedung belum disurvei.
  factory NavigationTarget.facility(Facility facility, {Poi? building}) {
    final locationHint = _extractLocationHint(facility.description);
    if (building != null &&
        facility.buildingId != null &&
        building.id == facility.buildingId &&
        building.entrances.isNotEmpty) {
      return NavigationTarget(
        id: facility.id,
        name: facility.name,
        kind: NavigationTargetKind.facility,
        point: building.navigationPoint,
        isPlaceholderPoint: true,
        candidates: List.unmodifiable([
          for (final entrance in building.entrances) entrance.position,
        ]),
        locationHint: locationHint,
      );
    }
    final lowerDescription = facility.description.toLowerCase();
    final unverifiedPoint =
        (!facility.metadata.approved && !facility.metadata.isPlaceholder) ||
        lowerDescription.contains('belum diverifikasi') ||
        lowerDescription.contains('belum disurvei');
    return NavigationTarget(
      id: facility.id,
      name: facility.name,
      kind: NavigationTargetKind.facility,
      point: facility.position,
      isPlaceholderPoint: unverifiedPoint,
      locationHint: locationHint,
    );
  }

  static String? _extractLocationHint(String description) {
    var text = description.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    const technicalMarkers = [
      'titik peta memakai',
      'titik ditandai',
      'belum diverifikasi',
      'belum disurvei',
    ];
    var cutoff = text.length;
    for (final marker in technicalMarkers) {
      final found = lower.indexOf(marker);
      if (found != -1 && found < cutoff) cutoff = found;
    }
    text = text.substring(0, cutoff).trim();
    final sentenceEnd = text.indexOf('. ');
    if (sentenceEnd != -1) {
      text = text.substring(0, sentenceEnd).trim();
    }
    while (text.endsWith('.') || text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trim();
    }
    return text.isEmpty ? null : text;
  }

  final String id;
  final String name;
  final NavigationTargetKind kind;
  final GeoPoint point;

  /// `true` jika [point] adalah titik tengah gedung atau titik akses yang
  /// belum dicek di lapangan. Navigasi ke titik ini belum memenuhi F06.
  final bool isPlaceholderPoint;

  /// Titik akses yang boleh dituju. Kosong: navigasi ke [point].
  ///
  /// Bila berisi, navigasi menuju kandidat dengan jarak jalan kaki terpendek
  /// (dihitung ulang setiap reroute) dan pengguna dianggap tiba ≤15 m dari
  /// kandidat mana pun (PRD §11).
  final List<GeoPoint> candidates;

  /// Petunjuk lokasi singkat fasilitas di dalam/sekitar gedung, mis.
  /// "Labtek V, lantai 3" atau "Di dalam Oktagon".
  final String? locationHint;
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
    this.activeStep,
  });

  const NavigationState.idle()
    : status = NavigationStatus.idle,
      target = null,
      route = null,
      currentStepIndex = null,
      remainingDistanceM = null,
      remainingEta = null,
      activeStep = null;

  final NavigationStatus status;
  final NavigationTarget? target;
  final WalkingRoute? route;
  final int? currentStepIndex;
  final double? remainingDistanceM;
  final Duration? remainingEta;

  /// Langkah aktif yang ditampilkan di UI saat ruas lurus berlanjut setelah
  /// belokan selesai, tanpa mengubah [currentStepIndex].
  final RouteStep? activeStep;

  RouteStep? get currentStep {
    if (activeStep != null) return activeStep;
    final index = currentStepIndex;
    final steps = route?.steps;
    if (index == null || steps == null || index >= steps.length) return null;
    return steps[index];
  }
}

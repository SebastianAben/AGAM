import 'dart:async';

import 'package:agam/contracts/contracts.dart';

// Fixture sintetis, dipakai hanya untuk pengujian.
final syntheticPois = List.generate(10, (i) {
  final point = GeoPoint(-6.89, 107.608 + i * .0005);
  return Poi(
    id: 'synthetic-$i',
    name: 'POI Sintetis $i',
    aliases: [],
    category: PoiCategory.lecture,
    position: point,
    radiusM: 15,
    entrances: [
      PoiEntrance(position: point, label: 'Pintu sintetis', verified: true),
    ],
    description: '',
    function: '',
    facilities: [],
    trivia: '',
    media: const PoiMedia(),
    metadata: const ContentMetadata.placeholder(),
    trailOrder: i + 1,
  );
});

const syntheticGraph = '''
{"type":"FeatureCollection","features":[
{"type":"Feature","geometry":{"type":"LineString","coordinates":[[107.607,-6.89],[107.613,-6.89]]}}
]}
''';

class SyntheticLocation implements LocationService {
  final controller = StreamController<LocationFix>.broadcast();
  @override
  LocationFix? lastFix;
  @override
  Stream<LocationFix> get positions => controller.stream;

  void move(GeoPoint point, {double accuracy = 5}) {
    lastFix = LocationFix(
      position: point,
      accuracyM: accuracy,
      timestamp: DateTime(2026, 1, 2, 12),
    );
    controller.add(lastFix!);
  }
}

class SyntheticSession implements SessionController {
  final states = StreamController<SessionState>.broadcast();
  final events = StreamController<PoiTriggerEvent>.broadcast();
  @override
  SessionState current = const SessionState.idle();
  @override
  Stream<SessionState> get state => states.stream;
  @override
  Stream<PoiTriggerEvent> get triggers => events.stream;

  @override
  Future<void> start(SessionMode mode) async {
    current = SessionState(mode: mode);
    states.add(current);
  }

  @override
  Future<void> end() => start(SessionMode.none);

  void trigger(int index, {SessionMode mode = SessionMode.trail}) {
    events.add(
      PoiTriggerEvent(
        poiId: syntheticPois[index].id,
        mode: mode,
        triggeredAt: DateTime(2026, 1, 2, 12),
        response: TriggerResponse.full,
      ),
    );
  }

  Future<void> dispose() async {
    await states.close();
    await events.close();
  }
}

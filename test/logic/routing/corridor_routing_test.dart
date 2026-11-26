import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:agam/logic/routing/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';

// Selasar lantai 1 OSM (`highway=corridor`, assets/routing/corridors.geojson)
// ikut menjadi ruas lorong kandidat. Pengguna di tengah Labtek V tidak lagi
// diarahkan lewat garis lurus menembus gedung bila selasar yang dipetakan
// tersedia (keputusan pengguna 26 November 2026).
void main() {
  final corridors = jsonDecode(
    File('assets/routing/corridors.geojson').readAsStringSync(),
  );
  final graph = jsonDecode(
    File('assets/routing/ganesha-walk-demo.geojson').readAsStringSync(),
  );

  test('selasar OSM berasal dari way corridor dan menyentuh graf', () {
    final features = corridors['features'] as List;
    expect(features, isNotEmpty);
    String key(List<dynamic> c) => '${c[0]},${c[1]}';
    final nodes = {
      for (final feature in graph['features'])
        for (final c in feature['geometry']['coordinates']) key(c),
    };
    var touching = 0;
    for (final feature in features) {
      final properties = feature['properties'];
      expect(properties['source_id'], startsWith('way/'));
      expect(properties['kind'], 'corridor');
      // Belum ada yang dicek di lapangan (PRD §11).
      expect(properties['verified'], isFalse);
      final coordinates = feature['geometry']['coordinates'] as List;
      expect(coordinates.length, greaterThanOrEqualTo(2));
      if (coordinates.any((c) => nodes.contains(key(c)))) touching++;
    }
    // 28 of 35 ways share a vertex with the walk graph (counted with
    // tools/routing/export_osm_corridors.py output on 26 November 2026); the rest join
    // through other corridors or fall outside the main network.
    expect(touching, 28);
  });

  test('Labtek V tengah ke Labtek VII mengikuti selasar, bukan menembus '
      'gedung', () async {
    final routing = CampusRoutingService.fromGeoJson(
      jsonEncode(graph),
      passages: File('assets/routing/passages.geojson').readAsStringSync(),
      corridors: jsonEncode(corridors),
    );
    final pois = decodePoiDataset(
      jsonDecode(File('assets/data/pois.json').readAsStringSync()),
    ).pois;
    final labtekVII = pois.firstWhere((p) => p.name == 'Labtek VII');
    const from = GeoPoint(-6.8905811, 107.6097754);

    final route = await planWalkingRoute(
      routing: routing,
      from: from,
      target: NavigationTarget.poi(labtekVII),
      pois: pois,
    );

    // Independent oracle (tools/routing/check_corridor_route.py: own
    // haversine R = 6371008.8 m, segment projection, Dijkstra over walk +
    // passages + corridors): with the unmapped first leg counted twice the
    // choice is the 13.0 m snap onto the north corridor, 161.6 m in all.
    // The shortest total would be a 52.4 m straight line across the
    // building to "Titik akses sisi timur 2" (130.1 m), which is what the
    // weighting rules out.
    expect(offNetworkLegM(from, route), closeTo(13.0, .5));
    expect(route.distanceM, closeTo(161.6, 1.5));
    expect(route.distanceM, lessThan(253));
    // The corridors are unverified passages and say so.
    expect(
      route.steps.any((s) => s.instruction.contains('belum diverifikasi')),
      isTrue,
    );
  });

  test('bobot luar jaringan memilih jalur bila selisihnya kecil', () async {
    // SYNTHETIC equator geometry; 0.0001° ≈ 11.1195 m.
    // Path A: snap 11.1 m north onto an east–west path that reaches the
    // target after 66.7 m (total 77.8 m, cost 88.9 m).
    // Door: 33.4 m straight east to a door on a diagonal path 35.2 m
    // (√10 × 11.1195) from the target (total 68.5 m, cost 101.9 m). The
    // door is shorter but crosses more unmapped ground, so path A wins.
    const target = GeoPoint(.0001, .0006);
    const doorPoint = GeoPoint(0, .0003);
    final routing = CampusRoutingService.fromGeoJson(
      jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [0, .0001],
                [.0006, .0001],
              ],
            },
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [.0003, 0],
                [.0006, .0001],
              ],
            },
          },
        ],
      }),
    );
    const from = GeoPoint(0, 0);
    final poi = Poi(
      id: 'P-SYNTHETIC',
      name: 'SINTETIS',
      aliases: const [],
      category: PoiCategory.lecture,
      position: from,
      radiusM: 15,
      entrances: const [PoiEntrance(position: doorPoint, label: 'SINTETIS')],
      description: 'SINTETIS',
      function: 'SINTETIS',
      facilities: const [],
      trivia: 'SINTETIS',
      media: const PoiMedia(),
      metadata: const ContentMetadata.placeholder(),
    );
    final route = await planWalkingRoute(
      routing: routing,
      from: from,
      target: const NavigationTarget(
        id: 'synthetic',
        name: 'SINTETIS',
        kind: NavigationTargetKind.poi,
        point: target,
        isPlaceholderPoint: false,
      ),
      pois: [poi],
    );
    expect(route.path[1], const GeoPoint(.0001, 0));
    expect(route.distanceM, closeTo(77.8, .3));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Rute ke titik akses (PRD §11) memakai graf bawaan + lorong tembus gedung,
// dibaca dari aset yang sama dengan aplikasi.
void main() {
  final routing = CampusRoutingService.fromGeoJson(
    File('assets/routing/ganesha-walk-demo.geojson').readAsStringSync(),
    passages: File('assets/routing/passages.geojson').readAsStringSync(),
  );
  final data = jsonDecode(File('assets/data/pois.json').readAsStringSync());
  final entrances = [
    for (final poi in data['pois'])
      for (final entrance in poi['entrances'])
        (
          poi: poi['id'] as String,
          label: entrance['label'] as String,
          point: GeoPoint(entrance['lat'], entrance['lng']),
        ),
  ];
  final passages = [
    for (final feature in jsonDecode(
      File('assets/routing/passages.geojson').readAsStringSync(),
    )['features'])
      (
        poi: feature['properties']['poi'] as String,
        ends: [
          for (final c in feature['geometry']['coordinates'])
            GeoPoint(c[1], c[0]),
        ],
      ),
  ];
  ({String poi, String label, GeoPoint point}) entrance(
    String poi,
    String label,
  ) => entrances.firstWhere((e) => e.poi == poi && e.label == label);

  // Titik awal tetap: titik akses timur Oktagon, di tengah jaringan utama.
  final start = entrance('P08', 'Titik akses sisi timur').point;

  test('dataset memiliki 41 titik akses', () {
    expect(entrances, hasLength(41));
  });

  test('rute dari titik tetap mencapai setiap titik akses', () async {
    for (final target in entrances) {
      final route = await routing.route(from: start, to: target.point);
      final reason = '${target.poi} ${target.label}';
      expect(route.path.first, start, reason: reason);
      expect(route.path.last, target.point, reason: reason);
      expect(route.distanceM, lessThan(1500), reason: reason);
      expect(route.steps.last.maneuver, Maneuver.arrive, reason: reason);
    }
  });

  test(
    'titik akses barat laut Labtek V di selasar dicapai lewat lorong',
    () async {
      final target = entrance('P01', 'Titik akses sisi barat laut').point;
      final passage = passages.firstWhere((p) => p.poi == 'P01').ends;
      expect(passage, contains(target));
      final route = await routing.route(from: start, to: target);
      final path = route.path;
      final crossing = [
        for (var i = 1; i < path.length; i++)
          if ({path[i - 1], path[i]}.containsAll(passage)) i,
      ];
      expect(crossing, isNotEmpty);
      expect(
        route.steps.map((s) => s.instruction),
        contains(contains('lorong dalam gedung (belum diverifikasi)')),
      );
    },
  );

  test(
    'titik pertama Labtek VIII (ujung selasar) dicapai lewat lorong',
    () async {
      final target = entrance('P04', 'Titik akses sisi timur laut').point;
      final route = await routing.route(from: start, to: target);
      expect(route.path.last, target);
      expect(
        route.steps.where((s) => s.instruction.contains('belum diverifikasi')),
        hasLength(1),
      );
    },
  );
}

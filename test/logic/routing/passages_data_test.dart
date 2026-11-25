import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

// Lorong tembus gedung (PRD §11) menyambung selasar yang terputus ke jaringan
// jalan kaki. Routing menambahkannya sebagai ruas graf, jadi setiap ujungnya
// harus berupa simpul yang sudah ada di graf bawaan.
void main() {
  final graph = jsonDecode(
    File('assets/routing/ganesha-walk-demo.geojson').readAsStringSync(),
  );
  final passages = jsonDecode(
    File('assets/routing/passages.geojson').readAsStringSync(),
  );
  final pois = {
    for (final poi in jsonDecode(
      File('assets/data/pois.json').readAsStringSync(),
    )['pois'])
      poi['id'] as String: GeoPoint(poi['lat'], poi['lng']),
  };
  String key(List<dynamic> c) =>
      '${(c[0] as num).toStringAsFixed(7)},${(c[1] as num).toStringAsFixed(7)}';
  final nodes = {
    for (final feature in graph['features'])
      for (final c in feature['geometry']['coordinates']) key(c),
  };

  test('setiap lorong menghubungkan dua simpul graf milik gedung POI', () {
    final features = passages['features'] as List;
    expect(features, isNotEmpty);
    final ids = <String>{};
    for (final feature in features) {
      final properties = feature['properties'];
      final id = properties['id'] as String;
      expect(ids.add(id), isTrue, reason: 'id ganda $id');
      expect(pois, contains(properties['poi']), reason: id);
      expect(properties['label'], startsWith('Lorong'), reason: id);
      expect(properties['verified'], isA<bool>(), reason: id);

      final coordinates = feature['geometry']['coordinates'] as List;
      expect(coordinates, hasLength(2), reason: id);
      for (final c in coordinates) {
        expect(nodes, contains(key(c)), reason: '$id ${key(c)}');
      }
      final a = GeoPoint(coordinates[0][1], coordinates[0][0]);
      final b = GeoPoint(coordinates[1][1], coordinates[1][0]);
      // Panjang tercatat sama dengan jarak ujung; lorong pendek dan lurus.
      expect(a.distanceTo(b), closeTo(properties['lengthM'], 1), reason: id);
      expect(a.distanceTo(b), inInclusiveRange(5, 60), reason: id);
      // Lorong berada di gedungnya sendiri, bukan di seberang kampus.
      expect(pois[properties['poi']]!.distanceTo(a), lessThan(110), reason: id);
    }
  });
}

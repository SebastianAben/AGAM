import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/map/agam_map_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // SINTETIS — kotak di dekat ekuator, bukan batas layanan Ganesha.
  const syntheticArea = CampusArea(
    polygon: [GeoPoint(0, 0), GeoPoint(0, 2), GeoPoint(2, 2), GeoPoint(2, 0)],
  );

  test(
    'area TBD tidak memakai coverage tile atau fake sebagai area layanan',
    () {
      final config = AgamMapConfig.pendingServiceArea();
      expect(config.hasServiceArea, isFalse);
      expect(config.campusArea.polygon, isEmpty);
      expect(config.isInsideCampus(config.initialCenter), isFalse);
      expect(config.isInsideCampus(const GeoPoint(1, 1)), isFalse);
      expect(AgamMapConfig.pendingAreaMessage, contains('PLACEHOLDER'));
      expect(
        AgamMapConfig.outsideAreaMessage,
        'Anda berada di luar area Kampus Ganesha',
      );
    },
  );

  test('pusat kamera sama dengan P08 dataset PRD, bukan pintu masuk', () {
    final dataset = jsonDecode(
      File('assets/data/pois.json').readAsStringSync(),
    );
    final pois = dataset['pois'] as List;
    final p08 = pois.singleWhere((poi) => poi['id'] == 'P08');
    expect(
      AgamMapConfig.pendingServiceArea().initialCenter,
      GeoPoint((p08['lat'] as num).toDouble(), (p08['lng'] as num).toDouble()),
    );
  });

  test(
    'demo berpusat pada Labtek V dan memakai coverage engineering berlabel',
    () {
      final dataset = jsonDecode(
        File('assets/data/pois.json').readAsStringSync(),
      );
      final pois = dataset['pois'] as List;
      final p01 = pois.singleWhere((poi) => poi['id'] == 'P01');
      final demo = AgamMapConfig.internalDemo();
      expect(demo.initialCenter, GeoPoint(p01['lat'], p01['lng']));
      expect(demo.serviceAreaSource, startsWith('DEMO INTERNAL'));
      for (final poi in pois) {
        expect(demo.isInsideCampus(GeoPoint(poi['lat'], poi['lng'])), isTrue);
      }
      expect(demo.isInsideCampus(const GeoPoint(0, 0)), isFalse);
    },
  );

  test('area eksplisit membedakan dalam/luar dan menolak posisi invalid', () {
    final config = AgamMapConfig.withServiceArea(
      area: syntheticArea,
      source: 'SINTETIS — hanya unit test',
    );
    expect(config.isInsideCampus(const GeoPoint(1, 1)), isTrue);
    for (final point in [
      const GeoPoint(-1, 1),
      const GeoPoint(3, 1),
      const GeoPoint(1, -1),
      const GeoPoint(1, 3),
      const GeoPoint(double.nan, 1),
      const GeoPoint(1, double.infinity),
      const GeoPoint(91, 1),
      const GeoPoint(1, 181),
    ]) {
      expect(config.isInsideCampus(point), isFalse, reason: '$point');
    }
    expect(() => config.campusArea.polygon.clear(), throwsUnsupportedError);
  });

  test('geometri kosong, titik invalid, dan sumber kosong ditolak', () {
    for (final area in [
      const CampusArea(polygon: []),
      const CampusArea(
        polygon: [GeoPoint(0, 0), GeoPoint(0, 0), GeoPoint(1, 1)],
      ),
      const CampusArea(
        polygon: [GeoPoint(91, 0), GeoPoint(0, 1), GeoPoint(1, 0)],
      ),
    ]) {
      expect(
        () => AgamMapConfig.withServiceArea(area: area, source: 'SINTETIS'),
        throwsArgumentError,
      );
    }
    expect(
      () => AgamMapConfig.withServiceArea(area: syntheticArea, source: ' '),
      throwsArgumentError,
    );
  });

  test('aset nyata tersedia; kandidat style tidak meminta tile/glyph/sprite remote', () {
    final source = AgamMapConfig.pendingServiceArea().style;
    expect(source.isPlaceholder, isFalse);
    final manifest = jsonDecode(
      File('assets/map/ganesha.manifest.json').readAsStringSync(),
    );
    expect(
      File(source.tilesAssetPath).lengthSync(),
      manifest['output']['sizeBytes'],
    );
    expect(File(source.tilesAssetPath).readAsBytesSync()[96], 1);
    final style = jsonDecode(File(source.styleAssetPath).readAsStringSync());
    expect(
      style['metadata']['agam:status'],
      'integrated_memory_renderer_pending_device_test',
    );
    expect(style['sources']['openmaptiles']['tiles'], isEmpty);
    expect(style.containsKey('glyphs'), isFalse);
    expect(style.containsKey('sprite'), isFalse);
    final credits = style['metadata']['agam:attribution'] as List;
    expect(
      credits.map((credit) => credit['url']),
      containsAll([
        'https://www.openstreetmap.org/copyright',
        'https://openmaptiles.org/',
      ]),
    );
    expect(source.attribution, contains('OpenStreetMap'));
    expect(source.attribution, contains('OpenMapTiles'));
  });
}

import 'package:agam/contracts/contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoPoint.distanceTo', () {
    // Nilai acuan dihitung terpisah dengan Python (rumus haversine, R = 6371 km).
    test('Oktagon ke TVST ±49,39 m', () {
      const oktagon = GeoPoint(-6.8890603, 107.6100470);
      const tvst = GeoPoint(-6.8895043, 107.6100594);
      expect(oktagon.distanceTo(tvst), closeTo(49.3895, 0.01));
    });

    test('Labtek V ke Labtek VI ±49,94 m', () {
      const labtek5 = GeoPoint(-6.8905811, 107.6097754);
      const labtek6 = GeoPoint(-6.8901358, 107.6097167);
      expect(labtek5.distanceTo(labtek6), closeTo(49.9373, 0.01));
    });

    test('GKUB ke GKUT ±342,47 m', () {
      const gkub = GeoPoint(-6.89053, 107.60890);
      const gkut = GeoPoint(-6.8903881, 107.6119990);
      expect(gkub.distanceTo(gkut), closeTo(342.4679, 0.01));
    });
  });

  test('CampusArea.contains membedakan titik di dalam dan di luar', () {
    const area = CampusArea(
      polygon: [
        GeoPoint(-6.892, 107.607),
        GeoPoint(-6.892, 107.614),
        GeoPoint(-6.887, 107.614),
        GeoPoint(-6.887, 107.607),
      ],
    );
    expect(area.contains(const GeoPoint(-6.890, 107.610)), isTrue);
    expect(area.contains(const GeoPoint(-6.900, 107.610)), isFalse);
  });

  test('TrailProgress menghitung kunjungan di luar urutan', () {
    const progress = TrailProgress(
      order: ['P01', 'P02', 'P03'],
      visited: {'P02'},
      active: true,
    );
    expect(progress.visitedCount, 1);
    expect(progress.nextPoiId, 'P01');
    expect(progress.isComplete, isFalse);
  });
}

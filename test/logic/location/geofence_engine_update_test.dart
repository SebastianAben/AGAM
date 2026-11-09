import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/geofence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

// SINTETIS. Menguji suspend() dan updatePois() yang dibutuhkan integrasi
// sesi (PB06): dataset diperbarui tanpa kehilangan cooldown.
void main() {
  List<GeofenceEntry> run(
    GeofenceEngine engine,
    double from,
    double to, {
    double metersNorth = 5,
  }) {
    final entries = <GeofenceEntry>[];
    for (var t = from; t <= to; t++) {
      entries.addAll(
        engine.evaluate(
          syntheticFix(t, metersNorth: metersNorth),
          enabled: true,
        ),
      );
    }
    return entries;
  }

  test('updatePois mempertahankan cooldown POI yang sama', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    expect(run(engine, 0, 5), hasLength(1));
    // Keluar, dataset diperbarui, lalu masuk lagi dalam masa cooldown.
    run(engine, 6, 7, metersNorth: 100);
    engine.updatePois([syntheticPoi(radius: 20)]);
    expect(run(engine, 8, 300), isEmpty);
    // Setelah cooldown 10 menit sejak detik 5, trigger berikutnya muncul.
    expect(run(engine, 301, 610), hasLength(1));
  });

  test('updatePois dengan geometri sama mempertahankan dwell', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    expect(run(engine, 0, 3), isEmpty);
    engine.updatePois([syntheticPoi()]);
    expect(run(engine, 4, 5), hasLength(1));
  });

  test('updatePois dengan geometri berubah memulai dwell dari awal', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    expect(run(engine, 0, 3), isEmpty);
    engine.updatePois([syntheticPoi(radius: 16)]);
    expect(run(engine, 4, 8), isEmpty);
    expect(run(engine, 9, 9), hasLength(1));
  });

  test('POI baru dapat terpicu dan POI yang dihapus dilupakan', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    engine.updatePois([syntheticPoi(id: 'synthetic-b')]);
    final entries = run(engine, 0, 5);
    expect(entries.single.poiId, 'synthetic-b');
  });

  test('updatePois invalid ditolak dan snapshot lama tetap dipakai', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    expect(
      () => engine.updatePois([syntheticPoi(), syntheticPoi()]),
      throwsArgumentError,
    );
    expect(
      () => engine.updatePois([syntheticPoi(radius: 0)]),
      throwsArgumentError,
    );
    expect(run(engine, 0, 5).single.poiId, 'synthetic-a');
  });

  test('suspend membatalkan dwell tetapi mempertahankan cooldown', () {
    final engine = GeofenceEngine(pois: [syntheticPoi()]);
    expect(run(engine, 0, 3), isEmpty);
    engine.suspend();
    expect(run(engine, 4, 8), isEmpty);
    expect(run(engine, 9, 9), hasLength(1));

    engine.suspend();
    // Pengunci kunjungan dibersihkan, cooldown tetap menahan trigger.
    expect(run(engine, 10, 300), isEmpty);
  });

  test('suspend setara evaluate(enabled: false)', () {
    final a = GeofenceEngine(pois: [syntheticPoi()]);
    final b = GeofenceEngine(pois: [syntheticPoi()]);
    run(a, 0, 3);
    run(b, 0, 3);
    a.suspend();
    b.evaluate(
      LocationFix(
        position: const GeoPoint(0, 0),
        accuracyM: 5,
        timestamp: syntheticEpoch,
      ),
      enabled: false,
    );
    expect(run(a, 4, 9).length, run(b, 4, 9).length);
  });
}

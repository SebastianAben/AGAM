import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/location/geofence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS — bukan data kampus. Semua waktu bergerak tanpa timer/delay.
final _epoch = DateTime.utc(2026, 1, 1);

Poi _poi({
  String id = 'synthetic-a',
  double radius = 15,
  GeoPoint position = const GeoPoint(0, 0),
  List<PoiEntrance> entrances = const [],
}) => Poi(
  id: id,
  name: 'SINTETIS',
  aliases: const [],
  category: PoiCategory.lecture,
  position: position,
  radiusM: radius,
  entrances: entrances,
  description: 'SINTETIS',
  function: 'SINTETIS',
  facilities: const [],
  trivia: 'SINTETIS',
  media: const PoiMedia(),
  metadata: const ContentMetadata.placeholder(),
);

LocationFix _fix(
  int milliseconds, {
  double accuracy = 5,
  GeoPoint position = const GeoPoint(0, 0),
}) => LocationFix(
  position: position,
  accuracyM: accuracy,
  timestamp: _epoch.add(Duration(milliseconds: milliseconds)),
);

class _Harness {
  _Harness({double radius = 15}) {
    engine = GeofenceEngine(
      pois: [_poi(radius: radius)],
      distanceCalculator: (_, _) {
        calls++;
        return distance;
      },
    );
  }

  late final GeofenceEngine engine;
  double distance = 14;
  int calls = 0;

  List<GeofenceEntry> sample(int ms, {bool enabled = true}) =>
      engine.evaluate(_fix(ms), enabled: enabled);

  void trigger() {
    expect(sample(0), isEmpty);
    expect(sample(5000), hasLength(1));
  }
}

void main() {
  test('trial resets cooldown but never repeats while remaining inside', () {
    final h = _Harness();
    h.trigger();
    h.engine.setTrialMode(true);
    expect(h.sample(10000), isEmpty);
    expect(h.sample(700000), isEmpty); // Still inside, even after 10 minutes.
    h.distance = 26;
    expect(h.sample(701000), isEmpty);
    h.distance = 14;
    expect(h.sample(702000), isEmpty);
    expect(h.sample(707000), hasLength(1));
    h.distance = 26;
    h.sample(708000);
    h.distance = 14;
    expect(h.sample(709000), isEmpty);
    expect(h.sample(714000), hasLength(1)); // No 10-minute wait in trial.
    h.engine.setTrialMode(false);
    h.distance = 26;
    h.sample(715000);
    h.distance = 14;
    h.sample(716000);
    expect(h.sample(721000), isEmpty); // Normal cooldown is restored.
  });

  group('dwell dan radius', () {
    test(
      '5 m contact disk keeps data radius 15 m and accepts approach at 18 m',
      () {
        final poi = _poi();
        expect(poi.radiusM, 15);
        final h = _Harness()..distance = 18;
        expect(h.sample(0), isEmpty);
        expect(h.sample(5000), hasLength(1));
        h.distance = 25;
        h.sample(605000);
        expect(h.engine.activePoiIds, contains(poi.id));
        h.distance = 25.001;
        h.sample(606000);
        expect(h.engine.activePoiIds, isEmpty);
      },
    );

    test('beyond contact edge plus approach radius never triggers', () {
      final h = _Harness()..distance = 20.001;
      expect(h.sample(0), isEmpty);
      expect(h.sample(5000), isEmpty);
    });

    test('tepat radius dan dwell; entry memakai timestamp input', () {
      final h = _Harness()..distance = 20;
      expect(h.sample(0), isEmpty);
      expect(h.sample(4999), isEmpty);
      final entry = h.sample(5000).single;
      expect(entry.poiId, 'synthetic-a');
      expect(entry.triggeredAt, _epoch.add(const Duration(seconds: 5)));
    });

    test('keluar radius sebelum trigger membatalkan dwell', () {
      final h = _Harness();
      h.sample(0);
      h.distance = 20.001;
      expect(h.sample(4000), isEmpty);
      h.distance = 20;
      expect(h.sample(5000), isEmpty);
      expect(h.sample(10000), hasLength(1));
    });

    test('jeda tepat 10 detik diterima, lebih lama memulai ulang', () {
      final exact = _Harness();
      exact.sample(0);
      expect(exact.sample(10000), hasLength(1));
      final gap = _Harness();
      gap.sample(0);
      expect(gap.sample(11000), isEmpty);
      expect(gap.sample(15999), isEmpty);
      expect(gap.sample(16000), hasLength(1));
    });

    test('jeda maksimum custom dipakai', () {
      final engine = GeofenceEngine(
        pois: [_poi()],
        maxSampleGap: const Duration(seconds: 2),
        distanceCalculator: (_, _) => 0,
      );
      engine.evaluate(_fix(0), enabled: true);
      expect(engine.evaluate(_fix(5000), enabled: true), isEmpty);
      for (final ms in [7000, 9000]) {
        expect(engine.evaluate(_fix(ms), enabled: true), isEmpty);
      }
      expect(engine.evaluate(_fix(10000), enabled: true), hasLength(1));
    });
  });

  group('kualitas input', () {
    test('akurasi tepat 20 m diterima', () {
      final h = _Harness();
      h.engine.evaluate(_fix(0, accuracy: 20), enabled: true);
      expect(
        h.engine.evaluate(_fix(5000, accuracy: 20), enabled: true),
        hasLength(1),
      );
    });

    for (final accuracy in [20.001, -1.0, double.nan, double.infinity]) {
      test('akurasi $accuracy membatalkan dwell tanpa hitung jarak', () {
        final h = _Harness();
        h.sample(0);
        expect(
          h.engine.evaluate(_fix(4000, accuracy: accuracy), enabled: true),
          isEmpty,
        );
        expect(h.calls, 1);
        expect(h.sample(5000), isEmpty);
        expect(h.sample(10000), hasLength(1));
      });
    }

    for (final position in [
      const GeoPoint(90.001, 0),
      const GeoPoint(-90.001, 0),
      const GeoPoint(0, 180.001),
      const GeoPoint(0, -180.001),
      const GeoPoint(double.nan, 0),
      const GeoPoint(0, double.infinity),
    ]) {
      test('posisi invalid $position membatalkan dwell', () {
        final h = _Harness();
        h.sample(0);
        expect(
          h.engine.evaluate(_fix(4000, position: position), enabled: true),
          isEmpty,
        );
        expect(h.calls, 1);
        expect(h.sample(5000), isEmpty);
        expect(h.sample(10000), hasLength(1));
      });
    }

    for (final distance in [-1.0, double.nan, double.infinity]) {
      test('jarak calculator $distance membatalkan kandidat', () {
        final h = _Harness();
        h.sample(0);
        h.distance = distance;
        expect(h.sample(4000), isEmpty);
        h.distance = 14;
        expect(h.sample(5000), isEmpty);
        expect(h.sample(10000), hasLength(1));
      });
    }

    test('pembacaan buruk tidak melepaskan pengunci atau cooldown', () {
      final h = _Harness();
      h.trigger();
      h.distance = 100;
      expect(
        h.engine.evaluate(_fix(6000, accuracy: 21), enabled: true),
        isEmpty,
      );
      h.distance = 14;
      expect(h.sample(700000), isEmpty);
      h.distance = double.nan;
      expect(h.sample(701000), isEmpty);
      h.distance = 14;
      expect(h.sample(710000), isEmpty);
      expect(h.sample(715000), isEmpty);
    });

    test('input buruk tetap memperbarui urutan waktu global', () {
      final h = _Harness();
      h.engine.evaluate(_fix(10000, accuracy: 21), enabled: true);
      expect(h.sample(5000), isEmpty);
      expect(h.calls, 0);
      expect(h.sample(11000), isEmpty);
      expect(h.sample(16000), hasLength(1));
    });

    test('jarak invalid hanya membatalkan kandidat POI terkait', () {
      var invalid = false;
      final engine = GeofenceEngine(
        pois: [
          _poi(),
          _poi(id: 'synthetic-b', position: const GeoPoint(0, 1)),
        ],
        distanceCalculator: (_, to) => invalid && to.lng == 0 ? double.nan : 14,
      );
      engine.evaluate(_fix(0), enabled: true);
      invalid = true;
      engine.evaluate(_fix(4000), enabled: true);
      invalid = false;
      expect(
        engine.evaluate(_fix(5000), enabled: true).single.poiId,
        'synthetic-b',
      );
      expect(
        engine.evaluate(_fix(10000), enabled: true).single.poiId,
        'synthetic-a',
      );
    });
  });

  group('pengunci kunjungan dan cooldown', () {
    test('tetap di area tidak mengulang meskipun lewat cooldown', () {
      final h = _Harness();
      h.trigger();
      expect(h.sample(605000), isEmpty);
      h.distance = 25;
      expect(h.sample(606000), isEmpty);
      h.distance = 14;
      expect(h.sample(607000), isEmpty);
      expect(h.sample(612000), isEmpty);
    });

    test('keluar >25 m lalu dwell; cooldown tepat batas diterima', () {
      final h = _Harness();
      h.trigger();
      h.distance = 25.001;
      expect(h.sample(590000), isEmpty);
      h.distance = 14;
      expect(h.sample(595000), isEmpty);
      expect(h.sample(600000), isEmpty);
      expect(h.sample(604999), isEmpty);
      expect(h.sample(605000), hasLength(1));
      expect(h.sample(610000), isEmpty);
    });

    test('margin custom nol melepaskan setelah radius', () {
      var distance = 20.0;
      final engine = GeofenceEngine(
        pois: [_poi()],
        hysteresisMarginM: 0,
        distanceCalculator: (_, _) => distance,
      );
      engine.evaluate(_fix(0), enabled: true);
      expect(engine.evaluate(_fix(5000), enabled: true), hasLength(1));
      distance = 20.001;
      expect(engine.evaluate(_fix(6000), enabled: true), isEmpty);
      distance = 20;
      expect(engine.evaluate(_fix(605000), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(610000), enabled: true), hasLength(1));
    });

    test('cooldown terpisah untuk setiap POI', () {
      final distances = <double>[14, 30];
      final engine = GeofenceEngine(
        pois: [
          _poi(),
          _poi(id: 'synthetic-b', position: const GeoPoint(0, 1)),
        ],
        distanceCalculator: (_, to) => distances[to.lng.toInt()],
      );
      engine.evaluate(_fix(0), enabled: true);
      expect(
        engine.evaluate(_fix(5000), enabled: true).single.poiId,
        'synthetic-a',
      );
      distances[1] = 14;
      engine.evaluate(_fix(6000), enabled: true);
      expect(
        engine.evaluate(_fix(11000), enabled: true).single.poiId,
        'synthetic-b',
      );
    });
  });

  group('aktivasi dan timestamp', () {
    test('nonaktif tidak menghitung jarak atau memperbarui timestamp', () {
      final h = _Harness();
      expect(h.sample(1000000, enabled: false), isEmpty);
      expect(h.sample(2000000, enabled: false), isEmpty);
      expect(h.calls, 0);
      expect(h.sample(0), isEmpty);
      expect(h.sample(5000), hasLength(1));
    });

    test('nonaktif membatalkan dwell', () {
      final h = _Harness();
      h.sample(0);
      h.sample(4000, enabled: false);
      expect(h.sample(5000), isEmpty);
      expect(h.sample(10000), hasLength(1));
    });

    test('nonaktif diproses sebelum pemeriksaan timestamp', () {
      final h = _Harness();
      h.sample(0);
      h.sample(-1000, enabled: false);
      expect(h.sample(5000), isEmpty);
      expect(h.sample(10000), hasLength(1));
    });

    test('nonaktif melepas pengunci tetapi mempertahankan cooldown', () {
      final h = _Harness();
      h.trigger();
      h.sample(6000, enabled: false);
      expect(h.sample(595000), isEmpty);
      expect(h.sample(600000), isEmpty);
      expect(h.sample(605000), hasLength(1));
    });

    for (final ms in [0, -1000]) {
      test('timestamp $ms duplikat/mundur tidak membatalkan kandidat', () {
        final h = _Harness();
        h.sample(0);
        h.distance = 100;
        expect(h.sample(ms), isEmpty);
        expect(h.calls, 1);
        h.distance = 14;
        expect(h.sample(5000), hasLength(1));
      });
    }
  });

  group('dataset dan konfigurasi', () {
    test('dua entry terurut dan radius per POI dipakai', () {
      final engine = GeofenceEngine(
        pois: [
          _poi(id: 'synthetic-b', radius: 8),
          _poi(radius: 20),
        ],
        distanceCalculator: (_, _) => 14,
      );
      engine.evaluate(_fix(0), enabled: true);
      expect(engine.evaluate(_fix(5000), enabled: true).map((e) => e.poiId), [
        'synthetic-a',
      ]);
      final both = GeofenceEngine(
        pois: [
          _poi(id: 'synthetic-b'),
          _poi(),
        ],
        distanceCalculator: (_, _) => 14,
      );
      both.evaluate(_fix(0), enabled: true);
      expect(both.evaluate(_fix(5000), enabled: true).map((e) => e.poiId), [
        'synthetic-b',
        'synthetic-a',
      ]);
    });

    test('snapshot tidak berubah ketika koleksi asal berubah', () {
      final pois = [_poi()];
      final engine = GeofenceEngine(
        pois: pois,
        distanceCalculator: (_, _) => 14,
      );
      pois.clear();
      pois.add(_poi(id: 'synthetic-replacement', radius: 1));
      engine.evaluate(_fix(0), enabled: true);
      expect(
        engine.evaluate(_fix(5000), enabled: true).single.poiId,
        'synthetic-a',
      );
    });

    test('dataset kosong tidak memanggil calculator', () {
      final engine = GeofenceEngine(
        pois: [],
        distanceCalculator: (_, _) => throw StateError('Tidak boleh dipanggil'),
      );
      expect(engine.evaluate(_fix(0), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(5000), enabled: true), isEmpty);
    });

    test('ID kosong, whitespace, dan duplikat ditolak', () {
      for (final id in ['', '  ']) {
        expect(() => GeofenceEngine(pois: [_poi(id: id)]), throwsArgumentError);
      }
      expect(() => GeofenceEngine(pois: [_poi(), _poi()]), throwsArgumentError);
    });

    for (final radius in [0.0, -1.0, double.nan, double.infinity]) {
      test('radius $radius ditolak', () {
        expect(
          () => GeofenceEngine(pois: [_poi(radius: radius)]),
          throwsArgumentError,
        );
      });
    }
    for (final margin in [-1.0, double.nan, double.infinity]) {
      test('margin $margin ditolak', () {
        expect(
          () => GeofenceEngine(pois: [], hysteresisMarginM: margin),
          throwsArgumentError,
        );
      });
    }
    for (final gap in [Duration.zero, const Duration(microseconds: -1)]) {
      test('gap $gap ditolak', () {
        expect(
          () => GeofenceEngine(pois: [], maxSampleGap: gap),
          throwsArgumentError,
        );
      });
    }
    test('posisi POI invalid ditolak; batas WGS84 diterima', () {
      for (final position in [
        const GeoPoint(91, 0),
        const GeoPoint(0, -181),
        const GeoPoint(double.nan, 0),
        const GeoPoint(0, double.infinity),
      ]) {
        expect(
          () => GeofenceEngine(pois: [_poi(position: position)]),
          throwsArgumentError,
        );
      }
      expect(
        () => GeofenceEngine(pois: [_poi(position: const GeoPoint(-90, 180))]),
        returnsNormally,
      );
    });
  });

  test('haversine default memakai jarak acuan independen existing', () {
    // Titik referensi PRD existing, bukan koordinat kampus baru.
    // POI test tetap SINTETIS. Acuan test kontrak: Oktagon–TVST 49,3895 m
    // (Python independen, R=6371 km), sehingga berada di antara radius efektif 44+5 dan 45+5 m.
    const oktagon = GeoPoint(-6.8890603, 107.6100470);
    const tvst = GeoPoint(-6.8895043, 107.6100594);
    final engine = GeofenceEngine(
      pois: [
        _poi(id: 'synthetic-49', radius: 44, position: oktagon),
        _poi(id: 'synthetic-50', radius: 45, position: oktagon),
      ],
    );
    expect(engine.evaluate(_fix(0, position: tvst), enabled: true), isEmpty);
    expect(
      engine
          .evaluate(_fix(5000, position: tvst), enabled: true)
          .map((e) => e.poiId),
      ['synthetic-50'],
    );
  });

  group('titik akses (entrances)', () {
    test('masuk <=10 m dari titik akses dengan dwell 5 detik memicu POI '
        'meski jauh dari pusat', () {
      const center = GeoPoint(0, 0);
      const entrance = GeoPoint(0, 1);
      var centerDistance = 45.0;
      var entranceDistance = 10.001;
      final engine = GeofenceEngine(
        pois: [
          _poi(
            position: center,
            entrances: const [
              PoiEntrance(position: entrance, label: 'Pintu SINTETIS'),
            ],
          ),
        ],
        distanceCalculator: (_, to) =>
            to == center ? centerDistance : entranceDistance,
      );

      // Di luar 10 m dari pintu dan di luar 20 m dari pusat -> tidak memicu.
      expect(engine.evaluate(_fix(0), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(5000), enabled: true), isEmpty);

      // Tepat 10 m dari pintu -> mulai dwell dan memicu setelah 5 detik.
      entranceDistance = 10.0;
      expect(engine.evaluate(_fix(6000), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(10999), enabled: true), isEmpty);
      final entry = engine.evaluate(_fix(11000), enabled: true).single;
      expect(entry.poiId, 'synthetic-a');
      expect(engine.activePoiIds, {'synthetic-a'});
    });

    test('histeresis titik akses menahan kunci hingga >15 m dari semua pintu '
        'dan >25 m dari pusat', () {
      const center = GeoPoint(0, 0);
      const entranceA = GeoPoint(0, 1);
      const entranceB = GeoPoint(0, 2);
      var dCenter = 45.0;
      var dEntranceA = 8.0;
      var dEntranceB = 30.0;
      final engine = GeofenceEngine(
        pois: [
          _poi(
            position: center,
            entrances: const [
              PoiEntrance(position: entranceA, label: 'Pintu A'),
              PoiEntrance(position: entranceB, label: 'Pintu B'),
            ],
          ),
        ],
        distanceCalculator: (_, to) {
          if (to == center) return dCenter;
          if (to == entranceA) return dEntranceA;
          return dEntranceB;
        },
      );

      expect(engine.evaluate(_fix(0), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(5000), enabled: true), hasLength(1));

      // Tepat di batas histeresis pintu (15 m) tetap terkunci.
      dEntranceA = 15.0;
      engine.evaluate(_fix(6000), enabled: true);
      expect(engine.activePoiIds, {'synthetic-a'});

      // Keluar dari pintu A (>15 m), tetapi masih di dalam histeresis pintu B.
      dEntranceA = 20.0;
      dEntranceB = 14.0;
      engine.evaluate(_fix(7000), enabled: true);
      expect(engine.activePoiIds, {'synthetic-a'});

      // Keluar dari kedua pintu (>15 m), tetapi masih di dalam histeresis pusat.
      dEntranceB = 16.0;
      dCenter = 25.0;
      engine.evaluate(_fix(8000), enabled: true);
      expect(engine.activePoiIds, {'synthetic-a'});

      // Keluar dari pusat (>25 m) dan semua pintu (>15 m) -> keluar.
      dCenter = 25.001;
      engine.evaluate(_fix(9000), enabled: true);
      expect(engine.activePoiIds, isEmpty);
    });

    test(
      'dua titik akses berjarak ~20 m tidak tumpang tindih dengan haversine',
      () {
        // SINTETIS — jarak haversine independen di khatulistiwa:
        // 1e-4 deg lat = 6371000 * pi / 180 * 1e-4 = 11.11949 m.
        // Pintu A di (0, 0), Pintu B di (0.00018, 0) => jarak = 20.0151 m.
        const entranceA = GeoPoint(0, 0);
        const entranceB = GeoPoint(0.00018, 0);
        final engine = GeofenceEngine(
          pois: [
            _poi(
              id: 'synthetic-a',
              position: const GeoPoint(-0.0005, 0),
              entrances: const [
                PoiEntrance(position: entranceA, label: 'Pintu A'),
              ],
            ),
            _poi(
              id: 'synthetic-b',
              position: const GeoPoint(0.0007, 0),
              entrances: const [
                PoiEntrance(position: entranceB, label: 'Pintu B'),
              ],
            ),
          ],
        );

        // Titik tengah (~10.0075 m dari kedua pintu) -> tidak masuk keduanya.
        const midpoint = GeoPoint(0.00009, 0);
        expect(
          engine.evaluate(_fix(0, position: midpoint), enabled: true),
          isEmpty,
        );
        expect(
          engine.evaluate(_fix(5000, position: midpoint), enabled: true),
          isEmpty,
        );

        // ~5.0 m utara Pintu A (~15.01 m selatan Pintu B) -> hanya memicu A.
        const nearA = GeoPoint(0.000045, 0);
        expect(
          engine.evaluate(_fix(6000, position: nearA), enabled: true),
          isEmpty,
        );
        final entryA = engine.evaluate(
          _fix(11000, position: nearA),
          enabled: true,
        );
        expect(entryA.map((e) => e.poiId), ['synthetic-a']);

        // ~5.0 m selatan Pintu B (~15.01 m utara Pintu A) -> keluar A dan memicu B.
        const nearB = GeoPoint(0.000135, 0);
        expect(
          engine.evaluate(_fix(12000, position: nearB), enabled: true),
          isEmpty,
        );
        expect(engine.activePoiIds, isEmpty);
        final entryB = engine.evaluate(
          _fix(17000, position: nearB),
          enabled: true,
        );
        expect(entryB.map((e) => e.poiId), ['synthetic-b']);
      },
    );

    test('validasi entranceRadiusM dan koordinat titik akses', () {
      for (final radius in [-1.0, double.nan, double.infinity]) {
        expect(
          () => GeofenceEngine(pois: [], entranceRadiusM: radius),
          throwsArgumentError,
        );
      }
      expect(
        () => GeofenceEngine(pois: [], entranceRadiusM: 0),
        returnsNormally,
      );
      expect(
        () => GeofenceEngine(
          pois: [
            _poi(
              entrances: const [
                PoiEntrance(position: GeoPoint(91, 0), label: 'Invalid'),
              ],
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('jarak titik akses invalid membatalkan dwell tanpa melepas kunci', () {
      const center = GeoPoint(0, 0);
      const entrance = GeoPoint(0, 1);
      var entranceDistance = 5.0;
      final engine = GeofenceEngine(
        pois: [
          _poi(
            position: center,
            entrances: const [PoiEntrance(position: entrance, label: 'Pintu')],
          ),
        ],
        distanceCalculator: (_, to) => to == center ? 50.0 : entranceDistance,
      );

      engine.evaluate(_fix(0), enabled: true);
      entranceDistance = double.nan;
      expect(engine.evaluate(_fix(4000), enabled: true), isEmpty);
      entranceDistance = 5.0;
      expect(engine.evaluate(_fix(5000), enabled: true), isEmpty);
      expect(engine.evaluate(_fix(10000), enabled: true), hasLength(1));

      // Setelah terkunci, jarak invalid tidak melepas pengunci.
      entranceDistance = double.nan;
      engine.evaluate(_fix(11000), enabled: true);
      expect(engine.activePoiIds, {'synthetic-a'});
    });
  });
}

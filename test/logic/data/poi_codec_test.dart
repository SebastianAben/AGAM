/// Test validasi dokumen POI (PB03, PRD §15.2 butir 3).
///
/// Dokumen uji di file ini SINTETIS dan tidak boleh masuk dataset produksi.
library;

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokumen POI minimal yang valid. Koordinat sengaja memakai nilai sintetis,
/// bukan POI asli, agar tidak tertukar dengan data PRD §9.1.
Map<String, Object?> validPoi({Map<String, Object?> overrides = const {}}) => {
  'id': 'T01',
  'name': 'POI Uji',
  'category': 'lecture',
  'lat': -6.89,
  'lng': 107.61,
  'radiusM': 15,
  ...overrides,
};

void main() {
  group('decodePoi — dokumen valid', () {
    test('membaca field wajib dan menerapkan default', () {
      final issues = <PoiDecodeIssue>[];
      final poi = decodePoi(validPoi(), issues)!;

      expect(issues, isEmpty);
      expect(poi.id, 'T01');
      expect(poi.name, 'POI Uji');
      expect(poi.category, PoiCategory.lecture);
      expect(poi.position.lat, -6.89);
      expect(poi.position.lng, 107.61);
      expect(poi.radiusM, 15);
      expect(poi.entrances, isEmpty);
      expect(poi.aliases, isEmpty);
      expect(poi.trailOrder, isNull);
      // Tanpa blok metadata, konten diperlakukan sebagai placeholder (A02).
      expect(poi.metadata.isPlaceholder, isTrue);
      expect(poi.metadata.approved, isFalse);
    });

    test('radiusM tidak ada → memakai default kontrak', () {
      final issues = <PoiDecodeIssue>[];
      final poi = decodePoi(validPoi(overrides: {'radiusM': null}), issues)!;

      expect(issues, isEmpty);
      expect(poi.radiusM, kDefaultPoiRadiusM);
    });

    test('alias bukan teks disaring, bukan menolak dokumen', () {
      final issues = <PoiDecodeIssue>[];
      final poi = decodePoi(
        validPoi(
          overrides: {
            'aliases': ['labtek 5', 42, '', 'lab 5'],
          },
        ),
        issues,
      )!;

      expect(poi.aliases, ['labtek 5', 'lab 5']);
    });

    test('pintu masuk yang disurvei dipakai sebagai titik navigasi', () {
      final issues = <PoiDecodeIssue>[];
      final poi = decodePoi(
        validPoi(
          overrides: {
            'entrances': [
              {'lat': -6.8901, 'lng': 107.6102, 'label': 'Pintu utara'},
            ],
          },
        ),
        issues,
      )!;

      expect(issues, isEmpty);
      expect(poi.hasSurveyedEntrance, isTrue);
      expect(poi.navigationPoint, const GeoPoint(-6.8901, 107.6102));
      expect(poi.entrances.single.label, 'Pintu utara');
    });

    test('tanpa pintu masuk, titik navigasi jatuh ke titik tengah gedung', () {
      final poi = decodePoi(validPoi(), <PoiDecodeIssue>[])!;

      expect(poi.hasSurveyedEntrance, isFalse);
      expect(poi.navigationPoint, poi.position);
    });
  });

  group('decodePoi — dokumen ditolak', () {
    final cases = <String, Map<String, Object?>>{
      'id hilang': {'id': null},
      'id kosong': {'id': '   '},
      'id bukan teks': {'id': 7},
      'name hilang': {'name': null},
      'category tidak dikenal': {'category': 'kantin'},
      'lat bukan angka': {'lat': '-6.89'},
      'lng hilang': {'lng': null},
      'lat di luar rentang': {'lat': -91.0},
      'lng di luar rentang': {'lng': 181.0},
      'radius nol': {'radiusM': 0},
      'radius negatif': {'radiusM': -15},
      'radius bukan angka': {'radiusM': '15'},
      'entrances bukan daftar': {'entrances': 'tidak ada'},
      'entrances dengan koordinat rusak': {
        'entrances': [
          {'lat': 'x', 'lng': 107.61},
        ],
      },
      'trailOrder nol': {'trailOrder': 0},
      'trailOrder bukan bilangan bulat': {'trailOrder': 1.5},
    };

    cases.forEach((name, overrides) {
      test(name, () {
        final issues = <PoiDecodeIssue>[];
        expect(decodePoi(validPoi(overrides: overrides), issues), isNull);
        expect(issues, isNotEmpty);
      });
    });

    test('dokumen bukan objek', () {
      final issues = <PoiDecodeIssue>[];
      expect(decodePoi('P01', issues), isNull);
      expect(issues.single.reason, 'bukan objek');
    });
  });

  group('metadata A02', () {
    test('metadata lengkap terbaca dan dapat disetujui', () {
      final poi = decodePoi(
        validPoi(
          overrides: {
            'metadata': {
              'sources': ['Situs resmi ITB'],
              'owner': 'Tim konten',
              'verifiedAt': '2026-11-02',
              'assetAttribution': ['Foto: tim konten'],
              'approved': true,
            },
          },
        ),
        <PoiDecodeIssue>[],
      )!;

      expect(poi.metadata.isPlaceholder, isFalse);
      expect(poi.metadata.approved, isTrue);
      expect(poi.metadata.owner, 'Tim konten');
      expect(poi.metadata.verifiedAt, DateTime.parse('2026-11-02'));
    });

    test('isPlaceholder eksplisit mengalahkan metadata lain', () {
      final poi = decodePoi(
        validPoi(
          overrides: {
            'metadata': {
              'isPlaceholder': true,
              'sources': ['Situs resmi ITB'],
              'owner': 'Tim konten',
              'verifiedAt': '2026-11-02',
              'approved': true,
            },
          },
        ),
        <PoiDecodeIssue>[],
      )!;

      expect(poi.metadata.isPlaceholder, isTrue);
      expect(poi.metadata.approved, isFalse);
    });

    test('metadata tidak lengkap tetap placeholder meski approved true', () {
      for (final metadata in <Map<String, Object?>>[
        {'approved': true, 'owner': 'Tim konten', 'verifiedAt': '2026-11-02'},
        {
          'approved': true,
          'sources': ['Situs resmi ITB'],
          'verifiedAt': '2026-11-02',
        },
        {
          'approved': true,
          'sources': ['Situs resmi ITB'],
          'owner': 'Tim konten',
        },
        {
          'approved': true,
          'sources': ['Situs resmi ITB'],
          'owner': 'Tim konten',
          'verifiedAt': 'bukan tanggal',
        },
      ]) {
        final poi = decodePoi(
          validPoi(overrides: {'metadata': metadata}),
          <PoiDecodeIssue>[],
        )!;

        expect(poi.metadata.isPlaceholder, isTrue, reason: '$metadata');
        expect(poi.metadata.approved, isFalse, reason: '$metadata');
      }
    });
  });

  group('decodeFacility', () {
    test('membaca fasilitas valid', () {
      final issues = <PoiDecodeIssue>[];
      final facility = decodeFacility({
        'id': 'T-F01',
        'name': 'Toilet Uji',
        'category': 'toilet',
        'lat': -6.8902,
        'lng': 107.6099,
        'buildingId': 'T01',
      }, issues)!;

      expect(issues, isEmpty);
      expect(facility.category, FacilityCategory.toilet);
      expect(facility.buildingId, 'T01');
      expect(facility.metadata.isPlaceholder, isTrue);
    });

    test('kategori di luar daftar PRD ditolak', () {
      final issues = <PoiDecodeIssue>[];
      expect(
        decodeFacility({
          'id': 'T-F02',
          'name': 'Ruang Uji',
          'category': 'ruang kelas',
          'lat': -6.8902,
          'lng': 107.6099,
        }, issues),
        isNull,
      );
      expect(issues.single.field, 'category');
    });

    test('buildingId bukan teks ditolak', () {
      final issues = <PoiDecodeIssue>[];
      expect(
        decodeFacility({
          'id': 'T-F03',
          'name': 'ATM Uji',
          'category': 'atm',
          'lat': -6.8902,
          'lng': 107.6099,
          'buildingId': 1,
        }, issues),
        isNull,
      );
      expect(issues.single.field, 'buildingId');
    });
  });

  group('decodePoiDataset', () {
    test('dokumen rusak diabaikan, dokumen valid tetap terbaca', () {
      final result = decodePoiDataset({
        'pois': [
          validPoi(),
          validPoi(overrides: {'id': 'T02', 'radiusM': -1}),
          validPoi(overrides: {'id': 'T03'}),
          'bukan objek',
        ],
        'facilities': [
          {
            'id': 'T-F01',
            'name': 'Toilet Uji',
            'category': 'toilet',
            'lat': -6.8902,
            'lng': 107.6099,
          },
          {'id': 'T-F02', 'name': 'Rusak', 'category': 'toilet', 'lat': 'x'},
        ],
      });

      expect(result.pois.map((p) => p.id), ['T01', 'T03']);
      expect(result.facilities.map((f) => f.id), ['T-F01']);
      expect(result.hasIssues, isTrue);
    });

    test('id ganda hanya diambil yang pertama', () {
      final result = decodePoiDataset({
        'pois': [
          validPoi(overrides: {'name': 'Pertama'}),
          validPoi(overrides: {'name': 'Kedua'}),
        ],
      });

      expect(result.pois.single.name, 'Pertama');
      expect(result.issues.single.reason, 'id ganda');
    });

    test('field pois bukan daftar dicatat sebagai masalah', () {
      final result = decodePoiDataset({'pois': 'tidak ada'});

      expect(result.pois, isEmpty);
      expect(result.issues.single.field, 'pois');
    });

    test('dataset tanpa pois dan facilities menghasilkan daftar kosong', () {
      final result = decodePoiDataset(<String, Object?>{});

      expect(result.pois, isEmpty);
      expect(result.facilities, isEmpty);
      expect(result.hasIssues, isFalse);
    });

    test('dataset bukan objek melempar FormatException', () {
      expect(() => decodePoiDataset(const []), throwsFormatException);
    });
  });
}

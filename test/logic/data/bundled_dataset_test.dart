/// Mengunci dataset bawaan `assets/data/pois.json` terhadap PRD §9.1.
///
/// Nilai yang diharapkan di file ini disalin dari tabel PRD §9.1, bukan dari
/// kode implementasi. Jika PRD berubah, perbarui PRD lebih dulu lalu dataset
/// dan test ini.
library;

import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:flutter_test/flutter_test.dart';

/// (id, nama, kategori, lat, lng) dari PRD §9.1. Radius seluruh POI 15 m.
const List<(String, String, PoiCategory, double, double)> prdPois = [
  (
    'P01',
    'Labtek V',
    PoiCategory.laboratoryAndLecture,
    -6.8905811,
    107.6097754,
  ),
  (
    'P02',
    'Labtek VI',
    PoiCategory.laboratoryAndLecture,
    -6.8901358,
    107.6097167,
  ),
  (
    'P03',
    'Labtek VII',
    PoiCategory.laboratoryAndLecture,
    -6.8901169,
    107.6105714,
  ),
  (
    'P04',
    'Labtek VIII',
    PoiCategory.laboratoryAndLecture,
    -6.8905954,
    107.6105760,
  ),
  (
    'P05',
    'Labtek X & XI',
    PoiCategory.laboratoryAndLecture,
    -6.8889940,
    107.6095767,
  ),
  ('P06', 'Gedung Kuliah Umum Barat', PoiCategory.lecture, -6.89053, 107.60890),
  (
    'P07',
    'Gedung Kuliah Umum Timur',
    PoiCategory.lecture,
    -6.8903881,
    107.6119990,
  ),
  ('P08', 'Oktagon', PoiCategory.lecture, -6.8890603, 107.6100470),
  ('P09', 'TVST', PoiCategory.lecture, -6.8895043, 107.6100594),
  (
    'P10',
    'Labtek I',
    PoiCategory.laboratoryAndLecture,
    -6.8892078,
    107.6111876,
  ),
];

/// Alias awal dari PRD §9.1. Tim konten dapat menambah alias; test memeriksa
/// alias PRD tetap ada, bukan bahwa daftarnya persis sama.
const Map<String, List<String>> prdAliases = {
  'P01': ['labtek 5', 'lab 5'],
  'P02': ['labtek 6', 'lab 6'],
  'P03': ['labtek 7', 'lab 7'],
  'P04': ['labtek 8', 'lab 8'],
  'P05': ['Labtek Biru', 'labtek 10', 'labtek 11'],
  'P06': ['GKUB'],
  'P07': ['GKUT'],
  'P08': [],
  'P09': [],
  'P10': ['Mektan', 'labtek 1'],
};

void main() {
  late PoiDecodeResult result;

  setUpAll(() {
    final text = File('assets/data/pois.json').readAsStringSync();
    result = decodePoiDataset(jsonDecode(text));
  });

  test('seluruh dokumen lolos validasi', () {
    expect(result.issues, isEmpty);
  });

  test('memuat tepat 10 POI dengan id P01–P10 berurutan', () {
    expect(result.pois.map((p) => p.id), prdPois.map((e) => e.$1));
  });

  test('nama, kategori, dan koordinat sama dengan PRD §9.1', () {
    for (final (id, name, category, lat, lng) in prdPois) {
      final poi = result.pois.firstWhere((p) => p.id == id);
      expect(poi.name, name, reason: id);
      expect(poi.category, category, reason: id);
      expect(poi.position.lat, lat, reason: '$id lat');
      expect(poi.position.lng, lng, reason: '$id lng');
    }
  });

  test('radius seluruh POI 15 m sesuai PRD §9.1', () {
    for (final poi in result.pois) {
      expect(poi.radiusM, 15, reason: poi.id);
      expect(poi.radiusM, kDefaultPoiRadiusM, reason: poi.id);
    }
  });

  test('alias PRD tersedia untuk pencarian', () {
    for (final poi in result.pois) {
      expect(poi.aliases, containsAll(prdAliases[poi.id]!), reason: poi.id);
    }
  });

  test('radius 15 m tidak tumpang tindih antar-POI', () {
    // Jarak terdekat menurut PRD §9.1 adalah ±49 m (P08–P09), jauh di atas
    // 2 x 15 m. Nilai acuan dihitung independen dengan haversine di Python
    // (R = 6371000 m): P08–P09 = 49.4 m, P01–P02 = 49.9 m.
    for (final a in result.pois) {
      for (final b in result.pois) {
        if (a.id == b.id) continue;
        expect(
          a.position.distanceTo(b.position),
          greaterThan(a.radiusM + b.radiusM),
          reason: '${a.id}–${b.id}',
        );
      }
    }

    final p08 = result.pois.firstWhere((p) => p.id == 'P08');
    final p09 = result.pois.firstWhere((p) => p.id == 'P09');
    expect(p08.position.distanceTo(p09.position), closeTo(49.4, 0.5));

    final p01 = result.pois.firstWhere((p) => p.id == 'P01');
    final p02 = result.pois.firstWhere((p) => p.id == 'P02');
    expect(p01.position.distanceTo(p02.position), closeTo(49.9, 0.5));
  });

  group('hal yang masih tertunda (PRD §22)', () {
    // Disetujui tim 14 November 2026 setelah teks, foto, dan audio lengkap.
    // Isi minimum POI yang disetujui diperiksa content_assets_test.dart.
    test('hanya Labtek V dan VI yang siap rilis', () {
      const approved = {'P01', 'P02'};
      for (final poi in result.pois) {
        final ready = approved.contains(poi.id);
        expect(poi.metadata.approved, ready, reason: poi.id);
        expect(poi.metadata.isPlaceholder, !ready, reason: poi.id);
      }
    });

    // Foto dan audio sudah tersedia (14 November 2026); keberadaan file dan
    // pendaftarannya diperiksa content_assets_test.dart.
    test('video GKUB/GKUT belum tersedia', () {
      for (final poi in result.pois) {
        expect(poi.media.video, isNull, reason: poi.id);
      }
    });

    test(
      'pintu masuk belum disurvei; navigasi memakai titik tengah gedung',
      () {
        for (final poi in result.pois) {
          expect(poi.hasSurveyedEntrance, isFalse, reason: poi.id);
          expect(poi.navigationPoint, poi.position, reason: poi.id);
        }
      },
    );

    test('urutan trail belum ditetapkan', () {
      for (final poi in result.pois) {
        expect(poi.trailOrder, isNull, reason: poi.id);
      }
    });

    test('dataset fasilitas belum tersedia', () {
      expect(result.facilities, isEmpty);
    });
  });
}

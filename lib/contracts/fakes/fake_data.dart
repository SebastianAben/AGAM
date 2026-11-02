/// Data untuk implementasi palsu.
///
/// ID, nama, kategori, dan koordinat POI diambil dari `.agent/PRD.md` §9.1.
/// Semua teks, media, fasilitas, rute jalan, dan urutan trail di file ini
/// adalah SINTETIS atau PLACEHOLDER. Dilarang menyalinnya ke data produksi.
library;

import '../constants.dart';
import '../models/content.dart';
import '../models/geo.dart';

const String kPlaceholderText = 'PLACEHOLDER — menunggu tim konten';

Poi _poi(
  String id,
  String name,
  List<String> aliases,
  PoiCategory category,
  double lat,
  double lng,
) => Poi(
  id: id,
  name: name,
  aliases: aliases,
  category: category,
  position: GeoPoint(lat, lng),
  radiusM: kDefaultPoiRadiusM,
  entrances: const [],
  description: kPlaceholderText,
  function: kPlaceholderText,
  facilities: const [],
  trivia: kPlaceholderText,
  media: const PoiMedia(),
  metadata: const ContentMetadata.placeholder(),
);

final List<Poi> fakePois = [
  _poi(
    'P01',
    'Labtek V',
    ['labtek 5', 'lab 5'],
    PoiCategory.laboratoryAndLecture,
    -6.8905811,
    107.6097754,
  ),
  _poi(
    'P02',
    'Labtek VI',
    ['labtek 6', 'lab 6'],
    PoiCategory.laboratoryAndLecture,
    -6.8901358,
    107.6097167,
  ),
  _poi(
    'P03',
    'Labtek VII',
    ['labtek 7', 'lab 7'],
    PoiCategory.laboratoryAndLecture,
    -6.8901169,
    107.6105714,
  ),
  _poi(
    'P04',
    'Labtek VIII',
    ['labtek 8', 'lab 8'],
    PoiCategory.laboratoryAndLecture,
    -6.8905954,
    107.6105760,
  ),
  _poi(
    'P05',
    'Labtek X & XI',
    ['Labtek Biru', 'labtek 10', 'labtek 11'],
    PoiCategory.laboratoryAndLecture,
    -6.8889940,
    107.6095767,
  ),
  _poi(
    'P06',
    'Gedung Kuliah Umum Barat',
    ['GKUB'],
    PoiCategory.lecture,
    -6.89053,
    107.60890,
  ),
  _poi(
    'P07',
    'Gedung Kuliah Umum Timur',
    ['GKUT'],
    PoiCategory.lecture,
    -6.8903881,
    107.6119990,
  ),
  _poi('P08', 'Oktagon', [], PoiCategory.lecture, -6.8890603, 107.6100470),
  _poi('P09', 'TVST', [], PoiCategory.lecture, -6.8895043, 107.6100594),
  _poi(
    'P10',
    'Labtek I',
    ['Mektan', 'labtek 1'],
    PoiCategory.laboratoryAndLecture,
    -6.8892078,
    107.6111876,
  ),
];

/// SINTETIS: fasilitas contoh di sebelah POI. Dataset fasilitas asli belum
/// tersedia (PRD §22).
final List<Facility> fakeFacilities = [
  _facility(
    'F-FAKE-1',
    'Toilet (contoh)',
    FacilityCategory.toilet,
    'P01',
    0.00009,
  ),
  _facility(
    'F-FAKE-2',
    'Musala (contoh)',
    FacilityCategory.musala,
    'P07',
    -0.00009,
  ),
  _facility(
    'F-FAKE-3',
    'Kantin (contoh)',
    FacilityCategory.kantin,
    'P05',
    0.00009,
  ),
  _facility('F-FAKE-4', 'ATM (contoh)', FacilityCategory.atm, 'P09', -0.00009),
];

Facility _facility(
  String id,
  String name,
  FacilityCategory category,
  String buildingId,
  double lngOffset,
) {
  final building = fakePois.firstWhere((p) => p.id == buildingId);
  return Facility(
    id: id,
    name: name,
    category: category,
    position: GeoPoint(
      building.position.lat,
      building.position.lng + lngOffset,
    ),
    buildingId: buildingId,
    description: kPlaceholderText,
    metadata: const ContentMetadata.placeholder(),
  );
}

/// SINTETIS: urutan untuk simulasi dan trail palsu. Urutan Orientation Trail
/// resmi belum ditetapkan tim (PRD §12).
const List<String> fakeTrailOrder = [
  'P06',
  'P01',
  'P02',
  'P03',
  'P04',
  'P07',
  'P10',
  'P08',
  'P09',
  'P05',
];

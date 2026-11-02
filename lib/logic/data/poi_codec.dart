/// Pembacaan dan validasi dokumen POI serta fasilitas (PRD §15.2 butir 3,
/// §15.3).
///
/// Dokumen berasal dari dua tempat dengan bentuk yang sama: JSON bawaan di
/// APK dan dokumen Firestore. Dokumen yang tidak valid **diabaikan** satu per
/// satu, bukan menggagalkan seluruh dataset, agar satu dokumen rusak di
/// Firestore tidak membuat aplikasi kehilangan seluruh POI.
library;

import '../../contracts/contracts.dart';

/// Alasan sebuah dokumen ditolak. Dipakai untuk log dan test, bukan untuk UI.
class PoiDecodeIssue {
  const PoiDecodeIssue({
    required this.id,
    required this.field,
    required this.reason,
  });

  /// `id` dokumen jika terbaca, atau `null` jika `id` sendiri tidak valid.
  final String? id;

  final String field;
  final String reason;

  @override
  String toString() => 'PoiDecodeIssue(${id ?? '<tanpa id>'}, $field: $reason)';
}

/// Hasil pembacaan satu dataset: dokumen yang lolos validasi beserta
/// dokumen yang ditolak.
class PoiDecodeResult {
  const PoiDecodeResult({
    required this.pois,
    required this.facilities,
    required this.issues,
  });

  final List<Poi> pois;
  final List<Facility> facilities;
  final List<PoiDecodeIssue> issues;

  bool get hasIssues => issues.isNotEmpty;
}

/// Batas wajar koordinat WGS84.
const double _minLat = -90;
const double _maxLat = 90;
const double _minLng = -180;
const double _maxLng = 180;

/// Membaca dataset lengkap `{ "pois": [...], "facilities": [...] }`.
///
/// Tidak melempar error untuk dokumen yang rusak; lihat [PoiDecodeResult.issues].
/// Melempar [FormatException] hanya jika bentuk paling luar bukan objek
/// dengan daftar yang diharapkan, karena dataset seperti itu tidak dapat
/// dipakai sama sekali.
PoiDecodeResult decodePoiDataset(Object? raw) {
  if (raw is! Map<String, Object?>) {
    throw const FormatException('Dataset POI harus berupa objek JSON');
  }
  final issues = <PoiDecodeIssue>[];
  return PoiDecodeResult(
    pois: _decodeList(raw['pois'], 'pois', issues, decodePoi, (p) => p.id),
    facilities: _decodeList(
      raw['facilities'],
      'facilities',
      issues,
      decodeFacility,
      (f) => f.id,
    ),
    issues: issues,
  );
}

List<T> _decodeList<T>(
  Object? raw,
  String field,
  List<PoiDecodeIssue> issues,
  T? Function(Object?, List<PoiDecodeIssue>) decode,
  String Function(T) idOf,
) {
  if (raw == null) return const [];
  if (raw is! List) {
    issues.add(PoiDecodeIssue(id: null, field: field, reason: 'bukan daftar'));
    return const [];
  }
  final seen = <String>{};
  final result = <T>[];
  for (final entry in raw) {
    final decoded = decode(entry, issues);
    if (decoded == null) continue;
    final id = idOf(decoded);
    if (!seen.add(id)) {
      issues.add(PoiDecodeIssue(id: id, field: 'id', reason: 'id ganda'));
      continue;
    }
    result.add(decoded);
  }
  return result;
}

/// Membaca satu dokumen POI. Mengembalikan `null` jika dokumen tidak valid.
Poi? decodePoi(Object? raw, List<PoiDecodeIssue> issues) {
  if (raw is! Map<String, Object?>) {
    issues.add(
      const PoiDecodeIssue(id: null, field: '<dokumen>', reason: 'bukan objek'),
    );
    return null;
  }

  final id = _requiredString(raw['id'], 'id', null, issues);
  if (id == null) return null;

  final name = _requiredString(raw['name'], 'name', id, issues);
  if (name == null) return null;

  final lat = _coordinate(raw['lat'], 'lat', _minLat, _maxLat, id, issues);
  final lng = _coordinate(raw['lng'], 'lng', _minLng, _maxLng, id, issues);
  if (lat == null || lng == null) return null;

  final category = _poiCategory(raw['category'], id, issues);
  if (category == null) return null;

  final radiusM = _radius(raw['radiusM'], id, issues);
  if (radiusM == null) return null;

  final entrances = _entrances(raw['entrances'], id, issues);
  if (entrances == null) return null;

  // `trailOrder` boleh tidak ada (urutan trail belum ditetapkan, PRD §22),
  // tetapi jika ada wajib bilangan bulat positif.
  final rawTrailOrder = raw['trailOrder'];
  if (rawTrailOrder != null && (rawTrailOrder is! int || rawTrailOrder <= 0)) {
    issues.add(
      PoiDecodeIssue(
        id: id,
        field: 'trailOrder',
        reason: 'wajib bilangan bulat positif',
      ),
    );
    return null;
  }

  return Poi(
    id: id,
    name: name,
    aliases: _stringList(raw['aliases']),
    category: category,
    position: GeoPoint(lat, lng),
    radiusM: radiusM,
    entrances: entrances,
    description: _text(raw['description']),
    function: _text(raw['function']),
    facilities: _stringList(raw['facilities']),
    trivia: _text(raw['trivia']),
    media: _media(raw['media']),
    metadata: _metadata(raw['metadata']),
    trailOrder: rawTrailOrder as int?,
  );
}

/// Membaca satu dokumen fasilitas. Mengembalikan `null` jika tidak valid.
Facility? decodeFacility(Object? raw, List<PoiDecodeIssue> issues) {
  if (raw is! Map<String, Object?>) {
    issues.add(
      const PoiDecodeIssue(id: null, field: '<dokumen>', reason: 'bukan objek'),
    );
    return null;
  }

  final id = _requiredString(raw['id'], 'id', null, issues);
  if (id == null) return null;

  final name = _requiredString(raw['name'], 'name', id, issues);
  if (name == null) return null;

  final lat = _coordinate(raw['lat'], 'lat', _minLat, _maxLat, id, issues);
  final lng = _coordinate(raw['lng'], 'lng', _minLng, _maxLng, id, issues);
  if (lat == null || lng == null) return null;

  final category = _facilityCategory(raw['category'], id, issues);
  if (category == null) return null;

  final buildingId = raw['buildingId'];
  if (buildingId != null && buildingId is! String) {
    issues.add(
      PoiDecodeIssue(id: id, field: 'buildingId', reason: 'bukan teks'),
    );
    return null;
  }

  return Facility(
    id: id,
    name: name,
    category: category,
    position: GeoPoint(lat, lng),
    buildingId: buildingId as String?,
    description: _text(raw['description']),
    metadata: _metadata(raw['metadata']),
  );
}

String? _requiredString(
  Object? raw,
  String field,
  String? id,
  List<PoiDecodeIssue> issues,
) {
  if (raw is! String || raw.trim().isEmpty) {
    issues.add(
      PoiDecodeIssue(
        id: id,
        field: field,
        reason: 'wajib berupa teks tidak kosong',
      ),
    );
    return null;
  }
  return raw;
}

double? _coordinate(
  Object? raw,
  String field,
  double min,
  double max,
  String id,
  List<PoiDecodeIssue> issues,
) {
  if (raw is! num || !raw.toDouble().isFinite) {
    issues.add(
      PoiDecodeIssue(id: id, field: field, reason: 'wajib berupa angka'),
    );
    return null;
  }
  final value = raw.toDouble();
  if (value < min || value > max) {
    issues.add(
      PoiDecodeIssue(
        id: id,
        field: field,
        reason: 'di luar rentang $min..$max',
      ),
    );
    return null;
  }
  return value;
}

double? _radius(Object? raw, String id, List<PoiDecodeIssue> issues) {
  if (raw == null) return kDefaultPoiRadiusM;
  if (raw is! num || !raw.toDouble().isFinite) {
    issues.add(
      PoiDecodeIssue(id: id, field: 'radiusM', reason: 'wajib berupa angka'),
    );
    return null;
  }
  final value = raw.toDouble();
  if (value <= 0) {
    issues.add(
      PoiDecodeIssue(
        id: id,
        field: 'radiusM',
        reason: 'wajib lebih besar dari 0',
      ),
    );
    return null;
  }
  return value;
}

PoiCategory? _poiCategory(Object? raw, String id, List<PoiDecodeIssue> issues) {
  for (final value in PoiCategory.values) {
    if (value.name == raw) return value;
  }
  issues.add(
    PoiDecodeIssue(
      id: id,
      field: 'category',
      reason: 'nilai tidak dikenal: $raw',
    ),
  );
  return null;
}

FacilityCategory? _facilityCategory(
  Object? raw,
  String id,
  List<PoiDecodeIssue> issues,
) {
  for (final value in FacilityCategory.values) {
    if (value.name == raw) return value;
  }
  issues.add(
    PoiDecodeIssue(
      id: id,
      field: 'category',
      reason: 'nilai tidak dikenal: $raw',
    ),
  );
  return null;
}

List<PoiEntrance>? _entrances(
  Object? raw,
  String id,
  List<PoiDecodeIssue> issues,
) {
  if (raw == null) return const [];
  if (raw is! List) {
    issues.add(
      PoiDecodeIssue(id: id, field: 'entrances', reason: 'bukan daftar'),
    );
    return null;
  }
  final entrances = <PoiEntrance>[];
  for (final entry in raw) {
    if (entry is! Map<String, Object?>) {
      issues.add(
        PoiDecodeIssue(
          id: id,
          field: 'entrances',
          reason: 'elemen bukan objek',
        ),
      );
      return null;
    }
    final lat = _coordinate(
      entry['lat'],
      'entrances.lat',
      _minLat,
      _maxLat,
      id,
      issues,
    );
    final lng = _coordinate(
      entry['lng'],
      'entrances.lng',
      _minLng,
      _maxLng,
      id,
      issues,
    );
    if (lat == null || lng == null) return null;
    entrances.add(
      PoiEntrance(position: GeoPoint(lat, lng), label: _text(entry['label'])),
    );
  }
  return entrances;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return List.unmodifiable(
    raw.whereType<String>().where((s) => s.trim().isNotEmpty),
  );
}

String _text(Object? raw) => raw is String ? raw : '';

PoiMedia _media(Object? raw) {
  if (raw is! Map<String, Object?>) return const PoiMedia();
  return PoiMedia(
    photos: _stringList(raw['photos']),
    narrationAudio: _optionalText(raw['narrationAudio']),
    promptAudio: _optionalText(raw['promptAudio']),
    arrivalAudio: _optionalText(raw['arrivalAudio']),
    video: _optionalText(raw['video']),
  );
}

String? _optionalText(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw : null;

/// Metadata A02. Dokumen tanpa metadata lengkap dianggap placeholder dan
/// belum disetujui, sehingga UI tidak menampilkannya sebagai konten final.
ContentMetadata _metadata(Object? raw) {
  if (raw is! Map<String, Object?>) return const ContentMetadata.placeholder();
  if (raw['isPlaceholder'] == true) return const ContentMetadata.placeholder();

  final sources = _stringList(raw['sources']);
  final owner = _optionalText(raw['owner']);
  final verifiedAt = _dateTime(raw['verifiedAt']);
  final approved = raw['approved'] == true;

  // Tanpa sumber, penanggung jawab, atau tanggal verifikasi, konten tidak
  // memenuhi A02 dan tetap diperlakukan sebagai placeholder.
  if (sources.isEmpty || owner == null || verifiedAt == null) {
    return const ContentMetadata.placeholder();
  }

  return ContentMetadata(
    sources: sources,
    verifiedAt: verifiedAt,
    owner: owner,
    assetAttribution: _stringList(raw['assetAttribution']),
    approved: approved,
  );
}

DateTime? _dateTime(Object? raw) {
  if (raw is! String) return null;
  return DateTime.tryParse(raw);
}

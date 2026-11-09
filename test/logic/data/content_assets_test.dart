import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Validasi format aset konten untuk tim konten (PB09, A02, F03). Aturan
// lengkap: task-implementation/backend/PB09-LA-01-content-format.md.
//
// Saat ini seluruh POI masih placeholder sehingga sebagian besar
// pemeriksaan belum memiliki data. Test ini menjadi penjaga saat tim konten
// mulai mengisi `assets/data/pois.json` dan `assets/media/`.
void main() {
  final dataset = jsonDecode(
    File('assets/data/pois.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final pois = (dataset['pois']! as List).cast<Map<String, Object?>>();
  final pubspec = File('pubspec.yaml').readAsStringSync();

  const extensions = {
    'photos': {'.jpg', '.jpeg', '.png', '.webp'},
    'narrationAudio': {'.mp3', '.m4a', '.aac', '.ogg'},
    'promptAudio': {'.mp3', '.m4a', '.aac', '.ogg'},
    'arrivalAudio': {'.mp3', '.m4a', '.aac', '.ogg'},
    'video': {'.mp4'},
  };

  Iterable<(String poiId, String field, String path)> mediaPaths() sync* {
    for (final poi in pois) {
      final media = (poi['media'] as Map?)?.cast<String, Object?>() ?? {};
      for (final entry in media.entries) {
        final value = entry.value;
        final paths = value is List
            ? value.cast<String>()
            : [?value as String?];
        for (final path in paths) {
          yield (poi['id']! as String, entry.key, path);
        }
      }
    }
  }

  test('field media hanya memakai nama yang dikenal', () {
    for (final (id, field, _) in mediaPaths()) {
      expect(extensions.keys, contains(field), reason: '$id: $field');
    }
  });

  test('setiap path media ada di assets/media/<id POI>/ dengan ekstensi '
      'yang didukung', () {
    for (final (id, field, path) in mediaPaths()) {
      expect(path, startsWith('assets/media/$id/'), reason: '$id.$field');
      final ext = path.substring(path.lastIndexOf('.')).toLowerCase();
      expect(extensions[field], contains(ext), reason: '$id.$field: $path');
      expect(File(path).existsSync(), isTrue, reason: 'Tidak ada: $path');
    }
  });

  test('folder media POI didaftarkan di pubspec.yaml', () {
    final folders = {for (final (id, _, _) in mediaPaths()) id};
    for (final id in folders) {
      expect(pubspec, contains('assets/media/$id/'), reason: id);
    }
  });

  test('POI yang disetujui memenuhi isi minimum F03 dan metadata A02', () {
    for (final poi in pois) {
      final metadata = (poi['metadata'] as Map?)?.cast<String, Object?>() ?? {};
      if (metadata['approved'] != true) continue;
      final id = poi['id'];
      final media = (poi['media'] as Map?)?.cast<String, Object?>() ?? {};
      expect(metadata['isPlaceholder'], isNot(true), reason: '$id');
      expect((metadata['sources'] as List?) ?? [], isNotEmpty, reason: '$id');
      expect(metadata['owner'], isA<String>(), reason: '$id');
      expect(
        DateTime.tryParse('${metadata['verifiedAt']}'),
        isNotNull,
        reason: '$id',
      );
      expect((media['photos'] as List?) ?? [], isNotEmpty, reason: '$id');
      expect(media['narrationAudio'], isA<String>(), reason: '$id');
      expect(media['promptAudio'], isA<String>(), reason: '$id');
      expect(media['arrivalAudio'], isA<String>(), reason: '$id');
      for (final field in ['description', 'function', 'trivia']) {
        expect(
          '${poi[field]}',
          isNot(contains('PLACEHOLDER')),
          reason: '$id.$field',
        );
      }
      // F03: video narasi hanya untuk GKUB (P06) dan GKUT (P07).
      if (id == 'P06' || id == 'P07') {
        expect(media['video'], isA<String>(), reason: '$id');
      }
      // Atribusi aset wajib bila ada media.
      expect(
        (metadata['assetAttribution'] as List?) ?? [],
        isNotEmpty,
        reason: '$id',
      );
    }
  });
}

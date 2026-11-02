/// Sumber data POI: JSON bawaan di APK, cache lokal, dan sumber remote
/// (Firestore). Lihat PRD §15.1 dan §15.2.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Path aset dataset bawaan di APK.
const String kBundledPoiAsset = 'assets/data/pois.json';

/// Dataset mentah (`{ "pois": [...], "facilities": [...] }`) sebelum divalidasi.
typedef RawDataset = Map<String, Object?>;

/// Dataset JSON yang dibundel di APK. Selalu tersedia, juga saat offline
/// dan saat pertama kali aplikasi dibuka (PRD §15.2 butir 1).
class BundledDataset {
  const BundledDataset({this.bundle, this.assetPath = kBundledPoiAsset});

  /// Bundle aset yang dipakai; `null` berarti [rootBundle]. Test memberi
  /// bundle sendiri agar tidak bergantung pada APK.
  final AssetBundle? bundle;

  final String assetPath;

  AssetBundle get _assets => bundle ?? rootBundle;

  Future<RawDataset> load() async {
    final text = await _assets.loadString(assetPath);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Dataset bawaan harus berupa objek JSON');
    }
    return decoded;
  }
}

/// Salinan terakhir dari sumber remote, disimpan di perangkat.
///
/// Hanya berisi data konten. **Dilarang** menyimpan posisi pengguna di sini
/// (PRD A01).
abstract interface class DatasetCache {
  /// Salinan tersimpan, atau `null` jika belum ada atau rusak.
  Future<RawDataset?> read();

  Future<void> write(RawDataset dataset);

  Future<void> clear();
}

/// Cache berbasis satu file JSON di direktori aplikasi.
///
/// [directory] disediakan pemanggil agar kelas ini dapat diuji tanpa plugin
/// path. Saat integrasi, LA memberi direktori dokumen aplikasi; package
/// penyedia path belum ditambahkan ke `pubspec.yaml` dan versinya wajib
/// diverifikasi lebih dulu (`.agent/rules.md` §4.2).
class FileDatasetCache implements DatasetCache {
  const FileDatasetCache(this.directory, {this.fileName = 'pois_cache.json'});

  final Directory directory;
  final String fileName;

  File get _file => File('${directory.path}/$fileName');

  @override
  Future<RawDataset?> read() async {
    final file = _file;
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      // Cache rusak diperlakukan seperti tidak ada; pemanggil jatuh ke
      // dataset bawaan (PRD §15.2 butir 4).
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(RawDataset dataset) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await _file.writeAsString(jsonEncode(dataset), flush: true);
  }

  @override
  Future<void> clear() async {
    final file = _file;
    if (await file.exists()) await file.delete();
  }
}

/// Cache di memori; dipakai test dan sebagai fallback bila penyimpanan
/// tidak tersedia.
class InMemoryDatasetCache implements DatasetCache {
  RawDataset? _value;

  @override
  Future<RawDataset?> read() async => _value;

  @override
  Future<void> write(RawDataset dataset) async => _value = dataset;

  @override
  Future<void> clear() async => _value = null;
}

/// Sumber remote dataset (Firestore).
///
/// Implementasi Firestore **belum dibuat**: project Firebase belum tersedia
/// (PRD §22). Antarmuka ini memisahkan `PoiRepository` dari Firestore
/// sehingga sisa PB03 dapat diselesaikan dan diuji lebih dulu.
abstract interface class RemoteDatasetSource {
  /// Mengambil dataset terbaru. Melempar error bila gagal; pemanggil yang
  /// menentukan fallback.
  Future<RawDataset> fetch();
}

/// Sumber remote yang selalu gagal, dipakai selama project Firebase belum
/// dibuat. Dengan ini aplikasi berjalan memakai dataset bawaan dan cache,
/// sesuai jalur fallback PRD §15.2 butir 4.
class UnavailableRemoteSource implements RemoteDatasetSource {
  const UnavailableRemoteSource();

  @override
  Future<RawDataset> fetch() async => throw const RemoteDatasetUnavailable(
    'Project Firebase belum dibuat (PRD §22)',
  );
}

class RemoteDatasetUnavailable implements Exception {
  const RemoteDatasetUnavailable(this.message);

  final String message;

  @override
  String toString() => 'RemoteDatasetUnavailable: $message';
}

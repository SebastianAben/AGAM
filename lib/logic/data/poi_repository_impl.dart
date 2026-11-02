/// Implementasi asli [PoiRepository] (PB03).
///
/// Alur data mengikuti PRD §15.2:
///
/// 1. Saat pertama dibuka, aplikasi memakai JSON bawaan.
/// 2. Jika ada koneksi, data diambil dari sumber remote lalu disimpan ke
///    cache lokal.
/// 3. Setiap dokumen divalidasi; dokumen tidak valid diabaikan dan nilai
///    dari salinan lokal dipakai.
/// 4. Jika gagal (offline/error), salinan terakhir tetap dipakai.
///
/// Repository ini hanya membaca data konten. Posisi pengguna tidak pernah
/// masuk ke sini (PRD A01).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import 'poi_codec.dart';
import 'poi_sources.dart';

class PoiRepositoryImpl implements PoiRepository {
  PoiRepositoryImpl({
    required this.bundled,
    required this.cache,
    this.remote = const UnavailableRemoteSource(),
    this.onIssues,
  });

  final BundledDataset bundled;
  final DatasetCache cache;
  final RemoteDatasetSource remote;

  /// Dipanggil saat ada dokumen yang ditolak validasi, untuk log.
  final void Function(List<PoiDecodeIssue> issues)? onIssues;

  final _poiController = StreamController<List<Poi>>.broadcast();
  final _facilityController = StreamController<List<Facility>>.broadcast();

  List<Poi> _pois = const [];
  List<Facility> _facilities = const [];
  ContentSource? _source;
  Future<void>? _loading;

  /// Asal data yang sedang dipakai, atau `null` sebelum pemuatan pertama.
  ContentSource? get source => _source;

  /// Memuat data yang sudah tersedia di perangkat: cache lokal bila ada,
  /// jika tidak dataset bawaan. Tidak menyentuh jaringan.
  ///
  /// Aman dipanggil berulang; pemuatan hanya berjalan sekali.
  Future<void> ensureLoaded() => _loading ??= _loadLocal();

  Future<void> _loadLocal() async {
    final cached = await cache.read();
    if (cached != null && _apply(cached, ContentSource.cache)) return;
    _apply(await bundled.load(), ContentSource.bundled);
  }

  @override
  Stream<List<Poi>> watchPois() async* {
    await ensureLoaded();
    yield _pois;
    yield* _poiController.stream;
  }

  @override
  Stream<List<Facility>> watchFacilities() async* {
    await ensureLoaded();
    yield _facilities;
    yield* _facilityController.stream;
  }

  @override
  Future<Poi?> poiById(String id) async {
    await ensureLoaded();
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  @override
  Future<ContentSource> refresh() async {
    await ensureLoaded();
    try {
      final fetched = await remote.fetch();
      if (_apply(fetched, ContentSource.remote)) {
        // Hanya dataset yang berhasil dipakai yang disimpan, agar cache
        // tidak terisi dokumen yang semuanya ditolak.
        await cache.write(fetched);
        return ContentSource.remote;
      }
    } on Object {
      // Kegagalan jaringan, izin, atau format tidak boleh menggagalkan
      // pemanggil: aplikasi tetap memakai salinan yang sudah ada
      // (PRD §15.2 butir 4). Lihat ContentSource yang dikembalikan.
    }
    return _source ?? ContentSource.bundled;
  }

  /// Memvalidasi lalu memasang [raw] sebagai data aktif.
  ///
  /// Mengembalikan `false` jika dataset tidak dapat dipakai (bentuk salah,
  /// atau tidak ada satu pun POI yang lolos validasi) sehingga pemanggil
  /// dapat jatuh ke sumber berikutnya.
  bool _apply(RawDataset raw, ContentSource source) {
    final PoiDecodeResult result;
    try {
      result = decodePoiDataset(raw);
    } on FormatException {
      return false;
    }

    if (result.hasIssues) onIssues?.call(result.issues);

    // Dataset tanpa POI valid tidak dipakai: lebih baik memakai salinan
    // lama atau dataset bawaan daripada menampilkan peta tanpa POI.
    if (result.pois.isEmpty) return false;

    _pois = List.unmodifiable(result.pois);
    _facilities = List.unmodifiable(result.facilities);
    _source = source;
    if (_poiController.hasListener) _poiController.add(_pois);
    if (_facilityController.hasListener) _facilityController.add(_facilities);
    return true;
  }

  Future<void> dispose() async {
    await _poiController.close();
    await _facilityController.close();
  }
}

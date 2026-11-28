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
  Map<String, Map<String, Object?>> _rawPoisById = const {};
  Map<String, Map<String, Object?>> _rawFacilitiesById = const {};
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
    if (cached != null) {
      final result = _decodeOrNull(cached);
      if (result != null && result.pois.isNotEmpty) {
        if (result.hasIssues) {
          // Muat dataset bawaan sebagai cadangan per-ID untuk dokumen cache
          // yang tidak valid (PRD §15.2 butir 3).
          try {
            _apply(await bundled.load(), ContentSource.bundled, notify: false);
          } on Object {
            // Tetap lanjutkan memakai dokumen valid dari cache.
          }
          _applyDecoded(
            cached,
            result,
            ContentSource.cache,
            fallbackToExisting: true,
          );
          return;
        }
        _applyDecoded(cached, result, ContentSource.cache);
        return;
      }
      if (result != null && result.hasIssues) onIssues?.call(result.issues);
    }
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
      final merged = _apply(
        fetched,
        ContentSource.remote,
        fallbackToExisting: true,
      );
      if (merged != null) {
        // Simpan dataset gabungan yang sudah valid agar dokumen rusak di
        // remote tidak menghapus salinan lokal di cache.
        await cache.write(merged);
        return ContentSource.remote;
      }
    } on Object {
      // Kegagalan jaringan, izin, atau format tidak boleh menggagalkan
      // pemanggil: aplikasi tetap memakai salinan yang sudah ada
      // (PRD §15.2 butir 4). Lihat ContentSource yang dikembalikan.
    }
    return _source ?? ContentSource.bundled;
  }

  PoiDecodeResult? _decodeOrNull(RawDataset raw) {
    try {
      return decodePoiDataset(raw);
    } on FormatException {
      return null;
    }
  }

  /// Memvalidasi lalu memasang [raw] sebagai data aktif.
  ///
  /// Mengembalikan dataset mentah valid hasil gabungan (untuk disimpan ke
  /// cache), atau `null` jika dataset tidak dapat dipakai (bentuk salah, atau
  /// tidak ada satu pun POI yang lolos validasi) sehingga pemanggil dapat jatuh
  /// ke sumber berikutnya.
  RawDataset? _apply(
    RawDataset raw,
    ContentSource source, {
    bool fallbackToExisting = false,
    bool notify = true,
  }) {
    final result = _decodeOrNull(raw);
    if (result == null) return null;
    return _applyDecoded(
      raw,
      result,
      source,
      fallbackToExisting: fallbackToExisting,
      notify: notify,
    );
  }

  RawDataset? _applyDecoded(
    RawDataset raw,
    PoiDecodeResult result,
    ContentSource source, {
    bool fallbackToExisting = false,
    bool notify = true,
  }) {
    if (result.hasIssues) onIssues?.call(result.issues);

    // Dataset tanpa POI valid tidak dipakai: lebih baik memakai salinan
    // lama atau dataset bawaan daripada menampilkan peta tanpa POI.
    if (result.pois.isEmpty) return null;

    final mergedPois = _mergeCollection<Poi>(
      rawEntries: raw['pois'],
      decodedRemote: result.pois,
      existingItems: _pois,
      existingRawById: _rawPoisById,
      idOf: (p) => p.id,
      decodeItem: decodePoi,
      fallbackToExisting: fallbackToExisting,
      hasIssues: result.hasIssues,
    );
    final mergedFacilities = _mergeCollection<Facility>(
      rawEntries: raw['facilities'],
      decodedRemote: result.facilities,
      existingItems: _facilities,
      existingRawById: _rawFacilitiesById,
      idOf: (f) => f.id,
      decodeItem: decodeFacility,
      fallbackToExisting: fallbackToExisting,
      hasIssues: result.hasIssues,
    );

    _pois = List.unmodifiable(mergedPois.items);
    _facilities = List.unmodifiable(mergedFacilities.items);
    _rawPoisById = Map.unmodifiable(mergedPois.rawById);
    _rawFacilitiesById = Map.unmodifiable(mergedFacilities.rawById);
    _source = source;
    if (notify) {
      if (_poiController.hasListener) _poiController.add(_pois);
      if (_facilityController.hasListener) _facilityController.add(_facilities);
    }

    return <String, Object?>{
      'pois': mergedPois.rawList,
      if (raw.containsKey('facilities') || mergedFacilities.rawList.isNotEmpty)
        'facilities': mergedFacilities.rawList,
    };
  }

  /// Menggabungkan hasil validasi [decodedRemote] dengan salinan lokal yang
  /// sudah ada per-ID: dokumen tidak valid diabaikan dan nilai dari salinan
  /// lokal dipakai (PRD §15.2 butir 3), sedangkan dokumen valid memakai versi
  /// baru dan penghapusan sengaja tanpa galat validasi tetap dihormati.
  ({
    List<T> items,
    Map<String, Map<String, Object?>> rawById,
    List<Map<String, Object?>> rawList,
  })
  _mergeCollection<T>({
    required Object? rawEntries,
    required List<T> decodedRemote,
    required List<T> existingItems,
    required Map<String, Map<String, Object?>> existingRawById,
    required String Function(T) idOf,
    required T? Function(Object?, List<PoiDecodeIssue>) decodeItem,
    required bool fallbackToExisting,
    required bool hasIssues,
  }) {
    if (rawEntries == null) {
      return (items: const [], rawById: const {}, rawList: const []);
    }
    if (rawEntries is! List) {
      if (!fallbackToExisting || existingItems.isEmpty) {
        return (items: const [], rawById: const {}, rawList: const []);
      }
      return (
        items: existingItems,
        rawById: existingRawById,
        rawList: [
          for (final existing in existingItems)
            ?existingRawById[idOf(existing)],
        ],
      );
    }

    final validById = <String, T>{
      for (final item in decodedRemote) idOf(item): item,
    };
    final existingById = <String, T>{
      for (final item in existingItems) idOf(item): item,
    };

    final mergedItems = <T>[];
    final mergedRawById = <String, Map<String, Object?>>{};
    final mergedRawList = <Map<String, Object?>>[];
    final emittedIds = <String>{};
    var hasUnidentifiedIssue = false;

    for (final entry in rawEntries) {
      final rawId = entry is Map<String, Object?> ? entry['id'] : null;
      final id = rawId is String && rawId.trim().isNotEmpty ? rawId : null;
      if (id == null) {
        hasUnidentifiedIssue = true;
        continue;
      }
      if (emittedIds.contains(id)) continue;

      final validItem = validById[id];
      if (validItem != null) {
        if (hasIssues && decodeItem(entry, <PoiDecodeIssue>[]) == null) {
          continue;
        }
        final rawMap = entry as Map<String, Object?>;
        emittedIds.add(id);
        mergedItems.add(validItem);
        mergedRawById[id] = rawMap;
        mergedRawList.add(rawMap);
        continue;
      }

      if (fallbackToExisting) {
        final existing = existingById[id];
        if (existing != null) {
          emittedIds.add(id);
          mergedItems.add(existing);
          final existingRaw = existingRawById[id];
          if (existingRaw != null) {
            mergedRawById[id] = existingRaw;
            mergedRawList.add(existingRaw);
          }
        }
      }
    }

    if (fallbackToExisting && hasUnidentifiedIssue) {
      for (final existing in existingItems) {
        final id = idOf(existing);
        if (!emittedIds.add(id)) continue;
        mergedItems.add(existing);
        final existingRaw = existingRawById[id];
        if (existingRaw != null) {
          mergedRawById[id] = existingRaw;
          mergedRawList.add(existingRaw);
        }
      }
    }

    return (items: mergedItems, rawById: mergedRawById, rawList: mergedRawList);
  }

  Future<void> dispose() async {
    await _poiController.close();
    await _facilityController.close();
  }
}

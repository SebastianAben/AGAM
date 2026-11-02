/// Test alur sumber data [PoiRepositoryImpl] (PB03, PRD §15.2).
///
/// Dataset uji di file ini SINTETIS. Dataset bawaan yang asli diuji di
/// `bundled_dataset_test.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:agam/logic/data/poi_repository_impl.dart';
import 'package:agam/logic/data/poi_sources.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> poiDoc(String id, String name) => {
  'id': id,
  'name': name,
  'category': 'lecture',
  'lat': -6.89,
  'lng': 107.61,
  'radiusM': 15,
};

Map<String, Object?> dataset(List<Map<String, Object?>> pois) => {'pois': pois};

/// [AssetBundle] yang melayani satu dataset dari memori.
class _StubBundle extends CachingAssetBundle {
  _StubBundle(this.payload);

  final String payload;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(payload.codeUnits));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => payload;
}

BundledDataset bundledOf(List<Map<String, Object?>> pois) =>
    BundledDataset(bundle: _StubBundle(jsonEncode(dataset(pois))));

class _FixedRemote implements RemoteDatasetSource {
  _FixedRemote(this.value);

  final Map<String, Object?> value;
  int calls = 0;

  @override
  Future<RawDataset> fetch() async {
    calls++;
    return value;
  }
}

class _FailingRemote implements RemoteDatasetSource {
  int calls = 0;

  @override
  Future<RawDataset> fetch() async {
    calls++;
    throw Exception('offline');
  }
}

void main() {
  group('pemuatan pertama', () {
    test('memakai JSON bawaan saat cache kosong', () async {
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: InMemoryDatasetCache(),
      );
      addTearDown(repo.dispose);

      final pois = await repo.watchPois().first;

      expect(pois.single.name, 'Bawaan');
      expect(repo.source, ContentSource.bundled);
    });

    test('memakai cache lokal bila ada', () async {
      final cache = InMemoryDatasetCache();
      await cache.write(dataset([poiDoc('T01', 'Dari cache')]));
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: cache,
      );
      addTearDown(repo.dispose);

      final pois = await repo.watchPois().first;

      expect(pois.single.name, 'Dari cache');
      expect(repo.source, ContentSource.cache);
    });

    test('cache tanpa POI valid diabaikan, jatuh ke bawaan', () async {
      final cache = InMemoryDatasetCache();
      await cache.write(dataset([poiDoc('T01', 'Rusak')..['lat'] = 'x']));
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: cache,
      );
      addTearDown(repo.dispose);

      final pois = await repo.watchPois().first;

      expect(pois.single.name, 'Bawaan');
      expect(repo.source, ContentSource.bundled);
    });

    test(
      'poiById mencari tanpa perlu memanggil watchPois lebih dulu',
      () async {
        final repo = PoiRepositoryImpl(
          bundled: bundledOf([poiDoc('T01', 'Bawaan'), poiDoc('T02', 'Kedua')]),
          cache: InMemoryDatasetCache(),
        );
        addTearDown(repo.dispose);

        expect((await repo.poiById('T02'))!.name, 'Kedua');
        expect(await repo.poiById('T99'), isNull);
      },
    );
  });

  group('refresh', () {
    test('data remote valid dipakai dan disimpan ke cache', () async {
      final cache = InMemoryDatasetCache();
      final remote = _FixedRemote(dataset([poiDoc('T01', 'Dari remote')]));
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: cache,
        remote: remote,
      );
      addTearDown(repo.dispose);

      expect(await repo.refresh(), ContentSource.remote);
      expect((await repo.poiById('T01'))!.name, 'Dari remote');
      expect(await cache.read(), isNotNull);
      expect(remote.calls, 1);
    });

    test('kegagalan jaringan tidak melempar dan tidak mengubah data', () async {
      final remote = _FailingRemote();
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: InMemoryDatasetCache(),
        remote: remote,
      );
      addTearDown(repo.dispose);

      expect(await repo.refresh(), ContentSource.bundled);
      expect((await repo.poiById('T01'))!.name, 'Bawaan');
      expect(remote.calls, 1);
    });

    test(
      'sumber remote yang belum tersedia menyisakan dataset bawaan',
      () async {
        final repo = PoiRepositoryImpl(
          bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
          cache: InMemoryDatasetCache(),
          // Default: UnavailableRemoteSource selama project Firebase belum ada.
        );
        addTearDown(repo.dispose);

        expect(await repo.refresh(), ContentSource.bundled);
      },
    );

    test(
      'dataset remote tanpa POI valid tidak dipakai dan tidak di-cache',
      () async {
        final cache = InMemoryDatasetCache();
        final remote = _FixedRemote(
          dataset([poiDoc('T01', 'Rusak')..['radiusM'] = -5]),
        );
        final repo = PoiRepositoryImpl(
          bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
          cache: cache,
          remote: remote,
        );
        addTearDown(repo.dispose);

        expect(await repo.refresh(), ContentSource.bundled);
        expect((await repo.poiById('T01'))!.name, 'Bawaan');
        expect(await cache.read(), isNull);
      },
    );

    test('dokumen rusak dilaporkan lewat onIssues', () async {
      final issues = <PoiDecodeIssue>[];
      final remote = _FixedRemote(
        dataset([
          poiDoc('T01', 'Valid'),
          poiDoc('T02', 'Rusak')..['lat'] = 'x',
        ]),
      );
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: InMemoryDatasetCache(),
        remote: remote,
        onIssues: issues.addAll,
      );
      addTearDown(repo.dispose);

      await repo.refresh();

      expect(issues.single.id, 'T02');
      expect(issues.single.field, 'lat');
    });

    test('pendengar watchPois menerima data remote', () async {
      final remote = _FixedRemote(dataset([poiDoc('T01', 'Dari remote')]));
      final repo = PoiRepositoryImpl(
        bundled: bundledOf([poiDoc('T01', 'Bawaan')]),
        cache: InMemoryDatasetCache(),
        remote: remote,
      );
      addTearDown(repo.dispose);

      final seen = <String>[];
      final sub = repo.watchPois().listen((pois) => seen.add(pois.single.name));
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await repo.refresh();
      await pumpEventQueue();

      expect(seen, ['Bawaan', 'Dari remote']);
    });
  });

  group('FileDatasetCache', () {
    test('menulis, membaca, lalu menghapus salinan', () async {
      final dir = Directory.systemTemp.createTempSync('agam_cache_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final cache = FileDatasetCache(dir);

      expect(await cache.read(), isNull);

      await cache.write(dataset([poiDoc('T01', 'Tersimpan')]));
      final read = await cache.read();
      expect(((read!['pois'] as List).single as Map)['name'], 'Tersimpan');

      await cache.clear();
      expect(await cache.read(), isNull);
    });

    test('file rusak dibaca sebagai tidak ada', () async {
      final dir = Directory.systemTemp.createTempSync('agam_cache_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/pois_cache.json').writeAsStringSync('{bukan json');

      expect(await FileDatasetCache(dir).read(), isNull);
    });
  });
}

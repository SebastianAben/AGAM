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

Map<String, Object?> poiDoc(String id, String name, {int? trailOrder}) => {
  'id': id,
  'name': name,
  'category': 'lecture',
  'lat': -6.89,
  'lng': 107.61,
  'radiusM': 15,
  'trailOrder': ?trailOrder,
};

Map<String, Object?> facilityDoc(String id, String name) => {
  'id': id,
  'name': name,
  'category': 'toilet',
  'lat': -6.89,
  'lng': 107.61,
};

Map<String, Object?> dataset(
  List<Map<String, Object?>> pois, {
  List<Map<String, Object?>>? facilities,
}) => {'pois': pois, 'facilities': ?facilities};

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

    test('1 dari 10 dokumen POI remote rusak: 10 POI tetap utuh memakai salinan lokal untuk yang rusak dan cache tersimpan bersih', () async {
      final localPois = [
        for (var i = 1; i <= 10; i++)
          poiDoc('P${i.toString().padLeft(2, '0')}', 'Lokal $i', trailOrder: i),
      ];
      final remotePois = [
        for (var i = 1; i <= 10; i++)
          i == 5
              ? (poiDoc('P05', 'Remote rusak', trailOrder: 5)..['lat'] = 'x')
              : poiDoc(
                  'P${i.toString().padLeft(2, '0')}',
                  'Remote $i',
                  trailOrder: i,
                ),
      ];

      final issues = <PoiDecodeIssue>[];
      final cache = InMemoryDatasetCache();
      final repo = PoiRepositoryImpl(
        bundled: bundledOf(localPois),
        cache: cache,
        remote: _FixedRemote(dataset(remotePois)),
        onIssues: issues.addAll,
      );
      addTearDown(repo.dispose);

      expect(await repo.refresh(), ContentSource.remote);
      final pois = await repo.watchPois().first;
      expect(pois, hasLength(10));
      expect(pois.map((p) => p.id).toList(), [
        'P01',
        'P02',
        'P03',
        'P04',
        'P05',
        'P06',
        'P07',
        'P08',
        'P09',
        'P10',
      ]);
      expect((await repo.poiById('P05'))!.name, 'Lokal 5');
      expect((await repo.poiById('P05'))!.trailOrder, 5);
      expect((await repo.poiById('P01'))!.name, 'Remote 1');
      expect((await repo.poiById('P10'))!.name, 'Remote 10');
      expect(issues.single.id, 'P05');

      // Cache harus menyimpan dataset gabungan yang seluruhnya valid.
      final cachedRaw = await cache.read();
      expect(cachedRaw, isNotNull);
      final cachedDecoded = decodePoiDataset(cachedRaw);
      expect(cachedDecoded.hasIssues, isFalse);
      expect(cachedDecoded.pois, hasLength(10));

      // Memuat ulang dari cache (offline) tetap mempertahankan ke-10 POI.
      final reloaded = PoiRepositoryImpl(
        bundled: bundledOf(localPois),
        cache: cache,
      );
      addTearDown(reloaded.dispose);
      final fromCache = await reloaded.watchPois().first;
      expect(fromCache, hasLength(10));
      expect((await reloaded.poiById('P05'))!.name, 'Lokal 5');
      expect((await reloaded.poiById('P01'))!.name, 'Remote 1');
    });

    test('dokumen POI remote rusak tanpa id tetap mempertahankan POI lokal yang hilang', () async {
      final localPois = [poiDoc('P01', 'Lokal 1'), poiDoc('P02', 'Lokal 2')];
      final remotePois = [
        poiDoc('P01', 'Remote 1'),
        {
          'name': 'Tanpa id',
          'category': 'lecture',
          'lat': -6.89,
          'lng': 107.61,
        },
      ];

      final repo = PoiRepositoryImpl(
        bundled: bundledOf(localPois),
        cache: InMemoryDatasetCache(),
        remote: _FixedRemote(dataset(remotePois)),
      );
      addTearDown(repo.dispose);

      expect(await repo.refresh(), ContentSource.remote);
      final pois = await repo.watchPois().first;
      expect(pois.map((p) => p.id), containsAll(['P01', 'P02']));
      expect((await repo.poiById('P01'))!.name, 'Remote 1');
      expect((await repo.poiById('P02'))!.name, 'Lokal 2');
    });

    test(
      'penghapusan sengaja dari remote tanpa galat validasi tetap dihormati',
      () async {
        final repo = PoiRepositoryImpl(
          bundled: bundledOf([
            poiDoc('P01', 'Lokal 1'),
            poiDoc('P02', 'Lokal 2'),
          ]),
          cache: InMemoryDatasetCache(),
          remote: _FixedRemote(dataset([poiDoc('P01', 'Remote 1')])),
        );
        addTearDown(repo.dispose);

        expect(await repo.refresh(), ContentSource.remote);
        final pois = await repo.watchPois().first;
        expect(pois.map((p) => p.id).toList(), ['P01']);
      },
    );

    test(
      'dokumen fasilitas remote rusak jatuh ke salinan lokal per-ID',
      () async {
        final bundled = BundledDataset(
          bundle: _StubBundle(
            jsonEncode(
              dataset(
                [poiDoc('P01', 'Lokal 1')],
                facilities: [
                  facilityDoc('F01', 'Toilet Lokal 1'),
                  facilityDoc('F02', 'Toilet Lokal 2'),
                ],
              ),
            ),
          ),
        );
        final cache = InMemoryDatasetCache();
        final repo = PoiRepositoryImpl(
          bundled: bundled,
          cache: cache,
          remote: _FixedRemote(
            dataset(
              [poiDoc('P01', 'Remote 1')],
              facilities: [
                facilityDoc('F01', 'Toilet Remote 1'),
                facilityDoc('F02', 'Rusak')..['category'] = 'tidakAda',
              ],
            ),
          ),
        );
        addTearDown(repo.dispose);

        expect(await repo.refresh(), ContentSource.remote);
        final facilities = await repo.watchFacilities().first;
        expect(facilities, hasLength(2));
        expect(facilities[0].name, 'Toilet Remote 1');
        expect(facilities[1].name, 'Toilet Lokal 2');

        final cachedDecoded = decodePoiDataset(await cache.read());
        expect(cachedDecoded.hasIssues, isFalse);
        expect(cachedDecoded.facilities, hasLength(2));
      },
    );

    test(
      'cache yang rusak sebagian saat muat awal jatuh ke bawaan per-ID',
      () async {
        final cache = InMemoryDatasetCache();
        await cache.write(
          dataset([
            poiDoc('P01', 'Cache 1'),
            poiDoc('P02', 'Cache rusak')..['lat'] = 'x',
          ]),
        );
        final issues = <PoiDecodeIssue>[];
        final repo = PoiRepositoryImpl(
          bundled: bundledOf([
            poiDoc('P01', 'Bawaan 1'),
            poiDoc('P02', 'Bawaan 2'),
          ]),
          cache: cache,
          onIssues: issues.addAll,
        );
        addTearDown(repo.dispose);

        final pois = await repo.watchPois().first;
        expect(repo.source, ContentSource.cache);
        expect(pois, hasLength(2));
        expect((await repo.poiById('P01'))!.name, 'Cache 1');
        expect((await repo.poiById('P02'))!.name, 'Bawaan 2');
        expect(issues, hasLength(1));
        expect(issues.single.id, 'P02');
      },
    );
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

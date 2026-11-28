import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/data.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mengisi Firestore palsu seperti script `tools/firestore/`: satu dokumen
/// per item dengan ID dokumen = `id`.
Future<void> seed(FakeFirebaseFirestore firestore, RawDataset dataset) async {
  for (final collection in ['pois', 'facilities']) {
    for (final item in (dataset[collection] as List? ?? const [])) {
      final data = item as Map<String, Object?>;
      await firestore
          .collection(collection)
          .doc(data['id']! as String)
          .set(data);
    }
  }
}

void main() {
  final bundledJson = jsonDecode(
    File('assets/data/pois.json').readAsStringSync(),
  ) as Map<String, Object?>;

  test('dataset bawaan yang diunggah utuh terbaca kembali', () async {
    final firestore = FakeFirebaseFirestore();
    await seed(firestore, bundledJson);

    final fetched = await FirestoreDatasetSource(firestore: firestore).fetch();
    final fromRemote = decodePoiDataset(fetched);
    final fromBundle = decodePoiDataset(bundledJson);

    expect(fromRemote.issues, isEmpty);
    expect(
      fromRemote.pois.map((p) => p.id).toList()..sort(),
      fromBundle.pois.map((p) => p.id).toList()..sort(),
    );
    expect(fromRemote.facilities, hasLength(fromBundle.facilities.length));
  });

  test('repository memakai data Firestore setelah refresh', () async {
    final firestore = FakeFirebaseFirestore();
    await seed(firestore, bundledJson);
    final cache = InMemoryDatasetCache();
    final repository = PoiRepositoryImpl(
      bundled: const BundledDataset(),
      cache: cache,
      remote: FirestoreDatasetSource(firestore: firestore),
    );
    TestWidgetsFlutterBinding.ensureInitialized();

    expect(await repository.refresh(), ContentSource.remote);
    expect(await cache.read(), isNotNull);
  });

  test('Firestore kosong tidak menggantikan dataset bawaan', () async {
    final repository = PoiRepositoryImpl(
      bundled: const BundledDataset(),
      cache: InMemoryDatasetCache(),
      remote: FirestoreDatasetSource(firestore: FakeFirebaseFirestore()),
    );
    TestWidgetsFlutterBinding.ensureInitialized();

    expect(await repository.refresh(), ContentSource.bundled);
    expect(await repository.poiById('P01'), isNotNull);
  });
}

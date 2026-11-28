/// Sumber remote dataset dari Firestore (PB03, PRD §15.2–§15.4).
///
/// Isi koleksi `pois` dan `facilities` adalah salinan `assets/data/pois.json`
/// yang diunggah script `tools/firestore/` setelah perubahan masuk `dev`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'poi_sources.dart';

class FirestoreDatasetSource implements RemoteDatasetSource {
  FirestoreDatasetSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Mengambil dari server, bukan dari cache Firestore, agar kegagalan
  /// jaringan terlihat pemanggil dan dataset bawaan/cache aplikasi tetap
  /// dipakai (PRD §15.2 butir 4).
  @override
  Future<RawDataset> fetch() async {
    const options = GetOptions(source: Source.server);
    final pois = await _firestore.collection('pois').get(options);
    final facilities = await _firestore.collection('facilities').get(options);
    return {
      'pois': [for (final doc in pois.docs) doc.data()],
      'facilities': [for (final doc in facilities.docs) doc.data()],
    };
  }
}

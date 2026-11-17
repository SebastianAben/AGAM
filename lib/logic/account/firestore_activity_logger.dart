/// Implementasi asli [ActivityLogger] ke Firestore `activity_logs` (PB22;
/// PRD §15.4–§15.5).
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../contracts/contracts.dart';

/// Dokumen log untuk [event] milik [uid] pada waktu perangkat [now].
///
/// Hanya `uid`, `type`, waktu, dan field event (PRD §15.5). Waktu berupa
/// `at` (timestamp) atau `date` (`YYYY-MM-DD` tanpa jam) sesuai
/// [ActivityEvent.timePrecision]. Bentuk ini yang diperiksa
/// `firestore.rules` (`hasOnly`).
Map<String, Object> activityLogDocument(
  ActivityEvent event, {
  required String uid,
  required DateTime now,
}) => {
  'uid': uid,
  'type': event.type,
  ...switch (event.timePrecision) {
    ActivityTimePrecision.instant => {'at': Timestamp.fromDate(now)},
    ActivityTimePrecision.dateOnly => {'date': activityDate(now)},
  },
  ...event.fields,
};

/// Tanggal lokal perangkat `YYYY-MM-DD`.
String activityDate(DateTime now) {
  final local = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-'
      '${two(local.month)}-${two(local.day)}';
}

/// Menulis log ke Firestore tanpa ditunggu dan tanpa melempar error.
///
/// Saat offline, tulisan diantrekan oleh cache Firestore di perangkat dan
/// terkirim saat online (PRD §15.5). Event diabaikan jika tidak ada akun
/// yang login.
class FirestoreActivityLogger implements ActivityLogger {
  FirestoreActivityLogger({
    required this._currentUid,
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
  }) : _firestoreOverride = firestore,
       _clock = clock ?? DateTime.now;

  final String? Function() _currentUid;
  final FirebaseFirestore? _firestoreOverride;
  final DateTime Function() _clock;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _firestore.collection('activity_logs');

  @override
  void log(ActivityEvent event) {
    final uid = _currentUid();
    if (uid == null) return;
    try {
      final document = activityLogDocument(event, uid: uid, now: _clock());
      unawaited(_logs.add(document).then((_) {}, onError: (Object _) {}));
    } on Object {
      // Log tidak boleh mengganggu aplikasi.
    }
  }

  /// Menunggu log tertunda terkirim, paling lama [timeout]. Dipakai sebelum
  /// logout agar log tidak ditolak setelah akun keluar. Tidak melempar.
  Future<void> flush({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      await _firestore.waitForPendingWrites().timeout(timeout);
    } on Object {
      // Offline atau lambat: log tetap di antrean.
    }
  }

  /// Menghapus seluruh log milik [uid] (hapus akun, PRD §16). Rules hanya
  /// mengizinkan pemilik membaca dan menghapus log miliknya.
  Future<void> deleteAllFor(String uid) async {
    final snapshot = await _logs.where('uid', isEqualTo: uid).get();
    const chunk = 400;
    for (var i = 0; i < snapshot.docs.length; i += chunk) {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs.skip(i).take(chunk)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}

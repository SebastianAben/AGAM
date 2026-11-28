/// Profil `users/{uid}` dan salinan role di perangkat (PB21, PRD §15.3).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../contracts/contracts.dart';
import '../settings/device_settings_store.dart';

/// Profil pengguna di Firestore. Hanya `role` dan `createdAt`; email tidak
/// diduplikasi karena sudah ada di Firebase Auth (PRD §15.3).
abstract interface class ProfileStore {
  Future<void> create({required String uid, required UserRole role});

  /// `null` jika dokumen tidak ada. Gagal karena jaringan dilempar sebagai
  /// [AuthException] dengan [AuthErrorCode.network].
  Future<UserRole?> read(String uid);

  Future<void> delete(String uid);
}

class FirestoreProfileStore implements ProfileStore {
  FirestoreProfileStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<void> create({required String uid, required UserRole role}) => _guard(
    () => _doc(uid)
        .set({'role': role.name, 'createdAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<UserRole?> read(String uid) => _guard(() async {
    final snapshot = await _doc(uid).get();
    return roleFromName(snapshot.data()?['role']);
  });

  @override
  Future<void> delete(String uid) => _guard(() => _doc(uid).delete());

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw AuthException(
        e.code == 'unavailable' ? AuthErrorCode.network : AuthErrorCode.unknown,
      );
    }
  }
}

UserRole? roleFromName(Object? name) {
  for (final role in UserRole.values) {
    if (role.name == name) return role;
  }
  return null;
}

/// Salinan role per akun di perangkat, agar sesi login yang dipulihkan
/// saat cold start tetap berjalan dalam mode pesawat (PB21).
class LocalAccountStore {
  LocalAccountStore({KeyValueStore? store})
    : _store = store ?? SharedPreferencesKeyValueStore();

  final KeyValueStore _store;

  static String roleKeyFor(String uid) => 'account.$uid.role';

  Future<UserRole?> readRole(String uid) async {
    try {
      return roleFromName(await _store.getString(roleKeyFor(uid)));
    } on Exception {
      return null;
    }
  }

  Future<void> saveRole(String uid, UserRole role) =>
      _store.setString(roleKeyFor(uid), role.name);

  Future<void> clear(String uid) => _store.remove(roleKeyFor(uid));
}

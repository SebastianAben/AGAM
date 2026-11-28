import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../contracts/contracts.dart';

/// Stores POI IDs only, scoped to the UID captured when the trigger occurred.
/// Reads, additions, and deletion are serialized to avoid losing check-ins
/// and to let account deletion wait for earlier writes.
class AccountVisitStore {
  AccountVisitStore([SharedPreferences? preferences])
    : _preferences = preferences == null
          ? SharedPreferences.getInstance()
          : Future.value(preferences);

  final Future<SharedPreferences> _preferences;
  Future<void> _pending = Future.value();

  static String _key(String uid) => 'account.$uid.visitedPois';

  Future<Set<String>> read(String uid) => _enqueue(
    (preferences) async =>
        (preferences.getStringList(_key(uid)) ?? const <String>[]).toSet(),
  );

  Future<void> record(String uid, String poiId) => _enqueue((
    preferences,
  ) async {
    final key = _key(uid);
    final ids = (preferences.getStringList(key) ?? const <String>[]).toSet();
    if (ids.add(poiId) && !await preferences.setStringList(key, ids.toList())) {
      throw StateError('Kunjungan belum dapat disimpan.');
    }
  });

  Future<void> clear(String uid) => _enqueue((preferences) async {
    final visitsRemoved = await preferences.remove(_key(uid));
    final trailRemoved = await preferences.remove(_trailKey(uid));
    final startRemoved = await preferences.remove(_trailStartKey(uid));
    if (!visitsRemoved || !trailRemoved || !startRemoved) {
      throw StateError('Progres belum dapat dihapus.');
    }
  });

  static String _trailKey(String uid) => 'account.$uid.trailProgress';

  static String _trailStartKey(String uid) => 'account.$uid.trailStart';

  /// ID POI awal trail milik [uid]: POI terdekat saat trail pertama kali
  /// dimulai (PRD §12). Hanya ID POI yang disimpan, bukan posisi.
  Future<String?> readTrailStart(String uid) => _enqueue(
    (preferences) async => preferences.getString(_trailStartKey(uid)),
  );

  Future<void> saveTrailStart(String uid, String poiId) =>
      _enqueue((preferences) async {
        if (!await preferences.setString(_trailStartKey(uid), poiId)) {
          throw StateError('Awal Trail belum dapat disimpan.');
        }
      });

  Future<({Set<String> ids, DateTime? date})> readTrail(String uid) =>
      _enqueue((preferences) async {
        final raw = preferences.getString(_trailKey(uid));
        if (raw == null) return (ids: <String>{}, date: null);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return (
          ids: (data['ids'] as List).whereType<String>().toSet(),
          date: DateTime.tryParse(data['date'] as String? ?? ''),
        );
      });

  Future<void> saveTrail(String uid, Set<String> ids, DateTime? date) =>
      _enqueue((preferences) async {
        final saved = await preferences.setString(
          _trailKey(uid),
          jsonEncode({
            'ids': ids.toList(),
            'date': date?.toIso8601String().split('T').first,
          }),
        );
        if (!saved) throw StateError('Progres Trail belum dapat disimpan.');
      });

  Future<T> _enqueue<T>(Future<T> Function(SharedPreferences) action) {
    final next = _pending.then((_) async => action(await _preferences));
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}

/// Trail is unavailable until it is wired in bootstrap. `main.dart` still
/// uses this until `DeviceTrailService` (LB) is connected by LA; restored
/// when merging `dev` into `LB` so both builds keep compiling.
class UnavailableTrailService implements TrailService {
  const UnavailableTrailService();

  @override
  TrailProgress get current =>
      const TrailProgress(order: [], visited: {}, active: false);

  @override
  Stream<TrailProgress> get progress => const Stream.empty();

  @override
  Future<void> start() =>
      Future.error(StateError('Orientation Trail belum tersedia.'));

  @override
  Future<void> stop() async {}

  @override
  Future<void> reset() async {}
}

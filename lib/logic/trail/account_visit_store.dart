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
    if (!await preferences.remove(_key(uid))) {
      throw StateError('Progres belum dapat dihapus.');
    }
  });

  Future<T> _enqueue<T>(Future<T> Function(SharedPreferences) action) {
    final next = _pending.then((_) async => action(await _preferences));
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }
}

/// Trail is unavailable until the content team supplies an official order.
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

import 'dart:async';

import '../../contracts/contracts.dart';
import 'account_visit_store.dart';

class DeviceTrailService implements TrailService {
  DeviceTrailService({
    required PoiRepository pois,
    required this.visits,
    required this.currentUid,
    required Stream<dynamic> accounts,
    required this.session,
    required this.navigation,
    required this.map,
    required this.routingAvailable,
    required this.onComplete,
  }) {
    _subscriptions.addAll([
      pois.watchPois().listen(
        (pois) => _background(() async {
          final ordered = pois.where((poi) => poi.trailOrder != null).toList()
            ..sort((a, b) => a.trailOrder!.compareTo(b.trailOrder!));
          _order =
              ordered.length == 10 &&
                  ordered.map((p) => p.id).toSet().length == 10 &&
                  List.generate(
                    10,
                    (i) => ordered[i].trailOrder == i + 1,
                  ).every((valid) => valid)
              ? ordered
              : const [];
          await _restore();
          if (_current.active) {
            if (!_canRoute || _current.isComplete) {
              await _end();
            } else {
              await _routeNext();
            }
          }
        }),
      ),
      accounts.listen((_) => _background(_restore)),
      session.state.listen(
        (state) => _background(() async {
          if (!_current.active) return;
          if (state.mode == SessionMode.trail) {
            await _routeNext();
          } else {
            _emit(active: false);
          }
        }),
      ),
      session.triggers.listen((event) {
        final uid = currentUid();
        if (uid != null &&
            _uid == uid &&
            _current.active &&
            session.current.mode == SessionMode.trail &&
            event.mode == SessionMode.trail) {
          _background(() => _checkIn(uid, event));
        }
      }),
    ]);
  }

  final AccountVisitStore visits;
  final String? Function() currentUid;
  final SessionController session;
  final NavigationController navigation;
  final MapConfig map;
  final bool routingAvailable;
  final void Function() onComplete;
  final _changes = StreamController<TrailProgress>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  Future<void> _pending = Future.value();
  String? _uid;
  List<Poi> _order = const [];
  TrailProgress _current = const TrailProgress(
    order: [],
    visited: {},
    active: false,
  );

  bool get _canRoute =>
      routingAvailable &&
      _order.isNotEmpty &&
      _order.every(
        (poi) =>
            poi.hasSurveyedEntrance && map.isInsideCampus(poi.navigationPoint),
      );

  @override
  TrailProgress get current => _uid == currentUid()
      ? _current
      : TrailProgress(order: _current.order, visited: const {}, active: false);

  @override
  Stream<TrailProgress> get progress => _changes.stream;

  @override
  Future<void> start() => _enqueue(() async {
    await _restore();
    if (_uid == null || !_canRoute || _current.isComplete) {
      throw StateError('Trail belum dapat dimulai.');
    }
    _emit(active: true);
    await _routeNext();
  });

  @override
  Future<void> stop() => _enqueue(_end);

  @override
  Future<void> reset() async {
    final uid = currentUid();
    if (uid != null) await clearAccount(uid);
  }

  Future<void> clearAccount(String uid) => _enqueue(() async {
    if (_uid == uid) await _end();
    await visits.clear(uid);
    if (currentUid() == uid) await _restore();
  });

  Future<void> _restore() async {
    final uid = currentUid();
    final sameAccount = uid == _uid;
    if (!sameAccount && _current.active) await _end();
    final stored = uid == null ? null : await visits.readTrail(uid);
    if (currentUid() != uid) return;
    _uid = uid;
    final order = _order.map((p) => p.id).toList();
    final visited = (stored?.ids ?? const <String>{}).intersection(
      order.toSet(),
    );
    _current = TrailProgress(
      order: List.unmodifiable(order),
      visited: Set.unmodifiable(visited),
      active: sameAccount && _current.active,
      completedAt: order.isNotEmpty && visited.length == order.length
          ? stored?.date
          : null,
    );
    _changes.add(_current);
  }

  Future<void> _checkIn(String uid, PoiTriggerEvent event) async {
    if (_uid != uid ||
        currentUid() != uid ||
        !_current.active ||
        !_current.order.contains(event.poiId) ||
        _current.visited.contains(event.poiId)) {
      return;
    }
    final visited = {..._current.visited, event.poiId};
    final complete = visited.length == _current.total;
    final time = event.triggeredAt.toLocal();
    final date = complete ? DateTime(time.year, time.month, time.day) : null;
    await visits.saveTrail(uid, visited, date);
    if (currentUid() != uid) return;
    _emit(visited: visited, date: date);
    if (complete) {
      onComplete();
      await _end();
    } else {
      await _routeNext();
    }
  }

  Future<void> _routeNext() async {
    if (session.current.mode != SessionMode.trail || _uid != currentUid()) {
      return;
    }
    final id = _current.nextPoiId;
    if (id == null) return;
    final target = NavigationTarget.poi(
      _order.firstWhere((poi) => poi.id == id),
    );
    final current = navigation.current.target;
    if (current?.id != id || current?.point != target.point) {
      await navigation.start(target);
    }
  }

  Future<void> _end() async {
    if (_current.active) _emit(active: false);
    if (session.current.mode == SessionMode.trail) {
      await navigation.stop();
      await session.end();
    }
  }

  void _emit({bool? active, Set<String>? visited, DateTime? date}) {
    _current = TrailProgress(
      order: _current.order,
      visited: visited == null ? _current.visited : Set.unmodifiable(visited),
      active: active ?? _current.active,
      completedAt: date ?? _current.completedAt,
    );
    _changes.add(current);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  void _background(Future<void> Function() action) {
    unawaited(
      _enqueue(action).catchError((Object error, StackTrace stack) {
        _changes.addError(error, stack);
      }),
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _pending;
    await _changes.close();
  }
}

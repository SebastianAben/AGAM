import 'dart:async';
import 'dart:math' as math;

import '../../contracts/contracts.dart';
import 'account_visit_store.dart';

/// Orientation Trail di perangkat (F08, PRD §12).
///
/// Urutan resmi (`trailOrder` 1–10) berbentuk keliling. Saat trail pertama
/// kali dimulai untuk sebuah akun, POI terdekat dengan posisi pengguna
/// menjadi titik awal dan [TrailProgress.order] diputar agar dimulai dari
/// POI itu, lalu berlanjut searah putaran. Titik awal disimpan lokal per
/// akun (hanya ID POI) dan dipilih ulang setelah [reset].
///
/// Posisi diambil dari `LocationService.lastFix`, atau fix berikutnya jika
/// belum ada, dengan batas tunggu [startFixTimeout]. Tanpa fix, trail
/// dimulai dari `trailOrder` 1 dan titik awal itu tetap disimpan agar
/// urutan tidak berubah di tengah progres; hapus progres untuk memilih ulang.
class DeviceTrailService implements TrailService {
  DeviceTrailService({
    required PoiRepository pois,
    required this.location,
    required this.visits,
    required this.currentUid,
    required Stream<dynamic> accounts,
    required this.session,
    required this.navigation,
    required this.map,
    required this.routingAvailable,
    required this.onComplete,
    this.startFixTimeout = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
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
          _background(() => _checkIn(uid, event.poiId, event.triggeredAt));
        }
      }),
      navigation.state.listen((state) {
        final uid = currentUid();
        final target = state.target;
        if (state.status == NavigationStatus.arrived &&
            target != null &&
            target.kind == NavigationTargetKind.poi &&
            uid != null &&
            _uid == uid &&
            _current.active &&
            session.current.mode == SessionMode.trail) {
          _background(
            () => _checkIn(uid, target.id, _clock(), fromArrival: true),
          );
        }
      }),
    ]);
  }

  final LocationService location;
  final AccountVisitStore visits;
  final Duration startFixTimeout;
  final String? Function() currentUid;
  final SessionController session;
  final NavigationController navigation;
  final MapConfig map;
  final bool routingAvailable;
  final void Function() onComplete;
  final DateTime Function() _clock;
  final _changes = StreamController<TrailProgress>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  Future<void> _pending = Future.value();
  String? _uid;
  List<Poi> _order = const [];
  String? _start;
  TrailProgress _current = const TrailProgress(
    order: [],
    visited: {},
    active: false,
  );

  /// Titik akses boleh berupa kandidat yang belum diverifikasi; UI
  /// menandai rutenya sebagai pratinjau.
  bool get _canRoute =>
      routingAvailable &&
      _order.isNotEmpty &&
      _order.every((poi) => map.isInsideCampus(poi.navigationPoint));

  @override
  TrailProgress get current => _uid == currentUid()
      ? _current
      : TrailProgress(order: _current.order, visited: const {}, active: false);

  @override
  Stream<TrailProgress> get progress => _changes.stream;

  /// Pratinjau ID POI tujuan pertama/berikutnya tanpa mengubah state atau
  /// menyimpan titik awal ke perangkat.
  ///
  /// Bila titik awal akun aktif sudah tersimpan, mengembalikan
  /// [TrailProgress.nextPoiId]. Jika belum, memilih POI terdekat dari
  /// [position] (atau `location.lastFix?.position`) dengan rumus jarak yang
  /// sama dengan [_nearestStart], atau POI pertama bila belum ada posisi.
  String? previewFirstStopId([GeoPoint? position]) {
    if (_order.isEmpty) return null;
    if (_uid == currentUid() && _start != null) {
      return _current.nextPoiId;
    }
    return _nearestPoiId(position ?? location.lastFix?.position);
  }

  @override
  Future<void> start() => _enqueue(() async {
    await _restore();
    final uid = _uid;
    if (uid == null || !_canRoute || _current.isComplete) {
      throw StateError('Trail belum dapat dimulai.');
    }
    if (_start == null) {
      final start = await _nearestStart();
      if (currentUid() != uid) throw StateError('Akun berganti.');
      await visits.saveTrailStart(uid, start);
      await _restore();
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
    final start = uid == null ? null : await visits.readTrailStart(uid);
    if (currentUid() != uid) return;
    _uid = uid;
    final official = _order.map((p) => p.id).toList();
    // A start missing from the current dataset is picked again on start().
    final startIndex = start == null ? -1 : official.indexOf(start);
    _start = startIndex < 0 ? null : start;
    final order = [
      ...official.skip(startIndex < 0 ? 0 : startIndex),
      ...official.take(startIndex < 0 ? 0 : startIndex),
    ];
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
    if (!_changes.isClosed) _changes.add(_current);
  }

  String _nearestPoiId(GeoPoint? from) {
    if (from == null) return _order.first.id;
    double distance(Poi poi) => [
      poi.position,
      for (final entrance in poi.entrances) entrance.position,
    ].map(from.distanceTo).reduce(math.min);
    return _order.reduce((a, b) => distance(b) < distance(a) ? b : a).id;
  }

  /// POI dengan titik (pusat gedung atau titik akses) terdekat dari posisi
  /// pengguna; `trailOrder` 1 jika belum ada fix.
  Future<String> _nearestStart() async {
    var fix = location.lastFix;
    if (fix == null) {
      try {
        fix = await location.positions.first.timeout(startFixTimeout);
      } on Object {
        fix = null;
      }
    }
    return _nearestPoiId(fix?.position);
  }

  Future<void> _checkIn(
    String uid,
    String poiId,
    DateTime at, {
    bool fromArrival = false,
  }) async {
    if (_uid != uid ||
        currentUid() != uid ||
        !_current.active ||
        session.current.mode != SessionMode.trail ||
        !_current.order.contains(poiId) ||
        _current.visited.contains(poiId)) {
      return;
    }
    final visited = {..._current.visited, poiId};
    final complete = visited.length == _current.total;
    final time = at.toLocal();
    final date = complete ? DateTime(time.year, time.month, time.day) : null;
    await visits.saveTrail(uid, visited, date);
    if (currentUid() != uid) return;
    _emit(visited: visited, date: date);
    if (complete) {
      onComplete();
      await _end();
    } else if (!fromArrival &&
        navigation.current.status != NavigationStatus.arrived) {
      final currentTarget = navigation.current.target;
      final matchesCurrentTarget =
          currentTarget != null &&
          currentTarget.kind == NavigationTargetKind.poi &&
          currentTarget.id == poiId;
      final hasActiveRoute =
          navigation.current.status != NavigationStatus.idle &&
          navigation.current.status != NavigationStatus.error;
      if (!hasActiveRoute || matchesCurrentTarget) {
        await _routeNext();
      }
    }
  }

  Future<void> _routeNext() async {
    if (session.current.mode != SessionMode.trail || _uid != currentUid()) {
      return;
    }
    final nav = navigation.current;
    // Jangan menimpa ArrivalCard saat pengguna sedang melihat konfirmasi tiba.
    if (nav.status == NavigationStatus.arrived) {
      return;
    }
    final activeStatus =
        nav.status != NavigationStatus.idle &&
        nav.status != NavigationStatus.error;
    final currentTarget = nav.target;
    // Pertahankan rute aktif menuju POI trail yang belum dikunjungi agar
    // tujuan pilihan pengguna tidak ditimpa dan tidak memicu start() ganda.
    if (activeStatus &&
        currentTarget != null &&
        currentTarget.kind == NavigationTargetKind.poi &&
        _current.order.contains(currentTarget.id) &&
        !_current.visited.contains(currentTarget.id)) {
      final currentPoi = _order.firstWhere((poi) => poi.id == currentTarget.id);
      if (currentTarget.id != _current.nextPoiId ||
          currentTarget.point == currentPoi.navigationPoint) {
        return;
      }
    }
    final id = _current.nextPoiId;
    if (id == null) return;
    final target = NavigationTarget.poi(
      _order.firstWhere((poi) => poi.id == id),
    );
    await navigation.start(target);
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
    if (!_changes.isClosed) _changes.add(current);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  void _background(Future<void> Function() action) {
    unawaited(
      _enqueue(action).catchError((Object error, StackTrace stack) {
        if (!_changes.isClosed && _changes.hasListener) {
          _changes.addError(error, stack);
        }
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

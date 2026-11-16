/// Respons per mode saat trigger POI (PRD §9.2 butir 7, PB06/PB08).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import 'trigger_notifier.dart';
import 'poi_trigger_lifecycle.dart';

/// Menjalankan efek samping setiap [PoiTriggerEvent]:
///
/// - [TriggerResponse.full] (Explore/Trail): prompt audio; notifikasi + getar
///   hanya di latar belakang. FE menampilkan kartu saat aplikasi tampil.
///   Jika auto-play narasi aktif, narasi langsung diputar.
/// - [TriggerResponse.brief] (Navigasi): notifikasi ringkas tanpa audio.
///
/// Tombol notifikasi: Dengarkan → narasi; Lihat → [viewRequests] untuk
/// membuka kartu POI (disambungkan FE); Lewati → menutup notifikasi dan
/// menghentikan prompt POI tersebut.
///
/// Saat sesi berakhir (Akhiri, auto-end, atau izin dicabut), seluruh
/// notifikasi trigger dihapus agar tidak tertinggal setelah sesi selesai.
class TriggerResponder {
  TriggerResponder({
    required this._session,
    required this._pois,
    required this._notifier,
    required this._audio,
    required this._settings,
    bool Function()? isAppVisible,
  }) : _isAppVisible = isAppVisible ?? _background;

  static bool _background() => false;
  final bool Function() _isAppVisible;

  final SessionController _session;
  final PoiRepository _pois;
  final TriggerNotifier _notifier;
  final AudioService _audio;
  final SettingsStore _settings;

  int _generation = 0;
  bool _disposed = false;
  final _poiRevisions = <String, int>{};
  final _viewRequests = StreamController<String>.broadcast();
  StreamSubscription<PoiTriggerEvent>? _triggerSubscription;
  StreamSubscription<TriggerActionEvent>? _actionSubscription;
  StreamSubscription<SessionState>? _stateSubscription;
  StreamSubscription<String>? _deactivatedSubscription;

  /// ID POI yang kartunya diminta dibuka pengguna lewat tombol "Lihat".
  Stream<String> get viewRequests => _viewRequests.stream;

  void start() {
    _triggerSubscription ??= _session.triggers.listen(_onTrigger);
    _actionSubscription ??= _notifier.actions.listen(handleAction);
    _stateSubscription ??= _session.state.listen(_onSessionState);
    if (_session case PoiTriggerLifecycle lifecycle) {
      _deactivatedSubscription ??= lifecycle.deactivatedPois.listen(
        _onDeactivated,
      );
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _triggerSubscription?.cancel();
    await _actionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _deactivatedSubscription?.cancel();
    await _viewRequests.close();
  }

  Future<void> _onTrigger(PoiTriggerEvent event) async {
    final generation = _generation;
    final revision = _invalidate(event.poiId);
    bool valid() =>
        !_disposed &&
        generation == _generation &&
        revision == _poiRevisions[event.poiId] &&
        _session.current.isActive;
    if (_disposed || !_session.current.isActive) return;
    final poi = await _pois.poiById(event.poiId);
    if (poi == null || !valid()) {
      return;
    }
    switch (event.response) {
      case TriggerResponse.brief:
        if (!_isAppVisible()) await _notifier.showBrief(poi);
        if (!valid()) {
          await _notifier.dismiss(poi.id);
        }
      case TriggerResponse.full:
        if (!_isAppVisible()) await _notifier.showFull(poi);
        if (!valid()) {
          await _notifier.dismiss(poi.id);
          return;
        }
        final kind = _settings.current.autoPlayNarration
            ? AudioClipKind.narration
            : AudioClipKind.prompt;
        await _audio.play(AudioClip(poiId: poi.id, kind: kind));
    }
  }

  Future<void> _onSessionState(SessionState state) async {
    if (!state.isActive) {
      _generation++;
      await _stopPrompt();
      await _notifier.dismissAll();
    }
  }

  Future<void> handleAction(TriggerActionEvent event) async {
    if (_disposed) return;
    final revision = _invalidate(event.poiId);
    final generation = _generation;
    bool valid() =>
        !_disposed &&
        revision == _poiRevisions[event.poiId] &&
        generation == _generation;
    switch (event.action) {
      case TriggerAction.listen:
        await _notifier.dismiss(event.poiId);
        if (!valid()) return;
        await _audio.play(
          AudioClip(poiId: event.poiId, kind: AudioClipKind.narration),
        );
      case TriggerAction.view:
        await _notifier.dismiss(event.poiId);
        if (valid()) _viewRequests.add(event.poiId);
      case TriggerAction.skip:
        await _notifier.dismiss(event.poiId);
        if (!valid()) return;
        final clip = _audio.current.clip;
        if (clip != null &&
            clip.poiId == event.poiId &&
            clip.kind == AudioClipKind.prompt) {
          await _audio.stop();
        }
    }
  }

  int _invalidate(String id) =>
      _poiRevisions[id] = (_poiRevisions[id] ?? 0) + 1;

  Future<void> _onDeactivated(String id) async {
    _invalidate(id);
    // Stop synchronously starts before awaiting native notification dismissal.
    await _stopPrompt(id);
    await _notifier.dismiss(id);
  }

  Future<void> _stopPrompt([String? id]) async {
    final clip = _audio.current.clip;
    if (clip?.kind == AudioClipKind.prompt &&
        (id == null || clip!.poiId == id)) {
      await _audio.stop();
    }
  }
}

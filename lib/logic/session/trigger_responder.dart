/// Respons per mode saat trigger POI (PRD §9.2 butir 7, PB06/PB08).
library;

import 'dart:async';

import '../../contracts/contracts.dart';
import 'trigger_notifier.dart';

/// Menjalankan efek samping setiap [PoiTriggerEvent]:
///
/// - [TriggerResponse.full] (Explore/Trail): notifikasi + getar, lalu prompt
///   audio; jika auto-play narasi aktif, narasi langsung diputar.
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
  });

  final SessionController _session;
  final PoiRepository _pois;
  final TriggerNotifier _notifier;
  final AudioService _audio;
  final SettingsStore _settings;

  final _viewRequests = StreamController<String>.broadcast();
  StreamSubscription<PoiTriggerEvent>? _triggerSubscription;
  StreamSubscription<TriggerActionEvent>? _actionSubscription;
  StreamSubscription<SessionState>? _stateSubscription;

  /// ID POI yang kartunya diminta dibuka pengguna lewat tombol "Lihat".
  Stream<String> get viewRequests => _viewRequests.stream;

  void start() {
    _triggerSubscription ??= _session.triggers.listen(_onTrigger);
    _actionSubscription ??= _notifier.actions.listen(_onAction);
    _stateSubscription ??= _session.state.listen(_onSessionState);
  }

  Future<void> dispose() async {
    await _triggerSubscription?.cancel();
    await _actionSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _viewRequests.close();
  }

  Future<void> _onTrigger(PoiTriggerEvent event) async {
    final poi = await _pois.poiById(event.poiId);
    if (poi == null) return;
    switch (event.response) {
      case TriggerResponse.brief:
        await _notifier.showBrief(poi);
      case TriggerResponse.full:
        await _notifier.showFull(poi);
        final kind = _settings.current.autoPlayNarration
            ? AudioClipKind.narration
            : AudioClipKind.prompt;
        await _audio.play(AudioClip(poiId: poi.id, kind: kind));
    }
  }

  Future<void> _onSessionState(SessionState state) async {
    if (!state.isActive) await _notifier.dismissAll();
  }

  Future<void> _onAction(TriggerActionEvent event) async {
    switch (event.action) {
      case TriggerAction.listen:
        await _notifier.dismiss(event.poiId);
        await _audio.play(
          AudioClip(poiId: event.poiId, kind: AudioClipKind.narration),
        );
      case TriggerAction.view:
        _viewRequests.add(event.poiId);
      case TriggerAction.skip:
        await _notifier.dismiss(event.poiId);
        final clip = _audio.current.clip;
        if (clip != null &&
            clip.poiId == event.poiId &&
            clip.kind == AudioClipKind.prompt) {
          await _audio.stop();
        }
    }
  }
}

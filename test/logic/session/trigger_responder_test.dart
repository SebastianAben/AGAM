import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/session/trigger_notifier.dart';
import 'package:agam/logic/session/trigger_responder.dart';
import 'package:agam/logic/session/poi_trigger_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

class _ManualSession implements SessionController, PoiTriggerLifecycle {
  final _deactivated = StreamController<String>.broadcast();
  @override
  Stream<String> get deactivatedPois => _deactivated.stream;
  void leave(String id) => _deactivated.add(id);
  final _triggers = StreamController<PoiTriggerEvent>.broadcast();
  final _state = StreamController<SessionState>.broadcast();
  SessionState _current = const SessionState(mode: SessionMode.explore);

  void emitState(SessionState state) {
    _current = state;
    _state.add(state);
  }

  @override
  SessionState get current => _current;

  @override
  Stream<SessionState> get state => _state.stream;

  @override
  Stream<PoiTriggerEvent> get triggers => _triggers.stream;

  void fire(String poiId, TriggerResponse response) => _triggers.add(
    PoiTriggerEvent(
      poiId: poiId,
      mode: response == TriggerResponse.brief
          ? SessionMode.navigation
          : SessionMode.explore,
      response: response,
      triggeredAt: syntheticEpoch,
    ),
  );

  @override
  Future<void> start(SessionMode mode) async {}

  @override
  Future<void> end() async {}
}

class _RecordingNotifier implements TriggerNotifier {
  final calls = <String>[];
  Completer<void>? fullGate;
  final _actions = StreamController<TriggerActionEvent>.broadcast();

  void press(String poiId, TriggerAction action) =>
      _actions.add(TriggerActionEvent(poiId: poiId, action: action));

  @override
  Stream<TriggerActionEvent> get actions => _actions.stream;

  @override
  Future<void> showFull(Poi poi) async {
    calls.add('full:${poi.id}');
    await fullGate?.future;
  }

  @override
  Future<void> showBrief(Poi poi) async => calls.add('brief:${poi.id}');

  @override
  Future<void> dismiss(String poiId) async => calls.add('dismiss:$poiId');

  @override
  Future<void> dismissAll() async => calls.add('dismissAll');
}

void main() {
  late _ManualSession session;
  late _RecordingNotifier notifier;
  late FakeAudioService audio;
  late FakeSettingsStore settings;
  late TriggerResponder responder;
  var visible = false;

  setUp(() {
    visible = false;
    session = _ManualSession();
    notifier = _RecordingNotifier();
    audio = FakeAudioService(tick: const Duration(hours: 1));
    settings = FakeSettingsStore();
    responder = TriggerResponder(
      session: session,
      pois: FakePoiRepository(pois: [syntheticPoi()]),
      notifier: notifier,
      audio: audio,
      settings: settings,
      isAppVisible: () => visible,
    )..start();
  });

  tearDown(() async {
    await responder.dispose();
    audio.dispose();
  });

  test(
    'foreground plays audio without system popup; background keeps popup',
    () async {
      visible = true;
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      expect(notifier.calls, isEmpty);
      expect(audio.current.clip?.kind, AudioClipKind.prompt);
      visible = false;
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      expect(notifier.calls, ['full:synthetic-a']);
      expect(audio.current.clip?.kind, AudioClipKind.prompt);
    },
  );

  test('respons penuh: notifikasi lalu prompt audio', () async {
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    expect(notifier.calls, ['full:synthetic-a']);
    expect(audio.current.clip?.kind, AudioClipKind.prompt);
  });

  test('auto-play aktif: narasi langsung diputar', () async {
    await settings.update(const AppSettings(autoPlayNarration: true));
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    expect(audio.current.clip?.kind, AudioClipKind.narration);
  });

  test(
    'exit dismisses trigger and stops its prompt; next entry plays again',
    () async {
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      session.leave('synthetic-a');
      await pumpEventQueue();
      expect(audio.current.status, PlaybackStatus.idle);
      expect(notifier.calls.last, 'dismiss:synthetic-a');
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      expect(audio.current.clip?.kind, AudioClipKind.prompt);
      expect(audio.current.status, PlaybackStatus.playing);
    },
  );

  test('exit preserves narration explicitly requested by listener', () async {
    await responder.handleAction(
      const TriggerActionEvent(
        poiId: 'synthetic-a',
        action: TriggerAction.listen,
      ),
    );
    session.leave('synthetic-a');
    await pumpEventQueue();
    expect(audio.current.clip?.kind, AudioClipKind.narration);
    expect(audio.current.status, PlaybackStatus.playing);
  });

  test(
    'listen during pending notification cannot be replaced by late prompt',
    () async {
      notifier.fullGate = Completer<void>();
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      await responder.handleAction(
        const TriggerActionEvent(
          poiId: 'synthetic-a',
          action: TriggerAction.listen,
        ),
      );
      notifier.fullGate!.complete();
      await pumpEventQueue();
      expect(audio.current.clip?.kind, AudioClipKind.narration);
    },
  );

  test('exit while notification pending cancels late prompt', () async {
    notifier.fullGate = Completer<void>();
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    session.leave('synthetic-a');
    await pumpEventQueue();
    notifier.fullGate!.complete();
    await pumpEventQueue();
    expect(audio.current.status, PlaybackStatus.idle);
    expect(notifier.calls.last, 'dismiss:synthetic-a');
  });

  test('respons ringkas (Navigasi): notifikasi tanpa audio', () async {
    session.fire('synthetic-a', TriggerResponse.brief);
    await pumpEventQueue();
    expect(notifier.calls, ['brief:synthetic-a']);
    expect(audio.current.status, PlaybackStatus.idle);
  });

  test('POI tidak dikenal diabaikan', () async {
    session.fire('tidak-ada', TriggerResponse.full);
    await pumpEventQueue();
    expect(notifier.calls, isEmpty);
  });

  test('Dengarkan memutar narasi', () async {
    notifier.press('synthetic-a', TriggerAction.listen);
    await pumpEventQueue();
    expect(notifier.calls, ['dismiss:synthetic-a']);
    expect(audio.current.clip?.kind, AudioClipKind.narration);
  });

  test('Lihat meminta kartu POI dibuka', () async {
    final requests = <String>[];
    final sub = responder.viewRequests.listen(requests.add);
    notifier.press('synthetic-a', TriggerAction.view);
    await pumpEventQueue();
    expect(requests, ['synthetic-a']);
    expect(notifier.calls, ['dismiss:synthetic-a']);
    await sub.cancel();
  });

  test('Lewati menutup notifikasi, menghentikan prompt, dan memancarkan '
      'dismissedPois', () async {
    final dismissed = <String>[];
    final sub = responder.dismissedPois.listen(dismissed.add);
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    notifier.press('synthetic-a', TriggerAction.skip);
    await pumpEventQueue();
    expect(notifier.calls.last, 'dismiss:synthetic-a');
    expect(audio.current.status, PlaybackStatus.idle);
    expect(dismissed, ['synthetic-a']);
    await sub.cancel();
  });

  test('Dengarkan dan Lihat tidak memancarkan dismissedPois', () async {
    final dismissed = <String>[];
    final sub = responder.dismissedPois.listen(dismissed.add);
    notifier.press('synthetic-a', TriggerAction.listen);
    notifier.press('synthetic-a', TriggerAction.view);
    await pumpEventQueue();
    expect(dismissed, isEmpty);
    await sub.cancel();
  });

  test('dismissNotification menutup banner notifikasi tanpa menghentikan '
      'narasi atau prompt dan tanpa memancarkan dismissedPois', () async {
    final dismissed = <String>[];
    final sub = responder.dismissedPois.listen(dismissed.add);
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    await responder.handleAction(
      const TriggerActionEvent(
        poiId: 'synthetic-a',
        action: TriggerAction.listen,
      ),
    );
    notifier.calls.clear();

    await responder.dismissNotification('synthetic-a');
    expect(notifier.calls, ['dismiss:synthetic-a']);
    expect(audio.current.clip?.kind, AudioClipKind.narration);
    expect(audio.current.status, PlaybackStatus.playing);
    expect(dismissed, isEmpty);
    await sub.cancel();
  });

  test('dismissForegroundNotifications menutup semua notifikasi trigger '
      'tanpa menghentikan narasi atau prompt', () async {
    final dismissed = <String>[];
    final sub = responder.dismissedPois.listen(dismissed.add);
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    notifier.calls.clear();

    await responder.dismissForegroundNotifications();
    expect(notifier.calls, ['dismissAll']);
    expect(audio.current.clip?.kind, AudioClipKind.prompt);
    expect(audio.current.status, PlaybackStatus.playing);
    expect(dismissed, isEmpty);

    await responder.handleAction(
      const TriggerActionEvent(
        poiId: 'synthetic-a',
        action: TriggerAction.listen,
      ),
    );
    notifier.calls.clear();
    await responder.dismissForegroundNotifications();
    expect(notifier.calls, ['dismissAll']);
    expect(audio.current.clip?.kind, AudioClipKind.narration);
    expect(audio.current.status, PlaybackStatus.playing);
    expect(dismissed, isEmpty);
    await sub.cancel();
  });

  test('Lewati tidak menghentikan narasi yang sedang diputar', () async {
    notifier.press('synthetic-a', TriggerAction.listen);
    await pumpEventQueue();
    notifier.press('synthetic-a', TriggerAction.skip);
    await pumpEventQueue();
    expect(audio.current.clip?.kind, AudioClipKind.narration);
    expect(audio.current.status, PlaybackStatus.playing);
  });

  test('sesi berakhir: seluruh notifikasi trigger dihapus', () async {
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    session.emitState(
      const SessionState.idle(lastEndReason: SessionEndReason.userEnded),
    );
    await pumpEventQueue();
    expect(notifier.calls, ['full:synthetic-a', 'dismissAll']);
  });

  test('auto-end juga menghapus notifikasi trigger', () async {
    session.emitState(
      const SessionState.idle(
        lastEndReason: SessionEndReason.outsideCampusTimeout,
      ),
    );
    await pumpEventQueue();
    expect(notifier.calls, ['dismissAll']);
  });

  test('ganti mode selama sesi tidak menghapus notifikasi', () async {
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    session.emitState(SessionState(mode: SessionMode.navigation));
    await pumpEventQueue();
    expect(notifier.calls, ['full:synthetic-a']);
  });

  test(
    'ending a session while native show is pending cannot start prompt later',
    () async {
      notifier.fullGate = Completer<void>();
      session.fire('synthetic-a', TriggerResponse.full);
      await pumpEventQueue();
      expect(notifier.calls, ['full:synthetic-a']);
      session.emitState(const SessionState.idle());
      await pumpEventQueue();
      notifier.fullGate!.complete();
      await pumpEventQueue();
      expect(audio.current.status, PlaybackStatus.idle);
      expect(notifier.calls, [
        'full:synthetic-a',
        'dismissAll',
        'dismiss:synthetic-a',
      ]);
    },
  );

  test('foreground buttons use the same notifier and audio actions', () async {
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    await responder.handleAction(
      const TriggerActionEvent(
        poiId: 'synthetic-a',
        action: TriggerAction.skip,
      ),
    );
    expect(notifier.calls.last, 'dismiss:synthetic-a');
    expect(audio.current.status, PlaybackStatus.idle);
    await responder.handleAction(
      const TriggerActionEvent(
        poiId: 'synthetic-a',
        action: TriggerAction.listen,
      ),
    );
    expect(audio.current.clip?.kind, AudioClipKind.narration);
  });

  group('LocalTriggerNotifier', () {
    test('pemetaan tombol notifikasi', () {
      expect(LocalTriggerNotifier.actionFor('listen'), TriggerAction.listen);
      expect(LocalTriggerNotifier.actionFor('view'), TriggerAction.view);
      expect(LocalTriggerNotifier.actionFor('skip'), TriggerAction.skip);
      // Mengetuk badan notifikasi membuka kartu.
      expect(LocalTriggerNotifier.actionFor(null), TriggerAction.view);
      expect(LocalTriggerNotifier.actionFor('lain'), isNull);
    });

    test('ID notifikasi stabil dan berbeda untuk P01–P10', () {
      final ids = [
        for (var i = 1; i <= 10; i++)
          LocalTriggerNotifier.notificationIdFor(
            'P${i.toString().padLeft(2, '0')}',
          ),
      ];
      expect(ids.toSet(), hasLength(10));
      expect(LocalTriggerNotifier.notificationIdFor('P01'), ids.first);
      for (final id in ids) {
        expect(id, inInclusiveRange(1000, 1000 + 999999));
      }
    });
  });
}

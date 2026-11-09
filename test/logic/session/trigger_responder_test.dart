import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/session/trigger_notifier.dart';
import 'package:agam/logic/session/trigger_responder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

class _ManualSession implements SessionController {
  final _triggers = StreamController<PoiTriggerEvent>.broadcast();

  @override
  SessionState get current => const SessionState(mode: SessionMode.explore);

  @override
  Stream<SessionState> get state => const Stream.empty();

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
  final _actions = StreamController<TriggerActionEvent>.broadcast();

  void press(String poiId, TriggerAction action) =>
      _actions.add(TriggerActionEvent(poiId: poiId, action: action));

  @override
  Stream<TriggerActionEvent> get actions => _actions.stream;

  @override
  Future<void> showFull(Poi poi) async => calls.add('full:${poi.id}');

  @override
  Future<void> showBrief(Poi poi) async => calls.add('brief:${poi.id}');

  @override
  Future<void> dismiss(String poiId) async => calls.add('dismiss:$poiId');
}

void main() {
  late _ManualSession session;
  late _RecordingNotifier notifier;
  late FakeAudioService audio;
  late FakeSettingsStore settings;
  late TriggerResponder responder;

  setUp(() {
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
    )..start();
  });

  tearDown(() async {
    await responder.dispose();
    audio.dispose();
  });

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
    await sub.cancel();
  });

  test('Lewati menutup notifikasi dan menghentikan prompt', () async {
    session.fire('synthetic-a', TriggerResponse.full);
    await pumpEventQueue();
    notifier.press('synthetic-a', TriggerAction.skip);
    await pumpEventQueue();
    expect(notifier.calls.last, 'dismiss:synthetic-a');
    expect(audio.current.status, PlaybackStatus.idle);
  });

  test('Lewati tidak menghentikan narasi yang sedang diputar', () async {
    notifier.press('synthetic-a', TriggerAction.listen);
    await pumpEventQueue();
    notifier.press('synthetic-a', TriggerAction.skip);
    await pumpEventQueue();
    expect(audio.current.clip?.kind, AudioClipKind.narration);
    expect(audio.current.status, PlaybackStatus.playing);
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

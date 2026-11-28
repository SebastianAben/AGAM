import 'dart:async';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/logic/audio/audio_seek_control.dart';
import 'package:agam/ui/poi_detail_screen.dart';
import 'package:agam/ui/onboarding_screen.dart';
import 'package:agam/ui/profile_preview_screen.dart';
import 'package:agam/ui/widgets/agam_motion.dart';
import 'package:agam/ui/widgets/agam_poi_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: no plugin, GPS, real content or production asset is used here.
const _poi = Poi(
  id: 'synthetic-ui',
  name: 'SINTETIS',
  aliases: [],
  category: PoiCategory.lecture,
  position: GeoPoint(0, 0),
  radiusM: 15,
  entrances: [],
  description: 'SINTETIS deskripsi',
  function: 'SINTETIS fungsi',
  facilities: [],
  trivia: 'SINTETIS trivia',
  media: PoiMedia(narrationAudio: 'synthetic.mp3'),
  metadata: ContentMetadata(
    sources: ['SINTETIS'],
    verifiedAt: null,
    owner: 'SINTETIS',
    assetAttribution: [],
    approved: true,
  ),
);

class _Audio implements AudioService, AudioSeekControl {
  final _events = StreamController<PlaybackState>.broadcast();
  final calls = <String>[];
  @override
  PlaybackState current = const PlaybackState.idle();
  @override
  Stream<PlaybackState> get state => _events.stream;
  void _emit(PlaybackStatus status, {Duration? position}) {
    current = PlaybackState(
      status: status,
      clip: current.clip,
      duration: const Duration(seconds: 60),
      position: position ?? current.position,
    );
    _events.add(current);
  }

  @override
  Future<void> play(AudioClip clip) async {
    calls.add('play:${clip.poiId}');
    current = PlaybackState(
      status: PlaybackStatus.playing,
      clip: clip,
      duration: const Duration(seconds: 60),
    );
    _events.add(current);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _emit(PlaybackStatus.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _emit(PlaybackStatus.playing);
  }

  @override
  Future<void> replay() async {
    calls.add('replay');
    _emit(PlaybackStatus.playing, position: Duration.zero);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    current = const PlaybackState.idle();
    _events.add(current);
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seek');
    _emit(
      current.status,
      position: Duration(milliseconds: position.inMilliseconds.clamp(0, 60000)),
    );
  }

  Future<void> dispose() => _events.close();
}

class _Permissions extends FakePermissionService {
  final calls = <String>[];
  @override
  Future<void> openAppSettings() async => calls.add('appSettings');
  @override
  Future<void> openBatteryOptimizationSettings() async {
    calls.add('batterySettings');
    batteryOptimized = false;
  }
}

void main() {
  testWidgets(
    'panel handle, native scrolling and scrollbar share real extent/offset',
    (tester) async {
      ScrollController? scroll;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgamPoiPanel(
              builder: (context, controller, expanded, toggle, handle) {
                scroll = controller;
                return Material(
                  key: const ValueKey('surface'),
                  child: Column(
                    children: [
                      handle,
                      Expanded(
                        child: Scrollbar(
                          controller: controller,
                          thumbVisibility: true,
                          interactive: true,
                          child: SingleChildScrollView(
                            key: const ValueKey('scroll-body'),
                            controller: controller,
                            child: Column(
                              children: List.generate(
                                60,
                                (i) => SizedBox(
                                  height: 40,
                                  child: Text('SINTETIS $i'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final initial = tester.getRect(find.byKey(const ValueKey('surface')));
      await tester.drag(
        find.bySemanticsLabel('Perluas panel POI'),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final expanded = tester.getRect(find.byKey(const ValueKey('surface')));
      expect(expanded.height, greaterThan(initial.height));
      expect(expanded.bottom, initial.bottom);
      await tester.drag(
        find.byKey(const ValueKey('scroll-body')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(scroll!.offset, greaterThan(0));
      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).interactive,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('Ciutkan panel POI'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('surface'))).height,
        closeTo(initial.height, 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audio transport, seek gesture and autoplay affect shared services',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = _Audio();
      final settings = FakeSettingsStore();
      await tester.pumpWidget(
        MaterialApp(
          home: PoiDetailScreen(
            poi: _poi,
            audio: audio,
            settings: settings,
            onNavigate: () async {},
            checkedIn: false,
            navigationAvailable: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(audio.calls, ['play:synthetic-ui']);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.forward_10_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(audio.current.status, PlaybackStatus.paused);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(audio.calls.last, 'resume');
      await tester.drag(find.byType(Slider), const Offset(50, 0));
      await tester.pumpAndSettle();
      expect(audio.current.position, greaterThan(Duration.zero));
      final before = audio.current.position;
      await tester.tap(find.byIcon(Icons.replay_10_rounded));
      await tester.pumpAndSettle();
      expect(audio.current.position, before - const Duration(seconds: 10));
      await tester.tap(find.byIcon(Icons.replay_rounded));
      await tester.pumpAndSettle();
      expect(audio.current.position, Duration.zero);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.current.autoPlayNarration, isTrue);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();
      expect(audio.current.status, PlaybackStatus.idle);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await audio.dispose();
    },
  );

  testWidgets(
    'onboarding enters after permissions without a second confirmation',
    (tester) async {
      var entered = false;
      final permissions = _Permissions();
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            permissions: permissions,
            onAccessGranted: () => entered = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The permission CTA lives on the last onboarding page.
      expect(find.text('Izinkan Lokasi & Mulai Jelajah'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(entered, isFalse);
      await tester.tap(find.text('Izinkan Lokasi & Mulai Jelajah'));
      await tester.pumpAndSettle();
      expect(entered, isTrue);
      expect(
        await permissions.locationStatus(),
        LocationPermissionStatus.granted,
      );
      expect(
        await permissions.notificationStatus(),
        NotificationPermissionStatus.granted,
      );
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('onboarding pages advance one at a time and back returns', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(permissions: _Permissions())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selamat Datang di AGAM'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Cerita gedung datang sendiri'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Lokasi Anda tetap di ponsel'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Cerita gedung datang sendiri'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding keeps the user in place when location is refused', (
    tester,
  ) async {
    var entered = false;
    final permissions = _Permissions()
      ..locationResult = LocationPermissionStatus.permanentlyDenied;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          permissions: permissions,
          onAccessGranted: () => entered = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Izinkan Lokasi & Mulai Jelajah'));
    await tester.pumpAndSettle();
    expect(find.text('Izin lokasi ditolak'), findsOneWidget);
    await tester.tap(find.text('Buka Pengaturan'));
    await tester.pumpAndSettle();
    expect(permissions.calls, contains('appSettings'));
    expect(entered, isFalse);
    expect(find.text('Ditolak'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding battery row opens settings without blocking entry', (
    tester,
  ) async {
    final permissions = _Permissions();
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(permissions: permissions)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Optimasi baterai'), findsOneWidget);
    await tester.tap(find.text('Atur'));
    await tester.pumpAndSettle();
    expect(permissions.calls, contains('batterySettings'));
    expect(find.byKey(const ValueKey('battery-ok')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings links invoke native permission and battery services', (
    tester,
  ) async {
    final permissions = _Permissions();
    final fake = AppServices.fake(tick: const Duration(hours: 1));
    final services = AppServices(
      permissions: permissions,
      location: fake.location,
      pois: fake.pois,
      session: fake.session,
      audio: fake.audio,
      voice: fake.voice,
      settings: fake.settings,
      auth: fake.auth,
      activity: fake.activity,
      map: fake.map,
      routing: fake.routing,
      navigation: fake.navigation,
      search: fake.search,
      recommendations: fake.recommendations,
      trail: fake.trail,
      facilities: fake.facilities,
    );
    await tester.pumpWidget(
      MaterialApp(home: ProfilePreviewScreen(services: services)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Notifikasi & izin aplikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifikasi & izin aplikasi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pengaturan baterai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengaturan baterai'));
    await tester.pumpAndSettle();
    expect(permissions.calls, ['appSettings', 'batterySettings']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('press feedback preserves tap and respects reduced motion', (
    tester,
  ) async {
    var taps = 0;
    Widget app(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Material(
          child: Center(
            child: AgamPressFeedback(
              child: InkWell(
                onTap: () => taps++,
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Text('Aksi'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Aksi')),
    );
    await tester.pump(const Duration(milliseconds: 70));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .97);
    expect(taps, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.pumpWidget(app(true));
    final reducedGesture = await tester.startGesture(
      tester.getCenter(find.text('Aksi')),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await reducedGesture.up();
    await tester.pumpAndSettle();
    expect(taps, 2);
  });
}

import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/widgets/agam_components.dart';
import 'package:agam/ui/widgets/agam_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _opacityOf(WidgetTester tester, Finder child) => tester
    .widget<Opacity>(find.ancestor(of: child, matching: find.byType(Opacity)))
    .opacity;

void main() {
  testWidgets('two tabs; search on the map; settings behind the account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AgamMainShell(
          services: AppServices.fake(tick: const Duration(hours: 1)),
          internalDemo: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jelajah'), findsOneWidget);
    expect(find.text('Trail'), findsOneWidget);
    expect(find.text('Cari & Rute'), findsNothing);
    expect(find.text('Pengaturan'), findsNothing);
    // The search bar on the map opens the search page with the field ready.
    await tester.tap(find.text('Cari gedung atau fasilitas'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    // A facility chip opens the same page with that category filtering.
    await tester.tap(find.text('Musala'));
    await tester.pumpAndSettle();
    expect(find.text('Data musala belum tersedia.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profil & pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Profil Pengguna'), findsOneWidget);
    expect(find.text('Notifikasi & izin aplikasi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Profil Pengguna'), findsNothing);
    expect(find.text('Jelajah'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reveal waits for play, plays once, and rests on reduced motion',
    (tester) async {
      Widget reveal({required bool play, bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: AgamReveal(play: play, child: const Text('Isi')),
        ),
      );
      await tester.pumpWidget(reveal(play: false));
      await tester.pump(const Duration(seconds: 1));
      expect(_opacityOf(tester, find.text('Isi')), 0);
      await tester.pumpWidget(reveal(play: true));
      await tester.pump(const Duration(milliseconds: 60));
      final midway = _opacityOf(tester, find.text('Isi'));
      expect(midway, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(_opacityOf(tester, find.text('Isi')), 1);
      // Leaving and re-entering the tab must not replay the entrance.
      await tester.pumpWidget(reveal(play: false));
      await tester.pumpWidget(reveal(play: true));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_opacityOf(tester, find.text('Isi')), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(reveal(play: true, reduced: true));
      await tester.pump();
      expect(_opacityOf(tester, find.text('Isi')), 1);
    },
  );

  testWidgets('segmented control reports the tapped segment', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AgamSegmented(
              labels: const ['Semua', 'Belum', 'Selesai'],
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );
    final thumb = find.byType(AnimatedPositioned);
    final start = tester.getRect(thumb).left;
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.getRect(thumb).left, greaterThan(start));
    expect(
      tester.getRect(thumb).center.dx,
      closeTo(tester.getCenter(find.text('Selesai')).dx, 1),
    );
  });
}

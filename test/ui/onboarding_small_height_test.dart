import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: only window sizes are exercised; no content or plugin is used.
void main() {
  // Content cannot fit a window this short, so an overflow stripe is
  // acceptable there; anything else (negative sizes) breaks the tree.
  Future<void> squeeze(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
    final error = tester.takeException();
    expect(
      error == null || '$error'.contains('overflowed'),
      isTrue,
      reason: 'at $size: $error',
    );
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'at $size');
  }

  testWidgets('onboarding survives a window shorter than its sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(permissions: FakePermissionService())),
    );
    await tester.pumpAndSettle();

    await squeeze(tester, const Size(400, 240));
    await squeeze(tester, const Size(400, 60));
    await resize(tester, const Size(400, 800));
    expect(find.text('Selamat Datang di AGAM'), findsOneWidget);

    // The last page uses a taller sheet with its own height rule.
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    await squeeze(tester, const Size(400, 120));
    await resize(tester, const Size(400, 800));
    expect(find.text('Izinkan Lokasi & Mulai Jelajah'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('onboarding fits a landscape phone without layout errors', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 360);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(permissions: FakePermissionService())),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

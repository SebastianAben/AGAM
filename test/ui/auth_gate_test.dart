import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/auth_screen.dart';
import 'package:agam/ui/onboarding_screen.dart';
import 'package:agam/ui/profile_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('signing out from the profile returns to the login screen', (
    tester,
  ) async {
    final services = AppServices.fake();
    await tester.pumpWidget(AgamApp(services: services));
    await _settle(tester, 16);
    expect(find.byType(AuthScreen), findsOneWidget);

    await services.auth.signUp(
      email: 'tamu@contoh.id',
      password: 'rahasia1',
      role: UserRole.pengunjung,
    );
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await _settle(tester);
    await tester.tap(find.text('Izinkan Lokasi & Mulai Jelajah'));
    await _settle(tester);
    expect(find.byType(AgamMainShell), findsOneWidget);

    await tester.tap(find.byTooltip('Profil & pengaturan'));
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.text('Keluar akun'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await _settle(tester, 4);
    await tester.tap(find.text('Keluar akun'));
    await _settle(tester, 4);
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await _settle(tester);

    expect(services.auth.current.isSignedIn, isFalse);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(AgamMainShell), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester, 20);
  });

  testWidgets(
    'restored session with granted location skips onboarding straight to map',
    (tester) async {
      final services = AppServices.fake();
      await services.auth.signUp(
        email: 'maba@itb.ac.id',
        password: 'rahasia1',
        role: UserRole.mahasiswaItb,
      );
      await services.permissions.requestLocation();

      await tester.pumpWidget(AgamApp(services: services));
      await _settle(tester, 16);

      expect(find.byType(AgamMainShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(AuthScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _settle(tester, 20);
    },
  );

  testWidgets('external sign-out closes pushed screens and returns to login', (
    tester,
  ) async {
    final services = AppServices.fake();
    await services.auth.signUp(
      email: 'maba@itb.ac.id',
      password: 'rahasia1',
      role: UserRole.mahasiswaItb,
    );
    await services.permissions.requestLocation();

    await tester.pumpWidget(AgamApp(services: services));
    await _settle(tester, 16);
    await tester.tap(find.byTooltip('Profil & pengaturan'));
    await _settle(tester);
    expect(find.byType(ProfilePreviewScreen), findsOneWidget);

    // Sign out directly via service (simulating external sign-out).
    await services.auth.logout();
    await _settle(tester);

    expect(find.byType(ProfilePreviewScreen), findsNothing);
    expect(find.byType(AgamMainShell), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester, 20);
  });

  testWidgets(
    'profile shows active session mode, GPS status, and resets local progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final services = AppServices.fake(tick: const Duration(hours: 1));
      await services.auth.signUp(
        email: 'maba@itb.ac.id',
        password: 'rahasia1',
        role: UserRole.mahasiswaItb,
      );
      await services.permissions.requestLocation();
      await services.session.start(SessionMode.navigation);

      await tester.pumpWidget(
        MaterialApp(home: ProfilePreviewScreen(services: services)),
      );
      await _settle(tester);

      expect(find.text('Aktif (Akurat)'), findsOneWidget);
      expect(find.text('Sesi Navigasi aktif'), findsOneWidget);

      await tester.ensureVisible(find.text('Akhiri'));
      await tester.pumpAndSettle();
      await tester.runAsync(services.session.end);
      await tester.pumpAndSettle();
      expect(services.session.current.isActive, isFalse);
      expect(find.text('Tidak ada sesi aktif'), findsOneWidget);

      final resetRow = find.byKey(const ValueKey('reset-local-progress'));
      await tester.ensureVisible(resetRow);
      await tester.pumpAndSettle();
      await tester.tap(resetRow);
      await tester.pumpAndSettle();
      expect(find.text('Hapus progres lokal?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Hapus progres'));
      await tester.pumpAndSettle();

      expect(services.auth.current.isSignedIn, isTrue);
      expect(services.trail.current.visited, isEmpty);
      expect(find.text('Progres lokal telah dihapus.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

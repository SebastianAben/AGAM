import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/auth_screen.dart';
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
}

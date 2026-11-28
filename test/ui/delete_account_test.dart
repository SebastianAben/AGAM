import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/auth_screen.dart';
import 'package:agam/ui/profile_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// SINTETIS: fake auth service and synthetic credentials only.
const _email = 'tamu@contoh.id';
const _password = 'rahasia1';

Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Signs up, passes onboarding and opens the delete dialog from UI09.
Future<AppServices> _openDeleteDialog(WidgetTester tester) async {
  final services = AppServices.fake();
  await tester.pumpWidget(AgamApp(services: services));
  await _settle(tester, 16);
  await services.auth.signUp(
    email: _email,
    password: _password,
    role: UserRole.pengunjung,
  );
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await _settle(tester);
  await tester.tap(find.text('Izinkan Lokasi & Mulai Jelajah'));
  await _settle(tester);
  await tester.tap(find.byTooltip('Profil & pengaturan'));
  await _settle(tester);
  final delete = find.byKey(const ValueKey('delete-account'));
  await tester.scrollUntilVisible(
    delete,
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await _settle(tester, 4);
  await tester.tap(delete);
  await _settle(tester, 4);
  expect(find.text('Hapus akun?'), findsOneWidget);
  return services;
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester, 20);
}

final _confirm = find.byKey(const ValueKey('delete-account-confirm'));
final _field = find.byKey(const ValueKey('delete-account-password'));

void main() {
  testWidgets('deleting the account returns to the login screen', (
    tester,
  ) async {
    final services = await _openDeleteDialog(tester);

    // Nothing can be deleted before a password is typed.
    expect(tester.widget<FilledButton>(_confirm).onPressed, isNull);
    await tester.enterText(_field, _password);
    await tester.pump();
    await tester.tap(_confirm);
    await _settle(tester);

    expect(services.auth.current.isSignedIn, isFalse);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(AgamMainShell), findsNothing);
    expect(find.byType(ProfilePreviewScreen), findsNothing);
    expect(find.text('Hapus akun?'), findsNothing);
    // The account itself is gone: the same credentials no longer sign in.
    await expectLater(
      services.auth.login(email: _email, password: _password),
      throwsA(isA<AuthException>()),
    );
    await _tearDown(tester);
  });

  testWidgets('a wrong password keeps the user signed in and says why', (
    tester,
  ) async {
    final services = await _openDeleteDialog(tester);

    await tester.enterText(_field, 'salah123');
    await tester.pump();
    await tester.tap(_confirm);
    await _settle(tester, 4);

    expect(
      find.text('Password salah. Periksa lalu coba lagi.'),
      findsOneWidget,
    );
    expect(find.text('Hapus akun?'), findsOneWidget);
    expect(services.auth.current.isSignedIn, isTrue);
    expect(find.byType(ProfilePreviewScreen), findsOneWidget);

    // Editing the password clears the stale error.
    await tester.enterText(_field, 'salah1234');
    await _settle(tester, 4);
    expect(find.text('Password salah. Periksa lalu coba lagi.'), findsNothing);
    await _tearDown(tester);
  });

  testWidgets('offline deletion shows the connection message', (tester) async {
    final services = await _openDeleteDialog(tester);
    (services.auth as FakeAuthService).offline = true;

    await tester.enterText(_field, _password);
    await tester.pump();
    await tester.tap(_confirm);
    await _settle(tester, 4);

    expect(
      find.textContaining('Butuh koneksi internet untuk menghapus akun'),
      findsOneWidget,
    );
    expect(services.auth.current.isSignedIn, isTrue);
    await _tearDown(tester);
  });

  testWidgets('cancelling leaves the account untouched', (tester) async {
    final services = await _openDeleteDialog(tester);
    final events = (services.activity as FakeActivityLogger).events..clear();

    await tester.enterText(_field, _password);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await _settle(tester, 4);

    expect(find.text('Hapus akun?'), findsNothing);
    expect(find.byType(ProfilePreviewScreen), findsOneWidget);
    expect(services.auth.current.isSignedIn, isTrue);
    expect(services.auth.current.account?.email, _email);
    expect(events, isEmpty);
    await _tearDown(tester);
  });
}

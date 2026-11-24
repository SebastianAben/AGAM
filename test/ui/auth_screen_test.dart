import 'package:agam/contracts/contracts.dart';
import 'package:agam/contracts/fakes/fake_la_services.dart';
import 'package:agam/ui/auth_screen.dart';
import 'package:agam/ui/widgets/agam_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<FakeAuthService> pumpAuth(
    WidgetTester tester, {
    FakeAuthService? auth,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = auth ?? FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        theme: agamTheme(),
        home: AuthScreen(auth: service),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label).first;

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder submit(String label) => find.descendant(
    of: find.byType(FilledButton),
    matching: find.text(label),
  );

  Finder link(String label) =>
      find.descendant(of: find.byType(TextButton), matching: find.text(label));

  testWidgets('empty login shows field errors inline', (tester) async {
    await pumpAuth(tester);

    await tapVisible(tester, submit('Masuk'));

    expect(find.text('Email wajib diisi.'), findsOneWidget);
    expect(find.text('Password wajib diisi.'), findsOneWidget);
  });

  testWidgets('wrong credentials show a banner above the button', (
    tester,
  ) async {
    final auth = await pumpAuth(tester);

    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tester.enterText(field('Password'), 'salah123');
    await tapVisible(tester, submit('Masuk'));

    expect(find.text('Email atau password salah.'), findsOneWidget);
    expect(auth.current.isSignedIn, isFalse);

    // Editing a field clears the stale message.
    await tester.enterText(field('Password'), 'salah1234');
    await tester.pumpAndSettle();
    expect(find.text('Email atau password salah.'), findsNothing);
  });

  testWidgets('register needs consent, then signs up with the chosen role', (
    tester,
  ) async {
    final auth = await pumpAuth(tester);

    await tapVisible(tester, link('Daftar'));
    expect(find.text('Buat akun AGAM'), findsOneWidget);
    expect(find.text('Lupa password?'), findsNothing);

    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tester.enterText(field('Password'), 'rahasia1');
    await tapVisible(tester, find.text('Pengunjung'));
    await tapVisible(tester, submit('Daftar'));

    expect(
      find.text('Setujui pemberitahuan privasi untuk melanjutkan.'),
      findsOneWidget,
    );
    expect(auth.current.isSignedIn, isFalse);

    await tapVisible(tester, find.text(AuthScreen.consentText));
    expect(
      find.text('Setujui pemberitahuan privasi untuk melanjutkan.'),
      findsNothing,
    );
    await tapVisible(tester, submit('Daftar'));

    expect(auth.current.isSignedIn, isTrue);
    expect(auth.current.account!.role, UserRole.pengunjung);
  });

  testWidgets('register enforces the 6 character minimum', (tester) async {
    await pumpAuth(tester);

    await tapVisible(tester, link('Daftar'));
    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tester.enterText(field('Password'), '123');
    await tapVisible(tester, submit('Daftar'));

    expect(find.text('Password minimal 6 karakter.'), findsOneWidget);
  });

  testWidgets('forgot password asks for an email, then confirms', (
    tester,
  ) async {
    await pumpAuth(tester);

    await tapVisible(tester, find.text('Lupa password?'));
    expect(find.text('Masukkan email terlebih dahulu.'), findsOneWidget);

    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tapVisible(tester, find.text('Lupa password?'));
    expect(
      find.text('Jika email terdaftar, tautan reset password telah dikirim.'),
      findsOneWidget,
    );
  });

  testWidgets('offline login explains that a connection is needed', (
    tester,
  ) async {
    await pumpAuth(tester, auth: FakeAuthService()..offline = true);

    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tester.enterText(field('Password'), 'rahasia1');
    await tapVisible(tester, submit('Masuk'));

    expect(
      find.text('Butuh koneksi internet untuk login atau daftar pertama kali.'),
      findsOneWidget,
    );
  });

  testWidgets('password visibility toggles', (tester) async {
    await pumpAuth(tester);

    await tapVisible(tester, find.byTooltip('Tampilkan password'));
    expect(find.byTooltip('Sembunyikan password'), findsOneWidget);
  });

  testWidgets('switching mode keeps what was typed', (tester) async {
    await pumpAuth(tester);

    await tester.enterText(field('Email'), 'tamu@contoh.id');
    await tapVisible(tester, link('Daftar'));
    expect(find.text('tamu@contoh.id'), findsOneWidget);

    await tapVisible(tester, link('Masuk'));
    expect(find.text('tamu@contoh.id'), findsOneWidget);
  });

  testWidgets('login and register are separate pages', (tester) async {
    await pumpAuth(tester);

    expect(find.text('Baru di AGAM?'), findsOneWidget);
    expect(find.text('Daftar sebagai'), findsNothing);

    await tapVisible(tester, link('Daftar'));
    expect(find.text('Selamat datang'), findsNothing);
    expect(find.text('Lupa password?'), findsNothing);
    expect(find.text('Sudah punya akun?'), findsOneWidget);
    expect(find.text('Daftar sebagai'), findsOneWidget);

    await tapVisible(tester, find.byTooltip('Kembali'));
    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('Daftar sebagai'), findsNothing);
  });

  testWidgets('system back on register returns to login', (tester) async {
    await pumpAuth(tester);

    await tapVisible(tester, link('Daftar'));
    expect(find.text('Buat akun AGAM'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang'), findsOneWidget);
  });
}

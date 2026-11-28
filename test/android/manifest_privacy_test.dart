import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Penjaga privasi (PRD §6, A01): manifest aplikasi tidak boleh meminta lokasi
// "sepanjang waktu" dan wajib menghapus izin itu jika disisipkan library.
// Ini memeriksa file sumber; manifest hasil merge tetap perlu diperiksa dari
// build APK.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  test(
    'ACCESS_BACKGROUND_LOCATION hanya muncul dengan tools:node="remove"',
    () {
      final pattern = RegExp(
        r'<uses-permission[^>]*ACCESS_BACKGROUND_LOCATION[^>]*>',
        multiLine: true,
      );
      final matches = pattern.allMatches(manifest).toList();
      expect(matches, hasLength(1));
      expect(matches.single.group(0), contains('tools:node="remove"'));
    },
  );

  test('izin lokasi akurat dan foreground service lokasi dideklarasikan', () {
    expect(manifest, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
    );
  });

  test('izin internet dideklarasikan untuk Firebase', () {
    // Dibutuhkan Firestore dan Firebase Auth (PRD §15). Isi yang boleh
    // dikirim dibatasi PRD §15.5 dan A01, bukan oleh manifest.
    expect(manifest, contains('android.permission.INTERNET'));
  });
}

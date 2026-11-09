import 'package:agam/logic/location/adaptive_interval.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/synthetic.dart';

// SINTETIS. POI di (0, 0) radius 15 m; zona dekat = 15 + 30 = 45 m.
void main() {
  const normal = Duration(seconds: 3);
  const slow = Duration(seconds: 10);
  final pois = [syntheticPoi()];

  test('bergerak di antara POI memakai interval normal', () {
    final policy = AdaptiveIntervalPolicy();
    expect(policy.evaluate(syntheticFix(0, metersNorth: 100), pois), normal);
    expect(policy.evaluate(syntheticFix(3, metersNorth: 120), pois), normal);
  });

  test('lebih dari 200 m dari POI terdekat diperlambat', () {
    final policy = AdaptiveIntervalPolicy();
    expect(policy.evaluate(syntheticFix(0, metersNorth: 201), pois), slow);
    expect(policy.evaluate(syntheticFix(3, metersNorth: 199), pois), normal);
  });

  test('diam ≥30 detik di luar zona dekat diperlambat', () {
    final policy = AdaptiveIntervalPolicy();
    expect(policy.evaluate(syntheticFix(0, metersNorth: 100), pois), normal);
    expect(policy.evaluate(syntheticFix(29, metersNorth: 104), pois), normal);
    expect(policy.evaluate(syntheticFix(30, metersNorth: 96), pois), slow);
  });

  test('bergerak lagi setelah diam kembali ke interval normal', () {
    final policy = AdaptiveIntervalPolicy();
    policy.evaluate(syntheticFix(0, metersNorth: 100), pois);
    expect(policy.evaluate(syntheticFix(40, metersNorth: 100), pois), slow);
    expect(policy.evaluate(syntheticFix(43, metersNorth: 115), pois), normal);
  });

  test('diam di dalam zona dekat POI tetap normal agar dwell tidak putus', () {
    final policy = AdaptiveIntervalPolicy();
    policy.evaluate(syntheticFix(0, metersNorth: 44), pois);
    expect(policy.evaluate(syntheticFix(60, metersNorth: 44), pois), normal);
    policy.evaluate(syntheticFix(61, metersNorth: 10), pois);
    expect(policy.evaluate(syntheticFix(120, metersNorth: 10), pois), normal);
  });

  test('tepat di luar zona dekat (≈56 m) boleh diperlambat saat diam', () {
    final policy = AdaptiveIntervalPolicy();
    policy.evaluate(syntheticFix(0, metersNorth: 56), pois);
    expect(policy.evaluate(syntheticFix(30, metersNorth: 56), pois), slow);
  });

  test('pembacaan tidak akurat tidak mengubah status diam', () {
    final policy = AdaptiveIntervalPolicy();
    policy.evaluate(syntheticFix(0, metersNorth: 100), pois);
    // Lompatan 80 m dengan akurasi 50 m tidak dianggap bergerak.
    policy.evaluate(syntheticFix(10, metersNorth: 180, accuracy: 50), pois);
    expect(
      policy.isStationary(syntheticEpoch.add(const Duration(seconds: 30))),
      isTrue,
    );
  });

  test('tanpa POI memakai interval normal', () {
    final policy = AdaptiveIntervalPolicy();
    expect(policy.evaluate(syntheticFix(0), const []), normal);
  });

  test('reset melupakan titik jangkar', () {
    final policy = AdaptiveIntervalPolicy();
    policy.evaluate(syntheticFix(0, metersNorth: 100), pois);
    policy.reset();
    expect(
      policy.isStationary(syntheticEpoch.add(const Duration(hours: 1))),
      isFalse,
    );
  });
}

import 'package:agam/ui/widgets/agam_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AgamAnimatedSize replaces AnimatedSize on every screen: under reduced
// motion a zero-duration AnimatedSize can re-dirty its own layout and throw
// in debug builds (the APKs used for field tests), so the child is laid out
// directly instead.
void main() {
  Widget host(double height, {required bool reduced}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Center(
        child: AgamAnimatedSize(
          child: SizedBox(key: const Key('box'), width: 10, height: height),
        ),
      ),
    ),
  );

  testWidgets('reduced motion: no AnimatedSize, size changes at once', (
    tester,
  ) async {
    await tester.pumpWidget(host(10, reduced: true));
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.pumpWidget(host(40, reduced: true));
    expect(tester.getSize(find.byKey(const Key('box'))).height, 40);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal motion: the size change is animated', (tester) async {
    await tester.pumpWidget(host(10, reduced: false));
    expect(find.byType(AnimatedSize), findsOneWidget);
    await tester.pumpWidget(host(40, reduced: false));
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getSize(find.byType(AnimatedSize)).height;
    expect(mid, inExclusiveRange(10, 40));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AnimatedSize)).height, 40);
  });
}

import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgamApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      AgamApp(services: AppServices.fake(tick: Duration.zero)),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Masuk'), findsWidgets);
  });
}

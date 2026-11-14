import 'package:agam/contracts/contracts.dart';
import 'package:agam/ui/app.dart';
import 'package:agam/ui/onboarding_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgamApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      AgamApp(services: AppServices.fake(tick: Duration.zero)),
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}

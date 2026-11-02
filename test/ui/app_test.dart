import 'package:agam/ui/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AgamApp renders without crashing', (tester) async {
    await tester.pumpWidget(const AgamApp());

    expect(find.text('AGAM'), findsOneWidget);
  });
}

import 'package:agam/logic/trail/account_visit_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent synthetic check-ins persist once per ID and UID', () async {
    SharedPreferences.setMockInitialValues({});
    final visits = AccountVisitStore();
    await Future.wait([
      visits.record('fixture-a', 'synthetic-poi-1'),
      visits.record('fixture-a', 'synthetic-poi-2'),
      visits.record('fixture-a', 'synthetic-poi-1'),
      visits.record('fixture-b', 'synthetic-poi-3'),
    ]);
    final reopened = AccountVisitStore();
    expect(await reopened.read('fixture-a'), {
      'synthetic-poi-1',
      'synthetic-poi-2',
    });
    expect(await reopened.read('fixture-b'), {'synthetic-poi-3'});
    await reopened.clear('fixture-a');
    expect(await reopened.read('fixture-a'), isEmpty);
    expect(await reopened.read('fixture-b'), {'synthetic-poi-3'});
  });
}

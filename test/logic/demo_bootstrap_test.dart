import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/la_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'demo loads bundled POIs without Firebase or platform storage',
    () async {
      // Firebase dan path_provider sengaja tidak diinisialisasi/dimock.
      final repository = await createLaPoiRepository(bundledOnly: true);
      addTearDown(repository.dispose);

      expect(repository.source, ContentSource.bundled);
      expect(await repository.watchPois().first, hasLength(10));
      expect((await repository.poiById('P01'))?.name, 'Labtek V');
      expect(await repository.refresh(), ContentSource.bundled);
      expect(repository.source, ContentSource.bundled);
    },
  );
}

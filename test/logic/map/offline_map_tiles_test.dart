import 'dart:io';

import 'package:agam/logic/map/agam_map_config.dart';
import 'package:agam/logic/map/offline_map_tiles.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw StateError('Network forbidden during local map rendering');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'renders every bundled vector tile to memory with networking forbidden',
    () async {
      final tiles = await HttpOverrides.runWithHttpOverrides(
        () => OfflineMapTiles.load(AgamMapConfig.internalDemo().style),
        _NoNetwork(),
      );
      expect(tiles.images, hasLength(13));
      expect(tiles.minZoom, 12);
      expect(tiles.maxZoom, 16);
      expect(tiles.images.keys.map((key) => key.$1).toSet(), {
        12,
        13,
        14,
        15,
        16,
      });
      for (final png in tiles.images.values) {
        expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      }
      expect(
        tiles.images.values.any((png) => png.length > tiles.background.length),
        isTrue,
      );
    },
  );
}

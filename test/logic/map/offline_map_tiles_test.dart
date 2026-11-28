import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
        () => OfflineMapTiles.load(AgamMapConfig.campus().style),
        _NoNetwork(),
      );
      final manifest = jsonDecode(
        File('assets/map/ganesha.manifest.json').readAsStringSync(),
      );
      expect(
        tiles.images,
        hasLength(manifest['output']['addressedTiles'] as int),
      );
      expect(tiles.minZoom, 12);
      expect(tiles.maxZoom, 18);
      expect(tiles.images.keys.map((key) => key.$1).toSet(), {
        12,
        13,
        14,
        15,
        16,
        17,
        18,
      });
      for (final png in tiles.images.values) {
        expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final header = ByteData.sublistView(png);
        expect(header.getUint32(16), 512);
        expect(header.getUint32(20), 512);
      }
      expect(
        tiles.images.values.any((png) => png.length > tiles.background.length),
        isTrue,
      );
    },
  );
}

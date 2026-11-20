import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pmtiles/pmtiles.dart' as pm;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vector;

import '../../contracts/models/map.dart';

/// Rasterisasi vektor seluruh arsip kecil AGAM saat load, hanya di memori.
/// Tidak menyimpan cache tile/timestamp akses yang dapat menjadi jejak lokasi.
class OfflineMapTiles {
  OfflineMapTiles._(this.images, this.background, this.minZoom, this.maxZoom);

  final Map<(int, int, int), Uint8List> images;
  final Uint8List background;
  final int minZoom;
  final int maxZoom;

  // Reuse the same bundled pixels across Explore, destination and reroutes.
  // The cache key contains only asset names.
  static final _bundled = <(String, String), Future<OfflineMapTiles>>{};

  static Future<OfflineMapTiles> load(
    MapStyleSource source, {
    AssetBundle? bundle,
  }) {
    if (bundle != null) return _render(source, bundle);
    final key = (source.tilesAssetPath, source.styleAssetPath);
    return _bundled.putIfAbsent(
      key,
      () => _render(source, rootBundle).catchError((
        Object error,
        StackTrace stack,
      ) {
        _bundled.remove(key);
        Error.throwWithStackTrace(error, stack);
      }),
    );
  }

  static Future<OfflineMapTiles> _render(
    MapStyleSource source,
    AssetBundle assets,
  ) async {
    if (!source.tilesAssetPath.startsWith('assets/map/') ||
        !source.styleAssetPath.startsWith('assets/map/')) {
      throw const FormatException('Sumber peta wajib aset lokal AGAM.');
    }
    final style = jsonDecode(
      await assets.loadString(source.styleAssetPath),
    ) as Map<String, dynamic>;
    if (style['glyphs'] != null || style['sprite'] != null) {
      throw const FormatException(
        'Glyph/sprite eksternal tidak diperbolehkan.',
      );
    }
    final theme = vector.ThemeReader().read(style);
    if (theme.tileSources.length != 1 ||
        !theme.tileSources.contains('openmaptiles')) {
      throw const FormatException('Style wajib memakai source openmaptiles.');
    }
    final bytes = await assets.load(source.tilesAssetPath);
    final archive = await pm.PmTilesArchive.fromBytes(
      Uint8List.sublistView(bytes),
    );
    try {
      final entries = archive.root.entries;
      // Pipeline AGAM menghasilkan flat root. Hindari alokasi tak terbatas
      // apabila aset tak sengaja diganti dengan arsip wilayah besar.
      if (entries.any((e) => e.isLeaf) ||
          entries.fold<int>(0, (n, e) => n + e.runLength) > 256) {
        throw const FormatException('Arsip melampaui batas peta lokal AGAM.');
      }
      final renderer = vector.ImageRenderer(theme: theme, scale: 1);
      final factory = vector.TileFactory(theme, const vector.Logger.noop());
      Future<Uint8List> render(vector.VectorTile tile, double zoom) async {
        final image = await renderer.render(
          vector.TileSource(
            tileset: vector.Tileset({'openmaptiles': factory.create(tile)}),
          ),
          zoom: zoom,
        );
        try {
          return await image.toPng();
        } finally {
          image.dispose();
        }
      }

      final images = <(int, int, int), Uint8List>{};
      for (final entry in entries) {
        final data = await archive.tile(entry.tileId);
        final tile = vector.VectorTileReader().read(
          Uint8List.fromList(data.bytes()),
        );
        final png = await render(tile, entry.zxy.z.toDouble());
        for (var id = entry.tileId; id < entry.lastTileId; id++) {
          final xyz = pm.ZXY.fromTileId(id);
          images[(xyz.z, xyz.x, xyz.y)] = png;
        }
      }
      final background = await render(vector.VectorTile(layers: []), 16);
      return OfflineMapTiles._(
        Map.unmodifiable(images),
        background,
        archive.minZoom,
        archive.maxZoom,
      );
    } finally {
      await archive.close();
    }
  }
}

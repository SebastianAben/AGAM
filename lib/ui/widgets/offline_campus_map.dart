import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contracts/contracts.dart';
import '../../logic/map/offline_map_tiles.dart';

class OfflineCampusMap extends StatefulWidget {
  const OfflineCampusMap({
    super.key,
    required this.config,
    required this.pois,
    required this.onSelectPoi,
    this.userPosition,
    this.selectedPoiId,
  });

  final MapConfig config;
  final List<Poi> pois;
  final GeoPoint? userPosition;
  final String? selectedPoiId;
  final ValueChanged<Poi> onSelectPoi;

  @override
  State<OfflineCampusMap> createState() => _OfflineCampusMapState();
}

class _OfflineCampusMapState extends State<OfflineCampusMap> {
  late final _tiles = OfflineMapTiles.load(widget.config.style);
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OfflineMapTiles>(
    future: _tiles,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Peta offline tidak dapat dimuat.'));
      }
      final tiles = snapshot.data;
      if (tiles == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _latLng(widget.config.initialCenter),
              initialZoom: 17,
              minZoom: 14,
              maxZoom: 20,
            ),
            children: [
              TileLayer(
                tileProvider: _MemoryMapProvider(tiles),
                minNativeZoom: tiles.minZoom,
                maxNativeZoom: tiles.maxZoom,
                maxZoom: 20,
                tileDisplay: const TileDisplay.instantaneous(),
              ),
              MarkerLayer(
                markers: [
                  for (final poi in widget.pois)
                    Marker(
                      point: _latLng(poi.position),
                      width: 96,
                      height: 58,
                      child: GestureDetector(
                        onTap: () => widget.onSelectPoi(poi),
                        child: Semantics(
                          button: true,
                          label: 'Buka ${poi.name}',
                          child: Column(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 28,
                                color: poi.id == widget.selectedPoiId
                                    ? const Color(0xFF007C83)
                                    : const Color(0xFF073B82),
                              ),
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Text(
                                  poi.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget.userPosition case final position?)
                    Marker(
                      point: _latLng(position),
                      width: 24,
                      height: 24,
                      child: Semantics(
                        label: 'Posisi perangkat',
                        child: const Icon(
                          Icons.my_location,
                          color: Color(0xFF1553A6),
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: FilledButton.tonalIcon(
              onPressed: () => _controller.move(
                _latLng(widget.userPosition ?? widget.config.initialCenter),
                17,
              ),
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Pusatkan'),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            right: 4,
            child: Material(
              color: Colors.white,
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  _credit(
                    '© OpenStreetMap contributors (ODbL)',
                    'https://www.openstreetmap.org/copyright',
                  ),
                  _credit('© OpenMapTiles', 'https://openmaptiles.org/'),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _credit(String label, String url) => TextButton(
    style: TextButton.styleFrom(
      textStyle: const TextStyle(fontSize: 10, fontFamily: 'PlusJakartaSans'),
      minimumSize: const Size(0, 32),
      padding: const EdgeInsets.symmetric(horizontal: 5),
    ),
    onPressed: () async {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan atribusi tidak dapat dibuka.')),
        );
      }
    },
    child: Text(label),
  );

  LatLng _latLng(GeoPoint point) => LatLng(point.lat, point.lng);
}

/// Seluruh tile sudah dirender dari aset, sebelum pembacaan viewport.
/// Tidak memakai NetworkTileProvider atau cache filesystem vector_map_tiles.
class _MemoryMapProvider extends TileProvider {
  _MemoryMapProvider(this.tiles);
  final OfflineMapTiles tiles;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        tiles.images[(coordinates.z, coordinates.x, coordinates.y)] ??
            tiles.background,
      );
}

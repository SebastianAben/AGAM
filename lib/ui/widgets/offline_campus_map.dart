import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contracts/contracts.dart';
import '../../logic/map/offline_map_tiles.dart';
import 'agam_motion.dart';

class OfflineCampusMap extends StatefulWidget {
  const OfflineCampusMap({
    super.key,
    required this.config,
    required this.pois,
    required this.onSelectPoi,
    this.userPosition,
    this.selectedPoiId,
    this.showPois = true,
    this.initialFocus,
  });

  final GeoPoint? initialFocus;
  final bool showPois;
  final MapConfig config;
  final List<Poi> pois;
  final GeoPoint? userPosition;
  final String? selectedPoiId;
  final ValueChanged<Poi> onSelectPoi;

  @override
  OfflineCampusMapState createState() => OfflineCampusMapState();
}

class OfflineCampusMapState extends State<OfflineCampusMap>
    with SingleTickerProviderStateMixin {
  late final _tiles = OfflineMapTiles.load(widget.config.style);
  final _controller = MapController();
  bool _ready = false;
  late final _motion = AnimationController(vsync: this);
  VoidCallback? _cameraTick;
  GeoPoint? _pendingCenter;

  /// Kamera hanya hidup di memori; tidak menyimpan atau mengirim posisi.
  void focusOn(GeoPoint point) {
    _pendingCenter = point;
    if (_ready) _animateCamera(_latLng(point), 17, _controller.camera.rotation);
  }

  void resetNorth() {
    if (_ready) {
      _animateCamera(_controller.camera.center, _controller.camera.zoom, 0);
    }
  }

  void _animateCamera(LatLng target, double zoom, double rotation) {
    _motion.stop();
    if (_cameraTick case final tick?) _motion.removeListener(tick);
    final duration = AgamMotion.duration(context);
    if (duration == Duration.zero) {
      _controller.move(target, zoom);
      _controller.rotate(rotation);
      return;
    }
    final from = _controller.camera;
    _motion.duration = duration;
    _cameraTick = () {
      final t = AgamMotion.drawer.transform(_motion.value);
      _controller.move(
        LatLng(
          from.center.latitude + (target.latitude - from.center.latitude) * t,
          from.center.longitude +
              (target.longitude - from.center.longitude) * t,
        ),
        from.zoom + (zoom - from.zoom) * t,
      );
      _controller.rotate(from.rotation + (rotation - from.rotation) * t);
    };
    _motion.addListener(_cameraTick!);
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
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
      return Column(
        children: [
          Material(
            color: Colors.white,
            child: Wrap(
              alignment: WrapAlignment.start,
              children: [
                _credit(
                  '© OpenStreetMap contributors (ODbL)',
                  'https://www.openstreetmap.org/copyright',
                ),
                _credit('© OpenMapTiles', 'https://openmaptiles.org/'),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              onPointerDown: (_) => _motion.stop(),
              child: FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _latLng(
                    _pendingCenter ??
                        widget.initialFocus ??
                        widget.config.initialCenter,
                  ),
                  onMapReady: () => _ready = true,
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
                      for (final poi in widget.showPois ? widget.pois : <Poi>[])
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
                          child: IgnorePointer(
                            child: Semantics(
                              label: 'Posisi perangkat',
                              child: const Icon(
                                Icons.my_location,
                                color: Color(0xFF1553A6),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
      textStyle: const TextStyle(
        fontSize: 9,
        letterSpacing: 0,
        fontFamily: 'PlusJakartaSans',
      ),
      minimumSize: const Size(0, 20),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../contracts/contracts.dart';
import '../../logic/map/offline_map_tiles.dart';
import 'agam_motion.dart';
import 'agam_theme.dart';

class OfflineCampusMap extends StatefulWidget {
  const OfflineCampusMap({
    super.key,
    required this.config,
    required this.pois,
    required this.onSelectPoi,
    this.userPosition,
    this.userAccuracyM,
    this.selectedPoiId,
    this.showPois = true,
    this.initialFocus,
    this.attributionPadding = const EdgeInsets.all(10),
  });

  /// Where the map draws the OSM credit; null when the parent places
  /// [MapAttribution] itself, next to its own overlays.
  final EdgeInsets? attributionPadding;
  final GeoPoint? initialFocus;
  final bool showPois;
  final MapConfig config;
  final List<Poi> pois;
  final GeoPoint? userPosition;

  /// Reported accuracy of [userPosition]. Drawn as a circle in metres, as on
  /// Google Maps; a fix too coarse for POI triggers turns the dot grey.
  final double? userAccuracyM;
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
        return const ColoredBox(
          color: AgamColors.fill,
          child: Center(
            child: Text(
              'Peta offline tidak dapat dimuat.',
              style: AgamText.bodySmall,
            ),
          ),
        );
      }
      final tiles = snapshot.data;
      if (tiles == null) {
        return const ColoredBox(
          color: AgamColors.fill,
          child: Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AgamColors.brand,
              ),
            ),
          ),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Listener(
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
                if ((widget.userPosition, widget.userAccuracyM) case (
                  final position?,
                  final accuracy?,
                ))
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _latLng(position),
                        radius: accuracy,
                        useRadiusInMeter: true,
                        color: _dotColor.withValues(alpha: .12),
                        borderColor: _dotColor.withValues(alpha: .35),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final poi in _markerOrder())
                      Marker(
                        point: _latLng(poi.position),
                        width: 116,
                        height: 70,
                        alignment: const Alignment(0, .5),
                        child: _PoiMarker(
                          poi: poi,
                          selected: poi.id == widget.selectedPoiId,
                          onTap: () => widget.onSelectPoi(poi),
                        ),
                      ),
                    if (widget.userPosition case final position?)
                      Marker(
                        point: _latLng(position),
                        width: 24,
                        height: 24,
                        child: IgnorePointer(
                          child: Semantics(
                            label: _accurate
                                ? 'Posisi perangkat'
                                : 'Posisi perangkat, akurasi rendah',
                            child: _UserDot(color: _dotColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.attributionPadding case final padding?)
            Positioned(
              left: padding.left,
              bottom: padding.bottom,
              child: const MapAttribution(),
            ),
        ],
      );
    },
  );

  bool get _accurate => (widget.userAccuracyM ?? 0) <= kTriggerMaxAccuracyM;

  Color get _dotColor => _accurate ? AgamColors.brand : AgamColors.subtle;

  /// The selected POI is drawn last so its marker is never under another.
  List<Poi> _markerOrder() {
    if (!widget.showPois) return const [];
    return [
      for (final poi in widget.pois)
        if (poi.id != widget.selectedPoiId) poi,
      for (final poi in widget.pois)
        if (poi.id == widget.selectedPoiId) poi,
    ];
  }

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

/// A round badge on a white ring with the building name in a pill below.
/// The selected POI grows and turns cyan, scaling from the pin's base.
class _PoiMarker extends StatelessWidget {
  const _PoiMarker({
    required this.poi,
    required this.selected,
    required this.onTap,
  });

  final Poi poi;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Semantics(
      button: true,
      label: 'Buka ${poi.name}',
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        alignment: Alignment.bottomCenter,
        duration: AgamMotion.duration(context, 220),
        curve: AgamMotion.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AgamMotion.duration(context, 220),
              curve: AgamMotion.easeOut,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AgamColors.cyan : AgamColors.brand,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x400B1F44),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 15,
                color: selected ? AgamColors.brandDeep : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // Names collide at the campus overview zoom, so they appear once
            // the user zooms in; the selected POI always keeps its name.
            Builder(
              builder: (context) {
                final visible = selected || MapCamera.of(context).zoom >= 18;
                return IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: AgamMotion.duration(context, 180),
                    curve: AgamMotion.easeOut,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Color(0x260B1F44), blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        poi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: AgamColors.ink,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// The device position: a dot on a white ring. Accuracy is the circle the
/// map draws around it; nothing here loops, so the map can settle.
class _UserDot extends StatelessWidget {
  const _UserDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AgamMotion.duration(context, 240),
    margin: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [BoxShadow(color: Color(0x400B1F44), blurRadius: 6)],
    ),
  );
}

/// The required OpenStreetMap and OpenMapTiles credit.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(10),
    ),
    // Wraps to a second line rather than overflow on narrow screens or
    // with large system text.
    child: Wrap(
      children: [
        _credit(
          context,
          '© OpenStreetMap contributors (ODbL)',
          'https://www.openstreetmap.org/copyright',
        ),
        _credit(context, '© OpenMapTiles', 'https://openmaptiles.org/'),
      ],
    ),
  );

  Widget _credit(BuildContext context, String label, String url) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: AgamColors.muted,
      textStyle: const TextStyle(
        fontSize: 10,
        letterSpacing: 0,
        fontFamily: 'PlusJakartaSans',
      ),
      minimumSize: const Size(0, 26),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),
    onPressed: () async {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan atribusi tidak dapat dibuka.')),
        );
      }
    },
    child: Text(label),
  );
}

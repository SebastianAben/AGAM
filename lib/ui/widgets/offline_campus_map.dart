import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../contracts/contracts.dart';
import '../../logic/map/offline_map_tiles.dart';
import 'agam_motion.dart';
import 'agam_theme.dart';
import 'map_attribution.dart';

export 'map_attribution.dart' show MapAttribution;

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
    this.lockToTileBounds = false,
    this.initialFocus,
    this.highlight,
    this.routePath = const [],
    this.routeLeadIn = false,
    this.onMapReady,
    this.onUserInteract,
    this.attributionPadding = const EdgeInsets.all(10),
  });

  /// Where the map draws the OSM credit; null when the parent places
  /// [MapAttribution] itself, next to its own overlays.
  final EdgeInsets? attributionPadding;
  final GeoPoint? initialFocus;
  final List<GeoPoint> routePath;

  /// Whether the first piece of [routePath] is the unmapped straight walk
  /// from the user to the path or a building door. It is drawn as thin grey
  /// dots, apart from the route, so the map does not suggest a mapped way
  /// across a building.
  final bool routeLeadIn;
  final VoidCallback? onMapReady;

  /// Called when the user starts moving the map by hand: a drag, a fling,
  /// a pinch, a rotation or a double-tap zoom. Camera moves made in code
  /// ([focusOn], [flyTo], [follow], [fitPoints]) never call it, so a screen
  /// can stop following the user without its own moves turning that off.
  final VoidCallback? onUserInteract;

  /// A non-POI place to point at, such as a facility chosen as a
  /// destination. Drawn like a selected POI, with its own icon and label.
  final MapHighlight? highlight;
  final bool showPois;
  final bool lockToTileBounds;
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
  _OfflineViewportConstraint? _tileConstraint;

  void _onMapReady() {
    if (!mounted) return;
    _ready = true;
    if (widget.lockToTileBounds) _containViewport();
    widget.onMapReady?.call();
  }

  /// Sources that only a finger (or a mouse) produces. Code moves report
  /// `mapController` or `fitCamera`, and a resize `nonRotatedSizeChange`;
  /// a whitelist keeps those from ever reading as the user's own gesture.
  static const _gestureSources = {
    MapEventSource.dragStart,
    MapEventSource.onDrag,
    MapEventSource.multiFingerGestureStart,
    MapEventSource.onMultiFinger,
    MapEventSource.doubleTap,
    MapEventSource.doubleTapHold,
    MapEventSource.doubleTapZoomAnimationController,
    MapEventSource.flingAnimationController,
    MapEventSource.scrollWheel,
    MapEventSource.cursorKeyboardRotation,
  };

  void _onMapEvent(MapEvent event) {
    // flutter_map updates the viewport dimensions before emitting this
    // event, without applying the camera constraint to the new size.
    if (event is MapEventNonRotatedSizeChange && widget.lockToTileBounds) {
      _containViewport();
    }
    final gestureStart =
        event is MapEventMoveStart ||
        event is MapEventFlingAnimationStart ||
        event is MapEventRotateStart ||
        event is MapEventDoubleTapZoomStart ||
        event is MapEventScrollWheelZoom;
    if (gestureStart && _gestureSources.contains(event.source)) {
      widget.onUserInteract?.call();
    }
  }

  void _containViewport() {
    final camera = _controller.camera;
    _controller.move(camera.center, camera.zoom);
  }

  /// Kamera hanya hidup di memori; tidak menyimpan atau mengirim posisi.
  void focusOn(GeoPoint point) {
    _pendingCenter = point;
    if (_ready) _animateCamera(_latLng(point), 17, _controller.camera.rotation);
  }

  /// Travels the camera from where it is to [point] as one continuous move,
  /// so the viewer sees where the new place lies relative to the old one.
  ///
  /// Longer trips take longer (450–650 ms) and lift the zoom a little at
  /// mid-flight so the campus between both places stays readable. Returns
  /// the flight time: zero before the map is ready or under reduced motion.
  Duration flyTo(GeoPoint point, {double zoom = 17}) {
    _pendingCenter = point;
    if (!_ready) return Duration.zero;
    final camera = _controller.camera;
    final target = _latLng(point);
    final metres = const Distance().as(LengthUnit.Meter, camera.center, target);
    final duration = AgamMotion.duration(
      context,
      (420 + metres * .35).clamp(450, 650).round(),
    );
    _animateCamera(
      target,
      zoom,
      camera.rotation,
      duration: duration,
      curve: AgamMotion.travel,
      lift: metres < 80 ? 0 : (metres / 500).clamp(0.0, .8),
    );
    return duration;
  }

  /// Keeps the camera on a walker: a short glide to [point] at the current
  /// zoom and rotation, so the user's own zoom level is kept.
  ///
  /// A longer camera move still in flight (the start of the walk, a
  /// recenter) is left to finish; the next fix catches up. Reduced motion
  /// moves without a glide.
  void follow(GeoPoint point) {
    _pendingCenter = point;
    if (!_ready || _motion.isAnimating) return;
    final camera = _controller.camera;
    _animateCamera(
      _latLng(point),
      camera.zoom,
      camera.rotation,
      duration: AgamMotion.duration(context, 280),
      curve: AgamMotion.easeOut,
    );
  }

  void resetNorth() {
    if (_ready) {
      _animateCamera(_controller.camera.center, _controller.camera.zoom, 0);
    }
  }

  void fitPoints(List<GeoPoint> points, {required EdgeInsets padding}) {
    if (!_ready || points.isEmpty) return;
    _motion.stop();
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points.map(_latLng).toList(),
        padding: padding,
        maxZoom: 19,
      ),
    );
  }

  void _animateCamera(
    LatLng target,
    double zoom,
    double rotation, {
    Duration? duration,
    Curve curve = AgamMotion.drawer,
    double lift = 0,
  }) {
    _motion.stop();
    if (_cameraTick case final tick?) _motion.removeListener(tick);
    duration ??= AgamMotion.duration(context);
    if (duration == Duration.zero) {
      _controller.move(target, zoom);
      _controller.rotate(rotation);
      return;
    }
    final from = _controller.camera;
    _motion.duration = duration;
    _cameraTick = () {
      final raw = _motion.value;
      final t = curve.transform(raw);
      _controller.move(
        LatLng(
          from.center.latitude + (target.latitude - from.center.latitude) * t,
          from.center.longitude +
              (target.longitude - from.center.longitude) * t,
        ),
        // The lift peaks at mid-flight and is gone on arrival.
        from.zoom + (zoom - from.zoom) * t - lift * 4 * raw * (1 - raw),
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
            onPointerDown: (_) {
              _motion.stop();
              MapAttribution.notifyMapTouched();
            },
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _latLng(
                  _pendingCenter ??
                      widget.initialFocus ??
                      widget.config.initialCenter,
                ),
                onMapReady: _onMapReady,
                onMapEvent: _onMapEvent,
                initialZoom: 17,
                minZoom: 14,
                maxZoom: 20,
                cameraConstraint: widget.lockToTileBounds
                    ? (_tileConstraint ??= _OfflineViewportConstraint(
                        LatLngBounds(tiles.southWest, tiles.northEast),
                      ))
                    : const CameraConstraint.unconstrained(),
              ),
              children: [
                TileLayer(
                  tileProvider: _MemoryMapProvider(tiles),
                  minNativeZoom: tiles.minZoom,
                  maxNativeZoom: tiles.maxZoom,
                  maxZoom: 20,
                  tileDisplay: const TileDisplay.instantaneous(),
                ),
                if (widget.routePath.length >= 2)
                  PolylineLayer(
                    simplificationTolerance: 0,
                    polylines: [
                      if (widget.routeLeadIn)
                        Polyline(
                          points: [
                            _latLng(widget.routePath[0]),
                            _latLng(widget.routePath[1]),
                          ],
                          pattern: const StrokePattern.dotted(spacingFactor: 2),
                          color: AgamColors.muted,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                        ),
                      if (!widget.routeLeadIn || widget.routePath.length > 2)
                        Polyline(
                          points: widget.routePath
                              .skip(widget.routeLeadIn ? 1 : 0)
                              .map(_latLng)
                              .toList(),
                          pattern: StrokePattern.dashed(
                            segments: const [10, 8],
                            patternFit: PatternFit.appendDot,
                          ),
                          color: AgamColors.brand,
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                          strokeCap: StrokeCap.round,
                        ),
                    ],
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
                        child: _MarkerEntrance(
                          key: ValueKey('poi-${poi.id}'),
                          animate: _ready,
                          child: _PoiMarker(
                            poi: poi,
                            selected: poi.id == widget.selectedPoiId,
                            onTap: () => widget.onSelectPoi(poi),
                          ),
                        ),
                      ),
                    if (widget.highlight case final highlight?)
                      Marker(
                        point: _latLng(highlight.point),
                        width: 116,
                        height: 70,
                        alignment: const Alignment(0, .5),
                        child: _MarkerEntrance(
                          key: ValueKey(
                            'highlight-${highlight.point.lat},'
                            '${highlight.point.lng}',
                          ),
                          animate: _ready,
                          child: _HighlightMarker(highlight: highlight),
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

class _OfflineViewportConstraint extends CameraConstraint {
  _OfflineViewportConstraint(this.bounds)
    : _contain = CameraConstraint.contain(bounds: bounds);

  final LatLngBounds bounds;
  final CameraConstraint _contain;

  @override
  MapCamera? constrain(MapCamera camera) {
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) return camera;

    final northEast = camera.project(bounds.northEast);
    final southWest = camera.project(bounds.southWest);
    // The rotated viewport's bounding rectangle must still fit. Leave one
    // pixel of slack for rounding when the fitted zoom is at the limit.
    final scale = math.max(
      (camera.size.x + 1) / (northEast.x - southWest.x),
      (camera.size.y + 1) / (southWest.y - northEast.y),
    );
    final fitted = scale > 1 + 1e-9
        ? camera.withPosition(
            zoom: camera.clampZoom(camera.getScaleZoom(scale)),
          )
        : camera;
    final bounded = _contain.constrain(fitted);
    if (bounded == null) return null;
    // Avoid moving an already clamped center again due to projection rounding.
    if ((bounded.center.latitude - fitted.center.latitude).abs() < 1e-10 &&
        (bounded.center.longitude - fitted.center.longitude).abs() < 1e-10) {
      return fitted;
    }
    return bounded;
  }
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
/// A marker that appears after the map is on screen grows in from 90 % and
/// fades in from its tip, so it reads as placed on the ground. Markers
/// present when the map first draws are shown as they are.
class _MarkerEntrance extends StatelessWidget {
  const _MarkerEntrance({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: animate ? 0 : 1, end: 1),
    duration: AgamMotion.duration(context, 240),
    curve: AgamMotion.easeOut,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.scale(
        scale: .9 + .1 * t,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    ),
  );
}

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

/// A place on the map that is not a POI, e.g. a facility destination.
class MapHighlight {
  const MapHighlight({
    required this.point,
    required this.label,
    required this.icon,
  });

  final GeoPoint point;
  final String label;
  final IconData icon;
}

/// Same shape as a selected POI marker, but not tappable: it only shows
/// where the destination is.
class _HighlightMarker extends StatelessWidget {
  const _HighlightMarker({required this.highlight});

  final MapHighlight highlight;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: highlight.label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AgamColors.cyan,
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
            child: Icon(highlight.icon, size: 17, color: AgamColors.brandDeep),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x260B1F44), blurRadius: 6),
              ],
            ),
            child: Text(
              highlight.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AgamColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

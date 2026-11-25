import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/activity.dart';
import '../contracts/models/content.dart';
import '../contracts/models/audio.dart';
import '../contracts/models/location.dart';
import '../contracts/models/session.dart';
import '../contracts/services/la_services.dart';
import '../logic/location/device_location_service.dart';
import '../logic/location/position_source.dart';
import '../logic/session/trigger_notifier.dart';
import '../logic/session/poi_trigger_lifecycle.dart';
import 'poi_detail_screen.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_poi_panel.dart';
import 'widgets/agam_theme.dart';
import 'widgets/facility_labels.dart';
import 'widgets/offline_campus_map.dart';
import 'widgets/recommendation_card.dart';

/// UI02 Explore Map. UI03 trigger and UI04 detail are states layered over it.
class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({
    super.key,
    required this.services,
    this.embedded = false,
    this.isActive = true,
    this.onTabSelected,
    this.poiViewRequests = const Stream.empty(),
    this.poiMapRequests = const Stream.empty(),
    this.internalDemo = false,
    this.onPoiAction,
    this.onAutomaticPoi,
    this.onOpenSearch,
    this.onRoute,
    this.onStartRoute,
  });

  final VoidCallback? onAutomaticPoi;

  /// Opens the search page, optionally filtered to one facility category.
  /// Without it the map shows no search bar.
  final ValueChanged<FacilityCategory?>? onOpenSearch;

  /// Starts the route flow to a POI. Without it, or in the internal demo
  /// where the campus graph is missing, "Rute" explains it is unavailable.
  final ValueChanged<Poi>? onRoute;

  /// Starts navigating to a POI in one tap (a recommendation, Rute on the
  /// POI detail). Falls back to [onRoute] when not given.
  final ValueChanged<Poi>? onStartRoute;

  ValueChanged<Poi>? get _startRoute => onStartRoute ?? onRoute;
  final AppServices services;
  final bool embedded;
  final bool isActive;
  final ValueChanged<int>? onTabSelected;
  final Stream<String> poiViewRequests;
  final Stream<String> poiMapRequests;
  final bool internalDemo;
  final Future<void> Function(String, TriggerAction)? onPoiAction;

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen>
    with WidgetsBindingObserver {
  final _mapKey = GlobalKey<OfflineCampusMapState>();
  bool _showPois = true;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<LocationFix>? _locationSubscription;
  List<Poi> _pois = const [];
  List<Facility> _nearbyFacilities = const [];
  LocationFix? _fix;
  Poi? _selectedPoi;
  bool _sessionActive = false;
  bool _showDetail = false;
  String? _triggeredPoiId;
  // A POI the user opened from the map panel, not from a trigger.
  String? _panelViewId;
  bool _changingSession = false;
  bool _openingDetail = false;
  bool _appVisible = true;
  final _activeTriggerIds = <String>{};
  String? _locationMessage;
  // UI07 after a POI panel is closed; the counter drops late answers once
  // a panel opens again or the card is dismissed.
  RecommendationView? _recommendation;
  int _recommendRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appVisible =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (widget.services.location case DeviceLocationService device) {
      _subscriptions.add(
        device.issues.listen((issue) {
          if (!mounted) return;
          setState(() {
            _fix = null;
            _locationMessage = switch (issue) {
              LocationIssue.permissionDenied =>
                'Izin lokasi dicabut. Izinkan lokasi akurat.',
              LocationIssue.serviceDisabled =>
                'GPS perangkat mati. Aktifkan lokasi.',
              LocationIssue.other => 'Posisi belum tersedia. Coba lagi.',
            };
          });
        }),
      );
    }
    _sessionActive = widget.services.session.current.isActive;
    if (widget.services.session case PoiTriggerLifecycle lifecycle) {
      _subscriptions.add(
        lifecycle.deactivatedPois.listen((id) {
          _activeTriggerIds.remove(id);
          if (!mounted || _triggeredPoiId != id) return;
          setState(() {
            _triggeredPoiId = null;
            _showDetail = false;
          });
          _showNearestTrigger();
        }),
      );
    }
    _subscriptions.add(widget.poiViewRequests.listen(_openPoiById));
    _subscriptions.add(
      widget.poiMapRequests.listen((id) async {
        final poi = await widget.services.pois.poiById(id);
        if (!mounted || poi == null) return;
        setState(() {
          _selectedPoi = poi;
          _triggeredPoiId = null;
          _showPois = true;
          _showDetail = false;
          _clearRecommendation();
        });
        _mapKey.currentState?.focusOn(poi.position);
      }),
    );
    _subscriptions.add(
      widget.services.pois.watchPois().listen((pois) {
        if (!mounted) return;
        setState(() {
          _pois = pois;
          _selectedPoi ??= _findPoi('P01');
        });
        _loadFacilities();
      }),
    );
    _syncLocationSubscription();
    _subscriptions.add(
      widget.services.session.state.listen((state) {
        if (!mounted) return;
        setState(() {
          _sessionActive = state.isActive;
          if (!state.isActive) {
            _activeTriggerIds.clear();
            if (_triggeredPoiId != null) _showDetail = false;
            _triggeredPoiId = null;
          }
        });
      }),
    );
    _subscriptions.add(
      widget.services.session.triggers.listen((event) {
        if (!mounted) return;
        if (event.response != TriggerResponse.full) return;
        _activeTriggerIds.add(event.poiId);
        _showNearestTrigger();
      }),
    );
  }

  @override
  void didUpdateWidget(covariant ExploreMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncLocationSubscription();
    }
  }

  void _syncLocationSubscription() {
    if (widget.isActive && _appVisible) {
      _locationSubscription ??= widget.services.location.positions.listen((
        fix,
      ) {
        if (!mounted) return;
        setState(() {
          _fix = fix;
          _locationMessage = null;
        });
      });
    } else {
      final subscription = _locationSubscription;
      _locationSubscription = null;
      unawaited(subscription?.cancel());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    if (!_appVisible && mounted) setState(() => _fix = null);
    _syncLocationSubscription();
    if (_appVisible) _showNearestTrigger();
  }

  void _showNearestTrigger() {
    if (!mounted || !_appVisible || !_sessionActive) return;
    final candidates = _pois
        .where((poi) => _activeTriggerIds.contains(poi.id))
        .toList();
    if (candidates.isEmpty) return;
    final position = widget.services.location.lastFix?.position;
    if (position != null) {
      candidates.sort((a, b) {
        final comparison = position
            .distanceTo(a.position)
            .compareTo(position.distanceTo(b.position));
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
    }
    final poi = candidates.first;
    setState(() {
      _selectedPoi = poi;
      _triggeredPoiId = poi.id;
      _showDetail = true;
      _clearRecommendation();
    });
    widget.onAutomaticPoi?.call();
    _loadFacilities();
  }

  Poi? _findPoi(String id) {
    for (final poi in _pois) {
      if (poi.id == id) return poi;
    }
    return null;
  }

  Future<void> _loadFacilities() async {
    final poi = _selectedPoi;
    if (poi == null || widget.internalDemo) return;
    // Ask for every facility, then keep the nearest one per category.
    final facilities = await widget.services.facilities.nearby(
      from: poi.position,
      limit: 1000,
    );
    if (mounted) {
      setState(() => _nearbyFacilities = nearestPerCategory(facilities));
    }
  }

  Future<void> _toggleSession() async {
    if (_changingSession) return;
    setState(() => _changingSession = true);
    try {
      if (_sessionActive) {
        await widget.services.session.end();
      } else {
        final permission = await widget.services.permissions.requestLocation();
        if (!mounted) return;
        if (permission != LocationPermissionStatus.granted) {
          _showNotice(
            permission == LocationPermissionStatus.serviceDisabled
                ? 'Aktifkan GPS perangkat untuk memulai Explore.'
                : 'Izin lokasi akurat saat aplikasi digunakan diperlukan.',
          );
          return;
        }
        await widget.services.session.start(SessionMode.explore);
      }
    } catch (_) {
      if (mounted) {
        _showNotice('Sesi belum dapat diubah. Periksa izin lokasi dan GPS.');
      }
    } finally {
      if (mounted) setState(() => _changingSession = false);
    }
  }

  Future<void> _openPoiById(String id) async {
    // Requests come from a trigger's "Lihat", unless the user asked for this
    // POI from the map panel and the request was routed through
    // [ExploreMapScreen.onPoiAction].
    final fromPanel = _panelViewId == id;
    _panelViewId = null;
    final poi = await widget.services.pois.poiById(id);
    if (mounted && poi != null) _openDetail(poi, fromTrigger: !fromPanel);
  }

  /// [fromTrigger] opens the detail without `featureUsed`: right after a
  /// trigger its time would match the arrival at the POI (PRD §15.5).
  Future<void> _openDetail(Poi poi, {bool fromTrigger = false}) async {
    if (_openingDetail) return;
    _openingDetail = true;
    try {
      await Navigator.of(context).push(
        AgamMotion.route<void>(
          (context) => PoiDetailScreen(
            poi: poi,
            activity: fromTrigger ? null : widget.services.activity,
            audio: widget.services.audio,
            settings: widget.services.settings,
            checkedIn: false,
            navigationAvailable: widget._startRoute != null,
            // The route card lives on the search page, as from the panel.
            onNavigate: () async {
              Navigator.of(context).pop();
              widget._startRoute?.call(poi);
            },
          ),
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  void _selectPoi(Poi poi) {
    setState(() {
      _triggeredPoiId = null;
      _selectedPoi = poi;
      _showPois = true;
      _showDetail = true;
      _clearRecommendation();
    });
    _mapKey.currentState?.focusOn(poi.position);
    _loadFacilities();
  }

  /// Closing the panel (its X or back) offers where to go next (F07).
  /// "Lewati" declines the POI instead, so it does not come here.
  void _closePanel() {
    final closed = _selectedPoi;
    _activeTriggerIds.remove(_triggeredPoiId);
    setState(() {
      _triggeredPoiId = null;
      _showDetail = false;
    });
    if (closed != null) _recommendAfter(closed);
  }

  /// From the user's position when the map has one, else from the closed
  /// POI. Nothing is logged: right after a trigger its time would match the
  /// visit (PRD §15.5, rules §5.1).
  Future<void> _recommendAfter(Poi poi) async {
    final request = ++_recommendRequest;
    final position = _fix?.position;
    final from = position ?? poi.position;
    try {
      final result = await widget.services.recommendations.recommend(
        from: from,
        afterPoiId: poi.id,
      );
      if (!mounted || request != _recommendRequest || _showDetail) return;
      setState(
        () => _recommendation = RecommendationView.resolve(
          result,
          pois: _pois,
          from: from,
          trailActive: widget.services.trail.current.active,
          origin: position == null ? poi.name : null,
        ),
      );
    } catch (_) {
      // Optional; the map stays as it was.
    }
  }

  void _clearRecommendation() {
    _recommendRequest++;
    _recommendation = null;
  }

  Future<void> _poiAction(Poi poi, TriggerAction action) async {
    final fromTrigger = _triggeredPoiId == poi.id;
    if (action == TriggerAction.skip) {
      _activeTriggerIds.remove(poi.id);
      setState(() {
        _triggeredPoiId = null;
        _showDetail = false;
      });
    }
    try {
      final audio = widget.services.audio;
      if (action == TriggerAction.listen &&
          audio.current.clip?.poiId == poi.id &&
          audio.current.clip?.kind == AudioClipKind.narration) {
        if (audio.current.status == PlaybackStatus.playing) {
          await audio.pause();
          return;
        }
        if (audio.current.status == PlaybackStatus.paused) {
          await audio.resume();
          return;
        }
      }
      // A fresh start from a POI the user picked on the map; never from the
      // trigger card, whose time would match the arrival (PRD §15.5).
      if (action == TriggerAction.listen && !fromTrigger) {
        widget.services.activity.log(
          const ActivityEvent.featureUsed(feature: ActivityFeature.narration),
        );
      }
      final onAction = widget.onPoiAction;
      if (onAction != null) {
        if (action == TriggerAction.view && !fromTrigger) _panelViewId = poi.id;
        try {
          await onAction(poi.id, action);
        } finally {
          // The view request has been delivered by now (or was dropped); a
          // later notification "Lihat" must not count as a panel open.
          _panelViewId = null;
        }
      } else {
        switch (action) {
          case TriggerAction.listen:
            await audio.play(
              AudioClip(poiId: poi.id, kind: AudioClipKind.narration),
            );
          case TriggerAction.view:
            if (mounted) _openDetail(poi, fromTrigger: fromTrigger);
          case TriggerAction.skip:
            if (audio.current.clip?.poiId == poi.id &&
                audio.current.clip?.kind == AudioClipKind.prompt) {
              await audio.stop();
            }
        }
      }
    } catch (_) {
      if (mounted) _showNotice('Aksi belum dapat dijalankan. Coba lagi.');
    }
  }

  void _centerLocation() {
    final fix = _fix;
    if (fix == null) {
      _showNotice('Lokasi belum tersedia. Periksa izin dan GPS perangkat.');
      return;
    }
    _mapKey.currentState?.focusOn(fix.position);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_locationSubscription?.cancel());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = _selectedPoi;
    final outsideCampus =
        _fix != null && !widget.services.map.isInsideCampus(_fix!.position);
    return PopScope(
      canPop: !widget.isActive || !_showDetail,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isActive && _showDetail) _closePanel();
      },
      child: Scaffold(
        backgroundColor: AgamColors.canvas,
        body: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              OfflineCampusMap(
                key: _mapKey,
                showPois: _showPois,
                config: widget.services.map,
                pois: _pois,
                selectedPoiId: poi?.id,
                userPosition: _fix?.position,
                userAccuracyM: _fix?.accuracyM,
                onSelectPoi: _selectPoi,
                // The credit sits in the bottom stack, above the session card.
                attributionPadding: null,
              ),
              if (widget.onOpenSearch case final openSearch?)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: _SearchOverlay(
                    onSearch: () => openSearch(null),
                    onFacility: openSearch,
                  ),
                ),
              Positioned(
                top: widget.onOpenSearch == null ? 12 : 126,
                right: 16,
                child: _MapControls(
                  showPois: _showPois,
                  locationIcon: _locationIcon,
                  onNorth: () => _mapKey.currentState?.resetNorth(),
                  onCenter: _centerLocation,
                  onLayers: () => setState(() => _showPois = !_showPois),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                // The stack stays below the map controls, so a tall
                // recommendation scrolls instead of covering them.
                top:
                    (widget.onOpenSearch == null ? 12 : 126) +
                    _MapControls.height +
                    12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const MapAttribution(),
                    const SizedBox(height: 10),
                    // Location speaks through the dot on the map; words
                    // appear only when something needs the user's action.
                    AnimatedSize(
                      duration: AgamMotion.duration(context, 240),
                      curve: AgamMotion.easeOut,
                      alignment: Alignment.bottomCenter,
                      child: switch (_locationMessage ??
                          (outsideCampus
                              ? 'Anda berada di luar area Kampus Ganesha'
                              : null)) {
                        final message? => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LocationBanner(message: message),
                        ),
                        null => const SizedBox(width: double.infinity),
                      },
                    ),
                    // UI07 after a closed panel: a dismissible card, at most
                    // half the map and never over the map controls.
                    Flexible(
                      child: RecommendationPresence(
                        child: switch (_recommendation) {
                          final view? => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight * .5,
                              ),
                              child: SingleChildScrollView(
                                child: RecommendationCard(
                                  view: view,
                                  floating: true,
                                  routeAvailable: widget._startRoute != null,
                                  onRoute: (poi) {
                                    setState(_clearRecommendation);
                                    widget._startRoute?.call(poi);
                                  },
                                  onDismiss: () =>
                                      setState(_clearRecommendation),
                                ),
                              ),
                            ),
                          ),
                          null => null,
                        },
                      ),
                    ),
                    _SessionCard(
                      active: _sessionActive,
                      busy: _changingSession,
                      onPressed: _changingSession ? null : _toggleSession,
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showDetail,
                  child: AnimatedSwitcher(
                    duration: AgamMotion.duration(context, 280),
                    reverseDuration: AgamMotion.duration(context, 180),
                    switchInCurve: AgamMotion.drawer,
                    switchOutCurve: AgamMotion.easeOut,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final outgoing in previous)
                          ExcludeSemantics(
                            child: IgnorePointer(child: outgoing),
                          ),
                        ?current,
                      ],
                    ),
                    transitionBuilder: MediaQuery.disableAnimationsOf(context)
                        ? (child, animation) =>
                              FadeTransition(opacity: animation, child: child)
                        : AgamMotion.panel,
                    child: poi != null && _showDetail
                        ? AgamPoiPanel(
                            key: const ValueKey('poi-panel'),
                            builder:
                                (context, scroll, expanded, toggle, handle) =>
                                    _PoiSheet(
                                      poi: poi,
                                      triggered: _triggeredPoiId == poi.id,
                                      facilities: _nearbyFacilities,
                                      scrollController: scroll,
                                      handle: handle,
                                      expanded: expanded,
                                      onToggleExpanded: toggle,
                                      onClose: _closePanel,
                                      onSkip: () =>
                                          _poiAction(poi, TriggerAction.skip),
                                      onView: () =>
                                          _poiAction(poi, TriggerAction.view),
                                      onListen: () =>
                                          _poiAction(poi, TriggerAction.listen),
                                      routeAvailable: widget.onRoute != null,
                                      onRoute: () => widget.onRoute?.call(poi),
                                      audio: widget.services.audio,
                                    ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The centre button carries the GPS state, as Google Maps does: a filled
  /// target when the fix is good, a searching ring otherwise, crossed out
  /// when location is off or denied.
  IconData get _locationIcon {
    if (_locationMessage != null && _fix == null) {
      return Icons.location_disabled_rounded;
    }
    final fix = _fix;
    if (fix == null || !fix.isAccurateForTrigger) {
      return Icons.location_searching_rounded;
    }
    return Icons.my_location_rounded;
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

/// Search entry on the map, as in Google Maps: a bar that opens the search
/// page, and facility chips below it that open it already filtered.
class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({required this.onSearch, required this.onFacility});

  final VoidCallback onSearch;
  final ValueChanged<FacilityCategory> onFacility;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Semantics(
          button: true,
          label: 'Cari gedung atau fasilitas',
          child: AgamPressFeedback(
            // The shadow sits under the white surface, not on top of it.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: AgamShadows.floating,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onSearch,
                  borderRadius: BorderRadius.circular(26),
                  child: const SizedBox(
                    height: 52,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: AgamColors.brand,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Cari gedung atau fasilitas',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AgamColors.subtle,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.none,
          itemCount: facilityCategories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = facilityCategories[index];
            return AgamPressFeedback(
              child: Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                elevation: 2,
                shadowColor: const Color(0x330B1F44),
                child: InkWell(
                  onTap: () => onFacility(category),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          facilityIcon(category),
                          size: 17,
                          color: AgamColors.brand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          facilityName(category),
                          style: const TextStyle(
                            color: AgamColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

/// Shown only when location needs the user: GPS off, permission revoked,
/// or the user is outside campus.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AgamRadius.control),
      boxShadow: AgamShadows.floating,
    ),
    child: Row(
      children: [
        const Icon(
          Icons.location_off_rounded,
          size: 20,
          color: AgamColors.warning,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: AgamText.label)),
      ],
    ),
  );
}

/// North, centre and layers grouped in one capsule.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.showPois,
    required this.locationIcon,
    required this.onNorth,
    required this.onCenter,
    required this.onLayers,
  });

  /// Three 48 px buttons and two 1 px dividers.
  static const height = 3 * 48.0 + 2;

  final bool showPois;
  final IconData locationIcon;
  final VoidCallback onNorth;
  final VoidCallback onCenter;
  final VoidCallback onLayers;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AgamShadows.floating,
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          _ControlButton(
            icon: Icons.explore_outlined,
            tooltip: 'Arahkan peta ke utara',
            onTap: onNorth,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: locationIcon,
            tooltip: 'Pusatkan lokasi saya',
            onTap: onCenter,
          ),
          const _ControlDivider(),
          _ControlButton(
            icon: showPois ? Icons.layers_rounded : Icons.layers_clear_rounded,
            tooltip: showPois
                ? 'Sembunyikan penanda POI'
                : 'Tampilkan penanda POI',
            onTap: onLayers,
          ),
        ],
      ),
    ),
  );
}

class _ControlDivider extends StatelessWidget {
  const _ControlDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 24,
    child: Divider(height: 1, thickness: 1, color: AgamColors.line),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedSwitcher(
          duration: AgamMotion.duration(context, 160),
          child: Icon(
            icon,
            key: ValueKey(icon),
            color: AgamColors.brand,
            size: 22,
          ),
        ),
      ),
    ),
  );
}

/// The main action of the map. Idle it is a white card that invites the user
/// to start Explore; active it turns navy, like the onboarding ground, and
/// the action becomes "Akhiri". Colour and content morph in place.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.active,
    required this.busy,
    required this.onPressed,
  });

  final bool active;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final duration = AgamMotion.duration(context, 280);
    final actionColor = active ? AgamColors.danger : Colors.white;
    return AnimatedContainer(
      duration: duration,
      curve: AgamMotion.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? AgamColors.brandDeep : Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.floating,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: duration,
            curve: AgamMotion.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: .14)
                  : AgamColors.tint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: duration,
                child: active
                    ? Container(
                        key: const ValueKey('live'),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AgamColors.mint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AgamColors.mint.withValues(alpha: .35),
                            width: 4,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.explore_rounded,
                        key: ValueKey('idle'),
                        color: AgamColors.brand,
                        size: 22,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: AgamMotion.easeOut,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey(active),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    active ? 'Explore aktif' : 'Explore',
                    style: AgamText.label.copyWith(
                      fontSize: 16,
                      color: active ? Colors.white : AgamColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: active ? 'Akhiri sesi' : 'Mulai Explore',
            // While the session changes the button dims instead of spinning:
            // starting can wait on GPS, and an endless spinner reads as a hang.
            child: AnimatedOpacity(
              opacity: busy ? .55 : 1,
              duration: duration,
              child: AgamPressFeedback(
                child: Material(
                  color: active ? Colors.white : AgamColors.brand,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onPressed,
                    child: SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              active
                                  ? Icons.stop_circle_outlined
                                  : Icons.directions_walk_rounded,
                              size: 18,
                              color: actionColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              active ? 'Akhiri' : 'Mulai',
                              style: TextStyle(
                                color: actionColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// UI03 trigger card. It mirrors the prompt card shown on the onboarding:
/// voice prompt first, one large "Dengarkan" action, quieter Lihat/Lewati.
/// A POI tapped on the map shows its summary instead of the prompt.
class _PoiSheet extends StatelessWidget {
  const _PoiSheet({
    required this.poi,
    required this.triggered,
    required this.facilities,
    required this.scrollController,
    required this.handle,
    required this.audio,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClose,
    required this.onSkip,
    required this.onView,
    required this.onListen,
    required this.routeAvailable,
    required this.onRoute,
  });

  final Poi poi;
  final bool triggered;
  final List<Facility> facilities;
  final ScrollController scrollController;
  final Widget handle;
  final AudioService audio;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClose;
  final VoidCallback onSkip;
  final VoidCallback onView;
  final VoidCallback onListen;
  final bool routeAvailable;
  final VoidCallback onRoute;

  bool get _contentReady =>
      poi.metadata.approved && !poi.metadata.isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final narrationAvailable =
        _contentReady && poi.media.narrationAudio?.isNotEmpty == true;
    final photo = _contentReady && poi.media.photos.isNotEmpty
        ? poi.media.photos.first
        : null;
    final description = _contentReady && poi.description.trim().isNotEmpty
        ? poi.description
        : 'Informasi belum tersedia';
    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: const Color(0x660B1F44),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AgamRadius.sheet),
      ),
      child: Column(
        children: [
          handle,
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox.square(
                    dimension: 52,
                    child: photo != null
                        ? Image.asset(
                            photo,
                            fit: BoxFit.cover,
                            cacheWidth: 156,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => const AgamIconTile(
                              icon: Icons.apartment_rounded,
                              size: 52,
                            ),
                          )
                        : const AgamIconTile(
                            icon: Icons.apartment_rounded,
                            size: 52,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AgamText.title,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleExpanded,
                  tooltip: expanded ? 'Ciutkan informasi' : 'Perluas informasi',
                  color: AgamColors.muted,
                  icon: AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: AgamMotion.duration(context, 240),
                    curve: AgamMotion.easeOut,
                    child: const Icon(Icons.expand_less_rounded),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Tutup informasi',
                  style: IconButton.styleFrom(
                    backgroundColor: AgamColors.fill,
                    foregroundColor: AgamColors.ink,
                    fixedSize: const Size(40, 40),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              interactive: true,
              child: SingleChildScrollView(
                key: ValueKey(poi.id),
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (triggered)
                      _PromptCard(poi: poi)
                    else
                      AnimatedSize(
                        duration: AgamMotion.duration(context, 240),
                        curve: AgamMotion.easeOut,
                        alignment: Alignment.topCenter,
                        child: Text(
                          description,
                          maxLines: expanded ? null : 3,
                          overflow: expanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: AgamText.body.copyWith(fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 16),
                    StreamBuilder<PlaybackState>(
                      stream: audio.state,
                      initialData: audio.current,
                      builder: (context, snapshot) {
                        final playing =
                            snapshot.data?.clip?.poiId == poi.id &&
                            snapshot.data?.clip?.kind ==
                                AudioClipKind.narration &&
                            snapshot.data?.status == PlaybackStatus.playing;
                        return AgamPrimaryButton(
                          onPressed: narrationAvailable ? onListen : null,
                          icon: playing
                              ? Icons.pause_rounded
                              : Icons.headphones_rounded,
                          label: narrationAvailable
                              ? (playing ? 'Jeda cerita' : 'Dengarkan Cerita')
                              : 'Narasi belum tersedia',
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AgamRouteButton(
                            available: routeAvailable,
                            onPressed: onRoute,
                            padding: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AgamTonalButton(
                            onPressed: onView,
                            icon: Icons.info_outline_rounded,
                            padding: 8,
                            label: 'Lihat',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AgamTonalButton(
                            onPressed: onSkip,
                            icon: Icons.skip_next_rounded,
                            foreground: AgamColors.muted,
                            padding: 8,
                            label: 'Lewati',
                          ),
                        ),
                      ],
                    ),
                    // Empty sections are left out instead of labelled empty.
                    if (facilities.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const Text('Fasilitas sekitar', style: AgamText.label),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // The facility service only returns approved,
                          // non-placeholder entries, so names show as-is.
                          for (final facility in facilities)
                            AgamPill(facility.name, icon: Icons.place_rounded),
                        ],
                      ),
                    ],
                    if (photo != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AgamRadius.tile),
                        child: Image.asset(
                          photo,
                          height: 176,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheWidth: 900,
                          semanticLabel: 'Foto ${poi.name}',
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    if (expanded && triggered) ...[
                      const SizedBox(height: 20),
                      Text(
                        description,
                        style: AgamText.body.copyWith(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: AgamColors.canvas,
      borderRadius: BorderRadius.circular(AgamRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/media/logo.png',
            width: 22,
            height: 22,
            cacheWidth: 66,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '“Anda mendekati ${poi.name}. Apakah Anda ingin mendengarkan '
          'ceritanya?”',
          style: const TextStyle(
            color: AgamColors.ink,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

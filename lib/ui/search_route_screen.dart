import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/activity.dart';
import '../contracts/models/content.dart';
import '../contracts/models/discovery.dart';
import '../contracts/models/geo.dart';
import '../contracts/models/navigation.dart';
import '../contracts/models/session.dart';
import 'poi_detail_screen.dart';
import 'widgets/agam_arrival.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';
import 'widgets/arrival_card.dart';
import 'widgets/facility_labels.dart';
import 'widgets/offline_campus_map.dart';
import 'widgets/recommendation_card.dart';

/// UI05 Search & Destination plus the active UI06 navigation summary.
/// Search/routing implementations are injected from AppServices.
class SearchRouteScreen extends StatefulWidget {
  const SearchRouteScreen({
    super.key,
    required this.services,
    this.isActive = true,
    this.initialFacility,
    this.autofocus = false,
    this.initialDestination,
    this.startRouteOnOpen = false,
    this.onTabSelected,
    this.internalDemo = false,
    this.onShowPoiOnMap,
  });

  final ValueChanged<String>? onShowPoiOnMap;
  final AppServices services;

  /// Entrance motion waits until the tab is first shown.
  final bool isActive;

  /// Opens with this facility category already filtering, from a map chip.
  final FacilityCategory? initialFacility;

  /// Opens with the keyboard up, from the map's search bar.
  final bool autofocus;

  /// Opens with this building already chosen, from "Rute" on the map.
  final Poi? initialDestination;

  /// Starts the route to [initialDestination] as soon as the page shows, for
  /// one-tap actions (a recommendation, Rute on a POI detail; PRD F07).
  final bool startRouteOnOpen;
  final ValueChanged<int>? onTabSelected;
  final bool internalDemo;

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  List<Poi> _pois = const [];
  List<Facility> _facilities = const [];
  List<SearchResult> _results = const [];
  SearchResult? _destination;
  // Set by [SearchRouteScreen.startRouteOnOpen] until the POIs have loaded.
  SearchResult? _pendingRoute;
  // One map lives in the destination card while it is open, so switching
  // destinations moves its camera instead of rebuilding it at the new place.
  final _cardMap = GlobalKey<OfflineCampusMapState>();
  // The destination card sits at the top of the list; choosing a place from
  // further down scrolls back so the card and its camera move are in view.
  final _list = ScrollController();
  // How long the card's text waits before naming a new destination: just past
  // the middle of the camera's flight, so the name lands with its marker.
  Duration _arriveAfter = Duration.zero;
  NavigationState _navigation = const NavigationState.idle();
  FacilityCategory? _facilityFilter;
  int _searchRequest = 0;
  bool _searching = false;
  bool _routing = false;
  String? _error;
  StreamSubscription<List<Poi>>? _poiSubscription;
  StreamSubscription<List<Facility>>? _facilitySubscription;
  StreamSubscription<NavigationState>? _navigationSubscription;
  // `featureUsed` (PRD §15.5) is logged at most once per feature per visit:
  // `search` when a typed search first returns results, `facilities` when a
  // facility category first filters the page. Only the feature is sent.
  final _loggedFeatures = <ActivityFeature>{};
  // UI07 after arrival; the request counter drops answers that come back
  // after the route changed.
  RecommendationView? _recommendation;
  int _recommendRequest = 0;

  void _logOnce(ActivityFeature feature) {
    if (!_loggedFeatures.add(feature)) return;
    widget.services.activity.log(ActivityEvent.featureUsed(feature: feature));
  }

  @override
  void initState() {
    super.initState();
    _poiSubscription = widget.services.pois.watchPois().listen((value) {
      if (!mounted) return;
      setState(() => _pois = value);
      // A one-tap route waits for the POIs it needs to build its target.
      if (_pendingRoute case final destination?
          when _poiFor(destination) != null) {
        _pendingRoute = null;
        _startRoute(destination);
      }
    });
    _facilitySubscription = widget.services.pois.watchFacilities().listen((
      value,
    ) {
      if (mounted) setState(() => _facilities = value);
    });
    _navigation = widget.services.navigation.current;
    _navigationSubscription = widget.services.navigation.state.listen((value) {
      if (!mounted) return;
      final arrived =
          value.status == NavigationStatus.arrived &&
          _navigation.status != NavigationStatus.arrived;
      setState(() => _navigation = value);
      // The arrival card replaces the route card at the top of the list;
      // bring it into view if the list was scrolled down meanwhile.
      if (arrived) {
        _recommendAfter(value.target);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _revealCard();
        });
      }
    });
    if (_navigation.status == NavigationStatus.arrived) {
      _recommendAfter(_navigation.target);
    }
    _facilityFilter = widget.initialFacility;
    if (_facilityFilter != null) _logOnce(ActivityFeature.facilities);
    if (widget.initialDestination case final poi?) {
      final destination = SearchResult(
        kind: SearchResultKind.poi,
        id: poi.id,
        name: poi.name,
        score: 1,
      );
      _destination = destination;
      if (widget.startRouteOnOpen) _pendingRoute = destination;
    }
    _query.addListener(_runSearch);
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query
      ..removeListener(_runSearch)
      ..dispose();
    _focus.dispose();
    _list.dispose();
    _poiSubscription?.cancel();
    _facilitySubscription?.cancel();
    _navigationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final request = ++_searchRequest;
    final text = _query.text.trim();
    if (text.isEmpty) {
      if (mounted) {
        setState(() {
          _results = const [];
          _searching = false;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final result = await widget.services.search.search(
        text,
        includePois: _facilityFilter == null,
        facilityCategories: _facilityFilter == null ? null : {_facilityFilter!},
      );
      if (mounted && request == _searchRequest) {
        setState(() => _results = result);
        if (result.isNotEmpty) _logOnce(ActivityFeature.search);
      }
    } catch (_) {
      if (mounted && request == _searchRequest) {
        setState(() => _error = 'Pencarian belum dapat dimuat.');
      }
    } finally {
      if (mounted && request == _searchRequest) {
        setState(() => _searching = false);
      }
    }
  }

  void _setFacilityFilter(FacilityCategory category) {
    setState(() {
      _facilityFilter = _facilityFilter == category ? null : category;
    });
    if (_facilityFilter != null) _logOnce(ActivityFeature.facilities);
    _runSearch();
  }

  Poi? _poiFor(SearchResult result) {
    for (final poi in _pois) {
      if (poi.id == result.id) return poi;
    }
    return null;
  }

  Facility? _facilityFor(SearchResult result) {
    for (final facility in _facilities) {
      if (facility.id == result.id) return facility;
    }
    return null;
  }

  void _selectDestination(SearchResult result) {
    if (widget.internalDemo && result.kind != SearchResultKind.poi) {
      _showMessage('Pencarian fasilitas belum tersedia.');
      return;
    }
    _travelTo(result);
    setState(() {
      _destination = result;
      _error = null;
    });
    _revealCard();
  }

  /// Scrolls back to the destination card. It is shorter than the camera's
  /// flight, so the card is in view before the new marker settles.
  void _revealCard() {
    if (!_list.hasClients || _list.offset <= 0) return;
    final duration = AgamMotion.duration(context, 360);
    if (duration == Duration.zero) {
      _list.jumpTo(0);
    } else {
      _list.animateTo(0, duration: duration, curve: AgamMotion.drawer);
    }
  }

  /// Flies the open card's map to [result]; a card opening fresh starts
  /// there, so it needs no flight.
  void _travelTo(SearchResult result) {
    final point = _pointFor(result);
    final map = _cardMap.currentState;
    if (_destination == null || _destination!.id == result.id) return;
    if (point == null || map == null) {
      _arriveAfter = Duration.zero;
      return;
    }
    _arriveAfter = map.flyTo(point) * .55;
  }

  /// [onArrival] opens the detail without `featureUsed`: right after arriving
  /// its time would match the arrival at the POI (PRD §15.5, rules §5.1).
  Future<void> _openPoiDetail(Poi poi, {bool onArrival = false}) async {
    await Navigator.of(context).push<void>(
      AgamMotion.route(
        (context) => PoiDetailScreen(
          activity: onArrival ? null : widget.services.activity,
          poi: poi,
          audio: widget.services.audio,
          settings: widget.services.settings,
          checkedIn: false,
          onNavigate: () async {
            Navigator.of(context).pop();
            final result = SearchResult(
              kind: SearchResultKind.poi,
              id: poi.id,
              name: poi.name,
              score: 1,
            );
            _selectDestination(result);
            await _startRoute(result);
          },
        ),
      ),
    );
  }

  Future<void> _openDemoPoi(String id) async {
    final poi = await widget.services.pois.poiById(id);
    if (!mounted) return;
    if (poi == null) {
      _showMessage('POI tidak tersedia di dataset demo.');
      return;
    }
    await _openPoiDetail(poi);
  }

  /// UI07 under the arrival card: next POIs from where the user now stands
  /// (or the arrival point), excluding the POI just reached. Nothing is
  /// logged (PRD §15.5, rules §5.1).
  Future<void> _recommendAfter(NavigationTarget? target) async {
    if (target == null) return;
    _recommendation = null;
    final request = ++_recommendRequest;
    final from = widget.services.location.lastFix?.position ?? target.point;
    try {
      final result = await widget.services.recommendations.recommend(
        from: from,
        afterPoiId: target.kind == NavigationTargetKind.poi ? target.id : null,
      );
      final pois = await widget.services.pois.watchPois().first;
      if (!mounted || request != _recommendRequest) return;
      setState(
        () => _recommendation = RecommendationView.resolve(
          result,
          pois: pois,
          from: from,
          trailActive: widget.services.trail.current.active,
        ),
      );
    } catch (_) {
      // Recommendations are optional; the arrival card stands on its own.
    }
  }

  void _clearRecommendation() {
    _recommendRequest++;
    _recommendation = null;
  }

  Future<void> _routeToRecommended(Poi poi) async {
    final result = SearchResult(
      kind: SearchResultKind.poi,
      id: poi.id,
      name: poi.name,
      score: 1,
    );
    _selectDestination(result);
    await _startRoute(result);
  }

  Future<void> _startRoute(SearchResult result) async {
    if (_routing) return;
    final poi = _poiFor(result);
    final facility = _facilityFor(result);
    final target = poi != null
        ? NavigationTarget.poi(poi)
        : facility != null
        ? NavigationTarget.facility(facility)
        : null;
    if (target == null) return;

    setState(() {
      _routing = true;
      _error = null;
      _destination = result;
      _clearRecommendation();
    });
    var sessionStarted = false;
    try {
      await widget.services.session.start(SessionMode.navigation);
      sessionStarted = true;
      if (widget.services.location.lastFix == null) {
        await widget.services.location.positions.first.timeout(
          const Duration(seconds: 12),
        );
      }
      await widget.services.navigation.start(target);
      // The real controller reports an unavailable route as an error state
      // rather than throwing, e.g. while the campus walking graph is not
      // bundled. Treat it as a failure instead of announcing a route.
      if (widget.services.navigation.current.status == NavigationStatus.error) {
        throw StateError('Rute belum tersedia.');
      }
      if (mounted) {
        setState(() => _destination = result);
        if (target.isPlaceholderPoint) {
          _showMessage(
            'Rute menuju titik akses yang belum diverifikasi di lapangan.',
          );
        }
      }
    } on TimeoutException {
      await widget.services.session.end();
      if (mounted) {
        setState(
          () =>
              _error = 'Lokasi belum tersedia. Periksa izin dan GPS perangkat.',
        );
      }
    } catch (_) {
      await widget.services.navigation.stop();
      if (sessionStarted) await widget.services.session.end();
      if (mounted) {
        setState(() => _error = 'Rute belum tersedia untuk tujuan ini.');
      }
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _stopRoute() async {
    if (widget.internalDemo && _navigation.status == NavigationStatus.idle) {
      setState(() => _destination = null);
      return;
    }
    await widget.services.navigation.stop();
    await widget.services.session.end();
    if (mounted) {
      setState(() {
        _destination = null;
        _navigation = const NavigationState.idle();
        _clearRecommendation();
      });
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute =
        _navigation.status != NavigationStatus.idle &&
        _navigation.status != NavigationStatus.error;
    final currentTarget = _navigation.target;
    final selected =
        _destination ??
        (currentTarget == null
            ? null
            : SearchResult(
                kind: currentTarget.kind == NavigationTargetKind.poi
                    ? SearchResultKind.poi
                    : SearchResultKind.facility,
                id: currentTarget.id,
                name: currentTarget.name,
                score: 1,
              ));
    final approvedFacilities = _facilities
        .where(
          (f) =>
              f.category == _facilityFilter &&
              f.metadata.approved &&
              !f.metadata.isPlaceholder,
        )
        .toList();
    final play = widget.isActive;
    final searching = _query.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AgamColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchHeader(),
            Expanded(
              child: CustomScrollView(
                controller: _list,
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverList.list(
                      children: [
                        AgamAnimatedSize(
                          milliseconds: 280,
                          alignment: Alignment.topCenter,
                          child: selected == null
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: _routeCard(
                                    selected,
                                    activeRoute: activeRoute,
                                  ),
                                ),
                        ),
                        if (_error != null) _errorCard(_error!),
                        if (searching) ...[
                          const AgamSectionHeader('Hasil Pencarian'),
                          if (_facilityFilter case final category?) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _activeFilter(category),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_searching)
                            const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AgamColors.brand,
                                  ),
                                ),
                              ),
                            )
                          else if (_results.isEmpty)
                            _emptyCard(
                              _facilityFilter != null &&
                                      approvedFacilities.isEmpty
                                  ? _missingData(_facilityFilter!)
                                  : 'Tidak ada hasil yang cocok.',
                              icon: Icons.search_off_rounded,
                            )
                          else
                            AgamGroup(
                              children: _results.map(_resultRow).toList(),
                            ),
                        ] else ...[
                          // A chosen facility category is the filter: the building
                          // list steps aside for that category's places.
                          if (_facilityFilter == null) ...[
                            AgamReveal(
                              order: 1,
                              play: play,
                              child: const AgamSectionHeader('Gedung'),
                            ),
                            AgamReveal(
                              order: 2,
                              play: play,
                              child: AgamGroup(
                                children: _pois.map(_poiRow).toList(),
                              ),
                            ),
                            const SizedBox(height: 28),
                          ],
                          AgamReveal(
                            order: 3,
                            play: play,
                            child: const AgamSectionHeader('Fasilitas'),
                          ),
                          AgamReveal(
                            order: 4,
                            play: play,
                            child: _facilityGrid(),
                          ),
                          if (_facilityFilter case final category?) ...[
                            const SizedBox(height: 14),
                            if (approvedFacilities.isEmpty)
                              _emptyCard(
                                _missingData(category),
                                icon: Icons.inventory_2_outlined,
                              )
                            else
                              AgamGroup(
                                children: [
                                  for (final facility in approvedFacilities)
                                    AgamListRow(
                                      icon: facilityIcon(facility.category),
                                      title: facility.name,
                                      trailing: _routeIcon(
                                        SearchResult(
                                          kind: SearchResultKind.facility,
                                          id: facility.id,
                                          name: facility.name,
                                          score: 1,
                                        ),
                                      ),
                                      onTap: _routing
                                          ? null
                                          : () => _selectDestination(
                                              SearchResult(
                                                kind: SearchResultKind.facility,
                                                id: facility.id,
                                                name: facility.name,
                                                score: 1,
                                              ),
                                            ),
                                    ),
                                ],
                              ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search field with a back arrow, pinned above the results the way
  /// Material's search view and Google Maps present it.
  Widget _searchHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
    child: Row(
      children: [
        if (Navigator.canPop(context))
          const AgamBackButton()
        else
          const SizedBox(width: 8),
        const SizedBox(width: 4),
        Expanded(
          child: AnimatedContainer(
            duration: AgamMotion.duration(context, 200),
            curve: AgamMotion.easeOut,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: (_focus.hasFocus ? AgamColors.cyan : Colors.black)
                      .withValues(alpha: _focus.hasFocus ? .55 : .12),
                  blurRadius: _focus.hasFocus ? 0 : 12,
                  spreadRadius: _focus.hasFocus ? 3 : 0,
                  offset: _focus.hasFocus ? Offset.zero : const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(
                  Icons.search_rounded,
                  color: AgamColors.brand,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    style: AgamText.label.copyWith(fontSize: 15),
                    cursorColor: AgamColors.brand,
                    decoration: InputDecoration(
                      hintText: 'Cari gedung atau fasilitas',
                      hintStyle: const TextStyle(
                        color: AgamColors.subtle,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: AgamMotion.duration(context, 160),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: .8, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _query.text.isEmpty
                      ? const SizedBox(key: ValueKey('empty'), width: 4)
                      : IconButton(
                          key: const ValueKey('clear'),
                          tooltip: 'Hapus pencarian',
                          color: AgamColors.muted,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            setState(() => _destination = null);
                            _query.clear();
                          },
                        ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  /// Shown above results while a facility category filters the search.
  Widget _activeFilter(FacilityCategory category) => Semantics(
    button: true,
    label: 'Hapus filter ${facilityName(category)}',
    child: AgamPressFeedback(
      child: GestureDetector(
        onTap: () => _setFacilityFilter(category),
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
          decoration: BoxDecoration(
            color: AgamColors.brand,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(facilityIcon(category), size: 16, color: Colors.white),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Text(
                  facilityName(category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );

  String _missingData(FacilityCategory category) =>
      'Data ${facilityName(category).toLowerCase()} belum tersedia.';

  Widget _facilityGrid() => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap * 2) / 3;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final category in facilityCategories)
            SizedBox(
              width: width,
              child: _facilityTile(category, _facilityFilter == category),
            ),
        ],
      );
    },
  );

  Widget _facilityTile(FacilityCategory category, bool selected) => Semantics(
    button: true,
    selected: selected,
    child: AgamPressFeedback(
      child: GestureDetector(
        onTap: () => _setFacilityFilter(category),
        child: AnimatedContainer(
          duration: AgamMotion.duration(context, 220),
          curve: AgamMotion.easeOut,
          height: 100,
          decoration: BoxDecoration(
            color: selected ? AgamColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(AgamRadius.tile),
            boxShadow: selected
                ? AgamShadows.glow(AgamColors.brand)
                : AgamShadows.card,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: AgamMotion.duration(context, 220),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .16)
                      : AgamColors.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  facilityIcon(category),
                  size: 20,
                  color: selected ? Colors.white : AgamColors.brand,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  facilityName(category),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AgamColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _demoPoiCard(SearchResult destination) {
    final poi = _poiFor(destination);
    if (poi == null) return _emptyCard('Informasi gedung belum tersedia.');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 188,
            child: OfflineCampusMap(
              key: _cardMap,
              config: widget.services.map,
              initialFocus: poi.position,
              pois: [poi],
              selectedPoiId: poi.id,
              onSelectPoi: _openPoiDetail,
              attributionPadding: const EdgeInsets.all(8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AgamArrival(
                  id: poi.id,
                  arriveAfter: _arriveAfter,
                  child: Text(poi.name, style: AgamText.title),
                ),
                const SizedBox(height: 16),
                AgamRouteButton(
                  available: true,
                  primary: true,
                  onPressed: _routing ? null : () => _startRoute(destination),
                  busy: _routing,
                ),
                const SizedBox(height: 10),
                AgamTonalButton(
                  icon: Icons.map_rounded,
                  label: 'Tampilkan di peta',
                  onPressed: () {
                    final showOnMap = widget.onShowPoiOnMap;
                    if (showOnMap != null) {
                      showOnMap(poi.id);
                    } else {
                      Navigator.of(context).push(
                        AgamMotion.route<void>(
                          (_) => Scaffold(
                            appBar: AppBar(
                              title: Text(poi.name, style: AgamText.headline),
                              backgroundColor: Colors.white,
                              surfaceTintColor: Colors.transparent,
                            ),
                            body: OfflineCampusMap(
                              config: widget.services.map,
                              initialFocus: poi.position,
                              pois: _pois,
                              selectedPoiId: poi.id,
                              onSelectPoi: _openPoiDetail,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                AgamTonalButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Lihat Detail POI',
                  onPressed: () => _openDemoPoi(poi.id),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _stopRoute,
                  style: TextButton.styleFrom(
                    foregroundColor: AgamColors.muted,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text(
                    'Tutup pilihan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // During navigation the marker sits where the route ends: the access point
  // the controller chose, not necessarily the target's first entrance.
  GeoPoint? _pointFor(SearchResult result) =>
      _navigation.target?.id == result.id
      ? (_navigation.route?.path.lastOrNull ?? _navigation.target!.point)
      : _poiFor(result)?.position ?? _facilityFor(result)?.position;

  Widget _routeCard(SearchResult destination, {required bool activeRoute}) {
    if (_hasArrivedAt(destination)) return _arrivalCard(destination);
    // An active route shows its progress in the regular card.
    if (widget.internalDemo && !activeRoute) return _demoPoiCard(destination);
    final route = _navigation.route;
    final step = _navigation.currentStep;
    final eta = _navigation.remainingEta ?? route?.eta;
    final distance = _navigation.remainingDistanceM ?? route?.distanceM;
    final point = _pointFor(destination);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (point != null)
            SizedBox(
              height: 168,
              child: OfflineCampusMap(
                key: _cardMap,
                config: widget.services.map,
                initialFocus: point,
                pois: [?_poiFor(destination)],
                selectedPoiId: destination.id,
                highlight: switch (_facilityFor(destination)) {
                  final facility? => MapHighlight(
                    point: facility.position,
                    label: facility.name,
                    icon: facilityIcon(facility.category),
                  ),
                  null => null,
                },
                onSelectPoi: _openPoiDetail,
                attributionPadding: const EdgeInsets.all(8),
              ),
            ),
          AgamGround(
            radius: 0,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: AgamColors.cyan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AgamArrival(
                    id: destination.id,
                    arriveAfter: _arriveAfter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.name,
                          style: AgamText.headline.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          distance == null ? '— m' : '${distance.round()} m',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .75),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AgamArrival(
                  id: destination.id,
                  arriveAfter: _arriveAfter,
                  child: Column(
                    children: [
                      Text(
                        // Rounded up: a 50 s walk reads "1 menit", not "0".
                        eta == null
                            ? '—'
                            : '${math.max(1, (eta.inSeconds / 60).ceil())}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'menit',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (step != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const AgamIconTile(icon: Icons.turn_left_rounded, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.instruction, style: AgamText.label),
                        const SizedBox(height: 2),
                        Text(
                          'Arahan • ${step.distanceM.round()} m',
                          style: AgamText.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: AgamRouteButton(
                    available: true,
                    primary: true,
                    onPressed: _routing || activeRoute
                        ? null
                        : () => _startRoute(destination),
                    busy: _routing,
                    label: activeRoute ? 'Navigasi sedang berjalan' : 'Rute',
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _stopRoute,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Akhiri rute',
                  style: IconButton.styleFrom(
                    backgroundColor: AgamColors.fill,
                    foregroundColor: AgamColors.ink,
                    fixedSize: const Size(54, 54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasArrivedAt(SearchResult destination) =>
      _navigation.status == NavigationStatus.arrived &&
      _navigation.target?.id == destination.id;

  /// The destination card once navigation reports arrival. The map keeps
  /// its key, so it carries over from the route card without moving.
  Widget _arrivalCard(SearchResult destination) {
    final poi = _poiFor(destination);
    final facility = _facilityFor(destination);
    final point = _pointFor(destination);
    final recommendation = _recommendation;
    final arrival = ArrivalCard(
      name: _navigation.target?.name ?? destination.name,
      kind: _navigation.target?.kind ?? NavigationTargetKind.poi,
      voice: widget.services.voice,
      onFinish: _stopRoute,
      onOpenDetail: poi == null
          ? null
          : () => _openPoiDetail(poi, onArrival: true),
      map: point == null
          ? null
          : OfflineCampusMap(
              key: _cardMap,
              config: widget.services.map,
              initialFocus: point,
              pois: [?poi],
              selectedPoiId: destination.id,
              highlight: facility == null
                  ? null
                  : MapHighlight(
                      point: facility.position,
                      label: facility.name,
                      icon: facilityIcon(facility.category),
                    ),
              onSelectPoi: _openPoiDetail,
              attributionPadding: const EdgeInsets.all(8),
            ),
    );
    // UI07: the next places sit right under the arrival, one tap from a route.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        arrival,
        RecommendationPresence(
          child: recommendation == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: RecommendationCard(
                    view: recommendation,
                    onRoute: _routeToRecommended,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _resultRow(SearchResult result) => AgamListRow(
    icon: result.kind == SearchResultKind.poi
        ? Icons.apartment_rounded
        : Icons.place_rounded,
    title: result.name,
    trailing: const _Chevron(),
    onTap: _routing ? null : () => _selectDestination(result),
  );

  Widget _poiRow(Poi poi) => AgamListRow(
    icon: Icons.apartment_rounded,
    title: poi.name,
    trailing: const _Chevron(),
    onTap: _routing
        ? null
        : () => _selectDestination(
            SearchResult(
              kind: SearchResultKind.poi,
              id: poi.id,
              name: poi.name,
              score: 1,
            ),
          ),
  );

  /// Compact "Rute" for list rows; the row itself still opens the card.
  Widget _routeIcon(SearchResult result) => IconButton(
    tooltip: 'Rute',
    icon: const Icon(Icons.directions_rounded),
    color: AgamColors.brand,
    style: IconButton.styleFrom(
      backgroundColor: AgamColors.fill,
      fixedSize: const Size(44, 44),
    ),
    onPressed: _routing ? null : () => _startRoute(result),
  );

  Widget _emptyCard(
    String text, {
    IconData icon = Icons.info_outline_rounded,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AgamRadius.tile),
      border: Border.all(color: AgamColors.line),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AgamColors.subtle),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AgamText.bodySmall)),
      ],
    ),
  );

  Widget _errorCard(String text) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AgamColors.dangerTint,
      borderRadius: BorderRadius.circular(AgamRadius.tile),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: AgamColors.danger,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AgamText.bodySmall.copyWith(color: AgamColors.danger),
          ),
        ),
      ],
    ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.chevron_right_rounded,
    size: 22,
    color: AgamColors.subtle,
  );
}

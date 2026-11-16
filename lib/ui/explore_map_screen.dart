import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/app_services.dart';
import '../contracts/models/content.dart';
import '../contracts/models/audio.dart';
import '../contracts/models/location.dart';
import '../contracts/models/session.dart';
import '../contracts/services/la_services.dart';
import '../logic/location/device_location_service.dart';
import '../logic/location/position_source.dart';
import '../logic/session/trigger_notifier.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_poi_panel.dart';
import 'orientation_trail_screen.dart';
import 'poi_detail_screen.dart';
import 'widgets/offline_campus_map.dart';
import 'widgets/agam_bottom_navigation.dart';

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
  });

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
  static const _navy = Color(0xFF073B82);
  static const _blue = Color(0xFF1553A6);

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
  bool _changingSession = false;
  bool _openingDetail = false;
  bool _appVisible = true;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _subscriptions.add(widget.poiViewRequests.listen(_openPoiById));
    _subscriptions.add(
      widget.poiMapRequests.listen((id) async {
        final poi = await widget.services.pois.poiById(id);
        if (!mounted || poi == null) return;
        setState(() {
          _selectedPoi = poi;
          _showPois = true;
          _showDetail = false;
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
        setState(() => _sessionActive = state.isActive);
      }),
    );
    _subscriptions.add(
      widget.services.session.triggers.listen((event) {
        if (!mounted) return;
        final poi = _findPoi(event.poiId);
        if (poi == null) return;
        setState(() {
          _selectedPoi = poi;
          _showDetail = true;
        });
        _loadFacilities();
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
    _appVisible =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!_appVisible && mounted) setState(() => _fix = null);
    _syncLocationSubscription();
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
    final facilities = await widget.services.facilities.nearby(
      from: poi.position,
      limit: 4,
    );
    if (mounted) {
      setState(
        () => _nearbyFacilities = facilities
            .map((item) => item.facility)
            .toList(),
      );
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
    final poi = await widget.services.pois.poiById(id);
    if (mounted && poi != null) _openDetail(poi);
  }

  Future<void> _openDetail(Poi poi) async {
    if (_openingDetail) return;
    _openingDetail = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PoiDetailScreen(
            poi: poi,
            audio: widget.services.audio,
            settings: widget.services.settings,
            checkedIn: false,
            navigationAvailable: !widget.internalDemo,
            onNavigate: () async => _showNotice('Navigasi belum tersedia.'),
          ),
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  void _selectPoi(Poi poi) {
    setState(() {
      _selectedPoi = poi;
      _showPois = true;
      _showDetail = true;
    });
    _mapKey.currentState?.focusOn(poi.position);
    _loadFacilities();
  }

  Future<void> _poiAction(Poi poi, TriggerAction action) async {
    if (action == TriggerAction.skip) setState(() => _showDetail = false);
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
      final onAction = widget.onPoiAction;
      if (onAction != null) {
        await onAction(poi.id, action);
      } else {
        switch (action) {
          case TriggerAction.listen:
            await audio.play(
              AudioClip(poiId: poi.id, kind: AudioClipKind.narration),
            );
          case TriggerAction.view:
            if (mounted) _openDetail(poi);
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
    return PopScope(
      canPop: !widget.isActive || !_showDetail,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isActive && _showDetail) {
          setState(() => _showDetail = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFAFF),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (!widget.embedded)
                _TopBar(onProfile: () => _showNotice('Profil belum tersedia')),
              _LocationStatus(
                fix: _fix,
                pois: _pois,
                message:
                    _locationMessage ??
                    (_fix != null &&
                            !widget.services.map.isInsideCampus(_fix!.position)
                        ? 'Anda berada di luar area Kampus Ganesha'
                        : null),
              ),
              Expanded(
                child: LayoutBuilder(
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
                        onSelectPoi: _selectPoi,
                      ),
                      Positioned(
                        top: 32,
                        right: 12,
                        child: _MapControls(
                          sessionActive: _sessionActive,
                          onSession: _changingSession ? null : _toggleSession,
                          showPois: _showPois,
                          onNorth: () => _mapKey.currentState?.resetNorth(),
                          onCenter: _centerLocation,
                          onLayers: () =>
                              setState(() => _showPois = !_showPois),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !_showDetail,
                          child: AnimatedSwitcher(
                            duration: AgamMotion.duration(context),
                            reverseDuration: AgamMotion.duration(context, 160),
                            switchInCurve: AgamMotion.easeOut,
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
                            transitionBuilder:
                                MediaQuery.disableAnimationsOf(context)
                                ? (child, animation) => FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  )
                                : AgamMotion.panel,
                            child: poi != null && _showDetail
                                ? AgamPoiPanel(
                                    key: const ValueKey('poi-panel'),
                                    builder:
                                        (
                                          context,
                                          scroll,
                                          expanded,
                                          toggle,
                                          handle,
                                        ) => _PoiSheet(
                                          poi: poi,
                                          facilities: _nearbyFacilities,
                                          scrollController: scroll,
                                          handle: handle,
                                          expanded: expanded,
                                          onToggleExpanded: toggle,
                                          onClose: () => setState(
                                            () => _showDetail = false,
                                          ),
                                          onSkip: () => _poiAction(
                                            poi,
                                            TriggerAction.skip,
                                          ),
                                          onView: () => _poiAction(
                                            poi,
                                            TriggerAction.view,
                                          ),
                                          onListen: () => _poiAction(
                                            poi,
                                            TriggerAction.listen,
                                          ),
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
              if (!widget.embedded)
                SafeArea(
                  top: false,
                  child: AgamBottomNavigation(
                    selectedIndex: 0,
                    onSelect: _openTab,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openTab(int index) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OrientationTrailScreen(services: widget.services),
        ),
      );
    } else if (index == 2) {
      _showNotice('Pencarian dan rute belum tersedia');
    } else if (index == 3) {
      _showNotice('Pengaturan belum tersedia');
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF104DA5),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.explore_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onProfile,
            customBorder: const CircleBorder(),
            child: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE7E9F2),
              child: Icon(
                Icons.person_rounded,
                color: Color(0xFF50576A),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.fix, required this.pois, this.message});

  final LocationFix? fix;
  final List<Poi> pois;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final nearest = fix == null || pois.isEmpty
        ? null
        : pois.reduce(
            (a, b) =>
                fix!.position.distanceTo(a.position) <
                    fix!.position.distanceTo(b.position)
                ? a
                : b,
          );
    return Container(
      height: 40,
      alignment: Alignment.center,
      color: Colors.white,
      child: Container(
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFF),
          border: Border.all(color: const Color(0xFFEDEEF5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 9, color: Color(0xFF006B51)),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                message ??
                    (nearest == null
                        ? 'Lokasi belum tersedia · periksa izin/GPS'
                        : 'Dekat ${nearest.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E9FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fix == null
                    ? 'GPS mencari…'
                    : 'GPS ±${fix!.accuracyM.round()}m',
                style: const TextStyle(
                  color: Color(0xFF164FA1),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.circle, size: 6, color: Color(0xFF006B51)),
          ],
        ),
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.sessionActive,
    required this.onSession,
    required this.showPois,
    required this.onNorth,
    required this.onCenter,
    required this.onLayers,
  });

  final bool showPois;
  final VoidCallback onNorth;
  final VoidCallback onCenter;
  final VoidCallback onLayers;
  final bool sessionActive;
  final VoidCallback? onSession;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ControlButton(
          icon: Icons.explore_outlined,
          tooltip: 'Arahkan peta ke utara',
          onTap: onNorth,
        ),
        const SizedBox(height: 7),
        _ControlButton(
          icon: Icons.my_location_rounded,
          tooltip: 'Pusatkan lokasi saya',
          onTap: onCenter,
        ),
        const SizedBox(height: 7),
        _ControlButton(
          icon: Icons.layers_outlined,
          tooltip: showPois
              ? 'Sembunyikan penanda POI'
              : 'Tampilkan penanda POI',
          onTap: onLayers,
        ),
        const SizedBox(height: 7),
        Material(
          color: sessionActive
              ? const Color(0xFFB33D55)
              : const Color(0xFF007C83),
          shape: const CircleBorder(),
          elevation: 3,
          child: Tooltip(
            message: sessionActive ? 'Akhiri sesi' : 'Mulai Explore',
            child: InkWell(
              onTap: onSession,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  sessionActive
                      ? Icons.stop_rounded
                      : Icons.people_outline_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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
    child: AgamPressFeedback(
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 39,
            height: 39,
            child: Icon(icon, color: const Color(0xFF174F9E), size: 20),
          ),
        ),
      ),
    ),
  );
}

class _PoiSheet extends StatelessWidget {
  const _PoiSheet({
    required this.poi,
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
  });

  final Poi poi;
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

  @override
  Widget build(BuildContext context) {
    final contentReady = poi.metadata.approved && !poi.metadata.isPlaceholder;
    final narrationAvailable =
        contentReady && poi.media.narrationAudio?.isNotEmpty == true;
    final prompt =
        '“Anda mendekati ${poi.name}. Apakah Anda ingin mendengarkan ceritanya?”';
    return Material(
      color: Colors.white,
      elevation: 12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(23)),
      child: Column(
        children: [
          handle,
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4BD8F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: Color(0xFF00536B),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    poi.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onToggleExpanded,
                  tooltip: expanded ? 'Ciutkan informasi' : 'Perluas informasi',
                  icon: Icon(expanded ? Icons.expand_more : Icons.expand_less),
                ),
                IconButton.filledTonal(
                  onPressed: onClose,
                  tooltip: 'Tutup informasi',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE9ECFF),
                    foregroundColor: const Color(0xFF35415E),
                    fixedSize: const Size(34, 34),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              interactive: true,
              child: SingleChildScrollView(
                key: ValueKey(poi.id),
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 25,
                            height: 25,
                            decoration: const BoxDecoration(
                              color: _ExploreMapScreenState._blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.campaign_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pemandu AGAM Suara',
                                  style: const TextStyle(
                                    color: _ExploreMapScreenState._navy,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  prompt,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.25,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: facilities.isEmpty
                          ? [
                              const _FacilityChip(
                                label: 'Fasilitas belum tersedia',
                              ),
                            ]
                          : facilities
                                .map(
                                  (facility) => _FacilityChip(
                                    label: facility.name.contains('(contoh)')
                                        ? facility.name
                                        : '${facility.name} · contoh',
                                  ),
                                )
                                .toList(),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 94,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDF4),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: contentReady && poi.media.photos.isNotEmpty
                          ? Image.asset(
                              poi.media.photos.first,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              semanticLabel: 'Foto ${poi.name}',
                              errorBuilder: (_, _, _) => const Center(
                                child: Text('Foto belum dapat dimuat'),
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.image_outlined,
                                    size: 26,
                                    color: Color(0xFF8792A4),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    poi.media.photos.isEmpty
                                        ? 'Foto belum tersedia'
                                        : 'Foto POI',
                                    style: const TextStyle(
                                      color: Color(0xFF596477),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (expanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F8FC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          !contentReady
                              ? 'Informasi belum tersedia'
                              : poi.description,
                          style: const TextStyle(fontSize: 11, height: 1.35),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: StreamBuilder<PlaybackState>(
                        stream: audio.state,
                        initialData: audio.current,
                        builder: (context, snapshot) {
                          final playing =
                              snapshot.data?.clip?.poiId == poi.id &&
                              snapshot.data?.clip?.kind ==
                                  AudioClipKind.narration &&
                              snapshot.data?.status == PlaybackStatus.playing;
                          return FilledButton.icon(
                            onPressed: narrationAvailable ? onListen : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF063B82),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF063B82),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(
                              Icons.headphones_rounded,
                              size: 22,
                            ),
                            label: Text(
                              narrationAvailable
                                  ? (playing
                                        ? 'Jeda cerita'
                                        : 'Dengarkan Cerita')
                                  : 'Narasi belum tersedia',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onView,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7EAFF),
                              foregroundColor: _ExploreMapScreenState._navy,
                              side: BorderSide.none,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.info_outline, size: 17),
                            label: const Text(
                              'Lihat',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onSkip,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFE7EAFF),
                              foregroundColor: const Color(0xFF454B5B),
                              side: BorderSide.none,
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.timer_outlined, size: 17),
                            label: const Text(
                              'Lewati',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE9ECFF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
    ),
  );
}

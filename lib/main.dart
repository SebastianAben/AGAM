import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'contracts/contracts.dart';
import 'logic/la_bootstrap.dart';
import 'logic/map/agam_map_config.dart';
import 'logic/routing/campus_routing_service.dart';
import 'logic/routing/device_navigation_controller.dart';
import 'logic/search/poi_search_service.dart';
import 'logic/search/recommendation_bootstrap.dart';
import 'logic/search/repository_facility_service.dart';
import 'logic/trail/account_visit_store.dart';
import 'logic/trail/trail_bootstrap.dart';
import 'ui/app.dart';
import 'logic/session/trigger_notifier.dart';
import 'firebase_options.dart';
import 'logic/account/account_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final (services, views, dismissed, actions) =
      await _createProductionAppServices();
  runApp(
    AgamApp(
      services: services,
      poiViewRequests: views,
      poiDismissed: dismissed,
      onPoiAction: actions,
    ),
  );
}

/// Graf jalan kaki kampus dan lorong tembus gedung yang dibundel (PRD §11).
/// Rute dihitung di perangkat; posisi pengguna tidak dikirim ke mana pun.
Future<RoutingService> _loadCampusRouting() async =>
    CampusRoutingService.fromGeoJson(
      await rootBundle.loadString('assets/routing/ganesha-walk-demo.geojson'),
      passages: await rootBundle.loadString('assets/routing/passages.geojson'),
      corridors: await rootBundle.loadString(
        'assets/routing/corridors.geojson',
      ),
    );

/// Build produk utuh: Firebase, akun asli dengan gerbang login (UI10), batas
/// layanan Kampus Ganesha + 200 m (PRD §9.3), dan seluruh layanan asli LA/LB.
/// Routing memakai graf jalur kampus yang dibundel; trail memakai urutan
/// keliling dari dataset. Rekomendasi (F07) dan kunjungan mode Explore
/// berbagi penyimpanan lokal per akun yang sama dengan trail.
///
/// Permintaan buka POI dan aksi dari notifikasi trigger diteruskan ke UI;
/// tanpa ini notifikasi POI tidak membuka kartunya.
Future<
  (
    AppServices,
    Stream<String>,
    Stream<String>,
    Future<void> Function(String, TriggerAction),
  )
>
_createProductionAppServices() async {
  final map = AgamMapConfig.campus();
  final routing = await _loadCampusRouting();
  // Pintu gedung tempat pengguna berada ikut dicoba sebagai titik awal rute.
  var latestPois = const <Poi>[];
  final la = await createLaServices(
    bundledOnly: false,
    developerTrialAvailable: false,
    map: map,
    navigation: (location, session) => DeviceNavigationController(
      location: location,
      routing: routing,
      map: map,
      session: session,
      pois: () => latestPois,
    ),
  );
  la.pois.watchPois().listen((pois) => latestPois = pois);
  // One store for visited POIs and trail progress per account, so resetting
  // local progress or deleting the account clears both (PRD §15.1, §16).
  final visits = AccountVisitStore();
  final account = await createLaAccountServices(la, trailVisits: visits);
  String? currentUid() => account.auth.current.account?.uid;
  la.session.triggers.listen((event) {
    final uid = currentUid();
    if (uid != null &&
        (event.mode == SessionMode.explore ||
            event.mode == SessionMode.navigation)) {
      unawaited(visits.record(uid, event.poiId).catchError((Object _) {}));
    }
  });
  final trail = createDeviceTrailService(
    pois: la.pois,
    location: la.location,
    session: la.session,
    navigation: la.navigation,
    map: map,
    activity: account.activity,
    currentUid: currentUid,
    accounts: account.auth.state,
    routingAvailable: true,
    visits: visits,
  );
  final facilities = RepositoryFacilityService(la.pois);

  final services = AppServices(
    permissions: la.permissions,
    location: la.location,
    pois: la.pois,
    session: la.session,
    audio: la.audio,
    voice: la.voice,
    settings: la.settings,
    auth: account.auth,
    activity: account.activity,
    map: map,
    routing: routing,
    navigation: la.navigation,
    search: PoiSearchService(pois: la.pois),
    recommendations: createRecommendationService(
      pois: la.pois,
      facilities: facilities,
      visits: visits,
      currentUid: currentUid,
      trail: trail,
    ),
    trail: trail,
    facilities: facilities,
  );
  return (
    services,
    la.triggerResponder.viewRequests,
    la.triggerResponder.dismissedPois,
    (String id, TriggerAction action) => la.triggerResponder.handleAction(
      TriggerActionEvent(poiId: id, action: action),
    ),
  );
}

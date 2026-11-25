import '../../contracts/contracts.dart';
import 'account_visit_store.dart';
import 'device_trail_service.dart';

/// Merangkai [DeviceTrailService] untuk build produk dan demo.
///
/// Trail selesai dicatat sebagai `trailCompleted` lewat [activity]: tanggal
/// saja, tanpa ID POI, titik awal, urutan, atau posisi (PRD §15.5). Titik
/// awal dan kunjungan hanya disimpan lokal per akun di [visits].
DeviceTrailService createDeviceTrailService({
  required PoiRepository pois,
  required LocationService location,
  required SessionController session,
  required NavigationController navigation,
  required MapConfig map,
  required ActivityLogger activity,
  required String? Function() currentUid,
  required Stream<dynamic> accounts,
  required bool routingAvailable,
  AccountVisitStore? visits,
  Duration startFixTimeout = const Duration(seconds: 3),
}) => DeviceTrailService(
  pois: pois,
  location: location,
  visits: visits ?? AccountVisitStore(),
  currentUid: currentUid,
  accounts: accounts,
  session: session,
  navigation: navigation,
  map: map,
  routingAvailable: routingAvailable,
  startFixTimeout: startFixTimeout,
  onComplete: () => activity.log(const ActivityEvent.trailCompleted()),
);

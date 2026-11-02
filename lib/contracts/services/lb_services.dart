/// Antarmuka layanan milik track LB (peta, rute, pencarian, trail).
///
/// Implementasi asli berada di `lib/logic/{map,routing,search,trail}/`.
/// Implementasi palsu berada di `lib/contracts/fakes/`.
library;

import '../models/content.dart';
import '../models/discovery.dart';
import '../models/geo.dart';
import '../models/map.dart';
import '../models/navigation.dart';

abstract interface class MapConfig {
  MapStyleSource get style;
  CampusArea get campusArea;

  /// Titik awal kamera peta.
  GeoPoint get initialCenter;

  /// Apakah [point] berada di area layanan. Di luar area, trigger dan
  /// navigasi tidak aktif.
  bool isInsideCampus(GeoPoint point);
}

abstract interface class RoutingService {
  /// Menghitung rute jalan kaki di perangkat. Dilarang memanggil server
  /// routing (PRD §11). Melempar [RouteUnavailableException] jika tidak ada
  /// rute, mis. titik di luar graf jalur kampus.
  Future<WalkingRoute> route({required GeoPoint from, required GeoPoint to});
}

class RouteUnavailableException implements Exception {
  const RouteUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'RouteUnavailableException: $message';
}

abstract interface class NavigationController {
  NavigationState get current;
  Stream<NavigationState> get state;

  /// Memulai navigasi ke [target]. Pemanggil juga memulai sesi Navigasi
  /// lewat `SessionController`.
  Future<void> start(NavigationTarget target);

  Future<void> stop();
}

abstract interface class SearchService {
  /// Mencari POI dan fasilitas. Mendukung alias, singkatan, serta angka Arab
  /// dan Romawi ("labtek 5" = "Labtek V"). Hasil diurutkan menurut skor.
  ///
  /// [facilityCategories] membatasi fasilitas yang dicari; `null` berarti
  /// semua kategori. [includePois] `false` untuk mencari fasilitas saja.
  Future<List<SearchResult>> search(
    String query, {
    Set<FacilityCategory>? facilityCategories,
    bool includePois = true,
  });
}

abstract interface class RecommendationService {
  /// Rekomendasi setelah kartu POI ditutup atau setelah tiba (F07).
  /// [afterPoiId] adalah POI yang baru dikunjungi, jika ada.
  Future<Recommendation> recommend({
    required GeoPoint from,
    String? afterPoiId,
  });
}

abstract interface class TrailService {
  TrailProgress get current;
  Stream<TrailProgress> get progress;

  /// Mengaktifkan trail. Pemanggil juga memulai sesi Trail lewat
  /// `SessionController`. Check-in terjadi otomatis dari trigger POI.
  Future<void> start();

  /// Menonaktifkan trail tanpa menghapus progres.
  Future<void> stop();

  /// Menghapus progres dan lencana yang tersimpan di perangkat (A01).
  Future<void> reset();
}

abstract interface class FacilityService {
  /// Fasilitas terdekat dari [from], terurut menurut jarak.
  Future<List<FacilityDistance>> nearby({
    required GeoPoint from,
    FacilityCategory? category,
    int limit = 5,
  });
}

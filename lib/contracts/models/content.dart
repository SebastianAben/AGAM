import 'geo.dart';

/// Metadata keterlacakan konten (PRD A02).
class ContentMetadata {
  const ContentMetadata({
    required this.sources,
    required this.verifiedAt,
    required this.owner,
    required this.assetAttribution,
    required this.approved,
    this.isPlaceholder = false,
  });

  /// Metadata untuk data contoh atau konten yang belum tersedia.
  const ContentMetadata.placeholder()
    : sources = const [],
      verifiedAt = null,
      owner = null,
      assetAttribution = const [],
      approved = false,
      isPlaceholder = true;

  final List<String> sources;
  final DateTime? verifiedAt;

  /// Penanggung jawab konten.
  final String? owner;

  final List<String> assetAttribution;

  /// Persetujuan verifikasi tim. Konten yang belum disetujui tidak siap rilis.
  final bool approved;

  /// `true` untuk konten berlabel PLACEHOLDER atau data sintetis.
  /// UI tidak boleh menampilkannya seolah-olah konten final.
  final bool isPlaceholder;
}

enum PoiCategory {
  /// Gedung laboratorium dan perkuliahan.
  laboratoryAndLecture,

  /// Gedung perkuliahan.
  lecture,
}

/// Path aset media di dalam APK. `null` berarti belum tersedia.
class PoiMedia {
  const PoiMedia({
    this.photos = const [],
    this.narrationAudio,
    this.promptAudio,
    this.arrivalAudio,
    this.video,
  });

  final List<String> photos;

  /// Narasi 45–90 detik.
  final String? narrationAudio;

  /// Prompt saat trigger, mis. "Anda mendekati ...".
  final String? promptAudio;

  /// Pengumuman tiba, mis. "Anda telah tiba di ...".
  final String? arrivalAudio;

  /// Hanya untuk GKUB dan GKUT.
  final String? video;
}

class PoiEntrance {
  const PoiEntrance({required this.position, required this.label});

  final GeoPoint position;
  final String label;
}

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.aliases,
    required this.category,
    required this.position,
    required this.radiusM,
    required this.entrances,
    required this.description,
    required this.function,
    required this.facilities,
    required this.trivia,
    required this.media,
    required this.metadata,
    this.trailOrder,
  });

  /// `P01`–`P10`.
  final String id;
  final String name;
  final List<String> aliases;
  final PoiCategory category;

  /// Titik tengah gedung; dipakai untuk geofence.
  final GeoPoint position;

  final double radiusM;

  /// Koordinat pintu masuk dari survei. Kosong selama survei belum dilakukan.
  final List<PoiEntrance> entrances;

  final String description;
  final String function;

  /// Fasilitas di dalam gedung, dalam bentuk teks.
  final List<String> facilities;

  final String trivia;
  final PoiMedia media;
  final ContentMetadata metadata;

  /// Posisi dalam Orientation Trail. `null` selama urutan belum ditetapkan.
  final int? trailOrder;

  bool get hasSurveyedEntrance => entrances.isNotEmpty;

  /// Titik tujuan navigasi. Memakai titik tengah gedung sebagai placeholder
  /// jika pintu masuk belum disurvei (lihat [hasSurveyedEntrance]).
  GeoPoint get navigationPoint =>
      hasSurveyedEntrance ? entrances.first.position : position;
}

enum FacilityCategory {
  toilet,
  musala,
  kantin,
  atm,
  perpustakaan,
  layananAkademik,
}

class Facility {
  const Facility({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.description,
    required this.metadata,
    this.buildingId,
  });

  final String id;
  final String name;
  final FacilityCategory category;
  final GeoPoint position;

  /// ID POI tempat fasilitas berada, jika ada.
  final String? buildingId;

  final String description;
  final ContentMetadata metadata;
}

/// Asal data konten yang sedang dipakai aplikasi.
enum ContentSource {
  /// JSON bawaan di APK.
  bundled,

  /// Salinan terakhir dari Firestore yang tersimpan di perangkat.
  cache,

  /// Baru saja diambil dari Firestore.
  remote,
}

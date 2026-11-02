class AppSettings {
  const AppSettings({this.autoPlayNarration = false});

  /// Putar narasi otomatis saat trigger tanpa menunggu tombol Dengarkan.
  final bool autoPlayNarration;

  AppSettings copyWith({bool? autoPlayNarration}) => AppSettings(
    autoPlayNarration: autoPlayNarration ?? this.autoPlayNarration,
  );
}

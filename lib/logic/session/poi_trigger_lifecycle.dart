/// Kemampuan opsional sesi asli, tanpa mengubah kontrak bersama.
abstract interface class PoiTriggerLifecycle {
  /// ID trigger yang tidak lagi aktif: keluar histeresis, dataset berubah,
  /// atau sesi berakhir. Tidak menyimpan posisi maupun riwayat lokasi.
  Stream<String> get deactivatedPois;
}

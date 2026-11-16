/// Kontrol uji developer opsional; tidak mengubah kontrak SessionController.
abstract interface class PoiTrialControl {
  bool get trialModeAvailable;
  bool get trialModeEnabled;
  Stream<bool> get trialModeChanges;
  void setTrialMode(bool enabled);
}

/// Optional transport capability; the shared AudioService contract is unchanged.
abstract interface class AudioSeekControl {
  Future<void> seekTo(Duration position);
}

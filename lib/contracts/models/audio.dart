enum AudioClipKind { narration, prompt, arrival }

/// File audio milik satu POI.
class AudioClip {
  const AudioClip({required this.poiId, required this.kind});

  final String poiId;
  final AudioClipKind kind;
}

enum PlaybackStatus { idle, playing, paused, completed, error }

class PlaybackState {
  const PlaybackState({
    required this.status,
    this.clip,
    this.position = Duration.zero,
    this.duration,
  });

  const PlaybackState.idle()
    : status = PlaybackStatus.idle,
      clip = null,
      position = Duration.zero,
      duration = null;

  final PlaybackStatus status;
  final AudioClip? clip;
  final Duration position;
  final Duration? duration;
}

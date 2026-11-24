import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'agam_components.dart';
import 'agam_motion.dart';
import 'agam_theme.dart';

/// Membuat controller untuk satu path aset video. Dapat diganti di test.
typedef AgamVideoControllerFactory = VideoPlayerController Function(
  String assetPath,
);

VideoPlayerController _assetController(String assetPath) =>
    VideoPlayerController.asset(assetPath);

/// Pemutar video bundel APK untuk kartu POI (UI04, F03).
///
/// Controller baru dibuat saat pengguna mengetuk putar, sehingga membuka kartu
/// tidak memuat video. Video tidak pernah diputar otomatis. Saat aplikasi masuk
/// latar belakang, `video_player` menjedanya sendiri
/// (`allowBackgroundPlayback` bawaan `false`).
class AgamVideoPlayer extends StatefulWidget {
  const AgamVideoPlayer({
    super.key,
    required this.assetPath,
    this.onPlay,
    this.audioActive = false,
    this.controllerFactory = _assetController,
  });

  final String assetPath;

  /// Dipanggil tepat sebelum video mulai diputar, mis. untuk menjeda narasi.
  final VoidCallback? onPlay;

  /// Saat berubah menjadi `true` (audio POI mulai diputar), video dijeda agar
  /// dua suara tidak tumpang tindih.
  final bool audioActive;

  final AgamVideoControllerFactory controllerFactory;

  @override
  State<AgamVideoPlayer> createState() => _AgamVideoPlayerState();
}

class _AgamVideoPlayerState extends State<AgamVideoPlayer> {
  static const _maxHeight = 420.0;

  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  bool _fullscreen = false;

  @override
  void didUpdateWidget(AgamVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioActive &&
        !oldWidget.audioActive &&
        _controller?.value.isPlaying == true) {
      unawaited(_controller!.pause());
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = widget.controllerFactory(widget.assetPath);
    try {
      await controller.initialize();
    } catch (_) {
      unawaited(controller.dispose());
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted) {
      unawaited(controller.dispose());
      return;
    }
    setState(() {
      _controller = controller;
      _loading = false;
    });
    await _play();
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null) return;
    widget.onPlay?.call();
    if (controller.value.isCompleted ||
        controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null) return _start();
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await _play();
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _fullscreen = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullscreenVideo(controller: controller, onToggle: _toggle),
      ),
    );
    if (mounted) setState(() => _fullscreen = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AgamGround(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  color: AgamColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Video',
                  style: AgamText.headline.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final height = (constraints.maxWidth * 16 / 9).clamp(
                0.0,
                _maxHeight,
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(AgamRadius.control),
                child: SizedBox(
                  height: height,
                  child: ColoredBox(
                    color: Colors.black,
                    child: controller == null || _fullscreen
                        ? _poster()
                        : _VideoSurface(
                            controller: controller,
                            onToggle: _toggle,
                          ),
                  ),
                ),
              );
            },
          ),
          if (controller != null) ...[
            const SizedBox(height: 12),
            _VideoControls(
              controller: controller,
              onToggle: _toggle,
              onFullscreen: _fullscreen ? null : _openFullscreen,
            ),
          ],
        ],
      ),
    );
  }

  Widget _poster() {
    final Widget content;
    if (_loading) {
      content = const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
      );
    } else if (_failed) {
      content = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white.withValues(alpha: .8),
            ),
            const SizedBox(height: 8),
            const Text(
              'Video belum dapat diputar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _start,
              style: TextButton.styleFrom(foregroundColor: AgamColors.cyan),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    } else if (_fullscreen) {
      content = Text(
        'Sedang diputar di layar penuh',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .75),
          fontSize: 13,
        ),
      );
    } else {
      content = _bigPlayButton(onTap: _start);
    }
    return Center(child: content);
  }
}

Widget _bigPlayButton({required VoidCallback onTap}) => Tooltip(
  message: 'Putar video',
  child: AgamPressFeedback(
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox.square(
          dimension: 64,
          child: Icon(
            Icons.play_arrow_rounded,
            size: 34,
            color: AgamColors.brandDeep,
          ),
        ),
      ),
    ),
  ),
);

/// Gambar video di tengah latar hitam; ketuk untuk jeda/putar.
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller, required this.onToggle});

  final VideoPlayerController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onToggle,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) => AnimatedOpacity(
            opacity: value.isPlaying ? 0 : 1,
            duration: AgamMotion.duration(context, 160),
            child: IgnorePointer(
              ignoring: value.isPlaying,
              child: Center(child: _bigPlayButton(onTap: onToggle)),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Progres (dapat digeser), waktu, putar/jeda, dan layar penuh.
class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.onToggle,
    this.onFullscreen,
  });

  final VideoPlayerController controller;
  final VoidCallback onToggle;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Progres video',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white.withValues(alpha: .35),
                    backgroundColor: Colors.white.withValues(alpha: .18),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _iconButton(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: value.isPlaying ? 'Jeda video' : 'Putar video',
                  onPressed: onToggle,
                ),
                const SizedBox(width: 10),
                Text(
                  '${_format(value.position)} / ${_format(value.duration)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (onFullscreen != null)
                  _iconButton(
                    Icons.fullscreen_rounded,
                    tooltip: 'Layar penuh',
                    onPressed: onFullscreen!,
                  ),
              ],
            ),
          ],
        ),
      );
}

Widget _iconButton(
  IconData icon, {
  required String tooltip,
  required VoidCallback onPressed,
}) => Tooltip(
  message: tooltip,
  child: Material(
    color: Colors.white.withValues(alpha: .14),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: 44,
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    ),
  ),
);

String _format(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Layar penuh memakai controller yang sama; menutupnya tidak membuang
/// controller sehingga posisi pemutaran tetap.
class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({required this.controller, required this.onToggle});

  final VideoPlayerController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _iconButton(
                Icons.close_rounded,
                tooltip: 'Tutup layar penuh',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Expanded(
            child: _VideoSurface(controller: controller, onToggle: onToggle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _VideoControls(controller: controller, onToggle: onToggle),
          ),
        ],
      ),
    ),
  );
}

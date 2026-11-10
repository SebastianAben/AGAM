import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/models/audio.dart';
import '../contracts/models/content.dart';
import '../contracts/services/la_services.dart';

/// UI04 — Detail Lokasi. Only approved POI content is presented as factual.
class PoiDetailScreen extends StatefulWidget {
  const PoiDetailScreen({
    super.key,
    required this.poi,
    required this.audio,
    required this.onNavigate,
    required this.checkedIn,
  });

  final Poi poi;
  final AudioService audio;
  final Future<void> Function() onNavigate;
  final bool checkedIn;

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen> {
  static const _navy = Color(0xFF104DA5);
  static const _ink = Color(0xFF202A3D);
  bool _transcriptExpanded = false;
  bool _navigating = false;
  late PlaybackState _playback;
  StreamSubscription<PlaybackState>? _playbackSubscription;

  @override
  void initState() {
    super.initState();
    _playback = widget.audio.current;
    _playbackSubscription = widget.audio.state.listen((playback) {
      if (mounted) setState(() => _playback = playback);
    });
  }

  @override
  void dispose() {
    unawaited(_playbackSubscription?.cancel());
    super.dispose();
  }

  bool get _contentReady =>
      widget.poi.metadata.approved && !widget.poi.metadata.isPlaceholder;

  bool get _audioAvailable =>
      _contentReady && widget.poi.media.narrationAudio?.isNotEmpty == true;

  bool get _currentNarration =>
      _playback.clip?.poiId == widget.poi.id &&
      _playback.clip?.kind == AudioClipKind.narration;

  String get _aliasLabel => widget.poi.aliases.isEmpty
      ? 'Alias belum tersedia'
      : 'Alias: ${widget.poi.aliases.join(', ')}';

  String get _pendingContent =>
      'PLACEHOLDER — menunggu tim konten dan verifikasi sumber.';

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text(
          'Detail Lokasi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFFFAF8FF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _hero(poi)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            sliver: SliverList.list(
              children: [
                _narrationCard(poi),
                const SizedBox(height: 14),
                _contentSection(
                  icon: Icons.apartment_rounded,
                  title: 'Fungsi & Gambaran Gedung',
                  child: Text(
                    _contentReady && poi.function.trim().isNotEmpty
                        ? poi.function
                        : _pendingContent,
                    style: const TextStyle(
                      color: Color(0xFF596273),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _contentSection(
                  icon: Icons.grid_view_rounded,
                  title: 'Fasilitas Dalam Gedung',
                  child: _facilities(poi),
                ),
                const SizedBox(height: 14),
                _triviaCard(poi),
                const SizedBox(height: 14),
                _sourcesCard(poi),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomActions(),
    );
  }

  Widget _hero(Poi poi) {
    final photos = _contentReady ? poi.media.photos : const <String>[];
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isNotEmpty)
            Image.asset(
              photos.first,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _heroPlaceholder(),
            )
          else
            _heroPlaceholder(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC071A38)],
                stops: [0.35, 1],
              ),
            ),
          ),
          if (photos.isEmpty)
            Positioned(
              top: 12,
              left: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  child: Text(
                    'FOTO PLACEHOLDER',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  poi.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _aliasLabel,
                  style: const TextStyle(
                    color: Color(0xFFE4EAF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPlaceholder() => ClipRect(
    child: Container(
      color: const Color(0xFFDDE7F6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            top: 28,
            right: 28,
            child: Icon(
              Icons.location_city_rounded,
              size: 118,
              color: Color(0xFFB7C9E6),
            ),
          ),
          CustomPaint(painter: _BuildingPlaceholderPainter()),
        ],
      ),
    ),
  );

  Widget _narrationCard(Poi poi) {
    final audioAvailable = _audioAvailable;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _CircleIcon(
                icon: Icons.headphones_rounded,
                color: Color(0xFF49D6F1),
                foreground: Color(0xFF075875),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Narasi Sejarah & Fungsi ${poi.aliases.isEmpty ? poi.name : poi.aliases.first}',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 29; i++)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 3,
                        height: 10.0 + ((i * 17) % 28),
                        decoration: BoxDecoration(
                          color:
                              _currentNarration &&
                                  _playback.duration != null &&
                                  i / 29 <=
                                      (_playback.position.inMilliseconds /
                                          _playback.duration!.inMilliseconds)
                              ? _navy
                              : const Color(0xFFD7DDFC),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                audioAvailable
                    ? _formatDuration(
                        _currentNarration ? _playback.position : Duration.zero,
                      )
                    : 'Audio belum tersedia',
                style: const TextStyle(
                  color: _navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                audioAvailable &&
                        _currentNarration &&
                        _playback.duration != null &&
                        _playback.duration!.inMilliseconds > 0
                    ? _formatDuration(_playback.duration!)
                    : '--:--',
                style: const TextStyle(
                  color: Color(0xFF70798A),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _smallControl(Icons.speed_rounded, '1.0×', enabled: false),
              const Spacer(),
              _roundControl(Icons.replay_10_rounded, enabled: false),
              const SizedBox(width: 9),
              _roundControl(
                Icons.play_arrow_rounded,
                enabled: audioAvailable,
                primary: audioAvailable,
                onPressed: _toggleNarration,
              ),
              const SizedBox(width: 9),
              _roundControl(Icons.forward_10_rounded, enabled: false),
              const Spacer(),
              _smallControl(Icons.volume_up_rounded, '', enabled: false),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.autorenew_rounded,
                  size: 15,
                  color: Color(0xFF647086),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Putar Narasi Otomatis',
                    style: TextStyle(fontSize: 10, color: Color(0xFF596273)),
                  ),
                ),
                Switch.adaptive(
                  value: false,
                  onChanged: null,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: const Color(0xFFF0F2FF),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  setState(() => _transcriptExpanded = !_transcriptExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.subject_rounded,
                          size: 15,
                          color: _navy,
                        ),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'Transkrip Teks Narasi',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _transcriptExpanded
                              ? Icons.expand_less_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 17,
                          color: _navy,
                        ),
                      ],
                    ),
                    if (_transcriptExpanded) ...[
                      const SizedBox(height: 8),
                      Text(
                        _pendingContent,
                        style: const TextStyle(
                          color: Color(0xFF626B7A),
                          fontSize: 11,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!audioAvailable) ...[
            const SizedBox(height: 8),
            const Text(
              'Audio placeholder · belum dapat diputar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF737D90), fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _toggleNarration() async {
    if (!_audioAvailable) return;
    if (_currentNarration && _playback.status == PlaybackStatus.playing) {
      await widget.audio.pause();
    } else if (_currentNarration && _playback.status == PlaybackStatus.paused) {
      await widget.audio.resume();
    } else {
      await widget.audio.play(
        AudioClip(poiId: widget.poi.id, kind: AudioClipKind.narration),
      );
    }
  }

  Widget _contentSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: _navy),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _facilities(Poi poi) {
    if (!_contentReady || poi.facilities.isEmpty) {
      return _placeholderPanel(_pendingContent);
    }
    return Column(
      children: [
        for (final facility in poi.facilities) ...[
          _placeholderPanel(facility),
          if (facility != poi.facilities.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _triviaCard(Poi poi) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF50D8F2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: _navy),
            SizedBox(width: 6),
            Text(
              'TRIVIA & SEJARAH KAMPUS',
              style: TextStyle(
                color: Color(0xFF075875),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _contentReady && poi.trivia.trim().isNotEmpty
              ? poi.trivia
              : _pendingContent,
          style: const TextStyle(
            color: Color(0xFF075875),
            fontSize: 12,
            height: 1.55,
          ),
        ),
      ],
    ),
  );

  Widget _sourcesCard(Poi poi) {
    final sources = _contentReady ? poi.metadata.sources : const <String>[];
    final attributions = _contentReady
        ? poi.metadata.assetAttribution
        : const <String>[];
    return _contentSection(
      icon: Icons.source_outlined,
      title: 'Sumber Informasi',
      child: Text(
        [...sources, ...attributions].isEmpty
            ? _pendingContent
            : [...sources, ...attributions].join('\n'),
        style: const TextStyle(
          color: Color(0xFF626B7A),
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _placeholderPanel(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F2FF),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF596273),
        fontSize: 11,
        height: 1.45,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120C2452),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _smallControl(IconData icon, String label, {required bool enabled}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF637086)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  color: enabled ? _navy : const Color(0xFF596273),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );

  Widget _roundControl(
    IconData icon, {
    required bool enabled,
    bool primary = false,
    VoidCallback? onPressed,
  }) => Material(
    color: primary ? _navy : const Color(0xFFF0F2FF),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: enabled ? onPressed : null,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: primary ? 42 : 36,
        height: primary ? 42 : 36,
        child: Icon(
          _currentNarration && _playback.status == PlaybackStatus.playing
              ? Icons.pause_rounded
              : icon,
          color: primary
              ? Colors.white
              : enabled
              ? _navy
              : const Color(0xFF596273),
          size: primary ? 23 : 18,
        ),
      ),
    ),
  );

  Widget _bottomActions() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE6E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _navigating ? null : _navigate,
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: _navigating
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.directions_walk_rounded, size: 17),
                label: const Text(
                  'Navigasi Jalan Kaki',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.checkedIn
                      ? 'Check-in ${widget.poi.name} sudah tercatat otomatis.'
                      : 'Check-in akan tercatat otomatis saat lokasi terdeteksi.',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            tooltip: widget.checkedIn ? 'Sudah check-in' : 'Check-in otomatis',
            icon: Icon(
              widget.checkedIn
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded,
            ),
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              backgroundColor: const Color(0xFFE9ECFF),
              foregroundColor: _navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _navigate() async {
    setState(() => _navigating = true);
    try {
      await widget.onNavigate();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.icon,
    required this.color,
    required this.foreground,
  });

  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, color: foreground, size: 19),
  );
}

class _BuildingPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCCD8EB);
    final edge = Paint()
      ..color = const Color(0xFFB6C6DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(
      size.width * 0.12,
      size.height * 0.32,
      size.width * 0.76,
      size.height * 0.58,
    );
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, edge);
    for (var column = 0; column < 5; column++) {
      for (var row = 0; row < 3; row++) {
        final window = Rect.fromLTWH(
          rect.left + 13 + column * ((rect.width - 30) / 5),
          rect.top + 14 + row * 27,
          13,
          16,
        );
        canvas.drawRect(window, Paint()..color = const Color(0xFF9FB3D1));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BuildingPlaceholderPainter oldDelegate) =>
      false;
}

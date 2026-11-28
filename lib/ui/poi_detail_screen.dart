import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/models/activity.dart';
import '../contracts/models/audio.dart';
import '../contracts/models/content.dart';
import '../contracts/services/la_services.dart';
import '../contracts/models/settings.dart';
import '../logic/audio/audio_seek_control.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/narration_wave.dart';
import 'widgets/agam_theme.dart';
import 'widgets/agam_video_player.dart';

/// UI04 — Detail Lokasi. Only approved POI content is presented as factual.
class PoiDetailScreen extends StatefulWidget {
  const PoiDetailScreen({
    super.key,
    required this.poi,
    required this.audio,
    required this.onNavigate,
    required this.checkedIn,
    this.navigationAvailable = true,
    this.settings,
    this.activity,
  });

  final SettingsStore? settings;

  /// Records `featureUsed` (PRD §15.5): `poiCard` once when this screen
  /// opens and `narration` each time the user starts the narration afresh
  /// (never on resume). Null when the screen was opened from a POI trigger,
  /// because the event's time would match the arrival at that POI.
  final ActivityLogger? activity;
  final Poi poi;
  final AudioService audio;
  final Future<void> Function() onNavigate;
  final bool checkedIn;
  final bool navigationAvailable;

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen> {
  static const _heroHeight = 320.0;

  bool _transcriptExpanded = false;
  bool _navigating = false;
  late PlaybackState _playback;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  NarrationEnvelope? _waveEnvelope;

  @override
  void initState() {
    super.initState();
    widget.activity?.log(
      const ActivityEvent.featureUsed(feature: ActivityFeature.poiCard),
    );
    if (_audioAvailable) {
      unawaited(
        NarrationEnvelope.load(widget.poi.media.narrationAudio!).then((value) {
          if (mounted && value != null) setState(() => _waveEnvelope = value);
        }),
      );
    }
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

  /// Video hanya ditampilkan bila tersedia dan kontennya sudah disetujui
  /// (F03: GKUB/GKUT, video opsional).
  String? get _videoPath {
    final video = widget.poi.media.video;
    return _contentReady && video != null && video.trim().isNotEmpty
        ? video
        : null;
  }

  /// Dua suara tidak diputar bersamaan: audio POI apa pun dijeda saat video
  /// mulai.
  void _pauseAudioForVideo() {
    if (widget.audio.current.status == PlaybackStatus.playing) {
      unawaited(widget.audio.pause());
    }
  }

  String get _pendingContent => 'Informasi belum tersedia.';

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: _heroHeight,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: Navigator.canPop(context)
                ? const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: AgamBackButton(),
                  )
                : null,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final collapsed =
                    constraints.maxHeight <= kToolbarHeight + topInset + 24;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: _hero(poi),
                    ),
                    Positioned(
                      left: 72,
                      right: 24,
                      bottom: 0,
                      height: kToolbarHeight,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: collapsed ? 1 : 0,
                          duration: AgamMotion.duration(context, 180),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              poi.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AgamText.headline,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverList.list(
              children: [
                AgamReveal(child: _narrationCard(poi)),
                if (_videoPath case final video?) ...[
                  const SizedBox(height: 16),
                  AgamReveal(
                    child: AgamVideoPlayer(
                      assetPath: video,
                      audioActive: _playback.status == PlaybackStatus.playing,
                      onPlay: _pauseAudioForVideo,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                AgamReveal(order: 1, child: _transcript(poi)),
                const SizedBox(height: 28),
                AgamReveal(
                  order: 2,
                  child: _section(
                    icon: Icons.apartment_rounded,
                    title: 'Fungsi',
                    child: Text(
                      _contentReady && poi.function.trim().isNotEmpty
                          ? poi.function
                          : _pendingContent,
                      style: AgamText.body,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AgamReveal(
                  order: 3,
                  child: _section(
                    icon: Icons.grid_view_rounded,
                    title: 'Fasilitas',
                    child: _facilities(poi),
                  ),
                ),
                const SizedBox(height: 28),
                AgamReveal(order: 4, child: _triviaCard(poi)),
                const SizedBox(height: 28),
                AgamReveal(order: 5, child: _sourcesCard(poi)),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isNotEmpty)
          Image.asset(
            photos.first,
            fit: BoxFit.cover,
            cacheWidth: 1080,
            errorBuilder: (_, _, _) => _heroPlaceholder(),
          )
        else
          _heroPlaceholder(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66061A3D),
                Colors.transparent,
                Color(0xD9061A3D),
              ],
              stops: [0, .35, 1],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                poi.name,
                style: AgamText.display.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
              ),
              if (poi.aliases.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  poi.aliases.join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        // The white sheet starts inside the hero, as on the onboarding.
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: 29,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AgamRadius.sheet),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// No drawn building: an honest empty ground with a label.
  Widget _heroPlaceholder() => AgamGround(
    radius: 0,
    padding: EdgeInsets.zero,
    child: SizedBox.expand(
      child: Align(
        alignment: const Alignment(.55, -.2),
        child: Icon(
          Icons.apartment_rounded,
          size: 120,
          color: Colors.white.withValues(alpha: .16),
        ),
      ),
    ),
  );

  Widget _narrationCard(Poi poi) {
    final audioAvailable = _audioAvailable;
    final playing =
        _currentNarration && _playback.status == PlaybackStatus.playing;
    final duration = _currentNarration ? _playback.duration : null;
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
                child: AnimatedSwitcher(
                  duration: AgamMotion.duration(context, 200),
                  transitionBuilder: AgamMotion.iconSwap,
                  child: _narrationGlyph(playing),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Narasi',
                  style: AgamText.headline.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: .22),
              disabledActiveTrackColor: Colors.white.withValues(alpha: .4),
              disabledInactiveTrackColor: Colors.white.withValues(alpha: .18),
              thumbColor: Colors.white,
              disabledThumbColor: Colors.white.withValues(alpha: .5),
              overlayColor: Colors.white.withValues(alpha: .12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              semanticFormatterCallback: (value) =>
                  '${(value / 1000).round()} detik',
              min: 0,
              max: duration?.inMilliseconds.toDouble() ?? 1,
              value: _currentNarration && _playback.duration != null
                  ? _playback.position.inMilliseconds.toDouble().clamp(
                      0,
                      _playback.duration!.inMilliseconds.toDouble(),
                    )
                  : 0,
              onChanged: _canSeek
                  ? (value) => (widget.audio as AudioSeekControl).seekTo(
                      Duration(milliseconds: value.round()),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    audioAvailable
                        ? _formatDuration(
                            _currentNarration
                                ? _playback.position
                                : Duration.zero,
                          )
                        : 'Audio belum tersedia',
                    style: _timeStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  audioAvailable &&
                          duration != null &&
                          duration.inMilliseconds > 0
                      ? _formatDuration(duration)
                      : '--:--',
                  style: _timeStyle,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _transport(audioAvailable: audioAvailable, playing: playing),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AgamRadius.control),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.autorenew_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: .8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Putar Narasi Otomatis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.settings case final settings?)
                  StreamBuilder<AppSettings>(
                    stream: settings.settings,
                    initialData: settings.current,
                    builder: (context, snapshot) => Switch(
                      value: snapshot.data!.autoPlayNarration,
                      activeThumbColor: AgamColors.brandDeep,
                      activeTrackColor: AgamColors.cyan,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.white.withValues(alpha: .2),
                      trackOutlineColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      onChanged: (value) async {
                        try {
                          await settings.update(
                            settings.current.copyWith(autoPlayNarration: value),
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pengaturan belum dapat disimpan.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Headphones while idle; while playing, bars that follow the narration's
  /// loudness. Without an envelope, or with reduced motion, a static
  /// equaliser icon stands in rather than a fake animation.
  Widget _narrationGlyph(bool playing) {
    if (!playing) {
      return const Icon(
        Icons.headphones_rounded,
        key: ValueKey('idle'),
        color: AgamColors.cyan,
        size: 20,
      );
    }
    final envelope = _waveEnvelope;
    if (envelope == null || MediaQuery.disableAnimationsOf(context)) {
      return const Icon(
        Icons.graphic_eq_rounded,
        key: ValueKey('playing'),
        color: AgamColors.cyan,
        size: 20,
      );
    }
    return NarrationWave(
      key: const ValueKey('wave'),
      envelope: envelope,
      playing: _playback.status == PlaybackStatus.playing,
      position: _playback.position,
      color: AgamColors.cyan,
    );
  }

  static final _timeStyle = TextStyle(
    color: Colors.white.withValues(alpha: .75),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Replay, back 10 s, play, forward 10 s and stop. The roomy layout needs
  /// [_roomyTransportWidth]; narrower cards (320 dp phones, large text) drop
  /// the spacers and shrink the play button, keeping every target at 44 dp.
  /// Only below the compact row's own width does it scale down as a whole.
  static const _roomyTransportWidth = 288.0;
  static const _compactTransportWidth = 4 * 44.0 + 56;

  Widget _transport({required bool audioAvailable, required bool playing}) {
    final replay = _control(
      Icons.replay_rounded,
      tooltip: 'Ulangi narasi',
      enabled: audioAvailable,
      onPressed: () =>
          _currentNarration ? widget.audio.replay() : _toggleNarration(),
    );
    final back = _control(
      Icons.replay_10_rounded,
      tooltip: 'Mundur 10 detik',
      enabled: _canSeek,
      onPressed: () => _seekBy(-10),
    );
    final forward = _control(
      Icons.forward_10_rounded,
      tooltip: 'Maju 10 detik',
      enabled: _canSeek,
      onPressed: () => _seekBy(10),
    );
    final stop = _control(
      Icons.stop_rounded,
      tooltip: 'Hentikan narasi',
      enabled: _currentNarration,
      onPressed: widget.audio.stop,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _roomyTransportWidth) {
          return Row(
            children: [
              replay,
              const Spacer(),
              back,
              const SizedBox(width: 14),
              _playButton(enabled: audioAvailable, playing: playing),
              const SizedBox(width: 14),
              forward,
              const Spacer(),
              stop,
            ],
          );
        }
        final compact = SizedBox(
          width: constraints.maxWidth < _compactTransportWidth
              ? _compactTransportWidth
              : constraints.maxWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              replay,
              back,
              _playButton(
                enabled: audioAvailable,
                playing: playing,
                dimension: 56,
              ),
              forward,
              stop,
            ],
          ),
        );
        if (constraints.maxWidth >= _compactTransportWidth) return compact;
        return FittedBox(fit: BoxFit.scaleDown, child: compact);
      },
    );
  }

  Widget _playButton({
    required bool enabled,
    required bool playing,
    double dimension = 64,
  }) => Tooltip(
    message: playing ? 'Jeda narasi' : 'Putar narasi',
    child: AgamPressFeedback(
      child: Material(
        color: enabled ? Colors.white : Colors.white.withValues(alpha: .2),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled ? _toggleNarration : null,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: dimension,
            child: AnimatedSwitcher(
              duration: AgamMotion.duration(context, 160),
              transitionBuilder: AgamMotion.iconSwap,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(playing),
                size: dimension / 2,
                color: enabled ? AgamColors.brandDeep : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _control(
    IconData icon, {
    required String tooltip,
    required bool enabled,
    VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white.withValues(alpha: enabled ? .14 : .06),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(
            icon,
            size: 22,
            color: Colors.white.withValues(alpha: enabled ? 1 : .4),
          ),
        ),
      ),
    ),
  );

  bool get _canSeek =>
      _audioAvailable &&
      _currentNarration &&
      _playback.duration != null &&
      _playback.duration! > Duration.zero &&
      widget.audio is AudioSeekControl;

  Future<void> _seekBy(int seconds) async {
    if (!_canSeek) return;
    await (widget.audio as AudioSeekControl).seekTo(
      _playback.position + Duration(seconds: seconds),
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
      widget.activity?.log(
        const ActivityEvent.featureUsed(feature: ActivityFeature.narration),
      );
      await widget.audio.play(
        AudioClip(poiId: widget.poi.id, kind: AudioClipKind.narration),
      );
    }
  }

  Widget _transcript(Poi poi) => Material(
    color: AgamColors.canvas,
    borderRadius: BorderRadius.circular(AgamRadius.tile),
    child: InkWell(
      borderRadius: BorderRadius.circular(AgamRadius.tile),
      onTap: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.subject_rounded,
                  size: 20,
                  color: AgamColors.brand,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Tentang gedung', style: AgamText.label),
                ),
                AnimatedRotation(
                  turns: _transcriptExpanded ? .5 : 0,
                  duration: AgamMotion.duration(context, 220),
                  curve: AgamMotion.easeOut,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AgamColors.muted,
                  ),
                ),
              ],
            ),
            AgamAnimatedSize(
              milliseconds: 240,
              curve: AgamMotion.easeOut,
              alignment: Alignment.topCenter,
              child: _transcriptExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _contentReady ? poi.description : _pendingContent,
                        style: AgamText.body.copyWith(fontSize: 14),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          AgamIconTile(icon: icon, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AgamText.headline)),
        ],
      ),
      const SizedBox(height: 12),
      child,
    ],
  );

  Widget _facilities(Poi poi) {
    if (!_contentReady || poi.facilities.isEmpty) {
      return _placeholderPanel(_pendingContent);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final facility in poi.facilities)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AgamColors.canvas,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _facilityIcon(facility),
                  size: 16,
                  color: AgamColors.brand,
                ),
                const SizedBox(width: 6),
                Text(facility, style: AgamText.label.copyWith(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  /// Icon for a facility name from the dataset. Names are matched loosely
  /// so variants like "Toilet Pria" still get the right glyph; anything
  /// unknown gets a neutral marker instead of a misleading picture.
  static IconData _facilityIcon(String facility) {
    final name = facility.toLowerCase();
    bool has(String word) => name.contains(word);
    if (has('toilet') || has('wc') || has('kamar mandi')) {
      return Icons.wc_rounded;
    }
    if (has('mushal') || has('musal') || has('masjid') || has('musholla')) {
      return Icons.mosque_rounded;
    }
    if (has('kantin') || has('kafe') || has('makan')) {
      return Icons.restaurant_rounded;
    }
    if (has('apotek') || has('klinik') || has('kesehatan')) {
      return Icons.local_pharmacy_rounded;
    }
    if (has('lab')) return Icons.science_rounded;
    if (has('kelas') || has('kuliah')) return Icons.school_rounded;
    if (has('perpustakaan')) return Icons.local_library_rounded;
    if (has('parkir')) return Icons.local_parking_rounded;
    if (has('atm')) return Icons.local_atm_rounded;
    return Icons.place_rounded;
  }

  Widget _triviaCard(Poi poi) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AgamColors.cyan.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(AgamRadius.tile),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.lightbulb_rounded,
              size: 18,
              color: AgamColors.teal,
            ),
            const SizedBox(width: 8),
            Text(
              'Trivia',
              style: AgamText.label.copyWith(color: AgamColors.teal),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _contentReady && poi.trivia.trim().isNotEmpty
              ? poi.trivia
              : _pendingContent,
          style: AgamText.body.copyWith(color: AgamColors.ink, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _sourcesCard(Poi poi) {
    final sources = _contentReady ? poi.metadata.sources : const <String>[];
    final attributions = _contentReady
        ? poi.metadata.assetAttribution
        : const <String>[];
    final assetPrefix = RegExp(r'^assets/media/.+? — ');
    final lines = {
      ...sources,
      for (final entry in attributions) entry.replaceFirst(assetPrefix, ''),
    };
    return _section(
      icon: Icons.source_outlined,
      title: 'Sumber',
      child: Text(
        lines.isEmpty ? _pendingContent : lines.join('\n'),
        style: AgamText.caption.copyWith(fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget _placeholderPanel(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AgamColors.canvas,
      borderRadius: BorderRadius.circular(AgamRadius.control),
    ),
    child: Text(text, style: AgamText.bodySmall),
  );

  Widget _bottomActions() => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x140B1F44),
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: AgamRouteButton(
                available: widget.navigationAvailable,
                primary: true,
                onPressed: _navigating ? null : _navigate,
                busy: _navigating,
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: widget.checkedIn ? 'Sudah check-in' : 'Belum dikunjungi',
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: widget.checkedIn
                      ? AgamColors.successTint
                      : AgamColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.checkedIn
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  color: widget.checkedIn
                      ? AgamColors.success
                      : AgamColors.subtle,
                ),
              ),
            ),
          ],
        ),
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

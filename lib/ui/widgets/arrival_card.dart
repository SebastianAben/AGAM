import 'package:flutter/material.dart';

import '../../contracts/models/navigation.dart';
import '../../contracts/services/la_services.dart';
import 'agam_components.dart';
import 'agam_motion.dart';
import 'agam_theme.dart';

/// The destination card once navigation reports arrival (UI07, F06).
///
/// It takes the place of the route summary in the same card: the map stays
/// where it was, so only the text and actions below it change. That content
/// fades in and rises 8 px over 240 ms with [AgamMotion.easeOut]; the card's
/// own height change is left to the list's `AnimatedSize`. Reduced motion
/// shows it at rest straight away.
///
/// A facility has no recorded arrival clip; it is announced with TTS (PRD
/// §10). When no Indonesian voice is installed that announcement stays
/// silent, so the card says once, inline, how to get one. Voice
/// availability is asked once, when the card appears.
///
/// A facility inside a building is reached at the building's door, so the
/// card ends the outdoor route with where to go inside ([locationHint], e.g.
/// "Labtek V, lantai 3"). The last Orientation Trail stop can add a calm
/// [completionNote]; the card stays until the user taps Selesai.
class ArrivalCard extends StatefulWidget {
  const ArrivalCard({
    super.key,
    required this.name,
    required this.kind,
    required this.voice,
    required this.onFinish,
    this.onOpenDetail,
    this.map,
    this.locationHint,
    this.enterBuilding = false,
    this.completionNote,
  });

  final String name;
  final NavigationTargetKind kind;
  final VoiceGuidance voice;

  /// Ends navigation, like the route card's close button.
  final VoidCallback onFinish;

  /// Opens the building's detail; only offered for a POI.
  final VoidCallback? onOpenDetail;

  /// The card's map, kept from the route summary for continuity.
  final Widget? map;

  /// Where a facility is inside or around its building, as written in its
  /// data. Shown for a facility only; never written by the app itself.
  final String? locationHint;

  /// The route ended at a building door, so the card adds [indoorNote].
  final bool enterBuilding;

  /// A short note shown above the actions, e.g. Trail completion.
  final String? completionNote;

  static const indoorNote = 'Masuk ke gedung, lalu menuju lokasi ini.';

  static const voiceNote =
      'Suara Bahasa Indonesia belum terpasang, jadi kedatangan tidak '
      'diumumkan. Pasang data suaranya di pengaturan text-to-speech (TTS) '
      'Android.';

  static String headline(String name) => 'Anda telah tiba di $name';

  @override
  State<ArrivalCard> createState() => _ArrivalCardState();
}

class _ArrivalCardState extends State<ArrivalCard>
    with SingleTickerProviderStateMixin {
  static const _rise = 8.0;

  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final _curve = CurvedAnimation(
    parent: _entrance,
    curve: AgamMotion.easeOut,
  );
  bool _voiceMissing = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == NavigationTargetKind.facility) _checkVoice();
  }

  Future<void> _checkVoice() async {
    bool available;
    try {
      available = await widget.voice.isAvailable();
    } catch (_) {
      available = false;
    }
    if (mounted && !available) setState(() => _voiceMissing = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entrance.isDismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _entrance.dispose();
    super.dispose();
  }

  String? get _indoorHint {
    final hint = widget.locationHint?.trim();
    if (widget.kind != NavigationTargetKind.facility) return null;
    return hint == null || hint.isEmpty ? null : hint;
  }

  @override
  Widget build(BuildContext context) {
    final openDetail = widget.onOpenDetail;
    final indoorHint = _indoorHint;
    final completionNote = widget.completionNote;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.map case final map?) SizedBox(height: 168, child: map),
          AnimatedBuilder(
            animation: _curve,
            builder: (context, child) => Opacity(
              opacity: _curve.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - _curve.value) * _rise),
                child: child,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AgamIconTile(
                        icon: Icons.where_to_vote_rounded,
                        background: AgamColors.successTint,
                        foreground: AgamColors.success,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          header: true,
                          child: Text(
                            ArrivalCard.headline(widget.name),
                            style: AgamText.title,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (indoorHint != null) ...[
                    const SizedBox(height: 14),
                    _IndoorCue(
                      hint: indoorHint,
                      enterBuilding: widget.enterBuilding,
                    ),
                  ],
                  if (completionNote != null) ...[
                    const SizedBox(height: 14),
                    _CompletionNote(text: completionNote),
                  ],
                  if (_voiceMissing) ...[
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.volume_off_rounded,
                            size: 18,
                            color: AgamColors.subtle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ArrivalCard.voiceNote,
                            style: AgamText.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (openDetail != null) ...[
                    AgamPrimaryButton(
                      icon: Icons.info_outline_rounded,
                      label: 'Lihat Detail POI',
                      onPressed: openDetail,
                    ),
                    const SizedBox(height: 10),
                    AgamTonalButton(
                      icon: Icons.check_rounded,
                      label: 'Selesai',
                      onPressed: widget.onFinish,
                    ),
                  ] else
                    AgamPrimaryButton(
                      icon: Icons.check_rounded,
                      label: 'Selesai',
                      onPressed: widget.onFinish,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The second stage of a facility route: the outdoor walk ends at the
/// building door, and this says where to go once inside.
class _IndoorCue extends StatelessWidget {
  const _IndoorCue({required this.hint, required this.enterBuilding});

  final String hint;
  final bool enterBuilding;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: enterBuilding ? '$hint. ${ArrivalCard.indoorNote}' : hint,
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AgamColors.tint,
        borderRadius: BorderRadius.circular(AgamRadius.control),
      ),
      child: Row(
        children: [
          const AgamIconTile(
            icon: Icons.meeting_room_rounded,
            size: 36,
            background: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint,
                  style: AgamText.label.copyWith(color: AgamColors.ink),
                ),
                if (enterBuilding) ...[
                  const SizedBox(height: 2),
                  const Text(ArrivalCard.indoorNote, style: AgamText.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompletionNote extends StatelessWidget {
  const _CompletionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
    decoration: BoxDecoration(
      color: AgamColors.successTint,
      borderRadius: BorderRadius.circular(AgamRadius.control),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(
            Icons.workspace_premium_rounded,
            size: 20,
            color: AgamColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: AgamText.bodySmall.copyWith(color: AgamColors.ink),
            ),
          ),
        ),
      ],
    ),
  );
}

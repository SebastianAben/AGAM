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
class ArrivalCard extends StatefulWidget {
  const ArrivalCard({
    super.key,
    required this.name,
    required this.kind,
    required this.voice,
    required this.onFinish,
    this.onOpenDetail,
    this.map,
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

  @override
  Widget build(BuildContext context) {
    final openDetail = widget.onOpenDetail;
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

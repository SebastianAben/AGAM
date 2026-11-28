import 'package:flutter/material.dart';

import 'agam_motion.dart';
import 'agam_theme.dart';

/// The trip status while walking (UI06), read at a glance like a car
/// navigation card: how long is left, how far and when you arrive, where you
/// are going, and a clear way out.
///
/// ```
/// 2 menit                       [ Akhiri ]
/// 126 m · Tiba 09.24
/// ─────────────────────────────────────────
/// ⦿ Labtek X & XI
/// ▭ Di dalam Labtek V
/// ```
///
/// The time left is the hero, as the thing a walker checks most often. The
/// destination sits below a hairline so the walker always knows where the
/// route ends (Google Maps leaves it out; on a campus it matters). "Akhiri"
/// is a solid red pill: it stops the route, so it says so in words and in
/// colour, and its target stays 48 dp tall.
class TripStatusCard extends StatelessWidget {
  const TripStatusCard({
    super.key,
    required this.destination,
    required this.remainingDistanceM,
    required this.remainingEta,
    required this.onEnd,
    this.isApproximate = false,
    this.locationHint,
    this.clock,
  });

  /// The label and tooltip of the end action.
  static const endLabel = 'Akhiri';
  static const endTooltip = 'Akhiri rute';

  /// Shown instead of a time until the route has one; never a made-up number.
  static const calculatingLabel = 'Menghitung…';

  /// Shown instead of distance and arrival until there is a position.
  static const waitingLabel = 'Menunggu lokasi';

  final String destination;
  final double? remainingDistanceM;
  final Duration? remainingEta;
  final VoidCallback? onEnd;

  /// Kept for API compatibility. The walking card does not repeat the
  /// "Tujuan perkiraan" note: the route preview already says it before the
  /// walk starts, and the walking card stays short enough to read in motion.
  final bool isApproximate;

  /// Where a facility is inside its building ("Di dalam Labtek V"); the
  /// route itself ends at the building door.
  final String? locationHint;

  /// The time source for the arrival clock; [DateTime.now] when null.
  final DateTime Function()? clock;

  /// "126 m" below a kilometre, "1,2 km" from there, with a decimal comma.
  static String formatDistance(double distanceM) => distanceM < 1000
      ? '${distanceM.round()} m'
      : '${(distanceM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// The 24-hour clock with a dot, as written in Indonesian: "09.24".
  static String formatClock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}.'
      '${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hint = locationHint?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_eta(), const SizedBox(height: 2), _metrics()],
                  ),
                ),
                const SizedBox(width: 12),
                _EndPill(onPressed: onEnd),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 12, right: 6),
              child: Divider(height: 1, thickness: 1, color: AgamColors.line),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _destination(hint),
            ),
          ],
        ),
      ),
    );
  }

  static const _figures = [
    FontFeature.tabularFigures(),
    FontFeature.disable('liga'),
  ];

  /// The hero line: "2 menit", "< 1 menit", or a quiet "Menghitung…".
  Widget _eta() {
    final eta = remainingEta;
    if (eta == null) {
      return Text(
        calculatingLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AgamText.headline.copyWith(
          color: AgamColors.muted,
          fontWeight: FontWeight.w600,
          height: 1.4,
          fontFeatures: _figures,
        ),
      );
    }
    final underMinute = eta.inSeconds < 60;
    final minutes = (eta.inSeconds / 60).round().clamp(1, 999);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: underMinute ? '< 1' : '$minutes'),
          const TextSpan(
            text: ' menit',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      semanticsLabel: underMinute
          ? 'Kurang dari 1 menit lagi'
          : 'Perkiraan $minutes menit lagi',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AgamText.display.copyWith(
        fontSize: 24,
        color: AgamColors.brand,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.15,
        fontFeatures: _figures,
      ),
    );
  }

  /// The secondary line: "126 m · Tiba 09.24". It wraps rather than cuts so
  /// the arrival time is never hidden behind an ellipsis.
  Widget _metrics() {
    final distance = remainingDistanceM;
    final eta = remainingEta;
    final parts = [
      if (distance != null) formatDistance(distance),
      if (eta != null)
        'Tiba ${formatClock((clock ?? DateTime.now)().add(eta))}',
    ];
    return Text(
      parts.isEmpty ? waitingLabel : parts.join(' · '),
      style: AgamText.body.copyWith(
        color: AgamColors.muted,
        fontWeight: FontWeight.w500,
        height: 1.3,
        fontFeatures: _figures,
      ),
    );
  }

  /// Where the route ends, with the indoor hint for a facility.
  Widget _destination(String? hint) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.place_rounded, size: 20, color: AgamColors.brand),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: 'Tujuan',
              child: Text(
                destination,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AgamText.headline.copyWith(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      if (hint != null && hint.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 2, right: 2, top: 1),
              child: Icon(
                Icons.meeting_room_rounded,
                size: 16,
                color: AgamColors.muted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AgamText.bodySmall.copyWith(
                  color: AgamColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}

/// The solid red "Akhiri" pill, in the spirit of a car navigation "Exit":
/// drawn 44 dp tall, padded to a 48 dp target, with the shared press scale.
/// Screen readers hear "Akhiri rute" once; the tooltip says the same on a
/// long press without being read twice.
class _EndPill extends StatelessWidget {
  const _EndPill({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: TripStatusCard.endTooltip,
    excludeFromSemantics: true,
    child: AgamPressFeedback(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AgamColors.danger,
          disabledForegroundColor: AgamColors.subtle,
          disabledBackgroundColor: AgamColors.fill,
          minimumSize: const Size(0, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'PlusJakartaSans',
            letterSpacing: -0.1,
            fontFeatures: [FontFeature.disable('liga')],
          ),
        ),
        child: const Text(
          TripStatusCard.endLabel,
          semanticsLabel: TripStatusCard.endTooltip,
        ),
      ),
    ),
  );
}

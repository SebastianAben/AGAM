import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'agam_components.dart';
import 'agam_theme.dart';

/// The trip status while walking (UI06): where to, what is left, and a
/// quiet way out.
///
/// One row: the destination and the remaining distance and time on the
/// left, "Akhiri rute" as a compact text pill on the right. The pill has no
/// icon on purpose: an X reads as "close this card" rather than "stop the
/// route", and the label already says what happens. Its target stays 48 dp
/// tall so it is easy to hit while walking ([AgamTextPill]).
class TripStatusCard extends StatelessWidget {
  const TripStatusCard({
    super.key,
    required this.destination,
    required this.remainingDistanceM,
    required this.remainingEta,
    required this.onEnd,
    this.isApproximate = false,
  });

  final String destination;
  final double? remainingDistanceM;
  final Duration? remainingEta;
  final VoidCallback? onEnd;

  /// The destination is a placeholder point, so the card says so.
  final bool isApproximate;

  @override
  Widget build(BuildContext context) {
    final distance = remainingDistanceM;
    final eta = remainingEta;
    final minutes = eta == null
        ? null
        : math.max(1, (eta.inSeconds / 60).ceil());
    const quiet = TextStyle(
      color: AgamColors.muted,
      fontWeight: FontWeight.w500,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AgamRadius.card),
        boxShadow: AgamShadows.floating,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AgamText.title,
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Sisa ', style: quiet),
                        TextSpan(
                          text: distance == null
                              ? '—'
                              : '${distance.round()} m',
                        ),
                        const TextSpan(text: ' · ', style: quiet),
                        TextSpan(
                          text: minutes == null ? '—' : '~$minutes menit',
                          style: quiet,
                        ),
                      ],
                    ),
                    style: AgamText.label.copyWith(
                      color: AgamColors.brand,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isApproximate) ...[
                    const SizedBox(height: 2),
                    const Text('Tujuan perkiraan', style: AgamText.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            AgamTextPill(
              label: 'Akhiri rute',
              onPressed: onEnd,
              foreground: AgamColors.danger,
              background: AgamColors.dangerTint,
            ),
          ],
        ),
      ),
    );
  }
}

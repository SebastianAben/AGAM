import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// Splash pembuka yang tampil sebelum alur login/onboarding.
///
/// It continues the Android launch screen (same navy, logo centred) instead
/// of replacing it: the wordmark rises once under the logo, then the next
/// screen fades in. Nothing loops, and the hand-off stays under 1.2 s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _hold = Duration(milliseconds: 1100);

  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (mounted) setState(() => _finished = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_intro.isDismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AgamMotion.duration(context, 320),
    switchInCurve: AgamMotion.easeOut,
    switchOutCurve: AgamMotion.easeOut,
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: _finished
        ? KeyedSubtree(key: const ValueKey('app'), child: widget.child)
        : _Splash(key: const ValueKey('splash'), intro: _intro),
  );
}

class _Splash extends StatelessWidget {
  const _Splash({super.key, required this.intro});

  final Animation<double> intro;

  double _span(double begin, double end) => AgamMotion.easeOut.transform(
    ((intro.value - begin) / (end - begin)).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    // Same colour as the Android launch background, so the hand-off from
    // the native splash has no flash.
    backgroundColor: AgamColors.brandDeep,
    body: AnimatedBuilder(
      animation: intro,
      builder: (context, _) {
        final glow = _span(0, .7);
        final word = _span(.3, .8);
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -140,
              right: -120,
              child: Opacity(
                opacity: glow,
                child: const _Glow(diameter: 360, alpha: .1),
              ),
            ),
            Positioned(
              bottom: -160,
              left: -120,
              child: Opacity(
                opacity: glow,
                child: const _Glow(
                  diameter: 320,
                  alpha: .18,
                  color: AgamColors.cyan,
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: 1 - .04 * word,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/media/logo.png',
                      width: 112,
                      height: 112,
                      cacheWidth: 336,
                      semanticLabel: 'AGAM',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: word,
                  child: Transform.translate(
                    offset: Offset(0, (1 - word) * 10),
                    child: const ExcludeSemantics(
                      child: Text(
                        'AGAM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.diameter,
    required this.alpha,
    this.color = Colors.white,
  });

  final double diameter;
  final double alpha;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

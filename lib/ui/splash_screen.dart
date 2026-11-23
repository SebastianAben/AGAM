import 'dart:async';

import 'package:flutter/material.dart';

import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// Splash pembuka yang tampil sebelum alur login/onboarding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  bool _finished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: AgamMotion.easeOut,
    );
    _logoScale = Tween<double>(
      begin: .92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: AgamMotion.easeOut));
    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 1200), _finish);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (!mounted || _finished) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _finished = true);
      return;
    }
    setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;

    return Scaffold(
      backgroundColor: AgamColors.brandDeep,
      body: AgamGround(
        radius: 0,
        padding: EdgeInsets.zero,
        colors: const [AgamColors.brandDeep, AgamColors.teal],
        child: Center(
          child: FadeTransition(
            opacity: _logoOpacity,
            child: ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: 142,
                height: 142,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: AgamShadows.glow(AgamColors.cyan),
                ),
                child: Image.asset('assets/media/logo.png'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

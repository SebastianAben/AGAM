import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/models/location.dart';
import '../contracts/services/la_services.dart';
import 'widgets/agam_motion.dart';

const _blue = Color(0xFF124DA5);
const _ink = Color(0xFF17213A);
const _muted = Color(0xFF5B6070);
const _cyan = Color(0xFF3FD0EE);
const _mint = Color(0xFF64F3BF);
const _success = Color(0xFF0E7C66);
const _warning = Color(0xFFB4541A);
const _surface = Color(0xFFF4F7FB);

const _logo = 'assets/media/logo.png';
const _labtekV = 'assets/media/P01/foto-1.jpg';
const _labtekVI = 'assets/media/P02/foto-2.jpg';
const _gkubCourt = 'assets/media/P06/foto-2.jpg';
const _gkubFront = 'assets/media/P06/foto-1.jpg';
const _photoWidth = 720;

/// Page grounds, drawn from the navy and cyan of the AGAM logo.
const _grounds = [
  Color(0xFF0D3F8F),
  Color(0xFF0A6A7E),
  Color(0xFF0D564D),
  Color(0xFF124DA5),
];

const _copy = [
  ('Selamat Datang di AGAM', 'Pemandu Kampus ITB Ganesha.'),
  (
    'Cerita gedung datang sendiri',
    'Ponsel bergetar saat Anda mendekati gedung. Ketuk Dengarkan untuk '
        'memutar ceritanya.',
  ),
  (
    'Lokasi Anda tetap di ponsel',
    'Posisi diproses di perangkat, tidak dikirim ke server, dan tidak '
        'disimpan.',
  ),
  (
    'Izinkan akses untuk mulai',
    'Lokasi hanya dibaca saat aplikasi tampil atau selama sesi yang Anda '
        'mulai.',
  ),
];

double _span(
  double value,
  double begin,
  double end, [
  Curve curve = AgamMotion.easeOut,
]) => curve.transform(((value - begin) / (end - begin)).clamp(0.0, 1.0));

enum _Step { location, notification }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.permissions,
    this.onAccessGranted,
  });

  final PermissionService permissions;
  final VoidCallback? onAccessGranted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _last = 3;

  final _pages = PageController();
  // One-shot reveal per page; nothing repeats, so the screen always settles.
  late final _reveals = [
    for (final ms in const [900, 3600, 1200, 800])
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: ms),
      ),
  ];
  int _page = 0;
  int? _skipTarget;
  bool _requesting = false;
  bool _precached = false;
  bool _buzzed = false;
  _Step? _busy;
  LocationPermissionStatus? _location;
  NotificationPermissionStatus? _notification;
  bool _notificationAsked = false;
  bool _batteryOptimized = false;
  bool _batteryShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reveals[1].addListener(_buzzOnPrompt);
    _refreshStatuses();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final path in const [_labtekV, _labtekVI, _gkubCourt, _gkubFront]) {
      precacheImage(ResizeImage(AssetImage(path), width: _photoWidth), context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    for (final reveal in _reveals) {
      reveal.dispose();
    }
    super.dispose();
  }

  // Returning from system settings may have changed any of the three rows.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    final permissions = widget.permissions;
    final location = await permissions.locationStatus();
    final notification = await permissions.notificationStatus();
    final battery = await permissions.isBatteryOptimized();
    if (!mounted) return;
    setState(() {
      _location = location;
      _notification = notification;
      _batteryOptimized = battery;
      _batteryShown |= battery;
    });
  }

  void _reveal(int index) {
    final reveal = _reveals[index];
    if (MediaQuery.disableAnimationsOf(context)) {
      reveal.value = 1;
    } else if (reveal.isDismissed) {
      reveal.forward();
    }
  }

  void _buzzOnPrompt() {
    if (_buzzed || _page != 1 || _reveals[1].value < .22) return;
    _buzzed = true;
    HapticFeedback.lightImpact();
  }

  void _onPageChanged(int index) {
    setState(() => _page = index);
    // Pages passed over by "Lewati" keep their reveal for a later visit.
    if (_skipTarget == null || _skipTarget == index) {
      _skipTarget = null;
      _reveal(index);
    }
  }

  void _goTo(int index) {
    final duration = AgamMotion.duration(context, 460);
    if (duration == Duration.zero) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: duration, curve: AgamMotion.drawer);
    }
  }

  void _skip() {
    _skipTarget = _last;
    _goTo(_last);
  }

  void _next() => _page < _last ? _goTo(_page + 1) : _requestAccess();

  Future<void> _requestAccess() async {
    if (_requesting) return;
    setState(() {
      _requesting = true;
      _busy = _Step.location;
    });

    try {
      final location = await widget.permissions.requestLocation();
      if (!mounted) return;
      setState(() {
        _location = location;
        _busy = null;
        // The dialog is modal; no spinner should keep running behind it.
        if (location != LocationPermissionStatus.granted) _requesting = false;
      });

      if (location != LocationPermissionStatus.granted) {
        await _showLocationResult(location);
        return;
      }

      setState(() => _busy = _Step.notification);
      final notification = await widget.permissions.requestNotification();
      if (!mounted) return;
      setState(() {
        _notification = notification;
        _notificationAsked = true;
        _busy = null;
        if (notification != NotificationPermissionStatus.granted) {
          _requesting = false;
        }
      });

      // Notification permission is optional for entering the app. The UI
      // informs the user that trigger notifications may be unavailable.
      if (notification != NotificationPermissionStatus.granted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, color: _blue),
            title: const Text('Akses lokasi diizinkan'),
            content: const Text(
              'Lokasi diizinkan. Notifikasi belum diaktifkan, jadi '
              'pemberitahuan POI mungkin tidak muncul.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      }
      if (mounted) widget.onAccessGranted?.call();
    } finally {
      if (mounted) {
        setState(() {
          _requesting = false;
          _busy = null;
        });
      }
    }
  }

  Future<void> _showLocationResult(LocationPermissionStatus status) async {
    final (title, message, showSettings) = switch (status) {
      LocationPermissionStatus.approximateOnly => (
        'Lokasi akurat diperlukan',
        'Aktifkan Lokasi akurat agar posisi dan pemicu POI dapat bekerja.',
        false,
      ),
      LocationPermissionStatus.permanentlyDenied => (
        'Izin lokasi ditolak',
        'Izinkan lokasi saat aplikasi digunakan melalui Pengaturan perangkat.',
        true,
      ),
      LocationPermissionStatus.serviceDisabled => (
        'Layanan lokasi mati',
        'Aktifkan layanan lokasi perangkat, lalu coba lagi.',
        false,
      ),
      _ => (
        'Izin lokasi diperlukan',
        'Izinkan akses lokasi saat aplikasi digunakan untuk melihat posisi Anda di peta.',
        false,
      ),
    };

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined, color: _blue),
        title: Text(title),
        content: Text(message),
        actions: [
          if (showSettings)
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.permissions.openAppSettings();
              },
              child: const Text('Buka Pengaturan'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _openBatterySettings() async {
    await widget.permissions.openBatteryOptimizationSettings();
    final optimized = await widget.permissions.isBatteryOptimized();
    if (mounted) setState(() => _batteryOptimized = optimized);
  }

  // Never taller than the window, so very short windows (split screen, a
  // browser being resized) do not produce negative layout sizes.
  double _sheetHeight(int index, Size size, EdgeInsets padding) {
    final height = index != _last
        ? (size.height * .38).clamp(280.0, 330.0)
        : math.min(
            math.max(size.height * .62, 480.0),
            size.height - padding.top - 150,
          );
    return height.clamp(0.0, math.max(0.0, size.height));
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: _page == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goTo(_page - 1);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return AnimatedBuilder(
                animation: _pages,
                builder: (context, _) {
                  final page =
                      _pages.hasClients && _pages.position.haveDimensions
                      ? _pages.page!
                      : _page.toDouble();
                  return _buildFrame(page, size, padding, reduce);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFrame(double page, Size size, EdgeInsets padding, bool reduce) {
    final from = page.floor().clamp(0, _last);
    final to = (from + 1).clamp(0, _last);
    final ground = Color.lerp(_grounds[from], _grounds[to], page - from)!;
    final toLast = Curves.easeInOut.transform(
      (page - (_last - 1)).clamp(0.0, 1.0),
    );
    final sheetHeight = lerpDouble(
      _sheetHeight(0, size, padding),
      _sheetHeight(_last, size, padding),
      toLast,
    )!;
    final drift = reduce ? 0.0 : page;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: ground)),
        Positioned(
          top: -size.width * .45,
          right: -size.width * .35 - drift * 18,
          child: _Glow(
            diameter: size.width * 1.1,
            color: Colors.white.withValues(alpha: .08),
          ),
        ),
        Positioned(
          top: size.height * .2,
          left: -size.width * .45 + drift * 12,
          child: _Glow(
            diameter: size.width * .85,
            color: _cyan.withValues(alpha: .14),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: sheetHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
          ),
        ),
        PageView.builder(
          controller: _pages,
          itemCount: _copy.length,
          physics: _requesting ? const NeverScrollableScrollPhysics() : null,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) =>
              _buildPage(index, page, size, padding, reduce),
        ),
        // Scrolled text fades out before it reaches the controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: padding.bottom + 112,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, .3],
                  colors: [Color(0x00FFFFFF), Colors.white],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: padding.bottom + 20,
          height: 56,
          child: _buildControls(page, toLast, size),
        ),
      ],
    );
  }

  Widget _buildPage(
    int index,
    double page,
    Size size,
    EdgeInsets padding,
    bool reduce,
  ) {
    final delta = reduce ? 0.0 : index - page;
    final distance = (index - page).abs().clamp(0.0, 1.0);
    final reveal = reduce ? kAlwaysCompleteAnimation : _reveals[index];
    final visualHeight = size.height - _sheetHeight(index, size, padding);
    // _sheetHeight is capped at size.height, so this is never negative.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: visualHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, padding.top + 20, 24, 32),
            // The visual trails the page so it reads as a deeper layer.
            child: Opacity(
              opacity: 1 - distance * .5,
              child: Transform.translate(
                offset: Offset(-delta * size.width * .28, 0),
                child: Transform.scale(
                  scale: 1 - delta.abs().clamp(0.0, 1.0) * .06,
                  child: ExcludeSemantics(
                    child: switch (index) {
                      0 => _WelcomeVisual(animation: reveal),
                      1 => _StoryVisual(animation: reveal),
                      2 => _PrivacyVisual(animation: reveal),
                      _ => _AccessVisual(animation: reveal),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Opacity(
            opacity: (1 - distance * 1.6).clamp(0.0, 1.0),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(28, 32, 28, padding.bottom + 104),
              child: _buildText(index, delta, reveal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildText(int index, double delta, Animation<double> reveal) {
    final (title, body) = _copy[index];
    final intro = index == 0 ? reveal : kAlwaysCompleteAnimation;

    return AnimatedBuilder(
      animation: intro,
      builder: (context, _) {
        final titleIn = _span(intro.value, .3, .75);
        final bodyIn = _span(intro.value, .4, .85);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Opacity(
              opacity: titleIn,
              child: Transform.translate(
                offset: Offset(delta * 40, (1 - titleIn) * 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Opacity(
              opacity: bodyIn,
              child: Transform.translate(
                offset: Offset(delta * 80, (1 - bodyIn) * 12),
                child: Text(
                  body,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            if (index == _last) ...[
              const SizedBox(height: 20),
              _buildAccessRows(reveal, delta),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAccessRows(Animation<double> reveal, double delta) {
    final rows = [
      _AccessRow(
        icon: Icons.my_location_rounded,
        title: 'Lokasi akurat',
        subtitle: 'Hanya saat aplikasi digunakan',
        trailing: _locationTrailing(),
      ),
      _AccessRow(
        icon: Icons.notifications_active_rounded,
        title: 'Notifikasi',
        trailing: _notificationTrailing(),
      ),
      if (_batteryShown)
        _AccessRow(
          icon: Icons.battery_charging_full_rounded,
          title: 'Optimasi baterai',
          subtitle:
              'Pilih Tanpa batasan agar sesi tetap berjalan saat '
              'layar mati',
          trailing: _batteryOptimized
              ? TextButton(
                  onPressed: _openBatterySettings,
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    minimumSize: const Size(48, 40),
                  ),
                  // Styling the Text keeps the theme font; a button
                  // textStyle would replace the whole style.
                  child: const Text(
                    'Atur',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                )
              : const _Check(key: ValueKey('battery-ok')),
        ),
    ];

    return AnimatedBuilder(
      animation: reveal,
      builder: (context, _) => Column(
        children: [
          for (var k = 0; k < rows.length; k++)
            Builder(
              builder: (context) {
                final rowIn = _span(reveal.value, k * .14, .5 + k * .14);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Opacity(
                    opacity: rowIn,
                    child: Transform.translate(
                      offset: Offset(delta * (100 + k * 20), (1 - rowIn) * 10),
                      child: rows[k],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _locationTrailing() {
    if (_busy == _Step.location) return const _Spinner();
    return switch (_location) {
      LocationPermissionStatus.granted => const _Check(
        key: ValueKey('location-ok'),
      ),
      LocationPermissionStatus.approximateOnly => const _Pill(
        'Belum akurat',
        tone: _warning,
      ),
      LocationPermissionStatus.permanentlyDenied => const _Pill(
        'Ditolak',
        tone: _warning,
      ),
      LocationPermissionStatus.serviceDisabled => const _Pill(
        'GPS mati',
        tone: _warning,
      ),
      _ => const _Pill('Wajib', tone: _blue),
    };
  }

  Widget _notificationTrailing() {
    if (_busy == _Step.notification) return const _Spinner();
    if (_notification == NotificationPermissionStatus.granted) {
      return const _Check(key: ValueKey('notification-ok'));
    }
    return _notificationAsked
        ? const _Pill('Nonaktif', tone: _muted)
        : const _Pill('Opsional', tone: _muted);
  }

  Widget _buildControls(double page, double toLast, Size size) {
    final chromeOpacity = 1 - (toLast * 2).clamp(0.0, 1.0);
    final ctaWidth = lerpDouble(56, size.width - 48, toLast)!;

    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IgnorePointer(
            ignoring: toLast > .3,
            child: Opacity(
              opacity: chromeOpacity,
              child: TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: _requesting ? null : _skip,
                style: TextButton.styleFrom(
                  foregroundColor: _muted,
                  minimumSize: const Size(64, 48),
                ),
                child: const Text(
                  'Lewati',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        Opacity(
          opacity: chromeOpacity,
          child: Semantics(
            label: 'Halaman ${_page + 1} dari ${_copy.length}',
            child: ExcludeSemantics(child: _Dots(page: page)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: ctaWidth,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _blue.withValues(alpha: .3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AgamPressFeedback(
                child: Material(
                  color: _blue,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _requesting ? null : _next,
                    child: _buildCtaContent(toLast, size),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCtaContent(double toLast, Size size) {
    final arrowOpacity = 1 - _span(toLast, 0, .4, Curves.linear);
    final labelOpacity = _span(toLast, .55, 1, Curves.linear);

    return Stack(
      alignment: Alignment.center,
      children: [
        if (arrowOpacity > 0)
          Opacity(
            opacity: arrowOpacity,
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              semanticLabel: 'Lanjut',
            ),
          ),
        if (toLast > 0)
          Opacity(
            opacity: labelOpacity,
            // The label is laid out at full width while the pill grows.
            child: OverflowBox(
              maxWidth: size.width - 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requesting)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.near_me_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    _requesting
                        ? 'Meminta izin...'
                        : 'Izinkan Lokasi & Mulai Jelajah',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.page});

  final double page;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var k = 0; k < _copy.length; k++)
        Builder(
          builder: (context) {
            final active = (1 - (page - k).abs()).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8 + 18 * active,
              height: 8,
              decoration: BoxDecoration(
                color: Color.lerp(const Color(0xFFD5DCE8), _blue, active),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          },
        ),
    ],
  );
}

class _Photo extends StatelessWidget {
  const _Photo(
    this.path, {
    required this.width,
    required this.height,
    this.zoom = 1,
    this.shade = 0,
  });

  final String path;
  final double width;
  final double height;
  final double zoom;
  final double shade;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4D000814),
          blurRadius: 30,
          offset: Offset(0, 16),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: zoom,
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              cacheWidth: _photoWidth,
            ),
          ),
          if (shade > 0)
            ColoredBox(color: const Color(0xFF061A3D).withValues(alpha: shade)),
        ],
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * .27),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40000814),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .23),
      child: Image.asset(_logo, cacheWidth: 256),
    ),
  );
}

/// Labtek V in front; Labtek VI and the GKU Barat courtyard fan out behind.
class _WelcomeVisual extends StatelessWidget {
  const _WelcomeVisual({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final frontHeight = math.min(constraints.maxHeight * .9, 300.0);
      final frontWidth = frontHeight * .74;
      final backHeight = frontHeight * .8;
      final backWidth = backHeight * .74;
      final spread = math.min(
        frontWidth / 2 - backWidth * .02,
        constraints.maxWidth / 2 - backWidth / 2,
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          final frontIn = _span(value, 0, .6);
          final spreadIn = _span(value, .18, .78);
          final badgeIn = _span(value, .5, .92);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              for (final (side, path) in const [
                (-1.0, _labtekVI),
                (1.0, _gkubCourt),
              ])
                Transform.translate(
                  offset: Offset(side * spread * spreadIn, 16),
                  child: Opacity(
                    opacity: spreadIn,
                    child: Transform.scale(
                      scale: .9 + .1 * spreadIn,
                      child: _Photo(
                        path,
                        width: backWidth,
                        height: backHeight,
                        shade: .28,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: frontIn,
                child: Transform.scale(
                  scale: .94 + .06 * frontIn,
                  child: _Photo(
                    _labtekV,
                    width: frontWidth,
                    height: frontHeight,
                    zoom: 1.12 - .12 * frontIn,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(-frontWidth / 2 + 20, frontHeight / 2 - 20),
                child: Opacity(
                  opacity: badgeIn,
                  child: Transform.scale(
                    scale: .9 + .1 * badgeIn,
                    child: const _Logo(size: 68),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// A shortened replay of a real trigger: arrive, vibrate, prompt, listen.
class _StoryVisual extends StatelessWidget {
  const _StoryVisual({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // The prompt overlaps only the roofline, so the building sign stays
      // visible below it.
      const overlap = 92.0;
      final photoHeight = (constraints.maxHeight - overlap).clamp(0.0, 330.0);
      final photoWidth = math.min(photoHeight * .8, constraints.maxWidth * .8);
      final cardWidth = math.min(constraints.maxWidth, 320.0);
      final cardTop = (constraints.maxHeight - overlap - photoHeight) / 2;
      final photoTop = cardTop + overlap;

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          final arrive = _span(value, .16, .4);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: photoTop,
                left: (constraints.maxWidth - photoWidth) / 2,
                child: _Photo(
                  _gkubFront,
                  width: photoWidth,
                  height: photoHeight,
                ),
              ),
              Positioned(
                top: photoTop + photoHeight * .7 - 50,
                left: constraints.maxWidth / 2 - 50,
                child: _PulseDot(value: value),
              ),
              Positioned(
                top: cardTop - (1 - arrive) * 24,
                left: (constraints.maxWidth - cardWidth) / 2,
                width: cardWidth,
                child: Opacity(
                  opacity: arrive,
                  child: _PromptCard(value: value),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final core = _span(value, 0, .14);
    return SizedBox.square(
      dimension: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var k = 0; k < 2; k++)
            Builder(
              builder: (context) {
                final ring = _span(value, .04 + k * .12, .5 + k * .12);
                return Container(
                  width: 20 + 76 * ring,
                  height: 20 + 76 * ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: (1 - ring) * .9),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          Opacity(
            opacity: core,
            child: Transform.scale(
              scale: .9 + .1 * core,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _cyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000814), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final buzz = _span(value, .22, .4, Curves.linear);
    final press = math.sin(math.pi * _span(value, .5, .6, Curves.linear));
    final playing = _span(value, .62, .74);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000814),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(_logo, width: 22, cacheWidth: 96),
              ),
              const SizedBox(width: 8),
              const Text(
                'AGAM',
                style: TextStyle(
                  color: _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                ' · sekarang',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const Spacer(),
              Transform.rotate(
                angle: math.sin(buzz * math.pi * 8) * .2 * (1 - buzz),
                child: const Icon(
                  Icons.vibration_rounded,
                  size: 16,
                  color: _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Anda mendekati Gedung Kuliah Umum Barat.',
            style: TextStyle(
              color: _ink,
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Apakah Anda ingin mendengarkan ceritanya?',
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Lewati',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Transform.scale(
                  scale: 1 - .06 * press,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 1 - _span(value, .6, .68, Curves.linear),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.headphones_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Dengarkan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: playing,
                          child: Transform.scale(
                            scale: .94 + .06 * playing,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Bars(value: value, level: playing),
                                const SizedBox(width: 8),
                                const Text(
                                  'Memutar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.value, required this.level});

  final double value;
  final double level;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 16,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var k = 0; k < 4; k++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 3,
            height:
                4 + 12 * level * math.sin(value * math.pi * 14 + k * 1.3).abs(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

/// The phone keeps the position; the route to a server is drawn and stopped.
class _PrivacyVisual extends StatelessWidget {
  const _PrivacyVisual({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final phoneHeight = math.min(constraints.maxHeight * .86, 250.0);
      final phoneWidth = phoneHeight * .56;
      final gap = math.min(constraints.maxWidth - phoneWidth - 64, 120.0);

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          final pinIn = _span(value, 0, .4);
          final line = _span(value, .3, .7, Curves.easeInOut);
          final stop = _span(value, .62, .9);

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Phone(width: phoneWidth, height: phoneHeight, value: pinIn),
              SizedBox(
                width: gap,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ConnectorPainter(progress: line),
                      ),
                    ),
                    Opacity(
                      opacity: stop,
                      child: Transform.scale(
                        scale: .85 + .15 * stop,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            color: _mint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            size: 18,
                            color: Color(0xFF0D564D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: .4,
                child: Icon(
                  Icons.cloud_outlined,
                  size: 44,
                  color: Colors.white.withValues(alpha: .9),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _Phone extends StatelessWidget {
  const _Phone({
    required this.width,
    required this.height,
    required this.value,
  });

  final double width;
  final double height;
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(width * .2),
      border: Border.all(color: Colors.white.withValues(alpha: .4), width: 1.5),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 10,
          child: Container(
            width: width * .26,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        for (final (size, alpha) in const [(.82, .1), (.52, .16)])
          Transform.scale(
            scale: .9 + .1 * value,
            child: Container(
              width: width * size,
              height: width * size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: alpha * value),
              ),
            ),
          ),
        Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -(1 - value) * 14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: width * .36,
                  color: _mint,
                ),
                Positioned(
                  right: -6,
                  bottom: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: Color(0xFF0D564D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final faint = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final bright = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // The bright dashes stop at the middle, where the block badge sits.
    final reach = size.width / 2 * progress;
    for (var x = 4.0; x < size.width - 4; x += 10) {
      final end = math.min(x + 4, size.width - 4);
      canvas.drawLine(Offset(x, y), Offset(end, y), x < reach ? bright : faint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AccessVisual extends StatelessWidget {
  const _AccessVisual({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final outer = math.min(constraints.maxHeight, 260.0);

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final value = animation.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var k = 0; k < 3; k++)
                Builder(
                  builder: (context) {
                    final ringIn = _span(value, k * .12, .6 + k * .12);
                    return Opacity(
                      opacity: ringIn,
                      child: Transform.scale(
                        scale: .85 + .15 * ringIn,
                        child: Container(
                          width: outer * (1 - k * .26),
                          height: outer * (1 - k * .26),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: .1 + k * .05,
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              for (final (angle, radius, delay) in const [
                (-2.3, .5, .3),
                (.5, .37, .4),
                (2.6, .5, .5),
              ])
                Builder(
                  builder: (context) {
                    final pinIn = _span(value, delay, delay + .4);
                    return Transform.translate(
                      offset: Offset(
                        math.cos(angle) * outer * radius,
                        math.sin(angle) * outer * radius - (1 - pinIn) * 8,
                      ),
                      child: Opacity(
                        opacity: pinIn,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 20,
                          color: _cyan,
                        ),
                      ),
                    );
                  },
                ),
              Transform.scale(
                scale: .92 + .08 * _span(value, 0, .5),
                child: const _Logo(size: 84),
              ),
            ],
          );
        },
      );
    },
  );
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F0FB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: _blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: AgamMotion.duration(context, 200),
          switchInCurve: AgamMotion.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .9, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: trailing,
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey(label),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: tone, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: const BoxDecoration(color: _success, shape: BoxShape.circle),
    child: const Icon(
      Icons.check_rounded,
      size: 18,
      color: Colors.white,
      semanticLabel: 'Diizinkan',
    ),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    key: ValueKey('spinner'),
    dimension: 22,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: _blue),
  );
}

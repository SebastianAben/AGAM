import 'package:flutter/material.dart';

import '../contracts/models/location.dart';
import '../contracts/services/la_services.dart';

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

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _blue = Color(0xFF124DA5);
  bool _requesting = false;

  Future<void> _requestAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      final location = await widget.permissions.requestLocation();
      if (!mounted) return;

      if (location != LocationPermissionStatus.granted) {
        await _showLocationResult(location);
        return;
      }

      final notification = await widget.permissions.requestNotification();
      if (!mounted) return;

      // Notification permission is optional for entering the app. The UI
      // informs the user that trigger notifications may be unavailable.
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, color: _blue),
          title: const Text('Akses lokasi diizinkan'),
          content: Text(
            notification == NotificationPermissionStatus.granted
                ? 'AGAM siap membantu Anda menjelajahi Kampus ITB Ganesha.'
                : 'Lokasi diizinkan. Notifikasi belum diaktifkan, jadi pemberitahuan POI mungkin tidak muncul.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      if (mounted) widget.onAccessGranted?.call();
    } finally {
      if (mounted) setState(() => _requesting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final minHeight = availableHeight.isFinite && availableHeight > 32
                ? availableHeight - 32
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  children: [
                    const _WelcomeCard(),
                    const SizedBox(height: 14),
                    const _FeatureCard(
                      icon: Icons.navigation_rounded,
                      iconColor: Color(0xFF104DA7),
                      tileColor: Color(0xFFE2E7FF),
                      title: 'Panduan Otomatis Sekitar Kampus',
                      description: 'Mengenali gedung dan fasilitas penting saat Anda berjalan di kampus ITB.',
                    ),
                    const SizedBox(height: 8),
                    const _FeatureCard(
                      icon: Icons.headphones_rounded,
                      iconColor: Color(0xFF006B7A),
                      tileColor: Color(0xFFA9EEFC),
                      title: 'Audio & Penjelasan Singkat',
                      description: 'Dengarkan cerita sejarah dan info gedung tanpa perlu menatap layar ponsel.',
                    ),
                    const SizedBox(height: 8),
                    const _FeatureCard(
                      icon: Icons.lock_rounded,
                      iconColor: Color(0xFF003E34),
                      tileColor: Color(0xFF64F3BF),
                      title: 'Privasi Aman & Terjaga',
                      description: 'Lokasi Anda hanya diproses langsung di perangkat tanpa disimpan di server.',
                    ),
                    const SizedBox(height: 15),
                    const _LocationNotice(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _requesting ? null : _requestAccess,
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _requesting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.navigation_rounded, size: 19),
                        label: Text(
                          _requesting
                              ? 'Meminta izin...'
                              : 'Izinkan Lokasi & Mulai Jelajah',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 228,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F0FF), Color(0xFFD7F1FF)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              color: Color(0xFFDCEBFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: _OnboardingScreenState._blue,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const _AgamMark(),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 17,
            height: 4,
            decoration: BoxDecoration(
              color: Color(0xFFDDE5FF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selamat Datang di AGAM',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF20283B),
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pemandu Cerdas Kampus ITB Ganesha',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF73798A), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Simple in-app mark until the approved AGAM logo asset is supplied.
class _AgamMark extends StatelessWidget {
  const _AgamMark();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.shield_rounded, size: 57, color: Color(0xFF20D5EF)),
        Positioned(
          top: 24,
          child: Icon(Icons.explore_rounded, size: 37, color: Colors.white),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFF0EEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 25, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF17213A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF4F5360),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECFF),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.my_location_rounded,
                size: 18,
                color: _OnboardingScreenState._blue,
              ),
              SizedBox(width: 6),
              Text(
                'Akses Lokasi Diperlukan',
                style: TextStyle(
                  color: _OnboardingScreenState._blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Izin lokasi dipakai untuk menentukan posisi Anda secara langsung saat menjelajahi area kampus ITB Ganesha.',
            style: TextStyle(
              color: Color(0xFF4F5360),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

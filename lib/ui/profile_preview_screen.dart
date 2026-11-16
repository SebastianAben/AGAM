import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import '../logic/session/poi_trial_control.dart';

/// UI09 retains the FE account preview alongside available device settings.
class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({
    super.key,
    this.services,
    this.internalDemo = false,
  });

  final AppServices? services;
  final bool internalDemo;

  static const _ink = Color(0xFF172238);
  static const _muted = Color(0xFF596174);
  static const _pale = Color(0xFFF0F1FF);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAF8FF),
    body: SafeArea(
      bottom: false,
      child: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        children: [
          const Center(
            child: Text(
              'Profil Pengguna',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _identityCard(),
          const SizedBox(height: 15),
          _accountCard(),
          if (services != null) ...[
            const SizedBox(height: 15),
            if (services!.session case final PoiTrialControl trial
                when internalDemo && trial.trialModeAvailable)
              StreamBuilder<bool>(
                stream: trial.trialModeChanges,
                initialData: trial.trialModeEnabled,
                builder: (context, snapshot) => SwitchListTile(
                  title: const Text('Mode demo/trial'),
                  subtitle: const Text(
                    'Reset cooldown otomatis untuk developer. Keluar lalu masuk '
                    'POI kembali, tanpa menunggu 10 menit.',
                  ),
                  value: snapshot.data ?? false,
                  onChanged: trial.setTrialMode,
                ),
              ),
            ListTile(
              title: const Text('Notifikasi & izin aplikasi'),
              leading: const Icon(Icons.notifications_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: services!.permissions.openAppSettings,
            ),
            ListTile(
              title: const Text('Pengaturan baterai'),
              leading: const Icon(Icons.battery_saver_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: services!.permissions.openBatteryOptimizationSettings,
            ),
            StreamBuilder<AppSettings>(
              stream: services!.settings.settings,
              initialData: services!.settings.current,
              builder: (context, snapshot) => SwitchListTile(
                title: const Text('Putar narasi otomatis'),
                subtitle: const Text(
                  'Putar narasi saat tiba di POI pada sesi Explore.',
                ),
                value: snapshot.data!.autoPlayNarration,
                onChanged: (value) async {
                  try {
                    await services!.settings.update(
                      services!.settings.current.copyWith(
                        autoPlayNarration: value,
                      ),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pengaturan belum dapat disimpan.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            StreamBuilder<SessionState>(
              stream: services!.session.state,
              initialData: services!.session.current,
              builder: (context, snapshot) => ListTile(
                title: Text(
                  snapshot.data!.isActive
                      ? 'Sesi Explore aktif'
                      : 'Tidak ada sesi aktif',
                ),
                trailing: TextButton(
                  onPressed: snapshot.data!.isActive
                      ? () => services!.session.end()
                      : null,
                  child: const Text('Akhiri'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 19),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.logout_rounded, size: 19),
              label: const Text(
                'Keluar akun',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFFB50000),
                backgroundColor: const Color(0xFFFFDAD7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 1,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _identityCard() => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100A1B39),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      children: [
        Semantics(
          label: 'Foto profil',
          child: const CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFE8EBF3),
            child: Icon(
              Icons.person_rounded,
              color: Color(0xFF747D8E),
              size: 43,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pengguna',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'Email belum tersedia',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _accountCard() => Container(
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100A1B39),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detail Akun',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: _pale,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Column(
            children: [
              _AccountRow(label: 'Peran Akun', value: 'Belum tersedia'),
              SizedBox(height: 8),
              _AccountRow(
                label: 'Fakultas /\nSekolah',
                value: 'Belum tersedia',
              ),
              SizedBox(height: 8),
              _AccountRow(
                label: 'Akses Lokasi GPS',
                value: 'Lihat izin perangkat',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        flex: 5,
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF535A6D), fontSize: 11),
        ),
      ),
      Expanded(
        flex: 6,
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Color(0xFF182239),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}

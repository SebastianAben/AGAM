import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import '../logic/session/poi_trial_control.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// UI09, opened from the account button in the header: the account preview
/// and the device settings that already work, grouped by what they affect.
class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({
    super.key,
    this.services,
    this.internalDemo = false,
  });

  final AppServices? services;
  final bool internalDemo;

  @override
  Widget build(BuildContext context) {
    final services = this.services;
    final canPop = Navigator.canPop(context);
    final trial = switch (services?.session) {
      final PoiTrialControl control
          when internalDemo && control.trialModeAvailable =>
        control,
      _ => null,
    };
    var order = 0;
    Widget reveal(Widget child) => AgamReveal(order: order++, child: child);

    return Scaffold(
      backgroundColor: AgamColors.canvas,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // The identity shrinks away on scroll; the bar with the back
          // button and title stays pinned.
          SliverAppBar(
            pinned: true,
            expandedHeight: 290,
            backgroundColor: AgamColors.brandDeep,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: canPop
                ? const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: AgamBackButton(onDark: true),
                  )
                : null,
            title: const Text(
              'Profil Pengguna',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            flexibleSpace: const FlexibleSpaceBar(background: _Identity()),
          ),
          // A box adapter measures the real height; SliverFillRemaining would
          // size from intrinsics, which underestimate these rows.
          SliverToBoxAdapter(
            child: Container(
              color: AgamColors.canvas,
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  reveal(const AgamSectionHeader('Detail Akun')),
                  reveal(
                    const AgamGroup(
                      children: [
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Peran Akun',
                          value: 'Belum tersedia',
                        ),
                        _InfoRow(
                          icon: Icons.school_rounded,
                          label: 'Fakultas / Sekolah',
                          value: 'Belum tersedia',
                        ),
                        _InfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Akses Lokasi GPS',
                          value: 'Lihat izin perangkat',
                        ),
                      ],
                    ),
                  ),
                  if (services != null) ...[
                    const SizedBox(height: 28),
                    reveal(const AgamSectionHeader('Sesi')),
                    reveal(
                      AgamGroup(
                        children: [
                          StreamBuilder<SessionState>(
                            stream: services.session.state,
                            initialData: services.session.current,
                            builder: (context, snapshot) {
                              final active = snapshot.data!.isActive;
                              return AgamListRow(
                                icon: active
                                    ? Icons.sensors_rounded
                                    : Icons.sensors_off_rounded,
                                iconBackground: active
                                    ? AgamColors.successTint
                                    : AgamColors.fill,
                                iconForeground: active
                                    ? AgamColors.success
                                    : AgamColors.subtle,
                                title: active
                                    ? 'Sesi Explore aktif'
                                    : 'Tidak ada sesi aktif',
                                trailing: TextButton(
                                  onPressed: active
                                      ? () => services.session.end()
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AgamColors.danger,
                                    backgroundColor: active
                                        ? AgamColors.dangerTint
                                        : Colors.transparent,
                                    minimumSize: const Size(64, 40),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: const Text(
                                    'Akhiri',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    reveal(const AgamSectionHeader('Narasi')),
                    reveal(
                      AgamGroup(
                        children: [
                          StreamBuilder<AppSettings>(
                            stream: services.settings.settings,
                            initialData: services.settings.current,
                            builder: (context, snapshot) => _SwitchRow(
                              icon: Icons.headphones_rounded,
                              title: 'Putar narasi otomatis',
                              value: snapshot.data!.autoPlayNarration,
                              onChanged: (value) async {
                                try {
                                  await services.settings.update(
                                    services.settings.current.copyWith(
                                      autoPlayNarration: value,
                                    ),
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
                    const SizedBox(height: 28),
                    reveal(const AgamSectionHeader('Perangkat')),
                    reveal(
                      AgamGroup(
                        children: [
                          AgamListRow(
                            icon: Icons.notifications_rounded,
                            title: 'Notifikasi & izin aplikasi',
                            trailing: const _Chevron(),
                            onTap: services.permissions.openAppSettings,
                          ),
                          AgamListRow(
                            icon: Icons.battery_saver_rounded,
                            title: 'Pengaturan baterai',
                            trailing: const _Chevron(),
                            onTap: services
                                .permissions
                                .openBatteryOptimizationSettings,
                          ),
                        ],
                      ),
                    ),
                    if (trial != null) ...[
                      const SizedBox(height: 28),
                      reveal(const AgamSectionHeader('Developer')),
                      reveal(
                        AgamGroup(
                          children: [
                            StreamBuilder<bool>(
                              stream: trial.trialModeChanges,
                              initialData: trial.trialModeEnabled,
                              builder: (context, snapshot) => _SwitchRow(
                                icon: Icons.science_rounded,
                                iconBackground: AgamColors.warning.withValues(
                                  alpha: .12,
                                ),
                                iconForeground: AgamColors.warning,
                                title: 'Mode demo/trial',
                                subtitle: 'Lewati cooldown 10 menit POI',
                                value: snapshot.data ?? false,
                                onChanged: trial.setTrialMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                  reveal(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AgamTonalButton(
                          onPressed: null,
                          icon: Icons.logout_rounded,
                          height: 52,
                          foreground: AgamColors.danger,
                          background: AgamColors.dangerTint,
                          label: 'Keluar akun',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Fills a tall screen below short content with the sheet colour.
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ColoredBox(color: AgamColors.canvas),
          ),
        ],
      ),
    );
  }
}

/// The account identity on the onboarding ground, closed at the bottom by
/// the start of the canvas sheet.
class _Identity extends StatelessWidget {
  const _Identity();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AgamGround(
        radius: 0,
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight,
          bottom: 28,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Foto profil',
                child: Container(
                  width: 92,
                  height: 92,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AgamColors.cyan, AgamColors.mint],
                    ),
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: AgamColors.brand,
                      size: 46,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Pengguna',
                style: AgamText.title.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Email belum tersedia',
                style: AgamText.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: -1,
        height: 29,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AgamColors.canvas,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AgamRadius.sheet),
            ),
          ),
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AgamListRow(
    icon: icon,
    title: label,
    trailing: Text(
      value,
      textAlign: TextAlign.right,
      style: AgamText.caption.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// A settings row whose whole surface toggles the switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconBackground = AgamColors.tint,
    this.iconForeground = AgamColors.brand,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconBackground;
  final Color iconForeground;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    onChanged: onChanged,
    contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
    activeThumbColor: Colors.white,
    activeTrackColor: AgamColors.brand,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: AgamColors.line,
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    secondary: AgamIconTile(
      icon: icon,
      size: 42,
      background: iconBackground,
      foreground: iconForeground,
    ),
    title: Text(title, style: AgamText.label.copyWith(fontSize: 15)),
    subtitle: subtitle == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!, style: AgamText.caption),
          ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.chevron_right_rounded,
    size: 22,
    color: AgamColors.subtle,
  );
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// UI09, opened from the account button in the header: account identity,
/// session controls, audio preferences, device permissions, local progress
/// reset, logout, and account deletion.
class ProfilePreviewScreen extends StatefulWidget {
  const ProfilePreviewScreen({super.key, this.services});

  final AppServices? services;

  @override
  State<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends State<ProfilePreviewScreen>
    with WidgetsBindingObserver {
  LocationPermissionStatus? _locationStatus;
  AuthState _authState = const AuthState.signedOut();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchAuth();
    unawaited(_refreshPermissionStatus());
  }

  @override
  void didUpdateWidget(covariant ProfilePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services != widget.services) {
      _watchAuth();
      unawaited(_refreshPermissionStatus());
    }
  }

  void _watchAuth() {
    unawaited(_authSubscription?.cancel());
    final auth = widget.services?.auth;
    _authState = auth?.current ?? const AuthState.signedOut();
    _authSubscription = auth?.state.listen((state) {
      final changed =
          _authState.isSignedIn != state.isSignedIn ||
          _authState.account?.uid != state.account?.uid ||
          _authState.account?.email != state.account?.email ||
          _authState.account?.role != state.account?.role;
      if (changed && mounted) {
        setState(() => _authState = state);
      } else {
        _authState = state;
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshPermissionStatus());
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final permissions = widget.services?.permissions;
    if (permissions == null) return;
    final status = await permissions.locationStatus();
    if (mounted) setState(() => _locationStatus = status);
  }

  static String _locationLabel(LocationPermissionStatus? status) =>
      switch (status) {
        LocationPermissionStatus.granted => 'Aktif (Akurat)',
        LocationPermissionStatus.approximateOnly => 'Lokasi perkiraan',
        LocationPermissionStatus.serviceDisabled => 'Layanan lokasi mati',
        LocationPermissionStatus.permanentlyDenied => 'Ditolak permanen',
        LocationPermissionStatus.denied => 'Belum diizinkan',
        null => 'Lihat izin perangkat',
      };

  static String _sessionLabel(SessionState state) {
    if (!state.isActive) return 'Tidak ada sesi aktif';
    return switch (state.mode) {
      SessionMode.explore => 'Sesi Explore aktif',
      SessionMode.navigation => 'Sesi Navigasi aktif',
      SessionMode.trail => 'Sesi Orientation Trail aktif',
      SessionMode.none => 'Tidak ada sesi aktif',
    };
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final canPop = Navigator.canPop(context);
    final authState = _authState;
    final authAccount = authState.account;
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
            flexibleSpace: FlexibleSpaceBar(
              background: _Identity(account: authAccount),
            ),
          ),
          // A box adapter measures the real height; SliverFillRemaining
          // would size from intrinsics, which underestimate these rows.
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
                    AgamGroup(
                      children: [
                        _InfoRow(
                          icon: Icons.badge_rounded,
                          label: 'Peran Akun',
                          value: switch (authAccount?.role) {
                            UserRole.mahasiswaItb => 'Mahasiswa ITB',
                            UserRole.pengunjung => 'Pengunjung',
                            null => 'Belum tersedia',
                          },
                        ),
                        _InfoRow(
                          icon: Icons.my_location_rounded,
                          label: 'Akses Lokasi GPS',
                          value: _locationLabel(_locationStatus),
                          onTap: services?.permissions.openAppSettings,
                        ),
                        if (authAccount != null)
                          _InfoRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'Email',
                            value: authAccount.email,
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
                              final state = snapshot.data!;
                              final active = state.isActive;
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
                                title: _sessionLabel(state),
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
                          AgamListRow(
                            key: const ValueKey('reset-local-progress'),
                            icon: Icons.restart_alt_rounded,
                            title: 'Hapus progres lokal',
                            subtitle:
                                'Reset progres trail & daftar POI dikunjungi',
                            trailing: const _Chevron(),
                            onTap: () =>
                                _confirmResetProgress(context, services.trail),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  reveal(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AgamTonalButton(
                          onPressed: authState.isSignedIn
                              ? () => _confirmLogout(context, services!.auth)
                              : null,
                          icon: Icons.logout_rounded,
                          height: 52,
                          foreground: AgamColors.danger,
                          background: AgamColors.dangerTint,
                          label: 'Keluar akun',
                        ),
                        const SizedBox(height: 8),
                        // Quieter than logout on purpose: the destructive
                        // step lives in the dialog, behind the password.
                        TextButton.icon(
                          key: const ValueKey('delete-account'),
                          onPressed: authState.isSignedIn
                              ? () => _confirmDeleteAccount(
                                  context,
                                  services!.auth,
                                )
                              : null,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Hapus akun'),
                          style: TextButton.styleFrom(
                            foregroundColor: AgamColors.danger,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AgamRadius.control,
                              ),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

Future<void> _confirmResetProgress(
  BuildContext context,
  TrailService trail,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Hapus progres lokal?'),
      content: const Text(
        'Progres Orientation Trail dan daftar gedung yang dikunjungi untuk '
        'akun ini di perangkat akan direset. Akun Anda tidak dihapus.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AgamColors.danger),
          child: const Text('Hapus progres'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await trail.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progres lokal telah dihapus.')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progres lokal belum dapat dihapus.')),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Keluar akun?'),
      content: const Text(
        'Sesi aktif akan berakhir. Progres akun tetap tersimpan di perangkat.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AgamColors.danger),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await auth.logout();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  } on AuthException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Akun belum dapat keluar.')));
  }
}

/// Asks for the password and deletes the account (PRD §16). The dialog
/// deletes in place and stays open on failure; on success the profile closes
/// and the auth gate in `app.dart` is already showing UI10.
Future<void> _confirmDeleteAccount(
  BuildContext context,
  AuthService auth,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => _DeleteAccountDialog(auth: auth),
  );
  if (deleted != true || !context.mounted) return;
  Navigator.of(context).popUntil((route) => route.isFirst);
  messenger.showSnackBar(const SnackBar(content: Text('Akun telah dihapus.')));
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.auth});

  final AuthService auth;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password
      ..removeListener(_onPasswordChanged)
      ..dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    // Rebuilds the confirm button; a stale error clears once the user edits.
    setState(() => _error = null);
  }

  bool get _canSubmit => !_busy && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.deleteAccount(password: _password.text);
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(AuthErrorCode.unknown);
      });
    }
  }

  static String _message(AuthErrorCode code) => switch (code) {
    AuthErrorCode.wrongCredentials => 'Password salah. Periksa lalu coba lagi.',
    AuthErrorCode.network =>
      'Butuh koneksi internet untuk menghapus akun. Periksa koneksi lalu '
          'coba lagi.',
    AuthErrorCode.tooManyRequests =>
      'Terlalu banyak percobaan. Coba lagi nanti.',
    _ => 'Akun belum dapat dihapus. Coba lagi.',
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: AgamColors.danger,
        size: 28,
      ),
      title: const Text('Hapus akun?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akun dihapus permanen dan tidak dapat dipulihkan. '
            'Yang ikut dihapus:',
          ),
          const SizedBox(height: 10),
          const _DeletedItem('Profil akun (peran dan tanggal daftar)'),
          const _DeletedItem('Seluruh log aktivitas akun'),
          const _DeletedItem(
            'Progres trail, POI dikunjungi, dan pengaturan akun ini di '
            'perangkat ini',
          ),
          const _DeletedItem('Akun login (email dan password)'),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('delete-account-password'),
            controller: _password,
            enabled: !_busy,
            autofocus: true,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            cursorColor: AgamColors.brand,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Masukkan password untuk mengonfirmasi.',
              helperMaxLines: 2,
              // A live region, so screen readers read the error as it
              // appears.
              error: switch (_error) {
                final error? => Semantics(
                  liveRegion: true,
                  child: Text(
                    error,
                    style: AgamText.caption.copyWith(color: AgamColors.danger),
                  ),
                ),
                null => null,
              },
              filled: true,
              fillColor: AgamColors.fill,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: _busy
                    ? null
                    : () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AgamRadius.control),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const ValueKey('delete-account-confirm'),
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: AgamColors.danger),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy) ...[
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(_busy ? 'Menghapus…' : 'Hapus akun'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DeletedItem extends StatelessWidget {
  const _DeletedItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7, right: 10),
          child: SizedBox.square(
            dimension: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AgamColors.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Expanded(child: Text(text, style: AgamText.bodySmall)),
      ],
    ),
  );
}

/// The account identity on the onboarding ground, closed at the bottom by
/// the start of the canvas sheet.
class _Identity extends StatelessWidget {
  const _Identity({this.account});

  final UserAccount? account;

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
                account == null ? 'Pengguna' : 'Akun AGAM',
                style: AgamText.title.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                account?.email ?? 'Email belum tersedia',
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AgamListRow(
    icon: icon,
    title: label,
    onTap: onTap,
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
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

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
      background: AgamColors.tint,
      foreground: AgamColors.brand,
    ),
    title: Text(title, style: AgamText.label.copyWith(fontSize: 15)),
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

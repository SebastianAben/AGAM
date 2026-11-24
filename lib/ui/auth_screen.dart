import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/contracts.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// UI10, daftar dan masuk dengan Firebase Auth email/password.
///
/// One screen, two modes. The navy header continues the splash; the white
/// sheet holds the form. Problems are shown where they happen (under the
/// field, on the consent row, above the button) instead of in snackbars
/// that disappear before they are read.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  static const consentText =
      'Posisi diproses di perangkat dan tidak dikirim atau disimpan sebagai '
      'riwayat. Saya menyetujui pengelolaan akun dan log aktivitas yang '
      'disetujui.';

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Tone { error, info }

class _Notice {
  const _Notice(this.message, this.tone);

  final String message;
  final _Tone tone;
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  var _formKey = GlobalKey<FormState>();
  bool _register = false;
  bool _obscure = true;
  bool _acceptedPrivacy = false;
  bool _consentMissing = false;
  bool _busy = false;
  bool _submitting = false;
  UserRole _role = UserRole.mahasiswaItb;
  _Notice? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _setMode(bool register) {
    if (_busy || register == _register) return;
    setState(() {
      // A new key rebuilds the fields: stale errors go, typed text stays
      // in the controllers. Form.reset() would roll the text back instead.
      _formKey = GlobalKey<FormState>();
      _register = register;
      _acceptedPrivacy = false;
      _consentMissing = false;
      _notice = null;
    });
  }

  void _clearNotice() {
    if (_notice != null) setState(() => _notice = null);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _formKey.currentState?.validate() ?? false;
    final consentMissing = _register && !_acceptedPrivacy;
    setState(() {
      _consentMissing = consentMissing;
      _notice = null;
    });
    if (!valid || consentMissing) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = _submitting = true);
    try {
      if (_register) {
        await widget.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
        );
      } else {
        await widget.auth.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _notice = _Notice(_message(error.code), _Tone.error));
    } finally {
      if (mounted) setState(() => _busy = _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _notice = const _Notice(
          'Masukkan email terlebih dahulu.',
          _Tone.error,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await widget.auth.sendPasswordReset(email: email);
      if (!mounted) return;
      setState(
        () => _notice = const _Notice(
          'Jika email terdaftar, tautan reset password telah dikirim.',
          _Tone.info,
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _notice = _Notice(_message(error.code), _Tone.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resize = AgamMotion.duration(context, 280);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Expanded(
              child: ColoredBox(
                // Navy behind the sheet's rounded corners.
                color: AgamColors.brandDeep,
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _Header(register: _register)),
                    SliverToBoxAdapter(
                      child: _Sheet(
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AgamSegmented(
                                  labels: const ['Masuk', 'Daftar'],
                                  selected: _register ? 1 : 0,
                                  onChanged: (index) => _setMode(index == 1),
                                ),
                                const SizedBox(height: 22),
                                _Field(
                                  controller: _email,
                                  label: 'Email',
                                  icon: Icons.alternate_email_rounded,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  textInputAction: TextInputAction.next,
                                  onChanged: (_) => _clearNotice(),
                                  onSubmitted: (_) =>
                                      _passwordFocus.requestFocus(),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Email wajib diisi.';
                                    }
                                    if (!email.contains('@')) {
                                      return 'Format email tidak valid.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                _Field(
                                  controller: _password,
                                  focusNode: _passwordFocus,
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  enabled: !_busy,
                                  obscureText: _obscure,
                                  helperText: _register
                                      ? 'Minimal 6 karakter'
                                      : null,
                                  autofillHints: [
                                    _register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  textInputAction: TextInputAction.done,
                                  onChanged: (_) => _clearNotice(),
                                  onSubmitted: (_) => _submit(),
                                  suffix: IconButton(
                                    tooltip: _obscure
                                        ? 'Tampilkan password'
                                        : 'Sembunyikan password',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    color: AgamColors.subtle,
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').isEmpty) {
                                      return 'Password wajib diisi.';
                                    }
                                    if (_register && value!.length < 6) {
                                      return 'Password minimal 6 karakter.';
                                    }
                                    return null;
                                  },
                                ),
                                AnimatedSize(
                                  duration: resize,
                                  curve: AgamMotion.drawer,
                                  alignment: Alignment.topCenter,
                                  child: _register
                                      ? _RegisterExtras(
                                          role: _role,
                                          accepted: _acceptedPrivacy,
                                          missing: _consentMissing,
                                          enabled: !_busy,
                                          onRole: (role) =>
                                              setState(() => _role = role),
                                          onConsent: (value) => setState(() {
                                            _acceptedPrivacy = value;
                                            if (value) {
                                              _consentMissing = false;
                                            }
                                          }),
                                        )
                                      : Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : _resetPassword,
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    AgamColors.brand,
                                                textStyle: AgamText.label
                                                    .copyWith(fontSize: 13),
                                              ),
                                              child: const Text(
                                                'Lupa password?',
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                                AnimatedSize(
                                  duration: resize,
                                  curve: AgamMotion.easeOut,
                                  alignment: Alignment.topCenter,
                                  child: _notice == null
                                      ? const SizedBox(width: double.infinity)
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: _NoticeBanner(
                                            notice: _notice!,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // White filler so the sheet runs to the action bar on tall
                    // screens, without measuring the form's intrinsic height.
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: ColoredBox(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            // The action stays in the thumb zone and rides on top of the
            // keyboard, so it is never scrolled out of reach.
            _ActionBar(
              child: AgamPrimaryButton(
                label: _register ? 'Buat akun' : 'Masuk',
                busy: _submitting,
                onPressed: _busy ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(AuthErrorCode code) => switch (code) {
    AuthErrorCode.invalidEmail => 'Format email tidak valid.',
    AuthErrorCode.weakPassword => 'Password terlalu lemah.',
    AuthErrorCode.emailAlreadyInUse => 'Email sudah digunakan.',
    AuthErrorCode.wrongCredentials => 'Email atau password salah.',
    AuthErrorCode.network =>
      'Butuh koneksi internet untuk login atau daftar pertama kali.',
    AuthErrorCode.tooManyRequests =>
      'Terlalu banyak percobaan. Coba lagi nanti.',
    AuthErrorCode.unknown => 'Akun belum dapat diproses.',
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.register});

  final bool register;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AgamGround(
      radius: 0,
      colors: const [AgamColors.brandDeep, AgamColors.brandDeep],
      padding: EdgeInsets.fromLTRB(24, top + 28, 24, 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/media/logo.png',
                  width: 40,
                  height: 40,
                  cacheWidth: 120,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AGAM',
                style: AgamText.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 64),
          AnimatedSwitcher(
            duration: AgamMotion.duration(context, 220),
            switchInCurve: AgamMotion.easeOut,
            switchOutCurve: AgamMotion.easeOut,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .18),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              register ? 'Buat akun AGAM' : 'Selamat datang',
              key: ValueKey(register),
              style: AgamText.display.copyWith(
                color: Colors.white,
                fontSize: 30,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // With the keyboard up the safe-area inset is under the keyboard.
    final inset = media.viewInsets.bottom > 0 ? 0.0 : media.padding.bottom;
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + inset),
        child: child,
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AgamRadius.sheet),
      ),
    ),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: child,
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.validator,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.helperText,
    this.autofillHints,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? helperText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  static OutlineInputBorder _border([Color? color, double width = 1.5]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AgamRadius.control),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    keyboardType: keyboardType,
    obscureText: obscureText,
    autocorrect: false,
    enableSuggestions: !obscureText,
    autofillHints: autofillHints,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    style: AgamText.body.copyWith(color: AgamColors.ink),
    cursorColor: AgamColors.brand,
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      filled: true,
      fillColor: AgamColors.fill,
      prefixIcon: Icon(icon, size: 20),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? AgamColors.brand
            : AgamColors.subtle,
      ),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: AgamText.body.copyWith(color: AgamColors.subtle),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => AgamText.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.error)
              ? AgamColors.danger
              : states.contains(WidgetState.focused)
              ? AgamColors.brand
              : AgamColors.muted,
        ),
      ),
      helperStyle: AgamText.caption.copyWith(color: AgamColors.subtle),
      errorStyle: AgamText.caption.copyWith(color: AgamColors.danger),
      border: _border(),
      enabledBorder: _border(),
      disabledBorder: _border(),
      focusedBorder: _border(AgamColors.brand),
      errorBorder: _border(AgamColors.danger, 1),
      focusedErrorBorder: _border(AgamColors.danger),
    ),
  );
}

class _RegisterExtras extends StatelessWidget {
  const _RegisterExtras({
    required this.role,
    required this.accepted,
    required this.missing,
    required this.enabled,
    required this.onRole,
    required this.onConsent,
  });

  final UserRole role;
  final bool accepted;
  final bool missing;
  final bool enabled;
  final ValueChanged<UserRole> onRole;
  final ValueChanged<bool> onConsent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 22),
      Text('Daftar sebagai', style: AgamText.label),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _RoleCard(
              label: 'Mahasiswa ITB',
              icon: Icons.school_outlined,
              selected: role == UserRole.mahasiswaItb,
              onTap: enabled ? () => onRole(UserRole.mahasiswaItb) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RoleCard(
              label: 'Pengunjung',
              icon: Icons.hiking_rounded,
              selected: role == UserRole.pengunjung,
              onTap: enabled ? () => onRole(UserRole.pengunjung) : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _ConsentRow(
        accepted: accepted,
        missing: missing,
        onChanged: enabled ? onConsent : null,
      ),
    ],
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration = AgamMotion.duration(context, 200);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: AgamPressFeedback(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: duration,
            curve: AgamMotion.easeOut,
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              color: selected ? AgamColors.tint : Colors.white,
              borderRadius: BorderRadius.circular(AgamRadius.control),
              border: Border.all(
                color: selected ? AgamColors.brand : AgamColors.line,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected ? AgamColors.brand : AgamColors.muted,
                    ),
                    const Spacer(),
                    AnimatedContainer(
                      duration: duration,
                      curve: AgamMotion.easeOut,
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? AgamColors.brand : Colors.white,
                        border: Border.all(
                          color: selected ? AgamColors.brand : AgamColors.line,
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedOpacity(
                        duration: duration,
                        opacity: selected ? 1 : 0,
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AgamText.label.copyWith(
                    color: selected ? AgamColors.ink : AgamColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.accepted,
    required this.missing,
    required this.onChanged,
  });

  final bool accepted;
  final bool missing;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = AgamMotion.duration(context, 200);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!accepted),
            borderRadius: BorderRadius.circular(AgamRadius.control),
            child: AnimatedContainer(
              duration: duration,
              curve: AgamMotion.easeOut,
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 12),
              decoration: BoxDecoration(
                color: missing
                    ? AgamColors.danger.withValues(alpha: .06)
                    : AgamColors.canvas,
                borderRadius: BorderRadius.circular(AgamRadius.control),
                border: Border.all(
                  color: missing
                      ? AgamColors.danger.withValues(alpha: .5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: accepted,
                    onChanged: onChanged == null
                        ? null
                        : (value) => onChanged!(value ?? false),
                    activeColor: AgamColors.brand,
                    side: BorderSide(
                      color: missing ? AgamColors.danger : AgamColors.subtle,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        AuthScreen.consentText,
                        style: AgamText.bodySmall.copyWith(
                          color: AgamColors.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AgamMotion.duration(context, 220),
          curve: AgamMotion.easeOut,
          alignment: Alignment.topCenter,
          child: missing
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Setujui pemberitahuan privasi untuk melanjutkan.',
                    style: AgamText.caption.copyWith(color: AgamColors.danger),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    final error = notice.tone == _Tone.error;
    final tone = error ? AgamColors.danger : AgamColors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AgamRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.mark_email_read_outlined,
              size: 20,
              color: tone,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                notice.message,
                style: AgamText.bodySmall.copyWith(
                  color: AgamColors.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

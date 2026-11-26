import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/contracts.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_motion.dart';
import 'widgets/agam_theme.dart';

/// UI10, daftar dan masuk dengan Firebase Auth email/password.
///
/// Login and register are two separate pages. The navy header and the white
/// sheet stay put; only the title, the form and the action move, along the
/// same horizontal axis as every pushed page in the app. Going to register
/// moves forward, coming back moves backward. Problems are shown where they
/// happen instead of in snackbars.
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
  // The email follows the user between pages; passwords do not.
  final _email = TextEditingController();
  final _loginPassword = TextEditingController();
  final _registerPassword = TextEditingController();
  final _loginPasswordFocus = FocusNode();
  final _registerPasswordFocus = FocusNode();
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final _scroll = ScrollController();
  bool _register = false;
  bool _obscure = true;
  bool _acceptedPrivacy = false;
  bool _consentMissing = false;
  bool _busy = false;
  bool _submitting = false;
  // After the first submit, fields re-check as the user types, so an error
  // clears as soon as the input is fixed instead of lingering until the
  // next tap.
  bool _attempted = false;
  UserRole _role = UserRole.mahasiswaItb;
  _Notice? _notice;

  @override
  void dispose() {
    _email.dispose();
    _loginPassword.dispose();
    _registerPassword.dispose();
    _loginPasswordFocus.dispose();
    _registerPasswordFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showPage({required bool register}) {
    if (_busy || register == _register) return;
    // Drop the keyboard first: letting it close during the slide makes the
    // whole page jump halfway through the transition.
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _register = register;
      _attempted = false;
      _obscure = true;
      _notice = null;
      if (register) {
        _registerPassword.clear();
        _acceptedPrivacy = false;
        _consentMissing = false;
      } else {
        _loginPassword.clear();
      }
    });
  }

  void _clearNotice() {
    if (_notice != null) setState(() => _notice = null);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final form = _register ? _registerForm : _loginForm;
    final valid = form.currentState?.validate() ?? false;
    final consentMissing = _register && !_acceptedPrivacy;
    setState(() {
      _attempted = true;
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
          password: _registerPassword.text,
          role: _role,
        );
      } else {
        await widget.auth.login(
          email: _email.text.trim(),
          password: _loginPassword.text,
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

  Widget _emailField() => _Field(
    controller: _email,
    label: 'Email',
    icon: Icons.alternate_email_rounded,
    enabled: !_busy,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
    textInputAction: TextInputAction.next,
    onChanged: (_) => _clearNotice(),
    onSubmitted: (_) =>
        (_register ? _registerPasswordFocus : _loginPasswordFocus)
            .requestFocus(),
    validator: (value) {
      final email = value?.trim() ?? '';
      if (email.isEmpty) return 'Email wajib diisi.';
      if (!email.contains('@')) return 'Format email tidak valid.';
      return null;
    },
  );

  Widget _passwordField({required bool register}) => _Field(
    controller: register ? _registerPassword : _loginPassword,
    focusNode: register ? _registerPasswordFocus : _loginPasswordFocus,
    label: 'Password',
    icon: Icons.lock_outline_rounded,
    enabled: !_busy,
    obscureText: _obscure,
    helperText: register ? 'Minimal 6 karakter' : null,
    autofillHints: [
      register ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: TextInputAction.done,
    onChanged: (_) => _clearNotice(),
    onSubmitted: (_) => _submit(),
    suffix: IconButton(
      tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
      onPressed: () => setState(() => _obscure = !_obscure),
      color: AgamColors.subtle,
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
    ),
    validator: (value) {
      if ((value ?? '').isEmpty) return 'Password wajib diisi.';
      if (register && value!.length < 6) {
        return 'Password minimal 6 karakter.';
      }
      return null;
    },
  );

  Widget _noticeSlot() => AgamAnimatedSize(
    milliseconds: 240,
    curve: AgamMotion.easeOut,
    alignment: Alignment.topCenter,
    child: _notice == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _NoticeBanner(notice: _notice!),
          ),
  );

  AutovalidateMode get _autovalidate => _attempted
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  Widget _buildLogin() => Form(
    key: _loginForm,
    autovalidateMode: _autovalidate,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(register: false),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: _busy ? null : _resetPassword,
                style: TextButton.styleFrom(foregroundColor: AgamColors.brand),
                // Styled on the Text, not via textStyle: a button textStyle
                // replaces the theme font instead of merging with it.
                child: Text(
                  'Lupa password?',
                  style: AgamText.label.copyWith(
                    fontSize: 13,
                    color: AgamColors.brand,
                  ),
                ),
              ),
            ),
          ),
          _noticeSlot(),
        ],
      ),
    ),
  );

  Widget _buildRegister() => Form(
    key: _registerForm,
    autovalidateMode: _autovalidate,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(register: true),
          _RegisterExtras(
            role: _role,
            accepted: _acceptedPrivacy,
            missing: _consentMissing,
            enabled: !_busy,
            onRole: (role) => setState(() => _role = role),
            onConsent: (value) => setState(() {
              _acceptedPrivacy = value;
              if (value) _consentMissing = false;
            }),
          ),
          _noticeSlot(),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final page = _register ? 'register' : 'login';
    return PopScope(
      // Back on the register page returns to login, like a pushed page.
      canPop: !_register,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showPage(register: false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Expanded(
                child: ColoredBox(
                  // The sheet overlaps the header (see _Sheet), so its
                  // rounded corners sit on the header ground, glow included.
                  color: Colors.white,
                  child: CustomScrollView(
                    controller: _scroll,
                    physics: const ClampingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      // Header and sheet share one box: inside a viewport an
                      // earlier sliver paints over a later one, so the sheet
                      // could not overlap the header across two slivers.
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Header(
                              child: _PageSwap(
                                forward: _register,
                                alignment: Alignment.bottomLeft,
                                child: _register
                                    ? _HeaderContent(
                                        key: ValueKey('$page-header'),
                                        title: 'Buat akun AGAM',
                                        leading: _RoundBack(
                                          onPressed: _busy
                                              ? null
                                              : () =>
                                                    _showPage(register: false),
                                        ),
                                      )
                                    : const _HeaderContent(
                                        key: ValueKey('login-header'),
                                        title: 'Selamat datang',
                                        leading: _Brand(),
                                      ),
                              ),
                            ),
                            _Sheet(
                              child: _PageSwap(
                                forward: _register,
                                alignment: Alignment.topCenter,
                                child: KeyedSubtree(
                                  key: ValueKey('$page-form'),
                                  child: _register
                                      ? _buildRegister()
                                      : _buildLogin(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // White filler so the sheet runs to the action bar on
                      // tall screens, without measuring the form's intrinsic
                      // height.
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The button is the same control on both pages, so it
                    // stays still; only its label crossfades.
                    AgamPrimaryButton(
                      label: _register ? 'Daftar' : 'Masuk',
                      busy: _submitting,
                      onPressed: _busy ? null : _submit,
                    ),
                    _PageSwap(
                      forward: _register,
                      alignment: Alignment.center,
                      child: _SwitchLink(
                        key: ValueKey('$page-link'),
                        prompt: _register
                            ? 'Sudah punya akun?'
                            : 'Baru di AGAM?',
                        action: _register ? 'Masuk' : 'Daftar',
                        onPressed: _busy
                            ? null
                            : () => _showPage(register: !_register),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

/// Moves one slot of the page along the horizontal shared axis. All slots
/// use the same duration and direction, so header, form and action travel
/// together and read as one page change.
class _PageSwap extends StatelessWidget {
  const _PageSwap({
    required this.forward,
    required this.alignment,
    required this.child,
  });

  final bool forward;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => PageTransitionSwitcher(
    duration: AgamMotion.duration(context, 320),
    reverse: !forward,
    layoutBuilder: (entries) => Stack(alignment: alignment, children: entries),
    transitionBuilder: (child, animation, secondary) => SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondary,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Colors.transparent,
      child: child,
    ),
    child: child,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AgamGround(
      radius: 0,
      colors: const [AgamColors.brandDeep, AgamColors.brandDeep],
      padding: EdgeInsets.fromLTRB(24, top + 24, 24, 44 + AgamRadius.sheet),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({super.key, required this.title, required this.leading});

  final String title;
  final Widget leading;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 44, child: leading),
      const SizedBox(height: 64),
      Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AgamText.display.copyWith(
            color: Colors.white,
            fontSize: 30,
            height: 1.15,
          ),
        ),
      ),
    ],
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Row(
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
  );
}

class _RoundBack extends StatelessWidget {
  const _RoundBack({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: IconButton(
      tooltip: 'Kembali',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .12),
        foregroundColor: Colors.white,
        fixedSize: const Size.square(44),
      ),
      icon: const Icon(Icons.arrow_back_rounded, size: 22),
    ),
  );
}

class _SwitchLink extends StatelessWidget {
  const _SwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: AgamText.bodySmall),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AgamColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(48, 44),
          ),
          child: Text(
            action,
            style: AgamText.label.copyWith(
              fontSize: 13,
              color: AgamColors.brand,
            ),
          ),
        ),
      ],
    ),
  );
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
        padding: EdgeInsets.fromLTRB(20, 8, 20, 4 + inset),
        child: child,
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  // Pulled up by the corner radius so the rounded corners are drawn over
  // the header's gradient and glow instead of a flat backdrop, which left a
  // visible seam where the glow was clipped.
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(0, -AgamRadius.sheet),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgamRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: child,
    ),
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
              motion: _RoleMotion.toss,
              selected: role == UserRole.mahasiswaItb,
              onTap: enabled ? () => onRole(UserRole.mahasiswaItb) : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _RoleCard(
              label: 'Pengunjung',
              icon: Icons.hiking_rounded,
              motion: _RoleMotion.step,
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
    required this.motion,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final _RoleMotion motion;
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
                    _RoleIcon(icon: icon, motion: motion, selected: selected),
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

/// How a role icon reacts once when its card is chosen.
enum _RoleMotion {
  /// The cap lifts and tips back, like a small graduation toss.
  toss,

  /// The walker takes one small step forward.
  step,
}

/// Plays a short one-shot gesture when [selected] turns true. It never
/// loops, never plays on first build, and is skipped under reduced motion.
class _RoleIcon extends StatefulWidget {
  const _RoleIcon({
    required this.icon,
    required this.motion,
    required this.selected,
  });

  final IconData icon;
  final _RoleMotion motion;
  final bool selected;

  @override
  State<_RoleIcon> createState() => _RoleIconState();
}

class _RoleIconState extends State<_RoleIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  @override
  void didUpdateWidget(_RoleIcon old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(
      end: widget.selected ? AgamColors.brand : AgamColors.muted,
    ),
    duration: AgamMotion.duration(context, 200),
    curve: AgamMotion.easeOut,
    builder: (context, color, _) => AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rises quickly, settles slowly: one arc, back to rest at the end.
        final arc = math.sin(
          math.pi * Curves.easeOutCubic.transform(_controller.value),
        );
        return switch (widget.motion) {
          _RoleMotion.toss => Transform.translate(
            offset: Offset(0, -4 * arc),
            child: Transform.rotate(angle: -.22 * arc, child: child),
          ),
          _RoleMotion.step => Transform.translate(
            offset: Offset(4 * arc, 0),
            child: Transform.rotate(angle: .08 * arc, child: child),
          ),
        };
      },
      child: Icon(widget.icon, size: 22, color: color),
    ),
  );
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
          // The fill sits under a transparent Material so the ink ripple is
          // painted on top of it, not hidden behind it.
          child: AnimatedContainer(
            duration: duration,
            curve: AgamMotion.easeOut,
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
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onChanged == null ? null : () => onChanged!(!accepted),
                borderRadius: BorderRadius.circular(AgamRadius.control),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 12),
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
                          color: missing
                              ? AgamColors.danger
                              : AgamColors.subtle,
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
          ),
        ),
        AgamAnimatedSize(
          milliseconds: 220,
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

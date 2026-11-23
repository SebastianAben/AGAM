import 'package:flutter/material.dart';

import '../contracts/contracts.dart';
import 'widgets/agam_components.dart';
import 'widgets/agam_theme.dart';

/// UI10, daftar dan masuk dengan Firebase Auth email/password.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _register = false;
  bool _obscure = true;
  bool _acceptedPrivacy = false;
  bool _busy = false;
  UserRole _role = UserRole.mahasiswaItb;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_register && !_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setujui pemberitahuan privasi untuk melanjutkan.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(error.code))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email terlebih dahulu.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.auth.sendPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jika email terdaftar, tautan reset password telah dikirim.',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_message(error.code))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AgamColors.brandDeep,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/media/logo.png', width: 54, height: 54),
                    const SizedBox(height: 22),
                    Text(
                      _register ? 'Daftar akun' : 'Masuk',
                      style: AgamText.display.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Akun digunakan untuk menyimpan progres di perangkat.',
                      style: AgamText.body.copyWith(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AgamColors.canvas,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AgamRadius.sheet),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Masuk')),
                          ButtonSegment(value: true, label: Text('Daftar')),
                        ],
                        selected: {_register},
                        showSelectedIcon: false,
                        onSelectionChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _register = value.first;
                                _acceptedPrivacy = false;
                              }),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email wajib diisi.';
                          if (!email.contains('@')) {
                            return 'Format email tidak valid.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Tampilkan password'
                                : 'Sembunyikan password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
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
                      if (_register) ...[
                        const SizedBox(height: 16),
                        Text('Peran', style: AgamText.label),
                        const SizedBox(height: 8),
                        SegmentedButton<UserRole>(
                          segments: const [
                            ButtonSegment(
                              value: UserRole.mahasiswaItb,
                              label: Text('Mahasiswa ITB'),
                            ),
                            ButtonSegment(
                              value: UserRole.pengunjung,
                              label: Text('Pengunjung'),
                            ),
                          ],
                          selected: {_role},
                          showSelectedIcon: false,
                          onSelectionChanged: _busy
                              ? null
                              : (value) => setState(() => _role = value.first),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AgamColors.brand,
                          value: _acceptedPrivacy,
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _acceptedPrivacy = value ?? false,
                                ),
                          title: Text(
                            'Posisi diproses di perangkat dan tidak dikirim '
                            'atau disimpan sebagai riwayat. Saya menyetujui '
                            'pengelolaan akun dan log aktivitas yang disetujui.',
                            style: AgamText.bodySmall,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!_register)
                        TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('Lupa password'),
                        ),
                      const SizedBox(height: 8),
                      AgamPrimaryButton(
                        label: _register ? 'Daftar' : 'Masuk',
                        busy: _busy,
                        onPressed: _busy ? null : _submit,
                        icon: _register
                            ? Icons.person_add_alt_1_rounded
                            : Icons.login_rounded,
                      ),
                    ],
                  ),
                ),
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

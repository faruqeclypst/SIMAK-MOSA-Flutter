import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

/// Layar login SIMAK-MOSA (auth PocketBase).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identity = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _masuk() async {
    final id = _identity.text.trim();
    final pw = _password.text;
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Isi email/username dan kata sandi dulu.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await PbService().login(id, pw);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      setState(() {
        _error = 'Gagal masuk. Periksa email/username dan kata sandi.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  Text(
                        'SIMAK-MOSA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 150.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 6),
                  Text(
                        'Sistem Informasi Manajemen Akademik\nSMAN Modal Bangsa',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.grey,
                          height: 1.5,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _identity,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email / Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _masuk(),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _masuk,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Masuk'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Akun dibuat oleh admin sekolah.\nHubungi admin jika belum punya akun.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.grey,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

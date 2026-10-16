import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notifikasi.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

// Halaman Pengaturan: ganti kata sandi, tentang, keluar.
class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  void _tentang(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationIcon: Image.asset(
        'assets/images/logo.png',
        width: 48,
        height: 48,
        fit: BoxFit.contain,
      ),
      applicationName: 'SIMAK MOSA',
      applicationVersion: '2.0.0 (PocketBase)',
      applicationLegalese: 'SMAN Modal Bangsa',
      children: [
        Text(
          'Sistem Informasi Manajemen Akademik.\nBackend: PocketBase.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: AppColors.grey),
            const SizedBox(width: 6),
            Text(
              'Dibuat oleh Alfaruq Asri, S.Pd',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => launchUrl(
            Uri.parse('https://www.alfaruqasri.my.id'),
            mode: LaunchMode.externalApplication,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language_outlined,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'www.alfaruqasri.my.id',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _keluar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PbService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'AKUN',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.lock_outline,
            label: 'Ganti Kata Sandi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GantiPasswordScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'NOTIFIKASI & DERING',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.notifications_active_outlined,
            label: 'Uji Dering & Getar Notifikasi',
            warna: AppColors.primary,
            onTap: () async {
              await tesNotifikasiSuara();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🔔 Notifikasi terkirim dengan dering & getar! Cek bilah notifikasi HP.',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
          ),
          _MenuItem(
            icon: Icons.security_update_good_outlined,
            label: 'Cek Izin Notifikasi Sistem',
            onTap: () async {
              final granted = await requestIzinNotifikasi();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      granted
                          ? 'Izin notifikasi aktif.'
                          : 'Izin notifikasi belum diizinkan oleh sistem HP.',
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Text(
            'APLIKASI',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 10),
          _MenuItem(
            icon: Icons.auto_stories_outlined,
            label: 'Panduan & Onboarding Aplikasi',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(isPreviewOnly: true),
                ),
              );
            },
          ),
          _MenuItem(
            icon: Icons.info_outline,
            label: 'Tentang SIMAK MOSA',
            onTap: () => _tentang(context),
          ),
          _MenuItem(
            icon: Icons.logout,
            label: 'Keluar',
            warna: AppColors.red,
            onTap: () => _keluar(context),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.warna = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: warna),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: warna,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
        onTap: onTap,
      ),
    );
  }
}

class GantiPasswordScreen extends StatefulWidget {
  const GantiPasswordScreen({super.key});

  @override
  State<GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_baru.text.length < 8) {
      _pesan('Kata sandi baru minimal 8 karakter.');
      return;
    }
    if (_baru.text != _konfirmasi.text) {
      _pesan('Konfirmasi kata sandi tidak sama.');
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      await svc.pb
          .collection('users')
          .update(
            svc.me!.id,
            body: {
              'oldPassword': _lama.text,
              'password': _baru.text,
              'passwordConfirm': _konfirmasi.text,
            },
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kata sandi berhasil diganti.')),
      );
    } catch (e) {
      _pesan('Gagal. Pastikan kata sandi lama benar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pesan(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Kata Sandi')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _lama,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kata Sandi Lama',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _baru,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Kata Sandi Baru (min. 8 karakter)',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _konfirmasi,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi Kata Sandi Baru',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _simpan,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simpan Kata Sandi'),
          ),
        ],
      ),
    );
  }
}

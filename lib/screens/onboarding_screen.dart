import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isPreviewOnly;

  const OnboardingScreen({super.key, this.isPreviewOnly = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final String title;
  final String subtitle;
  final String badge;
  final IconData icon;
  final Color primaryColor;
  final Color softColor;
  final List<String> tags;

  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.icon,
    required this.primaryColor,
    required this.softColor,
    required this.tags,
  });
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      badge: 'SISTEM TERPADU',
      title: 'Selamat Datang di\nSIMAK MOSA',
      subtitle:
          'Sistem Informasi Monitoring Akademik modern yang dirancang khusus untuk memperlancar KBM, koordinasi, dan pemantauan di SMAN Modal Bangsa.',
      icon: Icons.school_rounded,
      primaryColor: AppColors.primary,
      softColor: Color(0xFFE8F8EA),
      tags: ['Real-time', 'Multi Peran', 'Terpusat'],
    ),
    _OnboardingSlide(
      badge: 'AKADEMIK & KBM',
      title: 'Jurnal Mengajar &\nMonitoring Piket',
      subtitle:
          'Pantau keterisian kelas secara live, isi jurnal mengajar tanpa ribet, catat izin siswa, dan cetak dokumen resmi dalam satu ketukan.',
      icon: Icons.assignment_turned_in_rounded,
      primaryColor: Color(0xFF0D9488),
      softColor: Color(0xFFCCFBF1),
      tags: ['KBM Terpantau', 'Rekap Presensi', 'Cetak PDF'],
    ),
    _OnboardingSlide(
      badge: 'CATATAN ON SPOT',
      title: 'Fitur CAP:\nStory & Laporan Harian',
      subtitle:
          'Abadikan catatan aktivitas dan peristiwa sekolah ala Story 24 jam. Otomatis reset tiap hari dan tersimpan aman di arsip digital.',
      icon: Icons.bolt_rounded,
      primaryColor: Color(0xFFD97706),
      softColor: Color(0xFFFEF3C7),
      tags: ['Story 24 Jam', 'Arsip Digital', 'Transparan'],
    ),
    _OnboardingSlide(
      badge: 'KOMUNIKASI CEPAT',
      title: 'Chat Koordinasi\nSecepat Telegram',
      subtitle:
          'Hubungi rekan guru dan buat grup koordinasi dengan UI telegram modern, fitur balas kutipan, reaksi emoji, serta notifikasi dering HP nyata.',
      icon: Icons.forum_rounded,
      primaryColor: Color(0xFF2563EB),
      softColor: Color(0xFFDBEAFE),
      tags: ['Notifikasi Dering', 'Kirim Foto', 'Grup Sekolah'],
    ),
  ];

  Future<void> _selesaikanOnboarding() async {
    if (!widget.isPreviewOnly) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    }

    if (!mounted) return;

    if (widget.isPreviewOnly) {
      Navigator.pop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PbService().isLoggedIn ? const MainShell() : const LoginScreen(),
      ),
    );
  }

  void _nextPage() {
    if (_currentIndex < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _selesaikanOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header bar: Logo & Tombol Lewati
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SIMAK MOSA',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _selesaikanOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.grey,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      widget.isPreviewOnly ? 'Tutup' : 'Lewati',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  final s = _slides[index];
                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustration Container
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  s.softColor,
                                  s.softColor.withValues(alpha: 0.3),
                                ],
                                radius: 0.85,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: s.primaryColor.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  s.icon,
                                  size: 58,
                                  color: s.primaryColor,
                                ),
                              ),
                            ),
                          )
                            .animate(key: ValueKey(index))
                            .scale(
                              begin: const Offset(0.85, 0.85),
                              end: const Offset(1, 1),
                              duration: 500.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(duration: 400.ms),

                        const SizedBox(height: 36),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: s.softColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            s.badge,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: s.primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                            .animate(key: ValueKey('badge_$index'))
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 14),

                        // Title
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        )
                            .animate(key: ValueKey('title_$index'))
                            .fadeIn(duration: 400.ms, delay: 100.ms)
                            .slideY(begin: 0.15, end: 0),

                        const SizedBox(height: 12),

                        // Subtitle
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.grey,
                            height: 1.5,
                          ),
                        )
                            .animate(key: ValueKey('sub_$index'))
                            .fadeIn(duration: 400.ms, delay: 150.ms),

                        const SizedBox(height: 20),

                        // Feature Tag Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: s.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6F5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.line.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 13,
                                    color: s.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tag,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                            .animate(key: ValueKey('tags_$index'))
                            .fadeIn(duration: 400.ms, delay: 200.ms),
                      ],
                    ),
                  ),
                );
                },
              ),
            ),

            // Bottom Navigation & Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Smooth Indicator Dots
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _currentIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? slide.primaryColor : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    }),
                  ),

                  // Action Button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slide.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: _currentIndex == _slides.length - 1 ? 26 : 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentIndex == _slides.length - 1
                                ? 'Mulai Sekarang'
                                : 'Lanjut',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _currentIndex == _slides.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.chevron_right_rounded,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

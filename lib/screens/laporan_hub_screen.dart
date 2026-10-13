import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'asrama_screen.dart';
import 'guru_berhalangan_screen.dart';
import 'kurikulum_screen.dart';
import 'laporan_izin_screen.dart';
import 'matriks_piket_screen.dart';
import 'piket_screen.dart';

// Hub Laporan: semua laporan dalam satu tempat, disaring per role.
class LaporanHubScreen extends StatelessWidget {
  const LaporanHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = PbService();
    final items = <_LaporanItem>[];

    if (svc.canLihatMonitoring) {
      items.add(
        _LaporanItem(
          'Kurikulum',
          'Monitoring keterisian KBM hari ini',
          Icons.menu_book_outlined,
          AppColors.primary,
          AppColors.primarySoft,
          const KurikulumScreen(),
        ),
      );
      items.add(
        _LaporanItem(
          'Matriks Piket',
          'Status tiap kelas x jam 1-8',
          Icons.grid_on_outlined,
          const Color(0xFF8B5CF6),
          const Color(0xFFEDE9FE),
          const MatriksPiketScreen(),
        ),
      );
    }
    if (svc.canKelolaBerhalangan || svc.canLihatMonitoring) {
      items.add(
        _LaporanItem(
          'Guru Berhalangan',
          'Guru yang tidak mengajar hari ini',
          Icons.person_off_outlined,
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
          const GuruBerhalanganScreen(),
        ),
      );
    }
    items.add(
      _LaporanItem(
        'Izin Siswa',
        'Agregasi izin piket & asrama',
        Icons.description_outlined,
        AppColors.red,
        AppColors.redSoft,
        const LaporanIzinScreen(),
      ),
    );
    if (svc.canKelolaAsrama || svc.canLihatMonitoring) {
      items.add(
        _LaporanItem(
          'Asrama',
          'Siswa/i tidak berangkat hari ini',
          Icons.home_outlined,
          const Color(0xFF0D9488),
          const Color(0xFFCCFBF1),
          const AsramaScreen(),
        ),
      );
    }
    if (svc.canKelolaPiket || svc.canLihatMonitoring) {
      items.add(
        _LaporanItem(
          'Jurnal Piket',
          'Siswa izin yang dicatat piket',
          Icons.shield_outlined,
          const Color(0xFF8B5CF6),
          const Color(0xFFEDE9FE),
          const PiketScreen(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: items.isEmpty
          ? Center(
              child: Text(
                'Tidak ada laporan untuk peran Anda.',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.grey,
                  fontSize: 15,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final it = items[i];
                return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => it.screen),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: it.warnaSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    it.icon,
                                    color: it.warna,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Laporan ${it.nama}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        it.deskripsi,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: i * 80))
                    .slideX(begin: 0.08, end: 0);
              },
            ),
    );
  }
}

class _LaporanItem {
  final String nama;
  final String deskripsi;
  final IconData icon;
  final Color warna;
  final Color warnaSoft;
  final Widget screen;
  const _LaporanItem(
    this.nama,
    this.deskripsi,
    this.icon,
    this.warna,
    this.warnaSoft,
    this.screen,
  );
}

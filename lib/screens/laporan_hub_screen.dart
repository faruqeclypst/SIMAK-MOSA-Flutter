import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/laporan_pdf.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'asrama_screen.dart';
import 'guru_berhalangan_screen.dart';
import 'kejadian_screen.dart';
import 'keterlambatan_screen.dart';
import 'kurikulum_screen.dart';
import 'laporan_izin_screen.dart';
import 'matriks_piket_screen.dart';
import 'piket_screen.dart';
import 'riwayat_screen.dart';

/// Pusat Laporan & Analitik SIMAK MOSA:
/// Dashboard eksekutif lengkap berisi indikator KPI real-time,
/// tombol cetak laporan PDF resmi harian, modul laporan terstruktur,
/// dan ringkasan kondisi KBM serta kesiswaan.
class LaporanHubScreen extends StatefulWidget {
  const LaporanHubScreen({super.key});

  @override
  State<LaporanHubScreen> createState() => _LaporanHubScreenState();
}

class _LaporanHubScreenState extends State<LaporanHubScreen> {
  int _kbmTerisi = 0;
  int _totalKelas = 18;
  int _totalIzin = 0;
  int _totalBerhalangan = 0;
  int _totalCap = 0;
  bool _loading = true;
  String _kategoriFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _muatDataRingkasan();
  }

  Future<void> _muatDataRingkasan() async {
    setState(() => _loading = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final tgl = svc.tanggalHariIni();

      // 1. Jurnal KBM hari ini
      final jurnal = await pb.collection('jurnal').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );
      final kelasTerisi = jurnal.items
          .map((j) => j.getStringValue('kelas'))
          .toSet()
          .length;

      // 2. Total kelas
      final kelasList = await pb.collection('kelas').getList(page: 1, perPage: 100);

      // 3. Izin piket hari ini
      final izinPiket = await pb.collection('izin_piket').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );

      // 4. Izin asrama hari ini
      final izinAsrama = await pb.collection('izin_asrama').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );

      // 5. Guru berhalangan hari ini
      final berhalangan = await pb.collection('guru_berhalangan').getList(
            page: 1,
            perPage: 50,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );

      // 6. Catatan CAP hari ini
      final cap = await pb.collection('kejadian').getList(
            page: 1,
            perPage: 50,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );

      if (mounted) {
        setState(() {
          _kbmTerisi = kelasTerisi;
          _totalKelas = kelasList.items.isEmpty ? 18 : kelasList.items.length;
          _totalIzin = izinPiket.items.length + izinAsrama.items.length;
          _totalBerhalangan = berhalangan.items.length;
          _totalCap = cap.items.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = PbService();

    final semuaLaporan = <_ModulLaporan>[
      _ModulLaporan(
        kategori: 'Akademik',
        judul: 'Monitoring Kurikulum',
        subjudul: 'Keterisian KBM kelas & jadwal hari ini secara live',
        icon: Icons.menu_book_rounded,
        warna: AppColors.primary,
        warnaSoft: AppColors.primarySoft,
        screen: const KurikulumScreen(),
        tampil: svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Akademik',
        judul: 'Matriks Piket Harian',
        subjudul: 'Grid status kehadiran jam ke 1–8 seluruh kelas',
        icon: Icons.grid_view_rounded,
        warna: const Color(0xFF8B5CF6),
        warnaSoft: const Color(0xFFEDE9FE),
        screen: const MatriksPiketScreen(),
        tampil: svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Akademik',
        judul: 'Riwayat Jurnal Guru',
        subjudul: 'Rekapitulasi pengisian jurnal pembelajaran dan materi KBM',
        icon: Icons.history_edu_rounded,
        warna: const Color(0xFF0284C7),
        warnaSoft: const Color(0xFFE0F2FE),
        screen: const RiwayatScreen(),
        tampil: true,
      ),
      _ModulLaporan(
        kategori: 'Kesiswaan',
        judul: 'Rekap Izin Siswa',
        subjudul: 'Agregasi izin gabungan piket sekolah & santri asrama',
        icon: Icons.badge_outlined,
        warna: AppColors.red,
        warnaSoft: AppColors.redSoft,
        screen: const LaporanIzinScreen(),
        tampil: true,
      ),
      _ModulLaporan(
        kategori: 'Kesiswaan',
        judul: 'Laporan Asrama',
        subjudul: 'Daftar siswa/i sakit dan tidak berangkat dari asrama',
        icon: Icons.holiday_village_outlined,
        warna: const Color(0xFF0D9488),
        warnaSoft: const Color(0xFFCCFBF1),
        screen: const AsramaScreen(),
        tampil: svc.canKelolaAsrama || svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Kesiswaan',
        judul: 'Jurnal Piket Sekolah',
        subjudul: 'Pencatatan mutasi izin keluar-masuk oleh guru piket',
        icon: Icons.shield_outlined,
        warna: const Color(0xFF6366F1),
        warnaSoft: const Color(0xFFEEF2FF),
        screen: const PiketScreen(),
        tampil: svc.canKelolaPiket || svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Kesiswaan',
        judul: 'Keterlambatan Gerbang',
        subjudul: 'Catatan siswa terlambat hadir di gerbang utama sekolah',
        icon: Icons.access_time_filled_rounded,
        warna: const Color(0xFFEA580C),
        warnaSoft: const Color(0xFFFFEDD5),
        screen: const KeterlambatanScreen(),
        tampil: svc.isAdmin || svc.isSatpam || svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Operasional',
        judul: 'Guru Berhalangan',
        subjudul: 'Data guru berhalangan mengajar beserta guru pengganti',
        icon: Icons.person_off_rounded,
        warna: const Color(0xFFB45309),
        warnaSoft: const Color(0xFFFEF3C7),
        screen: const GuruBerhalanganScreen(),
        tampil: svc.canKelolaBerhalangan || svc.canLihatMonitoring,
      ),
      _ModulLaporan(
        kategori: 'Operasional',
        judul: 'Arsip CAP (Catatan & Story)',
        subjudul: 'Arsip digital peristiwa, anomali, & kejadian on-spot 24 jam',
        icon: Icons.bolt_rounded,
        warna: const Color(0xFFD97706),
        warnaSoft: const Color(0xFFFEF3C7),
        screen: const KejadianScreen(),
        tampil: true,
      ),
    ];

    final laporanTampil = semuaLaporan
        .where((m) => m.tampil)
        .where((m) => _kategoriFilter == 'Semua' || m.kategori == _kategoriFilter)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Laporan & Analitik',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _muatDataRingkasan,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _muatDataRingkasan,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Executive KPI Dashboard (Clean & Harmonious)
              _buildKpiBanner(),

              const SizedBox(height: 14),

              // Export PDF Banner (Sleek & Professional)
              _buildExportCard(context),

              const SizedBox(height: 22),

              // Section Header & Filters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Modul Laporan',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      '${laporanTampil.length} Modul Tersedia',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Akademik', 'Kesiswaan', 'Operasional'].map((k) {
                    final aktif = _kategoriFilter == k;
                    return GestureDetector(
                      onTap: () => setState(() => _kategoriFilter = k),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: aktif ? AppColors.primary : Colors.white,
                          border: Border.all(
                            color: aktif ? AppColors.primary : AppColors.line,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          k,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: aktif ? Colors.white : AppColors.grey,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Modul List
              if (laporanTampil.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Text(
                    'Tidak ada laporan pada kategori ini.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.grey,
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: laporanTampil.length,
                  itemBuilder: (ctx, i) {
                    final item = laporanTampil[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => item.screen),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: item.warnaSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: item.warna,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.warnaSoft,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.kategori.toUpperCase(),
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: item.warna,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.judul,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.5,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        item.subjudul,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: AppColors.grey,
                                          fontSize: 11.5,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: i * 40)).slideY(
                          begin: 0.06,
                          end: 0,
                        );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rekap Operasional Hari Ini',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _loading ? 'Memuat...' : 'Live Sync',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primaryDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Grid KPI Metrics (Harmonious Tinted Cards)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'KBM Terisi',
                  value: _loading ? '...' : '$_kbmTerisi/$_totalKelas',
                  sub: 'Kelas hari ini',
                  icon: Icons.class_outlined,
                  color: AppColors.primary,
                  bgColor: AppColors.primarySoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Izin Siswa',
                  value: _loading ? '...' : '$_totalIzin',
                  sub: 'Piket & asrama',
                  icon: Icons.person_pin_outlined,
                  color: AppColors.red,
                  bgColor: AppColors.redSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Berhalangan',
                  value: _loading ? '...' : '$_totalBerhalangan',
                  sub: 'Guru izin/tugas',
                  icon: Icons.event_busy_outlined,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Catatan CAP',
                  value: _loading ? '...' : '$_totalCap',
                  sub: 'Peristiwa 24 jam',
                  icon: Icons.bolt_outlined,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFDBEAFE),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.grey,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00AA13), Color(0xFF00750D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cetak Rekap Harian Resmi',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ekspor PDF monitoring KBM, piket, & izin siswa 1 dokumen.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => cetakLaporanMonitoring(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Cetak',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }
}

class _ModulLaporan {
  final String kategori;
  final String judul;
  final String subjudul;
  final IconData icon;
  final Color warna;
  final Color warnaSoft;
  final Widget screen;
  final bool tampil;

  const _ModulLaporan({
    required this.kategori,
    required this.judul,
    required this.subjudul,
    required this.icon,
    required this.warna,
    required this.warnaSoft,
    required this.screen,
    required this.tampil,
  });
}

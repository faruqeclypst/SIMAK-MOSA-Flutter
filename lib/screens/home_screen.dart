import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/instagram_section.dart';
import '../widgets/kabar_sekolah.dart';
import '../widgets/pengumuman_banner.dart';
import 'admin/master_data_screen.dart';
import 'admin/pengumuman_admin_screen.dart';
import 'asrama_screen.dart';
import 'guru_berhalangan_screen.dart';
import 'jadwal_screen.dart';
import 'jurnal_form_screen.dart';
import 'kejadian_screen.dart';
import 'keterlambatan_screen.dart';
import 'kurikulum_screen.dart';
import 'laporan_izin_screen.dart';
import 'matriks_piket_screen.dart';
import 'piket_screen.dart';
import 'riwayat_screen.dart';
import 'satpam/izin_gerbang_screen.dart';
import 'search_result_screen.dart';

// Beranda: sapaan + search + pengingat mengajar + ringkasan
// + grid layanan adaptif per role. Data real dari PocketBase.
class HomeScreen extends StatefulWidget {
  final VoidCallback onAvatarTap;
  final VoidCallback? onLihatPengumuman;

  const HomeScreen({
    super.key,
    required this.onAvatarTap,
    this.onLihatPengumuman,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Jam ke -> menit mulai (07:00, tiap jam 45 menit)
int _menitMulaiJam(int jamKe) => 7 * 60 + (jamKe - 1) * 45;

String _fmtMenit(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

class _HomeScreenState extends State<HomeScreen> {
  List<RecordModel> _jadwalHariIni = [];
  List<RecordModel> _jadwalSaya = [];
  int _kelasTerisi = 0;
  int _kelasKosong = 0;
  int _totalKelas = 18;
  int _jurnalSayaHariIni = 0;
  int _gerbangDiLuar = 0;
  int _gerbangMenunggu = 0;
  int _gerbangTerlambat = 0;
  int _gerbangTotal = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = PbService();
      final pb = svc.pb;
      final hari = svc.hariIni();
      final tgl = svc.tanggalHariIni();

      final jadwal = await pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 50,
            filter: 'hari = "$hari"',
            sort: 'jam_ke',
            expand: 'kelas',
          );

      final jurnal = await pb
          .collection('jurnal')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );
      final kelasIds = jurnal.items
          .map((j) => j.getStringValue('kelas'))
          .toSet();

      final semuaKelas = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100);

      setState(() {
        _jadwalHariIni = jadwal.items;
        _jadwalSaya = jadwal.items
            .where((j) => j.getStringValue('guru') == svc.me!.id)
            .toList();
        _jurnalSayaHariIni = jurnal.items
            .where((j) => j.getStringValue('guru') == svc.me?.id)
            .length;
        _kelasTerisi = kelasIds.length;
        _totalKelas = semuaKelas.items.length;
        _kelasKosong = _totalKelas - _kelasTerisi;
        _loading = false;
      });

      if (svc.isSatpam || svc.canKelolaGerbang) {
        try {
          final tkt = await pb.collection('izin_keluar').getList(
                page: 1,
                perPage: 200,
                sort: '-created',
              );
          final now = DateTime.now();
          if (mounted) {
            setState(() {
              _gerbangTotal = tkt.items.length;
              _gerbangDiLuar = tkt.items
                  .where((t) => t.getStringValue('status') == 'Di Luar Kampus')
                  .length;
              _gerbangMenunggu = tkt.items
                  .where((t) => t.getStringValue('status') == 'Menunggu Keluar')
                  .length;
              _gerbangTerlambat = tkt.items.where((t) {
                if (t.getStringValue('status') == 'Terlambat') return true;
                if (t.getStringValue('status') == 'Di Luar Kampus') {
                  final w = t.getStringValue('waktu_kembali');
                  if (w.isNotEmpty) {
                    final dt = DateTime.tryParse(w);
                    if (dt != null && now.isAfter(dt)) return true;
                  }
                }
                return false;
              }).length;
            });
          }
        } catch (_) {}
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Tidak bisa memuat data. Periksa koneksi.';
      });
    }
  }

  /// Jadwal mengajar milik guru yang relevan sebagai pengingat:
  /// yang sedang berlangsung atau mulai <= 60 menit lagi.
  List<RecordModel> _pengingatMengajar() {
    if (_jadwalSaya.isEmpty) return [];
    final now = DateTime.now();
    final menitNow = now.hour * 60 + now.minute;
    final hasil = <RecordModel>[];
    for (final j in _jadwalSaya) {
      final jamKe = j.getIntValue('jam_ke');
      final mulai = _menitMulaiJam(jamKe);
      final selesai = mulai + 45;
      if (menitNow >= mulai - 60 && menitNow < selesai) {
        hasil.add(j);
      }
    }
    hasil.sort(
      (a, b) => a.getIntValue('jam_ke').compareTo(b.getIntValue('jam_ke')),
    );
    return hasil;
  }

  String _statusKelas(RecordModel j) {
    final now = DateTime.now();
    final menitNow = now.hour * 60 + now.minute;
    final mulai = _menitMulaiJam(j.getIntValue('jam_ke'));
    if (menitNow >= mulai && menitNow < mulai + 45) {
      return 'Sedang berlangsung';
    }
    final sisa = mulai - menitNow;
    if (sisa <= 0) return 'Selesai';
    if (sisa < 60) return 'Mulai $sisa mnt lagi';
    return 'Mulai ${_fmtMenit(mulai)}';
  }

  void _bukaLayanan(BuildContext context, String nama) {
    Widget? target;
    switch (nama) {
      case 'Jadwal':
        target = const JadwalScreen();
      case 'Riwayat':
        target = const RiwayatScreen();
      case 'Kurikulum':
        target = const KurikulumScreen();
      case 'Master Data':
        target = const MasterDataScreen();
      case 'Piket':
        target = const PiketScreen();
      case 'Asrama':
        target = const AsramaScreen();
      case 'Izin':
        target = const LaporanIzinScreen();
      case 'Keterlambatan':
        target = const KeterlambatanScreen();
      case 'Matriks':
        target = const MatriksPiketScreen();
      case 'Berhalangan':
        target = const GuruBerhalanganScreen();
      case 'Pengumuman':
        if (PbService().isAdmin) {
          target = const PengumumanAdminScreen();
        } else {
          widget.onLihatPengumuman?.call();
          return;
        }
      case 'Kejadian':
        target = const KejadianScreen();
      case 'Izin Gerbang':
        target = const IzinGerbangScreen();
      case 'Perizinan Siswa':
        target = const LaporanIzinScreen();
    }
    if (target != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => target!));
    }
  }

  List<_Layanan> _layananUntukRole() {
    final svc = PbService();
    const jadwal = _Layanan(
      'Jadwal',
      Icons.calendar_today_outlined,
      AppColors.blue,
      AppColors.blueSoft,
    );
    const riwayat = _Layanan(
      'Riwayat',
      Icons.access_time_outlined,
      AppColors.amber,
      AppColors.amberSoft,
    );
    const kurikulum = _Layanan(
      'Kurikulum',
      Icons.menu_book_outlined,
      AppColors.primary,
      AppColors.primarySoft,
    );
    const piket = _Layanan(
      'Piket',
      Icons.shield_outlined,
      Color(0xFF8B5CF6),
      Color(0xFFEDE9FE),
    );
    const asrama = _Layanan(
      'Asrama',
      Icons.home_outlined,
      Color(0xFF0D9488),
      Color(0xFFCCFBF1),
    );
    const izin = _Layanan(
      'Izin',
      Icons.description_outlined,
      AppColors.red,
      AppColors.redSoft,
    );
    const keterlambatan = _Layanan(
      'Keterlambatan',
      Icons.timer_outlined,
      AppColors.amber,
      AppColors.amberSoft,
    );
    const master = _Layanan(
      'Master Data',
      Icons.dataset_outlined,
      AppColors.ink,
      AppColors.greyLight,
    );
    const matriks = _Layanan(
      'Matriks',
      Icons.grid_on_outlined,
      Color(0xFF8B5CF6),
      Color(0xFFEDE9FE),
    );
    const berhalangan = _Layanan(
      'Berhalangan',
      Icons.person_off_outlined,
      Color(0xFF92400E),
      Color(0xFFFEF3C7),
    );
    const pengumuman = _Layanan(
      'Pengumuman',
      Icons.campaign_outlined,
      AppColors.primary,
      AppColors.primarySoft,
    );
    const kejadian = _Layanan(
      'Kejadian',
      Icons.bolt_outlined,
      Color(0xFFD97706),
      Color(0xFFFEF3C7),
    );
    const izinGerbang = _Layanan(
      'Izin Gerbang',
      Icons.confirmation_number_outlined,
      Color(0xFF0284C7),
      Color(0xFFE0F2FE),
    );
    const perizinanSiswa = _Layanan(
      'Perizinan Siswa',
      Icons.assignment_ind_outlined,
      Color(0xFF0D9488),
      Color(0xFFCCFBF1),
    );

    switch (svc.peran) {
      case 'admin':
        return [
          jadwal,
          riwayat,
          kurikulum,
          piket,
          matriks,
          berhalangan,
          kejadian,
          asrama,
          izinGerbang,
          izin,
          keterlambatan,
          pengumuman,
          master,
        ];
      case 'kurikulum':
        return [kurikulum, berhalangan, kejadian, riwayat, izin, jadwal];
      case 'asrama':
        return [asrama, izinGerbang, perizinanSiswa, kejadian, izin, jadwal, riwayat];
      case 'waka':
        return [
          kurikulum,
          matriks,
          berhalangan,
          kejadian,
          izin,
          asrama,
          piket,
          riwayat,
          jadwal,
        ];
      case 'satpam':
        return [
          izinGerbang,
          perizinanSiswa,
          keterlambatan,
          kejadian,
        ];
      case 'piket':
        return [piket, izinGerbang, matriks, berhalangan, kejadian, jadwal, riwayat, izin];
      case 'guru':
      default:
        return [
          jadwal,
          riwayat,
          kurikulum,
          kejadian,
          izin,
          matriks,
          berhalangan,
          pengumuman,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = PbService();
    final avatar = svc.avatarUrl();
    final layanan = _layananUntukRole();
    final pengingat = _pengingatMengajar();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _muat,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand header
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SIMAK MOSA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo,',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            color: AppColors.grey,
                          ),
                        ),
                        Text(
                          svc.nama,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${svc.hariIni()}, ${DateTime.now().day} ${_namaBulan()} • ${svc.peranLabel}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onAvatarTap,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              svc.inisial,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0),
              const SizedBox(height: 18),
              TextField(
                    readOnly: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchResultScreen(),
                        ),
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari kelas, siswa...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.grey,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F1F1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0),
              // Pengingat jam mengajar (hanya untuk guru yang mengajar, bukan satpam)
              if (!svc.isSatpam && pengingat.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...pengingat.map((j) {
                  final namaKelas = j.getStringValue('expand.kelas.nama');
                  final jamKe = j.getIntValue('jam_ke');
                  final mulai = _menitMulaiJam(jamKe);
                  final berlangsung = _statusKelas(j) == 'Sedang berlangsung';
                  return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: berlangsung
                                ? [
                                    const Color(0xFF00B818),
                                    const Color(0xFF00820F),
                                  ]
                                : [
                                    const Color(0xFFFFB800),
                                    const Color(0xFFF59E0B),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (berlangsung
                                          ? AppColors.primary
                                          : AppColors.amber)
                                      .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.notifications_active_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    berlangsung
                                        ? 'Sedang Mengajar'
                                        : 'Segera Mengajar',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$namaKelas • ${j.getStringValue('mapel')}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Jam ke-$jamKe (${_fmtMenit(mulai)}–${_fmtMenit(mulai + 45)}) • ${_statusKelas(j)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => JurnalFormScreen(
                                      kelasIdAwal: j.getStringValue('kelas'),
                                      jamAwal: jamKe,
                                      materiAwal: j.getStringValue('mapel'),
                                    ),
                                  ),
                                );
                                if (ok == true) _muat();
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'Isi Jurnal',
                                style: GoogleFonts.plusJakartaSans(
                                  color: berlangsung
                                      ? AppColors.primaryDark
                                      : const Color(0xFF92400E),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.15, end: 0)
                      .shimmer(
                        delay: 1200.ms,
                        duration: 1500.ms,
                        color: Colors.white.withValues(alpha: 0.3),
                      );
                }),
              ],
              const SizedBox(height: 18),
              // Hero Card Adaptif Berdasarkan Peran:
              // 1. Piket, Kurikulum, Waka, Admin: Ringkasan 18 Kelas KBM Sekolah
              // 2. Satpam: Pos Keamanan & Perizinan Gerbang (Siswa di luar kampus & keterlambatan)
              // 3. Guru Biasa: Jurnal Mengajar Anda Hari Ini
              if (svc.canLihatMonitoringKelas) ...[
                _buildCardMonitoringSekolah(),
              ] else if (svc.isSatpam) ...[
                _buildCardGerbangSatpam(),
              ] else ...[
                _buildCardKbmGuru(),
              ],
              const SizedBox(height: 26),
              Text(
                'Layanan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
              const SizedBox(height: 12),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.redSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_outlined,
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
              PengumumanBanner(
                onLihatSemua: () => widget.onLihatPengumuman?.call(),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: layanan.length,
                itemBuilder: (context, i) {
                  final l = layanan[i];
                  return _ServiceTile(
                        label: l.nama,
                        icon: l.icon,
                        warna: l.warna,
                        warnaSoft: l.warnaSoft,
                        onTap: () => _bukaLayanan(context, l.nama),
                      )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 300 + i * 60),
                        duration: 400.ms,
                      )
                      .scale(begin: const Offset(0.85, 0.85));
                },
              ),
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jadwal Hari Ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JadwalScreen()),
                      );
                    },
                    child: Text(
                      'Lihat Semua',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
              const SizedBox(height: 8),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_jadwalHariIni.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.greyLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Tidak ada jadwal hari ${svc.hariIni()}.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.grey,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ..._jadwalHariIni.take(3).map((j) {
                  final namaKelas = j.getStringValue('expand.kelas.nama');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: Text(
                              '${j.getIntValue('jam_ke')}',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                j.getStringValue('mapel'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kelas $namaKelas • Jam ke-${j.getIntValue('jam_ke')}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.grey),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 18),
              const InstagramSection(),
              const SizedBox(height: 18),
              const KabarSekolah(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Kartu Ringkasan KBM Agregat Seluruh Sekolah (Piket, Kurikulum, Waka, Admin)
  Widget _buildCardMonitoringSekolah() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const JurnalFormScreen(),
            ),
          );
          if (ok == true) _muat();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00AA13), Color(0xFF00750D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
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
                          _loading
                              ? 'Memuat status KBM...'
                              : '$_kelasTerisi dari $_totalKelas Kelas Terisi',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _loading
                              ? ''
                              : '$_kelasKosong ruang kelas belum terisi jurnal hari ini',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _totalKelas > 0
                          ? '${((_kelasTerisi / _totalKelas) * 100).toInt()}%'
                          : '0%',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _totalKelas > 0
                      ? (_kelasTerisi / _totalKelas)
                      : 0.0,
                  backgroundColor: Colors.white.withValues(
                    alpha: 0.25,
                  ),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Ketuk kartu ini untuk mengisi / pantau jurnal KBM',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Isi Jurnal',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 200.ms, duration: 500.ms)
    .slideY(begin: 0.12, end: 0);
  }

  // 2. Kartu Pos Keamanan & Perizinan Gerbang Kampus (Satpam / PKD)
  Widget _buildCardGerbangSatpam() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const IzinGerbangScreen(),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
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
                          '$_gerbangDiLuar Siswa di Luar Kampus',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_gerbangMenunggu siap keluar • $_gerbangTerlambat terlambat kembali',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_gerbangTotal Tiket',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Periksa tiket & catat jam keluar-masuk gerbang',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Izin Gerbang',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 200.ms, duration: 500.ms)
    .slideY(begin: 0.12, end: 0);
  }

  // 3. Kartu Jurnal Mengajar Personal Guru (Khusus Guru Biasa)
  Widget _buildCardKbmGuru() {
    final totalJadwal = _jadwalSaya.length;
    final terisi = _jurnalSayaHariIni;
    final persen =
        totalJadwal > 0 ? (terisi / totalJadwal).clamp(0.0, 1.0) : 1.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const JurnalFormScreen(),
            ),
          );
          if (ok == true) _muat();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00AA13), Color(0xFF00750D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
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
                          totalJadwal == 0
                              ? 'Jurnal Mengajar Hari Ini'
                              : '$terisi dari $totalJadwal Jadwal Terisi',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalJadwal == 0
                              ? 'Tidak ada jadwal mengajar terjadwal hari ini'
                              : (totalJadwal > terisi
                                  ? '${totalJadwal - terisi} jadwal mengajar belum diisi jurnal'
                                  : 'Seluruh jurnal mengajar Anda hari ini selesai'),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(
                              alpha: 0.85,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      totalJadwal > 0
                          ? '${(persen * 100).toInt()}%'
                          : '100%',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: persen,
                  backgroundColor: Colors.white.withValues(
                    alpha: 0.25,
                  ),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Ketuk kartu ini untuk mengisi jurnal kelas',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Isi Jurnal',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: 200.ms, duration: 500.ms)
    .slideY(begin: 0.12, end: 0);
  }

  String _namaBulan() {
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return bulan[DateTime.now().month];
  }
}

class _Layanan {
  final String nama;
  final IconData icon;
  final Color warna;
  final Color warnaSoft;
  const _Layanan(this.nama, this.icon, this.warna, this.warnaSoft);
}

class _ServiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color warna;
  final Color warnaSoft;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.label,
    required this.icon,
    required this.warna,
    required this.warnaSoft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: warna,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: warna.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

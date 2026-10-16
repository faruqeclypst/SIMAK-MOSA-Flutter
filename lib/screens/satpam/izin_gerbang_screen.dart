import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';

/// Sistem Manajemen Gerbang & Perizinan Sekolah Berasrama (MOSA Gate Pass & Boarding Pass)
/// Digunakan oleh Satpam/PKD, Pembina Asrama, Guru Piket, dan Admin untuk:
/// 1. Memantau izin keluar-masuk kampus (IB / Izin Bermalam, Pesiar, Berobat, dsb)
/// 2. Tracking jam keluar aktual & jam kembali aktual dengan nomor tiket resmi
/// 3. Deteksi keterlambatan kepulangan santri/siswa ke asrama
/// 4. Memeriksa izin siswa hari ini dari Guru Piket dan Asrama
class IzinGerbangScreen extends StatefulWidget {
  const IzinGerbangScreen({super.key});

  @override
  State<IzinGerbangScreen> createState() => _IzinGerbangScreenState();
}

class _IzinGerbangScreenState extends State<IzinGerbangScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecordModel> _tiketList = [];
  List<RecordModel> _izinPiketList = [];
  List<RecordModel> _asramaList = [];
  List<RecordModel> _siswaList = [];

  bool _loading = true;
  String _cariQuery = '';
  String _filterStatus = 'Semua';
  Function? _unsubTiket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _muatData();
    _langgananRealtime();
  }

  @override
  void dispose() {
    _unsubTiket?.call();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _langgananRealtime() async {
    try {
      final pb = PbService().pb;
      _unsubTiket = await pb.collection('izin_keluar').subscribe('*', (e) {
        _muatData(silent: true);
      });
    } catch (_) {}
  }

  String _formatWaktuDb(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:$sec';
  }

  String _formatJamDetik(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$h:$min:$sec';
  }

  String _formatKodeTgl(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  Future<void> _muatData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final tgl = PbService().tanggalHariIni();

      // 1. Muat tiket keluar gerbang
      final tktRes = await pb.collection('izin_keluar').getList(
            page: 1,
            perPage: 300,
            sort: '-created',
            expand: 'siswa,siswa.kelas,satpam_petugas',
          );

      // 2. Muat izin piket hari ini (izin guru/sekolah)
      final piketRes = await pb.collection('izin_piket').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            sort: '-created',
            expand: 'siswa,siswa.kelas',
          );

      // 3. Muat laporan asrama hari ini
      final asramaRes = await pb.collection('asrama').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            sort: '-created',
            expand: 'siswa,siswa.kelas',
          );

      // 4. Muat daftar siswa untuk form tiket baru
      final sRes = await pb.collection('siswa').getList(
            page: 1,
            perPage: 500,
            sort: 'nama',
            expand: 'kelas',
          );

      if (!mounted) return;
      setState(() {
        _tiketList = tktRes.items;
        _izinPiketList = piketRes.items;
        _asramaList = asramaRes.items;
        _siswaList = sRes.items;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Statistik tiket gerbang
  int get _countDiLuar => _tiketList
      .where((t) => t.getStringValue('status') == 'Di Luar Kampus')
      .length;
  int get _countMenunggu => _tiketList
      .where((t) => t.getStringValue('status') == 'Menunggu Keluar')
      .length;
  int get _countTerlambat => _tiketList
      .where((t) =>
          t.getStringValue('status') == 'Terlambat' ||
          _apakahTerlambatOtomatis(t))
      .length;
  int get _countKembali => _tiketList
      .where((t) => t.getStringValue('status') == 'Sudah Kembali')
      .length;

  bool _apakahTerlambatOtomatis(RecordModel t) {
    if (t.getStringValue('status') != 'Di Luar Kampus') return false;
    final wKembaliStr = t.getStringValue('waktu_kembali');
    if (wKembaliStr.isEmpty) return false;
    try {
      final batas = DateTime.parse(wKembaliStr);
      return DateTime.now().isAfter(batas);
    } catch (_) {
      return false;
    }
  }

  String _fmtWaktu(String iso) {
    if (iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
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
      final jam = d.hour.toString().padLeft(2, '0');
      final mnt = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${bulan[d.month]} ${d.year}, $jam:$mnt';
    } catch (_) {
      return iso;
    }
  }

  String _fmtJamSaja(String str) {
    if (str.isEmpty) return '-';
    try {
      if (str.contains(' ')) {
        final d = DateTime.parse(str).toLocal();
        final jam = d.hour.toString().padLeft(2, '0');
        final mnt = d.minute.toString().padLeft(2, '0');
        return '$jam:$mnt WIB';
      }
      return str;
    } catch (_) {
      return str;
    }
  }

  List<RecordModel> _tiketTampil() {
    return _tiketList.where((t) {
      final noTiket = t.getStringValue('nomor_tiket').toLowerCase();
      final siswaNama =
          t.getStringValue('expand.siswa.nama').toLowerCase();
      final jenis = t.getStringValue('jenis').toLowerCase();
      final ket = t.getStringValue('keterangan').toLowerCase();
      final q = _cariQuery.toLowerCase();

      final cocokCari = q.isEmpty ||
          noTiket.contains(q) ||
          siswaNama.contains(q) ||
          jenis.contains(q) ||
          ket.contains(q);

      if (!cocokCari) return false;

      final st = t.getStringValue('status');
      final telat = _apakahTerlambatOtomatis(t);

      if (_filterStatus == 'Menunggu Keluar') return st == 'Menunggu Keluar';
      if (_filterStatus == 'Di Luar Kampus') {
        return st == 'Di Luar Kampus' && !telat;
      }
      if (_filterStatus == 'Terlambat') {
        return st == 'Terlambat' || telat;
      }
      if (_filterStatus == 'Sudah Kembali') return st == 'Sudah Kembali';

      return true;
    }).toList();
  }

  // Aksi Satpam: Siswa Tap Keluar Gerbang
  Future<void> _tapKeluarGerbang(RecordModel t) async {
    final namaSiswa = t.getStringValue('expand.siswa.nama');
    final noTiket = t.getStringValue('nomor_tiket');
    final now = DateTime.now();
    final jamStr = _formatJamDetik(now);
    final waktuAktual = _formatWaktuDb(now);

    final konfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sensor_door_outlined,
                  color: Color(0xFFD97706)),
            ),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar Gerbang',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Catat waktu keluar gerbang untuk santri/siswa:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              namaSiswa,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tiket: #$noTiket',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Jam Keluar: $jamStr WIB',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Catat Keluar Sekarang'),
          ),
        ],
      ),
    );

    if (konfirm == true) {
      try {
        final pb = PbService().pb;
        final meId = PbService().me?.id;
        final body = <String, dynamic>{
          'status': 'Di Luar Kampus',
          'jam_keluar_aktual': waktuAktual,
        };
        if (meId != null) body['satpam_petugas'] = meId;
        await pb.collection('izin_keluar').update(t.id, body: body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$namaSiswa tercatat keluar gerbang jam $jamStr WIB.'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _muatData(silent: true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mencatat keluar gerbang.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  // Aksi Satpam: Siswa Tap Kembali ke Kampus
  Future<void> _tapKembaliKampus(RecordModel t) async {
    final namaSiswa = t.getStringValue('expand.siswa.nama');
    final noTiket = t.getStringValue('nomor_tiket');
    final wKembaliStr = t.getStringValue('waktu_kembali');
    final now = DateTime.now();
    final jamStr = _formatJamDetik(now);
    final waktuAktual = _formatWaktuDb(now);

    bool telat = false;
    Duration selisih = Duration.zero;
    if (wKembaliStr.isNotEmpty) {
      try {
        final batas = DateTime.parse(wKembaliStr);
        if (now.isAfter(batas)) {
          telat = true;
          selisih = now.difference(batas);
        }
      } catch (_) {}
    }

    final konfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: telat ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                telat ? Icons.warning_amber_rounded : Icons.login_rounded,
                color: telat ? AppColors.red : const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Kembali Kampus',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Santri/siswa tiba kembali di gerbang:',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              namaSiswa,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Tiket: #$noTiket',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0284C7),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: telat ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: telat ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled,
                        color: telat ? AppColors.red : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Jam Kembali: $jamStr WIB',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: telat ? AppColors.red : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  if (telat) ...[
                    const SizedBox(height: 6),
                    Text(
                      'PERINGATAN: Siswa melewati batas waktu kembali (${selisih.inHours} jam ${selisih.inMinutes % 60} menit terlambat). Status akan ditandai Terlambat.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: telat ? AppColors.red : const Color(0xFF0284C7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(telat ? 'Catat & Tandai Terlambat' : 'Catat Tiba di Kampus'),
          ),
        ],
      ),
    );

    if (konfirm == true) {
      try {
        final pb = PbService().pb;
        final meId = PbService().me?.id;
        final body = <String, dynamic>{
          'status': telat ? 'Terlambat' : 'Sudah Kembali',
          'jam_kembali_aktual': waktuAktual,
        };
        if (meId != null) body['satpam_petugas'] = meId;
        await pb.collection('izin_keluar').update(t.id, body: body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                telat
                    ? '$namaSiswa tercatat kembali jam $jamStr WIB (Terlambat).'
                    : '$namaSiswa telah kembali ke asrama dengan selamat.',
              ),
              backgroundColor: telat ? AppColors.red : AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _muatData(silent: true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mencatat kembali ke kampus.'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  // Dialog Tiket Digital / Boarding Pass Detail
  void _bukaDetailTiket(RecordModel t) {
    final noTiket = t.getStringValue('nomor_tiket');
    final namaSiswa = t.getStringValue('expand.siswa.nama');
    final namaKelas = t.getStringValue('expand.siswa.expand.kelas.nama');
    final nisn = t.getStringValue('expand.siswa.nisn');
    final jenis = t.getStringValue('jenis');
    final ket = t.getStringValue('keterangan');
    final penjemput = t.getStringValue('penjemput');
    final penyetuju = t.getStringValue('penyetuju');
    final wKeluar = _fmtWaktu(t.getStringValue('waktu_keluar'));
    final wKembali = _fmtWaktu(t.getStringValue('waktu_kembali'));
    final jKeluarAktual = _fmtJamSaja(t.getStringValue('jam_keluar_aktual'));
    final jKembaliAktual = _fmtJamSaja(t.getStringValue('jam_kembali_aktual'));
    final status = t.getStringValue('status');
    final satpam =
        t.getStringValue('expand.satpam_petugas.nama_lengkap');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header Tiket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 26,
                            height: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MOSA GATE PASS',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kartu Perizinan Keluar-Masuk Kampus',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  _badgeStatus(status, _apakahTerlambatOtomatis(t)),
                ],
              ),
              const SizedBox(height: 16),
              // Nomor Tiket Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOMOR TIKET PERIZINAN',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '#$noTiket',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0284C7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          color: AppColors.primary, size: 20),
                      tooltip: 'Salin Nomor Tiket',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: noTiket));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nomor tiket berhasil disalin!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Data Siswa
              _barisInfo('Nama Santri/Siswa', namaSiswa.isEmpty ? '-' : namaSiswa),
              _barisInfo('Kelas / NISN',
                  'Kelas ${namaKelas.isNotEmpty ? namaKelas : "-"} • NISN: ${nisn.isNotEmpty ? nisn : "-"}'),
              _barisInfo('Jenis Izin', jenis),
              _barisInfo('Keperluan / Alasan', ket.isEmpty ? '-' : ket),
              _barisInfo('Penjemput / Wali',
                  penjemput.isEmpty ? 'Mandiri / Tidak ada' : penjemput),
              _barisInfo('Penyetuju Izin',
                  penyetuju.isEmpty ? 'Guru Piket / Asrama' : penyetuju),
              const Divider(height: 24),
              // Jadwal Rencana & Aktual
              Text(
                'WAKTU & LOG POS GERBANG',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              _barisInfo('Rencana Keluar', wKeluar),
              _barisInfo('Batas Waktu Kembali', wKembali),
              _barisInfo('Jam Keluar Aktual Gerbang', jKeluarAktual),
              _barisInfo('Jam Tiba Aktual di Kampus', jKembaliAktual),
              if (satpam.isNotEmpty)
                _barisInfo('Petugas Satpam / PKD', satpam),
              const SizedBox(height: 20),
              // Tombol aksi di dalam modal
              if (status == 'Menunggu Keluar')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _tapKeluarGerbang(t);
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Tap Siswa Keluar Gerbang'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              else if (status == 'Di Luar Kampus' || status == 'Terlambat')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _tapKembaliKampus(t);
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Tap Siswa Kembali ke Kampus'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barisInfo(String label, String isi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isi,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog Buat Tiket Gerbang / Izin Darurat Baru
  void _bukaFormTiketBaru() {
    String? siswaTerpilihId;
    String jenisTerpilih = 'Izin Keluar Kampus';
    final ketCtrl = TextEditingController();
    final penjemputCtrl = TextEditingController();
    final penyetujuCtrl = TextEditingController(
      text: PbService().isSatpam
          ? 'Pos Satpam (Darurat)'
          : '${PbService().nama} (${PbService().peranLabel})',
    );

    DateTime tglKeluar = DateTime.now();
    DateTime tglKembali = DateTime.now().add(const Duration(hours: 4));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: AppColors.primaryDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Buat Tiket Gerbang / IB',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih Santri/Siswa:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: siswaTerpilihId,
                  decoration: InputDecoration(
                    hintText: 'Pilih siswa...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _siswaList.map((s) {
                    final nama = s.getStringValue('nama');
                    final kelas =
                        s.getStringValue('expand.kelas.nama');
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '$nama (${kelas.isNotEmpty ? "Kelas $kelas" : "-"})',
                        style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setDialogState(() => siswaTerpilihId = v),
                ),
                const SizedBox(height: 12),
                Text(
                  'Jenis Perizinan:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: jenisTerpilih,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Izin Pulang (IB/Bermalam)',
                        child: Text('Izin Pulang (IB / Bermalam)')),
                    DropdownMenuItem(
                        value: 'Izin Keluar Kampus',
                        child: Text('Izin Keluar Kampus (Pesiar)')),
                    DropdownMenuItem(
                        value: 'Izin Berobat/Medis',
                        child: Text('Izin Berobat / Medis (Klinik/RS)')),
                    DropdownMenuItem(
                        value: 'Izin Lomba/Dinas',
                        child: Text('Izin Lomba / Kegiatan Dinas')),
                    DropdownMenuItem(
                        value: 'Lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() {
                        jenisTerpilih = v;
                        if (v.contains('IB') || v.contains('Bermalam')) {
                          tglKembali =
                              DateTime.now().add(const Duration(days: 2));
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ketCtrl,
                  decoration: InputDecoration(
                    labelText: 'Keperluan / Keterangan',
                    hintText: 'mis. Pulang bersama keluarga / Beli obat',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: penjemputCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nama Penjemput / Wali',
                    hintText: 'mis. Bpk. Arman (Ayah)',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: penyetujuCtrl,
                  decoration: InputDecoration(
                    labelText: 'Disetujui Oleh',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Waktu Kembali (Batas Waktu)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batas Waktu Kembali ke Asrama:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _fmtWaktu(tglKembali.toIso8601String()),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: tglKembali,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 1)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 30)),
                              );
                              if (d != null && ctx.mounted) {
                                final t = await showTimePicker(
                                  context: ctx,
                                  initialTime: TimeOfDay.fromDateTime(tglKembali),
                                );
                                if (t != null) {
                                  setDialogState(() {
                                    tglKembali = DateTime(
                                      d.year,
                                      d.month,
                                      d.day,
                                      t.hour,
                                      t.minute,
                                    );
                                  });
                                }
                              }
                            },
                            child: const Text('Ubah Jam'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (siswaTerpilihId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih santri/siswa terlebih dahulu!'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                try {
                  final pb = PbService().pb;
                  final prefix = jenisTerpilih.contains('IB') ||
                          jenisTerpilih.contains('Bermalam')
                      ? 'IB'
                      : 'TKT';
                  final tglKode = _formatKodeTgl(DateTime.now());
                  final noRandom =
                      (100 + DateTime.now().millisecond % 900).toString();
                  final noTiket = '$prefix-$tglKode-$noRandom';

                  final body = <String, dynamic>{
                    'nomor_tiket': noTiket,
                    'siswa': siswaTerpilihId,
                    'jenis': jenisTerpilih,
                    'keterangan': ketCtrl.text.trim(),
                    'penjemput': penjemputCtrl.text.trim(),
                    'penyetuju': penyetujuCtrl.text.trim(),
                    'waktu_keluar': _formatWaktuDb(tglKeluar),
                    'waktu_kembali': _formatWaktuDb(tglKembali),
                    'status': 'Menunggu Keluar',
                  };
                  if (PbService().me?.id != null) {
                    body['satpam_petugas'] = PbService().me!.id;
                  }

                  await pb.collection('izin_keluar').create(body: body);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Tiket #$noTiket berhasil diterbitkan!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                  _muatData(silent: true);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menerbitkan tiket.'),
                        backgroundColor: AppColors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Terbitkan Tiket'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeStatus(String status, bool telat) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = AppColors.ink;
    String label = status;

    if (telat || status == 'Terlambat') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Terlambat Kembali';
    } else if (status == 'Di Luar Kampus') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status == 'Sudah Kembali') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'Menunggu Keluar') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pos Keamanan & Gerbang',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => _muatData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.confirmation_number_outlined, size: 20),
              text: 'Tiket Gerbang (${_tiketList.length})',
            ),
            Tab(
              icon: const Icon(Icons.shield_outlined, size: 20),
              text: 'Izin Piket & Asrama (${_izinPiketList.length + _asramaList.length})',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaFormTiketBaru,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Buat Tiket Baru',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTabTiketGerbang(),
                _buildTabIzinPiketAsrama(),
              ],
            ),
    );
  }

  // TAB 1: Manajemen Tiket Gerbang
  Widget _buildTabTiketGerbang() {
    final list = _tiketTampil();

    return RefreshIndicator(
      onRefresh: _muatData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          // Stat Bar Gerbang
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Di Luar',
                  '$_countDiLuar',
                  const Color(0xFFD97706),
                  const Color(0xFFFEF3C7),
                  Icons.door_sliding_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'Menunggu',
                  '$_countMenunggu',
                  const Color(0xFF0284C7),
                  const Color(0xFFE0F2FE),
                  Icons.schedule_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'Terlambat',
                  '$_countTerlambat',
                  AppColors.red,
                  const Color(0xFFFEE2E2),
                  Icons.alarm_on_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'Kembali',
                  '$_countKembali',
                  AppColors.primary,
                  AppColors.primarySoft,
                  Icons.check_circle_outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search & Filter
          TextField(
            onChanged: (v) => setState(() => _cariQuery = v.trim()),
            decoration: InputDecoration(
              hintText: 'Cari tiket #IB / #TKT atau nama siswa...',
              prefixIcon: const Icon(Icons.search, color: AppColors.grey),
              filled: true,
              fillColor: const Color(0xFFF4F6F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          // Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'Semua',
                'Di Luar Kampus',
                'Menunggu Keluar',
                'Terlambat',
                'Sudah Kembali',
              ].map((st) {
                final aktif = _filterStatus == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st),
                    selected: aktif,
                    selectedColor: AppColors.primary,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                      color: aktif ? Colors.white : AppColors.ink,
                    ),
                    backgroundColor: const Color(0xFFF1F5F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: aktif ? AppColors.primaryDark : AppColors.line,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _filterStatus = st);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: const EmptyState(
                icon: Icons.confirmation_number_outlined,
                warna: AppColors.primary,
                warnaSoft: AppColors.primarySoft,
                judul: 'Tidak Ada Tiket Perizinan',
                subjudul:
                    'Belum ada siswa dengan perizinan keluar atau bermalam pada filter ini.',
              ),
            )
          else
            ...list.map((t) => _buildTiketCard(t)),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String nilai,
    Color fg,
    Color bg,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(height: 4),
          Text(
            nilai,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTiketCard(RecordModel t) {
    final noTiket = t.getStringValue('nomor_tiket');
    final namaSiswa = t.getStringValue('expand.siswa.nama');
    final namaKelas = t.getStringValue('expand.siswa.expand.kelas.nama');
    final jenis = t.getStringValue('jenis');
    final ket = t.getStringValue('keterangan');
    final penjemput = t.getStringValue('penjemput');
    final wKembali = _fmtWaktu(t.getStringValue('waktu_kembali'));
    final status = t.getStringValue('status');
    final telat = _apakahTerlambatOtomatis(t);
    final jKeluar = _fmtJamSaja(t.getStringValue('jam_keluar_aktual'));
    final jKembali = _fmtJamSaja(t.getStringValue('jam_kembali_aktual'));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: telat ? const Color(0xFFFECDD3) : AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _bukaDetailTiket(t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Tiket & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '#$noTiket',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _badgeStatus(status, telat),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  namaSiswa.isEmpty ? 'Siswa' : namaSiswa,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Kelas ${namaKelas.isNotEmpty ? namaKelas : "-"} • $jenis',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.grey,
                  ),
                ),
                if (ket.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Keperluan: $ket',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (penjemput.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Penjemput: $penjemput',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                ],
                const Divider(height: 16),
                // Waktu & Jam Aktual
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Batas Kembali:',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.grey,
                            ),
                          ),
                          Text(
                            wKembali,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: telat ? AppColors.red : AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (status != 'Menunggu Keluar')
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              status == 'Sudah Kembali'
                                  ? 'Kembali Aktual:'
                                  : 'Keluar Aktual:',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: AppColors.grey,
                              ),
                            ),
                            Text(
                              status == 'Sudah Kembali' ? jKembali : jKeluar,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Tombol Aksi Langsung
                if (status == 'Menunggu Keluar') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _tapKeluarGerbang(t),
                      icon: const Icon(Icons.sensor_door_outlined, size: 18),
                      label: const Text('Tap Keluar Gerbang'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (status == 'Di Luar Kampus' || telat) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _tapKembaliKampus(t),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text('Tap Siswa Kembali ke Kampus'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            telat ? AppColors.red : const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TAB 2: Perizinan Guru Piket & Laporan Asrama Hari Ini
  Widget _buildTabIzinPiketAsrama() {
    return RefreshIndicator(
      onRefresh: _muatData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.grey, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Perizinan aktif santri/siswa hari ini dari Guru Piket & Pengasuh Asrama.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'IZIN PIKET / KBM HARI INI (${_izinPiketList.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_izinPiketList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada catatan izin piket hari ini.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
            )
          else
            ..._izinPiketList.map((p) {
              final namaSiswa = p.getStringValue('expand.siswa.nama');
              final namaKelas =
                  p.getStringValue('expand.siswa.expand.kelas.nama');
              final ket = p.getStringValue('keterangan');
              final jam = _fmtJamSaja(p.getStringValue('created'));

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEDE9FE),
                    child: Icon(Icons.shield_outlined,
                        color: Color(0xFF8B5CF6), size: 20),
                  ),
                  title: Text(
                    namaSiswa.isEmpty ? 'Siswa' : namaSiswa,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Kelas ${namaKelas.isNotEmpty ? namaKelas : "-"} • $ket\nDicatat jam $jam',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            'LAPORAN ASRAMA HARI INI (${_asramaList.length})',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_asramaList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada laporan sakit atau izin asrama hari ini.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
            )
          else
            ..._asramaList.map((a) {
              final namaSiswa = a.getStringValue('expand.siswa.nama');
              final namaKelas =
                  a.getStringValue('expand.siswa.expand.kelas.nama');
              final jenis = a.getStringValue('jenis');
              final ket = a.getStringValue('keterangan');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFCCFBF1),
                    child: Icon(Icons.home_outlined,
                        color: Color(0xFF0D9488), size: 20),
                  ),
                  title: Text(
                    namaSiswa.isEmpty ? 'Siswa' : namaSiswa,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Kelas ${namaKelas.isNotEmpty ? namaKelas : "-"} • $jenis\n$ket',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  ),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }
}

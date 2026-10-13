import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'jurnal_form_screen.dart';

// Notifikasi: pengingat jam mengajar + pengumuman dari admin.
class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

int _menitMulaiJam(int jamKe) => 7 * 60 + (jamKe - 1) * 45;

String _fmtMenit(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<RecordModel> _pengumuman = [];
  List<RecordModel> _jadwalSaya = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final res = await pb
          .collection('pengumuman')
          .getList(page: 1, perPage: 50, sort: '-tanggal,-created');
      List<RecordModel> jadwalSaya = [];
      if (svc.isGuru || svc.isPiket) {
        final j = await pb
            .collection('jadwal')
            .getList(
              page: 1,
              perPage: 50,
              filter: 'hari = "${svc.hariIni()}" && guru = "${svc.me!.id}"',
              sort: 'jam_ke',
              expand: 'kelas',
            );
        jadwalSaya = j.items;
      }
      setState(() {
        _pengumuman = res.items;
        _jadwalSaya = jadwalSaya;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _statusJam(RecordModel j) {
    final now = DateTime.now();
    final menitNow = now.hour * 60 + now.minute;
    final mulai = _menitMulaiJam(j.getIntValue('jam_ke'));
    if (menitNow < mulai - 60) return 'nanti';
    if (menitNow < mulai) return 'segera';
    if (menitNow < mulai + 45) return 'berlangsung';
    return 'selesai';
  }

  String _fmtTanggal(String iso) {
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
      return '${d.day} ${bulan[d.month]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_jadwalSaya.isNotEmpty) ...[
                    Text(
                      'Jadwal Mengajar Hari Ini',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 10),
                    ..._jadwalSaya.asMap().entries.map((en) {
                      final j = en.value;
                      final status = _statusJam(j);
                      final namaKelas = j.getStringValue('expand.kelas.nama');
                      final jamKe = j.getIntValue('jam_ke');
                      final mulai = _menitMulaiJam(jamKe);
                      final warna = status == 'berlangsung'
                          ? AppColors.primary
                          : status == 'segera'
                          ? AppColors.amber
                          : AppColors.grey;
                      final label = status == 'berlangsung'
                          ? 'SEDANG BERLANGSUNG'
                          : status == 'segera'
                          ? 'SEGERA DIMULAI'
                          : status == 'selesai'
                          ? 'SELESAI'
                          : 'TERJADWAL';
                      return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: status == 'nanti' || status == 'selesai'
                                    ? AppColors.line
                                    : warna.withValues(alpha: 0.5),
                                width: status == 'nanti' || status == 'selesai'
                                    ? 1
                                    : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              color: status == 'berlangsung'
                                  ? AppColors.primarySoft.withValues(alpha: 0.4)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: warna.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$jamKe',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: warna,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kelas $namaKelas • ${j.getStringValue('mapel')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_fmtMenit(mulai)}–${_fmtMenit(mulai + 45)} • $label',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: warna,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (status == 'berlangsung' ||
                                    status == 'segera')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_note_outlined,
                                      color: AppColors.primary,
                                    ),
                                    tooltip: 'Isi jurnal',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const JurnalFormScreen(),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: en.key * 80))
                          .slideY(begin: 0.08, end: 0);
                    }),
                    const SizedBox(height: 20),
                  ],
                  Text(
                    'Pengumuman',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 10),
                  if (_pengumuman.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Belum ada pengumuman.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ..._pengumuman.asMap().entries.map((en) {
                    final n = en.value;
                    return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: AppColors.primarySoft,
                                child: Icon(
                                  Icons.campaign_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.getStringValue('judul'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.getStringValue('isi'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _fmtTanggal(n.getStringValue('tanggal')),
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: en.key * 60))
                        .slideY(begin: 0.06, end: 0);
                  }),
                ],
              ),
            ),
    );
  }
}

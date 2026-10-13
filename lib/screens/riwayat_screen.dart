import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

// Riwayat jurnal dari PocketBase + ringkasan absensi.
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<RecordModel> _data = [];
  final Map<String, Map<String, int>> _ringkasan = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final res = await pb
          .collection('jurnal')
          .getList(
            page: 1,
            perPage: 50,
            sort: '-tanggal,-created',
            expand: 'kelas,guru',
          );
      final ringkasan = <String, Map<String, int>>{};
      for (final j in res.items) {
        final abs = await pb
            .collection('absensi')
            .getList(page: 1, perPage: 200, filter: 'jurnal = "${j.id}"');
        final m = {'Hadir': 0, 'Sakit': 0, 'Izin': 0, 'Alpa': 0};
        for (final a in abs.items) {
          final s = a.getStringValue('status');
          m[s] = (m[s] ?? 0) + 1;
        }
        ringkasan[j.id] = m;
      }
      setState(() {
        _data = res.items;
        _ringkasan.addAll(ringkasan);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
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
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Jurnal')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: _data.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const EmptyState(
                            icon: Icons.access_time_outlined,
                            warna: AppColors.amber,
                            warnaSoft: AppColors.amberSoft,
                            judul: 'Belum ada jurnal',
                            subjudul: 'Jurnal yang sudah diisi akan tercatat di sini sebagai arsip mengajar.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _data.length,
                      itemBuilder: (_, i) {
                        final j = _data[i];
                        final namaKelas = j.getStringValue('expand.kelas.nama');
                        final r = _ringkasan[j.id];
                        final absensiTxt = r == null
                            ? ''
                            : 'H:${r['Hadir']} S:${r['Sakit']} I:${r['Izin']} A:${r['Alpa']}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _fmtTanggal(j.getStringValue('tanggal')),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      namaKelas,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                j.getStringValue('materi'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Jam ke-${j.getStringValue('jam')} • $absensiTxt',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                ),
                              ),
                              if (j.getStringValue('catatan').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Catatan: ${j.getStringValue('catatan')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

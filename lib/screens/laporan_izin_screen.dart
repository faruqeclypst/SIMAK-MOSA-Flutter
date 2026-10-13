import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

// Laporan Izin: agregasi izin piket + laporan asrama,
// dikelompokkan per kelas lalu per siswa.
class LaporanIzinScreen extends StatefulWidget {
  const LaporanIzinScreen({super.key});

  @override
  State<LaporanIzinScreen> createState() => _LaporanIzinScreenState();
}

class _IzinEntry {
  final String tanggal;
  final String sumber;
  final String status;
  _IzinEntry(this.tanggal, this.sumber, this.status);
}

class _SiswaIzin {
  final String nama;
  final String kelas;
  final List<_IzinEntry> riwayat = [];
  _SiswaIzin(this.nama, this.kelas);
}

class _LaporanIzinScreenState extends State<LaporanIzinScreen> {
  Map<String, List<_SiswaIzin>> _perKelas = {};
  bool _loading = true;
  String _filterKelas = 'Semua';

  static const _avatarWarna = [
    (Color(0xFF00AA13), Color(0xFFE8F8EA)),
    (Color(0xFF2563EB), Color(0xFFDBEAFE)),
    (Color(0xFF8B5CF6), Color(0xFFEDE9FE)),
    (Color(0xFFD97706), Color(0xFFFEF3C7)),
    (Color(0xFF0D9488), Color(0xFFCCFBF1)),
    (Color(0xFFDC2626), Color(0xFFFEE2E2)),
  ];

  @override
  void initState() {
    super.initState();
    _muat();
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
      return '${d.day} ${bulan[d.month]}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final siswaMap = <String, _SiswaIzin>{};

      void catat(
        String? siswaId,
        String nama,
        String tgl,
        String sumber,
        String status,
      ) {
        if (siswaId == null || siswaId.isEmpty) return;
        final s = siswaMap.putIfAbsent(
          siswaId,
          () => _SiswaIzin(nama.isEmpty ? '-' : nama, ''),
        );
        s.riwayat.add(_IzinEntry(_fmtTanggal(tgl), sumber, status));
      }

      final piket = await pb
          .collection('izin_piket')
          .getList(page: 1, perPage: 500, sort: '-tanggal', expand: 'siswa');
      for (final p in piket.items) {
        catat(
          p.getStringValue('siswa'),
          p.getStringValue('expand.siswa.nama'),
          p.getStringValue('tanggal'),
          'Guru Piket',
          p.getStringValue('keterangan'),
        );
      }

      final asrama = await pb
          .collection('asrama')
          .getList(page: 1, perPage: 500, sort: '-tanggal', expand: 'siswa');
      for (final a in asrama.items) {
        final ket = a.getStringValue('keterangan');
        catat(
          a.getStringValue('siswa'),
          a.getStringValue('expand.siswa.nama'),
          a.getStringValue('tanggal'),
          'Asrama',
          '${a.getStringValue('jenis')}${ket.isNotEmpty ? ': $ket' : ''}',
        );
      }

      final perKelas = <String, List<_SiswaIzin>>{};
      if (siswaMap.isNotEmpty) {
        final ids = siswaMap.keys.map((id) => 'id = "$id"').join(' || ');
        final sw = await pb
            .collection('siswa')
            .getList(page: 1, perPage: 500, filter: ids, expand: 'kelas');
        for (final s in sw.items) {
          final entry = siswaMap[s.id];
          if (entry != null) {
            final namaKelas = s.getStringValue('expand.kelas.nama');
            final key = namaKelas.isEmpty ? 'Lainnya' : namaKelas;
            perKelas
                .putIfAbsent(key, () => [])
                .add(
                  _SiswaIzin(entry.nama, key)..riwayat.addAll(entry.riwayat),
                );
          }
        }
      }

      final sorted = Map.fromEntries(
        perKelas.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      for (final list in sorted.values) {
        list.sort((a, b) => b.riwayat.length.compareTo(a.riwayat.length));
      }

      setState(() {
        _perKelas = sorted;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  (Color, Color) _warnaAvatar(String nama) {
    final i = nama.hashCode.abs() % _avatarWarna.length;
    return _avatarWarna[i];
  }

  String _inisial(String nama) {
    final p = nama.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.first.toUpperCase();
    return (p.first.characters.first + p[1].characters.first).toUpperCase();
  }

  Color _warnaSumber(String sumber) {
    return sumber == 'Asrama'
        ? const Color(0xFF0D9488)
        : const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final daftarKelas = ['Semua', ..._perKelas.keys];
    final tampil = _filterKelas == 'Semua'
        ? _perKelas
        : {_filterKelas: _perKelas[_filterKelas] ?? []};
    final totalSiswa = tampil.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final totalCatatan = tampil.values.fold<int>(
      0,
      (sum, list) => sum + list.fold(0, (s, x) => s + x.riwayat.length),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Izin')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Kartu ringkasan gradien ala home
                  Container(
                        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF065F46), Color(0xFF00AA13)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 16,
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
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.fact_check_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Izin Siswa',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        'Akumulasi izin piket & asrama',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatBox(
                                    angka: '$totalSiswa',
                                    label: 'Siswa tercatat',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatBox(
                                    angka: '$totalCatatan',
                                    label: 'Total catatan',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0),

                  // Filter kelas: chips horizontal
                  if (daftarKelas.length > 1) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: daftarKelas.length,
                        itemBuilder: (_, i) {
                          final k = daftarKelas[i];
                          final aktif = _filterKelas == k;
                          return GestureDetector(
                            onTap: () => setState(() => _filterKelas = k),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: aktif ? AppColors.primary : Colors.white,
                                border: Border.all(
                                  color: aktif
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: aktif
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                k == 'Semua' ? 'Semua' : k,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: aktif ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  if (tampil.isEmpty)
                    const SizedBox(
                      height: 380,
                      child: EmptyState(
                        icon: Icons.fact_check_outlined,
                        warna: AppColors.primary,
                        warnaSoft: AppColors.primarySoft,
                        judul: 'Belum ada data izin',
                        subjudul: 'Data izin dari guru piket dan asrama akan terkumpul di sini secara otomatis.',
                      ),
                    ),

                  ...tampil.entries.map((e) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                          child: Row(
                            children: [
                              Text(
                                'Kelas ${e.key}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${e.value.length} siswa',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...e.value.asMap().entries.map((en) {
                          final s = en.value;
                          final (wc, ws) = _warnaAvatar(s.nama);
                          return Container(
                                margin: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  10,
                                ),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.line),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: ws,
                                          child: Text(
                                            _inisial(s.nama),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              color: wc,
                                              fontSize: 15,
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
                                                s.nama,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                              ),
                                              Text(
                                                'Kelas ${s.kelas}',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: AppColors.grey,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.amberSoft,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            '${s.riwayat.length}x',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    ...s.riwayat.take(5).map((r) {
                                      final w = _warnaSumber(r.sumber);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 5,
                                              ),
                                              width: 9,
                                              height: 9,
                                              decoration: BoxDecoration(
                                                color: w,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        r.tanggal,
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  AppColors.ink,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: w.withValues(
                                                            alpha: 0.12,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          r.sumber,
                                                          style:
                                                              GoogleFonts.plusJakartaSans(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: w,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (r.status.isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 2,
                                                          ),
                                                      child: Text(
                                                        r.status,
                                                        style:
                                                            GoogleFonts.plusJakartaSans(
                                                              fontSize: 13,
                                                              color: AppColors
                                                                  .grey,
                                                              height: 1.4,
                                                            ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    if (s.riwayat.length > 5)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '+${s.riwayat.length - 5} catatan lainnya',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: en.key * 60),
                              )
                              .slideY(begin: 0.06, end: 0);
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String angka;
  final String label;
  const _StatBox({required this.angka, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            angka,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

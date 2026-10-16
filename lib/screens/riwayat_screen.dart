import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'jurnal_form_screen.dart';

// Riwayat jurnal dari PocketBase + ringkasan absensi interaktif dengan Detail View.
class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<RecordModel> _data = [];
  final Map<String, Map<String, int>> _ringkasan = {};
  bool _loading = true;
  String _filterQuery = '';

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
      if (mounted) {
        setState(() {
          _data = res.items;
          _ringkasan.addAll(ringkasan);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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

  void _bukaDetailJurnal(RecordModel j, Map<String, int>? r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailJurnalSheet(
        jurnal: j,
        ringkasan: r,
        onJurnalDeleted: () => _muat(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listTampil = _data.where((j) {
      if (_filterQuery.isEmpty) return true;
      final kelas = j.getStringValue('expand.kelas.nama').toLowerCase();
      final materi = j.getStringValue('materi').toLowerCase();
      final mapel = j.getStringValue('mapel').toLowerCase();
      final q = _filterQuery.toLowerCase();
      return kelas.contains(q) || materi.contains(q) || mapel.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Jurnal Mengajar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      onChanged: (v) => setState(() => _filterQuery = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Cari riwayat kelas atau materi...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                        filled: true,
                        fillColor: const Color(0xFFF4F6F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: listTampil.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: const EmptyState(
                                  icon: Icons.access_time_outlined,
                                  warna: AppColors.amber,
                                  warnaSoft: AppColors.amberSoft,
                                  judul: 'Belum ada riwayat jurnal',
                                  subjudul:
                                      'Jurnal yang sudah diisi akan tercatat di sini dan dapat ditinjau kapan saja.',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: listTampil.length,
                            itemBuilder: (_, i) {
                              final j = listTampil[i];
                              final namaKelas =
                                  j.getStringValue('expand.kelas.nama');
                              final namaGuru =
                                  j.getStringValue('expand.guru.nama_lengkap');
                              final r = _ringkasan[j.id];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.line),
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
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _bukaDetailJurnal(j, r),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.calendar_today_outlined,
                                                    size: 14,
                                                    color: AppColors.grey,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _fmtTanggal(
                                                      j.getStringValue('tanggal'),
                                                    ),
                                                    style: GoogleFonts.plusJakartaSans(
                                                      color: AppColors.grey,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (j.getStringValue('mapel').isNotEmpty) ...[
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEFF6FF),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                          color: const Color(0xFFBFDBFE),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        j.getStringValue('mapel'),
                                                        style: GoogleFonts.plusJakartaSans(
                                                          color: const Color(0xFF1D4ED8),
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primarySoft,
                                                      borderRadius:
                                                          BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      'Kelas $namaKelas',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: AppColors.primaryDark,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            j.getStringValue('materi'),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Guru: ${namaGuru.isNotEmpty ? namaGuru : "Guru"} • Jam ke-${j.getStringValue('jam')}',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              color: AppColors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _badgeAbsensiMini(
                                                'H: ${r?['Hadir'] ?? 0}',
                                                AppColors.primary,
                                                AppColors.primarySoft,
                                              ),
                                              const SizedBox(width: 6),
                                              _badgeAbsensiMini(
                                                'S: ${r?['Sakit'] ?? 0}',
                                                AppColors.amber,
                                                AppColors.amberSoft,
                                              ),
                                              const SizedBox(width: 6),
                                              _badgeAbsensiMini(
                                                'I: ${r?['Izin'] ?? 0}',
                                                AppColors.blue,
                                                AppColors.blueSoft,
                                              ),
                                              const SizedBox(width: 6),
                                              _badgeAbsensiMini(
                                                'A: ${r?['Alpa'] ?? 0}',
                                                AppColors.red,
                                                AppColors.redSoft,
                                              ),
                                              const Spacer(),
                                              const Icon(
                                                Icons.chevron_right,
                                                color: AppColors.grey,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _badgeAbsensiMini(String text, Color textCol, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textCol,
        ),
      ),
    );
  }
}

// ==========================================
// BOTTOM SHEET DETAIL JURNAL LENGKAP
// ==========================================
class _DetailJurnalSheet extends StatefulWidget {
  final RecordModel jurnal;
  final Map<String, int>? ringkasan;
  final VoidCallback onJurnalDeleted;

  const _DetailJurnalSheet({
    required this.jurnal,
    required this.ringkasan,
    required this.onJurnalDeleted,
  });

  @override
  State<_DetailJurnalSheet> createState() => _DetailJurnalSheetState();
}

class _DetailJurnalSheetState extends State<_DetailJurnalSheet> {
  List<RecordModel> _absensiList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muatAbsensi();
  }

  Future<void> _muatAbsensi() async {
    try {
      final pb = PbService().pb;
      final res = await pb.collection('absensi').getList(
            page: 1,
            perPage: 100,
            filter: 'jurnal = "${widget.jurnal.id}"',
            expand: 'siswa',
            sort: 'status,siswa.nama',
          );
      if (mounted) {
        setState(() {
          _absensiList = res.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _hapusJurnal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Jurnal'),
        content: const Text(
          'Yakin ingin menghapus jurnal ini beserta seluruh data absensinya?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final pb = PbService().pb;
        // Hapus absensi terkait terlebih dahulu
        for (final a in _absensiList) {
          try {
            await pb.collection('absensi').delete(a.id);
          } catch (_) {}
        }
        await pb.collection('jurnal').delete(widget.jurnal.id);
        if (mounted) {
          Navigator.pop(context); // tutup sheet
          widget.onJurnalDeleted();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menghapus jurnal.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jurnal;
    final namaKelas = j.getStringValue('expand.kelas.nama');
    final namaGuru = j.getStringValue('expand.guru.nama_lengkap');
    final materi = j.getStringValue('materi');
    final catatan = j.getStringValue('catatan');
    final jam = j.getStringValue('jam');
    final svc = PbService();
    final canKelola = svc.isAdmin || (svc.me != null && j.getStringValue('guru') == svc.me!.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jurnal Kelas $namaKelas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            '${widget.jurnal.getStringValue('mapel').isNotEmpty ? "${widget.jurnal.getStringValue('mapel')} • " : ""}Jam ke-$jam • Guru: ${namaGuru.isNotEmpty ? namaGuru : "Guru"}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canKelola)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.red),
                        tooltip: 'Hapus Jurnal',
                        onPressed: _hapusJurnal,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scroll,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Materi & Catatan
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Materi Pembelajaran',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  materi,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                if (catatan.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Catatan Guru: $catatan',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.ink,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Statistik Kehadiran Siswa
                          Row(
                            children: [
                              _statChip('Hadir', '${widget.ringkasan?['Hadir'] ?? 0}', AppColors.primary, AppColors.primarySoft),
                              const SizedBox(width: 8),
                              _statChip('Sakit', '${widget.ringkasan?['Sakit'] ?? 0}', AppColors.amber, AppColors.amberSoft),
                              const SizedBox(width: 8),
                              _statChip('Izin', '${widget.ringkasan?['Izin'] ?? 0}', AppColors.blue, AppColors.blueSoft),
                              const SizedBox(width: 8),
                              _statChip('Alpa', '${widget.ringkasan?['Alpa'] ?? 0}', AppColors.red, AppColors.redSoft),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daftar Absensi Siswa (${_absensiList.length})',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (canKelola)
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JurnalFormScreen(
                                          kelasIdAwal: j.getStringValue('kelas'),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_note_outlined, size: 18),
                                  label: const Text('Edit Jurnal'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          ..._absensiList.map((a) {
                            final namaSiswa =
                                a.getStringValue('expand.siswa.nama');
                            final status = a.getStringValue('status');
                            final ket = a.getStringValue('keterangan');

                            Color badgeText = AppColors.primary;
                            Color badgeBg = AppColors.primarySoft;
                            if (status == 'Sakit') {
                              badgeText = AppColors.amber;
                              badgeBg = AppColors.amberSoft;
                            } else if (status == 'Izin') {
                              badgeText = AppColors.blue;
                              badgeBg = AppColors.blueSoft;
                            } else if (status == 'Alpa') {
                              badgeText = AppColors.red;
                              badgeBg = AppColors.redSoft;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'Hadir'
                                    ? const Color(0xFFF9FAFB)
                                    : badgeBg.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaSiswa.isNotEmpty
                                              ? namaSiswa
                                              : 'Siswa',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (ket.isNotEmpty)
                                          Text(
                                            ket,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: badgeText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statChip(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

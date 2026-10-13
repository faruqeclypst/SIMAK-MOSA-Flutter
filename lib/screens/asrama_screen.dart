import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

// Laporan Asrama: catat siswa tidak berangkat + rekap hari ini.
class AsramaScreen extends StatefulWidget {
  const AsramaScreen({super.key});

  @override
  State<AsramaScreen> createState() => _AsramaScreenState();
}

class _AsramaScreenState extends State<AsramaScreen> {
  List<RecordModel> _rekap = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final tgl = PbService().tanggalHariIni();
      final res = await PbService().pb
          .collection('asrama')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            sort: '-created',
            expand: 'siswa,pelapor',
          );
      setState(() {
        _rekap = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _hapus(String id, String nama) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Laporan'),
        content: Text('Hapus laporan "$nama"?'),
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
        await PbService().pb.collection('asrama').delete(id);
        _muat();
      } catch (_) {}
    }
  }

  Color _warnaJenis(String jenis) {
    switch (jenis) {
      case 'Sakit':
        return AppColors.amber;
      case 'Izin Pulang':
      case 'Izin Keluarga':
        return AppColors.blue;
      case 'Tanpa Keterangan':
        return AppColors.red;
      default:
        return AppColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTulis = PbService().canKelolaAsrama;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan Asrama')),
      floatingActionButton: canTulis
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _FormAsrama()),
                );
                _muat();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Catat',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: _rekap.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: const EmptyState(
                            icon: Icons.home_outlined,
                            warna: Color(0xFF0D9488),
                            warnaSoft: Color(0xFFCCFBF1),
                            judul: 'Semua siswa/i berangkat 🎉',
                            subjudul: 'Belum ada laporan asrama hari ini. Kalau ada siswa/i yang tidak berangkat, catat lewat tombol di bawah.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _rekap.length,
                      itemBuilder: (_, i) {
                        final r = _rekap[i];
                        final namaSiswa = r.getStringValue('expand.siswa.nama');
                        final jenis = r.getStringValue('jenis');
                        return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCCFBF1),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.bed_outlined,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          namaSiswa.isEmpty ? '-' : namaSiswa,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _warnaJenis(jenis)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            jenis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _warnaJenis(jenis),
                                            ),
                                          ),
                                        ),
                                        if (r
                                            .getStringValue('keterangan')
                                            .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              r.getStringValue('keterangan'),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    color: AppColors.grey,
                                                    fontSize: 13,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (canTulis)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.red,
                                        size: 20,
                                      ),
                                      onPressed: () => _hapus(
                                        r.id,
                                        namaSiswa.isEmpty ? '-' : namaSiswa,
                                      ),
                                    ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: i * 60))
                            .slideX(begin: 0.08, end: 0);
                      },
                    ),
            ),
    );
  }
}

class _FormAsrama extends StatefulWidget {
  const _FormAsrama();

  @override
  State<_FormAsrama> createState() => _FormAsramaState();
}

class _FormAsramaState extends State<_FormAsrama> {
  static const _jenisList = [
    'Sakit',
    'Izin Pulang',
    'Izin Keluarga',
    'Tanpa Keterangan',
    'Lainnya',
  ];

  List<RecordModel> _kelas = [];
  List<RecordModel> _siswa = [];
  String? _kelasId;
  String? _siswaId;
  String _jenis = 'Sakit';
  final _ketCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ketCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final k = await PbService().pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      setState(() {
        _kelas = k.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _muatSiswa(String kelasId) async {
    setState(() => _loading = true);
    try {
      final s = await PbService().pb
          .collection('siswa')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'kelas = "$kelasId"',
            sort: 'nama',
          );
      setState(() {
        _siswa = s.items;
        _siswaId = null;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _simpan() async {
    if (_siswaId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pilih siswa dulu.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      await svc.pb
          .collection('asrama')
          .create(
            body: {
              'tanggal': '${svc.tanggalHariIni()} 12:00:00',
              'siswa': _siswaId,
              'jenis': _jenis,
              'keterangan': _ketCtrl.text.trim(),
              'pelapor': svc.me!.id,
            },
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan asrama tersimpan.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Tidak Berangkat')),
      body: _loading && _kelas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Kelas',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _kelasId,
                  hint: const Text('Pilih kelas'),
                  items: _kelas
                      .map(
                        (k) => DropdownMenuItem(
                          value: k.id,
                          child: Text(k.getStringValue('nama')),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _kelasId = v);
                    if (v != null) _muatSiswa(v);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Siswa/i',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _siswaId,
                  hint: Text(
                    _kelasId == null ? 'Pilih kelas dulu' : 'Pilih siswa/i',
                  ),
                  items: _siswa
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.getStringValue('nama'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _siswaId = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _jenisList.map((j) {
                    final aktif = _jenis == j;
                    return ChoiceChip(
                      label: Text(j),
                      selected: aktif,
                      selectedColor: AppColors.primary,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: aktif ? Colors.white : AppColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      onSelected: (_) => setState(() => _jenis = j),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keterangan Tambahan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ketCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'mis. Demam, istirahat di barak',
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
                      : const Text('Simpan'),
                ),
              ],
            ),
    );
  }
}

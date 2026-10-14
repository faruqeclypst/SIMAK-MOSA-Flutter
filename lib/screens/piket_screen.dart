import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

// Jurnal Piket: catat siswa izin + rekap hari ini.
class PiketScreen extends StatefulWidget {
  const PiketScreen({super.key});

  @override
  State<PiketScreen> createState() => _PiketScreenState();
}

class _PiketScreenState extends State<PiketScreen> {
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
          .collection('izin_piket')
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
        title: const Text('Hapus Catatan'),
        content: Text('Hapus catatan izin "$nama"?'),
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
        await PbService().pb.collection('izin_piket').delete(id);
        _muat();
      } catch (_) {}
    }
  }

  Future<void> _bukaForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _FormIzinPiket()),
    );
    _muat();
  }

  @override
  Widget build(BuildContext context) {
    final canTulis = PbService().canKelolaPiket;
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal Piket')),
      floatingActionButton: canTulis
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _bukaForm,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Catat Izin',
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
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: EmptyState(
                            icon: Icons.shield_outlined,
                            warna: const Color(0xFF8B5CF6),
                            warnaSoft: const Color(0xFFEDE9FE),
                            judul: 'Piket aman hari ini',
                            subjudul: 'Belum ada siswa izin yang tercatat. Tetap waspada ya!',
                            aksiLabel: canTulis ? 'Catat Izin' : null,
                            onAksi: canTulis ? _bukaForm : null,
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
                        final pelapor = r.getStringValue(
                          'expand.pelapor.nama_lengkap',
                        );
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
                                      color: const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF8B5CF6),
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
                                        const SizedBox(height: 3),
                                        Text(
                                          '${r.getStringValue('keterangan')}${r.getStringValue('jam').isNotEmpty ? ' • Jam ${r.getStringValue('jam')}' : ''}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (pelapor.isNotEmpty)
                                          Text(
                                            'Dicatat: $pelapor',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: AppColors.grey,
                                              fontSize: 12,
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

class _FormIzinPiket extends StatefulWidget {
  const _FormIzinPiket();

  @override
  State<_FormIzinPiket> createState() => _FormIzinPiketState();
}

class _FormIzinPiketState extends State<_FormIzinPiket> {
  List<RecordModel> _kelas = [];
  List<RecordModel> _siswa = [];
  String? _kelasId;
  String? _siswaId;
  final _jamCtrl = TextEditingController();
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
    _jamCtrl.dispose();
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
    if (_siswaId == null || _ketCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih siswa dan isi keterangan izin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      await svc.pb
          .collection('izin_piket')
          .create(
            body: {
              'tanggal': '${svc.tanggalHariIni()} 12:00:00',
              'siswa': _siswaId,
              'jam': _jamCtrl.text.trim(),
              'keterangan': _ketCtrl.text.trim(),
              'pelapor': svc.me!.id,
            },
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Catatan izin tersimpan.')));
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
      appBar: AppBar(title: const Text('Catat Siswa Izin')),
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
                  key: ValueKey(_kelasId),
                  initialValue: _kelas.any((k) => k.id == _kelasId) ? _kelasId : null,
                  isExpanded: true,
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
                  'Siswa',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(_siswaId),
                  initialValue: _siswa.any((s) => s.id == _siswaId) ? _siswaId : null,
                  isExpanded: true,
                  hint: Text(
                    _kelasId == null ? 'Pilih kelas dulu' : 'Pilih siswa',
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
                  'Jam Pelajaran (opsional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _jamCtrl,
                  decoration: const InputDecoration(hintText: 'mis. 2,3'),
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                Text(
                  'Keterangan Izin',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ketCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'mis. Izin ke UKS, sakit perut',
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

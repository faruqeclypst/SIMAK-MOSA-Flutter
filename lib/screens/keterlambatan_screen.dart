import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

// Keterlambatan: dicatat Satpam (PKD) di gerbang + rekap hari ini.
class KeterlambatanScreen extends StatefulWidget {
  const KeterlambatanScreen({super.key});

  @override
  State<KeterlambatanScreen> createState() => _KeterlambatanScreenState();
}

class _KeterlambatanScreenState extends State<KeterlambatanScreen> {
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
          .collection('keterlambatan')
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
        content: Text('Hapus catatan keterlambatan "$nama"?'),
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
        await PbService().pb.collection('keterlambatan').delete(id);
        _muat();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTulis = PbService().canKelolaKeterlambatan;
    return Scaffold(
      appBar: AppBar(title: const Text('Keterlambatan')),
      floatingActionButton: canTulis
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const _FormTerlambat()),
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
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppColors.amber,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_rekap.length} siswa terlambat',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                'Hari ini • Gerbang utama',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _rekap.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: const EmptyState(
                                  icon: Icons.timer_outlined,
                                  warna: AppColors.amber,
                                  warnaSoft: AppColors.amberSoft,
                                  judul: 'Nihil keterlambatan 🎉',
                                  subjudul: 'Semua siswa datang tepat waktu hari ini. Pertahankan!',
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _rekap.length,
                            itemBuilder: (_, i) {
                              final r = _rekap[i];
                              final nama = r.getStringValue(
                                'expand.siswa.nama',
                              );
                              final jam = r.getStringValue('jam_datang');
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
                                            color: AppColors.amberSoft,
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.schedule_outlined,
                                            color: AppColors.amber,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nama.isEmpty ? '-' : nama,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                    ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                'Datang ${jam.isEmpty ? "-" : jam}'
                                                '${r.getStringValue('keterangan').isNotEmpty ? ' • ${r.getStringValue('keterangan')}' : ''}',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      color: AppColors.grey,
                                                      fontSize: 13,
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
                                              nama.isEmpty ? '-' : nama,
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
                ],
              ),
            ),
    );
  }
}

class _FormTerlambat extends StatefulWidget {
  const _FormTerlambat();

  @override
  State<_FormTerlambat> createState() => _FormTerlambatState();
}

class _FormTerlambatState extends State<_FormTerlambat> {
  List<RecordModel> _kelas = [];
  List<RecordModel> _siswa = [];
  String? _kelasId;
  String? _siswaId;
  TimeOfDay _jam = TimeOfDay.now();
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
      final jamStr =
          '${_jam.hour.toString().padLeft(2, '0')}:${_jam.minute.toString().padLeft(2, '0')}';
      await svc.pb
          .collection('keterlambatan')
          .create(
            body: {
              'tanggal': '${svc.tanggalHariIni()} 12:00:00',
              'siswa': _siswaId,
              'jam_datang': jamStr,
              'keterangan': _ketCtrl.text.trim(),
              'pelapor': svc.me!.id,
            },
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Catatan tersimpan.')));
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
      appBar: AppBar(title: const Text('Catat Keterlambatan')),
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
                  'Jam Datang',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _jam,
                    );
                    if (t != null) setState(() => _jam = t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.greyLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_outlined,
                          color: AppColors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_jam.hour.toString().padLeft(2, '0')}:${_jam.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Keterangan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ketCtrl,
                  decoration: const InputDecoration(
                    hintText: 'mis. Ban bocor, kesiangan',
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

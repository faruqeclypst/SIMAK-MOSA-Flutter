import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';

// Guru Berhalangan: catat guru yang tidak bisa mengajar hari ini
// agar piket/kurikulum bisa menyiapkan pengganti.
class GuruBerhalanganScreen extends StatefulWidget {
  const GuruBerhalanganScreen({super.key});

  @override
  State<GuruBerhalanganScreen> createState() => _GuruBerhalanganScreenState();
}

class _GuruBerhalanganScreenState extends State<GuruBerhalanganScreen> {
  List<RecordModel> _data = [];
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
          .collection('guru_berhalangan')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal ~ "$tgl"',
            sort: '-created',
            expand: 'guru,guru_pengganti',
          );
      setState(() {
        _data = res.items;
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
        content: Text('Hapus catatan berhalangan "$nama"?'),
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
        await PbService().pb.collection('guru_berhalangan').delete(id);
        _muat();
      } catch (_) {}
    }
  }

  Color _warnaStatus(String s) {
    switch (s) {
      case 'Sakit':
        return AppColors.red;
      case 'Izin':
        return const Color(0xFF92400E);
      case 'Dinas Luar':
        return AppColors.primary;
      default:
        return AppColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTulis = PbService().canKelolaBerhalangan;
    return Scaffold(
      appBar: AppBar(title: const Text('Guru Berhalangan')),
      floatingActionButton: canTulis
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FormBerhalangan(),
                  ),
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
              child: _data.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        Icon(
                          Icons.event_available_outlined,
                          size: 64,
                          color: AppColors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Semua guru hadir hari ini. Alhamdulillah.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      itemBuilder: (_, i) {
                        final r = _data[i];
                        var nama = r.getStringValue('expand.guru.nama_lengkap');
                        if (nama.isEmpty) {
                          nama = r.getStringValue('expand.guru.email');
                        }
                        var pengganti = r.getStringValue(
                          'expand.guru_pengganti.nama_lengkap',
                        );
                        if (pengganti.isEmpty) {
                          pengganti = r.getStringValue(
                            'expand.guru_pengganti.email',
                          );
                        }
                        final link = r.getStringValue('link_tugas');
                        final status = r.getStringValue('status');
                        return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.person_off_outlined,
                                      color: Color(0xFF92400E),
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
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${r.getStringValue('jam').isNotEmpty ? 'Jam ${r.getStringValue('jam')} • ' : ''}${r.getStringValue('keterangan')}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: AppColors.grey,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (pengganti.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.swap_horiz,
                                                size: 14,
                                                color: AppColors.primary,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Diganti: $pengganti',
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .primaryDark,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (link.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          GestureDetector(
                                            onTap: () => launchUrl(
                                              Uri.parse(
                                                link.startsWith('http')
                                                    ? link
                                                    : 'https://$link',
                                              ),
                                              mode: LaunchMode
                                                  .externalApplication,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.link_outlined,
                                                  size: 14,
                                                  color: AppColors.blue,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Buka tugas',
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              AppColors.blue,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _warnaStatus(status)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status.isEmpty ? '-' : status,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: _warnaStatus(status),
                                      ),
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
    );
  }
}

// Form catat/ubah guru berhalangan + guru pengganti (wajib) + link tugas.
// Dibuat publik agar bisa dipakai dari Matriks Piket.
class FormBerhalangan extends StatefulWidget {
  final String? guruIdAwal;
  final RecordModel? existing;
  const FormBerhalangan({super.key, this.guruIdAwal, this.existing});

  @override
  State<FormBerhalangan> createState() => _FormBerhalanganState();
}

class _FormBerhalanganState extends State<FormBerhalangan> {
  List<RecordModel> _guru = [];
  String? _guruId;
  String? _penggantiId;
  final _jamCtrl = TextEditingController();
  final _ketCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  String _status = 'Sakit';
  bool _loading = true;
  bool _saving = false;
  static const _daftarStatus = ['Sakit', 'Izin', 'Dinas Luar', 'Tanpa Kabar'];

  @override
  void initState() {
    super.initState();
    _guruId = widget.guruIdAwal ?? widget.existing?.getStringValue('guru');
    _init();
  }

  @override
  void dispose() {
    _jamCtrl.dispose();
    _ketCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  String _namaGuru(RecordModel u) {
    final n = u.getStringValue('nama_lengkap');
    return n.isEmpty ? u.getStringValue('email') : n;
  }

  Future<void> _init() async {
    try {
      final res = await PbService().pb
          .collection('users')
          .getList(page: 1, perPage: 300, sort: 'nama_lengkap');
      final ex = widget.existing;
      setState(() {
        _guru = res.items;
        if (ex != null) {
          _status = ex.getStringValue('status').isEmpty
              ? 'Sakit'
              : ex.getStringValue('status');
          _jamCtrl.text = ex.getStringValue('jam');
          _ketCtrl.text = ex.getStringValue('keterangan');
          _linkCtrl.text = ex.getStringValue('link_tugas');
          final pg = ex.getStringValue('guru_pengganti');
          if (pg.isNotEmpty) _penggantiId = pg;
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  bool _linkValid(String s) {
    if (s.isEmpty) return true;
    final t = s.startsWith('http') ? s : 'https://$s';
    final u = Uri.tryParse(t);
    return u != null && u.host.contains('.');
  }

  Future<void> _simpan() async {
    if (_guruId == null || _penggantiId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih guru yang berhalangan dan guru penggantinya.'),
        ),
      );
      return;
    }
    if (_guruId == _penggantiId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guru pengganti harus orang yang berbeda.'),
        ),
      );
      return;
    }
    if (_ketCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi keterangan.')),
      );
      return;
    }
    final link = _linkCtrl.text.trim();
    if (!_linkValid(link)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link tugas tidak valid.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      final body = {
        'guru': _guruId,
        'guru_pengganti': _penggantiId,
        'link_tugas': link,
        'jam': _jamCtrl.text.trim(),
        'keterangan': _ketCtrl.text.trim(),
        'status': _status,
      };
      final ex = widget.existing;
      if (ex != null) {
        await svc.pb.collection('guru_berhalangan').update(ex.id, body: body);
      } else {
        await svc.pb
            .collection('guru_berhalangan')
            .create(
              body: {
                ...body,
                'tanggal': '${svc.tanggalHariIni()} 07:00:00',
              },
            );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ex != null ? 'Catatan diperbarui.' : 'Catatan tersimpan.'),
        ),
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
    final isEdit = widget.existing != null;
    final calonPengganti = _guru.where((u) => u.id != _guruId).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Ubah Catatan Berhalangan' : 'Catat Guru Berhalangan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Guru yang berhalangan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _guruId,
                  hint: const Text('Pilih guru'),
                  isExpanded: true,
                  items: _guru
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            _namaGuru(u),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _guruId = v;
                    if (_penggantiId == v) _penggantiId = null;
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Guru Pengganti',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Wajib',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _penggantiId,
                  hint: const Text('Pilih guru pengganti'),
                  isExpanded: true,
                  items: calonPengganti
                      .map(
                        (u) => DropdownMenuItem(
                          value: u.id,
                          child: Text(
                            _namaGuru(u),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _penggantiId = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: _daftarStatus
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v ?? 'Sakit'),
                ),
                const SizedBox(height: 16),
                Text(
                  'Jam Mengajar (opsional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _jamCtrl,
                  decoration: const InputDecoration(hintText: 'mis. 1-3'),
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
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'mis. Sakit demam, ada surat dokter',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Link Tugas / Dokumen (opsional)',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'mis. docs.google.com/... atau drive link',
                    prefixIcon: Icon(Icons.link_outlined),
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

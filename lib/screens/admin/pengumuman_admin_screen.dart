import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';

// Kelola Pengumuman (admin): tambah, edit, hapus.
// Tampil untuk semua user di tab Notifikasi.
class PengumumanAdminScreen extends StatefulWidget {
  const PengumumanAdminScreen({super.key});

  @override
  State<PengumumanAdminScreen> createState() => _PengumumanAdminScreenState();
}

class _PengumumanAdminScreenState extends State<PengumumanAdminScreen> {
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
      final res = await PbService().pb
          .collection('pengumuman')
          .getList(page: 1, perPage: 100, sort: '-tanggal,-created');
      setState(() {
        _data = res.items;
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
      return '';
    }
  }

  Future<void> _form({RecordModel? rec}) async {
    final judul = TextEditingController(
      text: rec?.getStringValue('judul') ?? '',
    );
    final isi = TextEditingController(text: rec?.getStringValue('isi') ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(rec == null ? 'Tambah Pengumuman' : 'Edit Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: judul,
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: isi,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Isi pengumuman'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      if (judul.text.trim().isEmpty || isi.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Judul dan isi wajib diisi.')),
        );
        return;
      }
      try {
        final svc = PbService();
        final body = {
          'judul': judul.text.trim(),
          'isi': isi.text.trim(),
          'tanggal': '${svc.tanggalHariIni()} 07:00:00',
        };
        if (rec == null) {
          await svc.pb.collection('pengumuman').create(body: body);
        } else {
          await svc.pb.collection('pengumuman').update(rec.id, body: body);
        }
        _muat();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengumuman tersimpan.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan pengumuman.')),
          );
        }
      }
    }
  }

  Future<void> _hapus(RecordModel rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengumuman'),
        content: Text('Hapus "${rec.getStringValue('judul')}"?'),
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
        await PbService().pb.collection('pengumuman').delete(rec.id);
        _muat();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Gagal menghapus.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pengumuman')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
                          Icons.campaign_outlined,
                          size: 64,
                          color: AppColors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada pengumuman.',
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
                        final n = _data[i];
                        return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.line),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          n.getStringValue('judul'),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                        ),
                                        color: AppColors.primary,
                                        onPressed: () => _form(rec: n),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        color: AppColors.red,
                                        onPressed: () => _hapus(n),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n.getStringValue('isi'),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: AppColors.grey,
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
                            )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: i * 50))
                            .slideY(begin: 0.06, end: 0);
                      },
                    ),
            ),
    );
  }
}

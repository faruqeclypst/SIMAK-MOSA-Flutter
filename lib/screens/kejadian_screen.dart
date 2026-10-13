import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'kejadian_form_screen.dart';

// Cap on Spot: feed kejadian ala story WA — anomali, pelanggaran,
// peristiwa. Semua user bisa melihat, siapa pun bisa melapor cepat.
class KejadianScreen extends StatefulWidget {
  const KejadianScreen({super.key});

  @override
  State<KejadianScreen> createState() => _KejadianScreenState();
}

class _KejadianScreenState extends State<KejadianScreen> {
  List<RecordModel> _data = [];
  bool _loading = true;
  String _filter = 'Semua';
  static const _kategori = [
    'Semua',
    'Pelanggaran',
    'Anomali',
    'Peristiwa',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final res = await PbService().pb
          .collection('kejadian')
          .getList(page: 1, perPage: 100, sort: '-created', expand: 'pelapor');
      setState(() {
        _data = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _warnaKategori(String k) {
    switch (k) {
      case 'Pelanggaran':
        return AppColors.red;
      case 'Anomali':
        return const Color(0xFF92400E);
      case 'Peristiwa':
        return AppColors.primary;
      default:
        return AppColors.blue;
    }
  }

  String _fotoUrl(RecordModel r) {
    final f = r.getStringValue('foto');
    if (f.isEmpty) return '';
    try {
      return PbService().pb.files.getURL(r, f).toString();
    } catch (_) {
      return '';
    }
  }

  String _namaPelapor(RecordModel r) {
    var n = r.getStringValue('expand.pelapor.nama_lengkap');
    if (n.isEmpty) n = r.getStringValue('expand.pelapor.email');
    return n.isEmpty ? 'Pengguna' : n;
  }

  String _waktuRelatif(String created) {
    try {
      final d = DateTime.parse(created).toLocal();
      final selisih = DateTime.now().difference(d);
      if (selisih.inMinutes < 1) return 'baru saja';
      if (selisih.inMinutes < 60) return '${selisih.inMinutes} mnt lalu';
      if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
      if (selisih.inDays < 7) return '${selisih.inDays} hari lalu';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  void _lihatDetail(RecordModel r) {
    final foto = _fotoUrl(r);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (foto.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    foto,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _warnaKategori(r.getStringValue('kategori'))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        r.getStringValue('kategori'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _warnaKategori(r.getStringValue('kategori')),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.getStringValue('judul'),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    if (r.getStringValue('deskripsi').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.getStringValue('deskripsi'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Dilaporkan oleh ${_namaPelapor(r)} • ${_waktuRelatif(r.getStringValue('created'))}',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tampil = _filter == 'Semua'
        ? _data
        : _data.where((r) => r.getStringValue('kategori') == _filter).toList();
    final adaFoto = tampil.where((r) => _fotoUrl(r).isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Kejadian')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await bukaCapInstan(context);
          _muat();
        },
        icon: const Icon(Icons.bolt_outlined, color: Colors.white),
        label: Text(
          'Cap!',
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
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  // Story ala WA: kejadian berfoto terbaru
                  if (adaFoto.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Sorotan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 92,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: adaFoto.length.clamp(0, 15),
                        itemBuilder: (_, i) {
                          final r = adaFoto[i];
                          final kat = r.getStringValue('kategori');
                          return GestureDetector(
                            onTap: () => _lihatDetail(r),
                            child: Container(
                              width: 72,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                children: [
                                  Container(
                                    width: 62,
                                    height: 62,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _warnaKategori(kat),
                                        width: 2.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        _fotoUrl(r),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.image_outlined,
                                          color: AppColors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    kat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: AppColors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _kategori.map((k) {
                          final aktif = _filter == k;
                          return GestureDetector(
                            onTap: () => setState(() => _filter = k),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: aktif ? AppColors.primary : Colors.white,
                                border: Border.all(
                                  color: aktif
                                      ? AppColors.primary
                                      : AppColors.line,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                k,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: aktif ? Colors.white : AppColors.grey,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  if (tampil.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: AppColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bolt_outlined,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada kejadian.',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Lihat anomali atau pelanggaran?\nLangsung Cap! dari tombol di bawah.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: AppColors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...tampil.asMap().entries.map((en) {
                    final r = en.value;
                    final kat = r.getStringValue('kategori');
                    final foto = _fotoUrl(r);
                    return GestureDetector(
                          onTap: () => _lihatDetail(r),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.line),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (foto.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    child: Image.network(
                                      foto,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _warnaKategori(kat)
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              kat,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: _warnaKategori(kat),
                                                  ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            _waktuRelatif(
                                              r.getStringValue('created'),
                                            ),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        r.getStringValue('judul'),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (r
                                          .getStringValue('deskripsi')
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          r.getStringValue('deskripsi'),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: AppColors.grey,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: AppColors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _namaPelapor(r),
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

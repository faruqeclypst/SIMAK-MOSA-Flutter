import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'kejadian_form_screen.dart';

// Layar CAP (Catatan Aktivitas & Peristiwa) ala WhatsApp Story:
// - Status aktif 24 jam (reset harian otomatis)
// - Arsip CAP untuk histori catatan sebelumnya
// - Semua user bisa melihat status & arsip
// - Admin dan pembuat CAP berhak menghapus catatan
class KejadianScreen extends StatefulWidget {
  const KejadianScreen({super.key});

  @override
  State<KejadianScreen> createState() => _KejadianScreenState();
}

class _KejadianScreenState extends State<KejadianScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RecordModel> _data = [];
  bool _loading = true;
  String _filter = 'Semua';
  bool _isGridMode = true;

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
    _tabController = TabController(length: 2, vsync: this);
    _muat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final res = await PbService().pb
          .collection('kejadian')
          .getList(page: 1, perPage: 200, sort: '-created', expand: 'pelapor');
      if (mounted) {
        setState(() {
          _data = res.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isStoryAktif(RecordModel r) {
    try {
      final created = DateTime.parse(r.getStringValue('created')).toLocal();
      final selisih = DateTime.now().difference(created);
      // Status aktif selama 24 jam terakhir (reset harian ala WA story)
      return selisih.inHours < 24;
    } catch (_) {
      return false;
    }
  }

  bool _bisaHapus(RecordModel r) {
    final me = PbService().me;
    if (me == null) return false;
    if (PbService().isAdmin) return true;
    final pelaporId = r.getStringValue('pelapor');
    return pelaporId == me.id;
  }

  Future<void> _hapusCap(RecordModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus Catatan CAP?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${r.getStringValue('judul')}"? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await PbService().pb.collection('kejadian').delete(r.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan CAP berhasil dihapus.')),
        );
        _muat();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus catatan.')),
        );
      }
    }
  }

  Color _warnaKategori(String k) {
    switch (k) {
      case 'Pelanggaran':
        return AppColors.red;
      case 'Anomali':
        return const Color(0xFFD97706);
      case 'Peristiwa':
        return AppColors.primary;
      default:
        return const Color(0xFF2563EB);
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
    if (n.isEmpty) n = r.getStringValue('expand.pelapor.name');
    if (n.isEmpty) n = r.getStringValue('expand.pelapor.email');
    return n.isEmpty ? 'Warga Sekolah' : n;
  }

  String _inisialPelapor(RecordModel r) {
    final n = _namaPelapor(r);
    final p = n.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.first.toUpperCase();
    return (p.first.characters.first + p[1].characters.first).toUpperCase();
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

  void _bukaStoryViewer(List<RecordModel> list, int initialIndex) {
    if (list.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CapStoryViewerScreen(
          stories: list,
          initialIndex: initialIndex,
          onDeleted: _muat,
        ),
      ),
    );
  }

  void _lihatDetail(RecordModel r) {
    final foto = _fotoUrl(r);
    final bisaHapus = _bisaHapus(r);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (foto.isNotEmpty)
                Image.network(
                  foto,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                              color: _warnaKategori(
                                r.getStringValue('kategori'),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_isStoryAktif(r))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt,
                                  size: 13,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Aktif 24 Jam',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Arsip',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.getStringValue('judul'),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.ink,
                      ),
                    ),
                    if (r.getStringValue('deskripsi').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        r.getStringValue('deskripsi'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              _inisialPelapor(r),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _namaPelapor(r),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Dilaporkan • ${_waktuRelatif(r.getStringValue('created'))}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (bisaHapus)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _hapusCap(r);
                            },
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.red,
                              size: 18,
                            ),
                            label: Text(
                              'Hapus',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tutup'),
                        ),
                      ],
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
    final aktifSemua = _data.where(_isStoryAktif).toList();
    final arsipSemua = _data.where((r) => !_isStoryAktif(r)).toList();

    final aktifFiltered = _filter == 'Semua'
        ? aktifSemua
        : aktifSemua.where((r) => r.getStringValue('kategori') == _filter).toList();

    final arsipFiltered = _filter == 'Semua'
        ? arsipSemua
        : arsipSemua.where((r) => r.getStringValue('kategori') == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CAP (Catatan Aktivitas & Peristiwa)',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 18),
                  const SizedBox(width: 6),
                  Text('Hari Ini (${aktifSemua.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 17),
                  const SizedBox(width: 6),
                  Text('Arsip CAP (${arsipSemua.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await bukaCapInstan(context);
          _muat();
        },
        icon: const Icon(Icons.bolt_outlined, color: Colors.white),
        label: Text(
          'Cap Baru!',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: Column(
                children: [
                  // Filter Kategori Chips & Mode Galeri / Tabel Switch
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
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
                                      horizontal: 13,
                                      vertical: 6,
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: aktif ? Colors.white : AppColors.grey,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Toggle Galeri 4 Foto vs List Tabel
                        IconButton(
                          icon: Icon(
                            _isGridMode ? Icons.grid_view_rounded : Icons.view_agenda_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          tooltip: _isGridMode ? 'Tampilan: Galeri (4 Foto) • Klik untuk List' : 'Tampilan: List Tabel • Klik untuk Galeri',
                          onPressed: () => setState(() => _isGridMode = !_isGridMode),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: Status Hari Ini (24 Jam ala WA Story)
                        _buildTabAktif(aktifSemua, aktifFiltered),

                        // TAB 2: Arsip CAP
                        _buildTabArsip(arsipFiltered),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTabAktif(List<RecordModel> allActive, List<RecordModel> filtered) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        // Story Carousel ala WhatsApp
        if (allActive.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Text(
                  'Story Hari Ini',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Reset 24 Jam',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 105,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: allActive.length + 1,
              itemBuilder: (ctx, i) {
                // Posisi 0: Tambah Status Sendiri
                if (i == 0) {
                  return GestureDetector(
                    onTap: () async {
                      await bukaCapInstan(context);
                      _muat();
                    },
                    child: Container(
                      width: 76,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.line,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    PbService().inisial,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Status Anda',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final r = allActive[i - 1];
                final foto = _fotoUrl(r);
                final kat = r.getStringValue('kategori');

                return GestureDetector(
                  onTap: () => _bukaStoryViewer(allActive, i - 1),
                  child: Container(
                    width: 76,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        // WhatsApp Story Ring
                        Container(
                          width: 62,
                          height: 62,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                _warnaKategori(kat),
                                _warnaKategori(kat).withValues(alpha: 0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipOval(
                              child: foto.isNotEmpty
                                  ? Image.network(
                                      foto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.image_outlined,
                                        color: AppColors.grey,
                                      ),
                                    )
                                  : Container(
                                      color: _warnaKategori(kat).withValues(alpha: 0.15),
                                      child: Center(
                                        child: Text(
                                          _inisialPelapor(r),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w800,
                                            color: _warnaKategori(kat),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _namaPelapor(r),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 20),
        ],

        // Feed: Galeri 4 Foto (2-Kolom) atau List Tabel
        if (filtered.isEmpty)
          _buildEmptyState(
            'Belum ada status CAP hari ini.',
            'Semua catatan CAP akan aktif selama 24 jam lalu masuk ke arsip.',
          )
        else if (_isGridMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.74,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _buildGalleryCard(filtered[i]),
            ),
          )
        else
          ...filtered.map((r) => _buildTableCard(r)),
      ],
    );
  }

  Widget _buildTabArsip(List<RecordModel> arsipList) {
    if (arsipList.isEmpty) {
      return _buildEmptyState(
        'Belum ada arsip CAP.',
        'Catatan CAP yang telah melewati 24 jam akan otomatis tersimpan di sini.',
      );
    }

    if (_isGridMode) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.74,
        ),
        itemCount: arsipList.length,
        itemBuilder: (ctx, i) => _buildGalleryCard(arsipList[i], isArsip: true),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: arsipList.length,
      itemBuilder: (ctx, i) => _buildTableCard(arsipList[i], isArsip: true),
    );
  }

  Widget _buildGalleryCard(RecordModel r, {bool isArsip = false}) {
    final kat = r.getStringValue('kategori');
    final foto = _fotoUrl(r);
    final bisaHapus = _bisaHapus(r);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _lihatDetail(r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Foto dengan Overlay Badge & Tombol Hapus
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (foto.isNotEmpty)
                    Image.network(
                      foto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 26,
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: _warnaKategori(kat).withValues(alpha: 0.08),
                      child: Center(
                        child: Icon(
                          Icons.photo_outlined,
                          size: 32,
                          color: _warnaKategori(kat).withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _warnaKategori(kat).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        kat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (bisaHapus)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _hapusCap(r),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Teks Detail Kecil di dalam card
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.getStringValue('judul'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.getStringValue('deskripsi').isNotEmpty
                              ? r.getStringValue('deskripsi')
                              : 'Tanpa deskripsi tambahan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.grey,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 7,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            _inisialPelapor(r),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _namaPelapor(r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                        Text(
                          _waktuRelatif(r.getStringValue('created')),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(RecordModel r, {bool isArsip = false}) {
    final kat = r.getStringValue('kategori');
    final foto = _fotoUrl(r);
    final bisaHapus = _bisaHapus(r);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _lihatDetail(r),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: foto.isNotEmpty
                  ? Image.network(
                      foto,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 58,
                        height: 58,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 20,
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 58,
                      height: 58,
                      color: _warnaKategori(kat).withValues(alpha: 0.1),
                      child: Center(
                        child: Icon(
                          Icons.photo_outlined,
                          size: 22,
                          color: _warnaKategori(kat),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _warnaKategori(kat).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kat,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _warnaKategori(kat),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _waktuRelatif(r.getStringValue('created')),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.getStringValue('judul'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.ink,
                    ),
                  ),
                  if (r.getStringValue('deskripsi').isNotEmpty)
                    Text(
                      r.getStringValue('deskripsi'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.grey,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    'Oleh: ${_namaPelapor(r)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (bisaHapus)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.grey),
                onPressed: () => _hapusCap(r),
                tooltip: 'Hapus CAP',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Fullscreen Story Viewer ala WhatsApp
class CapStoryViewerScreen extends StatefulWidget {
  final List<RecordModel> stories;
  final int initialIndex;
  final VoidCallback onDeleted;

  const CapStoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onDeleted,
  });

  @override
  State<CapStoryViewerScreen> createState() => _CapStoryViewerScreenState();
}

class _CapStoryViewerScreenState extends State<CapStoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _progressController.reset();
        _progressController.forward();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progressController.reset();
        _progressController.forward();
      });
    } else {
      _progressController.reset();
      _progressController.forward();
    }
  }

  void _pause() {
    if (!_isPaused) {
      _progressController.stop();
      setState(() => _isPaused = true);
    }
  }

  void _resume() {
    if (_isPaused) {
      _progressController.forward();
      setState(() => _isPaused = false);
    }
  }

  bool _bisaHapus(RecordModel r) {
    final me = PbService().me;
    if (me == null) return false;
    if (PbService().isAdmin) return true;
    return r.getStringValue('pelapor') == me.id;
  }

  Future<void> _hapusCurrent() async {
    _pause();
    final r = widget.stories[_currentIndex];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan CAP?'),
        content: Text('Yakin ingin menghapus "${r.getStringValue('judul')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PbService().pb.collection('kejadian').delete(r.id);
        widget.onDeleted();
        if (mounted) Navigator.pop(context);
      } catch (_) {
        _resume();
      }
    } else {
      _resume();
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
    if (n.isEmpty) n = r.getStringValue('expand.pelapor.name');
    return n.isEmpty ? 'Warga Sekolah' : n;
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final foto = _fotoUrl(story);
    final bisaHapus = _bisaHapus(story);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width * 0.3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image or Gradient
            if (foto.isNotEmpty)
              Image.network(
                foto,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _buildTextBackground(story),
              )
            else
              _buildTextBackground(story),

            // Top Gradient Shadow
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Bottom Gradient Shadow & Caption
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        story.getStringValue('kategori'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.getStringValue('judul'),
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (story.getStringValue('deskripsi').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        story.getStringValue('deskripsi'),
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Top Header: Progress Bar + User Profile + Close & Delete
            SafeArea(
              child: Column(
                children: [
                  // Progress Bars
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, _) {
                                double value = 0.0;
                                if (i < _currentIndex) {
                                  value = 1.0;
                                } else if (i == _currentIndex) {
                                  value = _progressController.value;
                                }
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Header Author Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: const Icon(
                            Icons.bolt,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _namaPelapor(story),
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'CAP Story 24 Jam',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (bisaHapus)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                            onPressed: _hapusCurrent,
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBackground(RecordModel story) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: AppColors.primary, size: 54),
              const SizedBox(height: 18),
              Text(
                story.getStringValue('judul'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

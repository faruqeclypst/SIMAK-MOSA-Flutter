import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'jurnal_form_screen.dart';

// Pencarian interaktif: cari kelas & siswa dengan BottomSheet detail lengkap.
class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<RecordModel> _kelas = [];
  List<RecordModel> _siswa = [];
  bool _mencari = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cari(String q) async {
    setState(() {
      _query = q;
      _mencari = true;
    });
    if (q.trim().isEmpty) {
      setState(() {
        _kelas = [];
        _siswa = [];
        _mencari = false;
      });
      return;
    }
    try {
      final pb = PbService().pb;
      final cleanQ = q.replaceAll('"', '').replaceAll(r'\', '');
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 20, filter: 'nama ~ "$cleanQ"', sort: 'nama');
      final s = await pb
          .collection('siswa')
          .getList(
            page: 1,
            perPage: 30,
            filter: 'nama ~ "$cleanQ"',
            expand: 'kelas',
            sort: 'nama',
          );
      setState(() {
        _kelas = k.items;
        _siswa = s.items;
        _mencari = false;
      });
    } catch (_) {
      setState(() => _mencari = false);
    }
  }

  String _namaKelas(RecordModel s) {
    final n = s.getStringValue('expand.kelas.nama');
    return n.isEmpty ? '-' : n;
  }

  // --- DETAIL KELAS BOTTOM SHEET ---
  void _bukaDetailKelas(RecordModel k) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailKelasSheet(kelas: k),
    );
  }

  // --- DETAIL SISWA BOTTOM SHEET ---
  void _bukaDetailSiswa(RecordModel s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSiswaSheet(siswa: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pencarian')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _cari,
              decoration: InputDecoration(
                hintText: 'Cari nama kelas atau siswa...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.grey),
                        onPressed: () {
                          _searchCtrl.clear();
                          _cari('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF4F6F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cari Kelas atau Siswa',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Ketik nama kelas (mis. X-A) atau nama siswa\nuntuk melihat rincian dan absensi lengkap.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _mencari
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (_kelas.isNotEmpty) ...[
                        Text(
                          'Kelas (${_kelas.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._kelas.map(
                          (k) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.meeting_room_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                'Kelas ${k.getStringValue('nama')}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Tingkat ${k.getStringValue('tingkat')} • Fase ${k.getStringValue('fase')}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.grey,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.grey,
                              ),
                              onTap: () => _bukaDetailKelas(k),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_siswa.isNotEmpty) ...[
                        Text(
                          'Siswa (${_siswa.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._siswa.map(
                          (s) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE8F0FE),
                                child: Text(
                                  s.getStringValue('nama').isNotEmpty
                                      ? s.getStringValue('nama')[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.getStringValue('nama'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'Kelas ${_namaKelas(s)} • NISN: ${s.getStringValue('nisn').isNotEmpty ? s.getStringValue('nisn') : '-'}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.grey,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.grey,
                              ),
                              onTap: () => _bukaDetailSiswa(s),
                            ),
                          ),
                        ),
                      ],
                      if (_kelas.isEmpty && _siswa.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.search_off_outlined,
                                  size: 48,
                                  color: AppColors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tidak ada hasil untuk "$_query"',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BOTTOM SHEET DETAIL KELAS
// ==========================================
class _DetailKelasSheet extends StatefulWidget {
  final RecordModel kelas;
  const _DetailKelasSheet({required this.kelas});

  @override
  State<_DetailKelasSheet> createState() => _DetailKelasSheetState();
}

class _DetailKelasSheetState extends State<_DetailKelasSheet> {
  List<RecordModel> _siswaList = [];
  List<RecordModel> _jurnalHariIni = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pb = PbService().pb;
      final tgl = PbService().tanggalHariIni();
      final s = await pb.collection('siswa').getList(
            page: 1,
            perPage: 100,
            filter: 'kelas = "${widget.kelas.id}"',
            sort: 'nama',
          );
      final j = await pb.collection('jurnal').getList(
            page: 1,
            perPage: 20,
            filter:
                'kelas = "${widget.kelas.id}" && tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            expand: 'guru',
            sort: '-created',
          );
      if (mounted) {
        setState(() {
          _siswaList = s.items;
          _jurnalHariIni = j.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = widget.kelas.getStringValue('nama');
    final tingkat = widget.kelas.getStringValue('tingkat');
    final fase = widget.kelas.getStringValue('fase');
    final wali = widget.kelas.getStringValue('wali_kelas');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                        Icons.meeting_room,
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
                            'Kelas $nama',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Tingkat $tingkat • Fase $fase${wali.isNotEmpty ? ' • Wali: $wali' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
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
                          // Status KBM Hari Ini
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _jurnalHariIni.isNotEmpty
                                  ? AppColors.primarySoft
                                  : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _jurnalHariIni.isNotEmpty
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _jurnalHariIni.isNotEmpty
                                      ? Icons.check_circle_outline
                                      : Icons.info_outline,
                                  color: _jurnalHariIni.isNotEmpty
                                      ? AppColors.primaryDark
                                      : const Color(0xFFB45309),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _jurnalHariIni.isNotEmpty
                                            ? 'KBM Hari Ini: Terisi'
                                            : 'KBM Hari Ini: Belum Diisi',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _jurnalHariIni.isNotEmpty
                                              ? AppColors.primaryDark
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                      if (_jurnalHariIni.isNotEmpty)
                                        Text(
                                          'Guru: ${_jurnalHariIni.first.getStringValue('expand.guru.nama_lengkap').isNotEmpty ? _jurnalHariIni.first.getStringValue('expand.guru.nama_lengkap') : 'Guru'} • Jam ${_jurnalHariIni.first.getStringValue('jam')}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.primaryDark,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JurnalFormScreen(
                                          kelasIdAwal: widget.kelas.id,
                                        ),
                                      ),
                                    );
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Isi Jurnal'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daftar Siswa',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              Text(
                                '${_siswaList.length} Siswa',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_siswaList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'Belum ada data siswa di kelas ini.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ..._siswaList.asMap().entries.map((en) {
                            final idx = en.key;
                            final s = en.value;
                            final nisn = s.getStringValue('nisn');
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primarySoft,
                                    child: Text(
                                      '${idx + 1}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      s.getStringValue('nama'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (nisn.isNotEmpty)
                                    Text(
                                      nisn,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.grey,
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
}

// ==========================================
// BOTTOM SHEET DETAIL SISWA
// ==========================================
class _DetailSiswaSheet extends StatefulWidget {
  final RecordModel siswa;
  const _DetailSiswaSheet({required this.siswa});

  @override
  State<_DetailSiswaSheet> createState() => _DetailSiswaSheetState();
}

class _DetailSiswaSheetState extends State<_DetailSiswaSheet> {
  int _hadir = 0;
  int _sakit = 0;
  int _izin = 0;
  int _alpa = 0;
  List<RecordModel> _piketIzin = [];
  List<RecordModel> _asramaIzin = [];
  List<RecordModel> _terlambatList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final pb = PbService().pb;
      final sid = widget.siswa.id;

      // Rekap absensi jurnal
      final abs = await pb.collection('absensi').getList(
            page: 1,
            perPage: 200,
            filter: 'siswa = "$sid"',
          );
      var h = 0, s = 0, i = 0, a = 0;
      for (final it in abs.items) {
        final st = it.getStringValue('status');
        if (st == 'Hadir') h++;
        if (st == 'Sakit') s++;
        if (st == 'Izin') i++;
        if (st == 'Alpa') a++;
      }

      // Catatan Piket
      final p = await pb.collection('izin_piket').getList(
            page: 1,
            perPage: 10,
            filter: 'siswa = "$sid"',
            sort: '-tanggal',
          );

      // Catatan Asrama
      final asr = await pb.collection('asrama').getList(
            page: 1,
            perPage: 10,
            filter: 'siswa = "$sid"',
            sort: '-tanggal',
          );

      // Catatan Terlambat
      final t = await pb.collection('keterlambatan').getList(
            page: 1,
            perPage: 10,
            filter: 'siswa = "$sid"',
            sort: '-tanggal',
          );

      if (mounted) {
        setState(() {
          _hadir = h;
          _sakit = s;
          _izin = i;
          _alpa = a;
          _piketIzin = p.items;
          _asramaIzin = asr.items;
          _terlambatList = t.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtTanggal(String t) {
    try {
      final d = DateTime.parse(t).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.siswa;
    final nama = s.getStringValue('nama');
    final nisn = s.getStringValue('nisn');
    final kelas = s.getStringValue('expand.kelas.nama');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
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
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: Text(
                        nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            'Kelas $kelas • NISN: ${nisn.isNotEmpty ? nisn : '-'}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.grey,
                            ),
                          ),
                        ],
                      ),
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
                          // Rekap Absensi
                          Text(
                            'Statistik Kehadiran KBM',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _statChip('Hadir', '$_hadir', AppColors.primary, AppColors.primarySoft),
                              const SizedBox(width: 8),
                              _statChip('Sakit', '$_sakit', AppColors.amber, AppColors.amberSoft),
                              const SizedBox(width: 8),
                              _statChip('Izin', '$_izin', AppColors.blue, AppColors.blueSoft),
                              const SizedBox(width: 8),
                              _statChip('Alpa', '$_alpa', AppColors.red, AppColors.redSoft),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Riwayat Izin Piket
                          if (_piketIzin.isNotEmpty) ...[
                            Text(
                              'Riwayat Izin Piket',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._piketIzin.map(
                              (p) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.shield_outlined,
                                      size: 18,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${p.getStringValue('keterangan')} • Jam ${p.getStringValue('jam')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _fmtTanggal(p.getStringValue('tanggal')),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Riwayat Asrama
                          if (_asramaIzin.isNotEmpty) ...[
                            Text(
                              'Riwayat Laporan Asrama',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._asramaIzin.map(
                              (a) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.home_outlined,
                                      size: 18,
                                      color: Color(0xFF0D9488),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${a.getStringValue('jenis')}: ${a.getStringValue('keterangan')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _fmtTanggal(a.getStringValue('tanggal')),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Riwayat Keterlambatan Gerbang
                          if (_terlambatList.isNotEmpty) ...[
                            Text(
                              'Catatan Keterlambatan Gerbang',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._terlambatList.map(
                              (t) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.red.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      size: 18,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pukul ${t.getStringValue('jam_masuk')} • ${t.getStringValue('alasan')}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.red,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _fmtTanggal(t.getStringValue('tanggal')),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
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

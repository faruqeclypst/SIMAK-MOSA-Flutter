import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/laporan_pdf.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'jurnal_form_screen.dart';

// Monitoring KBM: status TERISI/KOSONG per kelas hari ini dengan rincian interaktif.
class KurikulumScreen extends StatefulWidget {
  const KurikulumScreen({super.key});

  @override
  State<KurikulumScreen> createState() => _KurikulumScreenState();
}

class _KurikulumScreenState extends State<KurikulumScreen> {
  List<RecordModel> _kelas = [];
  Set<String> _terisi = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final tgl = PbService().tanggalHariIni();
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      final j = await pb
          .collection('jurnal')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );
      if (mounted) {
        setState(() {
          _kelas = k.items;
          _terisi = j.items.map((x) => x.getStringValue('kelas')).toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _bukaDetailKelas(RecordModel k, bool terisi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailKbmKelasSheet(kelas: k, terisi: terisi, onUpdated: _muat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kosong = _kelas.length - _terisi.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Kurikulum'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Cetak PDF',
            onPressed: () => cetakLaporanMonitoring(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          angka: '${_terisi.length}',
                          label: 'Kelas terisi',
                          warna: AppColors.primary,
                          bg: AppColors.primarySoft,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          angka: '$kosong',
                          label: 'Kelas kosong',
                          warna: AppColors.red,
                          bg: AppColors.redSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Status KBM Hari Ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Ketuk kelas untuk detail',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: _kelas.length,
                    itemBuilder: (_, i) {
                      final k = _kelas[i];
                      final isi = _terisi.contains(k.id);
                      return Material(
                        color: isi
                            ? AppColors.primarySoft
                            : const Color(0xFFFDE8E8),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _bukaDetailKelas(k, isi),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isi
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  k.getStringValue('nama'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isi
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : AppColors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isi ? 'TERISI' : 'KOSONG',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isi
                                          ? AppColors.primaryDark
                                          : AppColors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String angka;
  final String label;
  final Color warna;
  final Color bg;

  const _StatBox({
    required this.angka,
    required this.label,
    required this.warna,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: warna.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            angka,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: warna,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: warna,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// BOTTOM SHEET RINCIAN KBM KELAS
// ==========================================
class _DetailKbmKelasSheet extends StatefulWidget {
  final RecordModel kelas;
  final bool terisi;

  final VoidCallback? onUpdated;

  const _DetailKbmKelasSheet({required this.kelas, required this.terisi, this.onUpdated});

  @override
  State<_DetailKbmKelasSheet> createState() => _DetailKbmKelasSheetState();
}

class _DetailKbmKelasSheetState extends State<_DetailKbmKelasSheet> {
  List<RecordModel> _jurnalList = [];
  List<RecordModel> _jadwalList = [];
  final Map<String, List<RecordModel>> _absensiPerJurnal = {};
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
      final hari = PbService().hariIni();
      final kid = widget.kelas.id;

      if (widget.terisi) {
        final j = await pb.collection('jurnal').getList(
              page: 1,
              perPage: 10,
              filter:
                  'kelas = "$kid" && tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
              expand: 'guru',
              sort: '-created',
            );
        _jurnalList = j.items;
        for (final item in j.items) {
          final abs = await pb.collection('absensi').getList(
                page: 1,
                perPage: 100,
                filter: 'jurnal = "${item.id}"',
                expand: 'siswa',
              );
          _absensiPerJurnal[item.id] = abs.items;
        }
      } else {
        // Ambil jadwal kelas hari ini untuk melihat siapa guru yang harusnya masuk
        final jd = await pb.collection('jadwal').getList(
              page: 1,
              perPage: 20,
              filter: 'kelas = "$kid" && hari = "$hari"',
              expand: 'guru',
              sort: 'jam_ke',
            );
        _jadwalList = jd.items;
      }

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = widget.kelas.getStringValue('nama');

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.35,
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
                        color: widget.terisi
                            ? AppColors.primarySoft
                            : AppColors.redSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.terisi
                            ? Icons.check_circle_outline
                            : Icons.highlight_off_outlined,
                        color: widget.terisi
                            ? AppColors.primaryDark
                            : AppColors.red,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status KBM Kelas $nama',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            widget.terisi
                                ? 'KBM Telah Terisi Hari Ini'
                                : 'KBM Belum Terisi (Kosong)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: widget.terisi
                                  ? AppColors.primaryDark
                                  : AppColors.red,
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
                          if (widget.terisi) ...[
                            ..._jurnalList.map((j) {
                              final guru = j.getStringValue(
                                'expand.guru.nama_lengkap',
                              );
                              final jam = j.getStringValue('jam');
                              final materi = j.getStringValue('materi');
                              final catatan = j.getStringValue('catatan');
                              final absList = _absensiPerJurnal[j.id] ?? [];
                              final tidakHadir = absList
                                  .where(
                                    (a) =>
                                        a.getStringValue('status') != 'Hadir',
                                  )
                                  .toList();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Guru: ${guru.isNotEmpty ? guru : "Guru"}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Jam ke-$jam',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Materi: $materi',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    if (catatan.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Catatan: $catatan',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.grey,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ketidakhadiran (${tidakHadir.length} siswa):',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (tidakHadir.isEmpty)
                                      Text(
                                        'Semua siswa hadir nihil alpa/izin/sakit.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.primaryDark,
                                        ),
                                      )
                                    else
                                      ...tidakHadir.map((th) {
                                        final namaSiswa = th.getStringValue(
                                          'expand.siswa.nama',
                                        );
                                        final st = th.getStringValue('status');
                                        final ket = th.getStringValue(
                                          'keterangan',
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: st == 'Sakit'
                                                      ? AppColors.amberSoft
                                                      : (st == 'Izin'
                                                          ? AppColors.blueSoft
                                                          : AppColors.redSoft),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  st,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: st == 'Sakit'
                                                            ? AppColors.amber
                                                            : (st == 'Izin'
                                                                ? AppColors.blue
                                                                : AppColors
                                                                    .red),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  namaSiswa.isNotEmpty
                                                      ? namaSiswa
                                                      : 'Siswa',
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              if (ket.isNotEmpty)
                                                Text(
                                                  ket,
                                                  style:
                                                      GoogleFonts.plusJakartaSans(
                                                        fontSize: 11,
                                                        color: AppColors.grey,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              );
                            }),
                          ] else ...[
                            // Jika kosong, tampilkan guru yang seharusnya mengajar
                            Text(
                              'Jadwal Pelajaran Hari Ini di Kelas Ini:',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_jadwalList.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Tidak ditemukan jadwal tercatat untuk hari ini.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.grey,
                                  ),
                                ),
                              )
                            else
                              ..._jadwalList.map((jd) {
                                final mapel = jd.getStringValue('mapel');
                                final guru = jd.getStringValue(
                                  'expand.guru.nama_lengkap',
                                );
                                final jamKe = jd.getIntValue('jam_ke');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.line),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: AppColors.amberSoft,
                                        child: Text(
                                          '$jamKe',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFB45309),
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
                                              mapel,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                  ),
                                            ),
                                            Text(
                                              'Guru: ${guru.isNotEmpty ? guru : "Guru"}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: AppColors.grey,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 16),
                            FilledButton.icon(
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
                              icon: const Icon(Icons.edit_note_outlined),
                              label: const Text('Isi Jurnal Kelas Sekarang'),
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
}

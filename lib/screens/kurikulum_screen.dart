import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/laporan_pdf.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';

// Monitoring KBM: status TERISI/KOSONG per kelas hari ini.
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
      setState(() {
        _kelas = k.items;
        _terisi = j.items.map((x) => x.getStringValue('kelas')).toSet();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kosong = _kelas.length - _terisi.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Kurikulum'),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          angka: '$kosong',
                          label: 'Kelas kosong',
                          warna: AppColors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Status KBM Hari Ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
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
                          childAspectRatio: 1.6,
                        ),
                    itemCount: _kelas.length,
                    itemBuilder: (_, i) {
                      final k = _kelas[i];
                      final isi = _terisi.contains(k.id);
                      return Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isi
                              ? AppColors.primarySoft
                              : const Color(0xFFFDE8E8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              k.getStringValue('nama'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              isi ? 'TERISI' : 'KOSONG',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isi
                                    ? AppColors.primaryDark
                                    : AppColors.red,
                              ),
                            ),
                          ],
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

  const _StatBox({
    required this.angka,
    required this.label,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
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
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

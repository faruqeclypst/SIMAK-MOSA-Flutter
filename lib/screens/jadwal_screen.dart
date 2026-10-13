import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'jurnal_form_screen.dart';

// Jadwal hari ini dari PocketBase + tombol isi jurnal per kelas.
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
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
      final hari = PbService().hariIni();
      final res = await PbService().pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 100,
            filter: 'hari = "$hari"',
            sort: 'jam_ke',
            expand: 'kelas,guru',
          );
      setState(() {
        _data = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hari = PbService().hariIni();
    return Scaffold(
      appBar: AppBar(title: Text('Jadwal • $hari')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: _data.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          size: 64,
                          color: AppColors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada jadwal hari $hari.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _data.length,
                      itemBuilder: (_, i) {
                        final j = _data[i];
                        final namaKelas = j.getStringValue('expand.kelas.nama');
                        final kelasId = j.getStringValue('kelas');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Jam ke-${j.getIntValue('jam_ke')}',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${j.getStringValue('mapel')} • Kelas $namaKelas',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JurnalFormScreen(
                                          kelasIdAwal: kelasId,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_note_outlined),
                                  label: const Text('Isi Jurnal Kelas'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

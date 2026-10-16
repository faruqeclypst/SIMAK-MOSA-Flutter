import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'jurnal_form_screen.dart';

// Jadwal Pelajaran komprehensif: pemilih hari (Senin-Sabtu),
// filter "Jadwal Saya" vs "Semua Kelas", pencarian mapel/guru, dan aksi cepat isi jurnal.
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  static const _daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  late String _hariTerpilih;
  bool _hanyaJadwalSaya = false;
  String? _filterKelasId;
  String _cariMapel = '';

  List<RecordModel> _jadwalList = [];
  List<RecordModel> _kelasList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final h = PbService().hariIni();
    _hariTerpilih = _daftarHari.contains(h) ? h : 'Senin';
    _muatKelas();
    _muatJadwal();
  }

  Future<void> _muatKelas() async {
    try {
      final pb = PbService().pb;
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      if (mounted) setState(() => _kelasList = k.items);
    } catch (_) {}
  }

  Future<void> _muatJadwal() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final res = await pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'hari = "$_hariTerpilih"',
            sort: 'jam_ke,kelas.nama',
            expand: 'kelas,guru',
          );
      if (mounted) {
        setState(() {
          _jadwalList = res.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }



  List<_JadwalSesi> _kelompokkanJadwal(List<RecordModel> list) {
    final Map<String, List<RecordModel>> groups = {};
    for (final rec in list) {
      final kId = rec.getStringValue('kelas');
      final gId = rec.getStringValue('guru');
      final mapel = rec.getStringValue('mapel').trim().toLowerCase();
      final key = '$kId|#|$gId|#|$mapel';
      groups.putIfAbsent(key, () => []).add(rec);
    }

    final List<_JadwalSesi> hasil = [];

    for (final entry in groups.entries) {
      final recs = entry.value;
      recs.sort(
        (a, b) => a.getIntValue('jam_ke').compareTo(b.getIntValue('jam_ke')),
      );

      List<RecordModel> currentRun = [];
      for (final r in recs) {
        if (currentRun.isEmpty) {
          currentRun.add(r);
        } else {
          final prevJam = currentRun.last.getIntValue('jam_ke');
          final thisJam = r.getIntValue('jam_ke');
          if (thisJam == prevJam + 1) {
            currentRun.add(r);
          } else {
            hasil.add(_buatSesi(currentRun));
            currentRun = [r];
          }
        }
      }
      if (currentRun.isNotEmpty) {
        hasil.add(_buatSesi(currentRun));
      }
    }

    hasil.sort((a, b) {
      final c = a.jamMulai.compareTo(b.jamMulai);
      if (c != 0) return c;
      return a.namaKelas.compareTo(b.namaKelas);
    });

    return hasil;
  }

  _JadwalSesi _buatSesi(List<RecordModel> run) {
    final first = run.first;
    final namaKelas = first.getStringValue('expand.kelas.nama');
    var namaGuru = first.getStringValue('expand.guru.nama_lengkap');
    if (namaGuru.isEmpty) namaGuru = first.getStringValue('expand.guru.email');
    if (namaGuru.isEmpty) namaGuru = 'Guru Pengampu';

    final jamList = run.map((r) => r.getIntValue('jam_ke')).toList();

    return _JadwalSesi(
      kelasId: first.getStringValue('kelas'),
      namaKelas: namaKelas.isNotEmpty ? namaKelas : 'Tanpa Kelas',
      guruId: first.getStringValue('guru'),
      namaGuru: namaGuru,
      mapel: first.getStringValue('mapel'),
      jamList: jamList,
      records: run,
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = PbService();
    final meId = svc.me?.id;

    // Filter list
    final listTampil = _jadwalList.where((j) {
      if (_hanyaJadwalSaya && meId != null) {
        if (j.getStringValue('guru') != meId) return false;
      }
      if (_filterKelasId != null && _filterKelasId!.isNotEmpty) {
        if (j.getStringValue('kelas') != _filterKelasId) return false;
      }
      if (_cariMapel.isNotEmpty) {
        final m = j.getStringValue('mapel').toLowerCase();
        final g = j.getStringValue('expand.guru.nama_lengkap').toLowerCase();
        final k = j.getStringValue('expand.kelas.nama').toLowerCase();
        final q = _cariMapel.toLowerCase();
        if (!m.contains(q) && !g.contains(q) && !k.contains(q)) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Pelajaran')),
      body: Column(
        children: [
          // Baris Pemilih Hari (Senin - Sabtu)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _daftarHari.map((h) {
                  final aktif = h == _hariTerpilih;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(h),
                      selected: aktif,
                      selectedColor: AppColors.primary,
                      backgroundColor: const Color(0xFFF4F6F5),
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: aktif ? Colors.white : AppColors.ink,
                        fontWeight: aktif ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: aktif ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      onSelected: (sel) {
                        if (sel) {
                          setState(() => _hariTerpilih = h);
                          _muatJadwal();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Baris Filter & Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _cariMapel = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Cari mapel, guru, kelas...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF4F6F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _kelasList.any((k) => k.id == _filterKelasId)
                                ? _filterKelasId
                                : null,
                            hint: Text(
                              'Pilih Kelas',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  'Semua Kelas',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                ),
                              ),
                              ..._kelasList.map(
                                (k) => DropdownMenuItem(
                                  value: k.id,
                                  child: Text(
                                    k.getStringValue('nama'),
                                    style: GoogleFonts.plusJakartaSans(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _filterKelasId = v),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Jadwal Saya'),
                        selected: _hanyaJadwalSaya,
                        selectedColor: AppColors.primarySoft,
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _hanyaJadwalSaya
                              ? AppColors.primaryDark
                              : AppColors.ink,
                        ),
                        onSelected: (val) {
                          setState(() => _hanyaJadwalSaya = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Daftar Jadwal
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muatJadwal,
                    color: AppColors.primary,
                    child: listTampil.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 56,
                                        color: AppColors.grey,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Tidak ada jadwal untuk kriteria ini.',
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
                          )
                        : Builder(
                            builder: (ctx) {
                              final sesiTampil = _kelompokkanJadwal(listTampil);
                              if (sesiTampil.isEmpty) {
                                return ListView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(40),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            const Icon(
                                              Icons.calendar_month_outlined,
                                              size: 56,
                                              color: AppColors.grey,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Tidak ada jadwal untuk kriteria ini.',
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
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: sesiTampil.length,
                                itemBuilder: (_, i) {
                                  final s = sesiTampil[i];

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.line),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${s.labelJam} • ${s.durasiJp} JP • ${s.rentangWaktu}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: AppColors.blue,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primarySoft,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Kelas ${s.namaKelas}',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: AppColors.primaryDark,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          s.mapel,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: AppColors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                s.namaGuru.isNotEmpty
                                                    ? s.namaGuru
                                                    : 'Guru Pengampu',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  color: AppColors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.tonalIcon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => JurnalFormScreen(
                                                    kelasIdAwal: s.kelasId,
                                                    jamAwal: s.jamList.first,
                                                    mapelAwal: s.mapel,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.edit_note_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              s.durasiJp > 1
                                                  ? 'Isi Jurnal (${s.durasiJp} JP)'
                                                  : 'Isi Jurnal Kelas',
                                            ),
                                            style: FilledButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _JadwalSesi {
  final String kelasId;
  final String namaKelas;
  final String guruId;
  final String namaGuru;
  final String mapel;
  final List<int> jamList;
  final List<RecordModel> records;

  _JadwalSesi({
    required this.kelasId,
    required this.namaKelas,
    required this.guruId,
    required this.namaGuru,
    required this.mapel,
    required this.jamList,
    required this.records,
  });

  int get durasiJp => jamList.length;
  int get jamMulai => jamList.isNotEmpty ? jamList.first : 0;
  int get jamSelesai => jamList.isNotEmpty ? jamList.last : 0;

  bool get isConsecutive {
    if (jamList.length <= 1) return true;
    for (int i = 0; i < jamList.length - 1; i++) {
      if (jamList[i + 1] != jamList[i] + 1) return false;
    }
    return true;
  }

  String get labelJam {
    if (jamList.isEmpty) return '-';
    if (jamList.length == 1) return 'Jam ke-${jamList.first}';
    if (isConsecutive) return 'Jam ke-${jamList.first}–${jamList.last}';
    return 'Jam ke-${jamList.join(', ')}';
  }

  String get rentangWaktu {
    if (jamList.isEmpty) return '';
    final mulai = 7 * 60 + (jamMulai - 1) * 45;
    final selesai = 7 * 60 + jamSelesai * 45;
    final fmtMulai =
        '${(mulai ~/ 60).toString().padLeft(2, '0')}:${(mulai % 60).toString().padLeft(2, '0')}';
    final fmtSelesai =
        '${(selesai ~/ 60).toString().padLeft(2, '0')}:${(selesai % 60).toString().padLeft(2, '0')}';
    return '$fmtMulai - $fmtSelesai';
  }
}

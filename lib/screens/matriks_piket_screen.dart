import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'guru_berhalangan_screen.dart';
import 'jurnal_form_screen.dart';

// Matriks Piket: 18 kelas x jam 1-8, status keterisian KBM per jam.
// Hijau = terisi (ada jurnal), merah = kosong (ada jadwal tapi tanpa jurnal),
// kuning = guru berhalangan, abu = tidak ada jadwal.
class MatriksPiketScreen extends StatefulWidget {
  const MatriksPiketScreen({super.key});

  @override
  State<MatriksPiketScreen> createState() => _MatriksPiketScreenState();
}

enum _StatusSel { terisi, kosong, berhalangan, tanpaJadwal }

class _SelInfo {
  final _StatusSel status;
  final String mapel;
  final String guru;
  final String kelasId;
  final String guruId;
  final int jamKe;
  final RecordModel? jurnal;
  final RecordModel? berhalangan;
  _SelInfo(
    this.status,
    this.mapel,
    this.guru, {
    this.kelasId = '',
    this.guruId = '',
    this.jamKe = 0,
    this.jurnal,
    this.berhalangan,
  });
}

class _MatriksPiketScreenState extends State<MatriksPiketScreen> {
  List<RecordModel> _kelas = [];
  Map<String, Map<int, _SelInfo>> _matriks = {};
  bool _loading = true;
  int _terisi = 0;
  int _kosong = 0;
  int _berhalangan = 0;

  static const _jamList = [1, 2, 3, 4, 5, 6, 7, 8];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Set<int> _parseJam(String s) {
    final out = <int>{};
    for (final p in s.split(',')) {
      final v = int.tryParse(p.trim());
      if (v != null && v >= 1 && v <= 8) out.add(v);
    }
    return out;
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final hari = svc.hariIni();
      final tgl = svc.tanggalHariIni();

      final kRes = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      final jRes = await pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 500,
            filter: 'hari = "$hari"',
            expand: 'kelas,guru',
          );
      final juRes = await pb
          .collection('jurnal')
          .getList(
            page: 1,
            perPage: 500,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
          );
      final Map<String, RecordModel> berhalangan = {};
      try {
        final bRes = await pb
            .collection('guru_berhalangan')
            .getList(
              page: 1,
              perPage: 200,
              filter: 'tanggal ~ "$tgl"',
              expand: 'guru_pengganti',
            );
        for (final b in bRes.items) {
          final g = b.getStringValue('guru');
          if (g.isNotEmpty) berhalangan.putIfAbsent(g, () => b);
        }
      } catch (_) {}

      // jurnal per (kelas, jam) agar sel bisa CRUD
      final jurnalPerSel = <String, Map<int, RecordModel>>{};
      for (final ju in juRes.items) {
        final kId = ju.getStringValue('kelas');
        if (kId.isEmpty) continue;
        for (final jm in _parseJam(ju.getStringValue('jam'))) {
          jurnalPerSel.putIfAbsent(kId, () => {})[jm] = ju;
        }
      }

      final matriks = <String, Map<int, _SelInfo>>{};
      var terisi = 0, kosong = 0, halangan = 0;
      for (final k in kRes.items) {
        final perJam = <int, _SelInfo>{};
        for (final jamKe in _jamList) {
          RecordModel? jadwal;
          for (final j in jRes.items) {
            if (j.getStringValue('kelas') == k.id &&
                j.getIntValue('jam_ke') == jamKe) {
              jadwal = j;
              break;
            }
          }
          if (jadwal == null) {
            perJam[jamKe] = _SelInfo(
              _StatusSel.tanpaJadwal,
              '',
              '',
              kelasId: k.id,
              jamKe: jamKe,
            );
            continue;
          }
          final mapel = jadwal.getStringValue('mapel');
          var guru = jadwal.getStringValue('expand.guru.nama_lengkap');
          if (guru.isEmpty) guru = jadwal.getStringValue('expand.guru.email');
          final guruId = jadwal.getStringValue('guru');
          final ju = jurnalPerSel[k.id]?[jamKe];
          final bh = guruId.isNotEmpty ? berhalangan[guruId] : null;
          if (ju != null) {
            perJam[jamKe] = _SelInfo(
              _StatusSel.terisi,
              mapel,
              guru,
              kelasId: k.id,
              guruId: guruId,
              jamKe: jamKe,
              jurnal: ju,
            );
            terisi++;
          } else if (bh != null) {
            perJam[jamKe] = _SelInfo(
              _StatusSel.berhalangan,
              mapel,
              guru,
              kelasId: k.id,
              guruId: guruId,
              jamKe: jamKe,
              berhalangan: bh,
            );
            halangan++;
          } else {
            perJam[jamKe] = _SelInfo(
              _StatusSel.kosong,
              mapel,
              guru,
              kelasId: k.id,
              guruId: guruId,
              jamKe: jamKe,
            );
            kosong++;
          }
        }
        matriks[k.id] = perJam;
      }

      setState(() {
        _kelas = kRes.items;
        _matriks = matriks;
        _terisi = terisi;
        _kosong = kosong;
        _berhalangan = halangan;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _warnaSel(_StatusSel s) {
    switch (s) {
      case _StatusSel.terisi:
        return const Color(0xFFD1FAE5);
      case _StatusSel.kosong:
        return const Color(0xFFFDE8E8);
      case _StatusSel.berhalangan:
        return const Color(0xFFFEF3C7);
      case _StatusSel.tanpaJadwal:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _warnaTeks(_StatusSel s) {
    switch (s) {
      case _StatusSel.terisi:
        return const Color(0xFF065F46);
      case _StatusSel.kosong:
        return AppColors.red;
      case _StatusSel.berhalangan:
        return const Color(0xFF92400E);
      case _StatusSel.tanpaJadwal:
        return AppColors.grey;
    }
  }

  String _labelSel(_StatusSel s) {
    switch (s) {
      case _StatusSel.terisi:
        return '✓';
      case _StatusSel.kosong:
        return '!';
      case _StatusSel.berhalangan:
        return '±';
      case _StatusSel.tanpaJadwal:
        return '–';
    }
  }

  String _labelStatus(_StatusSel s) => switch (s) {
    _StatusSel.terisi => 'Terisi — sudah ada jurnal',
    _StatusSel.kosong => 'Kosong — belum ada jurnal',
    _StatusSel.berhalangan => 'Guru berhalangan',
    _StatusSel.tanpaJadwal => 'Tidak ada jadwal',
  };

  /// Bottom sheet info sel + aksi CRUD sesuai status & role.
  Future<void> _aksiSel(String namaKelas, _SelInfo info) async {
    final svc = PbService();
    final canBerhalangan = svc.canKelolaBerhalangan;
    final canHapusJurnal = svc.isAdmin || svc.isPiket;
    final bh = info.berhalangan;
    var pengganti = bh?.getStringValue('expand.guru_pengganti.nama_lengkap') ?? '';
    if (pengganti.isEmpty) {
      pengganti = bh?.getStringValue('expand.guru_pengganti.email') ?? '';
    }
    final linkTugas = bh?.getStringValue('link_tugas') ?? '';

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kelas $namaKelas • Jam ${info.jamKe}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _warnaSel(info.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _labelStatus(info.status).split(' — ').first,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _warnaTeks(info.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (info.mapel.isNotEmpty) _baris('Mapel', info.mapel),
              if (info.guru.isNotEmpty) _baris('Guru', info.guru),
              if (bh != null) ...[
                _baris('Status', bh.getStringValue('status')),
                if (pengganti.isNotEmpty)
                  _baris('Pengganti', pengganti),
                if (bh.getStringValue('keterangan').isNotEmpty)
                  _baris('Keterangan', bh.getStringValue('keterangan')),
                if (linkTugas.isNotEmpty)
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(
                        linkTugas.startsWith('http')
                            ? linkTugas
                            : 'https://$linkTugas',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 64),
                          const Icon(
                            Icons.link_outlined,
                            size: 14,
                            color: AppColors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Buka tugas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (info.jurnal != null &&
                  info.jurnal!.getStringValue('materi').isNotEmpty)
                _baris('Materi', info.jurnal!.getStringValue('materi')),
              const SizedBox(height: 8),
              // Aksi CRUD
              if (info.status == _StatusSel.kosong) ...[
                _Aksi(
                  icon: Icons.edit_note_outlined,
                  label: 'Isi Jurnal',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JurnalFormScreen(
                          kelasIdAwal: info.kelasId,
                        ),
                      ),
                    );
                    _muat();
                  },
                ),
                if (canBerhalangan && info.guruId.isNotEmpty)
                  _Aksi(
                    icon: Icons.person_off_outlined,
                    label: 'Tandai Guru Berhalangan',
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormBerhalangan(
                            guruIdAwal: info.guruId,
                          ),
                        ),
                      );
                      _muat();
                    },
                  ),
              ],
              if (info.status == _StatusSel.terisi && canHapusJurnal)
                _Aksi(
                  icon: Icons.delete_outline,
                  label: 'Hapus Jurnal',
                  merah: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Hapus Jurnal'),
                        content: Text(
                          'Hapus jurnal kelas $namaKelas jam ${info.jamKe}?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Hapus',
                              style: TextStyle(color: AppColors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && info.jurnal != null) {
                      try {
                        await svc.pb
                            .collection('jurnal')
                            .delete(info.jurnal!.id);
                        _muat();
                      } catch (_) {}
                    }
                  },
                ),
              if (info.status == _StatusSel.berhalangan && canBerhalangan) ...[
                _Aksi(
                  icon: Icons.edit_outlined,
                  label: 'Ubah Catatan Berhalangan',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FormBerhalangan(existing: info.berhalangan),
                      ),
                    );
                    _muat();
                  },
                ),
                _Aksi(
                  icon: Icons.delete_outline,
                  label: 'Hapus Catatan Berhalangan',
                  merah: true,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Hapus Catatan'),
                        content: const Text(
                          'Hapus catatan berhalangan ini?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Hapus',
                              style: TextStyle(color: AppColors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && info.berhalangan != null) {
                      try {
                        await svc.pb
                            .collection('guru_berhalangan')
                            .delete(info.berhalangan!.id);
                        _muat();
                      } catch (_) {}
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baris(String label, String nilai) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.grey,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            nilai,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    const lebarSel = 52.0;
    const lebarKelas = 76.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Matriks Piket')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatMini(
                          angka: '$_terisi',
                          label: 'Terisi',
                          warna: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatMini(
                          angka: '$_kosong',
                          label: 'Kosong',
                          warna: AppColors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatMini(
                          angka: '$_berhalangan',
                          label: 'Berhalangan',
                          warna: const Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: const [
                      _Legenda('Terisi', Color(0xFFD1FAE5)),
                      _Legenda('Kosong', Color(0xFFFDE8E8)),
                      _Legenda('Berhalangan', Color(0xFFFEF3C7)),
                      _Legenda('Tanpa jadwal', Color(0xFFF3F4F6)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: lebarKelas),
                            for (final j in _jamList)
                              Container(
                                width: lebarSel,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  '$j',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        for (var i = 0; i < _kelas.length; i++)
                          Builder(
                            builder: (_) {
                              final k = _kelas[i];
                              final namaKelas = k.getStringValue('nama');
                              return Row(
                                children: [
                                  SizedBox(
                                    width: lebarKelas,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        namaKelas,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final j in _jamList)
                                    Builder(
                                      builder: (_) {
                                        final info =
                                            _matriks[k.id]?[j] ??
                                            _SelInfo(
                                              _StatusSel.tanpaJadwal,
                                              '',
                                              '',
                                            );
                                        return GestureDetector(
                                          onTap: () =>
                                              _aksiSel(namaKelas, info),
                                          child: Container(
                                            width: lebarSel,
                                            height: 40,
                                            margin: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: _warnaSel(info.status),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _labelSel(info.status),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: _warnaTeks(
                                                      info.status,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ).animate().fadeIn(
                                delay: Duration(milliseconds: i * 30),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ketuk sel untuk detail. Data jadwal & jurnal hari ${PbService().hariIni()}.',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Baris aksi di bottom sheet sel matriks.
class _Aksi extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool merah;
  final VoidCallback onTap;
  const _Aksi({
    required this.icon,
    required this.label,
    required this.onTap,
    this.merah = false,
  });

  @override
  Widget build(BuildContext context) {
    final warna = merah ? AppColors.red : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: warna),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: warna,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
        onTap: onTap,
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String angka;
  final String label;
  final Color warna;
  const _StatMini({
    required this.angka,
    required this.label,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            angka,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: warna,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final String label;
  final Color warna;
  const _Legenda(this.label, this.warna);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: warna,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }
}

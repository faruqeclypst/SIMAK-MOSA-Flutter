import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'riwayat_screen.dart';

// Form isi jurnal: pilih kelas, absensi per siswa (dengan badge izin
// otomatis dari data piket/asrama hari ini), jam multi-select,
// materi + catatan wajib, lalu simpan ke PocketBase.
class JurnalFormScreen extends StatefulWidget {
  final String? kelasIdAwal;
  const JurnalFormScreen({super.key, this.kelasIdAwal});

  @override
  State<JurnalFormScreen> createState() => _JurnalFormScreenState();
}

class _JurnalFormScreenState extends State<JurnalFormScreen> {
  static const _statusList = ['Hadir', 'Sakit', 'Izin', 'Alpa'];

  List<RecordModel> _kelasList = [];
  String? _kelasId;
  List<RecordModel> _siswa = [];
  RecordModel? _jurnalAda;
  final Map<String, String> _absensi = {};
  Map<String, String> _badgeIzin = {};
  final Set<int> _jamTerpilih = {};
  final _materiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _cari = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _materiCtrl.dispose();
    _catatanCtrl.dispose();
    _cari.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final pb = PbService().pb;
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      setState(() {
        _kelasList = k.items;
        _kelasId =
            widget.kelasIdAwal ??
            (k.items.isNotEmpty ? k.items.first.id : null);
        _loading = false;
      });
      if (_kelasId != null) _muatSiswa();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _muatSiswa() async {
    setState(() {
      _loading = true;
      _jurnalAda = null;
    });
    try {
      final pb = PbService().pb;
      final tgl = PbService().tanggalHariIni();
      final s = await pb
          .collection('siswa')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'kelas = "$_kelasId"',
            sort: 'nama',
          );
      // Badge otomatis: izin piket & laporan asrama hari ini
      final badge = <String, String>{};
      final piket = await pb
          .collection('izin_piket')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            expand: 'siswa',
          );
      for (final p in piket.items) {
        final swId = p.getStringValue('siswa');
        if (swId.isNotEmpty) {
          badge[swId] = 'Izin piket: ${p.getStringValue('keterangan')}';
        }
      }
      final asrama = await pb
          .collection('asrama')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            expand: 'siswa',
          );
      for (final a in asrama.items) {
        final swId = a.getStringValue('siswa');
        if (swId.isNotEmpty) {
          badge[swId] =
              'Asrama: ${a.getStringValue('jenis')} ${a.getStringValue('keterangan')}'
                  .trim();
        }
      }
      // Keterlambatan (satpam/PKD) hari ini: info saja, status tetap Hadir
      try {
        final telat = await pb
            .collection('keterlambatan')
            .getList(
              page: 1,
              perPage: 200,
              filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            );
        for (final t in telat.items) {
          final swId = t.getStringValue('siswa');
          if (swId.isNotEmpty && !badge.containsKey(swId)) {
            final jam = t.getStringValue('jam_datang');
            badge[swId] =
                'Terlambat datang${jam.isEmpty ? '' : ' jam $jam'}';
          }
        }
      } catch (_) {}
      setState(() {
        _siswa = s.items;
        _badgeIzin = badge;
        _absensi.clear();
        for (final sw in s.items) {
          _absensi[sw.id] = _statusOtomatis(badge[sw.id]);
        }
        _loading = false;
      });
      await _cekJurnalAda();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  /// Cek apakah saya sudah mengisi jurnal kelas ini hari ini.
  /// Kalau ada -> mode update (prefill + simpan menimpa, bukan duplikat).
  Future<void> _cekJurnalAda() async {
    if (_kelasId == null) return;
    try {
      final svc = PbService();
      final pb = svc.pb;
      final tgl = svc.tanggalHariIni();
      final res = await pb
          .collection('jurnal')
          .getList(
            page: 1,
            perPage: 1,
            filter:
                'kelas = "$_kelasId" && guru = "${svc.me!.id}" && '
                'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            sort: '-created',
          );
      if (res.items.isEmpty) {
        if (mounted) setState(() => _jurnalAda = null);
        return;
      }
      final j = res.items.first;
      final abs = await pb
          .collection('absensi')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'jurnal = "${j.id}"',
          );
      if (!mounted) return;
      setState(() {
        _jurnalAda = j;
        _materiCtrl.text = j.getStringValue('materi');
        _catatanCtrl.text = j.getStringValue('catatan');
        _jamTerpilih.clear();
        _jamTerpilih.addAll(_parseJam(j.getStringValue('jam')));
        for (final a in abs.items) {
          final st = a.getStringValue('status');
          if (st.isNotEmpty) _absensi[a.getStringValue('siswa')] = st;
        }
      });
    } catch (_) {}
  }

  /// Status awal dari badge otomatis:
  /// - Izin piket -> Izin
  /// - Asrama: Sakit -> Sakit, Izin Pulang/Keluarga -> Izin,
  ///   Tanpa Keterangan -> Alpa, Lainnya -> Izin
  /// - Terlambat -> tetap Hadir (hanya info)
  String _statusOtomatis(String? badge) {
    if (badge == null) return 'Hadir';
    if (badge.startsWith('Izin piket')) return 'Izin';
    if (badge.startsWith('Asrama:')) {
      final jenis = badge.replaceFirst('Asrama:', '').trim();
      if (jenis.startsWith('Sakit')) return 'Sakit';
      if (jenis.startsWith('Tanpa Keterangan')) return 'Alpa';
      if (jenis.startsWith('Izin')) return 'Izin';
      return 'Izin';
    }
    return 'Hadir';
  }

  Set<int> _parseJam(String s) {
    final out = <int>{};
    for (final p in s.split(',')) {
      final v = int.tryParse(p.trim());
      if (v != null && v >= 1 && v <= 8) out.add(v);
    }
    return out;
  }

  Map<String, int> _hitungan() {
    final h = {for (final s in _statusList) s: 0};
    for (final sw in _siswa) {
      final st = _absensi[sw.id] ?? 'Hadir';
      h[st] = (h[st] ?? 0) + 1;
    }
    return h;
  }

  List<RecordModel> _siswaTampil() {
    final q = _cari.text.trim().toLowerCase();
    if (q.isEmpty) return _siswa;
    return _siswa
        .where((sw) => sw.getStringValue('nama').toLowerCase().contains(q))
        .toList();
  }

  String _inisial(String nama) {
    final p = nama.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.first.toUpperCase();
    return (p.first.characters.first + p[1].characters.first).toUpperCase();
  }

  Future<void> _simpan() async {
    if (_kelasId == null) return;
    if (_jamTerpilih.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu jam pelajaran.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final jam = _jamTerpilih.toList()..sort();
      final tgl = svc.tanggalHariIni();
      final isUpdate = _jurnalAda != null;

      final String jurnalId;
      if (isUpdate) {
        // Update jurnal yang sudah ada: cegah duplikasi.
        jurnalId = _jurnalAda!.id;
        await pb
            .collection('jurnal')
            .update(
              jurnalId,
              body: {
                'jam': jam.join(','),
                'materi': _materiCtrl.text.trim(),
                'catatan': _catatanCtrl.text.trim(),
              },
            );
        // Upsert absensi: update yang ada, buat yang belum ada.
        final ada = await pb
            .collection('absensi')
            .getList(
              page: 1,
              perPage: 300,
              filter: 'jurnal = "$jurnalId"',
            );
        final peta = {
          for (final a in ada.items) a.getStringValue('siswa'): a.id,
        };
        for (final sw in _siswa) {
          final body = {
            'status': _absensi[sw.id] ?? 'Hadir',
            'keterangan': _badgeIzin[sw.id] ?? '',
          };
          final idLama = peta[sw.id];
          if (idLama != null) {
            await pb.collection('absensi').update(idLama, body: body);
          } else {
            await pb
                .collection('absensi')
                .create(
                  body: {'jurnal': jurnalId, 'siswa': sw.id, ...body},
                );
          }
        }
      } else {
        final jurnal = await pb
            .collection('jurnal')
            .create(
              body: {
                'tanggal': '$tgl 12:00:00',
                'kelas': _kelasId,
                'guru': svc.me!.id,
                'jam': jam.join(','),
                'materi': _materiCtrl.text.trim(),
                'catatan': _catatanCtrl.text.trim(),
              },
            );
        jurnalId = jurnal.id;
        for (final sw in _siswa) {
          await pb
              .collection('absensi')
              .create(
                body: {
                  'jurnal': jurnalId,
                  'siswa': sw.id,
                  'status': _absensi[sw.id] ?? 'Hadir',
                  'keterangan': _badgeIzin[sw.id] ?? '',
                },
              );
        }
      }

      if (!mounted) return;
      final namaKelas = _kelasList
          .firstWhere((k) => k.id == _kelasId, orElse: () => _kelasList.first)
          .getStringValue('nama');
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(isUpdate ? 'Jurnal Diperbarui' : 'Jurnal Tersimpan'),
          content: Text(
            'Kelas $namaKelas, jam ke-${jam.join(', ')}.\n'
            'Materi: ${_materiCtrl.text}\n'
            '${_siswa.length} data absensi tercatat.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop(); // tutup dialog
                nav.pop(); // tutup form
                nav.push(
                  MaterialPageRoute(builder: (_) => const RiwayatScreen()),
                );
              },
              child: const Text('Lihat Riwayat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan jurnal. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hitung = _hitungan();
    final tampil = _siswaTampil();
    return Scaffold(
      appBar: AppBar(title: const Text('Isi Jurnal Kelas')),
      bottomNavigationBar: _BarSimpan(
        hitung: hitung,
        saving: _saving,
        bisaSimpan: _kelasId != null && _siswa.isNotEmpty,
        isUpdate: _jurnalAda != null,
        onSimpan: _simpan,
      ),
      body: _loading && _siswa.isEmpty && _kelasList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_jurnalAda != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: AppColors.blue.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Jurnal hari ini sudah ada. Menyimpan akan memperbarui, bukan membuat baru.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.ink,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Kartu kelas + jam: satu kesatuan "kapan & di mana"
                  _Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _JudulSeksi('Kelas', Icons.meeting_room_outlined),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _kelasId,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          items: _kelasList
                              .map(
                                (k) => DropdownMenuItem(
                                  value: k.id,
                                  child: Text(
                                    'Kelas ${k.getStringValue('nama')}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() => _kelasId = v);
                            _muatSiswa();
                          },
                        ),
                        const Divider(height: 20),
                        _JudulSeksi('Jam Pelajaran', Icons.schedule_outlined),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(8, (i) => i + 1).map((j) {
                            final aktif = _jamTerpilih.contains(j);
                            return GestureDetector(
                              onTap: () => setState(() {
                                aktif
                                    ? _jamTerpilih.remove(j)
                                    : _jamTerpilih.add(j);
                              }),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: aktif
                                      ? AppColors.primary
                                      : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$j',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: aktif
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Kartu materi
                  _Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _JudulSeksi('Materi & Catatan', Icons.edit_note_outlined),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _materiCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Materi hari ini, mis. Limit fungsi aljabar',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Materi wajib diisi.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Catatan/kendala (isi Aman bila tidak ada)',
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Catatan wajib diisi.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Kepala absensi: judul + hitungan + aksi
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Absensi (${_siswa.length})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _siswa.isEmpty
                            ? null
                            : () => setState(() {
                                for (final sw in _siswa) {
                                  _absensi[sw.id] = 'Hadir';
                                }
                              }),
                        child: const Text('Semua Hadir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _HitunganAbsensi(hitung: hitung),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cari,
                    decoration: const InputDecoration(
                      hintText: 'Cari nama siswa',
                      prefixIcon: Icon(Icons.search_outlined),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (tampil.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _siswa.isEmpty
                            ? 'Pilih kelas untuk memuat daftar siswa.'
                            : 'Tidak ada siswa yang cocok.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  else
                    ...tampil.map((sw) {
                      final nama = sw.getStringValue('nama');
                      final badge = _badgeIzin[sw.id];
                      final status = _absensi[sw.id] ?? 'Hadir';
                      return _BarisSiswa(
                        nama: nama,
                        inisial: _inisial(nama),
                        badge: badge,
                        status: status,
                        onPilih: (s) =>
                            setState(() => _absensi[sw.id] = s),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

/// Kartu putih pembungkus seksi form.
class _Kartu extends StatelessWidget {
  final Widget child;
  const _Kartu({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// Judul seksi kecil dengan ikon.
class _JudulSeksi extends StatelessWidget {
  final String teks;
  final IconData icon;
  const _JudulSeksi(this.teks, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          teks,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.grey,
          ),
        ),
      ],
    );
  }
}

/// Ringkasan hitungan absensi: titik warna + angka per status.
class _HitunganAbsensi extends StatelessWidget {
  final Map<String, int> hitung;
  const _HitunganAbsensi({required this.hitung});

  Color _warna(String s) {
    switch (s) {
      case 'Hadir':
        return AppColors.primary;
      case 'Sakit':
        return AppColors.amber;
      case 'Izin':
        return AppColors.blue;
      default:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: hitung.entries.map((e) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _warna(e.key),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${e.key} ${e.value}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// Satu baris siswa: avatar + nama + badge + segmen status H/S/I/A.
class _BarisSiswa extends StatelessWidget {
  final String nama;
  final String inisial;
  final String? badge;
  final String status;
  final ValueChanged<String> onPilih;
  const _BarisSiswa({
    required this.nama,
    required this.inisial,
    required this.badge,
    required this.status,
    required this.onPilih,
  });

  static const _pendek = {
    'Hadir': 'H',
    'Sakit': 'S',
    'Izin': 'I',
    'Alpa': 'A',
  };

  Color _warna(String s) {
    switch (s) {
      case 'Hadir':
        return AppColors.primary;
      case 'Sakit':
        return AppColors.amber;
      case 'Izin':
        return AppColors.blue;
      default:
        return AppColors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              inisial,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (badge != null)
                  Text(
                    badge!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.primaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _pendek.entries.map((e) {
                final aktif = status == e.key;
                return GestureDetector(
                  onTap: () => onPilih(e.key),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: aktif ? _warna(e.key) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      e.value,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: aktif ? Colors.white : AppColors.grey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar bawah sticky: ringkasan + tombol simpan.
class _BarSimpan extends StatelessWidget {
  final Map<String, int> hitung;
  final bool saving;
  final bool bisaSimpan;
  final bool isUpdate;
  final VoidCallback onSimpan;
  const _BarSimpan({
    required this.hitung,
    required this.saving,
    required this.bisaSimpan,
    required this.isUpdate,
    required this.onSimpan,
  });

  @override
  Widget build(BuildContext context) {
    final hadir = hitung['Hadir'] ?? 0;
    final total = hitung.values.fold(0, (a, b) => a + b);
    final takHadir = total - hadir;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$hadir dari $total hadir',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  if (takHadir > 0)
                    Text(
                      '$takHadir tidak hadir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.grey,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: (!bisaSimpan || saving) ? null : onSimpan,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                saving ? 'Menyimpan' : (isUpdate ? 'Update Jurnal' : 'Simpan Jurnal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

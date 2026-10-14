import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'riwayat_screen.dart';

/// Form isi jurnal mengajar:
/// - Pilih kelas & jam multi-select (dengan prefill otomatis dari jadwal/pengingat)
/// - Mode Edit Jurnal langsung dengan ID jurnal atau deteksi jurnal hari ini
/// - Absensi siswa lengkap dengan badge izin piket/asrama/keterlambatan
/// - Catatan cepat & materi dengan validasi interaktif dan auto-scroll
/// - Konfirmasi simpan dengan pilihan "Selesai" atau "Lihat Riwayat" serta auto-refresh ke layar pemanggil
class JurnalFormScreen extends StatefulWidget {
  final String? kelasIdAwal;
  final int? jamAwal;
  final String? materiAwal;
  final String? editJurnalId;

  const JurnalFormScreen({
    super.key,
    this.kelasIdAwal,
    this.jamAwal,
    this.materiAwal,
    this.editJurnalId,
  });

  @override
  State<JurnalFormScreen> createState() => _JurnalFormScreenState();
}

class _JurnalFormScreenState extends State<JurnalFormScreen> {
  static const _statusList = ['Hadir', 'Sakit', 'Izin', 'Alpa'];
  static const _saranCatatan = [
    'KBM Lancar',
    'Aman',
    'Ulangan Harian',
    'Praktikum',
    'Tugas Kelompok',
  ];

  List<RecordModel> _kelasList = [];
  String? _kelasId;
  List<RecordModel> _siswa = [];
  RecordModel? _jurnalAda;
  final Map<String, String> _absensi = {};
  final Map<String, String> _keteranganSiswa = {};
  Map<String, String> _badgeIzin = {};
  final Set<int> _jamTerpilih = {};
  final _materiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _cari = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.jamAwal != null && widget.jamAwal! >= 1 && widget.jamAwal! <= 8) {
      _jamTerpilih.add(widget.jamAwal!);
    }
    if (widget.materiAwal != null && widget.materiAwal!.isNotEmpty) {
      _materiCtrl.text = widget.materiAwal!;
    }
    _init();
  }

  @override
  void dispose() {
    _materiCtrl.dispose();
    _catatanCtrl.dispose();
    _cari.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final pb = PbService().pb;
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');

      if (!mounted) return;
      setState(() {
        _kelasList = k.items;
      });

      // Jika membuka mode edit jurnal spesifik (misal dari Riwayat)
      if (widget.editJurnalId != null && widget.editJurnalId!.isNotEmpty) {
        await _muatJurnalSpesifik(widget.editJurnalId!);
        return;
      }

      // Mode normal / dari jadwal
      String? targetKelas = widget.kelasIdAwal;
      if (targetKelas == null || !_kelasList.any((item) => item.id == targetKelas)) {
        targetKelas = _kelasList.isNotEmpty ? _kelasList.first.id : null;
      }

      setState(() {
        _kelasId = targetKelas;
        _loading = false;
      });

      if (_kelasId != null) {
        await _muatSiswa();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Muat data jurnal spesifik saat diedit dari Riwayat
  Future<void> _muatJurnalSpesifik(String jurnalId) async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final j = await pb.collection('jurnal').getOne(jurnalId, expand: 'kelas,guru');
      final kelasId = j.getStringValue('kelas');

      _jurnalAda = j;
      _kelasId = kelasId;
      _materiCtrl.text = j.getStringValue('materi');
      _catatanCtrl.text = j.getStringValue('catatan');
      _jamTerpilih.clear();
      _jamTerpilih.addAll(_parseJam(j.getStringValue('jam')));

      // Muat daftar siswa kelas tersebut
      final s = await pb.collection('siswa').getList(
            page: 1,
            perPage: 200,
            filter: 'kelas = "$kelasId"',
            sort: 'nama',
          );

      // Muat absensi yang sudah tercatat
      final abs = await pb.collection('absensi').getList(
            page: 1,
            perPage: 300,
            filter: 'jurnal = "$jurnalId"',
          );

      _absensi.clear();
      _keteranganSiswa.clear();
      for (final sw in s.items) {
        _absensi[sw.id] = 'Hadir';
      }
      for (final a in abs.items) {
        final swId = a.getStringValue('siswa');
        final st = a.getStringValue('status');
        final ket = a.getStringValue('keterangan');
        if (swId.isNotEmpty) {
          if (st.isNotEmpty) _absensi[swId] = st;
          if (ket.isNotEmpty) _keteranganSiswa[swId] = ket;
        }
      }

      if (mounted) {
        setState(() {
          _siswa = s.items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _muatSiswa() async {
    if (_kelasId == null) return;
    setState(() {
      _loading = true;
      _jurnalAda = null;
    });

    try {
      final pb = PbService().pb;
      final tgl = PbService().tanggalHariIni();
      final s = await pb.collection('siswa').getList(
            page: 1,
            perPage: 200,
            filter: 'kelas = "$_kelasId"',
            sort: 'nama',
          );

      // Badge otomatis: izin piket & laporan asrama hari ini
      final badge = <String, String>{};
      final piket = await pb.collection('izin_piket').getList(
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

      final asrama = await pb.collection('asrama').getList(
            page: 1,
            perPage: 200,
            filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            expand: 'siswa',
          );
      for (final a in asrama.items) {
        final swId = a.getStringValue('siswa');
        if (swId.isNotEmpty) {
          badge[swId] =
              'Asrama: ${a.getStringValue('jenis')} ${a.getStringValue('keterangan')}'.trim();
        }
      }

      // Keterlambatan hari ini: info saja, status tetap Hadir
      try {
        final telat = await pb.collection('keterlambatan').getList(
              page: 1,
              perPage: 200,
              filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            );
        for (final t in telat.items) {
          final swId = t.getStringValue('siswa');
          if (swId.isNotEmpty && !badge.containsKey(swId)) {
            final jam = t.getStringValue('jam_datang');
            badge[swId] = 'Terlambat datang${jam.isEmpty ? '' : ' jam $jam'}';
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _siswa = s.items;
        _badgeIzin = badge;
        _absensi.clear();
        for (final sw in s.items) {
          _absensi[sw.id] = _statusOtomatis(badge[sw.id]);
          if (badge[sw.id] != null) {
            _keteranganSiswa[sw.id] = badge[sw.id]!;
          }
        }
        _loading = false;
      });

      await _cekJurnalAda();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Cek apakah saya sudah mengisi jurnal kelas ini hari ini.
  /// Kalau ada -> mode update (prefill data).
  Future<void> _cekJurnalAda() async {
    if (_kelasId == null) return;
    try {
      final svc = PbService();
      final pb = svc.pb;
      final tgl = svc.tanggalHariIni();
      final meId = svc.me?.id;
      if (meId == null) return;

      final res = await pb.collection('jurnal').getList(
            page: 1,
            perPage: 1,
            filter:
                'kelas = "$_kelasId" && guru = "$meId" && tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
            sort: '-created',
          );

      if (res.items.isEmpty) {
        if (mounted) {
          setState(() {
            _jurnalAda = null;
          });
        }
        return;
      }

      final j = res.items.first;
      final abs = await pb.collection('absensi').getList(
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
          final swId = a.getStringValue('siswa');
          final ket = a.getStringValue('keterangan');
          if (st.isNotEmpty) _absensi[swId] = st;
          if (ket.isNotEmpty) _keteranganSiswa[swId] = ket;
        }
      });
    } catch (_) {}
  }

  String _statusOtomatis(String? badge) {
    if (badge == null) return 'Hadir';
    if (badge.startsWith('Izin piket')) {
      if (badge.toLowerCase().contains('sakit')) return 'Sakit';
      return 'Izin';
    }
    if (badge.startsWith('Asrama:')) {
      final jenis = badge.replaceFirst('Asrama:', '').trim().toLowerCase();
      if (jenis.startsWith('sakit')) return 'Sakit';
      if (jenis.startsWith('tanpa keterangan')) return 'Alpa';
      if (jenis.startsWith('izin')) return 'Izin';
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
    final c1 = p.first.characters.isNotEmpty ? p.first.characters.first : '?';
    final c2 = p[1].characters.isNotEmpty ? p[1].characters.first : '';
    return (c1 + c2).toUpperCase();
  }

  void _editKeteranganSiswa(RecordModel sw) {
    final nama = sw.getStringValue('nama');
    final currentKet = _keteranganSiswa[sw.id] ?? _badgeIzin[sw.id] ?? '';
    final ctrl = TextEditingController(text: currentKet);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Catatan Siswa: $nama',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'mis. Sakit flu di UKS / Izin OSN',
            labelText: 'Keterangan Tambahan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                final text = ctrl.text.trim();
                if (text.isEmpty) {
                  _keteranganSiswa.remove(sw.id);
                } else {
                  _keteranganSiswa[sw.id] = text;
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _simpan() async {
    if (_kelasId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kelas terlebih dahulu.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (_jamTerpilih.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu jam pelajaran.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Materi & catatan wajib diisi. Silakan lengkapi form di atas.'),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final jam = _jamTerpilih.toList()..sort();
      final tgl = svc.tanggalHariIni();
      final isUpdate = _jurnalAda != null;

      final String jurnalId;
      if (isUpdate) {
        jurnalId = _jurnalAda!.id;
        await pb.collection('jurnal').update(
          jurnalId,
          body: {
            'jam': jam.join(','),
            'materi': _materiCtrl.text.trim(),
            'catatan': _catatanCtrl.text.trim(),
          },
        );

        final ada = await pb.collection('absensi').getList(
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
            'keterangan': _keteranganSiswa[sw.id] ?? _badgeIzin[sw.id] ?? '',
          };
          final idLama = peta[sw.id];
          if (idLama != null) {
            await pb.collection('absensi').update(idLama, body: body);
          } else {
            await pb.collection('absensi').create(
              body: {'jurnal': jurnalId, 'siswa': sw.id, ...body},
            );
          }
        }
      } else {
        final jurnal = await pb.collection('jurnal').create(
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
          await pb.collection('absensi').create(
            body: {
              'jurnal': jurnalId,
              'siswa': sw.id,
              'status': _absensi[sw.id] ?? 'Hadir',
              'keterangan': _keteranganSiswa[sw.id] ?? _badgeIzin[sw.id] ?? '',
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
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text(
                isUpdate ? 'Jurnal Diperbarui' : 'Jurnal Tersimpan',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'Kelas $namaKelas, jam ke-${jam.join(', ')}.\n'
            'Materi: ${_materiCtrl.text.trim()}\n'
            '${_siswa.length} data absensi berhasil dicatat.',
            style: GoogleFonts.plusJakartaSans(height: 1.5),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context, true); // Kembali dengan hasil sukses
              },
              child: const Text('Selesai'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context, true);
                Navigator.push(
                  context,
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
          const SnackBar(
            content: Text('Gagal menyimpan jurnal. Periksa koneksi internet.'),
            backgroundColor: AppColors.red,
          ),
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
    final kelasVal = _kelasList.any((k) => k.id == _kelasId) ? _kelasId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editJurnalId != null ? 'Edit Jurnal Mengajar' : 'Isi Jurnal Kelas'),
      ),
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
                controller: _scrollCtrl,
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
                              widget.editJurnalId != null
                                  ? 'Mode Edit: Mengubah data jurnal yang sudah tersimpan.'
                                  : 'Jurnal hari ini sudah ada. Menyimpan akan memperbarui data.',
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

                  // Bagian 1: Kelas & Jam Pelajaran
                  _Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _JudulSeksi('Kelas', Icons.meeting_room_outlined),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(kelasVal),
                          initialValue: kelasVal,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          hint: const Text('Pilih Kelas'),
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
                          onChanged: widget.editJurnalId != null
                              ? null // Kunci kelas jika mengedit jurnal yang sudah ada
                              : (v) {
                                  if (v == null || v == _kelasId) return;
                                  setState(() {
                                    _kelasId = v;
                                    _siswa = [];
                                    _absensi.clear();
                                    _keteranganSiswa.clear();
                                    _badgeIzin.clear();
                                    _materiCtrl.clear();
                                    _catatanCtrl.clear();
                                    _jamTerpilih.clear();
                                    if (widget.jamAwal != null) {
                                      _jamTerpilih.add(widget.jamAwal!);
                                    }
                                    if (widget.materiAwal != null) {
                                      _materiCtrl.text = widget.materiAwal!;
                                    }
                                  });
                                  _muatSiswa();
                                },
                        ),
                        const Divider(height: 20),
                        const _JudulSeksi('Jam Pelajaran', Icons.schedule_outlined),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(8, (i) => i + 1).map((j) {
                            final aktif = _jamTerpilih.contains(j);
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() {
                                aktif
                                    ? _jamTerpilih.remove(j)
                                    : _jamTerpilih.add(j);
                              }),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: aktif
                                      ? AppColors.primary
                                      : AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: aktif
                                        ? AppColors.primaryDark
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  '$j',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
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

                  // Bagian 2: Materi & Catatan
                  _Kartu(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _JudulSeksi('Materi & Catatan', Icons.edit_note_outlined),
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Catatan / kendala KBM',
                            prefixIcon: Icon(Icons.sticky_note_2_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Catatan wajib diisi.'
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _saranCatatan.map((s) {
                            return ActionChip(
                              label: Text(s),
                              labelStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDark,
                              ),
                              backgroundColor: AppColors.primarySoft.withValues(alpha: 0.6),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              onPressed: () {
                                setState(() {
                                  _catatanCtrl.text = s;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Bagian 3: Absensi Siswa
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
                      TextButton.icon(
                        onPressed: _siswa.isEmpty
                            ? null
                            : () => setState(() {
                                  for (final sw in _siswa) {
                                    _absensi[sw.id] = 'Hadir';
                                  }
                                }),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Semua Hadir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _HitunganAbsensi(hitung: hitung),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cari,
                    decoration: InputDecoration(
                      hintText: 'Cari nama siswa...',
                      prefixIcon: const Icon(Icons.search_outlined),
                      suffixIcon: _cari.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _cari.clear()),
                            )
                          : null,
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
                            : 'Tidak ada siswa yang cocok dengan pencarian.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.grey,
                        ),
                      ),
                    )
                  else
                    ...tampil.map((sw) {
                      final nama = sw.getStringValue('nama');
                      final badge = _keteranganSiswa[sw.id] ?? _badgeIzin[sw.id];
                      final status = _absensi[sw.id] ?? 'Hadir';
                      return _BarisSiswa(
                        nama: nama,
                        inisial: _inisial(nama),
                        badge: badge,
                        status: status,
                        onPilih: (s) => setState(() => _absensi[sw.id] = s),
                        onEditCatatan: () => _editKeteranganSiswa(sw),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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

/// Satu baris siswa: avatar + nama + badge info + tombol H/S/I/A
class _BarisSiswa extends StatelessWidget {
  final String nama;
  final String inisial;
  final String? badge;
  final String status;
  final ValueChanged<String> onPilih;
  final VoidCallback onEditCatatan;

  const _BarisSiswa({
    required this.nama,
    required this.inisial,
    required this.badge,
    required this.status,
    required this.onPilih,
    required this.onEditCatatan,
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

  Color _badgeBg(String b) {
    final lower = b.toLowerCase();
    if (lower.contains('sakit')) return AppColors.amberSoft;
    if (lower.contains('alpa') || lower.contains('tanpa keterangan')) return AppColors.redSoft;
    if (lower.contains('asrama')) return const Color(0xFFCCFBF1);
    if (lower.contains('terlambat')) return AppColors.amberSoft;
    return AppColors.blueSoft;
  }

  Color _badgeColor(String b) {
    final lower = b.toLowerCase();
    if (lower.contains('sakit')) return const Color(0xFFB45309);
    if (lower.contains('alpa') || lower.contains('tanpa keterangan')) return AppColors.red;
    if (lower.contains('asrama')) return const Color(0xFF0F766E);
    if (lower.contains('terlambat')) return const Color(0xFFB45309);
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: status == 'Hadir' ? AppColors.line : _warna(status).withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _warna(status).withValues(alpha: 0.15),
            child: Text(
              inisial,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: _warna(status),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (badge != null && badge!.isNotEmpty)
                  GestureDetector(
                    onTap: onEditCatatan,
                    child: Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _badgeBg(badge!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _badgeColor(badge!),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_note_outlined,
              size: 20,
              color: badge != null ? AppColors.primary : AppColors.grey,
            ),
            tooltip: 'Tambah/Ubah Catatan Siswa',
            onPressed: onEditCatatan,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
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
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPilih(e.key),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: aktif ? _warna(e.key) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: aktif
                          ? [
                              BoxShadow(
                                color: _warna(e.key).withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.line)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
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
                      '$takHadir siswa tidak hadir',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: (!bisaSimpan || saving) ? null : onSimpan,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
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
                saving
                    ? 'Menyimpan...'
                    : (isUpdate ? 'Update Jurnal' : 'Simpan Jurnal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

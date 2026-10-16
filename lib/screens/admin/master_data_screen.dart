import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';

/// Master Data untuk admin: Kelola Kelas, Siswa, Guru, Jadwal, Mapel.
/// Dioptimalkan untuk layar web/desktop (konten max-width, tabel ringkas).
class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Master Data'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: [
              Tab(text: 'Kelas'),
              Tab(text: 'Siswa'),
              Tab(text: 'Guru'),
              Tab(text: 'Jadwal'),
              Tab(text: 'Mapel'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: TabBarView(
              children: [
                _KelasTab(),
                _SiswaTab(),
                _GuruTab(),
                _JadwalTab(),
                _MapelTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- util ----------

Future<void> _confirmHapus(
  BuildContext context,
  String nama,
  Future<void> Function() onHapus,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hapus Data'),
      content: Text('Hapus "$nama"? Tindakan ini tidak bisa dibatalkan.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Hapus', style: TextStyle(color: AppColors.red)),
        ),
      ],
    ),
  );
  if (ok == true) {
    try {
      await onHapus();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menghapus data.')));
      }
    }
  }
}

class _BarisData extends StatelessWidget {
  final String judul;
  final String? sub;
  final VoidCallback onEdit;
  final VoidCallback onHapus;

  const _BarisData({
    required this.judul,
    this.sub,
    required this.onEdit,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          judul,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        subtitle: sub != null
            ? Text(
                sub!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.grey,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppColors.primary,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.red,
              onPressed: onHapus,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- TAB KELAS ----------

class _KelasTab extends StatefulWidget {
  const _KelasTab();

  @override
  State<_KelasTab> createState() => _KelasTabState();
}

class _KelasTabState extends State<_KelasTab> {
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
      final res = await PbService().pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      setState(() {
        _data = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _form({RecordModel? rec}) async {
    final nama = TextEditingController(text: rec?.getStringValue('nama') ?? '');
    final tingkat = ValueNotifier(rec?.getStringValue('tingkat') ?? 'X');
    final fase = TextEditingController(text: rec?.getStringValue('fase') ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(rec == null ? 'Tambah Kelas' : 'Edit Kelas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nama,
              decoration: const InputDecoration(labelText: 'Nama (mis. X-1)'),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: tingkat,
              builder: (_, v, _) => DropdownButtonFormField<String>(
                initialValue: v,
                decoration: const InputDecoration(labelText: 'Tingkat'),
                items: const ['X', 'XI', 'XII']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (x) => tingkat.value = x ?? 'X',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fase,
              decoration: const InputDecoration(
                labelText: 'Fase (mis. Fase E)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final body = {
          'nama': nama.text.trim(),
          'tingkat': tingkat.value,
          'fase': fase.text.trim(),
        };
        if (rec == null) {
          await PbService().pb.collection('kelas').create(body: body);
        } else {
          await PbService().pb.collection('kelas').update(rec.id, body: body);
        }
        _muat();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan kelas.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _data
                    .map(
                      (k) => _BarisData(
                        judul: k.getStringValue('nama'),
                        sub:
                            'Tingkat ${k.getStringValue('tingkat')} • ${k.getStringValue('fase')}',
                        onEdit: () => _form(rec: k),
                        onHapus: () => _confirmHapus(
                          context,
                          k.getStringValue('nama'),
                          () async {
                            await PbService().pb
                                .collection('kelas')
                                .delete(k.id);
                            _muat();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

// ---------- TAB SISWA ----------

class _SiswaTab extends StatefulWidget {
  const _SiswaTab();

  @override
  State<_SiswaTab> createState() => _SiswaTabState();
}

class _SiswaTabState extends State<_SiswaTab> {
  List<RecordModel> _data = [];
  List<RecordModel> _kelas = [];
  bool _loading = true;
  String _cari = '';

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final s = await pb
          .collection('siswa')
          .getList(
            page: 1,
            perPage: 200,
            sort: 'nama',
            expand: 'kelas',
            filter: _cari.isEmpty ? '' : 'nama ~ "$_cari"',
          );
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      setState(() {
        _data = s.items;
        _kelas = k.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _namaKelas(RecordModel s) {
    final n = s.getStringValue('expand.kelas.nama');
    return n.isEmpty ? '-' : n;
  }

  Future<void> _form({RecordModel? rec}) async {
    if (_kelas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tambah data kelas dulu.')));
      return;
    }
    final nama = TextEditingController(text: rec?.getStringValue('nama') ?? '');
    final nis = TextEditingController(text: rec?.getStringValue('nis') ?? '');
    String kelasId = rec?.getStringValue('kelas') ?? _kelas.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(rec == null ? 'Tambah Siswa' : 'Edit Siswa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nama,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nis,
              decoration: const InputDecoration(labelText: 'NIS'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kelasId,
              decoration: const InputDecoration(labelText: 'Kelas'),
              items: _kelas
                  .map(
                    (k) => DropdownMenuItem(
                      value: k.id,
                      child: Text(k.getStringValue('nama')),
                    ),
                  )
                  .toList(),
              onChanged: (x) => kelasId = x ?? kelasId,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final body = {
          'nama': nama.text.trim(),
          'nis': nis.text.trim(),
          'kelas': kelasId,
        };
        if (rec == null) {
          await PbService().pb.collection('siswa').create(body: body);
        } else {
          await PbService().pb.collection('siswa').update(rec.id, body: body);
        }
        _muat();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan siswa.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama siswa...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (v) {
                _cari = v.trim();
                _muat();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _data
                        .map(
                          (s) => _BarisData(
                            judul: s.getStringValue('nama'),
                            sub:
                                'Kelas ${_namaKelas(s)}${s.getStringValue('nis').isNotEmpty ? ' • NIS ${s.getStringValue('nis')}' : ''}',
                            onEdit: () => _form(rec: s),
                            onHapus: () => _confirmHapus(
                              context,
                              s.getStringValue('nama'),
                              () async {
                                await PbService().pb
                                    .collection('siswa')
                                    .delete(s.id);
                                _muat();
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------- TAB GURU ----------

class _GuruTab extends StatefulWidget {
  const _GuruTab();

  @override
  State<_GuruTab> createState() => _GuruTabState();
}

class _GuruTabState extends State<_GuruTab> {
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
      final res = await PbService().pb
          .collection('users')
          .getList(page: 1, perPage: 200, sort: 'nama_lengkap');
      setState(() {
        _data = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _form({RecordModel? rec}) async {
    final nama = TextEditingController(
      text: rec?.getStringValue('nama_lengkap') ?? '',
    );
    final username = TextEditingController(
      text: rec?.getStringValue('username') ?? '',
    );
    final email = TextEditingController(
      text: rec?.getStringValue('email') ?? '',
    );
    final mapel = TextEditingController(
      text: rec?.getStringValue('mapel') ?? '',
    );
    final kode = TextEditingController(
      text: rec?.getStringValue('kode_guru') ?? '',
    );
    final pass = TextEditingController();
    String peran = rec?.getStringValue('peran') ?? 'guru';
    const peranList = [
      'admin',
      'guru',
      'kurikulum',
      'asrama',
      'waka',
      'satpam',
      'piket',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(rec == null ? 'Tambah Guru' : 'Edit Guru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nama,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mapel,
                  decoration: const InputDecoration(
                    labelText: 'Mata Pelajaran Diampu',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kode,
                  decoration: const InputDecoration(
                    labelText: 'Kode Guru (inisial)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: peran,
                  decoration: const InputDecoration(labelText: 'Peran'),
                  items: peranList
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (x) => setS(() => peran = x ?? 'guru'),
                ),
                if (rec == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Kata Sandi Awal (min. 8)',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      try {
        final pb = PbService().pb;
        if (rec == null) {
          await pb
              .collection('users')
              .create(
                body: {
                  'email': email.text.trim(),
                  'username': username.text.trim(),
                  'password': pass.text,
                  'passwordConfirm': pass.text,
                  'nama_lengkap': nama.text.trim(),
                  'mapel': mapel.text.trim(),
                  'kode_guru': kode.text.trim(),
                  'peran': peran,
                  'emailVisibility': true,
                },
              );
        } else {
          await pb
              .collection('users')
              .update(
                rec.id,
                body: {
                  'nama_lengkap': nama.text.trim(),
                  'username': username.text.trim(),
                  'email': email.text.trim(),
                  'mapel': mapel.text.trim(),
                  'kode_guru': kode.text.trim(),
                  'peran': peran,
                },
              );
        }
        _muat();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan. Cek email/username unik.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _data
                    .map(
                      (u) => _BarisData(
                        judul: u.getStringValue('nama_lengkap').isEmpty
                            ? u.getStringValue('email')
                            : u.getStringValue('nama_lengkap'),
                        sub:
                            '@${u.getStringValue('username')} • ${u.getStringValue('mapel')} • ${PbService.peranLabels[u.getStringValue('peran')] ?? u.getStringValue('peran')}',
                        onEdit: () => _form(rec: u),
                        onHapus: () => _confirmHapus(
                          context,
                          u.getStringValue('nama_lengkap'),
                          () async {
                            await PbService().pb
                                .collection('users')
                                .delete(u.id);
                            _muat();
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}

// ---------- TAB JADWAL ----------

class _JadwalBlok {
  final String hari;
  final String kelasId;
  final String namaKelas;
  final String guruId;
  final String namaGuru;
  final String mapel;
  final List<int> jamList;
  final List<RecordModel> records;

  const _JadwalBlok({
    required this.hari,
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

  String get labelJamRingkas {
    if (jamList.isEmpty) return '-';
    if (jamList.length == 1) {
      return 'Jam ${jamList.first}';
    }
    if (isConsecutive) {
      return 'Jam ${jamList.first}–${jamList.last}';
    }
    return 'Jam ${jamList.join(', ')}';
  }

  String get labelJamLengkap {
    if (jamList.isEmpty) return '-';
    if (jamList.length == 1) {
      return 'Jam ke-${jamList.first} (1 JP)';
    }
    if (isConsecutive) {
      return 'Jam ke-${jamList.first} s/d ${jamList.last} ($durasiJp JP)';
    }
    return 'Jam ke-${jamList.join(', ')} ($durasiJp JP)';
  }

  String get labelJp => '$durasiJp JP';

  String get rentangWaktu {
    if (jamList.isEmpty) return '';
    final mulai = 7 * 60 + (jamMulai - 1) * 45;
    final selesai = 7 * 60 + jamSelesai * 45;
    final fmtMulai =
        '${(mulai ~/ 60).toString().padLeft(2, '0')}:${(mulai % 60).toString().padLeft(2, '0')}';
    final fmtSelesai =
        '${(selesai ~/ 60).toString().padLeft(2, '0')}:${(selesai % 60).toString().padLeft(2, '0')}';
    return '$fmtMulai - $fmtSelesai WIB';
  }
}

class _JadwalTab extends StatefulWidget {
  const _JadwalTab();

  @override
  State<_JadwalTab> createState() => _JadwalTabState();
}

class _JadwalTabState extends State<_JadwalTab> {
  List<RecordModel> _data = [];
  List<RecordModel> _kelas = [];
  List<RecordModel> _guru = [];
  List<RecordModel> _mapel = [];
  bool _loading = true;
  String _hari = 'Senin';
  String? _filterKelasId;
  String _cari = '';
  final TextEditingController _cariCtrl = TextEditingController();

  static const _daftarHari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final j = await pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'hari = "$_hari"',
            sort: 'jam_ke',
            expand: 'kelas,guru',
          );
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 100, sort: 'nama');
      final g = await pb
          .collection('users')
          .getList(page: 1, perPage: 200, sort: 'nama_lengkap');
      List<RecordModel> mapel = [];
      try {
        final mp = await pb
            .collection('mapel')
            .getList(page: 1, perPage: 100, sort: 'nama');
        mapel = mp.items;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _data = j.items;
          _kelas = k.items;
          _guru = g.items;
          _mapel = mapel;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_JadwalBlok> _kelompokkanJadwal(List<RecordModel> list) {
    // Map key: '${kelasId}|#|${guruId}|#|${mapel.trim().toLowerCase()}'
    final Map<String, List<RecordModel>> groups = {};
    for (final rec in list) {
      final kId = rec.getStringValue('kelas');
      final gId = rec.getStringValue('guru');
      final mapel = rec.getStringValue('mapel').trim().toLowerCase();
      final key = '$kId|#|$gId|#|$mapel';
      groups.putIfAbsent(key, () => []).add(rec);
    }

    final List<_JadwalBlok> hasil = [];

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
            hasil.add(_buatBlok(currentRun));
            currentRun = [r];
          }
        }
      }
      if (currentRun.isNotEmpty) {
        hasil.add(_buatBlok(currentRun));
      }
    }

    hasil.sort((a, b) {
      final c = a.jamMulai.compareTo(b.jamMulai);
      if (c != 0) return c;
      return a.namaKelas.compareTo(b.namaKelas);
    });

    return hasil;
  }

  _JadwalBlok _buatBlok(List<RecordModel> run) {
    final first = run.first;
    final namaKelas = first.getStringValue('expand.kelas.nama');
    var namaGuru = first.getStringValue('expand.guru.nama_lengkap');
    if (namaGuru.isEmpty) namaGuru = first.getStringValue('expand.guru.email');
    if (namaGuru.isEmpty) namaGuru = 'Belum ditentukan';

    final jamList = run.map((r) => r.getIntValue('jam_ke')).toList();

    return _JadwalBlok(
      hari: first.getStringValue('hari'),
      kelasId: first.getStringValue('kelas'),
      namaKelas: namaKelas.isNotEmpty ? namaKelas : 'Tanpa Kelas',
      guruId: first.getStringValue('guru'),
      namaGuru: namaGuru,
      mapel: first.getStringValue('mapel'),
      jamList: jamList,
      records: run,
    );
  }

  Future<void> _form({_JadwalBlok? blok}) async {
    if (_kelas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tambah data kelas dulu.')));
      return;
    }

    String hari = blok?.hari ?? _hari;
    if (!_daftarHari.contains(hari)) hari = _daftarHari.first;

    String kelasId = blok?.kelasId ?? _filterKelasId ?? _kelas.first.id;
    if (!_kelas.any((k) => k.id == kelasId)) {
      kelasId = _kelas.first.id;
    }

    final Set<int> jamTerpilih = <int>{};
    if (blok != null) {
      jamTerpilih.addAll(blok.jamList);
    } else {
      jamTerpilih.add(1);
    }

    final customMapel = TextEditingController(text: blok?.mapel ?? '');
    bool manualMapel = false;
    String mapelVal = blok?.mapel ?? '';
    final mapelOptions = _mapel
        .map((m) => m.getStringValue('nama'))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    if (_mapel.isNotEmpty) {
      if (mapelVal.isNotEmpty && !mapelOptions.contains(mapelVal)) {
        manualMapel = true;
      } else if (mapelVal.isEmpty && mapelOptions.isNotEmpty) {
        mapelVal = mapelOptions.first;
      }
    } else {
      manualMapel = true;
    }

    String? guruId = blok?.guruId;
    if (guruId != null && guruId.isEmpty) guruId = null;
    if (guruId != null && !_guru.any((u) => u.id == guruId)) guruId = null;

    String formatPilihanJam(Set<int> set) {
      if (set.isEmpty) return '⚠️ Pilih minimal 1 jam pelajaran';
      final sorted = set.toList()..sort();
      final count = sorted.length;
      bool isConsecutive = true;
      for (int i = 0; i < sorted.length - 1; i++) {
        if (sorted[i + 1] != sorted[i] + 1) {
          isConsecutive = false;
          break;
        }
      }
      final rangeStr = (isConsecutive && sorted.length > 1)
          ? 'Jam ke-${sorted.first} s/d ${sorted.last}'
          : 'Jam ke-${sorted.join(", ")}';
      return 'Terpilih: $rangeStr • Total: $count JP';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  blok == null ? Icons.add_alarm_rounded : Icons.edit_calendar_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                blok == null ? 'Tambah Jadwal' : 'Edit Jadwal (${blok.durasiJp} JP)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hari
                  DropdownButtonFormField<String>(
                    key: ValueKey('hari_$hari'),
                    initialValue: hari,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Hari Mengajar',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                    ),
                    items: _daftarHari
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (x) => setS(() => hari = x ?? _hari),
                  ),
                  const SizedBox(height: 14),

                  // Kelas
                  DropdownButtonFormField<String>(
                    key: ValueKey('kelas_$kelasId'),
                    initialValue: kelasId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Kelas',
                      prefixIcon: Icon(Icons.school_outlined, size: 20),
                    ),
                    items: _kelas
                        .map(
                          (k) => DropdownMenuItem(
                            value: k.id,
                            child: Text(
                              'Kelas ${k.getStringValue('nama')}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (x) {
                      if (x != null) setS(() => kelasId = x);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Jam Pelajaran (JP) Chips
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pilih Jam Pelajaran (JP):',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.ink,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => setS(() {
                                    jamTerpilih.addAll([1, 2, 3, 4, 5, 6, 7, 8]);
                                  }),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Semua (8 JP)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const Text(' • ', style: TextStyle(color: AppColors.grey)),
                                InkWell(
                                  onTap: () => setS(() => jamTerpilih.clear()),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Reset',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(8, (index) {
                            final j = index + 1;
                            final aktif = jamTerpilih.contains(j);
                            return InkWell(
                              onTap: () {
                                setS(() {
                                  if (aktif) {
                                    jamTerpilih.remove(j);
                                  } else {
                                    jamTerpilih.add(j);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: aktif ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: aktif
                                        ? AppColors.primaryDark
                                        : Colors.grey.shade300,
                                    width: aktif ? 1.5 : 1,
                                  ),
                                  boxShadow: aktif
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  '$j',
                                  style: TextStyle(
                                    color: aktif ? Colors.white : AppColors.ink,
                                    fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: jamTerpilih.isEmpty
                                ? AppColors.redSoft
                                : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                jamTerpilih.isEmpty
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                size: 16,
                                color: jamTerpilih.isEmpty
                                    ? AppColors.red
                                    : AppColors.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatPilihanJam(jamTerpilih),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: jamTerpilih.isEmpty
                                        ? AppColors.red
                                        : AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mata Pelajaran
                  if (_mapel.isEmpty || manualMapel) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customMapel,
                            decoration: const InputDecoration(
                              labelText: 'Mata Pelajaran',
                              prefixIcon: Icon(Icons.menu_book_outlined, size: 20),
                              hintText: 'Misal: Matematika, Fisika, dll',
                            ),
                          ),
                        ),
                        if (_mapel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Pilih dari daftar Master Mapel',
                            icon: const Icon(Icons.list_alt, color: AppColors.primary),
                            onPressed: () {
                              setS(() {
                                manualMapel = false;
                                if (mapelVal.isEmpty && mapelOptions.isNotEmpty) {
                                  mapelVal = mapelOptions.first;
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('mapel_$mapelVal'),
                            initialValue: mapelOptions.contains(mapelVal)
                                ? mapelVal
                                : (mapelOptions.isNotEmpty ? mapelOptions.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Mata Pelajaran',
                              prefixIcon: Icon(Icons.menu_book_outlined, size: 20),
                            ),
                            items: mapelOptions
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(m, overflow: TextOverflow.ellipsis),
                                  ),
                                )
                                .toList(),
                            onChanged: (x) => setS(() => mapelVal = x ?? mapelVal),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Ketik manual nama mapel',
                          icon: const Icon(Icons.edit_note, color: AppColors.primary),
                          onPressed: () {
                            setS(() {
                              manualMapel = true;
                              customMapel.text = mapelVal;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Guru
                  DropdownButtonFormField<String?>(
                    key: ValueKey('guru_$guruId'),
                    initialValue: (_guru.any((u) => u.id == guruId)) ? guruId : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Guru Pengampu (opsional)',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '(Belum ditentukan / Kosong)',
                          style: TextStyle(
                            color: AppColors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ..._guru.map(
                        (u) {
                          var nama = u.getStringValue('nama_lengkap');
                          if (nama.isEmpty) nama = u.getStringValue('email');
                          if (nama.isEmpty) nama = '-';
                          return DropdownMenuItem<String?>(
                            value: u.id,
                            child: Text(nama, overflow: TextOverflow.ellipsis),
                          );
                        },
                      ),
                    ],
                    onChanged: (x) => setS(() => guruId = x),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () {
                if (jamTerpilih.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pilih minimal satu jam pelajaran.'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                  return;
                }
                final finalNama = manualMapel ? customMapel.text.trim() : mapelVal.trim();
                if (finalNama.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mata pelajaran tidak boleh kosong.'),
                      backgroundColor: AppColors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Simpan Jadwal'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final finalNamaMapel = manualMapel ? customMapel.text.trim() : mapelVal.trim();
      if (jamTerpilih.isEmpty || finalNamaMapel.isEmpty) return;

      final sortedJam = jamTerpilih.toList()..sort();
      final targetHari = hari;
      final targetKelasId = kelasId;
      final targetGuruId = (guruId?.isNotEmpty == true) ? guruId : null;

      setState(() => _loading = true);
      try {
        final pb = PbService().pb;

        if (blok != null) {
          final oldRecordByJam = <int, RecordModel>{};
          for (final r in blok.records) {
            oldRecordByJam[r.getIntValue('jam_ke')] = r;
          }

          // Hapus jam lama yang tidak lagi terpilih
          for (final oldJam in oldRecordByJam.keys) {
            if (!sortedJam.contains(oldJam)) {
              await pb.collection('jadwal').delete(oldRecordByJam[oldJam]!.id);
            }
          }

          // Update atau buat jam terpilih
          for (final j in sortedJam) {
            final body = {
              'hari': targetHari,
              'kelas': targetKelasId,
              'jam_ke': j,
              'mapel': finalNamaMapel,
              'guru': targetGuruId ?? '',
            };

            if (oldRecordByJam.containsKey(j)) {
              await pb.collection('jadwal').update(oldRecordByJam[j]!.id, body: body);
            } else {
              final clashRes = await pb.collection('jadwal').getList(
                page: 1,
                perPage: 1,
                filter: 'hari = "$targetHari" && kelas = "$targetKelasId" && jam_ke = $j',
              );
              if (clashRes.items.isNotEmpty) {
                await pb.collection('jadwal').update(clashRes.items.first.id, body: body);
              } else {
                await pb.collection('jadwal').create(body: body);
              }
            }
          }
        } else {
          // Tambah baru
          for (final j in sortedJam) {
            final body = {
              'hari': targetHari,
              'kelas': targetKelasId,
              'jam_ke': j,
              'mapel': finalNamaMapel,
              'guru': targetGuruId ?? '',
            };
            final clashRes = await pb.collection('jadwal').getList(
              page: 1,
              perPage: 1,
              filter: 'hari = "$targetHari" && kelas = "$targetKelasId" && jam_ke = $j',
            );
            if (clashRes.items.isNotEmpty) {
              await pb.collection('jadwal').update(clashRes.items.first.id, body: body);
            } else {
              await pb.collection('jadwal').create(body: body);
            }
          }
        }

        if (_hari != targetHari) {
          _hari = targetHari;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Jadwal $finalNamaMapel ($targetHari, ${sortedJam.length} JP) berhasil disimpan.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan jadwal: $e'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          _muat();
        }
      }
    }
  }

  Future<void> _hapusBlok(_JadwalBlok blok) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: AppColors.red, size: 24),
            SizedBox(width: 8),
            Text('Hapus Jadwal'),
          ],
        ),
        content: Text(
          'Hapus jadwal ${blok.mapel} kelas ${blok.namaKelas} untuk '
          '${blok.labelJamLengkap}?\n\n'
          'Tindakan ini akan menghapus ${blok.records.length} jam pelajaran sekaligus.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      setState(() => _loading = true);
      try {
        final pb = PbService().pb;
        for (final r in blok.records) {
          await pb.collection('jadwal').delete(r.id);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Jadwal ${blok.mapel} (${blok.labelJp}) berhasil dihapus.',
              ),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus jadwal: $e'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      } finally {
        if (mounted) _muat();
      }
    }
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final blokList = _kelompokkanJadwal(_data);

    final tampilBlok = blokList.where((b) {
      if (_filterKelasId != null && _filterKelasId!.isNotEmpty) {
        if (b.kelasId != _filterKelasId) return false;
      }
      if (_cari.isNotEmpty) {
        final q = _cari.toLowerCase();
        final m = b.mapel.toLowerCase();
        final g = b.namaGuru.toLowerCase();
        final k = b.namaKelas.toLowerCase();
        if (!m.contains(q) && !g.contains(q) && !k.contains(q)) return false;
      }
      return true;
    }).toList();

    final totalSesi = blokList.length;
    final totalJp = blokList.fold<int>(0, (sum, b) => sum + b.durasiJp);
    final totalKelas = blokList.map((b) => b.kelasId).toSet().length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Tambah Jadwal',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Baris Pemilih Hari (Senin - Sabtu)
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
                  final aktif = h == _hari;
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
                        if (sel && _hari != h) {
                          setState(() => _hari = h);
                          _muat();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 2. Summary Stats Strip (Total Sesi, Total Beban JP, Total Kelas)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Total Sesi',
                    value: '$totalSesi Sesi',
                    color: AppColors.blue,
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.line),
                Expanded(
                  child: _statItem(
                    icon: Icons.timer_outlined,
                    label: 'Total Beban',
                    value: '$totalJp JP',
                    color: AppColors.primary,
                    isBold: true,
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.line),
                Expanded(
                  child: _statItem(
                    icon: Icons.school_outlined,
                    label: 'Kelas Terisi',
                    value: '$totalKelas Kelas',
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ),

          // 3. Search Bar & Kelas Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cariCtrl,
                    onChanged: (v) => setState(() => _cari = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Cari mapel, guru, kelas...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grey),
                      suffixIcon: _cari.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _cariCtrl.clear();
                                setState(() => _cari = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.line),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _kelas.any((k) => k.id == _filterKelasId) ? _filterKelasId : null,
                      hint: Text(
                        'Semua Kelas',
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
                        ..._kelas.map(
                          (k) => DropdownMenuItem(
                            value: k.id,
                            child: Text(
                              'Kelas ${k.getStringValue('nama')}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _filterKelasId = v),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Daftar Blok Jadwal
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    child: tampilBlok.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primarySoft,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 40,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Belum ada jadwal untuk hari $_hari',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _cari.isNotEmpty || _filterKelasId != null
                                            ? 'Coba sesuaikan kata kunci pencarian atau filter kelas.'
                                            : 'Tekan tombol Tambah Jadwal untuk mengatur jam pelajaran.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                        ),
                                        onPressed: () => _form(),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('Tambah Jadwal Hari Ini'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                            itemCount: tampilBlok.length,
                            itemBuilder: (ctx, idx) {
                              final b = tampilBlok[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.line),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Badge JP & Jam
                                    Container(
                                      width: 88,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${b.durasiJp} JP',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            b.labelJamRingkas,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            b.rentangWaktu.replaceAll(' WIB', ''),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 9.5,
                                              color: AppColors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Content Detail (Kelas, Mapel, Guru)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF3F4F6),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.school_outlined,
                                                      size: 12,
                                                      color: AppColors.ink,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Kelas ${b.namaKelas}',
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 11,
                                                        color: AppColors.ink,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            b.mapel,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.person_outline,
                                                size: 15,
                                                color: b.guruId.isNotEmpty
                                                    ? AppColors.primaryDark
                                                    : AppColors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  b.namaGuru,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: b.guruId.isNotEmpty
                                                        ? AppColors.ink
                                                        : AppColors.grey,
                                                    fontStyle: b.guruId.isNotEmpty
                                                        ? FontStyle.normal
                                                        : FontStyle.italic,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Buttons (Edit & Delete)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Edit Jadwal (${b.labelJp})',
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppColors.primary,
                                          ),
                                          onPressed: () => _form(blok: b),
                                        ),
                                        IconButton(
                                          tooltip: 'Hapus Jadwal',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                            color: AppColors.red,
                                          ),
                                          onPressed: () => _hapusBlok(b),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

// ---------- TAB MAPEL ----------

class _MapelTab extends StatefulWidget {
  const _MapelTab();

  @override
  State<_MapelTab> createState() => _MapelTabState();
}

class _MapelTabState extends State<_MapelTab> {
  List<RecordModel> _data = [];
  bool _loading = true;
  String _filter = 'Semua';
  static const _kelompok = ['Wajib', 'Peminatan', 'Muatan Lokal'];

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final res = await PbService().pb
          .collection('mapel')
          .getList(page: 1, perPage: 100, sort: 'kelompok,nama');
      setState(() {
        _data = res.items;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _form({RecordModel? rec}) async {
    final nama = TextEditingController(text: rec?.getStringValue('nama') ?? '');
    final kode = TextEditingController(text: rec?.getStringValue('kode') ?? '');
    String kelompok = rec?.getStringValue('kelompok') ?? 'Wajib';
    if (!_kelompok.contains(kelompok)) kelompok = 'Wajib';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(rec == null ? 'Tambah Mapel' : 'Edit Mapel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nama,
                decoration: const InputDecoration(
                  labelText: 'Nama Mata Pelajaran',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kode,
                decoration: const InputDecoration(labelText: 'Kode (mis. MTK)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kelompok,
                decoration: const InputDecoration(labelText: 'Kelompok'),
                items: _kelompok
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (x) => setS(() => kelompok = x ?? 'Wajib'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      if (nama.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama mapel wajib diisi.')),
        );
        return;
      }
      try {
        final body = {
          'nama': nama.text.trim(),
          'kode': kode.text.trim(),
          'kelompok': kelompok,
        };
        if (rec == null) {
          await PbService().pb.collection('mapel').create(body: body);
        } else {
          await PbService().pb.collection('mapel').update(rec.id, body: body);
        }
        _muat();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menyimpan mapel.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tampil = _filter == 'Semua'
        ? _data
        : _data.where((m) => m.getStringValue('kelompok') == _filter).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _form(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _filter,
              decoration: const InputDecoration(labelText: 'Kelompok'),
              items: [
                'Semua',
                ..._kelompok,
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (x) => setState(() => _filter = x ?? 'Semua'),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    child: tampil.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(32),
                            children: [
                              Text(
                                'Belum ada data mapel.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: tampil
                                .map(
                                  (m) => _BarisData(
                                    judul: m.getStringValue('nama'),
                                    sub:
                                        '${m.getStringValue('kelompok')}${m.getStringValue('kode').isNotEmpty ? ' • ${m.getStringValue('kode')}' : ''}',
                                    onEdit: () => _form(rec: m),
                                    onHapus: () => _confirmHapus(
                                      context,
                                      m.getStringValue('nama'),
                                      () async {
                                        await PbService().pb
                                            .collection('mapel')
                                            .delete(m.id);
                                        _muat();
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

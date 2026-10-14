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

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final pb = PbService().pb;
      final j = await pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 200,
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
      setState(() {
        _data = j.items;
        _kelas = k.items;
        _guru = g.items;
        _mapel = mapel;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _label(RecordModel j) {
    final namaKelas = j.getStringValue('expand.kelas.nama');
    var namaGuru = j.getStringValue('expand.guru.nama_lengkap');
    if (namaGuru.isEmpty) namaGuru = j.getStringValue('expand.guru.email');
    if (namaGuru.isEmpty) namaGuru = '-';
    return 'Jam ${j.getIntValue('jam_ke')} • $namaKelas • $namaGuru';
  }

  Future<void> _form({RecordModel? rec}) async {
    if (_kelas.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tambah data kelas dulu.')));
      return;
    }

    String hari = rec?.getStringValue('hari') ?? _hari;
    if (!_daftarHari.contains(hari)) hari = _daftarHari.first;

    String kelasId = rec?.getStringValue('kelas') ?? '';
    if (kelasId.isEmpty || !_kelas.any((k) => k.id == kelasId)) {
      kelasId = _kelas.first.id;
    }

    // Toggle on/off jam 1..8
    final Set<int> jamTerpilih = <int>{};
    if (rec != null) {
      final jk = rec.getIntValue('jam_ke');
      if (jk >= 1 && jk <= 8) {
        jamTerpilih.add(jk);
      } else if (jk > 0) {
        jamTerpilih.add(jk);
      }
    } else {
      jamTerpilih.add(1);
    }

    final customMapel = TextEditingController(
      text: rec?.getStringValue('mapel') ?? '',
    );
    bool manualMapel = false;
    String mapelVal = rec?.getStringValue('mapel') ?? '';
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

    String? guruId = rec?.getStringValue('guru');
    if (guruId != null && guruId.isEmpty) guruId = null;
    if (guruId != null && !_guru.any((u) => u.id == guruId)) guruId = null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              Icon(
                rec == null ? Icons.add_alarm : Icons.edit_calendar,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(rec == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
            ],
          ),
          content: SizedBox(
            width: 440,
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
                      labelText: 'Hari',
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
                            child: Text(k.getStringValue('nama')),
                          ),
                        )
                        .toList(),
                    onChanged: (x) {
                      if (x != null) {
                        setS(() => kelasId = x);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Toggle Jam Pelajaran 1..8
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Jam Pelajaran (1 - 8):',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
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
                                      'Semua',
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
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: aktif ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: aktif ? AppColors.primaryDark : Colors.grey.shade300,
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
                                    fontWeight: aktif ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 8),
                        if (jamTerpilih.isEmpty)
                          const Text(
                            '⚠️ Pilih minimal satu jam pelajaran.',
                            style: TextStyle(
                              color: AppColors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        else
                          Text(
                            'Aktif: Jam ke-${(jamTerpilih.toList()..sort()).join(", ")} (${jamTerpilih.length} JP)',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                              hintText: 'Misal: Matematika, IPA, dll',
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
                      labelText: 'Guru (opsional)',
                      prefixIcon: Icon(Icons.person_outline, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          '(Tanpa Guru / Kosong)',
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
              label: const Text('Simpan'),
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
        // Ambil jadwal yang sudah ada untuk hari & kelas tersebut
        final existingRes = await pb.collection('jadwal').getList(
          page: 1,
          perPage: 100,
          filter: 'hari = "$targetHari" && kelas = "$targetKelasId"',
        );
        final existingMap = <int, RecordModel>{};
        for (final item in existingRes.items) {
          existingMap[item.getIntValue('jam_ke')] = item;
        }

        final Set<String> updatedRecordIds = {};

        // Jika sedang mengedit rec dan jam aslinya tidak lagi dipilih di jamTerpilih:
        if (rec != null && !sortedJam.contains(rec.getIntValue('jam_ke'))) {
          final firstJam = sortedJam.first;
          final clash = existingMap[firstJam];
          if (clash != null && clash.id != rec.id) {
            await pb.collection('jadwal').delete(clash.id);
          }
          await pb.collection('jadwal').update(rec.id, body: {
            'hari': targetHari,
            'kelas': targetKelasId,
            'jam_ke': firstJam,
            'mapel': finalNamaMapel,
            'guru': targetGuruId ?? '',
          });
          updatedRecordIds.add(rec.id);
          existingMap[firstJam] = rec;
        }

        for (final j in sortedJam) {
          final body = {
            'hari': targetHari,
            'kelas': targetKelasId,
            'jam_ke': j,
            'mapel': finalNamaMapel,
            'guru': targetGuruId ?? '',
          };

          // Jika rec masih cocok dengan jam ini:
          if (rec != null && rec.getIntValue('jam_ke') == j && !updatedRecordIds.contains(rec.id)) {
            await pb.collection('jadwal').update(rec.id, body: body);
            updatedRecordIds.add(rec.id);
            continue;
          }

          final existingItem = existingMap[j];
          if (existingItem != null && !updatedRecordIds.contains(existingItem.id)) {
            await pb.collection('jadwal').update(existingItem.id, body: body);
            updatedRecordIds.add(existingItem.id);
          } else if (existingItem == null || !updatedRecordIds.contains(existingItem.id)) {
            await pb.collection('jadwal').create(body: body);
          }
        }

        if (_hari != targetHari) {
          _hari = targetHari;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jadwal berhasil disimpan (${sortedJam.length} JP).'),
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
            child: DropdownButtonFormField<String>(
              initialValue: _hari,
              decoration: const InputDecoration(labelText: 'Hari'),
              items: _daftarHari
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (x) {
                _hari = x ?? _hari;
                _muat();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: _data
                          .map(
                            (j) => _BarisData(
                              judul: j.getStringValue('mapel'),
                              sub: _label(j),
                              onEdit: () => _form(rec: j),
                              onHapus: () => _confirmHapus(
                                context,
                                j.getStringValue('mapel'),
                                () async {
                                  await PbService().pb
                                      .collection('jadwal')
                                      .delete(j.id);
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

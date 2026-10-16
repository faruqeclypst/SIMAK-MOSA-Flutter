import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';

// Layar Daftar Chat ala Telegram:
// Tab filter (Semua, Pribadi, Grup), pencarian percakapan,
// Telegram FAB pen button, status online/aktif, unread counter badge.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _RoomRow {
  final RecordModel room;
  final int unread;
  _RoomRow(this.room, this.unread);
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<_RoomRow> _rooms = [];
  bool _loading = true;
  String _filterTab = 'Semua';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final meId = svc.me!.id;
      final res = await pb
          .collection('chat_rooms')
          .getList(
            page: 1,
            perPage: 100,
            filter: 'anggota ~ "$meId"',
            sort: '-waktu_terakhir,-created',
          );

      // Peta waktu terakhir dibaca per room
      final baca = await pb
          .collection('chat_baca')
          .getList(page: 1, perPage: 200, filter: 'user = "$meId"');

      final petaBaca = {
        for (final b in baca.items)
          b.getStringValue('room'): b.getStringValue('terakhir'),
      };

      final rows = <_RoomRow>[];
      for (final r in res.items) {
        var unread = 0;
        try {
          final t = petaBaca[r.id] ?? '2000-01-01 00:00:00';
          final c = await pb
              .collection('chat_messages')
              .getList(
                page: 1,
                perPage: 1,
                filter:
                    'room = "${r.id}" && created > "$t" && pengirim != "$meId"',
              );
          unread = c.totalItems;
        } catch (_) {}
        rows.add(_RoomRow(r, unread));
      }
      if (mounted) {
        setState(() {
          _rooms = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtWaktu(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final hariIni = DateTime(now.year, now.month, now.day);
      final tgl = DateTime(d.year, d.month, d.day);
      final jam =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      if (tgl == hariIni) return jam;
      if (tgl == hariIni.subtract(const Duration(days: 1))) return 'Kemarin';
      return '${d.day}/${d.month}';
    } catch (_) {
      return '';
    }
  }

  bool _isOnline(String iso) {
    if (iso.isEmpty) return false;
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateTime.now().difference(d).inMinutes < 5;
    } catch (_) {
      return false;
    }
  }

  String _inisial(String nama) {
    final p = nama.trim().split(RegExp(r'\s+'));
    if (p.isEmpty || p.first.isEmpty) return '?';
    if (p.length == 1) return p.first.characters.first.toUpperCase();
    return (p.first.characters.first + p[1].characters.first).toUpperCase();
  }

  Future<void> _bukaBaru() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  'Grup Baru',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Buat ruang koordinasi antarguru/staf',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _formGrup();
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF0284C7),
                  ),
                ),
                title: Text(
                  'Chat Langsung',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  'Mulai percakapan privat 1 lawan 1',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pilihLangsung();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _namaUser(RecordModel u) {
    final n = u.getStringValue('nama_lengkap');
    return n.isEmpty ? u.getStringValue('email') : n;
  }

  Future<void> _formGrup() async {
    final namaCtrl = TextEditingController();
    List<RecordModel> users = [];
    final terpilih = <String>{};
    try {
      final res = await PbService().pb
          .collection('users')
          .getList(page: 1, perPage: 300, sort: 'nama_lengkap');
      users = res.items
          .where((u) => u.id != PbService().me!.id)
          .toList();
    } catch (_) {}
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Buat Grup Baru',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Grup',
                      hintText: 'mis. Tim Kurikulum / Piket Senin',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pilih Anggota (${terpilih.length} dipilih)',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...users.map(
                    (u) => CheckboxListTile(
                      dense: true,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _namaUser(u),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        PbService.peranLabels[u.getStringValue('peran')] ??
                            u.getStringValue('peran'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                      value: terpilih.contains(u.id),
                      onChanged: (v) => setS(() {
                        if (v == true) {
                          terpilih.add(u.id);
                        } else {
                          terpilih.remove(u.id);
                        }
                      }),
                    ),
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
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Buat Grup'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      if (namaCtrl.text.trim().isEmpty || terpilih.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Isi nama grup dan pilih minimal 1 anggota.'),
          ),
        );
        return;
      }
      try {
        final svc = PbService();
        final anggota = [svc.me!.id, ...terpilih];
        final room = await svc.pb.collection('chat_rooms').create(
          body: {
            'nama': namaCtrl.text.trim(),
            'tipe': 'grup',
            'anggota': anggota,
            'waktu_terakhir':
                '${svc.tanggalHariIni()} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00',
          },
        );
        _muat();
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(roomId: room.id),
            ),
          );
          _muat();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membuat grup.')),
          );
        }
      }
    }
  }

  Future<void> _pilihLangsung() async {
    List<RecordModel> users = [];
    try {
      final res = await PbService().pb
          .collection('users')
          .getList(page: 1, perPage: 300, sort: 'nama_lengkap');
      users = res.items
          .where((u) => u.id != PbService().me!.id)
          .toList();
    } catch (_) {}
    if (!mounted) return;
    final pilih = await showDialog<RecordModel>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mulai Chat Langsung',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: users
                  .map(
                    (u) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0F2FE),
                        child: Text(
                          _inisial(_namaUser(u)),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      title: Text(
                        _namaUser(u),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        PbService.peranLabels[u.getStringValue('peran')] ??
                            u.getStringValue('peran'),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.grey,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, u),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );

    if (pilih != null && mounted) {
      try {
        final svc = PbService();
        final meId = svc.me!.id;
        final ada = await svc.pb.collection('chat_rooms').getList(
              page: 1,
              perPage: 5,
              filter:
                  'tipe = "direct" && anggota ~ "$meId" && anggota ~ "${pilih.id}"',
            );
        String roomId;
        if (ada.items.isNotEmpty) {
          roomId = ada.items.first.id;
        } else {
          final room = await svc.pb.collection('chat_rooms').create(
            body: {
              'nama': _namaUser(pilih),
              'tipe': 'direct',
              'anggota': [meId, pilih.id],
              'waktu_terakhir':
                  '${svc.tanggalHariIni()} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00',
            },
          );
          roomId = room.id;
        }
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomScreen(roomId: roomId),
            ),
          );
          _muat();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal membuka chat.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter pencarian dan tab
    final terfilter = _rooms.where((row) {
      final r = row.room;
      final nama = r.getStringValue('nama').toLowerCase();
      final preview = r.getStringValue('pesan_terakhir').toLowerCase();
      final isGrup = r.getStringValue('tipe') == 'grup';

      if (_filterTab == 'Grup' && !isGrup) return false;
      if (_filterTab == 'Pribadi' && isGrup) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return nama.contains(q) || preview.contains(q);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Cari nama atau pesan...',
                  border: InputBorder.none,
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 16),
              )
            : Text(
                'Telegram Chat',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchCtrl.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB), // Telegram Blue
        onPressed: _bukaBaru,
        elevation: 4,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: Column(
        children: [
          // Filter Tabs (Semua, Pribadi, Grup)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: ['Semua', 'Pribadi', 'Grup'].map((tab) {
                final aktif = _filterTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _filterTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: aktif
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                        color: aktif ? Colors.white : AppColors.grey,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Chat Rows
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _muat,
                    color: const Color(0xFF2563EB),
                    child: terfilter.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(40),
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forum_outlined,
                                  size: 42,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ada obrolan ditemukan.'
                                    : 'Belum ada percakapan.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ketuk ikon pensil di bawah untuk memulai chat baru.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: terfilter.length,
                            separatorBuilder: (context, index) => const Divider(
                              indent: 74,
                              height: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (_, i) {
                              final row = terfilter[i];
                              final r = row.room;
                              final nama = r.getStringValue('nama');
                              final preview = r.getStringValue('pesan_terakhir');
                              final waktu = r.getStringValue('waktu_terakhir');
                              final isGrup = r.getStringValue('tipe') == 'grup';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: isGrup
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFDBEAFE),
                                      child: isGrup
                                          ? const Icon(
                                              Icons.groups_rounded,
                                              color: Color(0xFF16A34A),
                                              size: 26,
                                            )
                                          : Text(
                                              _inisial(nama),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF2563EB),
                                                fontSize: 16,
                                              ),
                                            ),
                                    ),
                                    if (!isGrup && _isOnline(waktu))
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF22C55E),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nama.isEmpty ? '-' : nama,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _fmtWaktu(waktu),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        color: row.unread > 0
                                            ? const Color(0xFF2563EB)
                                            : AppColors.grey,
                                        fontWeight: row.unread > 0
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        preview.isEmpty
                                            ? 'Mulai percakapan'
                                            : preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          color: row.unread > 0
                                              ? AppColors.ink
                                              : AppColors.grey,
                                          fontWeight: row.unread > 0
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    if (row.unread > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2563EB),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${row.unread}',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatRoomScreen(roomId: r.id),
                                    ),
                                  );
                                  _muat();
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

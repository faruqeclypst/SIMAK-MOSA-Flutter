import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';
import 'chat_room_screen.dart';

// Daftar chat ala WA: grup & chat langsung, badge unread, buat baru.
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

  @override
  void initState() {
    super.initState();
    _muat();
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
      // peta terakhir dibaca per room
      final baca = await pb
          .collection('chat_baca')
          .getList(
            page: 1,
            perPage: 200,
            filter: 'user = "$meId"',
          );
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
      setState(() {
        _rooms = rows;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(Icons.group_add_outlined, color: AppColors.primary),
              ),
              title: Text(
                'Grup baru',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Buat grup koordinasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _formGrup();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.blueSoft,
                child: Icon(Icons.person_add_outlined, color: AppColors.blue),
              ),
              title: Text(
                'Chat langsung',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Chat 1 lawan 1',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.grey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pilihLangsung();
              },
            ),
            const SizedBox(height: 12),
          ],
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
          title: const Text('Grup Baru'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama grup',
                      hintText: 'mis. Piket Senin',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Anggota',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  ...users.map(
                    (u) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _namaUser(u),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Buat'),
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
        final room = await svc.pb
            .collection('chat_rooms')
            .create(
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
        title: const Text('Chat Langsung'),
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
                        backgroundColor: AppColors.blueSoft,
                        child: Text(
                          _inisial(_namaUser(u)),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: AppColors.blue,
                          ),
                        ),
                      ),
                      title: Text(
                        _namaUser(u),
                        style: GoogleFonts.plusJakartaSans(fontSize: 14),
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
        // cari DM yang sudah ada
        final ada = await svc.pb
            .collection('chat_rooms')
            .getList(
              page: 1,
              perPage: 5,
              filter:
                  'tipe = "direct" && anggota ~ "$meId" && anggota ~ "${pilih.id}"',
            );
        String roomId;
        if (ada.items.isNotEmpty) {
          roomId = ada.items.first.id;
        } else {
          final room = await svc.pb
              .collection('chat_rooms')
              .create(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _bukaBaru,
        child: const Icon(Icons.chat_outlined, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _muat,
              color: AppColors.primary,
              child: _rooms.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada percakapan.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Mulai chat dengan piket, guru, atau waka lewat tombol +.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _rooms.length,
                      itemBuilder: (_, i) {
                        final row = _rooms[i];
                        final r = row.room;
                        final nama = r.getStringValue('nama');
                        final preview = r.getStringValue('pesan_terakhir');
                        final waktu = r.getStringValue('waktu_terakhir');
                        final isGrup = r.getStringValue('tipe') == 'grup';
                        return ListTile(
                              leading: CircleAvatar(
                                radius: 26,
                                backgroundColor: isGrup
                                    ? AppColors.primarySoft
                                    : AppColors.blueSoft,
                                child: isGrup
                                    ? const Icon(
                                        Icons.group_outlined,
                                        color: AppColors.primary,
                                      )
                                    : Text(
                                        _inisial(nama),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.blue,
                                        ),
                                      ),
                              ),
                              title: Text(
                                nama.isEmpty ? '-' : nama,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                preview.isEmpty ? 'Mulai percakapan' : preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.grey,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _fmtWaktu(waktu),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      color: row.unread > 0
                                          ? AppColors.primary
                                          : AppColors.grey,
                                      fontWeight: row.unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (row.unread > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
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
                            )
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: i * 50));
                      },
                    ),
                  ),
    );
  }
}

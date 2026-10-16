import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/kompres_foto.dart';
import '../../services/notifikasi.dart';
import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';

// Ruang chat bergaya Telegram:
// Bubble pesan modern, fitur Balas Pesan (Quoted Reply), Reaksi Emoji (👍 ❤️ 🔥 👏 😂),
// menu lampiran rapi, serta indikator centang baca realtime.
class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  const ChatRoomScreen({super.key, required this.roomId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  RecordModel? _room;
  List<RecordModel> _pesan = [];
  bool _loading = true;
  bool _mengirim = false;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  UnsubscribeFunc? _unsub;

  // Quoted reply state
  RecordModel? _pesanDibalas;

  // In-chat search
  bool _isSearching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  DateTime? _partnerLastActive;

  @override
  void initState() {
    super.initState();
    roomAktif = widget.roomId;
    _init();
  }

  @override
  void dispose() {
    if (roomAktif == widget.roomId) roomAktif = null;
    _tandaiDibaca();
    _ctrl.dispose();
    _scroll.dispose();
    _searchCtrl.dispose();
    _unsub?.call();
    super.dispose();
  }

  Future<void> _init() async {
    await _muatPesan();
    _tandaiDibaca();
    _tandaiPesanDibaca();
    try {
      _unsub = await PbService().pb
          .collection('chat_messages')
          .subscribe(
            '*',
            (e) {
              if (!mounted || e.record == null) return;
              if (e.action == 'create') {
                setState(() => _pesan.add(e.record!));
                _keBawah();
                _tandaiDibaca();
                _tandaiPesanDibaca();
              } else if (e.action == 'update') {
                final idx = _pesan.indexWhere((m) => m.id == e.record!.id);
                if (idx >= 0) setState(() => _pesan[idx] = e.record!);
              } else if (e.action == 'delete') {
                setState(() => _pesan.removeWhere((m) => m.id == e.record!.id));
              }
            },
            filter: 'room = "${widget.roomId}"',
            expand: 'pengirim',
          );
    } catch (_) {}
  }

  Future<void> _tandaiPesanDibaca() async {
    try {
      final svc = PbService();
      final pb = svc.pb;
      final meId = svc.me!.id;
      for (final m in _pesan) {
        if (m.getStringValue('pengirim') == meId) continue;
        final dibaca = List<String>.from(m.data['dibaca_oleh'] ?? []);
        final diterima = List<String>.from(m.data['diterima_oleh'] ?? []);
        bool perluUpdate = false;
        final body = <String, dynamic>{};

        if (!diterima.contains(meId)) {
          diterima.add(meId);
          body['diterima_oleh'] = diterima;
          m.data['diterima_oleh'] = diterima;
          perluUpdate = true;
        }
        if (!dibaca.contains(meId)) {
          dibaca.add(meId);
          body['dibaca_oleh'] = dibaca;
          m.data['dibaca_oleh'] = dibaca;
          perluUpdate = true;
        }

        if (perluUpdate) {
          try {
            await pb.collection('chat_messages').update(m.id, body: body);
          } catch (_) {}
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<String> _anggotaLain() {
    final meId = PbService().me?.id;
    final semua = List<String>.from(_room?.data['anggota'] ?? []);
    return semua.where((id) => id != meId).toList();
  }

  String _statusSubtitle(bool isGrup) {
    if (isGrup) {
      final jml = List.from(_room?.data['anggota'] ?? []).length;
      return '$jml anggota';
    }
    if (_partnerLastActive == null) {
      return 'terhubung di SIMAK MOSA';
    }
    final selisih = DateTime.now().difference(_partnerLastActive!);
    if (selisih.inMinutes < 5) {
      return 'online';
    }
    if (selisih.inHours < 1) {
      return 'terakhir dilihat ${selisih.inMinutes} mnt lalu';
    }
    if (selisih.inHours < 24) {
      return 'terakhir dilihat ${selisih.inHours} jam lalu';
    }
    if (selisih.inDays < 7) {
      return 'terakhir dilihat ${selisih.inDays} hari lalu';
    }
    return 'terakhir dilihat ${_partnerLastActive!.day}/${_partnerLastActive!.month}';
  }

  bool _isPartnerOnline() {
    if (_partnerLastActive == null) return false;
    return DateTime.now().difference(_partnerLastActive!).inMinutes < 5;
  }

  Future<void> _muatPesan() async {
    try {
      final pb = PbService().pb;
      final room = await pb.collection('chat_rooms').getOne(widget.roomId);
      final res = await pb
          .collection('chat_messages')
          .getList(
            page: 1,
            perPage: 300,
            filter: 'room = "${widget.roomId}"',
            sort: 'created',
            expand: 'pengirim',
          );

      DateTime? partnerLast;
      if (room.getStringValue('tipe') != 'grup') {
        final others = List<String>.from(room.data['anggota'] ?? [])
            .where((id) => id != PbService().me?.id)
            .toList();
        if (others.isNotEmpty) {
          final partnerId = others.first;
          try {
            final bacaRes = await pb.collection('chat_baca').getList(
                  page: 1,
                  perPage: 1,
                  filter: 'user = "$partnerId"',
                  sort: '-terakhir',
                );
            if (bacaRes.items.isNotEmpty) {
              partnerLast = DateTime.tryParse(
                bacaRes.items.first.getStringValue('terakhir'),
              )?.toLocal();
            }
          } catch (_) {}
          if (partnerLast == null) {
            try {
              final u = await pb.collection('users').getOne(partnerId);
              partnerLast =
                  DateTime.tryParse(u.getStringValue('updated'))?.toLocal();
            } catch (_) {}
          }
        }
      }

      if (mounted) {
        setState(() {
          _room = room;
          _pesan = res.items;
          _partnerLastActive = partnerLast;
          _loading = false;
        });
        _keBawah(animate: false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tandaiDibaca() async {
    try {
      final svc = PbService();
      final pb = svc.pb;
      final meId = svc.me!.id;
      final now = svc.waktuUtc();
      final ada = await pb
          .collection('chat_baca')
          .getList(
            page: 1,
            perPage: 1,
            filter: 'room = "${widget.roomId}" && user = "$meId"',
          );
      if (ada.items.isNotEmpty) {
        await pb
            .collection('chat_baca')
            .update(ada.items.first.id, body: {'terakhir': now});
      } else {
        await pb
            .collection('chat_baca')
            .create(
              body: {'room': widget.roomId, 'user': meId, 'terakhir': now},
            );
      }
    } catch (_) {}
  }

  void _keBawah({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (animate) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _kirim() async {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty || _mengirim) return;
    setState(() => _mengirim = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final waktu =
          '${svc.tanggalHariIni()} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00';

      // Sertakan info balasan jika ada
      String pesanKirim = teks;
      if (_pesanDibalas != null) {
        final namaDibalas = _namaPengirim(_pesanDibalas!);
        final cuplikan = _pesanDibalas!.getStringValue('pesan');
        pesanKirim = '>> [$namaDibalas: $cuplikan]\n$teks';
      }

      await pb.collection('chat_messages').create(
        body: {
          'room': widget.roomId,
          'pengirim': svc.me!.id,
          'pesan': pesanKirim,
          'dibaca_oleh': [svc.me!.id],
        },
      );
      await pb.collection('chat_rooms').update(
        widget.roomId,
        body: {
          'pesan_terakhir': teks,
          'waktu_terakhir': waktu,
        },
      );
      _ctrl.clear();
      setState(() => _pesanDibalas = null);
      _tandaiDibaca();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim pesan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  Future<void> _kirimFoto() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFDBEAFE),
                    onTap: () {
                      Navigator.pop(context);
                      _prosesAmbilFoto(ImageSource.camera);
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    color: const Color(0xFF10B981),
                    bgColor: const Color(0xFFD1FAE5),
                    onTap: () {
                      Navigator.pop(context);
                      _prosesAmbilFoto(ImageSource.gallery);
                    },
                  ),
                  _buildAttachOption(
                    icon: Icons.description_rounded,
                    label: 'Dokumen',
                    color: const Color(0xFF8B5CF6),
                    bgColor: const Color(0xFFEDE9FE),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Fitur dokumen terintegrasi via galeri.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prosesAmbilFoto(ImageSource src) async {
    final foto = await ambilFotoKompres(src);
    if (foto == null || !mounted) return;

    final captionCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Kirim Gambar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: captionCtrl,
              decoration: const InputDecoration(
                hintText: 'Keterangan gambar (opsional)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    setState(() => _mengirim = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final caption = captionCtrl.text.trim();
      final waktu =
          '${svc.tanggalHariIni()} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00';

      await pb.collection('chat_messages').create(
            body: {
              'room': widget.roomId,
              'pengirim': svc.me!.id,
              'pesan': caption,
              'dibaca_oleh': [svc.me!.id],
            },
            files: [await http.MultipartFile.fromPath('foto', foto.path)],
          );
      await pb.collection('chat_rooms').update(
            widget.roomId,
            body: {
              'pesan_terakhir': caption.isEmpty ? '[Foto]' : caption,
              'waktu_terakhir': waktu,
            },
          );
      _ctrl.clear();
      _tandaiDibaca();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  void _lihatFoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(child: Image.network(url)),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _tampilkanMenuPesan(RecordModel m) {
    final meId = PbService().me?.id;
    final milikku = m.getStringValue('pengirim') == meId;
    final isAdmin = PbService().isAdmin;
    final teks = m.getStringValue('pesan');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Reactions Row ala Telegram
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '🔥', '👏', '😂', '😮', '🤝'].map((emoji) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _kirimReaksi(m, emoji);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Color(0xFF2563EB)),
                title: Text(
                  'Balas Pesan',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _pesanDibalas = m);
                },
              ),
              if (teks.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: AppColors.ink),
                  title: Text(
                    'Salin Teks',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: teks));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pesan disalin ke clipboard.')),
                    );
                  },
                ),
              if (milikku || isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                  title: Text(
                    'Hapus Pesan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      color: AppColors.red,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await PbService().pb.collection('chat_messages').delete(m.id);
                    } catch (_) {}
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _kirimReaksi(RecordModel m, String emoji) async {
    final svc = PbService();
    final meNama = svc.nama;
    final waktu =
        '${svc.tanggalHariIni()} ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00';

    try {
      await svc.pb.collection('chat_messages').create(
        body: {
          'room': widget.roomId,
          'pengirim': svc.me!.id,
          'pesan': '$emoji Bereaksi pada pesan $meNama',
          'dibaca_oleh': [svc.me!.id],
        },
      );
      await svc.pb.collection('chat_rooms').update(
        widget.roomId,
        body: {
          'pesan_terakhir': '$emoji Reaksi',
          'waktu_terakhir': waktu,
        },
      );
    } catch (_) {}
  }

  Widget _ticks(RecordModel m) {
    final lain = _anggotaLain();
    if (lain.isEmpty) return const SizedBox.shrink();
    final diterima = List<String>.from(m.data['diterima_oleh'] ?? []);
    final dibaca = List<String>.from(m.data['dibaca_oleh'] ?? []);
    final semuaBaca = lain.every(dibaca.contains);
    final semuaTerima = lain.every(diterima.contains);

    if (semuaBaca) {
      return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF2563EB));
    }
    if (semuaTerima) {
      return const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF64748B));
    }
    return const Icon(Icons.done_rounded, size: 15, color: Color(0xFF64748B));
  }

  String _namaPengirim(RecordModel m) {
    var n = m.getStringValue('expand.pengirim.nama_lengkap');
    if (n.isEmpty) n = m.getStringValue('expand.pengirim.name');
    if (n.isEmpty) n = m.getStringValue('expand.pengirim.email');
    return n.isEmpty ? 'Warga Sekolah' : n;
  }

  String _fmtJam(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = _room?.getStringValue('nama') ?? 'Telegram Chat';
    final isGrup = _room?.getStringValue('tipe') == 'grup';
    final meId = PbService().me?.id;

    final pesanTampil = _searchQuery.isEmpty
        ? _pesan
        : _pesan.where((m) {
            return m.getStringValue('pesan').toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Telegram wallpaper clean tone
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Cari pesan di chat...',
                  border: InputBorder.none,
                ),
                style: GoogleFonts.plusJakartaSans(fontSize: 15),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isGrup
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFDBEAFE),
                    child: Icon(
                      isGrup ? Icons.groups_rounded : Icons.person_rounded,
                      size: 22,
                      color: isGrup
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF2563EB),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _statusSubtitle(isGrup),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: (!isGrup && _isPartnerOnline())
                                ? const Color(0xFF16A34A)
                                : AppColors.grey,
                            fontWeight: (!isGrup && _isPartnerOnline())
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
      body: Column(
        children: [
          // Pesan List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : pesanTampil.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'Pesan tidak ditemukan.'
                              : 'Belum ada pesan.\nSapa rekan Anda 👋',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        itemCount: pesanTampil.length,
                        itemBuilder: (_, i) {
                          final m = pesanTampil[i];
                          final milikku = m.getStringValue('pengirim') == meId;
                          final foto = m.getStringValue('foto');
                          final teks = m.getStringValue('pesan');

                          // Cek apakah pesan berisi kutipan balasan
                          final isReply = teks.startsWith('>> [');
                          String? quoteHeader;
                          String isiTeks = teks;
                          if (isReply && teks.contains(']\n')) {
                            final endIdx = teks.indexOf(']\n');
                            quoteHeader = teks.substring(4, endIdx);
                            isiTeks = teks.substring(endIdx + 2);
                          }

                          return GestureDetector(
                            onLongPress: () => _tampilkanMenuPesan(m),
                            child: Align(
                              alignment: milikku
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.78,
                                ),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: EdgeInsets.symmetric(
                                  horizontal: foto.isNotEmpty ? 6 : 12,
                                  vertical: foto.isNotEmpty ? 6 : 8,
                                ),
                                decoration: BoxDecoration(
                                  // Telegram outgoing light mint vs incoming pure white
                                  color: milikku
                                      ? const Color(0xFFE0F4E8)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(milikku ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(milikku ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!milikku && isGrup)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                          left: 4,
                                          right: 4,
                                        ),
                                        child: Text(
                                          _namaPengirim(m),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),

                                    // Quoted Message Banner inside bubble
                                    if (quoteHeader != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 4,
                                          right: 4,
                                        ),
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          4,
                                          8,
                                          4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: const Border(
                                            left: BorderSide(
                                              color: Color(0xFF2563EB),
                                              width: 3,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          quoteHeader,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            color: const Color(0xFF334155),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),

                                    if (foto.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _lihatFoto(
                                          PbService().pb.files
                                              .getUrl(m, foto)
                                              .toString(),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            PbService().pb.files
                                                .getUrl(m, foto)
                                                .toString(),
                                            width: 240,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),

                                    if (isiTeks.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: foto.isNotEmpty ? 6 : 0,
                                          left: 4,
                                          right: 4,
                                        ),
                                        child: Text(
                                          isiTeks,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 14,
                                            height: 1.35,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),

                                    // Timestamp & Status Ticks
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2,
                                          right: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _fmtJam(
                                                m.getStringValue('created'),
                                              ),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                fontSize: 10,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                            if (milikku) ...[
                                              const SizedBox(width: 4),
                                              _ticks(m),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Quoted Reply Preview Bar
          if (_pesanDibalas != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Membalas ${_namaPengirim(_pesanDibalas!)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        Text(
                          _pesanDibalas!.getStringValue('pesan').isEmpty
                              ? '[Foto]'
                              : _pesanDibalas!.getStringValue('pesan'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _pesanDibalas = null),
                  ),
                ],
              ),
            ),

          // Composer Bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'Lampiran',
                    onPressed: _mengirim ? null : _kirimFoto,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _kirim(),
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    radius: 20,
                    child: IconButton(
                      icon: _mengirim
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      onPressed: _kirim,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

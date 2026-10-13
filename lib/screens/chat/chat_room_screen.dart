import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../services/kompres_foto.dart';
import '../../services/notifikasi.dart';
import '../../services/pb_service.dart';
import '../../theme/app_theme.dart';

// Ruang chat ala WA: bubble pesan + realtime PocketBase.
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
                // pesan yang masuk saat room terbuka ikut ditandai dibaca
                _tandaiDibaca();
                _tandaiPesanDibaca();
              } else if (e.action == 'update') {
                // update centang (diterima/dibaca) secara live
                final idx = _pesan.indexWhere((m) => m.id == e.record!.id);
                if (idx >= 0) setState(() => _pesan[idx] = e.record!);
              }
            },
            filter: 'room = "${widget.roomId}"',
            expand: 'pengirim',
          );
    } catch (_) {}
  }

  /// Tandai semua pesan dari orang lain sebagai dibaca oleh saya.
  Future<void> _tandaiPesanDibaca() async {
    try {
      final svc = PbService();
      final pb = svc.pb;
      final meId = svc.me!.id;
      for (final m in _pesan) {
        if (m.getStringValue('pengirim') == meId) continue;
        final dibaca = List<String>.from(m.data['dibaca_oleh'] ?? []);
        if (dibaca.contains(meId)) continue;
        dibaca.add(meId);
        await pb
            .collection('chat_messages')
            .update(m.id, body: {'dibaca_oleh': dibaca});
        m.data['dibaca_oleh'] = dibaca;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  List<String> _anggotaLain() {
    final meId = PbService().me?.id;
    final semua = List<String>.from(_room?.data['anggota'] ?? []);
    return semua.where((id) => id != meId).toList();
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
      if (mounted) {
        setState(() {
          _room = room;
          _pesan = res.items;
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
      final pos = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          pos,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(pos);
      }
    });
  }

  Future<void> _kirim() async {
    final teks = _ctrl.text.trim();
    if (teks.isEmpty || _mengirim) return;
    setState(() => _mengirim = true);
    _ctrl.clear();
    try {
      final svc = PbService();
      final pb = svc.pb;
      final now = DateTime.now();
      final waktu =
          '${svc.tanggalHariIni()} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await pb
          .collection('chat_messages')
          .create(
            body: {
              'room': widget.roomId,
              'pengirim': svc.me!.id,
              'pesan': teks,
              'dibaca_oleh': [svc.me!.id],
            },
          );
      await pb
          .collection('chat_rooms')
          .update(
            widget.roomId,
            body: {'pesan_terakhir': teks, 'waktu_terakhir': waktu},
          );
      _tandaiDibaca();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal mengirim pesan.')));
      }
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  /// Kirim foto (dikompres) dengan caption opsional.
  Future<void> _kirimFoto() async {
    final sumber = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (sumber == null || !mounted) return;
    final foto = await ambilFotoKompres(sumber);
    if (foto == null || !mounted) return;
    setState(() => _mengirim = true);
    try {
      final svc = PbService();
      final pb = svc.pb;
      final caption = _ctrl.text.trim();
      final now = DateTime.now();
      final waktu =
          '${svc.tanggalHariIni()} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await pb
          .collection('chat_messages')
          .create(
            body: {
              'room': widget.roomId,
              'pengirim': svc.me!.id,
              'pesan': caption,
              'dibaca_oleh': [svc.me!.id],
            },
            files: [await http.MultipartFile.fromPath('foto', foto.path)],
          );
      await pb
          .collection('chat_rooms')
          .update(
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

  /// Centang ala WA: 1 abu = terkirim, 2 abu = diterima semua,
  /// 2 biru = dibaca semua anggota lain.
  Widget _ticks(RecordModel m) {
    final lain = _anggotaLain();
    if (lain.isEmpty) return const SizedBox.shrink();
    final diterima = List<String>.from(m.data['diterima_oleh'] ?? []);
    final dibaca = List<String>.from(m.data['dibaca_oleh'] ?? []);
    final semuaBaca = lain.every(dibaca.contains);
    final semuaTerima = lain.every(diterima.contains);
    if (semuaBaca) {
      return const Icon(Icons.done_all, size: 15, color: Color(0xFF7DE3FF));
    }
    if (semuaTerima) {
      return Icon(
        Icons.done_all,
        size: 15,
        color: Colors.white.withValues(alpha: 0.75),
      );
    }
    return Icon(
      Icons.done,
      size: 15,
      color: Colors.white.withValues(alpha: 0.75),
    );
  }

  String _namaPengirim(RecordModel m) {
    var n = m.getStringValue('expand.pengirim.nama_lengkap');
    if (n.isEmpty) n = m.getStringValue('expand.pengirim.email');
    return n.isEmpty ? 'Pengguna' : n;
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
    final nama = _room?.getStringValue('nama') ?? 'Chat';
    final isGrup = _room?.getStringValue('tipe') == 'grup';
    final meId = PbService().me?.id;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: isGrup
                  ? AppColors.primarySoft
                  : AppColors.blueSoft,
              child: Icon(
                isGrup ? Icons.group_outlined : Icons.person_outline,
                size: 20,
                color: isGrup ? AppColors.primary : AppColors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isGrup)
                    Text(
                      'Grup',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pesan.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada pesan.\nSapa dulu 👋',
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
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: _pesan.length,
                    itemBuilder: (_, i) {
                      final m = _pesan[i];
                      final milikku = m.getStringValue('pengirim') == meId;
                      final foto = m.getStringValue('foto');
                      final teks = m.getStringValue('pesan');
                      return Align(
                        alignment: milikku
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: foto.isNotEmpty ? 6 : 14,
                            vertical: foto.isNotEmpty ? 6 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: milikku ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(milikku ? 16 : 4),
                              bottomRight: Radius.circular(milikku ? 4 : 16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!milikku && isGrup)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 3,
                                    left: 8,
                                    right: 8,
                                  ),
                                  child: Text(
                                    _namaPengirim(m),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue,
                                    ),
                                  ),
                                ),
                              if (foto.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _lihatFoto(
                                    PbService()
                                        .pb
                                        .files
                                        .getUrl(m, foto)
                                        .toString(),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      PbService()
                                          .pb
                                          .files
                                          .getUrl(m, foto)
                                          .toString(),
                                      width: 220,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (_, child, progress) =>
                                              progress == null
                                              ? child
                                              : const SizedBox(
                                                  width: 220,
                                                  height: 140,
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                ),
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(
                                            width: 220,
                                            height: 100,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              if (teks.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: foto.isNotEmpty ? 6 : 0,
                                    left: foto.isNotEmpty ? 8 : 0,
                                    right: foto.isNotEmpty ? 8 : 0,
                                  ),
                                  child: Text(
                                    teks,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: milikku
                                          ? Colors.white
                                          : AppColors.ink,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 3,
                                  left: foto.isNotEmpty ? 8 : 0,
                                  right: foto.isNotEmpty ? 8 : 0,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _fmtJam(m.getStringValue('created')),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        color: milikku
                                            ? Colors.white.withValues(
                                                alpha: 0.8,
                                              )
                                            : AppColors.grey,
                                      ),
                                    ),
                                    if (milikku) ...[
                                      const SizedBox(width: 4),
                                      _ticks(m),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.attach_file_outlined,
                      color: AppColors.grey,
                    ),
                    tooltip: 'Kirim foto',
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
                        fillColor: const Color(0xFFF3F4F6),
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
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: _mengirim
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_outlined,
                              color: Colors.white,
                              size: 20,
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notifikasi.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'chat/chat_list_screen.dart';
import 'chat/chat_room_screen.dart';
import 'home_screen.dart';
import 'kejadian_form_screen.dart';
import 'laporan_hub_screen.dart';
import 'notifikasi_screen.dart';
import 'profil_screen.dart';

// Kerangka utama: bottom nav ala IG dengan tombol CAP di tengah.
// Ketuk CAP -> langsung buka kamera, lalu isi detail kejadian.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _adaPengingat = false;
  int _unreadChat = 0;
  Function? _unsubChat;
  Function? _unsubPengumuman;
  Function? _unsubKejadian;

  @override
  void initState() {
    super.initState();
    _cekPengingat();
    _cekUnreadChat();
    _pantauChat();
    _pantauPengumuman();
    _pantauKejadian();
  }

  @override
  void dispose() {
    _unsubChat?.call();
    _unsubPengumuman?.call();
    _unsubKejadian?.call();
    super.dispose();
  }

  /// Pantau pengumuman baru dari sekolah
  Future<void> _pantauPengumuman() async {
    try {
      final svc = PbService();
      _unsubPengumuman = await svc.pb
          .collection('pengumuman')
          .subscribe('*', (e) async {
            if (e.action != 'create' || e.record == null) return;
            final rec = e.record!;
            await notifPengumumanBaru(
              judul: rec.getStringValue('judul'),
              isi: rec.getStringValue('isi'),
            );
          });
    } catch (_) {}
  }

  /// Pantau kejadian mendesak / Cap on Spot baru
  Future<void> _pantauKejadian() async {
    try {
      final svc = PbService();
      _unsubKejadian = await svc.pb
          .collection('kejadian')
          .subscribe('*', (e) async {
            if (e.action != 'create' || e.record == null) return;
            final rec = e.record!;
            final meId = svc.me?.id;
            if (meId != null && rec.getStringValue('pelapor') == meId) return;
            var namaPelapor = rec.getStringValue('expand.pelapor.nama_lengkap');
            if (namaPelapor.isEmpty) {
              namaPelapor = rec.getStringValue('expand.pelapor.name');
            }
            if (namaPelapor.isEmpty) namaPelapor = 'Warga Sekolah';
            await notifKejadianBaru(
              judul: rec.getStringValue('judul'),
              kategori: rec.getStringValue('kategori'),
              pelapor: namaPelapor,
            );
          }, expand: 'pelapor');
    } catch (_) {}
  }

  /// Pantau pesan baru: tandai diterima, notifikasi, update badge.
  Future<void> _pantauChat() async {
    try {
      final svc = PbService();
      _unsubChat = await svc.pb
          .collection('chat_messages')
          .subscribe('*', (e) async {
            _cekUnreadChat();
            if (e.action != 'create' || e.record == null) return;
            final m = e.record!;
            final meId = svc.me?.id;
            if (meId == null || m.getStringValue('pengirim') == meId) return;
            // tandai diterima (centang 2 ala WA)
            try {
              final diterima = List<String>.from(
                m.data['diterima_oleh'] ?? [],
              );
              if (!diterima.contains(meId)) {
                diterima.add(meId);
                await svc.pb
                    .collection('chat_messages')
                    .update(m.id, body: {'diterima_oleh': diterima});
              }
            } catch (_) {}
            // notifikasi lokal bila room tidak sedang dibuka
            final roomId = m.getStringValue('room');
            var nama = m.getStringValue('expand.pengirim.nama_lengkap');
            if (nama.isEmpty) nama = 'Pesan baru';
            var isi = m.getStringValue('pesan');
            if (m.getStringValue('foto').isNotEmpty && isi.isEmpty) {
              isi = '[Foto]';
            }
            await notifPesanMasuk(
              roomId: roomId,
              namaPengirim: nama,
              isi: isi,
            );

            // Banner notifikasi dalam aplikasi jika user sedang tidak di room tersebut
            if (mounted && roomAktif != roomId) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF1E293B),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nama,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  action: SnackBarAction(
                    label: 'Buka',
                    textColor: const Color(0xFF38BDF8),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(roomId: roomId),
                        ),
                      );
                    },
                  ),
                ),
              );
            }
          }, expand: 'pengirim');
    } catch (_) {}
  }

  void _keTab(int i) {
    setState(() => _index = i);
    _cekUnreadChat();
  }

  void _bukaProfil() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilScreen()),
    );
  }

  /// Badge merah di tab Notifikasi bila guru punya jadwal
  /// yang segera/berlangsung hari ini.
  Future<void> _cekPengingat() async {
    try {
      final svc = PbService();
      if (!(svc.isGuru || svc.isPiket)) return;
      final j = await svc.pb
          .collection('jadwal')
          .getList(
            page: 1,
            perPage: 50,
            filter: 'hari = "${svc.hariIni()}" && guru = "${svc.me!.id}"',
          );
      final now = DateTime.now();
      final menitNow = now.hour * 60 + now.minute;
      final ada = j.items.any((it) {
        final jamKe = it.getIntValue('jam_ke');
        final mulai = 7 * 60 + (jamKe - 1) * 45;
        return menitNow >= mulai - 60 && menitNow < mulai + 45;
      });
      if (mounted) setState(() => _adaPengingat = ada);
    } catch (_) {}
  }

  /// Badge jumlah pesan belum dibaca di tab Chat.
  Future<void> _cekUnreadChat() async {
    try {
      final svc = PbService();
      final pb = svc.pb;
      final meId = svc.me!.id;
      final rooms = await pb
          .collection('chat_rooms')
          .getList(page: 1, perPage: 100, filter: 'anggota ~ "$meId"');
      if (rooms.items.isEmpty) {
        if (mounted) setState(() => _unreadChat = 0);
        return;
      }
      final baca = await pb
          .collection('chat_baca')
          .getList(page: 1, perPage: 200, filter: 'user = "$meId"');
      final peta = {
        for (final b in baca.items)
          b.getStringValue('room'): b.getStringValue('terakhir'),
      };
      var total = 0;
      for (final r in rooms.items) {
        final t = peta[r.id] ?? '2000-01-01 00:00:00';
        final c = await pb
            .collection('chat_messages')
            .getList(
              page: 1,
              perPage: 1,
              filter:
                  'room = "${r.id}" && created > "$t" && pengirim != "$meId"',
            );
        total += c.totalItems;
      }
      if (mounted) setState(() => _unreadChat = total);
    } catch (_) {}
  }

  Widget _tab(
    int tabIndex,
    IconData outlined,
    IconData filled,
    String label, {
    int badge = 0,
    bool dot = false,
  }) {
    final aktif = _index == tabIndex;
    final warna = aktif ? AppColors.primary : AppColors.grey;
    return Expanded(
      child: InkWell(
        onTap: () => _keTab(tabIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(aktif ? filled : outlined, color: warna, size: 26),
                  if (dot)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (badge > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                  color: warna,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tombolCap() {
    return Expanded(
      child: InkWell(
        onTap: () => bukaCapInstan(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C853), Color(0xFF00AA13)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 2),
              Text(
                'CAP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onAvatarTap: _bukaProfil,
        onLihatPengumuman: () => _keTab(3),
      ),
      const ChatListScreen(),
      const LaporanHubScreen(),
      const NotifikasiScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _tab(0, Icons.home_outlined, Icons.home, 'Beranda'),
              _tab(
                1,
                Icons.chat_bubble_outline,
                Icons.chat_bubble,
                'Chat',
                badge: _unreadChat,
              ),
              _tombolCap(),
              _tab(2, Icons.bar_chart_outlined, Icons.bar_chart, 'Laporan'),
              _tab(
                3,
                Icons.notifications_outlined,
                Icons.notifications,
                'Notifikasi',
                dot: _adaPengingat,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

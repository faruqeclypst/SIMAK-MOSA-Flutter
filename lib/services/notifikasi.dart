import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/chat/chat_room_screen.dart';

// Sistem notifikasi lokal SIMAK-MOSA: mendukung dering/suara HP asli,
// getar (vibration pattern), heads-up notification banner, dan navigasi otomatis.

final _notif = FlutterLocalNotificationsPlugin();
final navigatorKey = GlobalKey<NavigatorState>();

/// Room yang sedang dibuka user; notifikasi untuk room ini disenyapkan.
String? roomAktif;

// ID Kanal notifikasi Android (gunakan v1 untuk memastikan konfigurasi suara & getar baru terdaftar)
const _channelId = 'simak_utama_v1';
const _channelName = 'Notifikasi SIMAK-MOSA';
const _channelDesc = 'Pemberitahuan pesan chat, pengumuman sekolah, dan kejadian penting.';

// Pola getar HP: jeda 0ms, getar 400ms, jeda 200ms, getar 400ms (pola dering jelas)
final _vibratePattern = Int64List.fromList([0, 400, 200, 400]);

Future<void> initNotifikasi() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (resp) {
      final payload = resp.payload;
      if (payload == null || payload.isEmpty) return;

      if (payload.startsWith('room:')) {
        final roomId = payload.substring(5);
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId)),
        );
      }
    },
  );

  final androidPlugin = _notif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  // Minta izin notifikasi di Android 13+ (API 33+)
  await androidPlugin?.requestNotificationsPermission();

  // Buat kanal notifikasi Android dengan prioritas MAX, suara aktif, dan getar aktif
  final channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: _channelDesc,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    vibrationPattern: _vibratePattern,
    enableLights: true,
    ledColor: const Color(0xFF00AA13),
  );

  await androidPlugin?.createNotificationChannel(channel);
}

/// Minta izin notifikasi secara manual (dipanggil dari halaman pengaturan).
Future<bool> requestIzinNotifikasi() async {
  final androidPlugin = _notif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  final res = await androidPlugin?.requestNotificationsPermission();
  return res ?? false;
}

int _idNotif = 1000;

/// Notifikasi Pesan Chat Masuk dengan dering & getar.
Future<void> notifPesanMasuk({
  required String roomId,
  required String namaPengirim,
  required String isi,
}) async {
  if (roomAktif == roomId) return; // sedang dibuka, tidak perlu notifikasi

  await _notif.show(
    _idNotif++,
    '💬 $namaPengirim',
    isi.isEmpty ? '[Mengirim foto]' : isi,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibratePattern,
        color: const Color(0xFF00AA13),
        category: AndroidNotificationCategory.message,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: 'room:$roomId',
  );
}

/// Notifikasi Pengumuman Baru Sekolah dengan dering & getar.
Future<void> notifPengumumanBaru({
  required String judul,
  required String isi,
}) async {
  await _notif.show(
    _idNotif++,
    '📢 Pengumuman: $judul',
    isi,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibratePattern,
        color: const Color(0xFF00AA13),
        category: AndroidNotificationCategory.status,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: 'pengumuman',
  );
}

/// Notifikasi Kejadian Penting / Cap on Spot dengan dering & getar.
Future<void> notifKejadianBaru({
  required String judul,
  required String kategori,
  required String pelapor,
}) async {
  await _notif.show(
    _idNotif++,
    '⚡ [$kategori] $judul',
    'Dilaporkan oleh $pelapor',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibratePattern,
        color: const Color(0xFFD97706),
        category: AndroidNotificationCategory.event,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: 'kejadian',
  );
}

/// Uji coba dering & getar langsung di perangkat.
Future<void> tesNotifikasiSuara() async {
  await _notif.show(
    9999,
    '🔔 Tes Dering SIMAK-MOSA',
    'Jika terdengar suara & HP bergetar, sistem notifikasi telah aktif sempurna!',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: _vibratePattern,
        color: const Color(0xFF00AA13),
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: 'test',
  );
}

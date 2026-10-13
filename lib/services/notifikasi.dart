import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/chat/chat_room_screen.dart';

// Notifikasi lokal chat: muncul saat ada pesan baru dari orang lain
// selagi aplikasi hidup (foreground/background). Ketuk -> buka room.
// Catatan: push saat aplikasi mati total butuh FCM (belum dipasang).

final _notif = FlutterLocalNotificationsPlugin();
final navigatorKey = GlobalKey<NavigatorState>();

/// Room yang sedang dibuka user; notifikasi untuk room ini disenyapkan.
String? roomAktif;

Future<void> initNotifikasi() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _notif.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (resp) {
      final roomId = resp.payload;
      if (roomId == null || roomId.isEmpty) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => ChatRoomScreen(roomId: roomId)),
      );
    },
  );
  // Kanal Android untuk pesan chat
  await _notif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'chat',
          'Pesan Chat',
          description: 'Notifikasi pesan chat masuk',
          importance: Importance.high,
        ),
      );
}

int _idNotif = 0;

/// Tampilkan notifikasi pesan masuk. Payload = roomId untuk navigasi.
Future<void> notifPesanMasuk({
  required String roomId,
  required String namaPengirim,
  required String isi,
}) async {
  if (roomAktif == roomId) return; // sedang dibuka, tidak perlu notif
  await _notif.show(
    _idNotif++,
    namaPengirim,
    isi.isEmpty ? '[Foto]' : isi,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'chat',
        'Pesan Chat',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: roomId,
  );
}

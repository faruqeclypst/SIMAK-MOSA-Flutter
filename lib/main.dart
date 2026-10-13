import 'package:flutter/material.dart';

import 'services/notifikasi.dart';
import 'services/pb_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PbService().init();
  await initNotifikasi();
  runApp(const SimakMosaApp());
}

class SimakMosaApp extends StatelessWidget {
  const SimakMosaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIMAK-MOSA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      home: PbService().isLoggedIn ? const MainShell() : const LoginScreen(),
    );
  }
}

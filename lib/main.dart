import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'services/notifikasi.dart';
import 'services/pb_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PbService().init();
  await initNotifikasi();
  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  runApp(SimakMosaApp(hasSeenOnboarding: hasSeenOnboarding));
}

class SimakMosaApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const SimakMosaApp({super.key, this.hasSeenOnboarding = false});

  @override
  Widget build(BuildContext context) {
    Widget initialHome;
    if (!hasSeenOnboarding) {
      initialHome = const OnboardingScreen();
    } else if (PbService().isLoggedIn) {
      initialHome = const MainShell();
    } else {
      initialHome = const LoginScreen();
    }

    return MaterialApp(
      title: 'SIMAK MOSA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      home: initialHome,
    );
  }
}

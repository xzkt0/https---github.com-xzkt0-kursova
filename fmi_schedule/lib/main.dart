import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/schedule_page.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_preferences.dart';
import 'services/notification_service.dart';
import 'services/background_monitor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await NotificationService.initialize();
    if (Platform.isAndroid) {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }
  }

  runApp(const FmiScheduleApp());
}

class FmiScheduleApp extends StatefulWidget {
  const FmiScheduleApp({super.key});

  @override
  State<FmiScheduleApp> createState() => _FmiScheduleAppState();
}

class _FmiScheduleAppState extends State<FmiScheduleApp> {
  bool isDarkTheme = false;
  bool? _isRegistered;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final registered = await UserPreferences.isRegistered();
    setState(() => _isRegistered = registered);
  }

  void toggleTheme() {
    setState(() => isDarkTheme = !isDarkTheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: _isRegistered == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isRegistered!
              ? SchedulePage(
                  toggleTheme: toggleTheme, isDarkTheme: isDarkTheme)
              : OnboardingScreen(
                  toggleTheme: toggleTheme, isDarkTheme: isDarkTheme),
    );
  }
}

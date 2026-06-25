import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/schedule_page.dart';
import 'screens/onboarding_screen.dart';
import 'services/user_preferences.dart';
import 'services/notification_service.dart';
import 'services/background_monitor.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await NotificationService.initialize(onAlarmTapped: _showAlarmDialog);
    } catch (_) {}
    if (Platform.isAndroid) {
      try {
        await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      } catch (_) {}
    }
  }

  runApp(const FmiScheduleApp());
}

void _showAlarmDialog() {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text('⏰ Час вставати!'),
      content: const Text('Будильник спрацював. Вимкнути?'),
      actions: [
        TextButton(
          onPressed: () {
            NotificationService.cancelAlarm();
            Navigator.of(context).pop();
          },
          child: const Text('Вимкнути будильник'),
        ),
      ],
    ),
  );
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
      navigatorKey: navigatorKey,
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

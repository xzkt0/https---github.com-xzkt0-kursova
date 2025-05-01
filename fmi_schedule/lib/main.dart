  import 'package:flutter/material.dart';
import 'screens/schedule_page.dart';

void main() {
  runApp(const FmiScheduleApp());
}

class FmiScheduleApp extends StatefulWidget {
  const FmiScheduleApp({super.key});

  @override
  State<FmiScheduleApp> createState() => _FmiScheduleAppState();
}

class _FmiScheduleAppState extends State<FmiScheduleApp> {
  bool isDarkTheme = false;

  void toggleTheme() {
    setState(() {
      isDarkTheme = !isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: SchedulePage(toggleTheme: toggleTheme, isDarkTheme: isDarkTheme),
    );
  }
}

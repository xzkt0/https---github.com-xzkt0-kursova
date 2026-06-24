import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

// v2 — Android кешує параметри каналу, новий ID примушує створити канал
// з правильними налаштуваннями (alarm audio stream, вібрація)
const _alarmChannelId = 'fmi_alarm_v2';
const _monitorChannelId = 'fmi_monitor_v1';
const _alarmNotifId = 1;
const _monitorNotifId = 2;

// Патерн вібрації: пауза → вібро → пауза → вібро ...
final _vibrationPattern = Int64List.fromList([0, 800, 300, 800, 300, 800]);

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (!_supported || _initialized) return;
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Явно реєструємо канал будильника з alarm audio attributes
    if (Platform.isAndroid) {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _alarmChannelId,
          'Будильник',
          description: 'Дзвінок будильника',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
        ),
      );
    }

    _initialized = true;
  }

  static Future<void> scheduleAlarm(DateTime alarmTime, String body) async {
    if (!_supported) return;
    final tzTime = tz.TZDateTime.from(alarmTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'Будильник',
      channelDescription: 'Дзвінок будильника',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,           // показує поверх lock-screen
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      ongoing: false,
      autoCancel: true,
    );

    await _plugin.cancel(_alarmNotifId);
    await _plugin.zonedSchedule(
      _alarmNotifId,
      '⏰ Час вставати!',
      body,
      tzTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAlarm() async {
    if (!_supported) return;
    await _plugin.cancel(_alarmNotifId);
  }

  static Future<void> showMonitoringStatus(String subtitle) async {
    if (!_supported) return;
    const androidDetails = AndroidNotificationDetails(
      _monitorChannelId,
      'Моніторинг будильника',
      channelDescription: 'Стан фонового моніторингу трафіку',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
    );
    await _plugin.show(
      _monitorNotifId,
      'Моніторинг активний',
      subtitle,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> cancelMonitoringStatus() async {
    if (!_supported) return;
    await _plugin.cancel(_monitorNotifId);
  }
}

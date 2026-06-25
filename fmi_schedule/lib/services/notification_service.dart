import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

const _alarmChannelId = 'fmi_alarm_v2';
const _monitorChannelId = 'fmi_monitor_v1';
const _alarmNotifId = 1;
const _monitorNotifId = 2;

final _vibrationPattern = Int64List.fromList([0, 800, 300, 800, 300, 800]);

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function()? _onAlarmTapped;

  static Future<void> initialize({void Function()? onAlarmTapped}) async {
    _onAlarmTapped = onAlarmTapped;
    if (!_supported || _initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Kyiv'));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Kiev'));
      } catch (_) {}
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        if (details.id == _alarmNotifId) {
          _onAlarmTapped?.call();
        }
      },
    );

    // Явно запитуємо дозвіл на iOS
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
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
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      ongoing: false,
      autoCancel: true,
    );

    await _plugin.cancel(_alarmNotifId);
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.zonedSchedule(
      _alarmNotifId,
      '⏰ Час вставати!',
      body,
      tzTime,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> showAlarmNow(String body) async {
    if (!_supported) return;
    final androidDetails = AndroidNotificationDetails(
      _alarmChannelId,
      'Будильник',
      channelDescription: 'Дзвінок будильника',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      autoCancel: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await _plugin.show(
      _alarmNotifId,
      '⏰ Час вставати!',
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
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

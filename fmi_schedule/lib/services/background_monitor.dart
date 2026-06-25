import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../api/schedule_api.dart';
import 'notification_service.dart';
import 'location_service.dart';
import 'route_service.dart';
import 'user_preferences.dart';

bool get _supportsWorkManager => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

const int kMonitorIntervalMinutes = 15;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == BackgroundMonitor.taskName) {
      await BackgroundMonitor.runCheck();
    }
    return true;
  });
}

class BackgroundMonitor {
  static const taskName = 'alarm_monitor_check';
  static const _uniqueName = 'alarm_monitor';

  static const _dayNames = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY',
    'SATURDAY', 'SUNDAY',
  ];

  static const _periodStarts = {
    1: (h: 8, m: 20),
    2: (h: 9, m: 50),
    3: (h: 11, m: 30),
    4: (h: 13, m: 0),
    5: (h: 14, m: 40),
    6: (h: 16, m: 10),
  };

  static Future<void> startMonitoring({Duration initialDelay = Duration.zero}) async {
    if (_supportsWorkManager) {
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        taskName,
        frequency: const Duration(minutes: kMonitorIntervalMinutes),
        initialDelay: initialDelay,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
    await UserPreferences.setMonitoringActive(true);
  }

  static Future<void> stopMonitoring() async {
    if (_supportsWorkManager) {
      await Workmanager().cancelByUniqueName(_uniqueName);
    }
    await UserPreferences.setMonitoringActive(false);
    await NotificationService.cancelMonitoringStatus();
  }

  /// force=true — ручна перевірка з UI, кидає виняток з текстом помилки
  static Future<String> runCheck({bool force = false}) async {
    await NotificationService.initialize();

    final prefs = await UserPreferences.load();
    if (prefs == null) {
      if (force) throw Exception('Профіль не знайдено');
      return 'no_profile';
    }

    if (!(prefs['alarmEnabled'] as bool)) {
      if (force) throw Exception('Будильник вимкнено у налаштуваннях');
      return 'alarm_disabled';
    }

    if (!force) {
      final active = await UserPreferences.isMonitoringActive();
      if (!active) return 'not_active';
    }

    final groupId = await UserPreferences.getLastGroupId();
    if (groupId == null) {
      if (force) throw Exception('Оберіть групу у розкладі перед перевіркою');
      return 'no_group';
    }

    List<Map<String, dynamic>> schedule;
    try {
      schedule = await ScheduleApi.fetchSchedule(groupId);
    } catch (e) {
      if (force) throw Exception('Не вдалось завантажити розклад: перевірте бекенд');
      return 'fetch_error';
    }

    if (schedule.isEmpty) {
      if (force) throw Exception('Розклад для цієї групи порожній');
      return 'empty_schedule';
    }

    // Демо-пара перекриває реальний розклад якщо встановлена
    final mockClass = await UserPreferences.getMockClassTime();
    final nextClass = mockClass != null && mockClass.isAfter(DateTime.now())
        ? mockClass
        : _findNextClassToday(schedule, _isCurrentWeekEven());
    if (nextClass == null) {
      await UserPreferences.saveCheckTime(DateTime.now());
      // Зупиняємо моніторинг лише для фонової перевірки, не для ручної
      if (!force) await stopMonitoring();
      if (force) throw Exception('Сьогодні більше немає пар (або вихідний)');
      return 'no_classes_today';
    }

    // Пріоритет origin: координати домашньої адреси → GPS → кеш GPS
    final homeCoords = await UserPreferences.getHomeAddressCoords();
    final freshGps   = homeCoords == null
        ? await LocationService.getCurrentPositionBackground()
        : null; // не витрачаємо час на GPS якщо є домашня адреса
    final cachedGps  = (homeCoords == null && freshGps == null)
        ? await UserPreferences.getLastKnownCoords()
        : null;
    final fromCoords = homeCoords ?? freshGps ?? cachedGps;

    // homeAddress (текст) передається тільки якщо немає координат (стара збережена адреса без Place Details)
    final homeAddressText = (fromCoords == null)
        ? await UserPreferences.getHomeAddress()
        : null;

    final transportMode = await UserPreferences.getTransportMode();
    final destination   = await UserPreferences.getDestination();
    final routeMinutes  = await RouteService.getRouteToFaculty(
      transportMode,
      fromCoords: fromCoords,
      homeAddress: homeAddressText,
      destLat: destination?.lat,
      destLng: destination?.lng,
    );
    final prepMinutes = prefs['prepMinutes'] as int;
    final bufferMinutes = prefs['bufferMinutes'] as int;

    final newAlarmTime = nextClass.subtract(
      Duration(minutes: routeMinutes + prepMinutes + bufferMinutes),
    );

    if (newAlarmTime.isBefore(DateTime.now())) {
      await UserPreferences.saveCheckTime(DateTime.now());
      if (force) throw Exception('Розрахований час підйому вже в минулому — пара занадто скоро');
      return 'alarm_in_past';
    }

    // Стратегія A: тільки раніше (для фонової перевірки)
    final earliest = await UserPreferences.getEarliestAlarmTime();
    final isEarlier = !force
        ? (earliest == null || newAlarmTime.isBefore(earliest))
        : true; // ручна перевірка завжди оновлює

    if (isEarlier) {
      await NotificationService.scheduleAlarm(
        newAlarmTime,
        'Пара о ${_fmt(nextClass)} • Маршрут ~$routeMinutes хв',
      );
      await UserPreferences.saveAlarmState(
        earliestAlarmTime: newAlarmTime,
        lastAlarmTime: newAlarmTime,
        lastCheckTime: DateTime.now(),
      );
    } else {
      await UserPreferences.saveCheckTime(DateTime.now());
    }

    final displayAlarm = isEarlier ? newAlarmTime : earliest!;
    await NotificationService.showMonitoringStatus(
      'Будильник: ${_fmt(displayAlarm)} • Перевірено: ${_fmt(DateTime.now())}',
    );

    return 'ok';
  }

  static bool _isCurrentWeekEven() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final weekNum = ((now.difference(startOfYear).inDays) / 7).ceil() + 1;
    return weekNum % 2 == 0;
  }

  static DateTime? _findNextClassToday(
    List<Map<String, dynamic>> schedule,
    bool isEvenWeek,
  ) {
    final dayName = _dayNames[DateTime.now().weekday - 1];
    final weekFilter = isEvenWeek ? 'EVEN' : 'ODD';
    final now = DateTime.now();

    for (int period = 1; period <= 6; period++) {
      final hasClass = schedule.any(
        (item) =>
            item['day'] == dayName &&
            item['evenodd'] == weekFilter &&
            item['period'] == period,
      );
      if (!hasClass) continue;

      final start = _periodStarts[period]!;
      final classTime =
          DateTime(now.year, now.month, now.day, start.h, start.m);
      if (classTime.isAfter(now)) return classTime;
    }
    return null;
  }

  static String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

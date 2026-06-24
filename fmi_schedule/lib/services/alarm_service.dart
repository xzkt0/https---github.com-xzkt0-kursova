import 'background_monitor.dart';
import 'notification_service.dart';
import 'user_preferences.dart';

class AlarmService {
  // Запустити моніторинг: одразу або з затримкою до часу startHour:startMinute
  static Future<void> activate() async {
    final startTime = await UserPreferences.getMonitorStartTime();
    final now = DateTime.now();
    final todayStart = DateTime(
      now.year, now.month, now.day, startTime.hour, startTime.minute,
    );

    Duration delay = Duration.zero;
    if (todayStart.isAfter(now)) {
      delay = todayStart.difference(now);
    }

    // Негайна перевірка якщо вже після часу старту
    if (delay == Duration.zero) {
      await BackgroundMonitor.runCheck();
    }

    await BackgroundMonitor.startMonitoring(initialDelay: delay);
  }

  // Зупинити моніторинг і скасувати будильник
  static Future<void> deactivate() async {
    await BackgroundMonitor.stopMonitoring();
    await NotificationService.cancelAlarm();
    await UserPreferences.clearMonitoringState();
  }

  // Ручний разовий розрахунок (для відладки або швидкої перевірки з UI)
  static Future<void> runManualCheck() async {
    await BackgroundMonitor.runCheck(force: true);
  }
}

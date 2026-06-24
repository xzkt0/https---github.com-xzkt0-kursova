import 'package:shared_preferences/shared_preferences.dart';
import 'route_service.dart';

class UserPreferences {
  // --- Реєстрація ---
  static const _keyEmail = 'user_email';
  static const _keyAlarmEnabled = 'alarm_enabled';
  static const _keyPrepMinutes = 'prep_minutes';
  static const _keyBufferMinutes = 'buffer_minutes';

  // --- Моніторинг ---
  static const _keyMonitoringActive = 'monitoring_active';
  static const _keyMonitorStartHour = 'monitor_start_hour';
  static const _keyMonitorStartMinute = 'monitor_start_minute';
  static const _keyEarliestAlarmTime = 'earliest_alarm_time';
  static const _keyLastAlarmTime = 'last_alarm_time';
  static const _keyLastCheckTime = 'last_check_time';
  static const _keyTransportMode = 'transport_mode';
  static const _keyHomeAddress      = 'home_address';
  static const _keyHomeAddressLat   = 'home_address_lat';
  static const _keyHomeAddressLng   = 'home_address_lng';
  static const _keyLastKnownCoords  = 'last_known_coords';
  static const _keyLastKnownCoordsTs = 'last_known_coords_ts';

  // =========================
  // Реєстрація / профіль
  // =========================

  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyEmail);
  }

  static Future<void> save({
    required String email,
    required bool alarmEnabled,
    required int prepMinutes,
    required int bufferMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    await prefs.setBool(_keyAlarmEnabled, alarmEnabled);
    await prefs.setInt(_keyPrepMinutes, prepMinutes);
    await prefs.setInt(_keyBufferMinutes, bufferMinutes);
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyEmail)) return null;
    return {
      'email': prefs.getString(_keyEmail)!,
      'alarmEnabled': prefs.getBool(_keyAlarmEnabled) ?? false,
      'prepMinutes': prefs.getInt(_keyPrepMinutes) ?? 30,
      'bufferMinutes': prefs.getInt(_keyBufferMinutes) ?? 10,
    };
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyAlarmEnabled);
    await prefs.remove(_keyPrepMinutes);
    await prefs.remove(_keyBufferMinutes);
  }

  // =========================
  // Остання група
  // =========================

  static Future<int?> getLastGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('last_group_id');
  }

  // =========================
  // Стан моніторингу
  // =========================

  static Future<bool> isMonitoringActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMonitoringActive) ?? false;
  }

  static Future<void> setMonitoringActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMonitoringActive, active);
  }

  static Future<({int hour, int minute})> getMonitorStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      hour: prefs.getInt(_keyMonitorStartHour) ?? 6,
      minute: prefs.getInt(_keyMonitorStartMinute) ?? 30,
    );
  }

  static Future<void> saveMonitorStartTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMonitorStartHour, hour);
    await prefs.setInt(_keyMonitorStartMinute, minute);
  }

  static Future<DateTime?> getEarliestAlarmTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyEarliestAlarmTime);
    return str != null ? DateTime.tryParse(str) : null;
  }

  static Future<DateTime?> getLastAlarmTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastAlarmTime);
    return str != null ? DateTime.tryParse(str) : null;
  }

  static Future<DateTime?> getLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyLastCheckTime);
    return str != null ? DateTime.tryParse(str) : null;
  }

  static Future<void> saveAlarmState({
    required DateTime earliestAlarmTime,
    required DateTime lastAlarmTime,
    required DateTime lastCheckTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyEarliestAlarmTime, earliestAlarmTime.toIso8601String());
    await prefs.setString(_keyLastAlarmTime, lastAlarmTime.toIso8601String());
    await prefs.setString(_keyLastCheckTime, lastCheckTime.toIso8601String());
  }

  static Future<void> saveCheckTime(DateTime checkTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastCheckTime, checkTime.toIso8601String());
  }

  static Future<void> clearMonitoringState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMonitoringActive);
    await prefs.remove(_keyEarliestAlarmTime);
    await prefs.remove(_keyLastAlarmTime);
    await prefs.remove(_keyLastCheckTime);
  }

  // =========================
  // Вид транспорту
  // =========================

  static Future<TransportMode> getTransportMode() async {
    final prefs = await SharedPreferences.getInstance();
    return TransportMode.fromString(prefs.getString(_keyTransportMode));
  }

  static Future<void> saveTransportMode(TransportMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTransportMode, mode.name);
  }

  // =========================
  // Кеш GPS-координат
  // =========================

  /// Зберегти останню відому локацію (зберігається при кожному успішному GPS)
  static Future<void> saveLastKnownCoords(String coords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastKnownCoords, coords);
    await prefs.setString(
        _keyLastKnownCoordsTs, DateTime.now().toIso8601String());
  }

  /// Повернути кешовані координати якщо вони молодші [maxAge], інакше null
  static Future<String?> getLastKnownCoords(
      {Duration maxAge = const Duration(hours: 8)}) async {
    final prefs = await SharedPreferences.getInstance();
    final coords = prefs.getString(_keyLastKnownCoords);
    if (coords == null) return null;
    final tsStr = prefs.getString(_keyLastKnownCoordsTs);
    if (tsStr == null) return null;
    final saved = DateTime.tryParse(tsStr);
    if (saved == null || DateTime.now().difference(saved) > maxAge) return null;
    return coords;
  }

  // =========================
  // Домашня адреса
  // =========================

  /// Повертає текст адреси або null якщо не задана
  static Future<String?> getHomeAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyHomeAddress);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  /// Повертає "lat,lng" якщо збережені координати домашньої адреси, інакше null
  static Future<String?> getHomeAddressCoords() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyHomeAddressLat);
    final lng = prefs.getDouble(_keyHomeAddressLng);
    if (lat == null || lng == null) return null;
    return '$lat,$lng';
  }

  /// [lat]/[lng] — координати з Place Details. Якщо не передані — зберігається тільки текст.
  static Future<void> saveHomeAddress(
    String address, {
    double? lat,
    double? lng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeAddress, address.trim());
    if (lat != null && lng != null) {
      await prefs.setDouble(_keyHomeAddressLat, lat);
      await prefs.setDouble(_keyHomeAddressLng, lng);
    }
  }

  static Future<void> clearHomeAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHomeAddress);
    await prefs.remove(_keyHomeAddressLat);
    await prefs.remove(_keyHomeAddressLng);
  }

  // =========================
  // Демо-пара
  // =========================

  static const _keyMockClassTime = 'mock_class_time';

  static Future<DateTime?> getMockClassTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_keyMockClassTime);
    return str != null ? DateTime.tryParse(str) : null;
  }

  static Future<void> setMockClassTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMockClassTime, time.toIso8601String());
  }

  static Future<void> clearMockClassTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMockClassTime);
  }

  // =========================
  // Адреса призначення
  // =========================

  static const _keyDestinationAddress = 'destination_address';
  static const _keyDestinationLat     = 'destination_lat';
  static const _keyDestinationLng     = 'destination_lng';

  static Future<void> saveDestination({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDestinationAddress, address);
    await prefs.setDouble(_keyDestinationLat, lat);
    await prefs.setDouble(_keyDestinationLng, lng);
  }

  static Future<DestinationPrefs?> getDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyDestinationAddress);
    final lat     = prefs.getDouble(_keyDestinationLat);
    final lng     = prefs.getDouble(_keyDestinationLng);
    if (address == null || lat == null || lng == null) return null;
    return DestinationPrefs(address: address, lat: lat, lng: lng);
  }

  static Future<void> clearDestination() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDestinationAddress);
    await prefs.remove(_keyDestinationLat);
    await prefs.remove(_keyDestinationLng);
  }
}

class DestinationPrefs {
  final String address;
  final double lat;
  final double lng;
  const DestinationPrefs({
    required this.address,
    required this.lat,
    required this.lng,
  });
}

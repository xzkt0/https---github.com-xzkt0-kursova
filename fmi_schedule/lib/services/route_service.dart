import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kFacultyCoords = '48.2932673,25.929342';

// TTL кешу — 1 година
const Duration _cacheTtl = Duration(hours: 1);

enum TransportMode {
  walking,
  car,
  transit;

  String get label {
    switch (this) {
      case TransportMode.walking: return 'Пішки';
      case TransportMode.car:     return 'Автомобіль';
      case TransportMode.transit: return 'Транспорт';
    }
  }

  int get mockMinutes {
    switch (this) {
      case TransportMode.walking: return 30;
      case TransportMode.car:     return 12;
      case TransportMode.transit: return 20;
    }
  }

  static TransportMode fromString(String? s) {
    return TransportMode.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TransportMode.walking,
    );
  }
}

// ---------------------------------------------------------------------------
// Кеш останнього успішного результату (per mode) у SharedPreferences
// ---------------------------------------------------------------------------
class _RouteCache {
  // Різні ключі для GPS та адресного маршруту
  static String _minutesKey(TransportMode m, {bool byAddress = false}) =>
      'route_cache_min_${byAddress ? 'addr' : 'gps'}_${m.name}';
  static String _tsKey(TransportMode m, {bool byAddress = false}) =>
      'route_cache_ts_${byAddress ? 'addr' : 'gps'}_${m.name}';

  static Future<int?> get(TransportMode mode, {bool byAddress = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_tsKey(mode, byAddress: byAddress));
    if (ts == null) return null;
    final saved = DateTime.tryParse(ts);
    if (saved == null || DateTime.now().difference(saved) > _cacheTtl) return null;
    return prefs.getInt(_minutesKey(mode, byAddress: byAddress));
  }

  static Future<void> save(TransportMode mode, int minutes,
      {bool byAddress = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_minutesKey(mode, byAddress: byAddress), minutes);
    await prefs.setString(
        _tsKey(mode, byAddress: byAddress), DateTime.now().toIso8601String());
  }
}

// ---------------------------------------------------------------------------
// Провайдер через бекенд-проксі
// ---------------------------------------------------------------------------
class BackendRouteProvider {
  static String get _baseUrl {
    if (!kIsWeb && !kIsWasm && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static Future<int> getRouteMinutes(
    TransportMode mode, {
    String? fromCoords,
    String? homeAddress,
    double? destLat,
    double? destLng,
  }) async {
    final byAddress = homeAddress != null && homeAddress.isNotEmpty;
    final ts = DateTime.now();

    Map<String, String> queryParams = {'mode': mode.name};

    // Destination (якщо не вказано — бекенд використає ФМІ за замовчуванням)
    if (destLat != null && destLng != null) {
      queryParams['destLat'] = destLat.toString();
      queryParams['destLng'] = destLng.toString();
    }

    if (byAddress) {
      queryParams['address'] = homeAddress!;
    } else if (fromCoords != null) {
      final parts = fromCoords.split(',');
      if (parts.length == 2) {
        queryParams['lat'] = parts[0].trim();
        queryParams['lng'] = parts[1].trim();
      } else {
        _log(mode, null,
            fallback: true, reason: 'invalid coords', byAddress: false);
        return (await _RouteCache.get(mode)) ?? mode.mockMinutes;
      }
    } else {
      _log(mode, null,
          fallback: true, reason: 'no origin provided', byAddress: false);
      return (await _RouteCache.get(mode)) ?? mode.mockMinutes;
    }

    try {
      final uri = Uri.parse('$_baseUrl/route')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final minutes = data['minutes'] as int;
        _log(mode, minutes,
            staticMinutes: data['staticMinutes'] as int?,
            meters: data['meters'] as int?,
            byAddress: byAddress,
            ts: ts);
        await _RouteCache.save(mode, minutes, byAddress: byAddress);
        return minutes;
      }

      _log(mode, null,
          fallback: true,
          reason:
              'backend ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 80))}',
          byAddress: byAddress,
          ts: ts);
    } on SocketException catch (e) {
      _log(mode, null,
          fallback: true, reason: 'no network: $e', byAddress: byAddress, ts: ts);
    } on http.ClientException catch (e) {
      _log(mode, null,
          fallback: true, reason: 'http error: $e', byAddress: byAddress, ts: ts);
    } catch (e) {
      _log(mode, null,
          fallback: true, reason: 'unexpected: $e', byAddress: byAddress, ts: ts);
    }

    final cached = await _RouteCache.get(mode, byAddress: byAddress);
    return cached ?? mode.mockMinutes;
  }

  static void _log(
    TransportMode mode,
    int? minutes, {
    int? staticMinutes,
    int? meters,
    bool fallback = false,
    bool byAddress = false,
    String? reason,
    DateTime? ts,
  }) {
    final time = (ts ?? DateTime.now()).toIso8601String();
    final src = byAddress ? 'addr' : 'gps';
    if (fallback) {
      print('[$time] RouteService mode=${mode.name} src=$src → FALLBACK ($reason)');
    } else {
      final extra = staticMinutes != null
          ? ', без трафіку: ${staticMinutes}хв, ${meters}м'
          : '';
      print('[$time] RouteService mode=${mode.name} src=$src → ${minutes}хв$extra');
    }
  }
}

// ---------------------------------------------------------------------------
// Публічний API
// ---------------------------------------------------------------------------
class RouteService {
  /// [fromCoords] — GPS-координати "lat,lng" (може бути null)
  /// [homeAddress] — якщо вказана, має пріоритет над GPS
  /// Якщо немає ні адреси ні GPS — повертає мок без виклику API
  static Future<int> getRouteToFaculty(
    TransportMode mode, {
    String? fromCoords,
    String? homeAddress,
    double? destLat,
    double? destLng,
  }) async {
    if (homeAddress == null && fromCoords == null) {
      return mode.mockMinutes;
    }
    return BackendRouteProvider.getRouteMinutes(
      mode,
      fromCoords: fromCoords,
      homeAddress: homeAddress,
      destLat: destLat,
      destLng: destLng,
    );
  }
}

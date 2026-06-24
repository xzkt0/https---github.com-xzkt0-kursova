import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'user_preferences.dart';

bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

enum LocationStatus { granted, denied, deniedForever, serviceDisabled }

class LocationResult {
  final String? coords; // "lat,lng" або null
  final LocationStatus status;
  final String? debugError; // для діагностики у снекбарі
  const LocationResult({this.coords, required this.status, this.debugError});
  bool get hasLocation => coords != null;
}

class LocationService {
  static Future<LocationStatus> requestPermission() async {
    if (!_supported) return LocationStatus.denied;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      return LocationStatus.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)
        ? LocationStatus.granted
        : LocationStatus.denied;
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();

  /// Запросити дозвіл і відразу отримати позицію (для UI)
  static Future<LocationResult> requestAndGetPosition() async {
    final status = await requestPermission();
    if (status != LocationStatus.granted) {
      return LocationResult(status: status);
    }
    return _getPosition(status);
  }

  /// Тільки отримати позицію (для фону — дозвіл вже повинен бути)
  static Future<LocationResult> getPositionIfAllowed() async {
    if (!_supported) return const LocationResult(status: LocationStatus.denied);

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return LocationResult(
        status: permission == LocationPermission.deniedForever
            ? LocationStatus.deniedForever
            : LocationStatus.denied,
      );
    }
    return _getPosition(LocationStatus.granted);
  }

  static Future<LocationResult> _getPosition(LocationStatus status) async {
    try {
      // Спершу — остання відома позиція: миттєво, не потребує GPS-фіксу
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        final coords = '${lastKnown.latitude},${lastKnown.longitude}';
        debugPrint('[GPS] lastKnown: $coords');
        await UserPreferences.saveLastKnownCoords(coords);
        return LocationResult(coords: coords, status: status);
      }

      debugPrint('[GPS] lastKnown=null, calling getCurrentPosition...');

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('GPS timeout 15s'),
      );

      final coords = '${position.latitude},${position.longitude}';
      debugPrint('[GPS] current: $coords');
      await UserPreferences.saveLastKnownCoords(coords);
      return LocationResult(coords: coords, status: status);
    } catch (e) {
      debugPrint('[GPS] error: $e');
      return LocationResult(status: status, debugError: e.toString());
    }
  }

  // Зворотна сумісність (background_monitor)
  static Future<String?> getCurrentPositionBackground() async {
    final result = await getPositionIfAllowed();
    return result.coords;
  }
}

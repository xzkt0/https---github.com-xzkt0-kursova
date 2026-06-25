import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String text;
  const PlaceSuggestion({required this.placeId, required this.text});
}

class PlaceDetails {
  final double lat;
  final double lng;
  final String address;
  const PlaceDetails({required this.lat, required this.lng, required this.address});
}

class PlacesService {
  static String _sessionToken = _newToken();

  static String _newToken() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = Object().hashCode.abs().toRadixString(36);
    return '$t$r';
  }

  static String get _baseUrl {
    if (!kIsWeb && !kIsWasm && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://172.20.10.2:8000';
  }

  /// Повертає підказки для рядка пошуку. Мінімум 2 символи.
  static Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/autocomplete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'input': input.trim(),
              'sessionToken': _sessionToken,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List;
      return list
          .map((e) => PlaceSuggestion(
                placeId: e['placeId'] as String,
                text: e['text'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Повертає координати + адресу за placeId.
  /// Завершує поточну сесію і одразу генерує новий токен.
  static Future<PlaceDetails?> getDetails(String placeId) async {
    final token = _sessionToken;
    debugPrint('[Places] Place Details → placeId=$placeId');
    try {
      final uri = Uri.parse('$_baseUrl/place').replace(
        queryParameters: {'placeId': placeId, 'sessionToken': token},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[Places] Place Details error ${response.statusCode}: ${response.body}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PlaceDetails(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        address: data['address'] as String,
      );
    } catch (e) {
      debugPrint('[Places] Place Details exception: $e');
      return null;
    } finally {
      // Завжди скидаємо токен після Place Details — нова сесія
      _sessionToken = _newToken();
      debugPrint('[Places] Session token reset');
    }
  }
}

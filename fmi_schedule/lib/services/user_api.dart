import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UserApi {
  static String get _baseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://192.168.1.104:8000';
  }

  static Future<void> register({
    required String email,
    required bool alarmEnabled,
    required int prepMinutes,
    required int bufferMinutes,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'alarm_enabled': alarmEnabled,
        'prep_minutes': prepMinutes,
        'buffer_minutes': bufferMinutes,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Помилка реєстрації: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>?> getUser(String email) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users')
          .replace(queryParameters: {'email': email}),
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    }
    throw Exception('Не вдалось отримати дані: ${response.statusCode}');
  }

  static Future<void> updateUser({
    required String email,
    required bool alarmEnabled,
    required int prepMinutes,
    required int bufferMinutes,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users')
          .replace(queryParameters: {'email': email}),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'alarm_enabled': alarmEnabled,
        'prep_minutes': prepMinutes,
        'buffer_minutes': bufferMinutes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Не вдалось оновити налаштування: ${response.statusCode}');
    }
  }
}
